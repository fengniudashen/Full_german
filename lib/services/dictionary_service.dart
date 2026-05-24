import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'text_comparator.dart';

class DictionaryEntry {
  const DictionaryEntry({
    required this.word,
    required this.source,
    required this.definitions,
  });

  final String word;
  final String source;
  final List<String> definitions;
}

class DictionaryService {
  DictionaryService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  void dispose() {
    _client.close();
  }

  static const Map<String, List<String>> _offlineDefinitions = {
    'ich': ['第一人称单数代词：我。'],
    'du': ['第二人称单数代词：你。'],
    'er': ['第三人称单数阳性代词：他。'],
    'sie': ['第三人称阴性代词：她；复数：他们/她们。'],
    'es': ['第三人称中性代词：它。'],
    'sein': ['动词：是；也可作物主代词“他的”。'],
    'haben': ['动词：有。'],
    'werden': ['动词：成为；也用于构成将来时。'],
    'und': ['连词：和、并且。'],
    'nicht': ['否定副词：不、没有。'],
    'der': ['阳性定冠词；也可作关系代词。'],
    'die': ['阴性或复数定冠词；也可作关系代词。'],
    'das': ['中性定冠词；也可作指示代词或关系代词。'],
    'ein': ['不定冠词：一个。'],
    'lernen': ['动词：学习。'],
    'heute': ['副词：今天。'],
    'morgen': ['名词：早晨；副词：明天。'],
    'deutsch': ['形容词/名词：德语的；德语。'],
  };

  Future<DictionaryEntry> lookup(String rawWord) async {
    final word = TextComparator.dictionaryKey(rawWord);
    if (word.isEmpty) {
      return const DictionaryEntry(
        word: '',
        source: '本地',
        definitions: ['请选择一个有效单词。'],
      );
    }

    final local = _offlineDefinitions[word];
    if (local != null) {
      return DictionaryEntry(word: word, source: '本地简易词库', definitions: local);
    }

    try {
      final uri = Uri.https(
        'api.dictionaryapi.dev',
        '/api/v2/entries/de/$word',
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final definitions = _parseDefinitions(decoded);
        if (definitions.isNotEmpty) {
          return DictionaryEntry(
            word: word,
            source: 'dictionaryapi.dev',
            definitions: definitions,
          );
        }
      }
    } on TimeoutException {
      return DictionaryEntry(
        word: word,
        source: '网络超时',
        definitions: const ['词典服务响应超时，可稍后再试。'],
      );
    } catch (_) {
      // Fall through to the neutral not-found response.
    }

    return DictionaryEntry(
      word: word,
      source: '未命中',
      definitions: const ['暂未找到释义。你可以在语法笔记中记录自己的解释。'],
    );
  }

  List<String> _parseDefinitions(Object? decoded) {
    if (decoded is! List || decoded.isEmpty) {
      return const [];
    }

    final definitions = <String>[];
    for (final entry in decoded.take(2)) {
      if (entry is! Map<String, Object?>) {
        continue;
      }
      final meanings = entry['meanings'];
      if (meanings is! List) {
        continue;
      }
      for (final meaning in meanings.take(3)) {
        if (meaning is! Map<String, Object?>) {
          continue;
        }
        final partOfSpeech = meaning['partOfSpeech']?.toString();
        final rawDefinitions = meaning['definitions'];
        if (rawDefinitions is! List) {
          continue;
        }
        for (final definitionEntry in rawDefinitions.take(2)) {
          if (definitionEntry is! Map<String, Object?>) {
            continue;
          }
          final definition = definitionEntry['definition']?.toString();
          if (definition == null || definition.trim().isEmpty) {
            continue;
          }
          definitions.add(
            partOfSpeech == null || partOfSpeech.isEmpty
                ? definition
                : '$partOfSpeech: $definition',
          );
        }
      }
    }

    return definitions.toList(growable: false);
  }
}

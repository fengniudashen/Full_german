import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'text_comparator.dart';

class DictionaryEntry {
  const DictionaryEntry({
    required this.word,
    required this.source,
    required this.definitions,
    this.phonetic = '',
    this.partOfSpeech = '',
    this.examples = const [],
  });

  final String word;
  final String source;
  final List<String> definitions;
  final String phonetic;
  final String partOfSpeech;
  final List<String> examples;
}

class DictionaryService {
  DictionaryService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  final Map<String, DictionaryEntry> _cache = {};

  void dispose() => _client.close();

  static const Map<String, List<String>> _offlineDefinitions = {
    'ich': ['pron. 第一人称单数代词：我。'],
    'du': ['pron. 第二人称单数代词：你。'],
    'er': ['pron. 第三人称单数阳性代词：他。'],
    'sie': ['pron. 第三人称阴性代词：她；复数：他们/她们。'],
    'es': ['pron. 第三人称中性代词：它。'],
    'wir': ['pron. 第一人称复数代词：我们。'],
    'ihr': ['pron. 第二人称复数代词：你们。'],
    'sein': ['v. 是；也可作物主代词"他的"。'],
    'haben': ['v. 有。'],
    'werden': ['v. 成为；也用于构成将来时和被动态。'],
    'können': ['v. 能够、可以（情态动词）。'],
    'müssen': ['v. 必须（情态动词）。'],
    'sollen': ['v. 应该（情态动词）。'],
    'wollen': ['v. 想要（情态动词）。'],
    'dürfen': ['v. 被允许（情态动词）。'],
    'mögen': ['v. 喜欢；也可表示"可能"。'],
    'und': ['conj. 和、并且。'],
    'oder': ['conj. 或者。'],
    'aber': ['conj. 但是、然而。'],
    'weil': ['conj. 因为（从句连词）。'],
    'dass': ['conj. 引导从句：…（相当于that）。'],
    'wenn': ['conj. 如果；当…的时候。'],
    'nicht': ['adv. 否定副词：不、没有。'],
    'der': ['art. 阳性定冠词；也可作关系代词。'],
    'die': ['art. 阴性或复数定冠词；也可作关系代词。'],
    'das': ['art. 中性定冠词；也可作指示/关系代词。'],
    'ein': ['art. 不定冠词：一个。'],
    'kein': ['art. 否定冠词：没有一个。'],
    'lernen': ['v. 学习。'],
    'sprechen': ['v. 说话、讲。'],
    'schreiben': ['v. 写。'],
    'lesen': ['v. 读、阅读。'],
    'hören': ['v. 听。'],
    'verstehen': ['v. 理解、懂。'],
    'gehen': ['v. 走、去。'],
    'kommen': ['v. 来。'],
    'machen': ['v. 做、制作。'],
    'geben': ['v. 给。'],
    'nehmen': ['v. 拿、取。'],
    'sehen': ['v. 看见。'],
    'finden': ['v. 找到；觉得。'],
    'sagen': ['v. 说。'],
    'wissen': ['v. 知道。'],
    'denken': ['v. 想、思考。'],
    'heute': ['adv. 今天。'],
    'morgen': ['n./adv. 早晨；明天。'],
    'gestern': ['adv. 昨天。'],
    'hier': ['adv. 这里。'],
    'dort': ['adv. 那里。'],
    'deutsch': ['adj./n. 德语的；德语。'],
    'gut': ['adj. 好的。'],
    'schlecht': ['adj. 差的、坏的。'],
    'groß': ['adj. 大的；高的。'],
    'klein': ['adj. 小的。'],
    'schön': ['adj. 美丽的、好的。'],
    'danke': ['interj. 谢谢。'],
    'bitte': ['interj. 请；不客气。'],
    'ja': ['adv. 是的。'],
    'nein': ['adv. 不是。'],
  };

  Future<DictionaryEntry> lookup(String rawWord) async {
    final word = TextComparator.dictionaryKey(rawWord);
    if (word.isEmpty) {
      return const DictionaryEntry(
        word: '', source: '本地', definitions: ['请选择一个有效单词。'],
      );
    }

    if (_cache.containsKey(word)) return _cache[word]!;

    final local = _offlineDefinitions[word];
    if (local != null) {
      final entry = DictionaryEntry(
        word: word, source: '本地简易词库', definitions: local,
      );
      _cache[word] = entry;
      return entry;
    }

    try {
      final uri = Uri.https('api.dictionaryapi.dev', '/api/v2/entries/de/$word');
      final response = await _client.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final entry = _parseResponse(word, decoded);
        if (entry != null) {
          _cache[word] = entry;
          return entry;
        }
      }
    } on TimeoutException {
      return DictionaryEntry(
        word: word, source: '网络超时',
        definitions: const ['词典服务响应超时，可稍后再试。'],
      );
    } catch (_) {}

    return DictionaryEntry(
      word: word, source: '未命中',
      definitions: const ['暂未找到释义。你可以在语法笔记中记录自己的解释。'],
    );
  }

  DictionaryEntry? _parseResponse(String word, Object? decoded) {
    if (decoded is! List || decoded.isEmpty) return null;
    final defs = <String>[];
    final examples = <String>[];
    String phonetic = '';
    String pos = '';

    for (final entry in decoded.take(2)) {
      if (entry is! Map<String, Object?>) continue;
      phonetic = entry['phonetic']?.toString() ?? phonetic;
      final meanings = entry['meanings'];
      if (meanings is! List) continue;
      for (final meaning in meanings.take(3)) {
        if (meaning is! Map<String, Object?>) continue;
        pos = meaning['partOfSpeech']?.toString() ?? pos;
        final rawDefs = meaning['definitions'];
        if (rawDefs is! List) continue;
        for (final d in rawDefs.take(2)) {
          if (d is! Map<String, Object?>) continue;
          final def = d['definition']?.toString();
          if (def == null || def.trim().isEmpty) continue;
          defs.add(pos.isEmpty ? def : '$pos: $def');
          final ex = d['example']?.toString();
          if (ex != null && ex.trim().isNotEmpty) examples.add(ex);
        }
      }
    }

    if (defs.isEmpty) return null;
    return DictionaryEntry(
      word: word,
      source: 'dictionaryapi.dev',
      definitions: defs.toList(growable: false),
      phonetic: phonetic,
      partOfSpeech: pos,
      examples: examples.toList(growable: false),
    );
  }
}

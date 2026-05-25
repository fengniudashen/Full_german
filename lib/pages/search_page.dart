import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_sentence.dart';
import '../providers/app_state.dart';
import '../widgets/glass_card.dart';
import 'dictation_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchCtrl = TextEditingController();
  List<StudySentence> _results = const [];
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索句子内容…',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
          onChanged: _onSearch,
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _results = const []);
              },
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchCtrl.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64,
                color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text('输入关键词搜索所有项目中的句子',
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 56,
                color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text('没有找到匹配的句子',
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final s = _results[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => DictationPage(projectId: s.projectId),
              ));
            },
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _highlightText(context, s.text, _searchCtrl.text),
                if (s.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.note_outlined, size: 14,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(s.note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _highlightText(BuildContext context, String text, String query) {
    final theme = Theme.of(context);
    if (query.isEmpty) return Text(text);

    final lower = text.toLowerCase();
    final qLower = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final idx = lower.indexOf(qLower, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: TextStyle(
          backgroundColor:
              theme.colorScheme.primary.withValues(alpha: 0.2),
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.primary,
        ),
      ));
      start = idx + query.length;
    }

    return RichText(text: TextSpan(
      style: theme.textTheme.bodyMedium,
      children: spans,
    ));
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _searching = true);
    try {
      final results =
          await context.read<AppState>().database.searchSentences(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }
}

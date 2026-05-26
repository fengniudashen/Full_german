import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_page.dart';

/// Word frequency analysis — shows the most common words across all
/// projects, visualized as a chart and sortable table.
class WordStatsPage extends StatefulWidget {
  const WordStatsPage({super.key});

  @override
  State<WordStatsPage> createState() => _WordStatsPageState();
}

class _WordStatsPageState extends State<WordStatsPage> {
  List<_WordFreq> _words = [];
  bool _loading = true;
  String _sortBy = 'freq'; // 'freq' or 'alpha'
  int _minLength = 3; // Filter short words

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    setState(() => _loading = true);

    final state = context.read<AppState>();
    // Gather all sentences from all projects
    final allText = StringBuffer();
    for (final p in state.projects) {
      allText.write(p.sourceText);
      allText.write(' ');
    }

    final freq = <String, int>{};
    final words = allText.toString().split(RegExp(r'[\s,.:;!?"""''()\[\]{}–—/\\]+'));
    for (final w in words) {
      final clean = w.toLowerCase().replaceAll(RegExp(r'[^\w\u00C0-\u024FäöüÄÖÜß]'), '');
      if (clean.length >= _minLength) {
        freq[clean] = (freq[clean] ?? 0) + 1;
      }
    }

    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      _words = sorted.take(200).map((e) => _WordFreq(e.key, e.value)).toList();
      _loading = false;
    });
  }

  void _sort(String by) {
    setState(() {
      _sortBy = by;
      if (by == 'alpha') {
        _words.sort((a, b) => a.word.compareTo(b.word));
      } else {
        _words.sort((a, b) => b.count.compareTo(a.count));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('词频分析'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.filter_alt),
            tooltip: '最小词长',
            onSelected: (v) {
              _minLength = v;
              _analyze();
            },
            itemBuilder: (_) => [2, 3, 4, 5, 6].map((n) =>
              PopupMenuItem(value: n, child: Text('≥ $n 字符')),
            ).toList(),
          ),
          IconButton(
            icon: Icon(_sortBy == 'freq' ? Icons.sort : Icons.sort_by_alpha),
            tooltip: _sortBy == 'freq' ? '按字母排序' : '按频率排序',
            onPressed: () => _sort(_sortBy == 'freq' ? 'alpha' : 'freq'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
              ? Center(
                  child: Text('没有足够的文本数据',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      )),
                )
              : ResponsivePage(
                  maxWidth: 800,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSummary(theme, scheme),
                      const SizedBox(height: 16),
                      _buildTopWordsChart(theme, scheme),
                      const SizedBox(height: 16),
                      Text('完整词表 (Top 200)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 8),
                      Expanded(child: _buildWordList(theme, scheme)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummary(ThemeData theme, ColorScheme scheme) {
    final total = _words.fold<int>(0, (s, w) => s + w.count);
    final unique = _words.length;
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('$total', style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900, color: scheme.primary)),
                Text('总词数', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('$unique', style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900, color: Colors.green)),
                Text('独立词', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(_words.isEmpty ? '0' : '${_words.first.count}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900, color: Colors.orange)),
                Text('最高频', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopWordsChart(ThemeData theme, ColorScheme scheme) {
    final top = _words.take(15).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    final maxCount = top.first.count.toDouble();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top 15 高频词', style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...top.map((w) {
            final ratio = maxCount > 0 ? w.count / maxCount : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(w.word,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 14,
                        backgroundColor: scheme.surfaceContainerHighest,
                        color: _barColor(ratio),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text('${w.count}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.right),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _barColor(double ratio) {
    if (ratio > 0.7) return Colors.red.shade400;
    if (ratio > 0.4) return Colors.orange;
    return Colors.blue;
  }

  Widget _buildWordList(ThemeData theme, ColorScheme scheme) {
    return ListView.builder(
      itemCount: _words.length,
      itemBuilder: (context, index) {
        final w = _words[index];
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: scheme.primaryContainer,
            child: Text('${index + 1}',
                style: TextStyle(fontSize: 10, color: scheme.primary, fontWeight: FontWeight.w700)),
          ),
          title: Text(w.word, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: Text('×${w.count}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              )),
        );
      },
    );
  }
}

class _WordFreq {
  const _WordFreq(this.word, this.count);
  final String word;
  final int count;
}

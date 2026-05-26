import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_page.dart';

/// Error pattern analysis — categorize wrong words by error type,
/// show distribution charts and targeted practice suggestions.
class ErrorAnalysisPage extends StatelessWidget {
  const ErrorAnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = context.watch<AppState>();
    final allWords = state.wrongWords;

    if (allWords.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('错误类型分析')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
              SizedBox(height: 16),
              Text('暂无错词记录', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    // Categorize errors
    final categories = <String, List<_ErrorEntry>>{};

    for (final w in allWords) {
      final wrong = w.wrongForm;
      final correct = w.correctForm;
      final wLower = wrong.toLowerCase();
      final cLower = correct.toLowerCase();

      String category;
      if (wLower == cLower && wrong != correct) {
        category = '大小写错误';
      } else if (_isUmlautError(wLower, cLower)) {
        category = '变音符号错误';
      } else if (_isEndingError(wLower, cLower)) {
        category = '词尾变化错误';
      } else if (_isExtraOrMissing(wrong, correct)) {
        category = '漏词/多词';
      } else if (_levenshtein(wLower, cLower) <= 2) {
        category = '拼写小错';
      } else {
        category = '拼写大错';
      }

      categories.putIfAbsent(category, () => []);
      categories[category]!.add(_ErrorEntry(
        wrong: wrong,
        correct: correct,
        sentence: w.sentenceText,
        project: w.projectName,
        mastered: w.mastered,
      ));
    }

    // Sort by count descending
    final sorted = categories.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    // Color map
    final colorMap = <String, Color>{
      '大小写错误': Colors.amber,
      '变音符号错误': Colors.orange,
      '词尾变化错误': Colors.deepPurple,
      '漏词/多词': Colors.red,
      '拼写小错': Colors.blue,
      '拼写大错': Colors.red.shade900,
    };

    final iconMap = <String, IconData>{
      '大小写错误': Icons.text_fields,
      '变音符号错误': Icons.spellcheck,
      '词尾变化错误': Icons.rule,
      '漏词/多词': Icons.playlist_add,
      '拼写小错': Icons.edit,
      '拼写大错': Icons.dangerous,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('错误类型分析')),
      body: ResponsivePage(
        maxWidth: 900,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary bar
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('错误类型分布',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 16),
                  // Bar chart
                  ...sorted.map((e) {
                    final pct = e.value.length / allWords.length;
                    final color = colorMap[e.key] ?? Colors.grey;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(iconMap[e.key] ?? Icons.error, size: 16, color: color),
                              const SizedBox(width: 6),
                              Text(e.key, style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              )),
                              const Spacer(),
                              Text('${e.value.length}次 (${(pct * 100).toStringAsFixed(0)}%)',
                                  style: theme.textTheme.bodySmall),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: color.withValues(alpha: 0.15),
                              valueColor: AlwaysStoppedAnimation(color),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Category details
            ...sorted.map((e) {
              final color = colorMap[e.key] ?? Colors.grey;
              final examples = e.value.take(8).toList();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(iconMap[e.key] ?? Icons.error, color: color, size: 20),
                          const SizedBox(width: 8),
                          Text(e.key, style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: color,
                          )),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('${e.value.length}',
                                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...examples.map((ex) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(ex.wrong,
                                style: TextStyle(
                                  color: scheme.error,
                                  decoration: TextDecoration.lineThrough,
                                  fontSize: 13,
                                )),
                            const Text(' → ', style: TextStyle(fontSize: 13)),
                            Text(ex.correct,
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                )),
                          ],
                        ),
                      )),
                      if (e.value.length > 8)
                        Text('…还有${e.value.length - 8}个',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            )),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  static bool _isUmlautError(String a, String b) {
    final umlautPairs = [
      ['a', 'ä'], ['o', 'ö'], ['u', 'ü'],
      ['ae', 'ä'], ['oe', 'ö'], ['ue', 'ü'],
      ['ss', 'ß'],
    ];
    for (final pair in umlautPairs) {
      if (a.replaceAll(pair[0], pair[1]) == b ||
          a.replaceAll(pair[1], pair[0]) == b) return true;
    }
    return false;
  }

  static bool _isEndingError(String a, String b) {
    if (a.length < 3 || b.length < 3) return false;
    // Same stem, different ending (last 1-3 chars)
    final minLen = a.length < b.length ? a.length : b.length;
    final commonPrefix = _commonPrefixLen(a, b);
    return commonPrefix >= minLen * 0.6;
  }

  static int _commonPrefixLen(String a, String b) {
    int i = 0;
    while (i < a.length && i < b.length && a[i] == b[i]) i++;
    return i;
  }

  static bool _isExtraOrMissing(String a, String b) {
    return a.trim().isEmpty || b.trim().isEmpty ||
        a.split(' ').length != b.split(' ').length;
  }

  static int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final m = List.generate(a.length + 1, (i) =>
      List.generate(b.length + 1, (j) => i == 0 ? j : j == 0 ? i : 0));
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        m[i][j] = [m[i - 1][j] + 1, m[i][j - 1] + 1, m[i - 1][j - 1] + cost]
            .reduce((a, b) => a < b ? a : b);
      }
    }
    return m[a.length][b.length];
  }
}

class _ErrorEntry {
  final String wrong;
  final String correct;
  final String sentence;
  final String project;
  final bool mastered;

  const _ErrorEntry({
    required this.wrong,
    required this.correct,
    required this.sentence,
    required this.project,
    required this.mastered,
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/ai_service.dart';
import '../widgets/responsive_page.dart';

/// AI Smart Review — analyzes user's learning data and generates
/// personalized review recommendations and study plans.
class SmartReviewPage extends StatefulWidget {
  const SmartReviewPage({super.key});

  @override
  State<SmartReviewPage> createState() => _SmartReviewPageState();
}

class _SmartReviewPageState extends State<SmartReviewPage> {
  String? _plan;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generatePlan();
  }

  Future<void> _generatePlan() async {
    setState(() { _loading = true; _error = null; _plan = null; });

    try {
      final state = context.read<AppState>();

      // Gather learning data
      final totalSentences = state.totalSentencesPracticed;
      final streak = state.streakDays;
      final projects = state.projects;
      final wrongWords = state.wrongWords;
      final unmastered = wrongWords.where((w) => !w.mastered).toList();
      final mastered = wrongWords.where((w) => w.mastered).length;
      final dueForReview = wrongWords.where((w) => w.isDueForReview).toList();

      // Build stats summary for AI
      final stats = StringBuffer();
      stats.writeln('学习者统计数据:');
      stats.writeln('- 累计练习句子: $totalSentences');
      stats.writeln('- 连续学习天数: $streak');
      stats.writeln('- 项目数量: ${projects.length}');
      stats.writeln('- 错词总数: ${wrongWords.length} (已掌握: $mastered, 待复习: ${unmastered.length})');
      stats.writeln('- 今日待复习: ${dueForReview.length}');

      if (projects.isNotEmpty) {
        stats.writeln('\n项目列表:');
        for (final p in projects.take(10)) {
          stats.writeln('- ${p.name}');
        }
      }

      if (unmastered.isNotEmpty) {
        stats.writeln('\n最近的错词(未掌握):');
        for (final w in unmastered.take(20)) {
          stats.writeln('- "${w.wrongForm}" → "${w.correctForm}" (来自: ${w.projectName}, 复习${w.reviewCount}次)');
        }
      }

      // Analyze wrong word patterns
      final wrongPatterns = <String, int>{};
      for (final w in wrongWords) {
        // Categorize by error type (simplified)
        if (w.wrongForm.toLowerCase() != w.correctForm.toLowerCase()) {
          final isCapitalization = w.wrongForm.toLowerCase() == w.correctForm.toLowerCase();
          if (isCapitalization) {
            wrongPatterns['大小写'] = (wrongPatterns['大小写'] ?? 0) + 1;
          } else {
            wrongPatterns['拼写'] = (wrongPatterns['拼写'] ?? 0) + 1;
          }
        }
      }

      if (wrongPatterns.isNotEmpty) {
        stats.writeln('\n错误类型分布:');
        for (final e in wrongPatterns.entries) {
          stats.writeln('- ${e.key}: ${e.value}次');
        }
      }

      final provider = state.settings.activeProvider;
      final service = AiService(provider: provider);

      final result = await service.chatRaw(
        '$stats\n\n'
        '请基于以上学习数据，生成个性化的学习建议：\n\n'
        '## 📊 学习状况诊断\n'
        '分析学习者的强弱项，给出总体评价\n\n'
        '## 🎯 今日学习计划\n'
        '制定具体的今日学习步骤（15-30分钟）\n\n'
        '## 📝 重点复习清单\n'
        '从错词中挑选最需要复习的5个词，给出记忆技巧\n\n'
        '## 💡 提升建议\n'
        '3条针对性的学习方法建议\n\n'
        '## 🏆 本周目标\n'
        '设定一个可达成的本周学习目标\n\n'
        '用Markdown格式排版，建议要具体、可执行。',
        systemMessage: '你是一位资深德语学习规划师，善于分析学习数据并制定个性化学习计划。'
            '不要输出<think>标签，直接给出建议。使用Markdown格式。',
      );

      if (mounted) setState(() { _plan = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 学习规划'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新生成',
            onPressed: _loading ? null : _generatePlan,
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('AI 正在分析你的学习数据…',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      )),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: scheme.error),
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: scheme.error)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _generatePlan,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _plan != null
                  ? ResponsivePage(
                      maxWidth: 800,
                      child: Markdown(
                        data: _plan!,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                          h2: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 2,
                          ),
                          p: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
                          strong: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
    );
  }
}

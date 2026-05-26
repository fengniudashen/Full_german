import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/ai_service.dart';
import '../widgets/responsive_page.dart';

/// AI-generated daily German content — word of the day, grammar tip,
/// mini exercise, and cultural fact. Unique to AI era apps.
class DailyPage extends StatefulWidget {
  const DailyPage({super.key});

  @override
  State<DailyPage> createState() => _DailyPageState();
}

class _DailyPageState extends State<DailyPage> {
  String? _content;
  bool _loading = false;
  String? _error;
  String _level = 'B1';

  static const _levels = ['A1', 'A2', 'B1', 'B2', 'C1'];

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _error = null; _content = null; });

    try {
      final provider = context.read<AppState>().settings.activeProvider;
      final service = AiService(provider: provider);

      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final result = await service.chatRaw(
        '今天是 $dateStr，请为 $_level 水平的德语学习者生成今日德语学习内容。\n\n'
        '请包含以下五个板块：\n\n'
        '## 📝 今日单词\n'
        '选一个实用的德语单词，给出：词性、复数/变位、释义、2个例句、近义词\n\n'
        '## 📖 今日句子\n'
        '一个有代表性的德语句子，附翻译和语法要点分析\n\n'
        '## 🔤 语法小贴士\n'
        '一个 $_level 级别的语法知识点，用简洁的例子说明\n\n'
        '## 🧠 迷你练习\n'
        '3道快速练习题(选择/填空/判断)，并在末尾给出答案\n\n'
        '## 🌍 文化小知识\n'
        '一个关于德国/奥地利/瑞士的文化趣闻\n\n'
        '请用Markdown格式排版，德语单词和句子加粗，中文解释清晰。',
        systemMessage: '你是一位创意十足的德语教师，每天为学生准备丰富有趣的学习内容。'
            '用Markdown格式输出，使内容结构清晰、易读。不要输出<think>标签。',
      );

      if (mounted) setState(() { _content = result; _loading = false; });
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
        title: const Text('每日德语'),
        actions: [
          // Level selector
          SegmentedButton<String>(
            segments: _levels.map((l) => ButtonSegment(value: l, label: Text(l))).toList(),
            selected: {_level},
            onSelectionChanged: (s) {
              _level = s.first;
              _generate();
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新生成',
            onPressed: _loading ? null : _generate,
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
                  Text('AI 正在准备今日内容…',
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
                        onPressed: _generate,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _content != null
                  ? ResponsivePage(
                      maxWidth: 800,
                      child: Markdown(
                        data: _content!,
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

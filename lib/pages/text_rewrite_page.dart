import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/ai_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_page.dart';

/// AI text rewriter — simplify (降维) or elevate (升维) any German text
/// to match a target CEFR level, preserving core meaning.
class TextRewritePage extends StatefulWidget {
  const TextRewritePage({super.key, this.initialText});
  final String? initialText;

  @override
  State<TextRewritePage> createState() => _TextRewritePageState();
}

class _TextRewritePageState extends State<TextRewritePage> {
  final TextEditingController _controller = TextEditingController();
  String _targetLevel = 'B1';
  String _style = 'simplify'; // 'simplify', 'elevate', 'rewrite'
  String? _result;
  bool _loading = false;

  static const _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
  static const _styles = {
    'simplify': '降维简化',
    'elevate': '升维提升',
    'rewrite': '风格改写',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) {
      _controller.text = widget.initialText!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _rewrite() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() { _loading = true; _result = null; });

    try {
      final provider = context.read<AppState>().settings.activeProvider;
      final service = AiService(provider: provider);

      String prompt;
      switch (_style) {
        case 'simplify':
          prompt = '请将以下德语文本降维简化至 $_targetLevel 水平：\n\n$text\n\n'
              '要求：\n'
              '1. **简化版文本**: 用 $_targetLevel 级别的词汇和语法改写\n'
              '2. **对照标注**: 列出原文中被替换的高级词汇/结构，以及简化后的对应\n'
              '   格式: ❌ 原文表达 → ✅ 简化表达 (原因)\n'
              '3. **语法简化说明**: 哪些复杂语法被简化了(从句→主句，被动→主动 等)\n'
              '4. **保留核心意思**: 确保主要信息不丢失\n\n'
              '用Markdown格式，德语加粗。';
          break;
        case 'elevate':
          prompt = '请将以下德语文本升维提升至 $_targetLevel 水平：\n\n$text\n\n'
              '要求：\n'
              '1. **升级版文本**: 用 $_targetLevel 级别的高级词汇和复杂语法改写\n'
              '2. **对照标注**: 列出被升级的表达\n'
              '   格式: 📝 原文表达 → ⬆️ 高级表达 (说明)\n'
              '3. **新增语法**: 引入了哪些高级语法(虚拟式、功能动词结构、扩展形容词等)\n'
              '4. **高级词汇表**: 列出升级版中使用的高级词汇及释义\n\n'
              '用Markdown格式，德语加粗。';
          break;
        default: // 'rewrite'
          prompt = '请用5种不同风格改写以下德语文本：\n\n$text\n\n'
              '1. **口语风格 (Umgangssprache)**: 日常聊天的表达\n'
              '2. **正式风格 (Formell)**: 书面/商务的表达\n'
              '3. **新闻风格 (Nachrichtenstil)**: 新闻报道的表达\n'
              '4. **文学风格 (Literarisch)**: 优美/文学的表达\n'
              '5. **学术风格 (Wissenschaftlich)**: 学术论文的表达\n\n'
              '每种风格给出改写后的文本和关键差异说明。用Markdown格式，德语加粗。';
      }

      final result = await service.chatRaw(
        prompt,
        systemMessage: '你是一位精通德语各级别教学的语言专家。'
            '改写要自然地道，符合目标级别的真实用语习惯。'
            '不要输出<think>标签。',
      );

      if (mounted) setState(() { _result = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _result = '改写失败: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('文本改写')),
      body: ResponsivePage(
        maxWidth: 900,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Style selector
            SegmentedButton<String>(
              segments: _styles.entries.map((e) =>
                ButtonSegment(value: e.key, label: Text(e.value)),
              ).toList(),
              selected: {_style},
              onSelectionChanged: (s) => setState(() => _style = s.first),
            ),
            const SizedBox(height: 12),

            // Level selector (for simplify/elevate)
            if (_style != 'rewrite')
              Row(
                children: [
                  Text('目标级别: ', style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 8),
                  SegmentedButton<String>(
                    segments: _levels.map((l) =>
                      ButtonSegment(value: l, label: Text(l)),
                    ).toList(),
                    selected: {_targetLevel},
                    onSelectionChanged: (s) => setState(() => _targetLevel = s.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),

            // Input
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: '粘贴德语文本…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _rewrite,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_fix_high, size: 18),
                    label: Text(_loading ? '改写中…' : 'AI 改写'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Result
            if (_result != null)
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: MarkdownBody(
                  data: _result!,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                    strong: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

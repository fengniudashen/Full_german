import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_page.dart';

/// German writing correction — user writes German text,
/// AI provides detailed corrections, scoring, and rewrite.
class WritingPage extends StatefulWidget {
  const WritingPage({super.key, this.initialText});
  final String? initialText;

  @override
  State<WritingPage> createState() => _WritingPageState();
}

class _WritingPageState extends State<WritingPage> {
  final TextEditingController _controller = TextEditingController();
  String? _correction;
  bool _loading = false;
  String _topic = '';

  static const _topics = [
    '自我介绍 (Selbstvorstellung)',
    '我的一天 (Mein Tag)',
    '我的爱好 (Meine Hobbys)',
    '德国旅行 (Reise nach Deutschland)',
    '我的家庭 (Meine Familie)',
    '健康饮食 (Gesunde Ernährung)',
    '我的工作 (Meine Arbeit)',
    '环境保护 (Umweltschutz)',
  ];

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

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() { _loading = true; _correction = null; });

    try {
      final provider = context.read<AppState>().settings.activeProvider;
      final service = AiService(provider: provider);
      final result = await service.correctWriting(text);
      if (mounted) setState(() { _correction = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _correction = '批改失败: $e'; _loading = false; });
    }
  }

  void _setTopic(String topic) {
    setState(() => _topic = topic);
    _controller.text = '';
    _correction = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('写作批改'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.topic),
            tooltip: '选择话题',
            onSelected: _setTopic,
            itemBuilder: (_) => _topics.map((t) =>
              PopupMenuItem(value: t, child: Text(t)),
            ).toList(),
          ),
        ],
      ),
      body: ResponsivePage(
        maxWidth: 900,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_topic.isNotEmpty) ...[
              Text('话题: $_topic',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 8),
            ],
            // Writing area
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('请用德语写一段话:',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    maxLines: 8,
                    decoration: InputDecoration(
                      hintText: '在这里输入你的德语作文…\n\n例如: Ich bin Student und lerne seit zwei Jahren Deutsch.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_controller.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} 词',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _loading ? null : _submit,
                        icon: _loading
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.rate_review, size: 18),
                        label: Text(_loading ? '批改中…' : '提交批改'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Correction result
            if (_correction != null)
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: scheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text('AI 批改结果',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: scheme.primary,
                              )),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Markdown(
                          data: _correction!,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                            p: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_document, size: 64,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text('写好德语后点击"提交批改"',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          )),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

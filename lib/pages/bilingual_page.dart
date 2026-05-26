import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/ai_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_page.dart';

/// AI bilingual side-by-side translation. Paste German or Chinese text,
/// get sentence-aligned parallel translation with grammar annotations.
class BilingualPage extends StatefulWidget {
  const BilingualPage({super.key, this.initialText});
  final String? initialText;

  @override
  State<BilingualPage> createState() => _BilingualPageState();
}

class _BilingualPageState extends State<BilingualPage> {
  final TextEditingController _controller = TextEditingController();
  List<_SentencePair>? _pairs;
  bool _loading = false;
  String? _error;
  String _direction = 'de2zh'; // 'de2zh', 'zh2de'

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

  Future<void> _translate() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() { _loading = true; _error = null; _pairs = null; });

    try {
      final provider = context.read<AppState>().settings.activeProvider;
      final service = AiService(provider: provider);

      final sourceLang = _direction == 'de2zh' ? '德语' : '中文';
      final targetLang = _direction == 'de2zh' ? '中文' : '德语';

      final result = await service.chatRaw(
        '请将以下${sourceLang}文本翻译成$targetLang，并按句对齐输出。\n\n'
        '原文:\n$text\n\n'
        '输出格式(严格遵守):\n'
        '每一对用 === 分隔，原文和译文之间用 ||| 分隔。\n'
        '例如:\n'
        '原句1 ||| 译句1\n'
        '===\n'
        '原句2 ||| 译句2\n'
        '===\n\n'
        '注意：\n'
        '- 按句子切分对齐\n'
        '- 翻译准确自然\n'
        '- 不要加其他内容，只输出句对',
        systemMessage: '你是一位专业的德中翻译。'
            '严格按照要求的格式输出句对。不要输出<think>标签。',
      );

      // Parse result
      final lines = result.split('===');
      final pairs = <_SentencePair>[];

      for (final block in lines) {
        final trimmed = block.trim();
        if (trimmed.isEmpty) continue;

        final parts = trimmed.split('|||');
        if (parts.length >= 2) {
          pairs.add(_SentencePair(
            source: parts[0].trim(),
            target: parts.sublist(1).join('|||').trim(),
          ));
        } else if (trimmed.isNotEmpty) {
          // Fallback: put the whole text as source
          pairs.add(_SentencePair(source: trimmed, target: ''));
        }
      }

      if (mounted) setState(() { _pairs = pairs; _loading = false; });
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
        title: const Text('双语对照'),
        actions: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'de2zh', label: Text('DE→中')),
              ButtonSegment(value: 'zh2de', label: Text('中→DE')),
            ],
            selected: {_direction},
            onSelectionChanged: (s) => setState(() => _direction = s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsivePage(
        maxWidth: 1000,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input area
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: _direction == 'de2zh'
                          ? '粘贴德语文本…'
                          : '粘贴中文文本…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _translate,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.translate, size: 18),
                    label: Text(_loading ? '翻译中…' : 'AI 对照翻译'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Error
            if (_error != null)
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: TextStyle(color: scheme.error)),
              ),

            // Bilingual pairs
            if (_pairs != null)
              ...List.generate(_pairs!.length, (i) {
                final pair = _pairs![i];
                return Padding(
                  padding: EdgeInsets.only(top: i > 0 ? 4 : 0),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Number
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Text('${i + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: scheme.onPrimaryContainer,
                                fontSize: 12,
                              )),
                        ),
                        const SizedBox(width: 12),
                        // Source & target
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                pair.source,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                              ),
                              if (pair.target.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                SelectableText(
                                  pair.target,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
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
}

class _SentencePair {
  final String source;
  final String target;
  const _SentencePair({required this.source, required this.target});
}

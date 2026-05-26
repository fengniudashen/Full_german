import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/ai_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_page.dart';

/// AI sentence generation practice — give AI a word/grammar rule,
/// it generates contextualized example sentences and exercises.
class SentenceGenPage extends StatefulWidget {
  const SentenceGenPage({super.key});

  @override
  State<SentenceGenPage> createState() => _SentenceGenPageState();
}

class _SentenceGenPageState extends State<SentenceGenPage> {
  final TextEditingController _controller = TextEditingController();
  String? _result;
  bool _loading = false;
  String _mode = 'word'; // 'word', 'grammar', 'topic'

  static const _modes = {
    'word': '单词造句',
    'grammar': '语法练习',
    'topic': '主题作文',
  };

  static const _examples = {
    'word': 'z.B. Entscheidung, trotzdem, beeindruckend',
    'grammar': 'z.B. Konjunktiv II, Passiv, Relativsätze',
    'topic': 'z.B. Umwelt, Technologie, Bildung',
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    setState(() { _loading = true; _result = null; });

    try {
      final provider = context.read<AppState>().settings.activeProvider;
      final service = AiService(provider: provider);

      String prompt;
      switch (_mode) {
        case 'grammar':
          prompt = '请围绕德语语法知识点 "$input" 生成练习内容：\n\n'
              '1. **语法规则说明** (简明扼要)\n'
              '2. **5个例句** (从简到难，每句附中文翻译)\n'
              '3. **3道练习题** (填空/选择/改错)，附答案\n'
              '4. **常见错误提醒**\n\n'
              '用Markdown格式，德语加粗。';
          break;
        case 'topic':
          prompt = '请围绕主题 "$input" 生成德语学习内容：\n\n'
              '1. **主题词汇表** (10个核心词汇+释义+例句)\n'
              '2. **范文** (150-200词，附中文翻译)\n'
              '3. **关键句型** (5个可复用的句型模板)\n'
              '4. **讨论问题** (3个德语讨论问题)\n\n'
              '用Markdown格式，德语加粗。';
          break;
        default: // 'word'
          prompt = '请围绕德语单词 "$input" 生成深度学习内容：\n\n'
              '1. **词汇卡片**: 词性、复数/变位、词根词源\n'
              '2. **5个例句** (从简单到复杂，每句附中文)\n'
              '3. **搭配用法**: 常见介词搭配、固定短语\n'
              '4. **同义词/反义词/派生词** 词汇网络\n'
              '5. **记忆技巧**: 联想记忆法或词根记忆\n'
              '6. **迷你测试**: 2道造句练习，附参考答案\n\n'
              '用Markdown格式，德语加粗。';
      }

      final result = await service.chatRaw(
        prompt,
        systemMessage: '你是一位富有创造力的德语教师。生成丰富、实用、有趣的学习内容。'
            '不要输出<think>标签。使用Markdown格式排版。',
      );

      if (mounted) setState(() { _result = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _result = '生成失败: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 造句练习')),
      body: ResponsivePage(
        maxWidth: 900,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode selector
            SegmentedButton<String>(
              segments: _modes.entries.map((e) =>
                ButtonSegment(value: e.key, label: Text(e.value)),
              ).toList(),
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 16),

            // Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: _examples[_mode],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _generate(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _loading ? null : _generate,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_loading ? '生成中' : 'AI 生成'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick word buttons
            if (_result == null && !_loading)
              _buildQuickButtons(theme, scheme),

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

  Widget _buildQuickButtons(ThemeData theme, ColorScheme scheme) {
    final suggestions = _mode == 'word'
        ? ['Entscheidung', 'trotzdem', 'Erfahrung', 'beeindruckend', 'Zusammenhang', 'allerdings']
        : _mode == 'grammar'
            ? ['Konjunktiv II', 'Passiv', 'Relativsätze', 'Adjektivdeklination', 'Präteritum', 'Infinitiv mit zu']
            : ['Umweltschutz', 'Digitalisierung', 'Gesundheit', 'Bildung', 'Arbeitswelt', 'Reisen'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: suggestions.map((s) => ActionChip(
        label: Text(s),
        onPressed: () {
          _controller.text = s;
          _generate();
        },
      )).toList(),
    );
  }
}

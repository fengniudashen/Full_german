import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/ai_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_page.dart';

/// AI text difficulty analyzer — paste any German text, get CEFR level
/// assessment, vocabulary analysis, and readability metrics.
class DifficultyPage extends StatefulWidget {
  const DifficultyPage({super.key, this.initialText});
  final String? initialText;

  @override
  State<DifficultyPage> createState() => _DifficultyPageState();
}

class _DifficultyPageState extends State<DifficultyPage> {
  final TextEditingController _controller = TextEditingController();
  String? _result;
  bool _loading = false;

  // Local analysis
  Map<String, dynamic>? _localStats;

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

  void _analyzeLocal(String text) {
    final words = text.split(RegExp(r'\s+'));
    final cleanWords = words
        .map((w) => w.replaceAll(RegExp(r'[^\w\u00C0-\u024FäöüÄÖÜß]'), ''))
        .where((w) => w.isNotEmpty)
        .toList();

    if (cleanWords.isEmpty) return;

    final avgLen = cleanWords.fold<int>(0, (s, w) => s + w.length) / cleanWords.length;
    final sentences = text.split(RegExp(r'[.!?]+')).where((s) => s.trim().isNotEmpty).length;
    final avgWordsPerSentence = sentences > 0 ? cleanWords.length / sentences : cleanWords.length;
    final unique = cleanWords.map((w) => w.toLowerCase()).toSet().length;
    final lexicalDiversity = unique / cleanWords.length;

    // Count complex indicators
    final longWords = cleanWords.where((w) => w.length >= 10).length;
    final compoundIndicator = cleanWords.where((w) => w.length >= 15).length;

    setState(() {
      _localStats = {
        'words': cleanWords.length,
        'sentences': sentences,
        'unique': unique,
        'avgWordLen': avgLen,
        'avgSentLen': avgWordsPerSentence,
        'lexDiv': lexicalDiversity,
        'longWords': longWords,
        'compounds': compoundIndicator,
      };
    });
  }

  Future<void> _analyzeAI() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _analyzeLocal(text);
    setState(() { _loading = true; _result = null; });

    try {
      final provider = context.read<AppState>().settings.activeProvider;
      final service = AiService(provider: provider);

      final result = await service.chatRaw(
        '请分析以下德语文本的难度：\n\n$text\n\n'
        '请提供：\n'
        '1. **CEFR等级评估** (A1/A2/B1/B2/C1/C2) 及理由\n'
        '2. **词汇分析**: 标出超出该等级的高级词汇(列出5-10个)\n'
        '3. **语法复杂度**: 涉及的语法现象(从句、被动语态、虚拟式等)\n'
        '4. **可读性评价**: 总体难度和适合的学习者\n'
        '5. **学习建议**: 如何利用这篇文本学习\n\n'
        '用中文回答，德语词汇保持原文。',
        systemMessage: '你是一位德语教学评估专家，精通CEFR标准。'
            '不要输出<think>标签，直接给出分析。使用Markdown格式。',
      );

      if (mounted) setState(() { _result = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _result = '分析失败: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('文本难度分析')),
      body: ResponsivePage(
        maxWidth: 900,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controller,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: '粘贴任意德语文本…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _analyzeAI,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.analytics, size: 18),
                    label: Text(_loading ? '分析中…' : 'AI 分析难度'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Local stats
            if (_localStats != null) _buildLocalStats(theme, scheme),

            // AI result
            if (_result != null) ...[
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: MarkdownBody(
                  data: _result!,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocalStats(ThemeData theme, ColorScheme scheme) {
    final s = _localStats!;
    final stats = <Widget>[
      _MiniStat('词数', '${s['words']}', Colors.blue),
      _MiniStat('句数', '${s['sentences']}', Colors.green),
      _MiniStat('独立词', '${s['unique']}', Colors.orange),
      _MiniStat('词长', (s['avgWordLen'] as double).toStringAsFixed(1), Colors.purple),
      _MiniStat('句长', (s['avgSentLen'] as double).toStringAsFixed(1), Colors.red),
      _MiniStat('词多样性', '${((s['lexDiv'] as double) * 100).toInt()}%', Colors.teal),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: stats.map((w) => SizedBox(width: 120, child: w)).toList(),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 16)),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

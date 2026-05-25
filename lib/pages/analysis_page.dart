import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

/// AI-powered sentence analysis page.
/// Provides: word lookup, grammar analysis, translation, phrase analysis.
class AnalysisPage extends StatefulWidget {
  const AnalysisPage({
    super.key,
    this.initialSentence,
    this.initialWord,
  });
  final String? initialSentence;
  final String? initialWord;

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String _result = '';
  bool _loading = false;
  _AnalysisMode _mode = _AnalysisMode.grammar;
  String _sentenceCtx = '';

  @override
  void initState() {
    super.initState();
    _inputCtrl.addListener(() => setState(() {}));
    if (widget.initialSentence != null) {
      _inputCtrl.text = widget.initialSentence!;
      _sentenceCtx = widget.initialSentence!;
    }
    // Auto-run analysis only if a specific word was tapped
    if (widget.initialWord != null && widget.initialSentence != null) {
      _mode = _AnalysisMode.word;
      _inputCtrl.text = widget.initialWord!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  AiService _getService() {
    final provider = context.read<AppState>().settings.activeProvider;
    return AiService(provider: provider);
  }

  Future<void> _run() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _loading = true;
      _result = '';
    });

    // Track sentence context for word lookup
    if (_mode != _AnalysisMode.word) {
      _sentenceCtx = text;
    }

    final service = _getService();
    String result;

    switch (_mode) {
      case _AnalysisMode.word:
        result = await service.lookupWord(
          text,
          _sentenceCtx.isNotEmpty ? _sentenceCtx : text,
        );
      case _AnalysisMode.grammar:
        result = await service.analyzeGrammar(text);
      case _AnalysisMode.translate:
        result = await service.translate(text);
      case _AnalysisMode.phrase:
        result = await service.analyzePhrase(text, _sentenceCtx.isNotEmpty ? _sentenceCtx : null);
      case _AnalysisMode.pronunciation:
        result = await service.speakingCoach(text);
      case _AnalysisMode.ask:
        result = await service.ask(text);
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = result;
    });

    // Scroll to result
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Consumer<AppState>(
          builder: (_, state, __) {
            final p = state.settings.activeProvider;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('AI 德语助手'),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    p.name.split(' ').first,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置 API Key',
            onPressed: () => _showApiKeyDialog(context),
          ),
        ],
      ),
      body: ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16),
        children: [
          // Mode selector
          GlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('分析模式',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _AnalysisMode.values.map((mode) {
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(mode.icon, size: 16),
                          const SizedBox(width: 4),
                          Text(mode.label),
                        ],
                      ),
                      selected: _mode == mode,
                      onSelected: (_) => setState(() => _mode = mode),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Input
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _inputCtrl,
                  minLines: 2,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: _mode.inputLabel,
                    hintText: _mode.inputHint,
                    alignLabelWithHint: true,
                  ),
                ),
                // Interactive word chips — click a word to look it up
                if (_inputCtrl.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('点击词汇快速查询：',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      )),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _inputCtrl.text
                        .trim()
                        .split(RegExp(r'\s+'))
                        .where((w) => w.isNotEmpty)
                        .map((word) {
                      final cleanWord =
                          word.replaceAll(RegExp(r'[.,;:!?"""()–—]'), '').trim();
                      return Material(
                        color: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: cleanWord.isEmpty
                              ? null
                              : () {
                                  final fullSentence = _inputCtrl.text.trim();
                                  setState(() {
                                    _sentenceCtx = fullSentence;
                                    _mode = _AnalysisMode.word;
                                    _result = '';
                                  });
                                  _inputCtrl.text = cleanWord;
                                  _run();
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            child: Text(
                              word,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _loading ? null : _run,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_loading ? '分析中…' : '开始分析'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),

          // Result
          if (_result.isNotEmpty) ...[
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('AI 分析结果',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          )),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: '复制结果',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _result));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制到剪贴板')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  MarkdownBody(
                    data: _result,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(
                      Theme.of(context),
                    ).copyWith(
                      p: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                      listBullet: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _showApiKeyDialog(BuildContext context) async {
    final appState = context.read<AppState>();
    final provider = appState.settings.activeProvider;
    final ctrl = TextEditingController(text: provider.apiKey);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${provider.name} API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前模型: ${provider.name} (${provider.model})'),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'sk-...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '可在设置页面切换 AI 模型和管理所有 API Key',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await appState.updateProviderKey(
                  provider.id, ctrl.text.trim());
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }
}

enum _AnalysisMode {
  word(Icons.translate, '查词', '输入要查询的德语单词', '例如: Hyperschallrakete'),
  grammar(Icons.schema_outlined, '语法', '输入要分析语法的德语句子', '输入完整的德语句子…'),
  translate(Icons.g_translate, '翻译', '输入要翻译的德语文本', '输入德语句子或段落…'),
  phrase(Icons.short_text, '片段', '输入要解析的德语片段', '例如: in Kürze bekannt gegeben'),
  pronunciation(Icons.record_voice_over, '口语教练', '输入要练习朗读的德语句子', '输入完整的德语句子…'),
  ask(Icons.question_answer, '提问', '输入你的德语学习问题', '例如: 德语第二格有哪些用法？');

  const _AnalysisMode(this.icon, this.label, this.inputLabel, this.inputHint);
  final IconData icon;
  final String label;
  final String inputLabel;
  final String inputHint;
}

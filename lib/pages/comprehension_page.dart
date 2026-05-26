import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

/// Listening comprehension quiz — AI generates questions about the
/// listened/dictated text, user answers to test understanding.
class ComprehensionPage extends StatefulWidget {
  const ComprehensionPage({
    super.key,
    required this.sentences,
    required this.projectName,
  });

  final List<String> sentences;
  final String projectName;

  @override
  State<ComprehensionPage> createState() => _ComprehensionPageState();
}

class _ComprehensionPageState extends State<ComprehensionPage> {
  List<_Question>? _questions;
  bool _loading = false;
  String? _error;
  int _answered = 0;
  int _correct = 0;

  @override
  void initState() {
    super.initState();
    _generateQuestions();
  }

  Future<void> _generateQuestions() async {
    setState(() { _loading = true; _error = null; });

    try {
      final provider = context.read<AppState>().settings.activeProvider;
      final service = AiService(provider: provider);
      final fullText = widget.sentences.join(' ');

      final result = await service.chatRaw(
        '以下是一段德语文本：\n\n$fullText\n\n'
        '请根据这段文本生成5道选择题来测试理解能力。\n\n'
        '严格按照以下JSON格式输出，不要输出其他内容：\n'
        '```json\n'
        '[\n'
        '  {"q": "问题（用中文）", "options": ["A选项", "B选项", "C选项", "D选项"], "answer": 0, "explanation": "解释（用中文）"},\n'
        '  ...\n'
        ']\n'
        '```\n'
        'answer 是正确选项的索引(0-3)。选项用中文。',
        systemMessage: '你是一位德语考试出题专家。请严格按JSON格式输出，不要输出```json标记之外的任何文字。',
      );

      if (!mounted) return;

      // Parse JSON from the response
      final jsonStr = _extractJson(result);
      if (jsonStr == null) {
        setState(() { _loading = false; _error = '无法解析题目，请重试'; });
        return;
      }

      // Manually parse the JSON since we can't import dart:convert in the page
      // Actually we can, let's do it properly
      final questions = _parseQuestions(jsonStr);
      setState(() {
        _questions = questions;
        _loading = false;
        _answered = 0;
        _correct = 0;
      });
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _error = '生成题目失败: $e'; });
      }
    }
  }

  String? _extractJson(String text) {
    // Try to extract JSON array from response
    final match = RegExp(r'\[[\s\S]*\]').firstMatch(text);
    return match?.group(0);
  }

  List<_Question> _parseQuestions(String jsonStr) {
    // Simple manual JSON parsing for the specific format
    final questions = <_Question>[];
    try {
      // Use a basic approach: find each question object
      final matches = RegExp(r'\{[^{}]+\}').allMatches(jsonStr);
      for (final m in matches) {
        final obj = m.group(0)!;
        final q = RegExp(r'"q"\s*:\s*"([^"]*)"').firstMatch(obj)?.group(1) ?? '';
        final answerMatch = RegExp(r'"answer"\s*:\s*(\d)').firstMatch(obj);
        final answer = int.tryParse(answerMatch?.group(1) ?? '0') ?? 0;
        final explanation = RegExp(r'"explanation"\s*:\s*"([^"]*)"').firstMatch(obj)?.group(1) ?? '';

        // Extract options array
        final optionsMatch = RegExp(r'"options"\s*:\s*\[(.*?)\]').firstMatch(obj);
        final options = <String>[];
        if (optionsMatch != null) {
          final optStr = optionsMatch.group(1)!;
          final optMatches = RegExp(r'"([^"]*)"').allMatches(optStr);
          for (final om in optMatches) {
            options.add(om.group(1)!);
          }
        }

        if (q.isNotEmpty && options.length >= 2) {
          questions.add(_Question(
            question: q,
            options: options,
            correctIndex: answer.clamp(0, options.length - 1),
            explanation: explanation,
          ));
        }
      }
    } catch (_) {}
    return questions;
  }

  void _selectAnswer(int questionIndex, int optionIndex) {
    if (_questions == null) return;
    final q = _questions![questionIndex];
    if (q.selectedIndex != null) return; // Already answered

    setState(() {
      q.selectedIndex = optionIndex;
      _answered++;
      if (optionIndex == q.correctIndex) _correct++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('听力理解测验'),
        actions: [
          if (_questions != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '$_correct / $_answered',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('AI 正在出题…'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: TextStyle(color: scheme.error)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _generateQuestions,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _questions == null || _questions!.isEmpty
                  ? const Center(child: Text('没有生成题目'))
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Summary when all answered
                        if (_answered == _questions!.length)
                          _buildSummary(theme, scheme),
                        ...List.generate(_questions!.length, (i) {
                          return _buildQuestion(i, theme, scheme);
                        }),
                        if (_answered == _questions!.length) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _generateQuestions,
                            icon: const Icon(Icons.refresh),
                            label: const Text('再出一套题'),
                          ),
                        ],
                      ],
                    ),
    );
  }

  Widget _buildSummary(ThemeData theme, ColorScheme scheme) {
    final pct = _questions!.isEmpty ? 0 : _correct / _questions!.length;
    final grade = pct >= 0.9
        ? 'A'
        : pct >= 0.8
            ? 'B'
            : pct >= 0.6
                ? 'C'
                : 'D';
    final emoji = pct >= 0.8 ? '🎉' : pct >= 0.6 ? '👍' : '💪';

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            '$emoji 得分: $_correct / ${_questions!.length}  ($grade)',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: pct >= 0.6 ? Colors.green : scheme.error,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: pct.toDouble(),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: pct >= 0.8 ? Colors.green : pct >= 0.6 ? Colors.orange : scheme.error,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(int index, ThemeData theme, ColorScheme scheme) {
    final q = _questions![index];
    final answered = q.selectedIndex != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}. ${q.question}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(q.options.length, (oi) {
              final isSelected = q.selectedIndex == oi;
              final isCorrect = q.correctIndex == oi;
              Color? bg;
              Color? border;

              if (answered) {
                if (isCorrect) {
                  bg = Colors.green.withValues(alpha: 0.15);
                  border = Colors.green;
                } else if (isSelected && !isCorrect) {
                  bg = scheme.error.withValues(alpha: 0.15);
                  border = scheme.error;
                }
              } else if (isSelected) {
                bg = scheme.primaryContainer;
                border = scheme.primary;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: answered ? null : () => _selectAnswer(index, oi),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: bg ?? scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: border ?? scheme.outlineVariant,
                        width: (isSelected || (answered && isCorrect)) ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          String.fromCharCode(65 + oi), // A, B, C, D
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: border ?? scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(q.options[oi],
                              style: theme.textTheme.bodyMedium),
                        ),
                        if (answered && isCorrect)
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 20),
                        if (answered && isSelected && !isCorrect)
                          Icon(Icons.cancel,
                              color: scheme.error, size: 20),
                      ],
                    ),
                  ),
                ),
              );
            }),
            if (answered && q.explanation.isNotEmpty) ...[
              const Divider(),
              Text(
                '💡 ${q.explanation}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Question {
  _Question({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  int? selectedIndex;
}

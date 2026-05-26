import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

/// Cloze (fill-in-the-blank) exercise from existing project sentences.
/// Randomly blanks out words for the user to fill in.
class ClozePage extends StatefulWidget {
  const ClozePage({
    super.key,
    required this.projectId,
    required this.sentences,
  });

  final int projectId;
  final List<String> sentences;

  @override
  State<ClozePage> createState() => _ClozePageState();
}

class _ClozePageState extends State<ClozePage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final Random _rng = Random();

  late List<int> _order;
  int _current = 0;

  // Current exercise state
  String _original = '';
  String _display = ''; // sentence with blanks
  List<_Blank> _blanks = [];
  int _activeBlanks = 0;
  bool _revealed = false;

  // Stats
  int _correct = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _order = List.generate(widget.sentences.length, (i) => i)..shuffle(_rng);
    _generateExercise();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _generateExercise() {
    final sentence = widget.sentences[_order[_current % _order.length]];
    _original = sentence;

    // Split into words, pick 1-3 words to blank out
    final words = sentence.split(RegExp(r'\s+'));
    final blankCount = (words.length > 6 ? 2 + _rng.nextInt(2) : 1)
        .clamp(1, words.length);

    // Pick random indices (avoid very short words like ".", ",")
    final candidates = <int>[];
    for (int i = 0; i < words.length; i++) {
      if (words[i].replaceAll(RegExp(r'[^\w\u00C0-\u024F]'), '').length >= 2) {
        candidates.add(i);
      }
    }
    if (candidates.isEmpty) candidates.addAll(List.generate(words.length, (i) => i));
    candidates.shuffle(_rng);
    final selected = candidates.take(blankCount).toList()..sort();

    _blanks = [];
    final displayWords = List<String>.from(words);
    for (final idx in selected) {
      final word = words[idx];
      // Extract core word (strip trailing punctuation for comparison)
      final core = word.replaceAll(RegExp(r'[^\w\u00C0-\u024F]$'), '');
      final suffix = word.substring(core.length);
      _blanks.add(_Blank(index: idx, answer: core, suffix: suffix));
      displayWords[idx] = '_____$suffix';
    }

    _display = displayWords.join(' ');
    _activeBlanks = 0;
    _revealed = false;
    _controller.clear();

    setState(() {});
    _focusNode.requestFocus();
  }

  void _checkAnswer() {
    if (_revealed || _activeBlanks >= _blanks.length) return;
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    final blank = _blanks[_activeBlanks];
    final isCorrect = input.toLowerCase() == blank.answer.toLowerCase();

    setState(() {
      blank.userAnswer = input;
      blank.isCorrect = isCorrect;
      _activeBlanks++;
      _total++;
      if (isCorrect) _correct++;
      _controller.clear();
    });

    if (_activeBlanks >= _blanks.length) {
      setState(() => _revealed = true);
    } else {
      _focusNode.requestFocus();
    }
  }

  void _next() {
    _current++;
    _generateExercise();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('完形填空'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '$_correct / $_total',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress
            LinearProgressIndicator(
              value: _order.isEmpty ? 0 : _current / _order.length,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 8),
            Text(
              '第 ${_current + 1} / ${_order.length} 题',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Sentence card
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: _buildSentence(theme, scheme),
            ),
            const SizedBox(height: 24),

            // Input or results
            if (!_revealed) ...[
              Text(
                '填写第 ${_activeBlanks + 1} 个空 (共 ${_blanks.length} 个):',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: '输入德语单词…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _checkAnswer(),
                      autofocus: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _checkAnswer,
                    child: const Text('确认'),
                  ),
                ],
              ),
            ] else ...[
              // Show results
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('完整句子:', style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    SelectableText(
                      _original,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._blanks.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            b.isCorrect ? Icons.check_circle : Icons.cancel,
                            size: 18,
                            color: b.isCorrect ? Colors.green : scheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            b.isCorrect
                                ? '${b.answer} ✓'
                                : '${b.userAnswer} → ${b.answer}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: b.isCorrect ? Colors.green : scheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _next,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('下一题'),
              ),
            ],

            const Spacer(),

            // Accuracy summary
            if (_total > 0)
              Center(
                child: Text(
                  '正确率: ${(_correct / _total * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: _correct / _total >= 0.8 ? Colors.green : scheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentence(ThemeData theme, ColorScheme scheme) {
    // Build rich text with highlighted blanks
    final words = _display.split(RegExp(r'\s+'));
    final spans = <InlineSpan>[];

    int blankIdx = 0;
    for (int i = 0; i < words.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: ' '));

      final isBlank = _blanks.any((b) => b.index == i);
      if (isBlank && blankIdx < _blanks.length) {
        final blank = _blanks[blankIdx];
        if (blankIdx < _activeBlanks) {
          // Already answered
          spans.add(TextSpan(
            text: '${blank.userAnswer}${blank.suffix}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: blank.isCorrect ? Colors.green : scheme.error,
              decoration: blank.isCorrect ? null : TextDecoration.lineThrough,
            ),
          ));
        } else if (blankIdx == _activeBlanks && !_revealed) {
          // Current blank
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Container(
              width: 80,
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ));
          if (blank.suffix.isNotEmpty) {
            spans.add(TextSpan(text: blank.suffix));
          }
        } else {
          // Future blank
          spans.add(TextSpan(
            text: '_____${blank.suffix}',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              letterSpacing: 2,
            ),
          ));
        }
        blankIdx++;
      } else {
        spans.add(TextSpan(text: words[i]));
      }
    }

    return Text.rich(
      TextSpan(
        style: theme.textTheme.headlineSmall?.copyWith(
          height: 1.8,
          fontWeight: FontWeight.w500,
        ),
        children: spans,
      ),
    );
  }
}

class _Blank {
  _Blank({required this.index, required this.answer, this.suffix = ''});
  final int index;
  final String answer;
  final String suffix;
  String? userAnswer;
  bool isCorrect = false;
}

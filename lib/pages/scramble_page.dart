import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

/// Sentence scramble exercise — rearrange shuffled words to form
/// the correct German sentence. Trains word order & grammar intuition.
class ScramblePage extends StatefulWidget {
  const ScramblePage({
    super.key,
    required this.projectId,
    required this.sentences,
  });

  final int projectId;
  final List<String> sentences;

  @override
  State<ScramblePage> createState() => _ScramblePageState();
}

class _ScramblePageState extends State<ScramblePage> {
  final Random _rng = Random();
  late List<int> _order;
  int _current = 0;
  int _correct = 0;
  int _total = 0;

  String _original = '';
  List<String> _words = [];
  List<String> _shuffled = [];
  List<String> _placed = [];
  bool _revealed = false;
  bool? _isCorrect;

  @override
  void initState() {
    super.initState();
    _order = List.generate(widget.sentences.length, (i) => i)..shuffle(_rng);
    _generateExercise();
  }

  void _generateExercise() {
    _original = widget.sentences[_order[_current % _order.length]];
    _words = _original.split(RegExp(r'\s+'));
    _shuffled = List<String>.from(_words)..shuffle(_rng);
    // Ensure shuffled != original (if possible)
    if (_words.length > 2) {
      int attempts = 0;
      while (_shuffled.join(' ') == _words.join(' ') && attempts < 10) {
        _shuffled.shuffle(_rng);
        attempts++;
      }
    }
    _placed = [];
    _revealed = false;
    _isCorrect = null;
    setState(() {});
  }

  void _tapWord(int index) {
    if (_revealed) return;
    setState(() {
      _placed.add(_shuffled[index]);
      _shuffled = List<String>.from(_shuffled)..removeAt(index);
    });

    // Auto-check when all words placed
    if (_shuffled.isEmpty) {
      _check();
    }
  }

  void _removePlaced(int index) {
    if (_revealed) return;
    setState(() {
      _shuffled.add(_placed[index]);
      _placed = List<String>.from(_placed)..removeAt(index);
    });
  }

  void _check() {
    final answer = _placed.join(' ');
    final correct = _words.join(' ');
    setState(() {
      _total++;
      _isCorrect = answer == correct;
      if (_isCorrect!) _correct++;
      _revealed = true;
    });
  }

  void _next() {
    _current++;
    _generateExercise();
  }

  void _reset() {
    _generateExercise();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('句子排序'),
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
              '第 ${_current + 1} / ${_order.length} 题  ·  将打乱的单词排成正确的句子',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Placed words area (answer)
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 80),
                child: _placed.isEmpty
                    ? Center(
                        child: Text('点击下方单词排列句子',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                            )),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_placed.length, (i) {
                          Color? bg;
                          if (_revealed && _isCorrect == false) {
                            bg = _placed[i] == _words[i]
                                ? Colors.green.withValues(alpha: 0.2)
                                : scheme.error.withValues(alpha: 0.2);
                          }
                          return _WordChip(
                            word: _placed[i],
                            onTap: _revealed ? null : () => _removePlaced(i),
                            backgroundColor: bg,
                            border: _revealed
                                ? (_placed[i] == _words[i]
                                    ? Colors.green
                                    : scheme.error)
                                : scheme.primary,
                          );
                        }),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Available words
            if (!_revealed && _shuffled.isNotEmpty) ...[
              Text('可用单词:',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_shuffled.length, (i) {
                  return _WordChip(
                    word: _shuffled[i],
                    onTap: () => _tapWord(i),
                    backgroundColor: scheme.surfaceContainerHighest,
                    border: scheme.outlineVariant,
                  );
                }),
              ),
            ],

            const SizedBox(height: 24),

            // Results
            if (_revealed) ...[
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isCorrect! ? Icons.check_circle : Icons.cancel,
                          color: _isCorrect! ? Colors.green : scheme.error,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isCorrect! ? '完全正确！' : '顺序有误',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: _isCorrect! ? Colors.green : scheme.error,
                          ),
                        ),
                      ],
                    ),
                    if (!_isCorrect!) ...[
                      const SizedBox(height: 12),
                      Text('正确答案:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          )),
                      const SizedBox(height: 4),
                      SelectableText(
                        _original,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (!_isCorrect!)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('重试'),
                      ),
                    ),
                  if (!_isCorrect!) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _next,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('下一题'),
                    ),
                  ),
                ],
              ),
            ] else if (_placed.isNotEmpty && _shuffled.isNotEmpty) ...[
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重置'),
              ),
            ],

            const Spacer(),
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
}

class _WordChip extends StatelessWidget {
  const _WordChip({
    required this.word,
    this.onTap,
    this.backgroundColor,
    this.border,
  });

  final String word;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border ?? Colors.grey, width: 1.5),
          ),
          child: Text(
            word,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

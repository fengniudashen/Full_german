import 'package:flutter/material.dart';

import '../models/study_sentence.dart';
import '../models/word_comparison.dart';
import '../services/dictionary_service.dart';

class ComparisonResultSheet extends StatefulWidget {
  const ComparisonResultSheet({
    super.key,
    required this.sentence,
    required this.result,
    required this.onSaveNote,
  });

  final StudySentence sentence;
  final ComparisonResult result;
  final Future<void> Function(String note) onSaveNote;

  @override
  State<ComparisonResultSheet> createState() => _ComparisonResultSheetState();
}

class _ComparisonResultSheetState extends State<ComparisonResultSheet> {
  final DictionaryService _dictionaryService = DictionaryService();
  late final TextEditingController _noteController;
  bool _savingNote = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.sentence.note);
  }

  @override
  void dispose() {
    _dictionaryService.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('校对与精析', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SummaryChip(
                    label: '正确 ${widget.result.correctCount}',
                    color: Colors.green,
                  ),
                  _SummaryChip(
                    label: '轻微 ${widget.result.minorCount}',
                    color: Colors.amber,
                  ),
                  _SummaryChip(
                    label: '错误 ${widget.result.wrongCount}',
                    color: Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('原文', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(widget.sentence.text),
              const SizedBox(height: 18),
              Text('逐词对比', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.result.items
                    .map((item) => _ComparisonToken(
                          item: item,
                          onTap: item.original.isEmpty
                              ? null
                              : () => _showDictionary(item.original),
                        ))
                    .toList(growable: false),
              ),
              const SizedBox(height: 24),
              Text('语法笔记', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: '记录冠词、格、动词变位或固定搭配...',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _savingNote ? null : _saveNote,
                icon: _savingNote
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('保存笔记'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveNote() async {
    setState(() => _savingNote = true);
    try {
      await widget.onSaveNote(_noteController.text.trim());
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('笔记已保存')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingNote = false);
      }
    }
  }

  Future<void> _showDictionary(String word) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final entry = await _dictionaryService.lookup(word);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(entry.word.isEmpty ? '词典' : entry.word),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('来源：${entry.source}'),
              const SizedBox(height: 12),
              ...entry.definitions.map(
                (definition) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• $definition'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 5),
      label: Text(label),
    );
  }
}

class _ComparisonToken extends StatelessWidget {
  const _ComparisonToken({required this.item, required this.onTap});

  final WordComparison item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(context, item.status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          item.displayText,
          style: TextStyle(color: colors.foreground, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  _TokenColors _colorsFor(BuildContext context, ComparisonStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (status) {
      ComparisonStatus.correct => const _TokenColors(
          background: Color(0xFFE8F5E9),
          border: Color(0xFF81C784),
          foreground: Color(0xFF1B5E20),
        ),
      ComparisonStatus.minor => const _TokenColors(
          background: Color(0xFFFFF8E1),
          border: Color(0xFFFFCA28),
          foreground: Color(0xFF6D4C00),
        ),
      ComparisonStatus.wrong => _TokenColors(
          background: const Color(0xFFFFEBEE),
          border: const Color(0xFFE57373),
          foreground: colorScheme.error,
        ),
    };
  }
}

class _TokenColors {
  const _TokenColors({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

import 'package:flutter/material.dart';

import '../models/study_sentence.dart';
import '../models/word_comparison.dart';
import '../services/dictionary_service.dart';
import '../theme/app_theme.dart';
import '../widgets/accuracy_ring.dart';

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
  final DictionaryService _dict = DictionaryService();
  late final TextEditingController _noteCtrl;
  bool _savingNote = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.sentence.note);
  }

  @override
  void dispose() {
    _dict.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),

              // ── Header with accuracy ring ──
              Row(
                children: [
                  AccuracyRing(value: widget.result.accuracy, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('校对与精析',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _StatChip('正确 ${widget.result.correctCount}',
                                isDark ? AppTheme.correctFgDark : AppTheme.correctFg,
                                isDark ? AppTheme.correctBgDark : AppTheme.correctBg),
                            _StatChip('轻微 ${widget.result.minorCount}',
                                isDark ? AppTheme.minorFgDark : AppTheme.minorFg,
                                isDark ? AppTheme.minorBgDark : AppTheme.minorBg),
                            _StatChip('错误 ${widget.result.wrongCount}',
                                isDark ? AppTheme.wrongFgDark : AppTheme.wrongFg,
                                isDark ? AppTheme.wrongBgDark : AppTheme.wrongBg),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Original text ──
              _SectionTitle('原文', Icons.text_snippet_outlined),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: AppTheme.borderMd,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: SelectableText(
                  widget.sentence.text,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
              ),

              const SizedBox(height: 24),

              // ── Word-by-word comparison ──
              _SectionTitle('逐词对比', Icons.compare_arrows),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.result.items
                    .map((item) => _ComparisonToken(
                          item: item,
                          onTap: item.original.isEmpty
                              ? null
                              : () => _showDictionary(item.original),
                        ))
                    .toList(growable: false),
              ),

              const SizedBox(height: 28),

              // ── Grammar notes ──
              _SectionTitle('语法笔记', Icons.edit_note),
              const SizedBox(height: 8),
              TextField(
                controller: _noteCtrl,
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
      await widget.onSaveNote(_noteCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('笔记已保存')),
      );
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  Future<void> _showDictionary(String word) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final entry = await _dict.lookup(word);
    if (!mounted) return;
    Navigator.of(context).pop();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.menu_book, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(entry.word.isEmpty ? '词典' : entry.word),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.phonetic.isNotEmpty) ...[
                Text(entry.phonetic,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
              ],
              Text('来源：${entry.source}',
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              ...entry.definitions.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: theme.colorScheme.primary)),
                        Expanded(child: Text(d)),
                      ],
                    ),
                  )),
              if (entry.examples.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('例句', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                ...entry.examples.map((ex) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('→ $ex',
                          style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurfaceVariant)),
                    )),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.icon);
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(title, style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
        )),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.label, this.fg, this.bg);
  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppTheme.borderSm,
      ),
      child: Text(label,
          style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _ComparisonToken extends StatelessWidget {
  const _ComparisonToken({required this.item, required this.onTap});
  final WordComparison item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _colorsFor(item.status, isDark);
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderSm,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.$1,
          borderRadius: AppTheme.borderSm,
          border: Border.all(color: colors.$2),
        ),
        child: Text(
          item.displayText,
          style: TextStyle(color: colors.$3, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  (Color bg, Color border, Color fg) _colorsFor(ComparisonStatus status, bool isDark) {
    return switch (status) {
      ComparisonStatus.correct => isDark
          ? (AppTheme.correctBgDark, AppTheme.correctBorderDark, AppTheme.correctFgDark)
          : (AppTheme.correctBg, AppTheme.correctBorder, AppTheme.correctFg),
      ComparisonStatus.minor => isDark
          ? (AppTheme.minorBgDark, AppTheme.minorBorderDark, AppTheme.minorFgDark)
          : (AppTheme.minorBg, AppTheme.minorBorder, AppTheme.minorFg),
      ComparisonStatus.wrong => isDark
          ? (AppTheme.wrongBgDark, AppTheme.wrongBorderDark, AppTheme.wrongFgDark)
          : (AppTheme.wrongBg, AppTheme.wrongBorder, AppTheme.wrongFg),
    };
  }
}

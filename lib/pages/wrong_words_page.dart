import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/wrong_word.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_card.dart';

class WrongWordsPage extends StatefulWidget {
  const WrongWordsPage({super.key});

  @override
  State<WrongWordsPage> createState() => _WrongWordsPageState();
}

class _WrongWordsPageState extends State<WrongWordsPage> {
  int? _filterProjectId;
  bool? _filterMastered;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return RefreshIndicator(
          onRefresh: () => appState.loadWrongWords(
            projectId: _filterProjectId,
            mastered: _filterMastered,
          ),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _buildToolbar(context, appState),
                ),
              ),
              if (appState.wrongWords.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.spellcheck_outlined,
                    title: '暂无错词',
                    message: '听写核对后，红色错误会自动加入这里。\n掌握的词会被标记，帮你聚焦薄弱点。',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index.isOdd) return const SizedBox(height: 8);
                        return _WrongWordTile(
                          word: appState.wrongWords[index ~/ 2],
                        );
                      },
                      childCount: appState.wrongWords.length * 2 - 1,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context, AppState appState) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Project filter
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<int?>(
              value: _filterProjectId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '项目',
                prefixIcon: Icon(Icons.folder_outlined, size: 18),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('全部项目')),
                ...appState.projects.map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name,
                          overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: (v) {
                setState(() => _filterProjectId = v);
                appState.loadWrongWords(
                    projectId: v, mastered: _filterMastered);
              },
            ),
          ),

          // Mastered filter
          ChoiceChip(
            label: const Text('未掌握'),
            selected: _filterMastered == false,
            onSelected: (selected) {
              setState(() =>
                  _filterMastered = selected ? false : null);
              appState.loadWrongWords(
                  projectId: _filterProjectId,
                  mastered: _filterMastered);
            },
          ),
          ChoiceChip(
            label: const Text('已掌握'),
            selected: _filterMastered == true,
            onSelected: (selected) {
              setState(() =>
                  _filterMastered = selected ? true : null);
              appState.loadWrongWords(
                  projectId: _filterProjectId,
                  mastered: _filterMastered);
            },
          ),

          // Stats
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: AppTheme.borderSm,
            ),
            child: Text(
              '${appState.wrongWords.length} 条记录',
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),

          // Export
          FilledButton.icon(
            onPressed: _exporting ? null : _exportCsv,
            icon: _exporting
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share, size: 18),
            label: const Text('导出 CSV'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final file = await context
          .read<AppState>()
          .exportWrongWordsCsv(projectId: _filterProjectId);

      // Let user choose save location
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '导出错词本 CSV',
        fileName: 'deutschflow_wrong_words.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (outputPath != null) {
        await File(file.path).copy(outputPath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已导出到: $outputPath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _WrongWordTile extends StatelessWidget {
  const _WrongWordTile({required this.word});
  final WrongWord word;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Wrong form
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.wrongBgDark : AppTheme.wrongBg,
                  borderRadius: AppTheme.borderSm,
                  border: Border.all(
                    color: isDark
                        ? AppTheme.wrongBorderDark
                        : AppTheme.wrongBorder,
                  ),
                ),
                child: Text(word.wrongForm,
                    style: TextStyle(
                      color: isDark ? AppTheme.wrongFgDark : AppTheme.wrongFg,
                      fontWeight: FontWeight.w700,
                    )),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 16),
              ),
              // Correct form
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.correctBgDark
                      : AppTheme.correctBg,
                  borderRadius: AppTheme.borderSm,
                  border: Border.all(
                    color: isDark
                        ? AppTheme.correctBorderDark
                        : AppTheme.correctBorder,
                  ),
                ),
                child: Text(word.correctForm,
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.correctFgDark
                          : AppTheme.correctFg,
                      fontWeight: FontWeight.w700,
                    )),
              ),
              const Spacer(),

              // Mastered toggle
              IconButton(
                icon: Icon(
                  word.mastered
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  color: word.mastered ? AppTheme.emerald : null,
                  size: 22,
                ),
                tooltip: word.mastered ? '取消掌握' : '标记已掌握',
                onPressed: () {
                  context
                      .read<AppState>()
                      .markWordMastered(word.id, !word.mastered);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(word.sentenceText,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.folder_outlined,
                  size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(word.projectName,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(width: 12),
              Icon(Icons.access_time,
                  size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(dateFormat.format(word.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              if (word.reviewCount > 0) ...[
                const SizedBox(width: 12),
                Icon(Icons.refresh,
                    size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('复习 ${word.reviewCount} 次',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/study_project.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/accuracy_ring.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/metric_pill.dart';
import '../widgets/status_badge.dart';
import 'dictation_page.dart';
import 'flashcard_page.dart';
import 'new_project_page.dart';
import 'shadowing_page.dart';
import 'timeline_page.dart';

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (appState.projects.isEmpty) {
          return EmptyState(
            icon: Icons.library_music_outlined,
            title: '还没有学习项目',
            message: '点击新建项目，导入 MP3 和德语原文后开始标注与听写练习。',
            action: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const NewProjectPage()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('新建项目'),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: appState.loadInitialData,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount =
                  width >= 1200 ? 3 : width >= 760 ? 2 : 1;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: _ProjectOverview(projects: appState.projects),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: crossAxisCount == 1 ? 2.8 : 1.6,
                      ),
                      itemCount: appState.projects.length,
                      itemBuilder: (context, index) {
                        return _ProjectCard(
                          project: appState.projects[index],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _ProjectOverview extends StatelessWidget {
  const _ProjectOverview({required this.projects});
  final List<StudyProject> projects;

  @override
  Widget build(BuildContext context) {
    final annotated =
        projects.where((p) => p.timelineCompleted).length;
    final totalSentences =
        projects.fold<int>(0, (s, p) => s + p.sentenceCount);

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          MetricPill(
            icon: Icons.folder_copy_outlined,
            label: '项目总数',
            value: '${projects.length}',
          ),
          MetricPill(
            icon: Icons.task_alt,
            label: '可听写',
            value: '$annotated',
            color: AppTheme.emerald,
          ),
          MetricPill(
            icon: Icons.pending_actions_outlined,
            label: '待标注',
            value: '${projects.length - annotated}',
            color: AppTheme.accent,
          ),
          MetricPill(
            icon: Icons.segment_outlined,
            label: '句子总数',
            value: '$totalSentences',
            color: AppTheme.gold,
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final StudyProject project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return GlassCard(
      onTap: () => _openProject(context),
      onLongPress: () => _confirmDelete(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + status + menu
          Row(
            children: [
              Expanded(
                child: Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              StatusBadge.fromStatus(project.statusLabel),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 20,
                    color: theme.colorScheme.onSurfaceVariant),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('删除项目', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (v) {
                  if (v == 'delete') _confirmDelete(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            dateFormat.format(project.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          const Spacer(),

          // Progress bars
          _ProgressRow(
            label: '标注',
            value: project.annotationProgress,
            text: '${project.annotatedCount}/${project.sentenceCount}',
            color: AppTheme.emerald,
          ),
          const SizedBox(height: 6),
          _ProgressRow(
            label: '听写',
            value: project.dictationProgress,
            text: '${project.dictatedCount}/${project.sentenceCount}',
            color: AppTheme.sky,
          ),

          const SizedBox(height: 10),

          // Bottom stats + action buttons
          Row(
            children: [
              if (project.dictatedCount > 0) ...[
                AccuracyRing(
                  value: project.accuracy,
                  size: 28,
                  strokeWidth: 3,
                ),
                const SizedBox(width: 8),
              ],
              if (project.wrongWordCount > 0) ...[
                Icon(Icons.error_outline,
                    size: 14, color: AppTheme.accent),
                const SizedBox(width: 3),
                Text('${project.wrongWordCount} 错词',
                    style: theme.textTheme.labelSmall),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              // Shadowing button
              if (project.timelineCompleted)
                Tooltip(
                  message: '跟读模式',
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ShadowingPage(projectId: project.id),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.record_voice_over,
                          size: 18, color: theme.colorScheme.primary),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),

          // Mastery stage indicator
          if (project.timelineCompleted) ...[
            const SizedBox(height: 8),
            _MasteryStageBar(project: project),
          ],
        ],
      ),
    );
  }

  void _openProject(BuildContext context) {
    final page = project.timelineCompleted
        ? DictationPage(projectId: project.id)
        : TimelinePage(projectId: project.id);
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除项目'),
        content: Text('确定删除"${project.name}"及其所有数据吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<AppState>().deleteProject(project);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除 ${project.name}')),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.text,
    required this.color,
  });

  final String label;
  final double value;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(label,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(text,
            style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// 4-stage mastery indicator following the Shang Wenjie method.
class _MasteryStageBar extends StatelessWidget {
  const _MasteryStageBar({required this.project});
  final StudyProject project;

  int get _stage {
    if (project.dictatedCount == 0) return 0;
    if (project.dictationProgress < 1.0) return 1; // 听写中
    if (project.wrongWordCount > 0) return 2; // 解析中
    return 3; // 已精通
  }

  static const _stageLabels = ['待听写', '听写中', '解析中', '已精通'];
  static final _stageColors = [Colors.grey, AppTheme.sky, AppTheme.gold, AppTheme.emerald];
  static const _stageIcons = [
    Icons.headphones_outlined,
    Icons.edit_note,
    Icons.psychology_outlined,
    Icons.star,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stage = _stage;

    return Row(
      children: List.generate(4, (i) {
        final active = i <= stage;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: active
                  ? _stageColors[i].withValues(alpha: 0.2)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_stageIcons[i],
                    size: 10,
                    color: active
                        ? _stageColors[i]
                        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                const SizedBox(width: 2),
                Text(
                  _stageLabels[i],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color: active
                        ? _stageColors[i]
                        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

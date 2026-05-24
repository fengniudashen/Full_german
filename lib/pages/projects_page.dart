import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/study_project.dart';
import '../providers/app_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/metric_pill.dart';
import '../widgets/surface_panel.dart';
import 'dictation_page.dart';
import 'timeline_page.dart';

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (appState.projects.isEmpty) {
          return const EmptyState(
            icon: Icons.library_music_outlined,
            title: '还没有学习项目',
            message: '点击右下角新建项目，导入 MP3 和德语原文后开始标注。',
          );
        }

        return RefreshIndicator(
          onRefresh: appState.loadInitialData,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 1200
                  ? 3
                  : width >= 760
                      ? 2
                      : 1;

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
                        childAspectRatio: crossAxisCount == 1 ? 3.6 : 2.1,
                      ),
                      itemCount: appState.projects.length,
                      itemBuilder: (context, index) {
                        final project = appState.projects[index];
                        return _ProjectCard(project: project);
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
    final annotated = projects.where((project) => project.timelineCompleted).length;
    final sentenceCount = projects.fold<int>(0, (sum, project) => sum + project.sentenceCount);
    final pending = projects.length - annotated;

    return SurfacePanel(
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
            color: Colors.green.shade700,
          ),
          MetricPill(
            icon: Icons.pending_actions_outlined,
            label: '待标注',
            value: '$pending',
            color: Theme.of(context).colorScheme.secondary,
          ),
          MetricPill(
            icon: Icons.segment_outlined,
            label: '句子总数',
            value: '$sentenceCount',
            color: Theme.of(context).colorScheme.tertiary,
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
    final progressText = '${project.annotatedCount}/${project.sentenceCount} 句已标注';

    final statusColor = project.timelineCompleted ? Colors.green.shade700 : theme.colorScheme.secondary;
    final progress = project.sentenceCount == 0 ? 0.0 : project.annotatedCount / project.sentenceCount;

    return SurfacePanel(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openProject(context),
        onLongPress: () => _confirmDelete(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      project.timelineCompleted ? '可听写' : '待标注',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                dateFormat.format(project.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Expanded(child: Text(progressText, style: theme.textTheme.bodySmall)),
                  Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openProject(BuildContext context) {
    final destination = project.timelineCompleted
        ? DictationPage(projectId: project.id)
        : TimelinePage(projectId: project.id);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => destination));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除项目'),
          content: Text('确定删除“${project.name}”及其句子、错词记录吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !context.mounted) {
      return;
    }

    await context.read<AppState>().deleteProject(project);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除 ${project.name}')),
    );
  }
}

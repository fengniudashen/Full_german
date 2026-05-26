import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/accuracy_ring.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_header.dart';
import '../widgets/metric_pill.dart';
import '../widgets/mini_activity_chart.dart';
import '../widgets/responsive_page.dart';
import 'bilingual_page.dart';
import 'daily_page.dart';
import 'difficulty_page.dart';
import 'discovery_page.dart';
import 'achievements_page.dart';
import 'chat_practice_page.dart';
import 'error_analysis_page.dart';
import 'grammar_lab_page.dart';
import 'podcast_page.dart';
import 'pomodoro_page.dart';
import 'quick_notes_page.dart';
import 'sentence_gen_page.dart';
import 'smart_review_page.dart';
import 'text_rewrite_page.dart';
import 'word_stats_page.dart';
import 'writing_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return RefreshIndicator(
          onRefresh: state.loadInitialData,
          child: ResponsivePage(
            maxWidth: 1200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHero(context, state),
                const SizedBox(height: 20),
                _buildStatsRow(context, state),
                const SizedBox(height: 20),
                _buildQuickActions(context),
                const SizedBox(height: 20),
                _buildActivityAndRecent(context, state),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHero(BuildContext context, AppState state) {
    final todayCount = state.dailyStats.isEmpty
        ? 0
        : state.dailyStats.last.sentencesPracticed;
    final goalPct = state.settings.dailyGoal == 0
        ? 1.0
        : (todayCount / state.settings.dailyGoal).clamp(0.0, 1.0);

    return GradientHeader(
      title: '欢迎回来 👋',
      subtitle: '今日已练习 $todayCount / ${state.settings.dailyGoal} 句',
      icon: Icons.school,
      trailing: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: goalPct,
              strokeWidth: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor:
                  const AlwaysStoppedAnimation(Colors.white),
              strokeCap: StrokeCap.round,
            ),
            Text(
              '${(goalPct * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, AppState state) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 700;
      final children = [
        MetricPill(
          icon: Icons.folder_copy_outlined,
          label: '项目总数',
          value: '${state.projects.length}',
          large: true,
        ),
        MetricPill(
          icon: Icons.local_fire_department,
          label: '连续天数',
          value: '${state.streakDays}',
          color: AppTheme.accent,
          large: true,
        ),
        MetricPill(
          icon: Icons.check_circle_outline,
          label: '已练句数',
          value: '${state.totalSentencesPracticed}',
          color: AppTheme.emerald,
          large: true,
        ),
        MetricPill(
          icon: Icons.error_outline,
          label: '待复习',
          value: '${state.unmasteredCount}',
          color: AppTheme.gold,
          large: true,
        ),
      ];

      if (wide) {
        return Row(
          children: children
              .map((c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: c,
                    ),
                  ))
              .toList(),
        );
      }
      return GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.2,
        children: children,
      );
    });
  }

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    final actions = [
      _QuickAction(Icons.lightbulb, '灵光一闪', AppTheme.gold,
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QuickNotesPage()))),
      _QuickAction(Icons.waves, '句海拾遗', theme.colorScheme.primary,
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiscoveryPage()))),
      _QuickAction(Icons.chat, '德语对话', Colors.teal,
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatPracticePage()))),
      _QuickAction(Icons.rate_review, '写作批改', Colors.indigo,
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WritingPage()))),
      _QuickAction(Icons.podcasts, '播客导入', Colors.deepPurple,
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PodcastPage()))),
      _QuickAction(Icons.emoji_events, '学习成就', Colors.amber.shade700,
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AchievementsPage()))),
      _QuickAction(Icons.bar_chart, '词频分析', Colors.cyan,
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WordStatsPage()))),
      _QuickAction(Icons.today, '每日德语', Colors.deepOrange,
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DailyPage()))),
      _QuickAction(Icons.analytics, '难度分析', Colors.blueGrey,
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DifficultyPage()))),
      _QuickAction(Icons.translate, '双语对照', Colors.green.shade700,
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BilingualPage()))),
      _QuickAction(Icons.auto_awesome, 'AI造句', Colors.pink,
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SentenceGenPage()))),
      _QuickAction(Icons.psychology, 'AI规划', Colors.purple,
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SmartReviewPage()))),
      _QuickAction(Icons.science, '语法实验室', Colors.brown,
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GrammarLabPage()))),
      _QuickAction(Icons.auto_fix_high, '文本改写', Colors.lime.shade800,
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TextRewritePage()))),
      _QuickAction(Icons.bug_report, '错误分析', Colors.red.shade700,
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ErrorAnalysisPage()))),
      _QuickAction(Icons.timer, '番茄钟', Colors.red,
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PomodoroPage()))),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 800 ? 4 : constraints.maxWidth >= 500 ? 3 : 2;
        final itemWidth = (constraints.maxWidth - (cols - 1) * 10) / cols;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: actions.map((a) => SizedBox(
            width: itemWidth,
            child: _QuickActionCard(
              icon: a.icon,
              label: a.label,
              color: a.color,
              onTap: a.onTap,
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildActivityAndRecent(BuildContext context, AppState state) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 800;
      final activityCard = _ActivityCard(stats: state.dailyStats);
      final recentCard = _RecentSessionsCard(sessions: state.recentSessions);

      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: activityCard),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: recentCard),
          ],
        );
      }
      return Column(
        children: [
          activityCard,
          const SizedBox(height: 16),
          recentCard,
        ],
      );
    });
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.stats});
  final List<dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = stats
        .map((s) => (s as dynamic).sentencesPracticed.toDouble())
        .toList()
        .cast<double>();

    // Pad to 30 days
    while (data.length < 30) {
      data.insert(0, 0);
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('30 天练习活跃度',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          MiniActivityChart(
            data: data,
            height: 100,
            barWidth: 5,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('30天前',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              Text('今天',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentSessionsCard extends StatelessWidget {
  const _RecentSessionsCard({required this.sessions});
  final List<dynamic> sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('最近练习',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('还没有练习记录',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              ),
            )
          else
            ...sessions.take(5).map((s) {
              final session = s as dynamic;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    AccuracyRing(value: session.accuracy, size: 36, strokeWidth: 3),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(session.projectName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(
                            '${session.sentencesPracticed} 句 · ${formatDurationCompact(session.duration)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction(this.icon, this.label, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

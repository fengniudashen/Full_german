import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/accuracy_ring.dart';
import '../widgets/glass_card.dart';
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
                const SizedBox(height: 24),
                _buildStatsRow(context, state),
                const SizedBox(height: 28),
                _buildCoreActions(context),
                const SizedBox(height: 24),
                _buildAiToolsSection(context),
                const SizedBox(height: 24),
                _buildAnalyticsSection(context),
                const SizedBox(height: 24),
                _buildActivityAndRecent(context, state),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Hero Banner ─────────────────────────────────────────────
  Widget _buildHero(BuildContext context, AppState state) {
    final todayCount = state.dailyStats.isEmpty
        ? 0
        : state.dailyStats.last.sentencesPracticed;
    final goalPct = state.settings.dailyGoal == 0
        ? 1.0
        : (todayCount / state.settings.dailyGoal).clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.heroGradientDark : AppTheme.heroGradient,
        borderRadius: AppTheme.borderXl,
        boxShadow: AppTheme.shadowLg(Theme.of(context).brightness),
      ),
      child: Row(
        children: [
          // Left: greeting + stats chips
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'DeutschFlow',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _heroBadge(Icons.local_fire_department, '${state.streakDays} 天连续'),
                    _heroBadge(Icons.check_circle_outline, '${state.totalSentencesPracticed} 句已练'),
                    _heroBadge(Icons.replay, '${state.unmasteredCount} 待复习'),
                  ],
                ),
              ],
            ),
          ),
          // Right: circular progress
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: goalPct,
                    strokeWidth: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$todayCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        height: 1,
                      ),
                    ),
                    Text(
                      '/${state.settings.dailyGoal}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '🌙 夜深了，注意休息';
    if (hour < 12) return '☀️ 早上好';
    if (hour < 18) return '🌤 下午好';
    return '🌙 晚上好';
  }

  // ─── Stats Row ───────────────────────────────────────────────
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

  // ─── Core Learning Actions ───────────────────────────────────
  Widget _buildCoreActions(BuildContext context) {
    final theme = Theme.of(context);
    final actions = [
      _QuickAction(Icons.waves, '句海拾遗', const Color(0xFF1B6B5A), '发现新句子',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiscoveryPage()))),
      _QuickAction(Icons.chat_bubble_rounded, '德语对话', const Color(0xFF0891B2), 'AI口语练习',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatPracticePage()))),
      _QuickAction(Icons.edit_note, '写作批改', const Color(0xFF6366F1), 'AI写作反馈',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WritingPage()))),
      _QuickAction(Icons.today, '每日德语', const Color(0xFFEA580C), '每日一句',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DailyPage()))),
      _QuickAction(Icons.podcasts, '播客导入', const Color(0xFF7C3AED), '导入音频素材',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PodcastPage()))),
      _QuickAction(Icons.translate, '双语对照', const Color(0xFF059669), '中德对照阅读',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BilingualPage()))),
    ];

    return _buildSection(
      context,
      icon: Icons.school_rounded,
      title: '核心学习',
      color: theme.colorScheme.primary,
      children: actions,
      cols: 3,
    );
  }

  // ─── AI Power Tools ──────────────────────────────────────────
  Widget _buildAiToolsSection(BuildContext context) {
    final actions = [
      _QuickAction(Icons.auto_awesome, 'AI造句', const Color(0xFFEC4899), '智能例句生成',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SentenceGenPage()))),
      _QuickAction(Icons.psychology_rounded, 'AI规划', const Color(0xFF8B5CF6), '个性化复习',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SmartReviewPage()))),
      _QuickAction(Icons.science_rounded, '语法实验室', const Color(0xFF92400E), '复合词/词性/框形',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GrammarLabPage()))),
      _QuickAction(Icons.auto_fix_high, '文本改写', const Color(0xFF65A30D), 'CEFR级别改写',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TextRewritePage()))),
    ];

    return _buildSection(
      context,
      icon: Icons.bolt_rounded,
      title: 'AI 工具',
      color: AppTheme.lavender,
      children: actions,
      cols: 4,
    );
  }

  // ─── Analytics & Extras ──────────────────────────────────────
  Widget _buildAnalyticsSection(BuildContext context) {
    final actions = [
      _QuickAction(Icons.bar_chart_rounded, '词频分析', const Color(0xFF0891B2), '词汇使用统计',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WordStatsPage()))),
      _QuickAction(Icons.bug_report_rounded, '错误分析', const Color(0xFFDC2626), '错误类型分布',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ErrorAnalysisPage()))),
      _QuickAction(Icons.analytics_rounded, '难度分析', const Color(0xFF475569), '文本难度评估',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DifficultyPage()))),
      _QuickAction(Icons.emoji_events_rounded, '学习成就', const Color(0xFFD97706), '成就与徽章',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AchievementsPage()))),
      _QuickAction(Icons.lightbulb_rounded, '灵光一闪', const Color(0xFFCA8A04), '快速记录笔记',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QuickNotesPage()))),
      _QuickAction(Icons.timer_rounded, '番茄钟', const Color(0xFFE11D48), '专注计时',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PomodoroPage()))),
    ];

    return _buildSection(
      context,
      icon: Icons.insights_rounded,
      title: '统计 & 工具',
      color: AppTheme.sky,
      children: actions,
      cols: 3,
    );
  }

  // ─── Section Builder ─────────────────────────────────────────
  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required List<_QuickAction> children,
    int cols = 3,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final effectiveCols = constraints.maxWidth >= 800
                ? cols
                : constraints.maxWidth >= 500
                    ? (cols > 2 ? cols - 1 : cols)
                    : 2;
            final spacing = 10.0;
            final itemWidth =
                (constraints.maxWidth - (effectiveCols - 1) * spacing) / effectiveCols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: children
                  .map((a) => SizedBox(
                        width: itemWidth,
                        child: _ActionCard(action: a),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  // ─── Activity & Recent ───────────────────────────────────────
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

// ═══════════════════════════════════════════════════════════════════
// Private widgets
// ═══════════════════════════════════════════════════════════════════

class _ActionCard extends StatefulWidget {
  const _ActionCard({required this.action});
  final _QuickAction action;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = widget.action.color;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: _hovering
            ? (Matrix4.identity()..translate(0.0, -2.0))
            : Matrix4.identity(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.action.onTap,
            borderRadius: AppTheme.borderLg,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          color.withValues(alpha: 0.12),
                          color.withValues(alpha: 0.04),
                        ]
                      : [
                          color.withValues(alpha: 0.06),
                          Colors.white.withValues(alpha: 0.9),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AppTheme.borderLg,
                border: Border.all(
                  color: _hovering
                      ? color.withValues(alpha: 0.4)
                      : color.withValues(alpha: isDark ? 0.18 : 0.12),
                  width: _hovering ? 1.5 : 1,
                ),
                boxShadow: _hovering
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : AppTheme.shadowSm(theme.brightness),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.action.icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.action.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.action.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.4),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

    while (data.length < 30) {
      data.insert(0, 0);
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('30 天练习活跃度',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          MiniActivityChart(data: data, height: 100, barWidth: 5),
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
              Icon(Icons.history_rounded, color: theme.colorScheme.primary, size: 20),
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
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.hourglass_empty_rounded,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.4),
                        size: 32),
                    const SizedBox(height: 8),
                    Text('还没有练习记录',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
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
  const _QuickAction(this.icon, this.label, this.color, this.subtitle, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final String subtitle;
  final VoidCallback onTap;
}

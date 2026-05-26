import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_page.dart';

/// Achievement & level system — gamification to motivate learning.
class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final stats = _computeStats(state);
        final level = _computeLevel(stats.totalXP);
        final achievements = _computeAchievements(stats);

        return Scaffold(
          appBar: AppBar(title: const Text('学习成就')),
          body: ResponsivePage(
            maxWidth: 700,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLevelCard(context, level, stats),
                const SizedBox(height: 20),
                _buildStatsGrid(context, stats),
                const SizedBox(height: 20),
                Text('成就徽章',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        )),
                const SizedBox(height: 12),
                ...achievements.map((a) => _buildAchievementTile(context, a)),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  _LearnerStats _computeStats(AppState state) {
    final totalSentences = state.totalSentencesPracticed;
    final streak = state.streakDays;
    final projects = state.projects.length;
    final wrongWords = state.wrongWords.length;
    final mastered = state.wrongWords.where((w) => w.mastered).length;

    // XP: sentences * 10 + streak_bonus + mastered * 20
    final xp = totalSentences * 10 + streak * 50 + mastered * 20 + projects * 100;

    return _LearnerStats(
      totalSentences: totalSentences,
      streakDays: streak,
      projects: projects,
      wrongWords: wrongWords,
      mastered: mastered,
      totalXP: xp,
    );
  }

  _Level _computeLevel(int xp) {
    const levels = [
      _Level(1, 'Anfänger', '初学者', 0, 200, Icons.eco, Colors.green),
      _Level(2, 'Lernender', '学习者', 200, 500, Icons.local_library, Colors.blue),
      _Level(3, 'Fortgeschritten', '进阶者', 500, 1200, Icons.school, Colors.indigo),
      _Level(4, 'Könner', '能手', 1200, 2500, Icons.military_tech, Colors.orange),
      _Level(5, 'Experte', '专家', 2500, 5000, Icons.workspace_premium, Colors.purple),
      _Level(6, 'Meister', '大师', 5000, 10000, Icons.diamond, Colors.amber),
      _Level(7, 'Legende', '传奇', 10000, 99999, Icons.auto_awesome, Colors.red),
    ];

    for (int i = levels.length - 1; i >= 0; i--) {
      if (xp >= levels[i].minXP) return levels[i];
    }
    return levels[0];
  }

  List<_Achievement> _computeAchievements(_LearnerStats stats) {
    return [
      _Achievement(
        icon: Icons.play_arrow,
        title: '初次练习',
        desc: '完成第一句听写',
        unlocked: stats.totalSentences >= 1,
        progress: (stats.totalSentences / 1).clamp(0, 1),
      ),
      _Achievement(
        icon: Icons.looks_one,
        title: '十句小试',
        desc: '累计练习 10 句',
        unlocked: stats.totalSentences >= 10,
        progress: (stats.totalSentences / 10).clamp(0, 1),
      ),
      _Achievement(
        icon: Icons.looks_two,
        title: '百句精通',
        desc: '累计练习 100 句',
        unlocked: stats.totalSentences >= 100,
        progress: (stats.totalSentences / 100).clamp(0, 1),
      ),
      _Achievement(
        icon: Icons.whatshot,
        title: '千句磨练',
        desc: '累计练习 1000 句',
        unlocked: stats.totalSentences >= 1000,
        progress: (stats.totalSentences / 1000).clamp(0, 1),
      ),
      _Achievement(
        icon: Icons.local_fire_department,
        title: '三天连续',
        desc: '连续练习 3 天',
        unlocked: stats.streakDays >= 3,
        progress: (stats.streakDays / 3).clamp(0, 1),
      ),
      _Achievement(
        icon: Icons.whatshot,
        title: '一周坚持',
        desc: '连续练习 7 天',
        unlocked: stats.streakDays >= 7,
        progress: (stats.streakDays / 7).clamp(0, 1),
      ),
      _Achievement(
        icon: Icons.emoji_events,
        title: '月度达人',
        desc: '连续练习 30 天',
        unlocked: stats.streakDays >= 30,
        progress: (stats.streakDays / 30).clamp(0, 1),
      ),
      _Achievement(
        icon: Icons.folder_open,
        title: '项目起步',
        desc: '创建第一个项目',
        unlocked: stats.projects >= 1,
        progress: (stats.projects / 1).clamp(0, 1),
      ),
      _Achievement(
        icon: Icons.folder_special,
        title: '多元学习',
        desc: '创建 5 个项目',
        unlocked: stats.projects >= 5,
        progress: (stats.projects / 5).clamp(0, 1),
      ),
      _Achievement(
        icon: Icons.auto_fix_high,
        title: '纠错先锋',
        desc: '记录 50 个错词',
        unlocked: stats.wrongWords >= 50,
        progress: (stats.wrongWords / 50).clamp(0, 1),
      ),
      _Achievement(
        icon: Icons.check_circle_outline,
        title: '记忆达人',
        desc: '掌握 30 个错词',
        unlocked: stats.mastered >= 30,
        progress: (stats.mastered / 30).clamp(0, 1),
      ),
      _Achievement(
        icon: Icons.star,
        title: '词汇大师',
        desc: '掌握 100 个错词',
        unlocked: stats.mastered >= 100,
        progress: (stats.mastered / 100).clamp(0, 1),
      ),
    ];
  }

  Widget _buildLevelCard(BuildContext context, _Level level, _LearnerStats stats) {
    final theme = Theme.of(context);
    final progress = level.maxXP > level.minXP
        ? ((stats.totalXP - level.minXP) / (level.maxXP - level.minXP)).clamp(0.0, 1.0)
        : 1.0;

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [level.color, level.color.withValues(alpha: 0.6)],
                  ),
                ),
                child: Icon(level.icon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lv.${level.level} ${level.titleDe}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: level.color,
                      ),
                    ),
                    Text(level.titleZh,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
              Column(
                children: [
                  Text('${stats.totalXP}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: level.color,
                      )),
                  Text('XP', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: level.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${stats.totalXP - level.minXP} / ${level.maxXP - level.minXP} XP 到下一级',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, _LearnerStats stats) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: _StatCard(
          icon: Icons.edit, label: '句子', value: '${stats.totalSentences}',
          color: Colors.blue,
        )),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(
          icon: Icons.local_fire_department, label: '连续', value: '${stats.streakDays}天',
          color: Colors.orange,
        )),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(
          icon: Icons.folder, label: '项目', value: '${stats.projects}',
          color: Colors.green,
        )),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(
          icon: Icons.check, label: '已掌握', value: '${stats.mastered}',
          color: Colors.purple,
        )),
      ],
    );
  }

  Widget _buildAchievementTile(BuildContext context, _Achievement a) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: a.unlocked
                    ? Colors.amber.withValues(alpha: 0.2)
                    : scheme.surfaceContainerHighest,
              ),
              child: Icon(
                a.icon,
                color: a.unlocked ? Colors.amber.shade700 : scheme.onSurfaceVariant.withValues(alpha: 0.4),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: a.unlocked ? scheme.onSurface : scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(a.desc,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      )),
                ],
              ),
            ),
            SizedBox(
              width: 80,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: a.progress,
                      minHeight: 6,
                      color: a.unlocked ? Colors.amber : scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    a.unlocked ? '已解锁' : '${(a.progress * 100).toInt()}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: a.unlocked ? Colors.amber.shade700 : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              )),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _LearnerStats {
  const _LearnerStats({
    required this.totalSentences,
    required this.streakDays,
    required this.projects,
    required this.wrongWords,
    required this.mastered,
    required this.totalXP,
  });
  final int totalSentences;
  final int streakDays;
  final int projects;
  final int wrongWords;
  final int mastered;
  final int totalXP;
}

class _Level {
  const _Level(this.level, this.titleDe, this.titleZh, this.minXP, this.maxXP, this.icon, this.color);
  final int level;
  final String titleDe;
  final String titleZh;
  final int minXP;
  final int maxXP;
  final IconData icon;
  final Color color;
}

class _Achievement {
  const _Achievement({
    required this.icon,
    required this.title,
    required this.desc,
    required this.unlocked,
    required this.progress,
  });
  final IconData icon;
  final String title;
  final String desc;
  final bool unlocked;
  final double progress;
}

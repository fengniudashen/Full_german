import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return ResponsivePage(
          maxWidth: 700,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionTitle('外观'),
              const SizedBox(height: 8),
              _ThemeSelector(current: state.settings.themeMode),
              const SizedBox(height: 24),
              _SectionTitle('音频'),
              const SizedBox(height: 8),
              _SpeedSelector(current: state.settings.playbackSpeed),
              const SizedBox(height: 24),
              _SectionTitle('练习'),
              const SizedBox(height: 8),
              _PracticeSettings(state: state),
              const SizedBox(height: 24),
              _SectionTitle('AI 助手'),
              const SizedBox(height: 8),
              _AiSettings(state: state),
              const SizedBox(height: 24),
              _SectionTitle('关于'),
              const SizedBox(height: 8),
              _AboutCard(),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ));
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.current});
  final String current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('主题模式',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              _ThemeOption(
                icon: Icons.brightness_auto,
                label: '跟随系统',
                value: 'system',
                selected: current == 'system',
              ),
              const SizedBox(width: 8),
              _ThemeOption(
                icon: Icons.light_mode,
                label: '浅色',
                value: 'light',
                selected: current == 'light',
              ),
              const SizedBox(width: 8),
              _ThemeOption(
                icon: Icons.dark_mode,
                label: '深色',
                value: 'dark',
                selected: current == 'dark',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppTheme.borderMd,
          onTap: () => context.read<AppState>().updateThemeMode(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerLow,
              borderRadius: AppTheme.borderMd,
              border: Border.all(
                color: selected
                    ? scheme.primary
                    : scheme.outlineVariant,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon,
                    color: selected
                        ? scheme.primary
                        : scheme.onSurfaceVariant),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({required this.current});
  final double current;

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('默认播放速度',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _speeds.map((s) {
              final selected = (s - current).abs() < 0.01;
              return ChoiceChip(
                label: Text('${s}x'),
                selected: selected,
                onSelected: (_) =>
                    context.read<AppState>().updatePlaybackSpeed(s),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PracticeSettings extends StatelessWidget {
  const _PracticeSettings({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('核对后自动跳转下一句'),
            subtitle: const Text('校对完成后自动前进'),
            value: state.settings.autoAdvance,
            onChanged: (v) => state.updateAutoAdvance(v),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('显示提示'),
            subtitle: const Text('听写时显示首尾字母提示'),
            value: state.settings.showHints,
            onChanged: (v) => state.updateShowHints(v),
          ),
          const Divider(),
          ListTile(
            title: const Text('每日目标'),
            subtitle: Text('${state.settings.dailyGoal} 句/天'),
            trailing: SizedBox(
              width: 140,
              child: Slider(
                value: state.settings.dailyGoal.toDouble(),
                min: 5,
                max: 100,
                divisions: 19,
                label: '${state.settings.dailyGoal}',
                onChanged: (v) =>
                    state.updateDailyGoal(v.round()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiSettings extends StatelessWidget {
  const _AiSettings({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasKey = state.settings.deepseekApiKey.isNotEmpty;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(Icons.auto_awesome,
                color: hasKey ? AppTheme.emerald : theme.colorScheme.onSurfaceVariant),
            title: const Text('DeepSeek API Key'),
            subtitle: Text(hasKey ? '已配置 ✓' : '未配置 — 需要 API Key 才能使用 AI 功能'),
            trailing: FilledButton.tonal(
              onPressed: () => _editApiKey(context),
              child: Text(hasKey ? '修改' : '配置'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              '访问 platform.deepseek.com 注册并获取 API Key。\n'
              'AI 功能支持查词、语法分析、翻译、片段解析和自由提问。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editApiKey(BuildContext context) async {
    final ctrl = TextEditingController(
      text: state.settings.deepseekApiKey,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('DeepSeek API Key'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'sk-...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && context.mounted) {
      await state.updateDeepseekApiKey(result);
    }
  }
}

class _AboutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppTheme.heroGradient,
              borderRadius: AppTheme.borderMd,
            ),
            child: const Icon(Icons.graphic_eq, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DeutschFlow',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('v1.0.0 · Flutter 跨平台德语听写学习',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

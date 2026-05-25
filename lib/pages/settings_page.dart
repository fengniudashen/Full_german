import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_provider.dart';
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
    final activeId = state.settings.activeProviderId;
    final activeProvider = state.settings.activeProvider;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active provider selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('当前 AI 模型',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String>(
              value: activeId,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: AiProvider.presets.map((p) {
                final key = state.settings.providerKeys[p.id] ??
                    (p.id == 'deepseek' ? state.settings.deepseekApiKey : '');
                final hasKey = key.isNotEmpty;
                return DropdownMenuItem(
                  value: p.id,
                  child: Row(
                    children: [
                      Icon(
                        hasKey ? Icons.check_circle : Icons.circle_outlined,
                        size: 16,
                        color: hasKey ? AppTheme.emerald : theme.colorScheme.outlineVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(p.name),
                      if (p.id == activeId)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('使用中',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (id) {
                if (id != null) state.setActiveProvider(id);
              },
            ),
          ),
          if (activeProvider.hasKey)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                '模型: ${activeProvider.model}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const Divider(height: 20),

          // Provider key list
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('API Key 管理',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
          ),
          ...AiProvider.presets.map((p) {
            final key = state.settings.providerKeys[p.id] ??
                (p.id == 'deepseek' ? state.settings.deepseekApiKey : '');
            final hasKey = key.isNotEmpty;
            return ListTile(
              dense: true,
              leading: Icon(
                hasKey ? Icons.vpn_key : Icons.vpn_key_off_outlined,
                size: 18,
                color: hasKey ? AppTheme.emerald : theme.colorScheme.outlineVariant,
              ),
              title: Text(p.name, style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                hasKey ? '已配置 ✓' : '未配置',
                style: TextStyle(
                  fontSize: 12,
                  color: hasKey
                      ? AppTheme.emerald
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (p.id != activeId && hasKey)
                    TextButton(
                      onPressed: () => state.setActiveProvider(p.id),
                      child: const Text('切换', style: TextStyle(fontSize: 12)),
                    ),
                  FilledButton.tonal(
                    onPressed: () => _editProviderKey(context, p),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(56, 32),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: Text(hasKey ? '修改' : '配置'),
                  ),
                ],
              ),
            );
          }),

          // Custom provider URL (only when custom is selected)
          if (activeId == 'custom') ...[
            const Divider(height: 20),
            ListTile(
              dense: true,
              leading: const Icon(Icons.link, size: 18),
              title: const Text('自定义 API 地址', style: TextStyle(fontSize: 14)),
              subtitle: Text(
                state.settings.customProviderUrl.isEmpty
                    ? '未设置'
                    : state.settings.customProviderUrl,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: FilledButton.tonal(
                onPressed: () => _editCustomProvider(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(56, 32),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('设置'),
              ),
            ),
          ],

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'AI 功能支持查词、造句、近义词、反义词、变形表、语法分析、翻译、改写等。\n'
              '可自由切换不同的 AI 模型。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editProviderKey(BuildContext context, AiProvider preset) async {
    final currentKey = state.settings.providerKeys[preset.id] ??
        (preset.id == 'deepseek' ? state.settings.deepseekApiKey : '');
    final keyCtrl = TextEditingController(text: currentKey);
    final modelCtrl = TextEditingController(
      text: state.settings.providerModels[preset.id] ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${preset.name} 配置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: keyCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: preset.id == 'claude' ? 'sk-ant-...' : 'sk-...',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: modelCtrl,
              decoration: InputDecoration(
                labelText: '模型名称 (可选)',
                hintText: '默认: ${preset.defaultModel}',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getProviderHint(preset.id),
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await state.updateProviderKey(preset.id, keyCtrl.text.trim());
      final model = modelCtrl.text.trim();
      if (model.isNotEmpty) {
        await state.updateProviderModel(preset.id, model);
      }
    }
    keyCtrl.dispose();
    modelCtrl.dispose();
  }

  Future<void> _editCustomProvider(BuildContext context) async {
    final urlCtrl = TextEditingController(
      text: state.settings.customProviderUrl,
    );
    final nameCtrl = TextEditingController(
      text: state.settings.customProviderName,
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义 AI 服务'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'API 地址',
                hintText: 'https://your-api.example.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '显示名称',
                hintText: '我的 AI 服务',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '需要兼容 OpenAI Chat Completions API 格式。\n'
              'API 地址应指向 /v1/chat/completions 的上级路径。',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await state.updateCustomProvider(
        urlCtrl.text.trim(),
        nameCtrl.text.trim(),
      );
    }
    urlCtrl.dispose();
    nameCtrl.dispose();
  }

  String _getProviderHint(String id) {
    return switch (id) {
      'deepseek' => '访问 platform.deepseek.com 获取 API Key',
      'openai' => '访问 platform.openai.com 获取 API Key',
      'claude' => '访问 console.anthropic.com 获取 API Key',
      'minimax' => '访问 platform.minimaxi.com 获取 API Key',
      'glm' => '访问 open.bigmodel.cn 获取 API Key',
      'qwen' => '访问 dashscope.console.aliyun.com 获取 API Key',
      'doubao' => '访问 console.volcengine.com 获取 API Key',
      _ => '请输入对应平台的 API Key',
    };
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

import 'ai_provider.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = 'system',
    this.playbackSpeed = 1.0,
    this.autoAdvance = true,
    this.showHints = false,
    this.dailyGoal = 20,
    this.deepseekApiKey = '',
    this.activeProviderId = 'deepseek',
    this.providerKeys = const {},
    this.providerModels = const {},
    this.providerUrls = const {},
    this.customProviderUrl = '',
    this.customProviderName = '',
    this.useLocalWhisper = false,
    this.whisperModel = 'base',
  });

  final String themeMode; // 'light' | 'dark' | 'system'
  final double playbackSpeed;
  final bool autoAdvance;
  final bool showHints;
  final int dailyGoal;
  final String deepseekApiKey; // legacy — migrated to providerKeys
  final String activeProviderId;
  final Map<String, String> providerKeys;   // id → apiKey
  final Map<String, String> providerModels; // id → custom model
  final Map<String, String> providerUrls;   // id → custom URL
  final String customProviderUrl;
  final String customProviderName;
  final bool useLocalWhisper;
  final String whisperModel; // 'tiny' | 'base' | 'small'

  /// Get the currently active provider with its config.
  AiProvider get activeProvider {
    final preset = AiProvider.presets.firstWhere(
      (p) => p.id == activeProviderId,
      orElse: () => AiProvider.presets.first,
    );
    final key = providerKeys[activeProviderId] ??
        (activeProviderId == 'deepseek' ? deepseekApiKey : '');
    final customUrl = providerUrls[activeProviderId];
    return AiProvider(
      id: preset.id,
      name: preset.isCustom
          ? (customProviderName.isNotEmpty ? customProviderName : preset.name)
          : preset.name,
      baseUrl: customUrl != null && customUrl.isNotEmpty
          ? customUrl
          : preset.baseUrl,
      defaultModel: preset.defaultModel,
      apiKey: key,
      customModel: providerModels[activeProviderId],
      isCustom: preset.isCustom,
    );
  }

  /// Get a specific provider by id with its stored config.
  AiProvider getProvider(String id) {
    final preset = AiProvider.presets.firstWhere(
      (p) => p.id == id,
      orElse: () => AiProvider.presets.first,
    );
    final key = providerKeys[id] ??
        (id == 'deepseek' ? deepseekApiKey : '');
    final customUrl = providerUrls[id];
    return AiProvider(
      id: preset.id,
      name: preset.isCustom
          ? (customProviderName.isNotEmpty ? customProviderName : preset.name)
          : preset.name,
      baseUrl: customUrl != null && customUrl.isNotEmpty
          ? customUrl
          : preset.baseUrl,
      defaultModel: preset.defaultModel,
      apiKey: key,
      customModel: providerModels[id],
      isCustom: preset.isCustom,
    );
  }

  AppSettings copyWith({
    String? themeMode,
    double? playbackSpeed,
    bool? autoAdvance,
    bool? showHints,
    int? dailyGoal,
    String? deepseekApiKey,
    String? activeProviderId,
    Map<String, String>? providerKeys,
    Map<String, String>? providerModels,
    Map<String, String>? providerUrls,
    String? customProviderUrl,
    String? customProviderName,
    bool? useLocalWhisper,
    String? whisperModel,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      showHints: showHints ?? this.showHints,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      deepseekApiKey: deepseekApiKey ?? this.deepseekApiKey,
      activeProviderId: activeProviderId ?? this.activeProviderId,
      providerKeys: providerKeys ?? this.providerKeys,
      providerModels: providerModels ?? this.providerModels,
      providerUrls: providerUrls ?? this.providerUrls,
      customProviderUrl: customProviderUrl ?? this.customProviderUrl,
      customProviderName: customProviderName ?? this.customProviderName,
      useLocalWhisper: useLocalWhisper ?? this.useLocalWhisper,
      whisperModel: whisperModel ?? this.whisperModel,
    );
  }
}

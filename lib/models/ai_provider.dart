/// Represents an AI provider configuration.
class AiProvider {
  const AiProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.defaultModel,
    this.apiKey = '',
    this.customModel,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String defaultModel;
  final String apiKey;
  final String? customModel;
  final bool isCustom;

  String get model => customModel ?? defaultModel;
  bool get hasKey => apiKey.isNotEmpty;

  AiProvider copyWith({
    String? apiKey,
    String? customModel,
    String? baseUrl,
    String? name,
  }) {
    return AiProvider(
      id: id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      defaultModel: defaultModel,
      apiKey: apiKey ?? this.apiKey,
      customModel: customModel ?? this.customModel,
      isCustom: isCustom,
    );
  }

  /// Predefined providers.
  static const List<AiProvider> presets = [
    AiProvider(
      id: 'deepseek',
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com',
      defaultModel: 'deepseek-chat',
    ),
    AiProvider(
      id: 'openai',
      name: 'ChatGPT (OpenAI)',
      baseUrl: 'https://api.openai.com',
      defaultModel: 'gpt-4o',
    ),
    AiProvider(
      id: 'claude',
      name: 'Claude (Anthropic)',
      baseUrl: 'https://api.anthropic.com',
      defaultModel: 'claude-sonnet-4-20250514',
    ),
    AiProvider(
      id: 'minimax',
      name: 'MiniMax',
      baseUrl: 'https://api.minimax.chat',
      defaultModel: 'MiniMax-Text-01',
    ),
    AiProvider(
      id: 'glm',
      name: 'GLM (智谱)',
      baseUrl: 'https://open.bigmodel.cn/api/paas',
      defaultModel: 'glm-4-flash',
    ),
    AiProvider(
      id: 'qwen',
      name: 'Qwen (通义千问)',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode',
      defaultModel: 'qwen-plus',
    ),
    AiProvider(
      id: 'doubao',
      name: 'Doubao (豆包)',
      baseUrl: 'https://ark.cn-beijing.volces.com/api',
      defaultModel: 'doubao-1.5-pro-32k-250115',
    ),
    AiProvider(
      id: 'custom',
      name: '自定义 (OpenAI 兼容)',
      baseUrl: 'https://your-api.example.com',
      defaultModel: 'default',
      isCustom: true,
    ),
  ];

  /// Serialize to map for settings storage.
  Map<String, String> toSettingsMap() => {
        'ai_${id}_key': apiKey,
        if (customModel != null) 'ai_${id}_model': customModel!,
        if (isCustom) 'ai_${id}_url': baseUrl,
        if (isCustom) 'ai_${id}_name': name,
      };

  /// Deserialize from settings map.
  static AiProvider fromPreset(String id, Map<String, String> settings) {
    final preset = presets.firstWhere(
      (p) => p.id == id,
      orElse: () => presets.last, // fallback to custom
    );
    return AiProvider(
      id: preset.id,
      name: settings['ai_${id}_name'] ?? preset.name,
      baseUrl: settings['ai_${id}_url'] ?? preset.baseUrl,
      defaultModel: preset.defaultModel,
      apiKey: settings['ai_${id}_key'] ?? '',
      customModel: settings['ai_${id}_model'],
      isCustom: preset.isCustom,
    );
  }
}

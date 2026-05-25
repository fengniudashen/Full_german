class AppSettings {
  const AppSettings({
    this.themeMode = 'system',
    this.playbackSpeed = 1.0,
    this.autoAdvance = true,
    this.showHints = false,
    this.dailyGoal = 20,
    this.deepseekApiKey = '',
  });

  final String themeMode; // 'light' | 'dark' | 'system'
  final double playbackSpeed;
  final bool autoAdvance;
  final bool showHints;
  final int dailyGoal;
  final String deepseekApiKey;

  AppSettings copyWith({
    String? themeMode,
    double? playbackSpeed,
    bool? autoAdvance,
    bool? showHints,
    int? dailyGoal,
    String? deepseekApiKey,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      showHints: showHints ?? this.showHints,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      deepseekApiKey: deepseekApiKey ?? this.deepseekApiKey,
    );
  }
}

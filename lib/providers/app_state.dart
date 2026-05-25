import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/app_database.dart';
import '../models/app_settings.dart';
import '../models/practice_session.dart';
import '../models/study_project.dart';
import '../models/wrong_word.dart';
import '../services/csv_exporter.dart';
import '../services/text_parser.dart';

class AppState extends ChangeNotifier {
  AppState(this.database);

  final AppDatabase database;

  List<StudyProject> _projects = const [];
  List<WrongWord> _wrongWords = const [];
  List<PracticeSession> _recentSessions = const [];
  List<DailyStats> _dailyStats = const [];
  AppSettings _settings = const AppSettings();
  bool _isBusy = false;
  int _streakDays = 0;
  int _totalSentencesPracticed = 0;
  int _unmasteredCount = 0;

  List<StudyProject> get projects => _projects;
  List<WrongWord> get wrongWords => _wrongWords;
  List<PracticeSession> get recentSessions => _recentSessions;
  List<DailyStats> get dailyStats => _dailyStats;
  AppSettings get settings => _settings;
  bool get isBusy => _isBusy;
  int get streakDays => _streakDays;
  int get totalSentencesPracticed => _totalSentencesPracticed;
  int get unmasteredCount => _unmasteredCount;

  ThemeMode get themeMode {
    return switch (_settings.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> loadInitialData() async {
    await Future.wait([
      loadProjects(),
      loadWrongWords(),
      loadSessions(),
      loadDailyStats(),
      loadSettings(),
      _loadAggregates(),
    ]);
  }

  Future<void> loadProjects() async {
    _projects = await database.getProjects();
    notifyListeners();
  }

  Future<void> loadWrongWords({int? projectId, bool? mastered}) async {
    _wrongWords = await database.getWrongWords(
      projectId: projectId,
      mastered: mastered,
    );
    notifyListeners();
  }

  Future<void> loadSessions() async {
    _recentSessions = await database.getSessions(limit: 20);
    notifyListeners();
  }

  Future<void> loadDailyStats() async {
    _dailyStats = await database.getDailyStats(days: 30);
    notifyListeners();
  }

  Future<void> loadSettings() async {
    _settings = await database.getSettings();
    notifyListeners();
  }

  Future<void> _loadAggregates() async {
    _streakDays = await database.getStreakDays();
    _totalSentencesPracticed = await database.getTotalSentencesPracticed();
    _unmasteredCount = await database.getUnmasteredCount();
    notifyListeners();
  }

  // ─── Settings ───────────────────────────────────────────────
  Future<void> updateThemeMode(String mode) async {
    await database.saveSetting('theme_mode', mode);
    _settings = _settings.copyWith(themeMode: mode);
    notifyListeners();
  }

  Future<void> updatePlaybackSpeed(double speed) async {
    await database.saveSetting('playback_speed', speed.toString());
    _settings = _settings.copyWith(playbackSpeed: speed);
    notifyListeners();
  }

  Future<void> updateAutoAdvance(bool value) async {
    await database.saveSetting('auto_advance', value.toString());
    _settings = _settings.copyWith(autoAdvance: value);
    notifyListeners();
  }

  Future<void> updateShowHints(bool value) async {
    await database.saveSetting('show_hints', value.toString());
    _settings = _settings.copyWith(showHints: value);
    notifyListeners();
  }

  Future<void> updateDailyGoal(int goal) async {
    await database.saveSetting('daily_goal', goal.toString());
    _settings = _settings.copyWith(dailyGoal: goal);
    notifyListeners();
  }

  // ─── Projects ───────────────────────────────────────────────
  Future<int> createProject({
    required String name,
    required String sourceText,
    required String audioPath,
  }) async {
    final trimmedName = name.trim();
    final trimmedText = sourceText.trim();
    if (trimmedName.isEmpty) throw ArgumentError('请输入项目名称。');
    if (audioPath.trim().isEmpty) throw ArgumentError('请导入 MP3 音频。');

    final sentences = TextParser.splitIntoSentences(trimmedText);
    if (sentences.isEmpty) throw ArgumentError('德语原文至少需要包含一个句子。');

    _setBusy(true);
    try {
      final projectId = await database.createProject(
        name: trimmedName,
        sourceText: trimmedText,
      );
      final copied = await _copyAudioFile(projectId, audioPath);
      await database.updateProjectAudioPath(projectId, copied);
      await database.insertSentences(projectId, sentences);
      await loadProjects();
      return projectId;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> deleteProject(StudyProject project) async {
    _setBusy(true);
    try {
      await database.deleteProject(project.id);
      if (project.audioPath.isNotEmpty) {
        final f = File(project.audioPath);
        if (await f.exists()) await f.delete();
      }
      await loadInitialData();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> markTimelineCompleted(int projectId) async {
    await database.markTimelineCompleted(projectId);
    await loadProjects();
  }

  // ─── Wrong words ────────────────────────────────────────────
  Future<void> markWordMastered(int wordId, bool mastered) async {
    await database.markWordMastered(wordId, mastered);
    await loadWrongWords();
    await _loadAggregates();
  }

  // ─── Export ─────────────────────────────────────────────────
  Future<File> exportWrongWordsCsv({int? projectId}) async {
    final rows = await database.getWrongWords(projectId: projectId);
    final csv = CsvExporter.buildWrongWordsCsv(rows);
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File(p.join(dir.path, 'deutschflow_wrong_words_$ts.csv'));
    await file.writeAsString(csv, flush: true);
    return file;
  }

  // ─── Internal ───────────────────────────────────────────────
  Future<String> _copyAudioFile(int projectId, String originalPath) async {
    final source = File(originalPath);
    if (!await source.exists()) return originalPath;

    final docs = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(docs.path, 'DeutschFlowAudio'));
    if (!await audioDir.exists()) await audioDir.create(recursive: true);

    final ext = p.extension(originalPath).isEmpty
        ? '.mp3'
        : p.extension(originalPath);
    final target = File(p.join(audioDir.path, 'project_$projectId$ext'));
    final copied = await source.copy(target.path);
    return copied.path;
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    database.close();
    super.dispose();
  }
}

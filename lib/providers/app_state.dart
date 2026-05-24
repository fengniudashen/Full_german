import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/app_database.dart';
import '../models/study_project.dart';
import '../models/wrong_word.dart';
import '../services/csv_exporter.dart';
import '../services/text_parser.dart';

class AppState extends ChangeNotifier {
  AppState(this.database);

  final AppDatabase database;

  List<StudyProject> _projects = const [];
  List<WrongWord> _wrongWords = const [];
  bool _isBusy = false;

  List<StudyProject> get projects => _projects;

  List<WrongWord> get wrongWords => _wrongWords;

  bool get isBusy => _isBusy;

  Future<void> loadInitialData() async {
    await Future.wait([loadProjects(), loadWrongWords()]);
  }

  Future<void> loadProjects() async {
    _projects = await database.getProjects();
    notifyListeners();
  }

  Future<void> loadWrongWords({int? projectId}) async {
    _wrongWords = await database.getWrongWords(projectId: projectId);
    notifyListeners();
  }

  Future<int> createProject({
    required String name,
    required String sourceText,
    required String audioPath,
  }) async {
    final trimmedName = name.trim();
    final trimmedText = sourceText.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('请输入项目名称。');
    }
    if (audioPath.trim().isEmpty) {
      throw ArgumentError('请导入 MP3 音频。');
    }

    final sentences = TextParser.splitIntoSentences(trimmedText);
    if (sentences.isEmpty) {
      throw ArgumentError('德语原文至少需要包含一个句子。');
    }

    _setBusy(true);
    try {
      final projectId = await database.createProject(
        name: trimmedName,
        sourceText: trimmedText,
      );
      final copiedAudioPath = await _copyAudioFile(projectId, audioPath);
      await database.updateProjectAudioPath(projectId, copiedAudioPath);
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
        final audioFile = File(project.audioPath);
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
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

  Future<File> exportWrongWordsCsv({int? projectId}) async {
    final rows = await database.getWrongWords(projectId: projectId);
    final csv = CsvExporter.buildWrongWordsCsv(rows);
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(p.join(directory.path, 'deutschflow_wrong_words_$timestamp.csv'));
    await file.writeAsString(csv, flush: true);
    return file;
  }

  Future<String> _copyAudioFile(int projectId, String originalPath) async {
    final source = File(originalPath);
    if (!await source.exists()) {
      return originalPath;
    }

    final documents = await getApplicationDocumentsDirectory();
    final audioDirectory = Directory(p.join(documents.path, 'DeutschFlowAudio'));
    if (!await audioDirectory.exists()) {
      await audioDirectory.create(recursive: true);
    }

    final extension = p.extension(originalPath).isEmpty ? '.mp3' : p.extension(originalPath);
    final target = File(p.join(audioDirectory.path, 'project_$projectId$extension'));
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

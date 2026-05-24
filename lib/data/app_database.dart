import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/study_project.dart';
import '../models/study_sentence.dart';
import '../models/word_comparison.dart';
import '../models/wrong_word.dart';

class AppDatabase extends GeneratedDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (_) async => _createSchema(),
        beforeOpen: (_) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _createSchema() async {
    await customStatement('PRAGMA foreign_keys = ON');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        audio_path TEXT NOT NULL DEFAULT '',
        source_text TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        timeline_completed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS sentences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        position_index INTEGER NOT NULL,
        text TEXT NOT NULL,
        start_ms INTEGER NOT NULL DEFAULT 0,
        end_ms INTEGER NOT NULL DEFAULT 0,
        note TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS dictations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        sentence_id INTEGER NOT NULL,
        user_input TEXT NOT NULL,
        checked_at INTEGER NOT NULL,
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE,
        FOREIGN KEY(sentence_id) REFERENCES sentences(id) ON DELETE CASCADE
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS wrong_words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        sentence_id INTEGER NOT NULL,
        wrong_form TEXT NOT NULL,
        correct_form TEXT NOT NULL,
        sentence_text TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE,
        FOREIGN KEY(sentence_id) REFERENCES sentences(id) ON DELETE CASCADE
      )
    ''');

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sentences_project ON sentences(project_id, position_index)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_wrong_words_project ON wrong_words(project_id, created_at DESC)',
    );
  }

  Future<int> createProject({
    required String name,
    required String sourceText,
  }) {
    return customInsert(
      '''
      INSERT INTO projects (name, source_text, created_at)
      VALUES (?, ?, ?)
      ''',
      variables: [
        Variable.withString(name),
        Variable.withString(sourceText),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
      ],
    );
  }

  Future<void> updateProjectAudioPath(int projectId, String audioPath) async {
    await customUpdate(
      'UPDATE projects SET audio_path = ? WHERE id = ?',
      variables: [Variable.withString(audioPath), Variable.withInt(projectId)],
    );
  }

  Future<void> markTimelineCompleted(int projectId) async {
    await customUpdate(
      'UPDATE projects SET timeline_completed = 1 WHERE id = ?',
      variables: [Variable.withInt(projectId)],
    );
  }

  Future<void> deleteProject(int projectId) async {
    await customUpdate(
      'DELETE FROM projects WHERE id = ?',
      variables: [Variable.withInt(projectId)],
    );
  }

  Future<List<StudyProject>> getProjects() async {
    final rows = await customSelect('''
      SELECT
        p.id,
        p.name,
        p.audio_path,
        p.source_text,
        p.created_at,
        p.timeline_completed,
        COUNT(s.id) AS sentence_count,
        COALESCE(SUM(CASE WHEN s.end_ms > 0 THEN 1 ELSE 0 END), 0) AS annotated_count
      FROM projects p
      LEFT JOIN sentences s ON s.project_id = p.id
      GROUP BY p.id
      ORDER BY p.created_at DESC
    ''').get();

    return rows.map(_projectFromRow).toList(growable: false);
  }

  Future<StudyProject?> getProject(int projectId) async {
    final rows = await customSelect(
      '''
      SELECT
        p.id,
        p.name,
        p.audio_path,
        p.source_text,
        p.created_at,
        p.timeline_completed,
        COUNT(s.id) AS sentence_count,
        COALESCE(SUM(CASE WHEN s.end_ms > 0 THEN 1 ELSE 0 END), 0) AS annotated_count
      FROM projects p
      LEFT JOIN sentences s ON s.project_id = p.id
      WHERE p.id = ?
      GROUP BY p.id
      LIMIT 1
      ''',
      variables: [Variable.withInt(projectId)],
    ).get();

    if (rows.isEmpty) {
      return null;
    }
    return _projectFromRow(rows.first);
  }

  Future<void> insertSentences(int projectId, List<String> sentences) async {
    await transaction(() async {
      for (var index = 0; index < sentences.length; index++) {
        await customInsert(
          '''
          INSERT INTO sentences (project_id, position_index, text)
          VALUES (?, ?, ?)
          ''',
          variables: [
            Variable.withInt(projectId),
            Variable.withInt(index),
            Variable.withString(sentences[index]),
          ],
        );
      }
    });
  }

  Future<List<StudySentence>> getSentencesForProject(int projectId) async {
    final rows = await customSelect(
      '''
      SELECT id, project_id, position_index, text, start_ms, end_ms, note
      FROM sentences
      WHERE project_id = ?
      ORDER BY position_index ASC
      ''',
      variables: [Variable.withInt(projectId)],
    ).get();

    return rows.map(_sentenceFromRow).toList(growable: false);
  }

  Future<void> updateSentenceTimes(
    int sentenceId, {
    int? startMs,
    int? endMs,
  }) async {
    final setters = <String>[];
    final variables = <Variable>[];

    if (startMs != null) {
      setters.add('start_ms = ?');
      variables.add(Variable.withInt(startMs));
    }
    if (endMs != null) {
      setters.add('end_ms = ?');
      variables.add(Variable.withInt(endMs));
    }

    if (setters.isEmpty) {
      return;
    }

    variables.add(Variable.withInt(sentenceId));
    await customUpdate(
      'UPDATE sentences SET ${setters.join(', ')} WHERE id = ?',
      variables: variables,
    );
  }

  Future<void> updateSentenceNote(int sentenceId, String note) async {
    await customUpdate(
      'UPDATE sentences SET note = ? WHERE id = ?',
      variables: [Variable.withString(note), Variable.withInt(sentenceId)],
    );
  }

  Future<void> saveDictation({
    required int projectId,
    required int sentenceId,
    required String userInput,
  }) async {
    await customInsert(
      '''
      INSERT INTO dictations (project_id, sentence_id, user_input, checked_at)
      VALUES (?, ?, ?, ?)
      ''',
      variables: [
        Variable.withInt(projectId),
        Variable.withInt(sentenceId),
        Variable.withString(userInput),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
      ],
    );
  }

  Future<Map<int, String>> getLatestDictations(int projectId) async {
    final rows = await customSelect(
      '''
      SELECT d.sentence_id, d.user_input
      FROM dictations d
      INNER JOIN (
        SELECT sentence_id, MAX(checked_at) AS latest_checked_at
        FROM dictations
        WHERE project_id = ?
        GROUP BY sentence_id
      ) latest
        ON latest.sentence_id = d.sentence_id
       AND latest.latest_checked_at = d.checked_at
      WHERE d.project_id = ?
      ''',
      variables: [Variable.withInt(projectId), Variable.withInt(projectId)],
    ).get();

    return {
      for (final row in rows)
        row.read<int>('sentence_id'): row.read<String>('user_input'),
    };
  }

  Future<void> insertWrongWords({
    required int projectId,
    required int sentenceId,
    required String sentenceText,
    required List<WrongWordDraft> errors,
  }) async {
    if (errors.isEmpty) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await transaction(() async {
      for (final error in errors) {
        await customInsert(
          '''
          INSERT INTO wrong_words (
            project_id,
            sentence_id,
            wrong_form,
            correct_form,
            sentence_text,
            created_at
          ) VALUES (?, ?, ?, ?, ?, ?)
          ''',
          variables: [
            Variable.withInt(projectId),
            Variable.withInt(sentenceId),
            Variable.withString(error.wrongForm),
            Variable.withString(error.correctForm),
            Variable.withString(sentenceText),
            Variable.withInt(now),
          ],
        );
      }
    });
  }

  Future<List<WrongWord>> getWrongWords({int? projectId}) async {
    final whereClause = projectId == null ? '' : 'WHERE w.project_id = ?';
    final rows = await customSelect(
      '''
      SELECT
        w.id,
        w.project_id,
        w.sentence_id,
        w.wrong_form,
        w.correct_form,
        w.sentence_text,
        w.created_at,
        p.name AS project_name
      FROM wrong_words w
      INNER JOIN projects p ON p.id = w.project_id
      $whereClause
      ORDER BY w.created_at DESC, w.id DESC
      ''',
      variables: projectId == null ? const [] : [Variable.withInt(projectId)],
    ).get();

    return rows.map(_wrongWordFromRow).toList(growable: false);
  }

  StudyProject _projectFromRow(QueryRow row) {
    return StudyProject(
      id: row.read<int>('id'),
      name: row.read<String>('name'),
      audioPath: row.read<String>('audio_path'),
      sourceText: row.read<String>('source_text'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
      timelineCompleted: row.read<int>('timeline_completed') == 1,
      sentenceCount: row.readNullable<int>('sentence_count') ?? 0,
      annotatedCount: row.readNullable<int>('annotated_count') ?? 0,
    );
  }

  StudySentence _sentenceFromRow(QueryRow row) {
    return StudySentence(
      id: row.read<int>('id'),
      projectId: row.read<int>('project_id'),
      position: row.read<int>('position_index'),
      text: row.read<String>('text'),
      startMs: row.read<int>('start_ms'),
      endMs: row.read<int>('end_ms'),
      note: row.read<String>('note'),
    );
  }

  WrongWord _wrongWordFromRow(QueryRow row) {
    return WrongWord(
      id: row.read<int>('id'),
      projectId: row.read<int>('project_id'),
      sentenceId: row.read<int>('sentence_id'),
      wrongForm: row.read<String>('wrong_form'),
      correctForm: row.read<String>('correct_form'),
      sentenceText: row.read<String>('sentence_text'),
      projectName: row.read<String>('project_name'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
    );
  }
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final databaseFile = File(p.join(directory.path, 'deutschflow.sqlite'));
    return NativeDatabase.createInBackground(databaseFile);
  });
}

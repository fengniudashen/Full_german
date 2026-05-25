import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';
import '../models/practice_session.dart';
import '../models/study_project.dart';
import '../models/study_sentence.dart';
import '../models/word_comparison.dart';
import '../models/wrong_word.dart';

class AppDatabase extends GeneratedDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (_) async => _createSchema(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await _upgradeToV2();
          }
        },
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
        bookmarked INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS dictations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        sentence_id INTEGER NOT NULL,
        user_input TEXT NOT NULL,
        correct_count INTEGER NOT NULL DEFAULT 0,
        wrong_count INTEGER NOT NULL DEFAULT 0,
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
        mastered INTEGER NOT NULL DEFAULT 0,
        review_count INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE,
        FOREIGN KEY(sentence_id) REFERENCES sentences(id) ON DELETE CASCADE
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS practice_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        started_at INTEGER NOT NULL,
        sentences_practiced INTEGER NOT NULL DEFAULT 0,
        correct_count INTEGER NOT NULL DEFAULT 0,
        wrong_count INTEGER NOT NULL DEFAULT 0,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sentences_project ON sentences(project_id, position_index)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_wrong_words_project ON wrong_words(project_id, created_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dictations_project ON dictations(project_id, checked_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sessions_project ON practice_sessions(project_id, started_at DESC)',
    );
  }

  Future<void> _upgradeToV2() async {
    // Add new columns with defaults if they don't exist
    try {
      await customStatement(
          'ALTER TABLE sentences ADD COLUMN bookmarked INTEGER NOT NULL DEFAULT 0');
    } catch (_) {}
    try {
      await customStatement(
          'ALTER TABLE dictations ADD COLUMN correct_count INTEGER NOT NULL DEFAULT 0');
    } catch (_) {}
    try {
      await customStatement(
          'ALTER TABLE dictations ADD COLUMN wrong_count INTEGER NOT NULL DEFAULT 0');
    } catch (_) {}
    try {
      await customStatement(
          'ALTER TABLE wrong_words ADD COLUMN mastered INTEGER NOT NULL DEFAULT 0');
    } catch (_) {}
    try {
      await customStatement(
          'ALTER TABLE wrong_words ADD COLUMN review_count INTEGER NOT NULL DEFAULT 0');
    } catch (_) {}

    await customStatement('''
      CREATE TABLE IF NOT EXISTS practice_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        started_at INTEGER NOT NULL,
        sentences_practiced INTEGER NOT NULL DEFAULT 0,
        correct_count INTEGER NOT NULL DEFAULT 0,
        wrong_count INTEGER NOT NULL DEFAULT 0,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    try {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_dictations_project ON dictations(project_id, checked_at DESC)',
      );
    } catch (_) {}
    try {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_sessions_project ON practice_sessions(project_id, started_at DESC)',
      );
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════
  //  SETTINGS
  // ═══════════════════════════════════════════════════════════

  Future<AppSettings> getSettings() async {
    final rows = await customSelect('SELECT key, value FROM settings').get();
    final map = {for (final r in rows) r.read<String>('key'): r.read<String>('value')};
    return AppSettings(
      themeMode: map['theme_mode'] ?? 'system',
      playbackSpeed: double.tryParse(map['playback_speed'] ?? '') ?? 1.0,
      autoAdvance: map['auto_advance'] != 'false',
      showHints: map['show_hints'] == 'true',
      dailyGoal: int.tryParse(map['daily_goal'] ?? '') ?? 20,
    );
  }

  Future<void> saveSetting(String key, String value) async {
    await customInsert(
      'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
      variables: [Variable.withString(key), Variable.withString(value)],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  PROJECTS
  // ═══════════════════════════════════════════════════════════

  Future<int> createProject({
    required String name,
    required String sourceText,
  }) {
    return customInsert(
      'INSERT INTO projects (name, source_text, created_at) VALUES (?, ?, ?)',
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
        p.id, p.name, p.audio_path, p.source_text, p.created_at,
        p.timeline_completed,
        COUNT(s.id) AS sentence_count,
        COALESCE(SUM(CASE WHEN s.end_ms > 0 THEN 1 ELSE 0 END), 0) AS annotated_count,
        (SELECT COUNT(DISTINCT d.sentence_id)
         FROM dictations d WHERE d.project_id = p.id) AS dictated_count,
        (SELECT COUNT(*) FROM wrong_words w
         WHERE w.project_id = p.id AND w.mastered = 0) AS wrong_word_count,
        (SELECT MAX(d2.checked_at) FROM dictations d2
         WHERE d2.project_id = p.id) AS last_practiced
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
        p.id, p.name, p.audio_path, p.source_text, p.created_at,
        p.timeline_completed,
        COUNT(s.id) AS sentence_count,
        COALESCE(SUM(CASE WHEN s.end_ms > 0 THEN 1 ELSE 0 END), 0) AS annotated_count,
        (SELECT COUNT(DISTINCT d.sentence_id)
         FROM dictations d WHERE d.project_id = p.id) AS dictated_count,
        (SELECT COUNT(*) FROM wrong_words w
         WHERE w.project_id = p.id AND w.mastered = 0) AS wrong_word_count,
        (SELECT MAX(d2.checked_at) FROM dictations d2
         WHERE d2.project_id = p.id) AS last_practiced
      FROM projects p
      LEFT JOIN sentences s ON s.project_id = p.id
      WHERE p.id = ?
      GROUP BY p.id
      LIMIT 1
      ''',
      variables: [Variable.withInt(projectId)],
    ).get();
    if (rows.isEmpty) return null;
    return _projectFromRow(rows.first);
  }

  // ═══════════════════════════════════════════════════════════
  //  SENTENCES
  // ═══════════════════════════════════════════════════════════

  Future<void> insertSentences(int projectId, List<String> sentences) async {
    await transaction(() async {
      for (var i = 0; i < sentences.length; i++) {
        await customInsert(
          'INSERT INTO sentences (project_id, position_index, text) VALUES (?, ?, ?)',
          variables: [
            Variable.withInt(projectId),
            Variable.withInt(i),
            Variable.withString(sentences[i]),
          ],
        );
      }
    });
  }

  /// Insert sentences with pre-set timestamps (e.g. from subtitle files).
  Future<void> insertTimedSentences(
    int projectId,
    List<({String text, int startMs, int endMs})> entries,
  ) async {
    await transaction(() async {
      for (var i = 0; i < entries.length; i++) {
        final e = entries[i];
        await customInsert(
          'INSERT INTO sentences (project_id, position_index, text, start_ms, end_ms) '
          'VALUES (?, ?, ?, ?, ?)',
          variables: [
            Variable.withInt(projectId),
            Variable.withInt(i),
            Variable.withString(e.text),
            Variable.withInt(e.startMs),
            Variable.withInt(e.endMs),
          ],
        );
      }
    });
  }

  Future<List<StudySentence>> getSentencesForProject(int projectId) async {
    final rows = await customSelect(
      '''
      SELECT s.id, s.project_id, s.position_index, s.text,
             s.start_ms, s.end_ms, s.note, s.bookmarked,
             COALESCE(
               (SELECT d.user_input FROM dictations d
                WHERE d.sentence_id = s.id ORDER BY d.checked_at DESC LIMIT 1),
               ''
             ) AS last_dictation,
             (SELECT COUNT(*) FROM dictations d2
              WHERE d2.sentence_id = s.id AND d2.wrong_count = 0) AS correct_count,
             (SELECT COUNT(*) FROM dictations d3
              WHERE d3.sentence_id = s.id) AS attempt_count
      FROM sentences s
      WHERE s.project_id = ?
      ORDER BY s.position_index ASC
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
    if (setters.isEmpty) return;
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

  Future<void> toggleBookmark(int sentenceId, bool bookmarked) async {
    await customUpdate(
      'UPDATE sentences SET bookmarked = ? WHERE id = ?',
      variables: [
        Variable.withInt(bookmarked ? 1 : 0),
        Variable.withInt(sentenceId),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  DICTATIONS
  // ═══════════════════════════════════════════════════════════

  Future<void> saveDictation({
    required int projectId,
    required int sentenceId,
    required String userInput,
    required int correctCount,
    required int wrongCount,
  }) async {
    await customInsert(
      '''
      INSERT INTO dictations
        (project_id, sentence_id, user_input, correct_count, wrong_count, checked_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      variables: [
        Variable.withInt(projectId),
        Variable.withInt(sentenceId),
        Variable.withString(userInput),
        Variable.withInt(correctCount),
        Variable.withInt(wrongCount),
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
        SELECT sentence_id, MAX(checked_at) AS latest
        FROM dictations WHERE project_id = ?
        GROUP BY sentence_id
      ) latest ON latest.sentence_id = d.sentence_id AND latest.latest = d.checked_at
      WHERE d.project_id = ?
      ''',
      variables: [Variable.withInt(projectId), Variable.withInt(projectId)],
    ).get();
    return {
      for (final row in rows)
        row.read<int>('sentence_id'): row.read<String>('user_input'),
    };
  }

  // ═══════════════════════════════════════════════════════════
  //  WRONG WORDS
  // ═══════════════════════════════════════════════════════════

  Future<void> insertWrongWords({
    required int projectId,
    required int sentenceId,
    required String sentenceText,
    required List<WrongWordDraft> errors,
  }) async {
    if (errors.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await transaction(() async {
      for (final e in errors) {
        await customInsert(
          '''
          INSERT INTO wrong_words
            (project_id, sentence_id, wrong_form, correct_form, sentence_text, created_at)
          VALUES (?, ?, ?, ?, ?, ?)
          ''',
          variables: [
            Variable.withInt(projectId),
            Variable.withInt(sentenceId),
            Variable.withString(e.wrongForm),
            Variable.withString(e.correctForm),
            Variable.withString(sentenceText),
            Variable.withInt(now),
          ],
        );
      }
    });
  }

  Future<List<WrongWord>> getWrongWords({int? projectId, bool? mastered}) async {
    final clauses = <String>[];
    final vars = <Variable>[];
    if (projectId != null) {
      clauses.add('w.project_id = ?');
      vars.add(Variable.withInt(projectId));
    }
    if (mastered != null) {
      clauses.add('w.mastered = ?');
      vars.add(Variable.withInt(mastered ? 1 : 0));
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final rows = await customSelect(
      '''
      SELECT w.id, w.project_id, w.sentence_id,
             w.wrong_form, w.correct_form, w.sentence_text,
             w.created_at, w.mastered, w.review_count,
             p.name AS project_name
      FROM wrong_words w
      INNER JOIN projects p ON p.id = w.project_id
      $where
      ORDER BY w.created_at DESC, w.id DESC
      ''',
      variables: vars,
    ).get();
    return rows.map(_wrongWordFromRow).toList(growable: false);
  }

  Future<void> markWordMastered(int wordId, bool mastered) async {
    await customUpdate(
      'UPDATE wrong_words SET mastered = ?, review_count = review_count + 1 WHERE id = ?',
      variables: [
        Variable.withInt(mastered ? 1 : 0),
        Variable.withInt(wordId),
      ],
    );
  }

  Future<int> getUnmasteredCount() async {
    final rows = await customSelect(
      'SELECT COUNT(*) AS cnt FROM wrong_words WHERE mastered = 0',
    ).get();
    return rows.first.read<int>('cnt');
  }

  // ═══════════════════════════════════════════════════════════
  //  PRACTICE SESSIONS
  // ═══════════════════════════════════════════════════════════

  Future<int> createSession(int projectId) {
    return customInsert(
      'INSERT INTO practice_sessions (project_id, started_at) VALUES (?, ?)',
      variables: [
        Variable.withInt(projectId),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
      ],
    );
  }

  Future<void> updateSession({
    required int sessionId,
    required int sentencesPracticed,
    required int correctCount,
    required int wrongCount,
    required int durationMs,
  }) async {
    await customUpdate(
      '''
      UPDATE practice_sessions
      SET sentences_practiced = ?, correct_count = ?,
          wrong_count = ?, duration_ms = ?
      WHERE id = ?
      ''',
      variables: [
        Variable.withInt(sentencesPracticed),
        Variable.withInt(correctCount),
        Variable.withInt(wrongCount),
        Variable.withInt(durationMs),
        Variable.withInt(sessionId),
      ],
    );
  }

  Future<List<PracticeSession>> getSessions({int? limit}) async {
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final rows = await customSelect('''
      SELECT ps.id, ps.project_id, ps.started_at,
             ps.sentences_practiced, ps.correct_count,
             ps.wrong_count, ps.duration_ms,
             p.name AS project_name
      FROM practice_sessions ps
      INNER JOIN projects p ON p.id = ps.project_id
      ORDER BY ps.started_at DESC
      $limitClause
    ''').get();
    return rows.map(_sessionFromRow).toList(growable: false);
  }

  Future<List<DailyStats>> getDailyStats({int days = 30}) async {
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    final rows = await customSelect(
      '''
      SELECT
        date(checked_at / 1000, 'unixepoch', 'localtime') AS day,
        COUNT(*) AS sentences_practiced,
        SUM(correct_count) AS correct_count,
        SUM(wrong_count) AS wrong_count
      FROM dictations
      WHERE checked_at >= ?
      GROUP BY day
      ORDER BY day ASC
      ''',
      variables: [Variable.withInt(since)],
    ).get();
    return rows.map((r) {
      final dayStr = r.read<String>('day');
      final parts = dayStr.split('-');
      return DailyStats(
        date: DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        ),
        sentencesPracticed: r.read<int>('sentences_practiced'),
        correctCount: r.read<int>('correct_count'),
        wrongCount: r.read<int>('wrong_count'),
        practiceTimeMs: 0,
      );
    }).toList(growable: false);
  }

  Future<int> getTotalSentencesPracticed() async {
    final rows = await customSelect(
      'SELECT COUNT(DISTINCT sentence_id) AS cnt FROM dictations',
    ).get();
    return rows.first.read<int>('cnt');
  }

  Future<int> getStreakDays() async {
    final rows = await customSelect('''
      SELECT DISTINCT date(checked_at / 1000, 'unixepoch', 'localtime') AS day
      FROM dictations
      ORDER BY day DESC
    ''').get();
    if (rows.isEmpty) return 0;

    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final days = rows.map((r) => r.read<String>('day')).toList();
    if (days.first != todayStr) {
      // Check if yesterday counts
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      if (days.first != yesterdayStr) return 0;
    }

    int streak = 1;
    for (int i = 1; i < days.length; i++) {
      final prev = DateTime.parse(days[i - 1]);
      final curr = DateTime.parse(days[i]);
      if (prev.difference(curr).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  // ═══════════════════════════════════════════════════════════
  //  SEARCH
  // ═══════════════════════════════════════════════════════════

  Future<List<StudySentence>> searchSentences(String query) async {
    if (query.trim().isEmpty) return const [];
    final pattern = '%${query.trim()}%';
    final rows = await customSelect(
      '''
      SELECT s.id, s.project_id, s.position_index, s.text,
             s.start_ms, s.end_ms, s.note, s.bookmarked,
             '' AS last_dictation, 0 AS correct_count, 0 AS attempt_count
      FROM sentences s
      WHERE s.text LIKE ?
      ORDER BY s.project_id, s.position_index
      LIMIT 100
      ''',
      variables: [Variable.withString(pattern)],
    ).get();
    return rows.map(_sentenceFromRow).toList(growable: false);
  }

  // ═══════════════════════════════════════════════════════════
  //  ROW MAPPERS
  // ═══════════════════════════════════════════════════════════

  StudyProject _projectFromRow(QueryRow row) {
    final lastPracticed = row.readNullable<int>('last_practiced');
    return StudyProject(
      id: row.read<int>('id'),
      name: row.read<String>('name'),
      audioPath: row.read<String>('audio_path'),
      sourceText: row.read<String>('source_text'),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
      timelineCompleted: row.read<int>('timeline_completed') == 1,
      sentenceCount: row.readNullable<int>('sentence_count') ?? 0,
      annotatedCount: row.readNullable<int>('annotated_count') ?? 0,
      dictatedCount: row.readNullable<int>('dictated_count') ?? 0,
      wrongWordCount: row.readNullable<int>('wrong_word_count') ?? 0,
      lastPracticedAt: lastPracticed == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastPracticed),
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
      bookmarked: row.read<int>('bookmarked') == 1,
      lastDictation: row.read<String>('last_dictation'),
      correctCount: row.read<int>('correct_count'),
      attemptCount: row.read<int>('attempt_count'),
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
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
      mastered: row.read<int>('mastered') == 1,
      reviewCount: row.read<int>('review_count'),
    );
  }

  PracticeSession _sessionFromRow(QueryRow row) {
    return PracticeSession(
      id: row.read<int>('id'),
      projectId: row.read<int>('project_id'),
      projectName: row.read<String>('project_name'),
      startedAt:
          DateTime.fromMillisecondsSinceEpoch(row.read<int>('started_at')),
      sentencesPracticed: row.read<int>('sentences_practiced'),
      correctCount: row.read<int>('correct_count'),
      wrongCount: row.read<int>('wrong_count'),
      durationMs: row.read<int>('duration_ms'),
    );
  }
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'deutschflow.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

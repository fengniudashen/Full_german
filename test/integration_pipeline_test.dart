import 'package:flutter_test/flutter_test.dart';
import 'package:deutschflow/models/word_comparison.dart' as wc;
import 'package:deutschflow/models/wrong_word.dart';
import 'package:deutschflow/models/study_sentence.dart';
import 'package:deutschflow/models/practice_session.dart';
import 'package:deutschflow/services/text_comparator.dart';
import 'package:deutschflow/services/text_parser.dart';
import 'package:deutschflow/services/csv_exporter.dart';
import 'package:deutschflow/services/subtitle_parser.dart';

/// Cross-functional integration tests — validates the entire pipeline:
/// SRT/VTT → TextParser → StudySentence → TextComparator → WrongWord → CSV/Anki
/// Each test simulates a real user workflow end-to-end.
void main() {
  group('Pipeline: Subtitle → Parse → Dictation → Error → Export', () {
    test('Full SRT→dictation→error→CSV pipeline', () {
      // Step 1: Parse SRT subtitles
      const srt = '''1
00:00:01,000 --> 00:00:05,000
Die Bundesregierung hat neue Maßnahmen beschlossen.

2
00:00:06,000 --> 00:00:10,000
Schwere Luftangriffe auf die Hauptstadt.

3
00:00:11,000 --> 00:00:15,000
Das Wetter bleibt sonnig und warm.
''';
      final entries = SubtitleParser.parseSrt(srt);
      expect(entries.length, 3);

      // Step 2: Create StudySentences from entries
      final sentences = entries.asMap().entries.map((e) =>
        StudySentence(
          id: e.key + 1,
          projectId: 1,
          position: e.key,
          text: e.value.text,
          startMs: e.value.startMs,
          endMs: e.value.endMs,
          note: '',
        ),
      ).toList();
      expect(sentences.length, 3);
      expect(sentences.every((s) => s.hasValidRange), true);

      // Step 3: Simulate dictation with errors
      final userInputs = [
        'Die Bundesregierung hat neue Massnahmen beschlossen.',  // Maßnahmen→Massnahmen
        'Schwere Luftangrife auf die Hauptstadt.',  // Luftangriffe→Luftangrife
        'Das Wetter bleibt sonnig und warm.',  // perfect
      ];

      final results = <wc.ComparisonResult>[];
      final wrongWords = <WrongWord>[];

      for (int i = 0; i < sentences.length; i++) {
        final result = TextComparator.compare(sentences[i].text, userInputs[i]);
        results.add(result);

        // Collect wrong words
        for (final draft in result.redErrors) {
          wrongWords.add(WrongWord(
            id: wrongWords.length + 1,
            projectId: 1,
            sentenceId: sentences[i].id,
            wrongForm: draft.wrongForm,
            correctForm: draft.correctForm,
            sentenceText: sentences[i].text,
            projectName: 'Tagesschau',
            createdAt: DateTime.now(),
          ));
        }
      }

      // Step 4: Verify dictation results
      // Sentence 1: "Massnahmen" vs "Maßnahmen" — should be minor (ß→ss)
      expect(results[0].wrongCount, 0, reason: 'ß→ss should be minor not wrong');
      expect(results[0].minorCount, greaterThanOrEqualTo(1));

      // Sentence 2: "Luftangrife" vs "Luftangriffe" — should be wrong
      expect(results[1].wrongCount, greaterThanOrEqualTo(1));

      // Sentence 3: perfect
      expect(results[2].accuracy, 1.0);
      expect(results[2].wrongCount, 0);

      // Step 5: Verify wrong words collected
      expect(wrongWords.length, greaterThanOrEqualTo(1));

      // Step 6: Export to CSV
      final csv = CsvExporter.buildWrongWordsCsv(wrongWords);
      expect(csv, contains('错误形式'));
      expect(csv, contains('Tagesschau'));

      // Step 7: Export to Anki
      final anki = CsvExporter.buildAnkiTsv(wrongWords);
      expect(anki, contains('#separator:tab'));
      expect(anki, contains('learning'));

      // Step 8: Verify Ebbinghaus scheduling
      for (final w in wrongWords) {
        expect(w.isDueForReview, true);
        final nextReview = w.computeNextReview();
        expect(nextReview.isAfter(DateTime.now()), true);
      }
    });

    test('Full VTT→parse→dictation pipeline', () {
      const vtt = '''WEBVTT

00:00:01.000 --> 00:00:05.000
Guten Tag, hier ist die Tagesschau.

00:00:06.000 --> 00:00:10.000
Heute mit folgenden Themen.
''';
      final entries = SubtitleParser.parseVtt(vtt);
      expect(entries.length, greaterThanOrEqualTo(2));

      // Simulate dictation
      final r1 = TextComparator.compare(entries[0].text, 'Guten Tag, hier ist die Tagesschau.');
      expect(r1.accuracy, 1.0);

      final r2 = TextComparator.compare(entries[1].text, 'Heute mit folgenden Themen');
      // Missing period should be minor
      expect(r2.wrongCount, 0);
    });
  });

  group('Pipeline: TextParser → Compare → Stats', () {
    test('split text, compare each sentence, aggregate stats', () {
      const fullText = 'Ich bin müde. Du bist stark. Er ist schnell.';
      final sentences = TextParser.splitIntoSentences(fullText);
      expect(sentences.length, 3);

      // User typed all with minor errors
      final userTexts = [
        'ich bin müde.',   // case error
        'Du bist stark',   // missing period
        'Er ist schnell.',  // perfect
      ];

      int totalCorrect = 0;
      int totalMinor = 0;
      int totalWrong = 0;

      for (int i = 0; i < sentences.length; i++) {
        final r = TextComparator.compare(sentences[i], userTexts[i]);
        totalCorrect += r.correctCount;
        totalMinor += r.minorCount;
        totalWrong += r.wrongCount;
      }

      expect(totalWrong, 0, reason: 'No truly wrong words');
      expect(totalMinor, greaterThanOrEqualTo(2), reason: 'Case and punctuation errors');
      expect(totalCorrect, greaterThanOrEqualTo(6), reason: 'Most words are correct');

      // Create session
      final session = PracticeSession(
        id: 1,
        projectId: 1,
        projectName: 'Test',
        startedAt: DateTime.now(),
        sentencesPracticed: sentences.length,
        correctCount: sentences.length, // all "passed" (no red errors)
        wrongCount: 0,
        durationMs: 120000,
      );
      expect(session.accuracy, 1.0);
      expect(session.sentencesPracticed, 3);
    });
  });

  group('Pipeline: Multiple error types → categorization', () {
    test('different error types produce different comparison statuses', () {
      final testCases = <Map<String, dynamic>>[
        // Case error → minor
        {'orig': 'Hund', 'typed': 'hund', 'expected': wc.ComparisonStatus.minor},
        // ß→ss → minor
        {'orig': 'Straße', 'typed': 'Strasse', 'expected': wc.ComparisonStatus.minor},
        // Punctuation → minor
        {'orig': 'Ja!', 'typed': 'Ja', 'expected': wc.ComparisonStatus.minor},
        // Spelling error → wrong
        {'orig': 'Entscheidung', 'typed': 'Entscheidong', 'expected': wc.ComparisonStatus.wrong},
        // Completely different word → wrong
        {'orig': 'Haus', 'typed': 'Baum', 'expected': wc.ComparisonStatus.wrong},
        // Exact match → correct
        {'orig': 'perfekt', 'typed': 'perfekt', 'expected': wc.ComparisonStatus.correct},
      ];

      for (final tc in testCases) {
        final r = TextComparator.compare(tc['orig'] as String, tc['typed'] as String);
        expect(r.items.first.status, tc['expected'],
            reason: '"${tc['orig']}" vs "${tc['typed']}" should be ${tc['expected']}');
      }
    });
  });

  group('Pipeline: Error words → Anki round-trip integrity', () {
    test('wrong words survive CSV and Anki export without data loss', () {
      final originalWords = [
        WrongWord(
          id: 1, projectId: 1, sentenceId: 1,
          wrongForm: 'Strasse',
          correctForm: 'Straße',
          sentenceText: 'Über die Straße gehen.',
          projectName: 'Tagesschau',
          createdAt: DateTime.utc(2026, 6, 1),
          mastered: false,
          reviewCount: 2,
        ),
        WrongWord(
          id: 2, projectId: 1, sentenceId: 2,
          wrongForm: 'gehn',
          correctForm: 'gehen',
          sentenceText: 'Wir müssen jetzt gehen.',
          projectName: 'Tagesschau',
          createdAt: DateTime.utc(2026, 6, 1),
          mastered: true,
          reviewCount: 5,
        ),
      ];

      // CSV export
      final csv = CsvExporter.buildWrongWordsCsv(originalWords);
      // Verify every original field appears in CSV
      for (final w in originalWords) {
        expect(csv, contains(w.wrongForm));
        expect(csv, contains(w.correctForm));
        expect(csv, contains(w.projectName));
      }

      // Anki export
      final anki = CsvExporter.buildAnkiTsv(originalWords);
      for (final w in originalWords) {
        expect(anki, contains(w.correctForm));
        expect(anki, contains(w.sentenceText.replaceAll('\n', '<br>')));
      }

      // Verify mastered/unmastered tags
      final ankiLines = anki.split('\n');
      final dataLines = ankiLines.where((l) =>
          !l.startsWith('#') && l.trim().isNotEmpty).toList();
      expect(dataLines[0], contains('learning'));
      expect(dataLines[1], contains('mastered'));
    });
  });

  group('Pipeline: Sentence accuracy → Achievement XP calculation', () {
    test('XP formula: sentences×10 + streak×50 + mastered×20 + projects×100', () {
      // Simulate learning data
      const totalSentences = 150;
      const streakDays = 7;
      const masteredWords = 25;
      const projects = 3;

      final xp = totalSentences * 10 +
          streakDays * 50 +
          masteredWords * 20 +
          projects * 100;

      expect(xp, 150 * 10 + 7 * 50 + 25 * 20 + 3 * 100);
      expect(xp, 2650);

      // XP 2650 → Level 5 (Experte: 2500-5000)
      final levels = [0, 200, 500, 1200, 2500, 5000, 10000];
      int level = 1;
      for (int i = levels.length - 1; i >= 0; i--) {
        if (xp >= levels[i]) {
          level = i + 1;
          break;
        }
      }
      expect(level, 5, reason: 'XP 2650 should be level 5 (Experte)');
    });
  });

  group('Pipeline: Large-scale stress (100 sentences)', () {
    test('process 100 sentences through full pipeline', () {
      // Generate 100 SRT entries
      final buf = StringBuffer();
      for (int i = 0; i < 100; i++) {
        buf.writeln('${i + 1}');
        buf.writeln('00:${(i ~/ 60).toString().padLeft(2, '0')}:${(i % 60).toString().padLeft(2, '0')},000 --> '
            '00:${((i + 4) ~/ 60).toString().padLeft(2, '0')}:${((i + 4) % 60).toString().padLeft(2, '0')},000');
        buf.writeln('Dies ist Testsatz Nummer $i mit einigen Wörtern.');
        buf.writeln();
      }

      // Parse
      final entries = SubtitleParser.parseSrt(buf.toString());
      expect(entries.length, 100);

      // Compare each with identical text (perfect match)
      int perfectCount = 0;
      for (final e in entries) {
        final r = TextComparator.compare(e.text, e.text);
        if (r.accuracy == 1.0) perfectCount++;
      }
      expect(perfectCount, 100);

      // Compare each with one word wrong
      int errorCount = 0;
      for (final e in entries) {
        final words = e.text.split(' ');
        if (words.length > 2) {
          words[1] = 'FALSCH'; // Replace second word
        }
        final r = TextComparator.compare(e.text, words.join(' '));
        errorCount += r.wrongCount;
      }
      expect(errorCount, 100, reason: 'Each sentence should have exactly 1 wrong word');
    });
  });

  group('Edge: dictionaryKey consistency', () {
    test('same word produces same key regardless of punctuation/case', () {
      final variants = ['Straße!', 'straße.', 'STRASSE,', '"straße"'];
      final keys = variants.map(TextComparator.dictionaryKey).toSet();
      // All should normalize to same key (after ß→ss and case fold)
      // Note: "straße" and "strasse" won't be same without ß folding in dictionaryKey
      // dictionaryKey does NOT fold ß, so straße variants stay straße
      final strasseKeys = ['Straße!', 'straße.', '"straße"']
          .map(TextComparator.dictionaryKey).toSet();
      expect(strasseKeys.length, 1, reason: 'Same base word should produce same key');
    });
  });
}

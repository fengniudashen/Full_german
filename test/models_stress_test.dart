import 'package:flutter_test/flutter_test.dart';
import 'package:deutschflow/models/wrong_word.dart';
import 'package:deutschflow/models/word_comparison.dart';
import 'package:deutschflow/models/practice_session.dart';
import 'package:deutschflow/models/study_sentence.dart';
import 'package:deutschflow/models/app_settings.dart';

/// Intensive model tests — WrongWord, StudySentence, PracticeSession,
/// AppSettings, WordComparison. Cross-validates model invariants.
void main() {
  group('WrongWord — Ebbinghaus scheduling', () {
    WrongWord makeWord({int reviewCount = 0, DateTime? nextReviewAt, bool mastered = false}) {
      return WrongWord(
        id: 1,
        projectId: 1,
        sentenceId: 1,
        wrongForm: 'habn',
        correctForm: 'haben',
        sentenceText: 'Wir haben Zeit.',
        projectName: 'Test',
        createdAt: DateTime.now(),
        mastered: mastered,
        reviewCount: reviewCount,
        nextReviewAt: nextReviewAt,
      );
    }

    test('first review interval is 1 hour', () {
      final w = makeWord(reviewCount: 0);
      final next = w.computeNextReview();
      final diff = next.difference(DateTime.now());
      expect(diff.inMinutes, closeTo(60, 2));
    });

    test('second review interval is 8 hours', () {
      final w = makeWord(reviewCount: 1);
      final next = w.computeNextReview();
      final diff = next.difference(DateTime.now());
      expect(diff.inHours, closeTo(8, 1));
    });

    test('eighth review interval is 30 days (720 hours)', () {
      final w = makeWord(reviewCount: 7);
      final next = w.computeNextReview();
      final diff = next.difference(DateTime.now());
      expect(diff.inHours, closeTo(720, 2));
    });

    test('review count beyond max clamps to last interval', () {
      final w = makeWord(reviewCount: 100);
      final next = w.computeNextReview();
      final diff = next.difference(DateTime.now());
      expect(diff.inHours, closeTo(720, 2));
    });

    test('intervals are strictly increasing', () {
      final intervals = WrongWord.ebIntervals;
      for (int i = 1; i < intervals.length; i++) {
        expect(intervals[i], greaterThan(intervals[i - 1]),
            reason: 'Interval $i should be > interval ${i - 1}');
      }
    });

    test('isDueForReview returns true when past review time', () {
      final w = makeWord(
        reviewCount: 0,
        nextReviewAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      expect(w.isDueForReview, true);
    });

    test('isDueForReview returns false when not yet due', () {
      final w = makeWord(
        reviewCount: 0,
        nextReviewAt: DateTime.now().add(const Duration(hours: 2)),
      );
      expect(w.isDueForReview, false);
    });

    test('isDueForReview returns true when nextReviewAt is null', () {
      final w = makeWord(reviewCount: 0, nextReviewAt: null);
      expect(w.isDueForReview, true);
    });

    test('mastered words are never due for review', () {
      final w = makeWord(
        mastered: true,
        nextReviewAt: DateTime.now().subtract(const Duration(days: 100)),
      );
      expect(w.isDueForReview, false);
    });
  });

  group('StudySentence', () {
    StudySentence makeSentence({
      int startMs = 1000,
      int endMs = 5000,
      int correctCount = 0,
      int attemptCount = 0,
      bool bookmarked = false,
      String lastDictation = '',
    }) {
      return StudySentence(
        id: 1,
        projectId: 1,
        position: 0,
        text: 'Ich lerne Deutsch.',
        startMs: startMs,
        endMs: endMs,
        note: '',
        bookmarked: bookmarked,
        lastDictation: lastDictation,
        correctCount: correctCount,
        attemptCount: attemptCount,
      );
    }

    test('start and end Duration getters', () {
      final s = makeSentence(startMs: 1500, endMs: 4500);
      expect(s.start, const Duration(milliseconds: 1500));
      expect(s.end, const Duration(milliseconds: 4500));
    });

    test('hasEndTime is true when endMs > 0', () {
      expect(makeSentence(endMs: 100).hasEndTime, true);
      expect(makeSentence(endMs: 0).hasEndTime, false);
    });

    test('hasValidRange checks endMs > startMs', () {
      expect(makeSentence(startMs: 100, endMs: 200).hasValidRange, true);
      expect(makeSentence(startMs: 200, endMs: 100).hasValidRange, false);
      expect(makeSentence(startMs: 100, endMs: 100).hasValidRange, false);
    });

    test('hasDictation checks lastDictation is non-empty', () {
      expect(makeSentence(lastDictation: '').hasDictation, false);
      expect(makeSentence(lastDictation: 'text').hasDictation, true);
    });

    test('accuracy calculation', () {
      expect(makeSentence(correctCount: 3, attemptCount: 4).accuracy, 0.75);
      expect(makeSentence(correctCount: 0, attemptCount: 0).accuracy, 0.0);
      expect(makeSentence(correctCount: 10, attemptCount: 10).accuracy, 1.0);
    });
  });

  group('PracticeSession', () {
    PracticeSession makeSession({
      int correct = 5,
      int wrong = 5,
      int durationMs = 60000,
    }) {
      return PracticeSession(
        id: 1,
        projectId: 1,
        projectName: 'Test',
        startedAt: DateTime.now(),
        sentencesPracticed: correct + wrong,
        correctCount: correct,
        wrongCount: wrong,
        durationMs: durationMs,
      );
    }

    test('accuracy is correct/total', () {
      expect(makeSession(correct: 7, wrong: 3).accuracy, 0.7);
    });

    test('accuracy is 1.0 when no wrong', () {
      expect(makeSession(correct: 10, wrong: 0).accuracy, 1.0);
    });

    test('accuracy is 0.0 when no correct', () {
      expect(makeSession(correct: 0, wrong: 10).accuracy, 0.0);
    });

    test('accuracy is 1.0 when both zero', () {
      expect(makeSession(correct: 0, wrong: 0).accuracy, 1.0);
    });

    test('duration getter', () {
      final s = makeSession(durationMs: 90000);
      expect(s.duration, const Duration(milliseconds: 90000));
      expect(s.duration.inSeconds, 90);
    });
  });

  group('AppSettings', () {
    test('default values', () {
      const s = AppSettings();
      expect(s.themeMode, 'system');
      expect(s.playbackSpeed, 1.0);
      expect(s.autoAdvance, true);
      expect(s.showHints, false);
      expect(s.dailyGoal, 20);
      expect(s.activeProviderId, 'deepseek');
      expect(s.useLocalWhisper, false);
      expect(s.whisperModel, 'base');
    });

    test('activeProvider resolves from presets', () {
      const s = AppSettings(activeProviderId: 'deepseek');
      final provider = s.activeProvider;
      expect(provider.id, 'deepseek');
      expect(provider.name, isNotEmpty);
      expect(provider.baseUrl, isNotEmpty);
    });

    test('custom API key is used for active provider', () {
      const s = AppSettings(
        activeProviderId: 'deepseek',
        providerKeys: {'deepseek': 'test-key-123'},
      );
      final provider = s.activeProvider;
      expect(provider.apiKey, 'test-key-123');
    });

    test('custom URL overrides default', () {
      const s = AppSettings(
        activeProviderId: 'deepseek',
        providerUrls: {'deepseek': 'https://custom.api.com/v1'},
      );
      final provider = s.activeProvider;
      expect(provider.baseUrl, 'https://custom.api.com/v1');
    });

    test('unknown provider falls back to first preset', () {
      const s = AppSettings(activeProviderId: 'nonexistent');
      final provider = s.activeProvider;
      expect(provider.id, isNotEmpty);
    });

    test('legacy deepseekApiKey is used when providerKeys is empty', () {
      const s = AppSettings(
        activeProviderId: 'deepseek',
        deepseekApiKey: 'legacy-key',
      );
      final provider = s.activeProvider;
      expect(provider.apiKey, 'legacy-key');
    });
  });

  group('WordComparison', () {
    test('isExtraWord when original is empty', () {
      const c = WordComparison(
        original: '',
        typed: 'extra',
        status: ComparisonStatus.wrong,
      );
      expect(c.isExtraWord, true);
      expect(c.isMissingWord, false);
    });

    test('isMissingWord when typed is empty', () {
      const c = WordComparison(
        original: 'missing',
        typed: '',
        status: ComparisonStatus.wrong,
      );
      expect(c.isMissingWord, true);
      expect(c.isExtraWord, false);
    });

    test('displayText for correct word', () {
      const c = WordComparison(
        original: 'Deutsch',
        typed: 'Deutsch',
        status: ComparisonStatus.correct,
      );
      expect(c.displayText, 'Deutsch');
    });

    test('displayText for wrong word shows both', () {
      const c = WordComparison(
        original: 'haben',
        typed: 'habn',
        status: ComparisonStatus.wrong,
      );
      expect(c.displayText, 'haben / habn');
    });

    test('displayText for missing word', () {
      const c = WordComparison(
        original: 'Wort',
        typed: '',
        status: ComparisonStatus.wrong,
      );
      expect(c.displayText, contains('漏词'));
    });

    test('displayText for extra word', () {
      const c = WordComparison(
        original: '',
        typed: 'extra',
        status: ComparisonStatus.wrong,
      );
      expect(c.displayText, contains('extra'));
    });
  });

  group('Cross-model validation', () {
    test('WrongWord created from ComparisonResult redErrors has valid data', () {
      // Simulate: user typed "habn" instead of "haben"
      final draft = WrongWordDraft(wrongForm: 'habn', correctForm: 'haben');
      final word = WrongWord(
        id: 1,
        projectId: 1,
        sentenceId: 1,
        wrongForm: draft.wrongForm,
        correctForm: draft.correctForm,
        sentenceText: 'Wir haben Zeit.',
        projectName: 'Test',
        createdAt: DateTime.now(),
      );

      expect(word.wrongForm, 'habn');
      expect(word.correctForm, 'haben');
      expect(word.isDueForReview, true);
      expect(word.mastered, false);
    });

    test('PracticeSession stats align with comparison counts', () {
      // Simulate: 10 sentences, 7 correct, 3 wrong
      final session = PracticeSession(
        id: 1,
        projectId: 1,
        projectName: 'Test',
        startedAt: DateTime.now(),
        sentencesPracticed: 10,
        correctCount: 7,
        wrongCount: 3,
        durationMs: 300000,
      );

      expect(session.accuracy, 0.7);
      expect(session.sentencesPracticed, 10);
      expect(session.duration.inMinutes, 5);
    });
  });
}

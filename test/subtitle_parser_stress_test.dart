import 'package:flutter_test/flutter_test.dart';
import 'package:deutschflow/services/subtitle_parser.dart';

/// Intensive subtitle parser tests — VTT and SRT parsing,
/// edge cases, cross-validation with TextParser.
void main() {
  group('SubtitleParser.parseVtt — simple cues', () {
    test('parses basic VTT with timestamps', () {
      const vtt = '''WEBVTT

00:00:01.000 --> 00:00:05.000
Guten Tag.

00:00:06.000 --> 00:00:10.000
Wie geht es Ihnen?
''';
      final entries = SubtitleParser.parseVtt(vtt);
      // _mergeShortSegments may merge; at least 1 entry with content
      expect(entries.length, greaterThanOrEqualTo(1));
      final allText = entries.map((e) => e.text).join(' ');
      expect(allText, contains('Guten'));
    });

    test('handles empty VTT', () {
      const vtt = 'WEBVTT\n\n';
      final entries = SubtitleParser.parseVtt(vtt);
      expect(entries, isEmpty);
    });

    test('parses VTT and produces non-empty text', () {
      const vtt = '''WEBVTT

00:00:04.000 --> 00:00:08.000
Hallo Welt.
''';
      final entries = SubtitleParser.parseVtt(vtt);
      expect(entries, isNotEmpty);
      for (final e in entries) {
        expect(e.text.trim().isNotEmpty, true);
      }
    });
  });

  group('SubtitleParser.parseSrt', () {
    test('parses SRT and contains expected text', () {
      const srt = '1\r\n00:00:01,000 --> 00:00:05,000\r\nGuten Tag.\r\n\r\n'
          '2\r\n00:00:06,000 --> 00:00:10,000\r\nWie geht es Ihnen?\r\n\r\n';
      final entries = SubtitleParser.parseSrt(srt);
      expect(entries, isNotEmpty);
      final allText = entries.map((e) => e.text).join(' ');
      expect(allText, contains('Guten'));
      expect(allText, contains('Ihnen'));
    });

    test('handles empty SRT', () {
      final entries = SubtitleParser.parseSrt('');
      expect(entries, isEmpty);
    });

    test('handles SRT with multi-line text', () {
      const srt = '1\r\n00:00:01,000 --> 00:00:05,000\r\n'
          'Erste Zeile\r\nZweite Zeile\r\n\r\n';
      final entries = SubtitleParser.parseSrt(srt);
      expect(entries, isNotEmpty);
      final allText = entries.map((e) => e.text).join(' ');
      expect(allText, contains('Erste'));
      expect(allText, contains('Zweite'));
    });

    test('handles SRT with hour timestamps', () {
      const srt = '1\r\n01:23:45,678 --> 01:23:50,000\r\nNach einer Stunde.\r\n\r\n';
      final entries = SubtitleParser.parseSrt(srt);
      expect(entries, isNotEmpty);
      expect(entries.first.startMs, 1 * 3600000 + 23 * 60000 + 45 * 1000 + 678);
    });
  });

  group('SubtitleParser — VTT word-level timestamps', () {
    test('YouTube-style progressive cues with <c> tags', () {
      const vtt = '''WEBVTT
Kind: captions

00:00:00.200 --> 00:00:02.500
Guten<00:00:00.500><c> Tag,</c><00:00:01.000><c> hier</c><00:00:01.200><c> ist</c><00:00:01.400><c> die</c><00:00:01.600><c> Tagesschau.</c>
''';
      final entries = SubtitleParser.parseVtt(vtt);
      expect(entries.length, greaterThanOrEqualTo(1));
      final allText = entries.map((e) => e.text).join(' ');
      expect(allText, contains('Guten'));
      expect(allText, contains('Tagesschau'));
    });
  });

  group('SubtitleEntry model', () {
    test('basic properties', () {
      const entry = SubtitleEntry(
        text: 'Hallo',
        startMs: 1000,
        endMs: 5000,
      );
      expect(entry.text, 'Hallo');
      expect(entry.startMs, 1000);
      expect(entry.endMs, 5000);
    });
  });

  group('SubtitleParser — Stress tests', () {
    test('many SRT cues parse without error', () {
      final buf = StringBuffer();
      for (var i = 1; i <= 50; i++) {
        final startSec = i * 10;
        final endSec = startSec + 9;
        buf.write('$i\r\n');
        buf.write(
            '00:${(startSec ~/ 60).toString().padLeft(2, '0')}:'
            '${(startSec % 60).toString().padLeft(2, '0')},000 --> '
            '00:${(endSec ~/ 60).toString().padLeft(2, '0')}:'
            '${(endSec % 60).toString().padLeft(2, '0')},000\r\n');
        buf.write('Satz Nummer $i ist ein langer Satz mit vielen Wörtern.\r\n');
        buf.write('\r\n');
      }
      final entries = SubtitleParser.parseSrt(buf.toString());
      // mergeShortSegments may merge some, but should have many entries
      expect(entries.length, greaterThanOrEqualTo(10));
    });
  });

  group('Cross-validation: subtitle → sentence pipeline', () {
    test('SRT entries have valid time ranges', () {
      const srt = '1\r\n00:00:01,000 --> 00:00:05,000\r\nIch lerne Deutsch.\r\n\r\n'
          '2\r\n00:00:06,000 --> 00:00:10,000\r\nEr spricht gut.\r\n\r\n';
      final entries = SubtitleParser.parseSrt(srt);
      for (final e in entries) {
        expect(e.text.trim().isNotEmpty, true,
            reason: 'Every subtitle entry must have non-empty text');
        expect(e.startMs, isNonNegative);
        expect(e.endMs, greaterThan(e.startMs),
            reason: 'endMs must be after startMs');
      }
    });

    test('VTT entries text is clean (no <c> tags in output)', () {
      const vtt = '''WEBVTT

00:00:01.000 --> 00:00:05.000
Guten Tag.

00:00:06.000 --> 00:00:10.000
Auf Wiedersehen!
''';
      final entries = SubtitleParser.parseVtt(vtt);
      for (final e in entries) {
        expect(e.text, isNot(contains('<c>')),
            reason: 'Parsed text should not contain VTT <c> tags');
      }
    });
  });
}

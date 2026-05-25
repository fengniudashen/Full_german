import 'dart:io';

/// Parses VTT / SRT subtitle files into timed segments.
class SubtitleParser {
  /// Parse a VTT or SRT file into a list of [SubtitleEntry].
  static Future<List<SubtitleEntry>> parseFile(String filePath) async {
    final content = await File(filePath).readAsString();
    if (filePath.endsWith('.vtt')) {
      return parseVtt(content);
    }
    return parseSrt(content);
  }

  /// Parse WebVTT content using word-level timestamps from YouTube auto-subs.
  /// YouTube VTT uses progressive cues with <c> tags containing word timestamps.
  static List<SubtitleEntry> parseVtt(String content) {
    // Step 1: Extract word-level timing from progressive cues
    final words = _extractWordTimings(content);
    if (words.isEmpty) {
      // Fallback: simple cue-level parsing
      return _parseVttSimple(content);
    }

    // Step 2: Group words into sentences based on punctuation
    return _wordsToSentences(words);
  }

  /// Extract word-level timings from YouTube VTT <c> tags.
  ///
  /// YouTube auto-subs use progressive cues:
  ///   Line 1: Previously completed text (plain, NO <c> tags) — repeat, skip
  ///   Line 2: New words with <c> tags and word-level timestamps — extract
  /// Static cues (0.01s, no <c> tags at all) are also skipped.
  static List<_TimedWord> _extractWordTimings(String content) {
    final words = <_TimedWord>[];
    final lines = content.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Look for timestamp lines
      if (!line.contains('-->')) continue;

      final times = line.split('-->');
      if (times.length != 2) continue;

      final cueStart = _parseVttTime(times[0].trim());
      if (cueStart == null) continue;

      // Read content lines after timestamp (skip blank lines)
      final contentLines = <String>[];
      var j = i + 1;
      while (j < lines.length) {
        final cl = lines[j].trim();
        // Stop at next timestamp or after content followed by blank
        if (cl.contains('-->')) break;
        if (cl.isNotEmpty) {
          contentLines.add(lines[j]);
        } else if (contentLines.isNotEmpty) {
          break; // blank line after content = end of cue
        }
        j++;
      }

      // Only process lines that contain <c> tags (= new words).
      // Lines without <c> tags are repeated text from prior cues.
      for (final cl in contentLines) {
        if (!cl.contains('<c>')) continue;

        // Extract the leading word before first timestamp tag
        final firstWordMatch = RegExp(r'^([^<]+?)(?:<\d)').firstMatch(cl);
        if (firstWordMatch != null) {
          final word = firstWordMatch.group(1)!.trim();
          if (word.isNotEmpty) {
            words.add(_TimedWord(word, cueStart));
          }
        }

        // Extract <timestamp><c> word</c> pairs
        final tagPattern = RegExp(
          r'<(\d{2}:\d{2}:\d{2}\.\d{3})><c>\s*([^<]+?)\s*</c>',
        );
        for (final match in tagPattern.allMatches(cl)) {
          final ts = _parseVttTime(match.group(1)!);
          final word = match.group(2)!.trim();
          if (ts != null && word.isNotEmpty) {
            words.add(_TimedWord(word, ts));
          }
        }
      }
    }

    return words;
  }

  /// Group timed words into sentences based on sentence-ending punctuation.
  static List<SubtitleEntry> _wordsToSentences(List<_TimedWord> words) {
    if (words.isEmpty) return [];

    final sentences = <SubtitleEntry>[];
    var sentenceWords = <_TimedWord>[];

    for (final word in words) {
      sentenceWords.add(word);

      // Check if this word ends a sentence.
      // A period after a number (e.g. "21.") is likely an ordinal, not a
      // sentence end, unless followed by a capital letter in the next word.
      final endsWithPunctuation = RegExp(r'[.!?]$').hasMatch(word.text);
      final isOrdinalNumber = RegExp(r'^\d+\.$').hasMatch(word.text);

      if (endsWithPunctuation && !isOrdinalNumber && sentenceWords.length >= 3) {
        // Create sentence
        final text = sentenceWords.map((w) => w.text).join(' ');
        sentences.add(SubtitleEntry(
          startMs: sentenceWords.first.timestampMs,
          endMs: sentenceWords.last.timestampMs + 500, // Add 500ms buffer
          text: text,
        ));
        sentenceWords = [];
      }
    }

    // Add remaining words as final sentence
    if (sentenceWords.isNotEmpty) {
      final text = sentenceWords.map((w) => w.text).join(' ');
      sentences.add(SubtitleEntry(
        startMs: sentenceWords.first.timestampMs,
        endMs: sentenceWords.last.timestampMs + 500,
        text: text,
      ));
    }

    return sentences;
  }

  /// Fallback simple VTT parser (for non-YouTube VTTs without word timing).
  static List<SubtitleEntry> _parseVttSimple(String content) {
    final entries = <SubtitleEntry>[];
    final lines = content.split('\n');
    int i = 0;

    // Skip header
    while (i < lines.length) {
      if (lines[i].contains('-->')) break;
      i++;
    }

    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.contains('-->')) {
        final times = line.split('-->');
        if (times.length == 2) {
          final start = _parseVttTime(times[0].trim());
          final end = _parseVttTime(times[1].trim().split(' ').first);

          final textLines = <String>[];
          i++;
          while (i < lines.length && lines[i].trim().isNotEmpty) {
            final cleaned = lines[i]
                .trim()
                .replaceAll(RegExp(r'<[^>]+>'), '')
                .trim();
            if (cleaned.isNotEmpty) textLines.add(cleaned);
            i++;
          }

          if (textLines.isNotEmpty && start != null && end != null) {
            entries.add(SubtitleEntry(
              startMs: start,
              endMs: end,
              text: textLines.join(' '),
            ));
          }
        }
      }
      i++;
    }

    return _mergeShortSegments(entries);
  }

  /// Parse SRT content.
  static List<SubtitleEntry> parseSrt(String content) {
    final entries = <SubtitleEntry>[];
    final blocks = content
        .split(RegExp(r'\n\s*\n'))
        .where((b) => b.trim().isNotEmpty);

    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 2) continue;

      final tsLine = lines.firstWhere(
        (l) => l.contains('-->'),
        orElse: () => '',
      );
      if (tsLine.isEmpty) continue;

      final times = tsLine.split('-->');
      if (times.length != 2) continue;

      final start = _parseSrtTime(times[0].trim());
      final end = _parseSrtTime(times[1].trim());

      final tsIndex = lines.indexOf(tsLine);
      final textLines = lines
          .sublist(tsIndex + 1)
          .map((l) => l.trim().replaceAll(RegExp(r'<[^>]+>'), '').trim())
          .where((l) => l.isNotEmpty)
          .toList();

      if (textLines.isNotEmpty && start != null && end != null) {
        entries.add(SubtitleEntry(
          startMs: start,
          endMs: end,
          text: textLines.join(' '),
        ));
      }
    }

    return _mergeShortSegments(entries);
  }

  /// Merge short consecutive segments into sentence-level blocks.
  static List<SubtitleEntry> _mergeShortSegments(List<SubtitleEntry> raw) {
    if (raw.isEmpty) return raw;

    // Remove duplicates
    final deduped = <SubtitleEntry>[];
    for (final entry in raw) {
      if (deduped.isEmpty || deduped.last.text != entry.text) {
        deduped.add(entry);
      } else {
        deduped[deduped.length - 1] = SubtitleEntry(
          startMs: deduped.last.startMs,
          endMs: entry.endMs,
          text: deduped.last.text,
        );
      }
    }

    // Merge into sentences
    final merged = <SubtitleEntry>[];
    SubtitleEntry? current;

    for (final entry in deduped) {
      if (current == null) {
        current = entry;
        continue;
      }

      final gap = entry.startMs - current.endMs;
      final combined = '${current.text} ${entry.text}';
      final currentText = current.text.trim();
      final endsWithPunctuation = RegExp(r'[.!?]$').hasMatch(currentText);

      final shouldMerge = gap < 3000 &&
          combined.length < 300 &&
          (!endsWithPunctuation || currentText.length < 20);

      if (shouldMerge) {
        current = SubtitleEntry(
          startMs: current.startMs,
          endMs: entry.endMs,
          text: combined,
        );
      } else {
        merged.add(current);
        current = entry;
      }
    }
    if (current != null) merged.add(current);

    return merged;
  }

  /// Parse VTT timestamp: "00:00:01.234" or "01.234"
  static int? _parseVttTime(String ts) {
    final clean = ts.split(' ').first.trim();
    final parts = clean.split(':');
    try {
      if (parts.length == 3) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final secParts = parts[2].split('.');
        final s = int.parse(secParts[0]);
        final ms = secParts.length > 1
            ? int.parse(secParts[1].padRight(3, '0').substring(0, 3))
            : 0;
        return h * 3600000 + m * 60000 + s * 1000 + ms;
      } else if (parts.length == 2) {
        final m = int.parse(parts[0]);
        final secParts = parts[1].split('.');
        final s = int.parse(secParts[0]);
        final ms = secParts.length > 1
            ? int.parse(secParts[1].padRight(3, '0').substring(0, 3))
            : 0;
        return m * 60000 + s * 1000 + ms;
      }
    } catch (_) {}
    return null;
  }

  /// Parse SRT timestamp: "00:00:01,234"
  static int? _parseSrtTime(String ts) {
    return _parseVttTime(ts.replaceAll(',', '.'));
  }
}

class _TimedWord {
  const _TimedWord(this.text, this.timestampMs);
  final String text;
  final int timestampMs;
}

class SubtitleEntry {
  const SubtitleEntry({
    required this.startMs,
    required this.endMs,
    required this.text,
  });
  final int startMs;
  final int endMs;
  final String text;
}

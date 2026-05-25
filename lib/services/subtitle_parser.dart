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

  /// Parse WebVTT content.
  static List<SubtitleEntry> parseVtt(String content) {
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
            // Remove VTT tags like <c> </c> <00:00:01.234>
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

    return _deduplicateAndMerge(entries);
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

      // Find the timestamp line
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

    return _deduplicateAndMerge(entries);
  }

  /// Merge short segments into sentence-level blocks.
  /// YouTube auto-subs often have overlapping/repeated fragments.
  static List<SubtitleEntry> _deduplicateAndMerge(List<SubtitleEntry> raw) {
    if (raw.isEmpty) return raw;

    // 1. Remove duplicates (same text, overlapping time)
    final deduped = <SubtitleEntry>[];
    for (final entry in raw) {
      if (deduped.isEmpty || deduped.last.text != entry.text) {
        deduped.add(entry);
      } else {
        // Extend end time
        deduped[deduped.length - 1] = SubtitleEntry(
          startMs: deduped.last.startMs,
          endMs: entry.endMs,
          text: deduped.last.text,
        );
      }
    }

    // 2. Merge short consecutive segments into sentence-level blocks.
    // YouTube auto-subs produce fragments of 1-5 words each.
    // We merge aggressively until we detect sentence boundaries.
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

      // Check if current segment ends a sentence
      final endsWithSentencePunctuation =
          RegExp(r'[.!?]$').hasMatch(currentText);

      // Merge conditions:
      // - Gap < 3s (allow pauses within sentences)
      // - Combined text < 300 chars (don't make overly long sentences)
      // - Current segment doesn't end with sentence punctuation
      // - OR current text is very short (< 20 chars) — probably not a full sentence
      final shouldMerge = gap < 3000 &&
          combined.length < 300 &&
          (!endsWithSentencePunctuation || currentText.length < 20);

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

    // 3. Post-process: merge any remaining very short segments (< 15 chars)
    // with the next segment
    final result = <SubtitleEntry>[];
    for (var i = 0; i < merged.length; i++) {
      if (i < merged.length - 1 && merged[i].text.trim().length < 15) {
        // Merge with next
        final next = merged[i + 1];
        merged[i + 1] = SubtitleEntry(
          startMs: merged[i].startMs,
          endMs: next.endMs,
          text: '${merged[i].text} ${next.text}',
        );
      } else {
        result.add(merged[i]);
      }
    }

    return result;
  }

  /// Parse VTT timestamp: "00:00:01.234" or "01.234"
  static int? _parseVttTime(String ts) {
    // Remove position/alignment tags
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

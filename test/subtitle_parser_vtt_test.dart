import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:deutschflow/services/subtitle_parser.dart';

void main() {
  test('Parse real YouTube VTT with word-level timestamps', () async {
    final vttFile = File(
      r'C:\Users\xpeng\AppData\Roaming\com.example\deutschflow\downloads\KnGWwoXj8M4\24 Mai 2026 Tagesschau in 100 Sekunden.de.vtt',
    );

    if (!vttFile.existsSync()) {
      print('VTT file not found, skipping test');
      return;
    }

    final content = await vttFile.readAsString();
    final entries = SubtitleParser.parseVtt(content);

    print('=== Parsed ${entries.length} sentence segments ===\n');
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final startSec = (e.startMs / 1000).toStringAsFixed(1);
      final endSec = (e.endMs / 1000).toStringAsFixed(1);
      print('[$startSec - $endSec] ${e.text}');
    }

    // Basic sanity checks
    expect(entries.isNotEmpty, true);
    // First entry should start near 0
    expect(entries.first.startMs, lessThan(2000));
    // Every sentence should have text
    for (final e in entries) {
      expect(e.text.trim().isNotEmpty, true);
    }
    // No duplicate consecutive sentences
    for (var i = 1; i < entries.length; i++) {
      expect(entries[i].text, isNot(equals(entries[i - 1].text)));
    }
  });
}

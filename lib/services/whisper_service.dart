import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Whisper model sizes available for local transcription.
enum WhisperModel {
  tiny('tiny', 'ggml-tiny.bin', 75),
  base('base', 'ggml-base.bin', 142),
  small('small', 'ggml-small.bin', 466);

  const WhisperModel(this.label, this.filename, this.sizeMB);
  final String label;
  final String filename;
  final int sizeMB;
}

/// Manages local whisper.cpp binary and model downloads for on-device
/// speech-to-text. Works on Windows x64.
class WhisperService {
  static const _whisperVersion = 'v1.8.4';
  static const _whisperBinUrl =
      'https://github.com/ggml-org/whisper.cpp/releases/download/$_whisperVersion/whisper-bin-x64.zip';
  static const _modelBaseUrl =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';

  String? _cliPath;
  String? _modelPath;

  /// Directory where whisper tools are stored.
  Future<String> get _toolDir async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, 'whisper'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  /// Check if whisper-cli.exe is already available.
  Future<bool> get isCliReady async {
    if (_cliPath != null && File(_cliPath!).existsSync()) return true;
    final dir = await _toolDir;
    final exe = File(p.join(dir, 'whisper-cli.exe'));
    if (exe.existsSync()) {
      _cliPath = exe.path;
      return true;
    }
    return false;
  }

  /// Check if a specific model file is available.
  Future<bool> isModelReady([WhisperModel model = WhisperModel.base]) async {
    if (_modelPath != null && File(_modelPath!).existsSync()) return true;
    final dir = await _toolDir;
    final file = File(p.join(dir, model.filename));
    if (file.existsSync()) {
      _modelPath = file.path;
      return true;
    }
    return false;
  }

  /// Download and extract whisper-cli.exe (≈4 MB zip).
  Future<void> ensureCli({
    void Function(double progress)? onProgress,
  }) async {
    if (await isCliReady) return;

    final dir = await _toolDir;
    final zipPath = p.join(dir, 'whisper-bin-x64.zip');

    // Download zip
    await _download(_whisperBinUrl, zipPath, onProgress: onProgress);

    // Extract using PowerShell (built-in on Windows)
    final extractDir = p.join(dir, '_extract');
    if (Directory(extractDir).existsSync()) {
      Directory(extractDir).deleteSync(recursive: true);
    }
    Directory(extractDir).createSync();

    final result = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      'Expand-Archive -Path "$zipPath" -DestinationPath "$extractDir" -Force',
    ]);

    if (result.exitCode != 0) {
      throw Exception('解压 whisper.cpp 失败: ${result.stderr}');
    }

    // Find whisper-cli.exe recursively
    final exeFiles = Directory(extractDir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => p.basename(f.path).toLowerCase() == 'whisper-cli.exe');

    if (exeFiles.isEmpty) {
      throw Exception('解压后未找到 whisper-cli.exe');
    }

    // Copy exe and DLLs to tool dir
    final srcDir = exeFiles.first.parent;
    for (final f in srcDir.listSync().whereType<File>()) {
      final ext = p.extension(f.path).toLowerCase();
      if (ext == '.exe' || ext == '.dll') {
        f.copySync(p.join(dir, p.basename(f.path)));
      }
    }

    // Clean up
    try {
      Directory(extractDir).deleteSync(recursive: true);
      File(zipPath).deleteSync();
    } catch (_) {}

    _cliPath = p.join(dir, 'whisper-cli.exe');
    if (!File(_cliPath!).existsSync()) {
      _cliPath = null;
      throw Exception('whisper-cli.exe 安装失败');
    }
  }

  /// Download a Whisper GGML model (default: base, ≈142 MB).
  Future<void> ensureModel({
    WhisperModel model = WhisperModel.base,
    void Function(double progress)? onProgress,
  }) async {
    if (await isModelReady(model)) return;

    final dir = await _toolDir;
    final modelFile = p.join(dir, model.filename);
    final url = '$_modelBaseUrl/${model.filename}';

    await _download(url, modelFile, onProgress: onProgress);
    _modelPath = modelFile;
  }

  /// Transcribe an audio file locally using whisper.cpp.
  ///
  /// The audio file should be WAV (16-bit PCM, 16kHz mono) for best results.
  /// whisper.cpp also supports many common formats via built-in decoding.
  ///
  /// Returns the transcribed German text.
  Future<String> transcribe(
    String audioPath, {
    WhisperModel model = WhisperModel.base,
  }) async {
    await ensureCli();
    await ensureModel(model: model);

    final dir = await _toolDir;
    final cliPath = _cliPath ?? p.join(dir, 'whisper-cli.exe');
    final modelPath = _modelPath ?? p.join(dir, model.filename);

    // Run whisper-cli
    final result = await Process.run(
      cliPath,
      [
        '-m', modelPath,
        '-l', 'de', // German
        '--no-timestamps',
        '-f', audioPath,
      ],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    if (result.exitCode != 0) {
      final stderr = (result.stderr as String).trim();
      throw Exception('whisper.cpp 转写失败 (exit ${result.exitCode}): $stderr');
    }

    // Parse output: whisper-cli prints transcribed text to stdout
    final text = (result.stdout as String)
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('['))
        .join(' ')
        .trim();

    if (text.isEmpty) {
      throw Exception('whisper.cpp 未返回任何文本，音频可能过短或格式不支持。');
    }

    return text;
  }

  /// Get the total download size needed (binary + model).
  int getRequiredDownloadMB(WhisperModel model) {
    return 4 + model.sizeMB; // 4 MB binary + model size
  }

  /// Transcribe an audio file and return SRT-format subtitles with timestamps.
  ///
  /// This generates segment-level timestamps suitable for dictation practice.
  /// Returns SRT content as a string.
  Future<String> transcribeToSrt(
    String audioPath, {
    WhisperModel model = WhisperModel.base,
  }) async {
    await ensureCli();
    await ensureModel(model: model);

    final dir = await _toolDir;
    final cliPath = _cliPath ?? p.join(dir, 'whisper-cli.exe');
    final modelPath = _modelPath ?? p.join(dir, model.filename);

    // whisper.cpp --output-srt writes <input>.srt next to the input file.
    // We use a temp directory to avoid polluting the original audio location.
    final tempDir = await Directory.systemTemp.createTemp('whisper_');
    final tempAudio = p.join(tempDir.path, p.basename(audioPath));
    await File(audioPath).copy(tempAudio);

    final result = await Process.run(
      cliPath,
      [
        '-m', modelPath,
        '-l', 'de',
        '--output-srt',
        '-f', tempAudio,
      ],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    if (result.exitCode != 0) {
      final stderr = (result.stderr as String).trim();
      // Clean up temp
      try { tempDir.deleteSync(recursive: true); } catch (_) {}
      throw Exception('whisper.cpp SRT 转写失败 (exit ${result.exitCode}): $stderr');
    }

    // Read the generated SRT file
    final srtPath = '${p.withoutExtension(tempAudio)}.srt';
    final srtFile = File(srtPath);
    if (!srtFile.existsSync()) {
      try { tempDir.deleteSync(recursive: true); } catch (_) {}
      throw Exception('whisper.cpp 未生成 SRT 文件');
    }

    final srtContent = await srtFile.readAsString(encoding: utf8);

    // Clean up temp
    try { tempDir.deleteSync(recursive: true); } catch (_) {}

    if (srtContent.trim().isEmpty) {
      throw Exception('whisper.cpp SRT 输出为空，音频可能过短或格式不支持。');
    }

    return srtContent;
  }

  /// Helper: download a file with progress callback.
  Future<void> _download(
    String url,
    String destPath, {
    void Function(double progress)? onProgress,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      // Follow redirects manually if needed (Hugging Face uses them)
      if (response.statusCode == 302 || response.statusCode == 301) {
        final redirectUrl = response.headers.value('location');
        if (redirectUrl != null) {
          // Consume the original response
          await response.drain<void>();
          final req2 = await client.getUrl(Uri.parse(redirectUrl));
          final resp2 = await req2.close();
          await _writeStream(resp2, destPath, onProgress);
          return;
        }
      }

      if (response.statusCode != 200) {
        await response.drain<void>();
        throw Exception('下载失败 (HTTP ${response.statusCode}): $url');
      }

      await _writeStream(response, destPath, onProgress);
    } finally {
      client.close();
    }
  }

  Future<void> _writeStream(
    HttpClientResponse response,
    String destPath,
    void Function(double progress)? onProgress,
  ) async {
    final totalBytes = response.contentLength;
    final sink = File(destPath).openWrite();
    int received = 0;

    await for (final chunk in response) {
      sink.add(chunk);
      received += chunk.length;
      if (totalBytes > 0) {
        onProgress?.call(received / totalBytes);
      }
    }
    await sink.close();
  }
}

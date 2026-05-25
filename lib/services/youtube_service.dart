import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages yt-dlp binary and video/subtitle downloads.
class YoutubeService {
  static const _ytDlpVersion = '2024.12.23';
  static const _ytDlpUrl =
      'https://github.com/yt-dlp/yt-dlp/releases/download/$_ytDlpVersion/yt-dlp.exe';

  String? _ytDlpPath;

  /// Returns the path to yt-dlp.exe, downloading it if needed.
  Future<String> ensureYtDlp({
    void Function(double progress)? onProgress,
  }) async {
    if (_ytDlpPath != null && File(_ytDlpPath!).existsSync()) {
      return _ytDlpPath!;
    }

    final appDir = await getApplicationSupportDirectory();
    final toolDir = Directory(p.join(appDir.path, 'tools'));
    if (!toolDir.existsSync()) toolDir.createSync(recursive: true);

    final exePath = p.join(toolDir.path, 'yt-dlp.exe');
    if (File(exePath).existsSync()) {
      _ytDlpPath = exePath;
      return exePath;
    }

    // Download yt-dlp
    final request = http.Request('GET', Uri.parse(_ytDlpUrl));
    final response = await http.Client().send(request);
    if (response.statusCode != 200) {
      throw Exception('下载 yt-dlp 失败 (HTTP ${response.statusCode})');
    }

    final totalBytes = response.contentLength ?? 0;
    final sink = File(exePath).openWrite();
    int received = 0;

    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (totalBytes > 0) {
        onProgress?.call(received / totalBytes);
      }
    }
    await sink.close();
    _ytDlpPath = exePath;
    return exePath;
  }

  /// List videos in a YouTube playlist.
  /// Returns list of {id, title, duration, url}.
  Future<List<Map<String, dynamic>>> listPlaylist(String playlistUrl) async {
    final exe = await ensureYtDlp();
    final result = await Process.run(exe, [
      '--flat-playlist',
      '--dump-json',
      '--no-warnings',
      playlistUrl,
    ]);

    if (result.exitCode != 0) {
      throw Exception('获取播放列表失败：${result.stderr}');
    }

    final lines = (result.stdout as String)
        .split('\n')
        .where((l) => l.trim().isNotEmpty);

    return lines.map((line) {
      final json = jsonDecode(line) as Map<String, dynamic>;
      return {
        'id': json['id'] as String? ?? '',
        'title': json['title'] as String? ?? 'Untitled',
        'duration': json['duration'] as num? ?? 0,
        'url': json['url'] as String? ??
            json['webpage_url'] as String? ??
            'https://www.youtube.com/watch?v=${json['id']}',
      };
    }).toList();
  }

  /// Download audio + German subtitles for a video.
  /// Returns {audioPath, subtitlePath} or throws.
  Future<DownloadResult> downloadVideo(
    String videoUrl, {
    required String outputDir,
    void Function(String status)? onStatus,
  }) async {
    final exe = await ensureYtDlp();
    final dir = Directory(outputDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    // Download audio as mp3
    onStatus?.call('正在下载音频…');
    final audioResult = await Process.run(exe, [
      '-x',
      '--audio-format', 'mp3',
      '--audio-quality', '5',
      '-o', p.join(outputDir, '%(title)s.%(ext)s'),
      '--no-playlist',
      '--no-warnings',
      videoUrl,
    ]);

    if (audioResult.exitCode != 0) {
      throw Exception('音频下载失败：${audioResult.stderr}');
    }

    // Find the downloaded mp3
    final audioFile = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.mp3'))
        .toList();
    if (audioFile.isEmpty) {
      throw Exception('未找到下载的音频文件');
    }
    final mp3Path = audioFile.last.path;

    // Download German subtitles
    onStatus?.call('正在下载字幕…');
    await Process.run(exe, [
      '--write-subs',
      '--write-auto-subs',
      '--sub-lang', 'de',
      '--sub-format', 'vtt',
      '--skip-download',
      '-o', p.join(outputDir, '%(title)s.%(ext)s'),
      '--no-playlist',
      '--no-warnings',
      videoUrl,
    ]);

    // Find subtitle file
    String? subtitlePath;
    final subFiles = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.vtt') || f.path.endsWith('.srt'));
    if (subFiles.isNotEmpty) {
      subtitlePath = subFiles.last.path;
    }

    return DownloadResult(
      audioPath: mp3Path,
      subtitlePath: subtitlePath,
      title: p.basenameWithoutExtension(mp3Path),
    );
  }

  /// Check if yt-dlp is available.
  Future<bool> isAvailable() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final exePath = p.join(appDir.path, 'tools', 'yt-dlp.exe');
      return File(exePath).existsSync();
    } catch (_) {
      return false;
    }
  }
}

class DownloadResult {
  const DownloadResult({
    required this.audioPath,
    this.subtitlePath,
    required this.title,
  });
  final String audioPath;
  final String? subtitlePath;
  final String title;
}

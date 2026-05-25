import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages yt-dlp binary and video/subtitle downloads.
class YoutubeService {
  static const _ytDlpUrl =
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe';

  String? _ytDlpPath;

  /// Returns the path to yt-dlp.exe, downloading it if needed.
  Future<String> ensureYtDlp({
    void Function(double progress)? onProgress,
    bool forceUpdate = false,
  }) async {
    if (!forceUpdate && _ytDlpPath != null && File(_ytDlpPath!).existsSync()) {
      return _ytDlpPath!;
    }

    final appDir = await getApplicationSupportDirectory();
    final toolDir = Directory(p.join(appDir.path, 'tools'));
    if (!toolDir.existsSync()) toolDir.createSync(recursive: true);

    final exePath = p.join(toolDir.path, 'yt-dlp.exe');
    if (!forceUpdate && File(exePath).existsSync()) {
      _ytDlpPath = exePath;
      return exePath;
    }

    // Delete old version
    if (File(exePath).existsSync()) {
      File(exePath).deleteSync();
    }

    // Download yt-dlp using dart:io HttpClient (properly follows redirects)
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(_ytDlpUrl));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('下载 yt-dlp 失败 (HTTP ${response.statusCode})');
      }

      final totalBytes = response.contentLength;
      final sink = File(exePath).openWrite();
      int received = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0) {
          onProgress?.call(received / totalBytes);
        }
      }
      await sink.close();
    } finally {
      client.close();
    }
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

    // Clean up any previous partial downloads in this dir
    for (final f in dir.listSync().whereType<File>()) {
      f.deleteSync();
    }

    // Download without format restriction - let yt-dlp pick the best available
    onStatus?.call('正在下载音频和字幕…');
    var result = await Process.run(exe, [
      '-o', p.join(outputDir, '%(title)s.%(ext)s'),
      '--write-subs',
      '--write-auto-subs',
      '--sub-lang', 'de',
      '--sub-format', 'vtt',
      '--no-playlist',
      '--no-warnings',
      videoUrl,
    ]);

    if (result.exitCode != 0) {
      throw Exception('下载失败：${result.stderr}');
    }

    // Find the downloaded media file (could be video or audio)
    final mediaExts = ['.m4a', '.mp3', '.webm', '.ogg', '.opus', '.wav', '.mp4', '.mkv'];
    final mediaFiles = dir
        .listSync()
        .whereType<File>()
        .where((f) {
          final lower = f.path.toLowerCase();
          return mediaExts.any((ext) => lower.endsWith(ext)) &&
                 !lower.endsWith('.vtt') && !lower.endsWith('.srt');
        })
        .toList();
    if (mediaFiles.isEmpty) {
      throw Exception('未找到下载的媒体文件');
    }
    final audioPath = mediaFiles.last.path;

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
      audioPath: audioPath,
      subtitlePath: subtitlePath,
      title: p.basenameWithoutExtension(audioPath),
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

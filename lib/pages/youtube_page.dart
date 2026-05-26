import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/subtitle_parser.dart';
import '../services/youtube_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class YoutubePage extends StatefulWidget {
  const YoutubePage({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  State<YoutubePage> createState() => _YoutubePageState();
}

class _YoutubePageState extends State<YoutubePage> {
  static const _presets = [
    _Playlist(
      title: 'TAGESSCHAU 100 Sekunden',
      description: '每日100秒新闻精华，适合中级学习者',
      url:
          'https://www.youtube.com/watch?v=KnGWwoXj8M4&list=PLOixzgWxGZAmoeziLaRxdb29FA5FAF2Ty',
      icon: Icons.timer,
    ),
    _Playlist(
      title: 'TAGESSCHAU 完整版',
      description: '完整新闻节目，适合高级学习者',
      url:
          'https://www.youtube.com/watch?v=8qXRanekUwU&list=PL4A2F331EE86DCC22',
      icon: Icons.tv,
    ),
  ];

  final YoutubeService _ytService = YoutubeService();
  final TextEditingController _urlCtrl = TextEditingController();

  bool _ytDlpReady = false;
  bool _downloadingYtDlp = false;
  double _ytDlpProgress = 0;
  String? _ytDlpError;

  List<Map<String, dynamic>>? _videos;
  bool _loadingPlaylist = false;
  String? _playlistError;
  String? _currentPlaylistTitle;

  final Map<String, _DownloadState> _downloading = {};

  @override
  void initState() {
    super.initState();
    _checkYtDlp();
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlCtrl.text = widget.initialUrl!;
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_ytDlpReady) ...[
                _buildYtDlpSetup(),
                const SizedBox(height: 16),
              ] else ...[
                _buildPresets(),
                const SizedBox(height: 16),
                _buildCustomUrl(),
                const SizedBox(height: 16),
                if (_loadingPlaylist)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                if (_playlistError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GlassCard(
                      padding: const EdgeInsets.all(14),
                      borderColor: Colors.red.withValues(alpha: 0.3),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_playlistError!)),
                        ],
                      ),
                    ),
                  ),
                if (_videos != null) _buildVideoList(),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYtDlpSetup() {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.download_for_offline,
              size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text('需要下载 yt-dlp 工具',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('yt-dlp 是开源视频下载工具，约 12MB。\n首次使用需要下载，之后无需重复下载。',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          if (_downloadingYtDlp) ...[
            LinearProgressIndicator(value: _ytDlpProgress),
            const SizedBox(height: 8),
            Text('下载中 ${(_ytDlpProgress * 100).toStringAsFixed(0)}%'),
          ] else if (_ytDlpError != null) ...[
            Text(_ytDlpError!,
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _installYtDlp,
              child: const Text('重试下载'),
            ),
          ] else
            FilledButton.icon(
              onPressed: _installYtDlp,
              icon: const Icon(Icons.download),
              label: const Text('下载 yt-dlp'),
            ),
        ],
      ),
    );
  }

  Widget _buildPresets() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('推荐播放列表',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
            ),
            TextButton.icon(
              onPressed: _downloadingYtDlp ? null : _updateYtDlp,
              icon: _downloadingYtDlp
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.update, size: 18),
              label: Text(_downloadingYtDlp ? '更新中…' : '更新 yt-dlp'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...List.generate(_presets.length, (i) {
          final preset = _presets[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              onTap: () => _loadPlaylist(preset.url, preset.title),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: i == 0
                          ? AppTheme.heroGradient
                          : AppTheme.warmGradient,
                      borderRadius: AppTheme.borderMd,
                    ),
                    child: Icon(preset.icon, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(preset.title,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        Text(preset.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCustomUrl() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('自定义播放列表',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(
                    hintText: '粘贴 YouTube 播放列表或视频链接…',
                    prefixIcon: Icon(Icons.link),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: () {
                  final url = _urlCtrl.text.trim();
                  if (url.isNotEmpty) _loadPlaylist(url, '自定义播放列表');
                },
                child: const Text('加载'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$_currentPlaylistTitle (${_videos!.length} 个视频)',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                _videos = null;
                _currentPlaylistTitle = null;
              }),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('关闭'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...List.generate(_videos!.length.clamp(0, 50), (i) {
          final v = _videos![i];
          final id = v['id'] as String;
          final title = v['title'] as String;
          final duration = v['duration'] as num;
          final state = _downloading[id];

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Index
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${i + 1}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        if (duration > 0)
                          Text(
                            _formatDuration(duration.toInt()),
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        if (state != null) ...[
                          const SizedBox(height: 4),
                          if (state.status == _DlStatus.downloading)
                            Row(
                              children: [
                                const SizedBox.square(
                                  dimension: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                                const SizedBox(width: 6),
                                Text(state.message,
                                    style: theme.textTheme.labelSmall),
                              ],
                            ),
                          if (state.status == _DlStatus.done)
                            Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: AppTheme.emerald, size: 16),
                                const SizedBox(width: 4),
                                Text('已导入为项目',
                                    style: theme.textTheme.labelSmall
                                        ?.copyWith(color: AppTheme.emerald)),
                              ],
                            ),
                          if (state.status == _DlStatus.error)
                            Row(
                              children: [
                                const Icon(Icons.error,
                                    color: Colors.red, size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(state.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: Colors.red)),
                                ),
                              ],
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (state?.status == _DlStatus.downloading)
                    const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (state?.status == _DlStatus.done)
                    const Icon(Icons.check, color: AppTheme.emerald)
                  else
                    IconButton(
                      icon: const Icon(Icons.download),
                      tooltip: '下载并导入',
                      onPressed: () => _downloadAndImport(v),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─── Logic ───────────────────────────────────────────────

  Future<void> _checkYtDlp() async {
    final ready = await _ytService.isAvailable();
    if (mounted) setState(() => _ytDlpReady = ready);
  }

  Future<void> _installYtDlp() async {
    setState(() {
      _downloadingYtDlp = true;
      _ytDlpError = null;
      _ytDlpProgress = 0;
    });
    try {
      await _ytService.ensureYtDlp(
        onProgress: (p) {
          if (mounted) setState(() => _ytDlpProgress = p);
        },
      );
      if (mounted) {
        setState(() {
          _ytDlpReady = true;
          _downloadingYtDlp = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadingYtDlp = false;
          _ytDlpError = '下载失败：$e';
        });
      }
    }
  }

  Future<void> _updateYtDlp() async {
    setState(() {
      _downloadingYtDlp = true;
      _ytDlpError = null;
      _ytDlpProgress = 0;
    });
    try {
      await _ytService.ensureYtDlp(
        forceUpdate: true,
        onProgress: (p) {
          if (mounted) setState(() => _ytDlpProgress = p);
        },
      );
      if (mounted) {
        setState(() => _downloadingYtDlp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('yt-dlp 已更新到最新版本')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadingYtDlp = false;
          _ytDlpError = '更新失败：$e';
        });
      }
    }
  }

  Future<void> _loadPlaylist(String url, String title) async {
    setState(() {
      _loadingPlaylist = true;
      _playlistError = null;
      _videos = null;
      _currentPlaylistTitle = title;
    });
    try {
      final videos = await _ytService.listPlaylist(url);
      if (!mounted) return;
      setState(() {
        _videos = videos;
        _loadingPlaylist = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPlaylist = false;
        _playlistError = '加载播放列表失败：$e';
      });
    }
  }

  Future<void> _downloadAndImport(Map<String, dynamic> video) async {
    final id = video['id'] as String;
    final title = video['title'] as String;
    final url = video['url'] as String;

    setState(() {
      _downloading[id] = _DownloadState(_DlStatus.downloading, '准备下载…');
    });

    try {
      final appDir = await getApplicationSupportDirectory();
      final outputDir = p.join(appDir.path, 'downloads', id);

      final result = await _ytService.downloadVideo(
        url,
        outputDir: outputDir,
        onStatus: (status) {
          if (mounted) {
            setState(() {
              _downloading[id] = _DownloadState(_DlStatus.downloading, status);
            });
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _downloading[id] =
            _DownloadState(_DlStatus.downloading, '正在创建项目…');
      });

      // Parse subtitles if available
      List<({String text, int startMs, int endMs})>? timedSentences;
      String sourceText = title;

      if (result.subtitlePath != null) {
        final subs = await SubtitleParser.parseFile(result.subtitlePath!);
        if (subs.isNotEmpty) {
          sourceText = subs.map((s) => s.text).join('\n');
          timedSentences = subs
              .map((s) => (text: s.text, startMs: s.startMs, endMs: s.endMs))
              .toList();
        }
      }

      // Create project
      final appState = context.read<AppState>();
      final db = appState.database;
      final projectId = await db.createProject(
        name: title,
        sourceText: sourceText,
      );
      await db.updateProjectAudioPath(projectId, result.audioPath);

      if (timedSentences != null && timedSentences.isNotEmpty) {
        await db.insertTimedSentences(projectId, timedSentences);
        await db.markTimelineCompleted(projectId);
      } else {
        // No subtitles: just split source text into sentences
        final sentences = sourceText
            .split(RegExp(r'(?<=[.!?])\s+'))
            .where((s) => s.trim().isNotEmpty)
            .toList();
        if (sentences.isNotEmpty) {
          await db.insertSentences(projectId, sentences);
        }
      }

      await appState.loadProjects();

      if (!mounted) return;
      setState(() {
        _downloading[id] = _DownloadState(_DlStatus.done, '完成');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading[id] = _DownloadState(_DlStatus.error, '$e');
      });
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}:${s.toString().padLeft(2, '0')}';
  }
}

class _Playlist {
  const _Playlist({
    required this.title,
    required this.description,
    required this.url,
    required this.icon,
  });
  final String title;
  final String description;
  final String url;
  final IconData icon;
}

enum _DlStatus { downloading, done, error }

class _DownloadState {
  const _DownloadState(this.status, this.message);
  final _DlStatus status;
  final String message;
}

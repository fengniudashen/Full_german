import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/ai_service.dart';
import '../services/subtitle_parser.dart';
import '../services/whisper_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'timeline_page.dart';

/// A page that lets users import audio from podcast RSS feeds.
class PodcastPage extends StatefulWidget {
  const PodcastPage({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  State<PodcastPage> createState() => _PodcastPageState();
}

class _PodcastPageState extends State<PodcastPage> {
  final _urlCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _createSectionKey = GlobalKey();
  final WhisperService _whisper = WhisperService();

  bool _loading = false;
  bool _downloading = false;
  double _downloadProgress = 0;
  bool _transcribing = false;
  double _transcribeProgress = 0;
  bool _segmenting = false;
  String? _error;
  List<_Episode> _episodes = const [];
  _Episode? _selected;
  String? _downloadedAudioPath;
  String? _srtContent; // SRT from Whisper transcription

  static const _presets = [
    _Preset(
      title: 'Slow German',
      desc: '慢速德语播客，适合初中级学习者',
      url: 'https://slowgerman.com/feed/mp3/',
      icon: Icons.speed,
    ),
    _Preset(
      title: 'Deutsche Welle – Langsam gesprochene Nachrichten',
      desc: 'DW慢速新闻，每日更新',
      url: 'https://rss.dw.com/xml/DKpodcast_lgn_de',
      icon: Icons.newspaper,
    ),
    _Preset(
      title: 'Coffee Break German',
      desc: '轻松德语教学播客',
      url: 'https://podcast.coffeebreakacademy.com/coffeebreasgerman',
      icon: Icons.coffee,
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlCtrl.text = widget.initialUrl!;
      // Auto-fetch after the first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchFeed(widget.initialUrl!);
      });
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _textCtrl.dispose();
    _nameCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── RSS Parsing ────────────────────────────────────────────

  Future<void> _fetchFeed(String url) async {
    if (url.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _episodes = const [];
      _selected = null;
      _downloadedAudioPath = null;
    });

    try {
      final response = await http.get(Uri.parse(url.trim()));
      if (!mounted) return;
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final episodes = _parseRss(response.body);
      if (episodes.isEmpty) throw Exception('未找到播客节目');
      setState(() {
        _episodes = episodes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '获取RSS失败: $e';
        _loading = false;
      });
    }
  }

  List<_Episode> _parseRss(String xml) {
    final episodes = <_Episode>[];
    // Simple XML parsing for RSS <item> elements
    final itemRegex = RegExp(r'<item[^>]*>(.*?)</item>', dotAll: true);
    final titleRegex = RegExp(r'<title[^>]*>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</title>', dotAll: true);
    final enclosureRegex = RegExp(r'<enclosure[^>]+url="([^"]+)"', dotAll: true);
    final descRegex = RegExp(r'<description[^>]*>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</description>', dotAll: true);
    final pubDateRegex = RegExp(r'<pubDate[^>]*>(.*?)</pubDate>');

    for (final match in itemRegex.allMatches(xml)) {
      final item = match.group(1) ?? '';
      final title = titleRegex.firstMatch(item)?.group(1)?.trim() ?? '未命名';
      final audioUrl = enclosureRegex.firstMatch(item)?.group(1);
      final desc = descRegex.firstMatch(item)?.group(1)?.trim() ?? '';
      final pubDate = pubDateRegex.firstMatch(item)?.group(1)?.trim() ?? '';

      if (audioUrl != null) {
        episodes.add(_Episode(
          title: _stripHtml(title),
          audioUrl: audioUrl,
          description: _stripHtml(desc),
          pubDate: pubDate,
        ));
      }
    }
    return episodes;
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .trim();
  }

  // ─── Download & Create ──────────────────────────────────────

  Future<void> _downloadEpisode(_Episode ep) async {
    setState(() {
      _selected = ep;
      _downloading = true;
      _downloadProgress = 0;
      _error = null;
    });

    try {
      final dir = await getApplicationSupportDirectory();
      final ext = p.extension(Uri.parse(ep.audioUrl).path);
      final safeName = ep.title
          .replaceAll(RegExp(r'[^\w\s\u4e00-\u9fff-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final filePath = p.join(dir.path, 'podcast_$safeName$ext');

      // Simple download (handles redirects automatically)
      final response = await http.get(Uri.parse(ep.audioUrl));
      if (response.statusCode != 200) {
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }
      await File(filePath).writeAsBytes(response.bodyBytes);

      if (!mounted) return;
      setState(() {
        _selected = ep;
        _downloadedAudioPath = filePath;
        _nameCtrl.text = ep.title;
        _downloading = false;
        _downloadProgress = 1;
      });

      // Auto-scroll to creation section
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _createSectionKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '下载失败: $e';
        _downloading = false;
      });
    }
  }

  // ─── Whisper Transcribe ─────────────────────────────────────

  /// Local whisper.cpp transcription.
  Future<void> _whisperTranscribe() async {
    if (_downloadedAudioPath == null) return;
    final settings = context.read<AppState>().settings;
    final model = WhisperModel.values.firstWhere(
      (m) => m.label == settings.whisperModel,
      orElse: () => WhisperModel.base,
    );

    setState(() {
      _transcribing = true;
      _transcribeProgress = 0;
      _error = null;
    });

    try {
      // Ensure Whisper CLI is ready
      setState(() => _transcribeProgress = 0.1);
      await _whisper.ensureCli(
        onProgress: (p) {
          if (mounted) setState(() => _transcribeProgress = 0.1 + p * 0.2);
        },
      );

      // Ensure model is ready
      if (!mounted) return;
      setState(() => _transcribeProgress = 0.3);
      await _whisper.ensureModel(
        model: model,
        onProgress: (p) {
          if (mounted) setState(() => _transcribeProgress = 0.3 + p * 0.3);
        },
      );

      // Transcribe to SRT
      if (!mounted) return;
      setState(() => _transcribeProgress = 0.6);
      final srt = await _whisper.transcribeToSrt(
        _downloadedAudioPath!,
        model: model,
      );

      if (!mounted) return;

      // Parse SRT to get text for display
      final entries = SubtitleParser.parseSrt(srt);
      final text = entries.map((e) => e.text).join('\n');

      setState(() {
        _srtContent = srt;
        _textCtrl.text = text;
        _transcribing = false;
        _transcribeProgress = 1.0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('转写完成！共 ${entries.length} 个句段，已填入文本框'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Whisper 转写失败: $e';
        _transcribing = false;
      });
    }
  }

  /// Cloud Whisper API transcription (OpenAI-compatible).
  Future<void> _whisperTranscribeCloud() async {
    if (_downloadedAudioPath == null) return;
    final settings = context.read<AppState>().settings;

    // Try to find an OpenAI-compatible provider with API key.
    // Priority: openai → active provider → any provider with key.
    String? apiBase;
    String? apiKey;

    final openai = settings.getProvider('openai');
    if (openai.hasKey) {
      apiBase = openai.baseUrl;
      apiKey = openai.apiKey;
    } else {
      final active = settings.activeProvider;
      if (active.hasKey) {
        apiBase = active.baseUrl;
        apiKey = active.apiKey;
      }
    }

    if (apiBase == null || apiKey == null || apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在设置中配置 OpenAI（或兼容）API Key')),
      );
      return;
    }

    setState(() {
      _transcribing = true;
      _transcribeProgress = 0;
      _error = null;
    });

    try {
      setState(() => _transcribeProgress = 0.3);

      final srt = await WhisperService.transcribeCloud(
        apiBase: apiBase,
        apiKey: apiKey,
        audioPath: _downloadedAudioPath!,
      );

      if (!mounted) return;

      final entries = SubtitleParser.parseSrt(srt);
      final text = entries.map((e) => e.text).join('\n');

      setState(() {
        _srtContent = srt;
        _textCtrl.text = text;
        _transcribing = false;
        _transcribeProgress = 1.0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('云端转写完成！共 ${entries.length} 个句段'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '云端 Whisper 转写失败: $e';
        _transcribing = false;
      });
    }
  }

  /// Use LLM to intelligently re-segment the SRT subtitles.
  Future<void> _aiSegment() async {
    if (_srtContent == null || _srtContent!.isEmpty) return;
    final settings = context.read<AppState>().settings;
    final provider = settings.activeProvider;

    if (!provider.hasKey) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在设置中配置 AI API Key')),
      );
      return;
    }

    setState(() {
      _segmenting = true;
      _error = null;
    });

    try {
      final ai = AiService(provider: provider);
      final newSrt = await ai.segmentSrt(_srtContent!);

      if (!mounted) return;

      // Parse the improved SRT
      final entries = SubtitleParser.parseSrt(newSrt);
      if (entries.isEmpty) {
        setState(() {
          _error = 'AI 分句结果为空，请检查 AI 返回内容';
          _segmenting = false;
        });
        return;
      }

      final text = entries.map((e) => e.text).join('\n');

      setState(() {
        _srtContent = newSrt;
        _textCtrl.text = text;
        _segmenting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI 智能分句完成！共 ${entries.length} 个句段'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'AI 分句失败: $e';
        _segmenting = false;
      });
    }
  }

  Future<void> _createProject() async {
    if (_downloadedAudioPath == null) return;
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入或粘贴德语原文，或使用 Whisper 自动转写')));
      return;
    }

    setState(() => _loading = true);
    try {
      final projectName =
          _nameCtrl.text.trim().isEmpty ? '播客项目' : _nameCtrl.text.trim();
      int id;

      if (_srtContent != null && _srtContent!.isNotEmpty) {
        // Use SRT with timestamps
        id = await context.read<AppState>().createProjectFromSrt(
              name: projectName,
              srtContent: _srtContent!,
              audioPath: _downloadedAudioPath!,
            );
      } else {
        // Plain text — no timestamps
        id = await context.read<AppState>().createProject(
              name: projectName,
              sourceText: text,
              audioPath: _downloadedAudioPath!,
            );
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => TimelinePage(projectId: id)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  // ─── Create Section Widget ──────────────────────────────────

  Widget _buildCreateSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        key: _createSectionKey,
        borderColor: theme.colorScheme.primary.withValues(alpha: 0.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '已下载: ${_selected?.title ?? ""}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Whisper transcribe buttons (local + cloud)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _transcribing ? null : _whisperTranscribe,
                    icon: _transcribing
                        ? SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: _transcribeProgress > 0
                                  ? _transcribeProgress
                                  : null,
                            ),
                          )
                        : const Icon(Icons.mic, size: 18),
                    label: Text(
                      _transcribing
                          ? '${(_transcribeProgress * 100).toInt()}%'
                          : '本地转写',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: AppTheme.emerald.withValues(alpha: 0.4),
                      ),
                      foregroundColor: AppTheme.emerald,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _transcribing ? null : _whisperTranscribeCloud,
                    icon: _transcribing
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cloud, size: 18),
                    label: const Text(
                      '云端转写',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: AppTheme.emerald,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '本地: whisper.cpp 离线 · 云端: OpenAI API',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (_srtContent != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '✅ 已生成带时间戳的 SRT 字幕',
                  style: TextStyle(
                    color: AppTheme.emerald,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _segmenting ? null : _aiSegment,
                  icon: _segmenting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_fix_high, size: 18),
                  label: Text(_segmenting ? 'AI 分句处理中...' : 'AI 智能分句'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '使用 AI 合并断句、修正拼写、优化时间戳',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            if (_srtContent == null)
              Text(
                '或手动粘贴文本：',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Text(
                '↓ 可直接编辑修改转录文本',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.emerald,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '项目名称',
                prefixIcon: Icon(Icons.drive_file_rename_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textCtrl,
              minLines: 8,
              maxLines: 16,
              decoration: InputDecoration(
                labelText: _srtContent != null ? '转录文本（可编辑修改）' : '德语原文',
                alignLabelWithHint: true,
                hintText: '粘贴播客对应的德语文本或转录稿',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _createProject,
              icon: const Icon(Icons.check),
              label: const Text('创建项目'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('播客导入')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            children: [
              // Preset podcasts
              Text('推荐播客', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presets.map((p) {
                  return ActionChip(
                    avatar: Icon(p.icon, size: 18),
                    label: Text(p.title),
                    onPressed: () {
                      _urlCtrl.text = p.url;
                      _fetchFeed(p.url);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Custom URL input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'RSS Feed URL',
                        hintText: 'https://example.com/feed.xml',
                        prefixIcon: Icon(Icons.rss_feed),
                        isDense: true,
                      ),
                      onSubmitted: _fetchFeed,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading ? null : () => _fetchFeed(_urlCtrl.text),
                    child: _loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('加载'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ),

              // Episode list
              if (_episodes.isNotEmpty) ...[
                Text(
                  '共 ${_episodes.length} 期节目',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ..._episodes.take(20).expand((ep) {
                  final isSelected = _selected == ep;
                  return [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        borderColor: isSelected ? theme.colorScheme.primary : null,
                        onTap: _downloading ? null : () => _downloadEpisode(ep),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle : Icons.podcasts,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ep.title,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (ep.pubDate.isNotEmpty)
                                    Text(
                                      ep.pubDate,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (_downloading && _selected == ep)
                              const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else if (!isSelected)
                              Icon(Icons.download,
                                  size: 20,
                                  color: theme.colorScheme.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                    // Show creation section right below selected episode
                    if (isSelected && _downloadedAudioPath != null)
                      _buildCreateSection(theme),
                  ];
                }),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _Episode {
  const _Episode({
    required this.title,
    required this.audioUrl,
    required this.description,
    required this.pubDate,
  });
  final String title;
  final String audioUrl;
  final String description;
  final String pubDate;
}

class _Preset {
  const _Preset({
    required this.title,
    required this.desc,
    required this.url,
    required this.icon,
  });
  final String title;
  final String desc;
  final String url;
  final IconData icon;
}

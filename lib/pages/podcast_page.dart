import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'timeline_page.dart';

/// A page that lets users import audio from podcast RSS feeds.
class PodcastPage extends StatefulWidget {
  const PodcastPage({super.key});

  @override
  State<PodcastPage> createState() => _PodcastPageState();
}

class _PodcastPageState extends State<PodcastPage> {
  final _urlCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _loading = false;
  bool _downloading = false;
  String? _error;
  List<_Episode> _episodes = const [];
  _Episode? _selected;
  String? _downloadedAudioPath;

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
  void dispose() {
    _urlCtrl.dispose();
    _textCtrl.dispose();
    _nameCtrl.dispose();
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
      _downloading = true;
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

      final response = await http.get(Uri.parse(ep.audioUrl));
      if (response.statusCode != 200) {
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }
      await File(filePath).writeAsBytes(response.bodyBytes);

      setState(() {
        _selected = ep;
        _downloadedAudioPath = filePath;
        _nameCtrl.text = ep.title;
        _downloading = false;
      });
    } catch (e) {
      setState(() {
        _error = '下载失败: $e';
        _downloading = false;
      });
    }
  }

  Future<void> _createProject() async {
    if (_downloadedAudioPath == null) return;
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入或粘贴德语原文')));
      return;
    }

    setState(() => _loading = true);
    try {
      final id = await context.read<AppState>().createProject(
            name: _nameCtrl.text.trim().isEmpty ? '播客项目' : _nameCtrl.text.trim(),
            sourceText: text,
            audioPath: _downloadedAudioPath!,
          );
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
                ..._episodes.take(20).map((ep) {
                  final isSelected = _selected == ep;
                  return Padding(
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
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],

              // After download: text input + create
              if (_downloadedAudioPath != null) ...[
                const Divider(height: 32),
                GlassCard(
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
                        minLines: 6,
                        maxLines: 12,
                        decoration: const InputDecoration(
                          labelText: '德语原文',
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

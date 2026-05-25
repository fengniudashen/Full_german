import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

/// 金句本 — Bookmarked / favorite sentences collection.
class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  List<Map<String, dynamic>> _sentences = [];
  bool _loading = true;
  final AudioPlayer _player = AudioPlayer();
  int? _playingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = context.read<AppState>().database;
    final rows = await db.getBookmarkedSentences();
    if (!mounted) return;
    setState(() {
      _sentences = rows;
      _loading = false;
    });
  }

  Future<void> _play(Map<String, dynamic> s) async {
    final id = s['id'] as int;
    if (_playingId == id && _player.playing) {
      await _player.pause();
      setState(() => _playingId = null);
      return;
    }

    final audioPath = s['audioPath'] as String;
    if (!File(audioPath).existsSync()) return;

    await _player.setFilePath(audioPath);
    final startMs = s['startMs'] as int;
    final endMs = s['endMs'] as int;
    await _player.setClip(
      start: Duration(milliseconds: startMs),
      end: Duration(milliseconds: endMs),
    );
    setState(() => _playingId = id);
    await _player.play();
    if (mounted) setState(() => _playingId = null);
  }

  Future<void> _unbookmark(int sentenceId) async {
    final db = context.read<AppState>().database;
    await db.toggleBookmark(sentenceId, false);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('金句本')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sentences.isEmpty
              ? const EmptyState(
                  icon: Icons.bookmark_border,
                  title: '暂无收藏句子',
                  message: '在听写或跟读时点击书签图标收藏句子',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sentences.length,
                  itemBuilder: (_, i) {
                    final s = _sentences[i];
                    final id = s['id'] as int;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: IconButton(
                          icon: Icon(
                            _playingId == id
                                ? Icons.pause_circle
                                : Icons.play_circle,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: () => _play(s),
                        ),
                        title: Text(
                          s['text'] as String,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          s['projectName'] as String,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              tooltip: '复制',
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: s['text'] as String));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已复制')),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.bookmark_remove, size: 18),
                              tooltip: '取消收藏',
                              onPressed: () => _unbookmark(id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

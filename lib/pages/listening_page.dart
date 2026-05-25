import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../models/study_project.dart';
import '../models/study_sentence.dart';
import '../providers/app_state.dart';
import '../utils/time_format.dart';

/// 泛听模式 — Extensive listening without showing text.
/// Follows 尚雯婕法 Step 1: "不看原文，纯靠耳朵"
class ListeningPage extends StatefulWidget {
  const ListeningPage({super.key, required this.projectId});
  final int projectId;

  @override
  State<ListeningPage> createState() => _ListeningPageState();
}

class _ListeningPageState extends State<ListeningPage> {
  static const _speeds = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.5];

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _posSub;

  StudyProject? _project;
  List<StudySentence> _sentences = const [];
  int _activeIndex = -1;
  double _speed = 1.0;
  bool _loading = true;
  bool _loopAll = true;
  bool _showText = false; // Hidden by default for extensive listening
  int _listenCount = 0; // How many times played through
  String? _error;

  @override
  void initState() {
    super.initState();
    _posSub = _player.positionStream.listen(_onPosition);
    _player.playerStateStream.listen(_onPlayerState);
    _load();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final db = context.read<AppState>().database;
      final project = await db.getProject(widget.projectId);
      if (project == null) {
        setState(() { _loading = false; _error = '项目不存在。'; });
        return;
      }
      final sentences = await db.getSentencesForProject(widget.projectId);
      final audioFile = File(project.audioPath);
      if (!audioFile.existsSync()) {
        setState(() { _loading = false; _error = '音频文件不存在。'; });
        return;
      }
      await _player.setFilePath(project.audioPath);
      await _player.setSpeed(_speed);
      if (!mounted) return;
      setState(() {
        _project = project;
        _sentences = sentences;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '加载失败：$e'; });
    }
  }

  void _onPosition(Duration pos) {
    final ms = pos.inMilliseconds;
    var newIndex = -1;
    for (var i = 0; i < _sentences.length; i++) {
      if (ms >= _sentences[i].startMs && ms < _sentences[i].endMs) {
        newIndex = i;
        break;
      }
    }
    if (newIndex != _activeIndex) {
      setState(() => _activeIndex = newIndex);
    }
  }

  void _onPlayerState(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      setState(() => _listenCount++);
      if (_loopAll && _sentences.isNotEmpty) {
        _player.seek(Duration(milliseconds: _sentences.first.startMs));
        _player.play();
      }
    }
  }

  Future<void> _playAll() async {
    if (_sentences.isEmpty) return;
    if (_player.playing) {
      await _player.pause();
      return;
    }
    await _player.seek(Duration(milliseconds: _sentences.first.startMs));
    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_project?.name ?? '泛听模式'),
        actions: [
          // Speed selector
          PopupMenuButton<double>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.speed, size: 18),
                const SizedBox(width: 4),
                Text('${_speed}x',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
            onSelected: (s) {
              setState(() => _speed = s);
              _player.setSpeed(s);
            },
            itemBuilder: (_) => _speeds
                .map((s) => PopupMenuItem(
                      value: s,
                      child: Text('${s}x',
                          style: TextStyle(
                              fontWeight: s == _speed
                                  ? FontWeight.w800
                                  : FontWeight.w500)),
                    ))
                .toList(),
          ),
          // Loop toggle
          IconButton(
            icon: Icon(_loopAll ? Icons.repeat_on : Icons.repeat),
            tooltip: _loopAll ? '关闭循环' : '全文循环',
            onPressed: () => setState(() => _loopAll = !_loopAll),
          ),
          // Show/hide text toggle
          IconButton(
            icon: Icon(_showText ? Icons.visibility : Icons.visibility_off),
            tooltip: _showText ? '隐藏原文' : '显示原文',
            onPressed: () => setState(() => _showText = !_showText),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    _buildInfoBar(theme),
                    _buildProgressBar(theme),
                    Expanded(child: _buildCenterContent(theme)),
                  ],
                ),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _playAll,
              icon: StreamBuilder<bool>(
                stream: _player.playingStream,
                builder: (_, snap) => Icon(
                  (snap.data ?? false) ? Icons.pause : Icons.play_arrow,
                ),
              ),
              label: const Text('播放'),
            ),
    );
  }

  Widget _buildInfoBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.headphones, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '尚雯婕法 · 第1步：泛听',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '已听 $_listenCount 遍',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (_, snap) {
              final pos = snap.data ?? Duration.zero;
              return Text(
                formatDurationMs(pos.inMilliseconds),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontFeatures: [const FontFeature.tabularFigures()],
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(ThemeData theme) {
    return StreamBuilder<Duration>(
      stream: _player.positionStream,
      builder: (_, snap) {
        final pos = snap.data ?? Duration.zero;
        final duration = _player.duration ?? Duration.zero;
        final progress = duration.inMilliseconds > 0
            ? pos.inMilliseconds / duration.inMilliseconds
            : 0.0;
        return LinearProgressIndicator(
          value: progress,
          minHeight: 3,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
        );
      },
    );
  }

  Widget _buildCenterContent(ThemeData theme) {
    if (!_showText) {
      // Large centered listening indicator
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<bool>(
              stream: _player.playingStream,
              builder: (_, snap) {
                final playing = snap.data ?? false;
                return Icon(
                  playing ? Icons.hearing : Icons.headphones,
                  size: 120,
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              '专注聆听，不看原文',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '第 ${_activeIndex + 1} / ${_sentences.length} 句',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => setState(() => _showText = true),
              icon: const Icon(Icons.visibility),
              label: const Text('查看原文'),
            ),
          ],
        ),
      );
    }

    // Show text mode
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _sentences.length,
      itemBuilder: (_, i) {
        final s = _sentences[i];
        final isActive = i == _activeIndex;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              s.text,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        );
      },
    );
  }
}

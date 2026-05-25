import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../models/study_project.dart';
import '../models/study_sentence.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/glass_card.dart';

/// Shadowing / read-along page — plays audio continuously and highlights
/// the current sentence in karaoke style, following the Shang Wenjie method
/// Step 3: "全文背诵与原声同速共振".
class ShadowingPage extends StatefulWidget {
  const ShadowingPage({super.key, required this.projectId});
  final int projectId;

  @override
  State<ShadowingPage> createState() => _ShadowingPageState();
}

class _ShadowingPageState extends State<ShadowingPage> {
  static const _speeds = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.5];

  final AudioPlayer _player = AudioPlayer();
  final ScrollController _scrollCtrl = ScrollController();
  StreamSubscription<Duration>? _posSub;

  StudyProject? _project;
  List<StudySentence> _sentences = const [];
  int _activeIndex = -1;
  double _speed = 0.7; // Start slower for shadowing
  bool _loading = true;
  bool _loopAll = false;
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
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final db = context.read<AppState>().database;
      final project = await db.getProject(widget.projectId);
      if (project == null) {
        setState(() {
          _loading = false;
          _error = '项目不存在。';
        });
        return;
      }
      final sentences = await db.getSentencesForProject(widget.projectId);

      final audioFile = File(project.audioPath);
      if (!audioFile.existsSync()) {
        setState(() {
          _loading = false;
          _error = '音频文件不存在。';
        });
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
      setState(() {
        _loading = false;
        _error = '加载失败：$e';
      });
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
      if (newIndex >= 0) _scrollToIndex(newIndex);
    }
  }

  void _onPlayerState(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      if (_loopAll && _sentences.isNotEmpty) {
        // Restart from beginning
        _player.seek(Duration(milliseconds: _sentences.first.startMs));
        _player.play();
      }
    }
  }

  void _scrollToIndex(int index) {
    // Approximate: each sentence card ~80px high + 8px spacing
    final targetOffset = index * 88.0 - 200;
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        targetOffset.clamp(0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
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

  Future<void> _playFrom(int index) async {
    if (index < 0 || index >= _sentences.length) return;
    await _player.seek(Duration(milliseconds: _sentences[index].startMs));
    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_project?.name ?? '跟读模式'),
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
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    // Top info bar
                    _buildInfoBar(theme),
                    // Sentence list
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: _sentences.length,
                        itemBuilder: (_, i) => _buildSentenceCard(i, theme),
                      ),
                    ),
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
              label: const Text('全文播放'),
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
          Icon(Icons.record_voice_over, size: 18,
              color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '尚雯婕法 · 第3步：跟读背诵',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const Spacer(),
          Text(
            '${_sentences.length} 句',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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

  Widget _buildSentenceCard(int index, ThemeData theme) {
    final s = _sentences[index];
    final isActive = index == _activeIndex;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _playFrom(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: isActive ? 2 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Index badge
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isActive
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatDurationMs(s.startMs)} – ${formatDurationMs(s.endMs)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Icon(Icons.volume_up,
                    color: theme.colorScheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

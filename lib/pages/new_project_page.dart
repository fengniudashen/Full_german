import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/subtitle_parser.dart';
import '../services/text_parser.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_page.dart';
import 'timeline_page.dart';

class NewProjectPage extends StatefulWidget {
  const NewProjectPage({super.key});

  @override
  State<NewProjectPage> createState() => _NewProjectPageState();
}

class _NewProjectPageState extends State<NewProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  String? _audioPath;
  String? _audioName;
  bool _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sentences = TextParser.splitIntoSentences(_textCtrl.text);

    return Scaffold(
      appBar: AppBar(title: const Text('新建项目')),
      body: ResponsivePage(
        maxWidth: 1120,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final form = Form(key: _formKey, child: _buildForm(sentences.length));
            final preview = _buildPreview(context, sentences);
            if (constraints.maxWidth >= 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: form),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: preview),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [form, const SizedBox(height: 16), preview],
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm(int count) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '项目名称',
              prefixIcon: Icon(Icons.drive_file_rename_outline),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? '请输入项目名称' : null,
          ),
          const SizedBox(height: 16),
          _AudioImportTile(audioName: _audioName, onPick: _pickAudio),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text('德语原文', style: Theme.of(context).textTheme.bodySmall),
              ),
              TextButton.icon(
                onPressed: _importTextFile,
                icon: const Icon(Icons.file_open, size: 16),
                label: const Text('从文件导入'),
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _textCtrl,
            minLines: 10,
            maxLines: 18,
            decoration: InputDecoration(
              alignLabelWithHint: true,
              hintText:
                  '粘贴德语原文，或点击「从文件导入」导入 TXT/SRT/VTT 文件',
              helperText: count > 0 ? '已解析 $count 个句子' : null,
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (TextParser.splitIntoSentences(v ?? '').isEmpty) {
                return '请粘贴至少一个句子';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _creating ? null : _createProject,
            icon: _creating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('创建并进入标注'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context, List<String> sentences) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.segment_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('句子预览',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: AppTheme.borderSm,
                ),
                child: Text('${sentences.length} 句',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: theme.colorScheme.onPrimaryContainer,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sentences.isEmpty)
            Text(
              '粘贴原文后会按 . ! ? 自动拆句。',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else
            ...sentences.take(10).indexed.map((entry) {
              final (i, s) = entry;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text('${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          )),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s)),
                  ],
                ),
              );
            }),
          if (sentences.length > 10)
            Text(
              '另有 ${sentences.length - 10} 句未显示',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  Future<void> _importTextFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'srt', 'vtt'],
      allowMultiple: false,
    );
    final file = result?.files.single;
    if (file == null || file.path == null) return;

    try {
      final content = await File(file.path!).readAsString();
      final ext = file.extension?.toLowerCase() ?? '';

      String text;
      if (ext == 'vtt' || ext == 'srt') {
        // Parse subtitle file to extract sentences
        final parsed = SubtitleParser.parseVtt(content);
        text = parsed.map((s) => s.text).join('\n');
      } else {
        text = content;
      }

      setState(() {
        _textCtrl.text = text;
        if (_nameCtrl.text.isEmpty) {
          // Auto-fill project name from filename
          final name = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
          _nameCtrl.text = name;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e')),
      );
    }
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'm4a', 'ogg', 'mp4', 'mkv', 'webm', 'avi', 'flac', 'aac'],
      allowMultiple: false,
      withData: false,
    );
    final file = result?.files.single;
    if (file == null) return;
    if (file.path == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前平台未返回可访问的音频路径')),
      );
      return;
    }
    setState(() {
      _audioPath = file.path;
      _audioName = file.name;
    });
  }

  Future<void> _createProject() async {
    if (!_formKey.currentState!.validate()) return;
    if (_audioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先导入音频文件')),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      final id = await context.read<AppState>().createProject(
            name: _nameCtrl.text,
            sourceText: _textCtrl.text,
            audioPath: _audioPath!,
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => TimelinePage(projectId: id)),
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message.toString())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}

class _AudioImportTile extends StatelessWidget {
  const _AudioImportTile({required this.audioName, required this.onPick});
  final String? audioName;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasFile = audioName != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: hasFile
            ? LinearGradient(colors: [
                AppTheme.emerald.withValues(alpha: isDark ? 0.15 : 0.06),
                AppTheme.emerald.withValues(alpha: isDark ? 0.08 : 0.02),
              ])
            : LinearGradient(colors: [
                theme.colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.06),
                theme.colorScheme.primary.withValues(alpha: isDark ? 0.06 : 0.02),
              ]),
        borderRadius: AppTheme.borderMd,
        border: Border.all(
          color: hasFile
              ? AppTheme.emerald.withValues(alpha: 0.3)
              : theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (hasFile ? AppTheme.emerald : theme.colorScheme.primary)
                  .withValues(alpha: 0.15),
              borderRadius: AppTheme.borderSm,
            ),
            child: Icon(
              hasFile ? Icons.check_circle : Icons.audio_file_outlined,
              color: hasFile ? AppTheme.emerald : theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasFile ? audioName! : '尚未导入音频',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                if (!hasFile)
                  Text('支持 MP3, WAV, M4A, OGG',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: onPick,
            icon: const Icon(Icons.upload_file, size: 18),
            label: Text(hasFile ? '更换' : '导入'),
          ),
        ],
      ),
    );
  }
}

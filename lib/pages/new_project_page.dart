import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/text_parser.dart';
import '../widgets/responsive_page.dart';
import '../widgets/surface_panel.dart';
import 'timeline_page.dart';

class NewProjectPage extends StatefulWidget {
  const NewProjectPage({super.key});

  @override
  State<NewProjectPage> createState() => _NewProjectPageState();
}

class _NewProjectPageState extends State<NewProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _textController = TextEditingController();
  String? _audioPath;
  String? _audioName;
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewSentences = TextParser.splitIntoSentences(_textController.text);

    return Scaffold(
      appBar: AppBar(title: const Text('新建项目')),
      body: ResponsivePage(
        maxWidth: 1120,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final form = Form(
              key: _formKey,
              child: _buildForm(previewSentences.length),
            );
            final preview = _buildPreview(context, previewSentences);
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

  Widget _buildForm(int previewCount) {
    return SurfacePanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '项目名称',
              prefixIcon: Icon(Icons.drive_file_rename_outline),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? '请输入项目名称' : null,
          ),
          const SizedBox(height: 14),
          _AudioImportTile(audioName: _audioName, onPick: _pickAudio),
          const SizedBox(height: 14),
          TextFormField(
            controller: _textController,
            minLines: 12,
            maxLines: 18,
            decoration: InputDecoration(
              labelText: '德语原文',
              alignLabelWithHint: true,
              hintText: 'Guten Morgen! Wie geht es dir? Ich lerne Deutsch.',
              helperText: previewCount > 0 ? '已解析 $previewCount 个句子' : null,
            ),
            onChanged: (_) => setState(() {}),
            validator: (value) {
              final sentences = TextParser.splitIntoSentences(value ?? '');
              if (sentences.isEmpty) {
                return '请粘贴至少一个句子';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
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
    return SurfacePanel(
      padding: const EdgeInsets.all(18),
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.segment_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '句子预览',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Chip(label: Text('${sentences.length} 句')),
            ],
          ),
          const SizedBox(height: 12),
          if (sentences.isEmpty)
            Text(
              '粘贴原文后会按 . ! ? 自动拆句。',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else
            ...sentences.take(8).map(
                  (sentence) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes_outlined, size: 18, color: theme.colorScheme.secondary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(sentence)),
                      ],
                    ),
                  ),
                ),
          if (sentences.length > 8)
            Text(
              '另有 ${sentences.length - 8} 句未显示',
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3'],
      allowMultiple: false,
      withData: false,
    );
    final file = result?.files.single;
    if (file == null) {
      return;
    }
    if (file.path == null) {
      if (!mounted) {
        return;
      }
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
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_audioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先导入 MP3 音频')),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      final projectId = await context.read<AppState>().createProject(
            name: _nameController.text,
            sourceText: _textController.text,
            audioPath: _audioPath!,
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => TimelinePage(projectId: projectId)),
      );
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message.toString())),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.audio_file_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              audioName ?? '尚未导入 MP3 音频',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: onPick,
            icon: const Icon(Icons.upload_file),
            label: const Text('导入'),
          ),
        ],
      ),
    );
  }
}

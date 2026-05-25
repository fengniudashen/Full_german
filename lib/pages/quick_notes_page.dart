import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_card.dart';

/// 灵光一闪 — Quick notes for language learning insights.
class QuickNotesPage extends StatefulWidget {
  const QuickNotesPage({super.key, this.sourceSentence, this.projectName});
  final String? sourceSentence;
  final String? projectName;

  @override
  State<QuickNotesPage> createState() => _QuickNotesPageState();
}

class _QuickNotesPageState extends State<QuickNotesPage> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final notes = await context.read<AppState>().database.getNotes();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    await context.read<AppState>().database.insertNote(
      text,
      sourceSentence: widget.sourceSentence ?? '',
      projectName: widget.projectName ?? '',
    );
    _ctrl.clear();
    FocusScope.of(context).unfocus();
    await _load();
  }

  Future<void> _delete(int id) async {
    await context.read<AppState>().database.deleteNote(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('MM/dd HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('💡 灵光一闪')),
      body: Column(
        children: [
          // Input area
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: '记录你的学习灵感…',
                      border: OutlineInputBorder(
                        borderRadius: AppTheme.borderSm,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _add,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
          if (widget.sourceSentence != null && widget.sourceSentence!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: AppTheme.borderSm,
                ),
                child: Text(
                  '📌 ${widget.sourceSentence}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          const SizedBox(height: 8),
          // Notes list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _notes.isEmpty
                    ? const EmptyState(
                        icon: Icons.lightbulb_outline,
                        title: '还没有笔记',
                        message: '在学习中随时记录灵感和心得',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _notes.length,
                        itemBuilder: (context, i) {
                          final n = _notes[i];
                          final dt = DateTime.fromMillisecondsSinceEpoch(
                              n['created_at'] as int);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GlassCard(
                              child: ListTile(
                                title: Text(n['content'] as String),
                                subtitle: Text(
                                  [
                                    fmt.format(dt),
                                    if ((n['project_name'] as String)
                                        .isNotEmpty)
                                      n['project_name'] as String,
                                  ].join(' · '),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 20),
                                  onPressed: () => _delete(n['id'] as int),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

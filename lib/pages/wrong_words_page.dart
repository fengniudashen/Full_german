import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/study_project.dart';
import '../models/wrong_word.dart';
import '../providers/app_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/surface_panel.dart';

class WrongWordsPage extends StatefulWidget {
  const WrongWordsPage({super.key});

  @override
  State<WrongWordsPage> createState() => _WrongWordsPageState();
}

class _WrongWordsPageState extends State<WrongWordsPage> {
  int? _projectFilterId;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return RefreshIndicator(
          onRefresh: () => appState.loadWrongWords(projectId: _projectFilterId),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _buildToolbar(context, appState.projects),
                ),
              ),
              if (appState.wrongWords.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.spellcheck_outlined,
                    title: '暂无错词',
                    message: '听写核对后，红色错误会自动加入这里。',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index.isOdd) {
                          return const SizedBox(height: 8);
                        }
                        final wordIndex = index ~/ 2;
                        return _WrongWordTile(word: appState.wrongWords[wordIndex]);
                      },
                      childCount: appState.wrongWords.length * 2 - 1,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context, List<StudyProject> projects) {
    return SurfacePanel(
      padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: DropdownButtonFormField<int?>(
                value: _projectFilterId,
                decoration: const InputDecoration(
                  labelText: '按项目筛选',
                  prefixIcon: Icon(Icons.filter_list),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('全部项目'),
                  ),
                  ...projects.map(
                    (project) => DropdownMenuItem<int?>(
                      value: project.id,
                      child: Text(
                        project.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) async {
                  setState(() => _projectFilterId = value);
                  await context.read<AppState>().loadWrongWords(projectId: value);
                },
              ),
            ),
            FilledButton.icon(
              onPressed: _exporting ? null : _exportCsv,
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
              label: const Text('导出 CSV'),
            ),
          ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final file = await context
          .read<AppState>()
          .exportWrongWordsCsv(projectId: _projectFilterId);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'DeutschFlow 错词本 CSV',
        subject: 'DeutschFlow 错词本',
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }
}

class _WrongWordTile extends StatelessWidget {
  const _WrongWordTile({required this.word});

  final WrongWord word;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    return SurfacePanel(
      padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(word.wrongForm),
                  backgroundColor: const Color(0xFFFFEBEE),
                  side: const BorderSide(color: Color(0xFFE57373)),
                ),
                const Icon(Icons.arrow_forward, size: 18),
                Chip(
                  label: Text(word.correctForm),
                  backgroundColor: const Color(0xFFE8F5E9),
                  side: const BorderSide(color: Color(0xFF81C784)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(word.sentenceText),
            const SizedBox(height: 8),
            Text(
              '${word.projectName} · ${dateFormat.format(word.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
      ),
    );
  }
}

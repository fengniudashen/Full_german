import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'analysis_page.dart';
import 'bookmarks_page.dart';
import 'dashboard_page.dart';
import 'flashcard_page.dart';
import 'new_project_page.dart';
import 'projects_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'resource_hub_page.dart';
import 'wrong_words_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  static const _destinations = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard, '总览'),
    _NavItem(Icons.folder_outlined, Icons.folder, '项目'),
    _NavItem(Icons.explore_outlined, Icons.explore, '资源'),
    _NavItem(Icons.spellcheck_outlined, Icons.spellcheck, '错词本'),
    _NavItem(Icons.settings_outlined, Icons.settings, '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final extended = MediaQuery.sizeOf(context).width >= 1180;

    final pages = const [
      DashboardPage(),
      ProjectsPage(),
      ResourceHubPage(),
      WrongWordsPage(),
      SettingsPage(),
    ];

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _DesktopNavRail(
              selectedIndex: _selectedIndex,
              extended: extended,
              onSelect: (i) => setState(() => _selectedIndex = i),
            ),
            VerticalDivider(
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(
              child: Column(
                children: [
                  _DesktopTopBar(
                    title: _destinations[_selectedIndex].label,
                    showCreate: _selectedIndex == 1,
                    showSearch: true,
                    showFlashcard: _selectedIndex == 3,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: KeyedSubtree(
                        key: ValueKey(_selectedIndex),
                        child: pages[_selectedIndex],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile layout
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0
            ? 'DeutschFlow'
            : _destinations[_selectedIndex].label),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'AI 德语助手',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const AnalysisPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: '金句本',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const BookmarksPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SearchPage()),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: pages[_selectedIndex],
        ),
      ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              heroTag: 'create_project',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const NewProjectPage()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('新建'),
            )
          : _selectedIndex == 3
              ? FloatingActionButton.extended(
                  heroTag: 'flashcard',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const FlashcardPage()),
                  ),
                  icon: const Icon(Icons.style),
                  label: const Text('闪卡复习'),
                )
              : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: _destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.activeIcon),
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

// ═══════════════════════════════════════════════════════════════
//  Desktop Navigation Rail
// ═══════════════════════════════════════════════════════════════

class _DesktopNavRail extends StatelessWidget {
  const _DesktopNavRail({
    required this.selectedIndex,
    required this.extended,
    required this.onSelect,
  });

  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      extended: extended,
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelect,
      leading: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: _BrandMark(extended: extended),
      ),
      destinations: HomeShellState._destinations
          .map((d) => NavigationRailDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.activeIcon),
                label: Text(d.label),
              ))
          .toList(),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.extended});
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: isDark ? AppTheme.heroGradientDark : AppTheme.heroGradient,
            borderRadius: AppTheme.borderMd,
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.graphic_eq, color: Colors.white, size: 22),
        ),
        if (extended) ...[
          const SizedBox(width: 10),
          Text(
            'DeutschFlow',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Desktop Top Bar
// ═══════════════════════════════════════════════════════════════

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.title,
    required this.showCreate,
    required this.showSearch,
    this.showFlashcard = false,
  });

  final String title;
  final bool showCreate;
  final bool showSearch;
  final bool showFlashcard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          // Streak badge
          if (appState.streakDays > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppTheme.warmGradient,
                borderRadius: AppTheme.borderSm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${appState.streakDays} 天连续',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],

          if (showSearch) ...[
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'AI 德语助手',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const AnalysisPage()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.bookmark_outline),
              tooltip: '金句本',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const BookmarksPage()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SearchPage()),
              ),
            ),
          ],
          if (showCreate) ...[
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const NewProjectPage()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('新建项目'),
            ),
          ],
          if (showFlashcard) ...[
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const FlashcardPage()),
              ),
              icon: const Icon(Icons.style),
              label: const Text('闪卡复习'),
            ),
          ],
        ],
      ),
    );
  }
}

// Type alias for the private state so other widgets can reference _destinations
typedef HomeShellState = _HomeShellState;

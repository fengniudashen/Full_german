import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_page.dart';
import 'youtube_page.dart';
import 'podcast_page.dart';

/// 资源中心 — 汇集无需科学上网即可访问的德语学习音频/视频资源
class ResourceHubPage extends StatefulWidget {
  const ResourceHubPage({super.key});

  @override
  State<ResourceHubPage> createState() => _ResourceHubPageState();
}

class _ResourceHubPageState extends State<ResourceHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('资源中心'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.headphones), text: '播客/音频'),
            Tab(icon: Icon(Icons.video_library), text: '视频课程'),
            Tab(icon: Icon(Icons.menu_book), text: '阅读素材'),
            Tab(icon: Icon(Icons.apps), text: '工具/APP'),
            Tab(icon: Icon(Icons.download_rounded), text: '导入工具'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildList(_podcastResources),
          _buildList(_videoResources),
          _buildList(_readingResources),
          _buildList(_toolResources),
          _buildImportTools(),
        ],
      ),
    );
  }

  Widget _buildList(List<_Resource> resources) {
    return ResponsivePage(
      maxWidth: 900,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: resources.map((r) => _ResourceCard(resource: r)).toList(),
      ),
    );
  }

  Widget _buildImportTools() {
    final theme = Theme.of(context);
    return ResponsivePage(
      maxWidth: 900,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // YouTube importer card
          _ImportToolCard(
            icon: Icons.smart_display,
            title: 'YouTube 字幕导入',
            description: '从 YouTube 视频/播放列表中下载字幕，自动解析为练习句子。需要科学上网环境。',
            color: const Color(0xFFFF0000),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const YoutubePage()),
            ),
          ),
          const SizedBox(height: 12),
          // Podcast importer card
          _ImportToolCard(
            icon: Icons.podcasts,
            title: '播客 RSS 导入',
            description: '通过 RSS 链接导入播客音频。可以从上方「播客/音频」标签页复制 RSS 链接，粘贴到此处导入。',
            color: const Color(0xFF7C3AED),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PodcastPage()),
            ),
          ),
          const SizedBox(height: 24),
          // Tips section
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tips_and_updates, color: AppTheme.gold, size: 20),
                    const SizedBox(width: 8),
                    Text('使用提示',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _tipRow(theme, '1', '在「播客/音频」标签页中找到喜欢的资源'),
                _tipRow(theme, '2', '点击 RSS 链接旁的复制按钮'),
                _tipRow(theme, '3', '进入「播客 RSS 导入」粘贴链接即可导入'),
                _tipRow(theme, '4', '大陆用户推荐使用 DW (德国之声) 资源，无需科学上网'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipRow(ThemeData theme, String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(num,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.emerald,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Resource card widget
// ═══════════════════════════════════════════════════════════════

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.resource});
  final _Resource resource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: resource.color.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(resource.icon, color: resource.color, size: 24),
                ),
                const SizedBox(width: 14),
                // Title + tags
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _tag(context, resource.level, AppTheme.emerald),
                          if (resource.chinaAccessible)
                            _tag(context, '🇨🇳 国内可访问', const Color(0xFF059669)),
                          if (resource.free)
                            _tag(context, '免费', AppTheme.sky),
                          _tag(context, resource.type, AppTheme.lavender),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Description
            Text(
              resource.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            // URL row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, size: 14,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      resource.url,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: resource.url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已复制链接到剪贴板'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Icon(Icons.copy, size: 16,
                        color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
            // RSS feed if available
            if (resource.rssFeed != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: isDark ? 0.12 : 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.rss_feed, size: 14, color: AppTheme.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        resource.rssFeed!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.gold,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: resource.rssFeed!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已复制 RSS 链接 — 可粘贴到「播客导入」'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Icon(Icons.copy, size: 16,
                          color: AppTheme.gold),
                    ),
                  ],
                ),
              ),
            ],
            // Import button
            if (resource.canImport) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    if (resource.rssFeed != null) {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PodcastPage(initialUrl: resource.rssFeed),
                      ));
                    } else if (resource.youtubeUrl != null) {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => YoutubePage(initialUrl: resource.youtubeUrl),
                      ));
                    }
                  },
                  icon: Icon(
                    resource.rssFeed != null ? Icons.podcasts : Icons.smart_display,
                    size: 18,
                  ),
                  label: Text(
                    resource.rssFeed != null ? '一键导入播客' : '导入 YouTube 字幕',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: resource.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tag(BuildContext context, String text, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Import tool card widget
// ═══════════════════════════════════════════════════════════════

class _ImportToolCard extends StatelessWidget {
  const _ImportToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Resource model
// ═══════════════════════════════════════════════════════════════

class _Resource {
  const _Resource({
    required this.name,
    required this.description,
    required this.url,
    required this.icon,
    required this.color,
    required this.level,
    required this.type,
    this.rssFeed,
    this.youtubeUrl,
    this.chinaAccessible = true,
    this.free = true,
  });

  final String name;
  final String description;
  final String url;
  final IconData icon;
  final Color color;
  final String level;
  final String type;
  final String? rssFeed;
  final String? youtubeUrl;
  final bool chinaAccessible;
  final bool free;

  bool get canImport => rssFeed != null || youtubeUrl != null;
}

// ═══════════════════════════════════════════════════════════════
// Resource data — 国内可访问的德语学习资源
// ═══════════════════════════════════════════════════════════════

final _podcastResources = <_Resource>[
  const _Resource(
    name: 'Deutsche Welle — 慢速德语新闻',
    description: '德国之声每日慢速德语新闻播报，语速适中，配有文本。DW 在中国大陆可直接访问，是最佳的免费德语听力资源之一。',
    url: 'https://www.dw.com/de/deutsch-lernen/nachrichten/s-8030',
    rssFeed: 'https://rss.dw.com/xml/DKpodcast_lgn_de',
    icon: Icons.newspaper,
    color: Color(0xFF0D47A1),
    level: 'B1-B2',
    type: '新闻播报',
  ),
  const _Resource(
    name: 'Deutsche Welle — Langsam gesprochene Nachrichten',
    description: '每日更新的慢速德语新闻，每篇约5-8分钟。语速约为正常语速的70%，非常适合听写练习。可直接在播客导入中使用 RSS 链接。',
    url: 'https://www.dw.com/de/deutsch-lernen/nachrichten/s-8030',
    rssFeed: 'https://rss.dw.com/xml/DKpodcast_lgn_de',
    icon: Icons.speed,
    color: Color(0xFF1565C0),
    level: 'B1-B2',
    type: '慢速新闻',
  ),
  const _Resource(
    name: 'Deutsche Welle — Top-Thema',
    description: '每周多次更新的热门话题讲解，每篇约3-4分钟。配有词汇表和练习题，是中级学习者的最佳选择。',
    url: 'https://www.dw.com/de/deutsch-lernen/top-thema/s-8031',
    rssFeed: 'https://rss.dw.com/xml/DKpodcast_topthema_de',
    icon: Icons.trending_up,
    color: Color(0xFF1976D2),
    level: 'B1',
    type: '话题讲解',
  ),
  const _Resource(
    name: 'Deutsche Welle — Alltagsdeutsch',
    description: '日常德语节目，介绍德国文化、习俗和日常生活用语。语速适中，内容贴近生活。',
    url: 'https://www.dw.com/de/deutsch-lernen/alltagsdeutsch/s-9214',
    rssFeed: 'https://rss.dw.com/xml/DKpodcast_alltagsdeutsch_de',
    icon: Icons.people,
    color: Color(0xFF42A5F5),
    level: 'B2-C1',
    type: '日常对话',
  ),
  const _Resource(
    name: 'Slow German — Annik Rubens',
    description: '由 Annik Rubens 制作的慢速德语播客，涵盖德国文化、历史、社会等话题。语速非常慢，适合初中级学习者。',
    url: 'https://slowgerman.com',
    rssFeed: 'https://slowgerman.com/feed/mp3/',
    icon: Icons.mic,
    color: Color(0xFFE65100),
    level: 'A2-B1',
    type: '文化话题',
  ),
  const _Resource(
    name: 'Coffee Break German',
    description: '轻松愉快的德语学习播客，从零基础开始，循序渐进。每集约20分钟，适合通勤时收听。',
    url: 'https://coffeebreaklanguages.com/coffeebreakgerman/',
    rssFeed: 'https://podcast.coffeebreakacademy.com/feed/cbg-season-1',
    icon: Icons.coffee,
    color: Color(0xFF795548),
    level: 'A1-A2',
    type: '入门教学',
  ),
  const _Resource(
    name: '喜马拉雅FM — 德语学习频道',
    description: '国内最大的音频平台，搜索"德语"可找到大量德语学习节目，包括德语入门、德福备考、德语新闻等。完全无需科学上网。',
    url: 'https://www.ximalaya.com/search/德语',
    icon: Icons.headset,
    color: Color(0xFFF44336),
    level: 'A1-C1',
    type: '综合平台',
  ),
  const _Resource(
    name: '小宇宙 — 德语播客',
    description: '国内播客平台，有不少德语学习类播客。搜索"德语"或"Deutsch"即可找到。支持倍速播放和收藏。',
    url: 'https://www.xiaoyuzhoufm.com',
    icon: Icons.podcasts,
    color: Color(0xFF7C4DFF),
    level: 'A1-B2',
    type: '播客平台',
  ),
];

final _videoResources = <_Resource>[
  const _Resource(
    name: 'Deutsche Welle — Nicos Weg',
    description: '德国之声出品的免费德语视频课程，讲述 Nico 来到德国的故事。A1-B1 三个级别，每级约75集短视频，配有互动练习。制作精良，强烈推荐！',
    url: 'https://learngerman.dw.com/de/nicos-weg/c-36519789',
    youtubeUrl: 'https://www.youtube.com/playlist?list=PLs7zUO7VPyJ5JOA3m-dI4pLwlGiaNwnv9',
    icon: Icons.play_circle_fill,
    color: Color(0xFF0D47A1),
    level: 'A1-B1',
    type: '视频课程',
    chinaAccessible: false,
  ),
  const _Resource(
    name: 'Deutsche Welle — Harry (gefangen in der Zeit)',
    description: 'DW 制作的互动冒险德语学习视频课程，学习者跟随 Harry 穿越时空学德语。100集，适合 B1 水平。',
    url: 'https://learngerman.dw.com/de/harry-gefangen-in-der-zeit/c-45001506',
    icon: Icons.movie,
    color: Color(0xFF1565C0),
    level: 'B1',
    type: '互动课程',
  ),
  const _Resource(
    name: 'Bilibili — 德语学习',
    description: 'B站上有大量免费德语教学视频，包括语法讲解、发音教程、德福备考等。搜索"德语入门"、"德语语法"等关键词。推荐UP主：德语学习、柏林飞鸟等。',
    url: 'https://search.bilibili.com/all?keyword=德语学习',
    icon: Icons.smart_display,
    color: Color(0xFFFF6699),
    level: 'A1-C1',
    type: '视频平台',
  ),
  const _Resource(
    name: 'Bilibili — 德福备考',
    description: 'B站上的 TestDaF 备考资源，包括听力技巧、写作模板、口语训练等。搜索"德福"或"TestDaF"。',
    url: 'https://search.bilibili.com/all?keyword=德福备考',
    icon: Icons.school,
    color: Color(0xFFFF6699),
    level: 'B2-C1',
    type: '考试备考',
  ),
  const _Resource(
    name: 'TAGESSCHAU 100 Sekunden',
    description: '每日100秒新闻精华，YouTube 播放列表。有自动生成的德语字幕，非常适合听写练习。需要科学上网。',
    url: 'https://www.youtube.com/playlist?list=PLOixzgWxGZAmoeziLaRxdb29FA5FAF2Ty',
    youtubeUrl: 'https://www.youtube.com/playlist?list=PLOixzgWxGZAmoeziLaRxdb29FA5FAF2Ty',
    icon: Icons.timer,
    color: Color(0xFF01579B),
    level: 'B1-B2',
    type: 'YouTube',
    chinaAccessible: false,
  ),
  const _Resource(
    name: 'Easy German (YouTube)',
    description: '街头采访形式的德语学习频道，采访真实德国人。带德英双语字幕，适合了解日常口语和文化。需要科学上网。',
    url: 'https://www.youtube.com/@EasyGerman',
    youtubeUrl: 'https://www.youtube.com/@EasyGerman',
    icon: Icons.people,
    color: Color(0xFFE65100),
    level: 'A2-B2',
    type: 'YouTube',
    chinaAccessible: false,
  ),
  const _Resource(
    name: 'Deutsche Welle — Das Bandtagebuch',
    description: 'DW 的乐队日记系列，通过德国乐队 EINSHOCH6 的音乐和视频学习德语。适合喜欢音乐的学习者。',
    url: 'https://learngerman.dw.com/de/das-bandtagebuch/c-45001516',
    icon: Icons.music_video,
    color: Color(0xFF1976D2),
    level: 'B1-B2',
    type: '音乐学习',
  ),
  const _Resource(
    name: '网易公开课 — 德语',
    description: '网易公开课平台上的德语学习资源，包括大学公开课和语言教程。完全免费，国内直接访问。',
    url: 'https://open.163.com/search?query=德语',
    icon: Icons.cast_for_education,
    color: Color(0xFFD32F2F),
    level: 'A1-B2',
    type: '公开课',
  ),
  const _Resource(
    name: 'Goethe-Institut — 在线课程',
    description: '歌德学院官方在线学习平台，部分免费资源。包括分级练习、文化内容等。歌德学院官网在国内可访问。',
    url: 'https://www.goethe.de/ins/cn/zh/spr/ueb.html',
    icon: Icons.account_balance,
    color: Color(0xFF388E3C),
    level: 'A1-C1',
    type: '官方课程',
  ),
];

final _readingResources = <_Resource>[
  const _Resource(
    name: 'Deutsche Welle — 德语学习文本',
    description: 'DW 提供的分级阅读材料，每篇文章都标注了难度等级。Top-Thema 和 Video-Thema 附带词汇表和练习题。',
    url: 'https://www.dw.com/de/deutsch-lernen/s-2055',
    icon: Icons.article,
    color: Color(0xFF0D47A1),
    level: 'A1-C1',
    type: '分级阅读',
  ),
  const _Resource(
    name: 'nachrichtenleicht.de',
    description: 'Deutschlandfunk 制作的简单德语新闻网站，用简单的德语报道每周新闻。非常适合阅读练习，文本短小精悍。',
    url: 'https://www.nachrichtenleicht.de',
    icon: Icons.newspaper,
    color: Color(0xFF00695C),
    level: 'A2-B1',
    type: '简易新闻',
  ),
  const _Resource(
    name: 'Spiegel Online',
    description: '德国《明镜》周刊在线版，原汁原味的德语新闻。适合高级学习者进行阅读训练。国内可直接访问。',
    url: 'https://www.spiegel.de',
    icon: Icons.chrome_reader_mode,
    color: Color(0xFFE65100),
    level: 'C1-C2',
    type: '新闻媒体',
  ),
  const _Resource(
    name: 'tagesschau.de',
    description: '德国第一电视台 ARD 的新闻网站，提供文本和视频。每日更新，适合配合听写使用。',
    url: 'https://www.tagesschau.de',
    icon: Icons.tv,
    color: Color(0xFF01579B),
    level: 'B2-C1',
    type: '电视新闻',
  ),
  const _Resource(
    name: 'DWDS — Digitales Wörterbuch',
    description: '德语数字词典，提供详细的词义解释、例句、词源和用法统计。适合查询生词和深入理解词汇。',
    url: 'https://www.dwds.de',
    icon: Icons.menu_book,
    color: Color(0xFF4527A0),
    level: 'B1-C2',
    type: '词典工具',
  ),
  const _Resource(
    name: 'Grimms Märchen Online',
    description: '格林童话在线版，适合初中级学习者阅读练习。童话故事结构简单，词汇重复率高，是很好的阅读材料。',
    url: 'https://www.grimmstories.com/de/grimm_maerchen',
    icon: Icons.auto_stories,
    color: Color(0xFF6A1B9A),
    level: 'A2-B1',
    type: '文学作品',
  ),
  const _Resource(
    name: 'Zeit Online — leichte Sprache',
    description: '《时代》周刊在线版，部分内容有"leichte Sprache"(简单语言)版本。适合中级阅读练习。',
    url: 'https://www.zeit.de',
    icon: Icons.public,
    color: Color(0xFF263238),
    level: 'B2-C1',
    type: '深度新闻',
  ),
];

final _toolResources = <_Resource>[
  const _Resource(
    name: 'Anki — 间隔重复记忆',
    description: '最强大的记忆卡片工具，支持自制卡片和社区分享卡组。DeutschFlow 支持导出 Anki 格式，可直接导入使用。',
    url: 'https://apps.ankiweb.net',
    icon: Icons.style,
    color: Color(0xFF1565C0),
    level: 'A1-C2',
    type: '记忆工具',
  ),
  const _Resource(
    name: 'dict.cc — 德英/德中词典',
    description: '优秀的在线词典，支持德英、德中互译。词库丰富，有发音和例句。国内可直接访问。',
    url: 'https://www.dict.cc',
    icon: Icons.translate,
    color: Color(0xFF2E7D32),
    level: 'A1-C2',
    type: '在线词典',
  ),
  const _Resource(
    name: 'Linguee — 语境词典',
    description: '语境词典，展示真实翻译语境中的用法。可以看到词汇在真实文档中的翻译方式，有助于理解词义。',
    url: 'https://www.linguee.de',
    icon: Icons.find_in_page,
    color: Color(0xFF00838F),
    level: 'A2-C1',
    type: '语境词典',
  ),
  const _Resource(
    name: 'Verbformen.de — 动词变位',
    description: '最全面的德语动词变位查询工具。输入任意形式即可查看完整变位表，包括虚拟式和被动态。',
    url: 'https://www.verbformen.de',
    icon: Icons.text_rotation_none,
    color: Color(0xFF6A1B9A),
    level: 'A1-C1',
    type: '语法工具',
  ),
  const _Resource(
    name: 'Forvo — 发音词典',
    description: '真人发音词典，由母语者录制。可以听到不同地区、不同说话者的发音，非常适合纠正发音。',
    url: 'https://forvo.com/languages/de/',
    icon: Icons.record_voice_over,
    color: Color(0xFFE65100),
    level: 'A1-C2',
    type: '发音工具',
  ),
  const _Resource(
    name: 'LanguageTool — 语法检查',
    description: '免费的德语语法和拼写检查工具。可以检查大小写、标点、语法错误等。支持浏览器插件。',
    url: 'https://languagetool.org/de',
    icon: Icons.spellcheck,
    color: Color(0xFF1976D2),
    level: 'A2-C1',
    type: '写作工具',
  ),
  const _Resource(
    name: 'Leo.org — 在线词典',
    description: '德国最受欢迎的在线词典之一，支持德英、德中等多语种。有论坛社区可以讨论疑难词汇。',
    url: 'https://dict.leo.org/chinesisch-deutsch/',
    icon: Icons.language,
    color: Color(0xFFF57F17),
    level: 'A1-C2',
    type: '在线词典',
  ),
  const _Resource(
    name: 'Duden — 正写法词典',
    description: '德语权威词典 Duden 的在线版。提供标准拼写、释义和语法信息。是德语学习者的终极参考。',
    url: 'https://www.duden.de',
    icon: Icons.gavel,
    color: Color(0xFFFFD600),
    level: 'B1-C2',
    type: '权威词典',
  ),
];

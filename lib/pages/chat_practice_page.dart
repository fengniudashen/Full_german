import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

/// AI German conversation practice — chat with AI in German,
/// get real-time corrections and suggestions.
class ChatPracticePage extends StatefulWidget {
  const ChatPracticePage({super.key});

  @override
  State<ChatPracticePage> createState() => _ChatPracticePageState();
}

class _ChatPracticePageState extends State<ChatPracticePage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  String _scenario = 'free'; // current conversation scenario

  static const _scenarios = <String, String>{
    'free': '自由对话',
    'cafe': '咖啡馆点餐',
    'market': '超市购物',
    'arzt': '看医生',
    'bahnhof': '火车站问路',
    'wohnung': '租房看房',
    'vorstellung': '自我介绍',
    'arbeit': '工作面试',
  };

  static const _scenarioPrompts = <String, String>{
    'free': '你是一位友善的德语母语者。请和学生用德语自由对话。适时纠正语法错误。',
    'cafe': '你是一位德国咖啡馆的服务员。用德语接待顾客点餐。菜单有: Kaffee(€2.50), Cappuccino(€3.50), Kuchen(€4.00), Brötchen(€2.00)。',
    'market': '你是德国超市的收银员。用德语和顾客交流。帮助他们找到商品、告知价格。',
    'arzt': '你是一位德国医生。用德语询问病人的症状，给出建议。请使用简单清晰的德语。',
    'bahnhof': '你是一位在德国火车站的工作人员。用德语帮助旅客查询列车信息、购票。',
    'wohnung': '你是一位德国房东。用德语向租客介绍公寓（2室1厅, 60m², 月租€800, 含暖气）。',
    'vorstellung': '你是一位新同事。用德语和新来的同事互相认识。询问名字、来自哪里、爱好等。',
    'arbeit': '你是一位德国公司的面试官。用德语进行简单的面试。询问工作经验、技能、为什么想加入等。',
  };

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startNewConversation(String scenario) {
    setState(() {
      _scenario = scenario;
      _messages.clear();
    });
    _sendSystemGreeting();
  }

  Future<void> _sendSystemGreeting() async {
    setState(() => _isLoading = true);

    try {
      final provider = context.read<AppState>().settings.activeProvider;
      final service = AiService(provider: provider);

      final prompt = '${_scenarioPrompts[_scenario]}\n\n'
          '请先用德语打招呼开始对话。在每次回复末尾，用【纠正】标签指出用户的语法错误（如果有的话），用【提示】给出下一句话的建议。'
          '对话要自然，每次只说1-2句话，不要太长。';

      final response = await service.chatRaw(prompt);
      if (!mounted) return;

      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', content: response));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(role: 'system', content: '连接AI失败: $e'));
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final provider = context.read<AppState>().settings.activeProvider;
      final service = AiService(provider: provider);

      // Build conversation history for context
      final history = StringBuffer();
      history.writeln('场景设定: ${_scenarioPrompts[_scenario]}');
      history.writeln('规则: 用德语对话。每次回复末尾用【纠正】指出语法错误，用【提示】建议下一句。每次只说1-2句话。');
      history.writeln();
      for (final msg in _messages) {
        if (msg.role == 'user') {
          history.writeln('学生: ${msg.content}');
        } else if (msg.role == 'assistant') {
          history.writeln('你: ${msg.content}');
        }
      }
      history.writeln();
      history.writeln('请继续对话，回复学生最后一句话。');

      final response = await service.chatRaw(history.toString());
      if (!mounted) return;

      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', content: response));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(role: 'system', content: '请求失败: $e'));
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('德语对话练习'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.theater_comedy),
            tooltip: '选择场景',
            onSelected: _startNewConversation,
            itemBuilder: (_) => _scenarios.entries.map((e) {
              return PopupMenuItem(
                value: e.key,
                child: Row(
                  children: [
                    Icon(
                      _scenario == e.key ? Icons.check : Icons.circle_outlined,
                      size: 18,
                      color: _scenario == e.key ? scheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    Text(e.value),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Scenario banner
          if (_messages.isEmpty)
            _buildScenarioSelector(theme, scheme)
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: scheme.primaryContainer.withValues(alpha: 0.3),
              child: Text(
                '场景: ${_scenarios[_scenario]}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          // Chat messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text('选择场景开始对话练习',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        )),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildTypingIndicator(scheme);
                      }
                      return _buildMessageBubble(_messages[index], theme);
                    },
                  ),
          ),
          // Input bar
          _buildInputBar(theme, scheme),
        ],
      ),
    );
  }

  Widget _buildScenarioSelector(ThemeData theme, ColorScheme scheme) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择对话场景',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                )),
            const SizedBox(height: 8),
            Text('AI 会扮演对应角色，和你用德语对话。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                )),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.5,
                children: _scenarios.entries.map((e) {
                  final icons = {
                    'free': Icons.chat_bubble_outline,
                    'cafe': Icons.coffee,
                    'market': Icons.shopping_cart,
                    'arzt': Icons.local_hospital,
                    'bahnhof': Icons.train,
                    'wohnung': Icons.home,
                    'vorstellung': Icons.people,
                    'arbeit': Icons.business_center,
                  };
                  return GlassCard(
                    padding: EdgeInsets.zero,
                    child: InkWell(
                      onTap: () => _startNewConversation(e.key),
                      borderRadius: AppTheme.borderMd,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(icons[e.key] ?? Icons.chat,
                                color: scheme.primary, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(e.value,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  )),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, ThemeData theme) {
    final isUser = msg.role == 'user';
    final isSystem = msg.role == 'system';
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: isSystem ? scheme.error : scheme.primaryContainer,
              child: Icon(
                isSystem ? Icons.warning : Icons.smart_toy,
                size: 18,
                color: isSystem ? Colors.white : scheme.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? scheme.primary
                    : isSystem
                        ? scheme.errorContainer
                        : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: SelectableText(
                msg.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isUser
                      ? scheme.onPrimary
                      : isSystem
                          ? scheme.onErrorContainer
                          : scheme.onSurface,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: scheme.secondary,
              child: Icon(Icons.person, size: 18, color: scheme.onSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.primaryContainer,
            child: Icon(Icons.smart_toy, size: 18, color: scheme.primary),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: SizedBox(
              width: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (i) => _Dot(delay: i * 200)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant, width: 0.5)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: '用德语输入…',
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                maxLines: null,
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: _isLoading ? null : _sendMessage,
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  _ChatMessage({required this.role, required this.content});
  final String role; // 'user', 'assistant', 'system'
  final String content;
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delay});
  final int delay;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.3 + _ctrl.value * 0.5),
        ),
      ),
    );
  }
}

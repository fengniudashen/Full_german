import 'dart:convert';
import 'dart:io';

/// AI service using DeepSeek API for grammar analysis, translation, etc.
class AiService {
  AiService({required this.apiKey, this.baseUrl = 'https://api.deepseek.com'});

  final String apiKey;
  final String baseUrl;
  static const _model = 'deepseek-chat';

  /// Look up a word with its sentence context.
  Future<String> lookupWord(String word, String sentenceContext) async {
    return _chat('''
你是一位专业的德语教师。请对以下德语单词进行详细解析：

**单词：** $word
**上下文句子：** $sentenceContext

请提供以下信息：
1. **词性** (名词/动词/形容词等)
2. **基本释义** (中文)
3. **词形变化** (如果是名词：性/复数；动词：变位；形容词：比较级等)
4. **在本句中的含义与用法**
5. **常见搭配** (2-3个)
6. **例句** (1-2个简单例句)

请用简洁明了的中文回答。
''');
  }

  /// Analyze the grammar of a sentence.
  Future<String> analyzeGrammar(String sentence) async {
    return _chat('''
你是一位专业的德语教师。请对以下德语句子进行详细的语法分析：

**句子：** $sentence

请提供以下分析：
1. **句型结构** (主句/从句/并列句等)
2. **动词分析** (时态、语态、位置)
3. **各成分标注** (主语、谓语、宾语、状语、定语等)
4. **重点语法现象** (框架结构、从句语序、被动语态等)
5. **关键语法规则** (简要解释涉及的语法要点)

请用简洁明了的中文回答。
''');
  }

  /// Translate a sentence with explanations.
  Future<String> translate(String sentence) async {
    return _chat('''
你是一位专业的德语翻译。请翻译以下德语句子：

**原文：** $sentence

请提供：
1. **直译** (尽量保留原文结构)
2. **意译** (流畅的中文表达)
3. **关键词汇** (列出3-5个重要词汇及释义)
4. **文化/背景注释** (如有相关背景知识)

请用简洁明了的中文回答。
''');
  }

  /// Analyze a text fragment / phrase.
  Future<String> analyzePhrase(String phrase, String? context) async {
    final contextPart = context != null ? '\n**上下文：** $context' : '';
    return _chat('''
你是一位专业的德语教师。请解析以下德语片段：

**片段：** $phrase$contextPart

请提供：
1. **含义** (中文释义)
2. **语法分析** (成分、搭配)
3. **是否为固定搭配/惯用语** 
4. **类似表达** (如有)
5. **用法说明与例句**

请用简洁明了的中文回答。
''');
  }

  /// Free-form question about German language.
  Future<String> ask(String question) async {
    return _chat('''
你是一位专业的德语教师，精通德语语法、词汇和文化。请回答以下关于德语学习的问题：

$question

请用简洁明了的中文回答。如果问题涉及具体德语内容，请附上德语原文。
''');
  }

  /// Generate example sentences using a word/phrase.
  Future<String> makeSentences(String wordOrPhrase, String? context) async {
    final ctxPart = context != null ? '\n**来源句子：** $context' : '';
    return _chat('''
你是一位专业的德语教师。请用以下德语词汇/片段造句：

**词汇/片段：** $wordOrPhrase$ctxPart

请提供：
1. **5个由简到难的例句**（附中文翻译）
2. **涵盖不同场景**（日常、正式、新闻、口语等）
3. **标注关键语法点**（如果涉及特殊语法结构）

请用简洁明了的中文和德语对照回答。
''');
  }

  /// Find synonyms for a word/phrase.
  Future<String> synonyms(String wordOrPhrase, String? context) async {
    final ctxPart = context != null ? '\n**上下文：** $context' : '';
    return _chat('''
你是一位专业的德语教师。请给出以下德语词汇/表达的近义词和近义表达：

**词汇/表达：** $wordOrPhrase$ctxPart

请提供：
1. **近义词列表**（4-6个，附中文释义）
2. **各词的细微差别**（语义、语气、使用场景的区别）
3. **替换例句**（用近义词改写原句或造新句，2-3个）
4. **常见搭配差异**（各近义词的典型搭配）

请用简洁明了的中文回答，所有德语词附上中文释义。
''');
  }

  /// Find antonyms for a word/phrase.
  Future<String> antonyms(String wordOrPhrase, String? context) async {
    final ctxPart = context != null ? '\n**上下文：** $context' : '';
    return _chat('''
你是一位专业的德语教师。请给出以下德语词汇/表达的反义词和对立表达：

**词汇/表达：** $wordOrPhrase$ctxPart

请提供：
1. **反义词列表**（3-5个，附中文释义）
2. **用法对比**（反义词之间的语义差异和使用场景）
3. **对比例句**（用反义词造对比句，2-3组）
4. **相关词族**（同根词、词组搭配中的对立用法）

请用简洁明了的中文回答，所有德语词附上中文释义。
''');
  }

  /// Explain conjugation / declension of a word.
  Future<String> conjugate(String word, String? context) async {
    final ctxPart = context != null ? '\n**上下文：** $context' : '';
    return _chat('''
你是一位专业的德语教师。请给出以下德语词汇的完整变形表：

**词汇：** $word$ctxPart

请根据词性提供：
- **动词**：现在时/过去时/现在完成时的完整变位，命令式，第二虚拟式
- **名词**：性/单复数/四格变化表
- **形容词**：比较级/最高级，强/弱/混合变格表

请用表格或列表形式清晰展示。
''');
  }

  /// Rewrite / paraphrase a sentence in different styles.
  Future<String> rewrite(String sentence) async {
    return _chat('''
你是一位专业的德语教师。请用不同方式改写以下德语句子：

**原句：** $sentence

请提供以下改写版本：
1. **口语化**（日常会话风格）
2. **正式/书面**（正式信件或学术风格）
3. **简化版**（更简单的词汇和句式，适合初学者）
4. **新闻体**（新闻报道风格）
5. **被动语态**（如果原句是主动语态，反之亦然）

每个版本附上中文翻译和简要说明改写要点。
''');
  }

  Future<String> _chat(String prompt) async {
    if (apiKey.isEmpty) {
      return '⚠️ 请先在设置中配置 DeepSeek API Key。\n\n'
          '获取方式：访问 https://platform.deepseek.com 注册并创建 API Key。';
    }

    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl/v1/chat/completions');
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $apiKey');

      final body = jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.3,
        'max_tokens': 2000,
      });
      request.write(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        final error = jsonDecode(responseBody);
        final message = error['error']?['message'] ?? '未知错误';
        return '❌ API 错误 (${response.statusCode}): $message';
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        return '❌ 无响应内容。';
      }
      return (choices[0]['message']['content'] as String).trim();
    } on SocketException catch (e) {
      return '❌ 网络错误: $e\n\n请检查网络连接。';
    } catch (e) {
      return '❌ 请求失败: $e';
    } finally {
      client.close();
    }
  }
}

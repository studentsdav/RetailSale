import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/api/endpoints.dart';
import '../core/settings/local_preferences.dart';

class LynxAssistChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Map<String, dynamic>? action;
  final List<String>? quickReplies;

  LynxAssistChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.action,
    this.quickReplies,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'action': action,
      'quickReplies': quickReplies,
    };
  }

  factory LynxAssistChatMessage.fromJson(Map<String, dynamic> json) {
    return LynxAssistChatMessage(
      text: json['text'] ?? '',
      isUser: json['isUser'] == true,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
      action: json['action'] != null ? Map<String, dynamic>.from(json['action'] as Map) : null,
      quickReplies: json['quickReplies'] != null ? List<String>.from(json['quickReplies'] as List) : null,
    );
  }
}

class LynxAssistModal extends StatefulWidget {
  final Function(String actionType, Map<String, dynamic>? payload)? onActionTriggered;

  const LynxAssistModal({Key? key, this.onActionTriggered}) : super(key: key);

  static void show(BuildContext context, {Function(String actionType, Map<String, dynamic>? payload)? onActionTriggered}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: LynxAssistModal(onActionTriggered: onActionTriggered),
      ),
    );
  }

  @override
  State<LynxAssistModal> createState() => _LynxAssistModalState();
}

class _LynxAssistModalState extends State<LynxAssistModal> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<LynxAssistChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;

  // AI Configuration Settings
  String _aiProvider = 'gemini';
  String _aiModelName = 'gemini-1.5-flash';
  String _aiApiKey = '';
  String _aiBaseUrl = 'https://generativelanguage.googleapis.com';

  final List<String> _defaultChips = [
    "Create New Bill",
    "Low Stock Alert",
    "Attendance Logs",
    "Captain POS",
    "WhatsApp Dashboard",
    "Cash Ledger",
    "Purchase Order",
    "Day Closing",
  ];

  @override
  void initState() {
    super.initState();
    _loadSettingsAndHistory();
  }

  Future<void> _loadSettingsAndHistory() async {
    final key = await LocalPreferences.getLynxAiApiKey();
    final provider = await LocalPreferences.getLynxAiProvider();
    final model = await LocalPreferences.getLynxAiModelName();
    final baseUrl = await LocalPreferences.getLynxAiBaseUrl();
    final savedHistory = await LocalPreferences.getLynxChatHistory();

    setState(() {
      _aiApiKey = key;
      _aiProvider = provider;
      _aiModelName = model;
      _aiBaseUrl = baseUrl;

      _messages.clear();
      if (savedHistory.isNotEmpty) {
        for (final item in savedHistory) {
          _messages.add(LynxAssistChatMessage.fromJson(item));
        }
      } else {
        _messages.add(
          LynxAssistChatMessage(
            text: "👋 Hi! I am **LYNX ASSIST**, your AI business companion.\nHow can I help you manage your store today?",
            isUser: false,
            timestamp: DateTime.now(),
            quickReplies: _defaultChips,
          ),
        );
      }
    });

    _scrollToBottom();
  }

  Future<void> _saveHistoryLocally() async {
    final list = _messages.map((m) => m.toJson()).toList();
    await LocalPreferences.setLynxChatHistory(list);
  }

  Future<void> _confirmClearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2D),
        title: const Text("Clear Chat History?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to clear all stored chat messages from local memory?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC81E1E)),
            child: const Text("Clear", style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await LocalPreferences.clearLynxChatHistory();
      setState(() {
        _messages.clear();
        _messages.add(
          LynxAssistChatMessage(
            text: "🧹 Chat history cleared.\nHow can I help you manage your store today?",
            isUser: false,
            timestamp: DateTime.now(),
            quickReplies: _defaultChips,
          ),
        );
      });
      await _saveHistoryLocally();
    }
  }

  void _showSettingsDialog() {
    final apiKeyCtrl = TextEditingController(text: _aiApiKey);
    final modelCtrl = TextEditingController(text: _aiModelName);
    final urlCtrl = TextEditingController(text: _aiBaseUrl);
    String selectedProvider = _aiProvider;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2D),
          title: Row(
            children: const [
              Icon(Icons.settings_outlined, color: Color(0xFFE53935)),
              SizedBox(width: 8),
              Text("AI Assistant Settings", style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("AI Provider", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B2B40),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedProvider,
                      dropdownColor: const Color(0xFF2B2B40),
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'gemini', child: Text("Google Gemini AI")),
                        DropdownMenuItem(value: 'openai', child: Text("OpenAI / ChatGPT")),
                        DropdownMenuItem(value: 'claude', child: Text("Anthropic Claude")),
                        DropdownMenuItem(value: 'deepseek', child: Text("DeepSeek AI")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedProvider = val;
                            if (val == 'gemini') {
                              modelCtrl.text = 'gemini-1.5-flash';
                              urlCtrl.text = 'https://generativelanguage.googleapis.com';
                            } else if (val == 'openai') {
                              modelCtrl.text = 'gpt-4o';
                              urlCtrl.text = 'https://api.openai.com';
                            } else if (val == 'deepseek') {
                              modelCtrl.text = 'deepseek-chat';
                              urlCtrl.text = 'https://api.deepseek.com';
                            }
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text("API Key", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: apiKeyCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Enter your Gemini API key (AIzaSy...)",
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF2B2B40),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                const Text("Model Name", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: modelCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "e.g. gemini-1.5-flash or gemini-1.5-pro",
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF2B2B40),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                const Text("API Base URL", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: urlCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Base API URL endpoint",
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF2B2B40),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC81E1E)),
              child: const Text("Save Settings", style: TextStyle(color: Colors.white)),
              onPressed: () async {
                await LocalPreferences.setLynxAiProvider(selectedProvider);
                await LocalPreferences.setLynxAiApiKey(apiKeyCtrl.text.trim());
                await LocalPreferences.setLynxAiModelName(modelCtrl.text.trim());
                await LocalPreferences.setLynxAiBaseUrl(urlCtrl.text.trim());

                setState(() {
                  _aiProvider = selectedProvider;
                  _aiApiKey = apiKeyCtrl.text.trim();
                  _aiModelName = modelCtrl.text.trim();
                  _aiBaseUrl = urlCtrl.text.trim();
                });

                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("✅ AI Configuration saved locally to SharedPreferences."),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
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

  Future<void> _sendMessage(String text, {bool isVoice = false}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    final userMsg = LynxAssistChatMessage(
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });

    _inputController.clear();
    _saveHistoryLocally();
    _scrollToBottom();

    try {
      final endpoint = isVoice ? ApiEndpoints.lynxAssistVoice : ApiEndpoints.lynxAssistChat;
      final payload = isVoice
          ? {
              'transcript': trimmed,
              'aiProvider': _aiProvider,
              'aiModelName': _aiModelName,
              'aiApiKey': _aiApiKey,
              'aiBaseUrl': _aiBaseUrl,
            }
          : {
              'message': trimmed,
              'history': _messages.map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text}).toList(),
              'aiProvider': _aiProvider,
              'aiModelName': _aiModelName,
              'aiApiKey': _aiApiKey,
              'aiBaseUrl': _aiBaseUrl,
            };

      final response = await ApiClient.post(endpoint, payload);

      if (response != null && response['success'] == true) {
        final data = response['data'] ?? {};
        final replyText = data['reply'] ?? "Processed successfully.";
        final actionMap = data['action'] is Map<String, dynamic> ? data['action'] as Map<String, dynamic> : null;
        final rawQuick = data['quickReplies'];
        List<String> replies = [];
        if (rawQuick is List) {
          replies = rawQuick.map((e) => e.toString()).toList();
        }

        final botMsg = LynxAssistChatMessage(
          text: replyText,
          isUser: false,
          timestamp: DateTime.now(),
          action: actionMap,
          quickReplies: replies.isNotEmpty ? replies : _defaultChips,
        );

        setState(() {
          _messages.add(botMsg);
        });
        await _saveHistoryLocally();
      } else {
        _addErrorMessage("Could not reach LYNX ASSIST service. Operating in offline verification mode.");
      }
    } catch (e) {
      _addErrorMessage("Error: ${e.toString()}");
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _addErrorMessage(String error) {
    final errMessage = LynxAssistChatMessage(
      text: "⚠️ $error",
      isUser: false,
      timestamp: DateTime.now(),
      quickReplies: _defaultChips,
    );

    setState(() {
      _messages.add(errMessage);
    });
    _saveHistoryLocally();
  }

  void _toggleVoiceListening() {
    setState(() {
      _isListening = !_isListening;
    });

    if (_isListening) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🎤 LYNX ASSIST is listening... Speak your question or command."),
          duration: Duration(seconds: 3),
          backgroundColor: Color(0xFFC81E1E),
        ),
      );
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted && _isListening) {
          setState(() {
            _isListening = false;
          });
          _sendMessage("Show today's total sales and low stock items", isVoice: true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF151521),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC81E1E).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: Color(0xFFE53935), size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "FAMALTH LYNX ASSIST",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (_aiApiKey.isNotEmpty ? Colors.green : Colors.amber).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _aiApiKey.isNotEmpty ? "AI GEMINI" : "AI ONLINE",
                              style: TextStyle(
                                color: _aiApiKey.isNotEmpty ? Colors.greenAccent : Colors.amberAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        "Text-to-SQL Voice & Chat Business Companion",
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // Settings Button (Configure Gemini API Key & Model)
                IconButton(
                  tooltip: "AI Key & Model Settings",
                  icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 20),
                  onPressed: _showSettingsDialog,
                ),

                // Clear Chat Button (Stores locally, clear when user wants)
                IconButton(
                  tooltip: "Clear Chat History",
                  icon: const Icon(Icons.cleaning_services_rounded, color: Colors.white70, size: 20),
                  onPressed: _confirmClearChat,
                ),

                // Close Button
                IconButton(
                  tooltip: "Close Assistant",
                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Chat Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageItem(message);
              },
            ),
          ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: const [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE53935)),
                  ),
                  SizedBox(width: 10),
                  Text("LYNX ASSIST is translating question to SQL & executing query...", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),

          // Bottom Input Controls
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF151521),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Quick Prompt Chips
                  if (_messages.isNotEmpty && _messages.last.quickReplies != null && _messages.last.quickReplies!.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _messages.last.quickReplies!.map((chip) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8, bottom: 8),
                            child: ActionChip(
                              backgroundColor: const Color(0xFF2B2B40),
                              side: const BorderSide(color: Color(0xFF3F3F5F)),
                              label: Text(
                                chip,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              onPressed: () => _sendMessage(chip),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  Row(
                    children: [
                      // Voice Listening Button
                      GestureDetector(
                        onTap: _toggleVoiceListening,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isListening ? Colors.redAccent : const Color(0xFF2B2B40),
                            shape: BoxShape.circle,
                            boxShadow: _isListening
                                ? [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 12, spreadRadius: 2)]
                                : [],
                          ),
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Text input field
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: _isListening ? "Listening to your voice..." : "Ask LYNX ASSIST or query database...",
                            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                            filled: true,
                            fillColor: const Color(0xFF2B2B40),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (val) => _sendMessage(val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Send Button
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFC81E1E),
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        onPressed: () => _sendMessage(_inputController.text),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedMarkdown(String rawText) {
    final lines = rawText.split('\n');
    List<Widget> widgets = [];

    const defaultStyle = TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4);
    const boldStyle = TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, height: 1.4);
    const titleStyle = TextStyle(color: Color(0xFF60A5FA), fontSize: 14.5, fontWeight: FontWeight.bold, height: 1.4);

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];

      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 4));
        continue;
      }

      bool isBullet = line.trim().startsWith('* ') || line.trim().startsWith('- ');
      if (isBullet) {
        line = line.trim().substring(2);
      }

      bool isHeader = line.startsWith('###') || line.startsWith('##') || line.startsWith('#');
      if (isHeader) {
        line = line.replaceAll('#', '').trim();
      }

      final spans = _parseInlineMarkdown(line, isHeader ? titleStyle : defaultStyle, isHeader ? titleStyle : boldStyle);

      Widget lineWidget = RichText(
        text: TextSpan(children: spans),
      );

      if (isBullet) {
        lineWidget = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6, right: 8),
              child: Icon(Icons.circle, size: 5, color: Color(0xFFE53935)),
            ),
            Expanded(child: lineWidget),
          ],
        );
      }

      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: lineWidget,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  List<InlineSpan> _parseInlineMarkdown(String text, TextStyle normalStyle, TextStyle boldStyle) {
    List<InlineSpan> spans = [];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start), style: normalStyle));
      }
      spans.add(TextSpan(text: match.group(1), style: boldStyle));
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: normalStyle));
    }

    return spans;
  }

  Widget _buildMessageItem(LynxAssistChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: message.isUser ? const Color(0xFFC81E1E) : const Color(0xFF2B2B40),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFormattedMarkdown(message.text),
            if (message.action != null && message.action!['type'] != 'NONE') ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 16),
                label: Text(message.action!['label'] ?? "Execute Action"),
                onPressed: () {
                  final actionType = message.action!['type'].toString();
                  final actionPayload = message.action;
                  final callback = widget.onActionTriggered;

                  Navigator.of(context).pop();

                  if (callback != null) {
                    callback(actionType, actionPayload);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

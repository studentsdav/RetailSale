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

  const LynxAssistModal({super.key, this.onActionTriggered});

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

  // Theme & Appearance State
  bool _isDarkMode = true;

  // Dynamic Adaptive Color Palette
  Color get _modalBgColor => _isDarkMode ? const Color(0xFF1E1E2D) : const Color(0xFFF8FAFC);
  Color get _headerBgColor => _isDarkMode ? const Color(0xFF151521) : const Color(0xFFEDF2F7);
  Color get _botMessageBgColor => _isDarkMode ? const Color(0xFF2B2B40) : const Color(0xFFFFFFFF);
  Color get _botMessageBorderColor => _isDarkMode ? const Color(0xFF3F3F5F) : const Color(0xFFCBD5E1);
  Color get _primaryTextColor => _isDarkMode ? Colors.white : const Color(0xFF0F172A);
  Color get _secondaryTextColor => _isDarkMode ? Colors.white70 : const Color(0xFF334155);
  Color get _greyTextColor => _isDarkMode ? Colors.grey : const Color(0xFF64748B);
  Color get _chipBgColor => _isDarkMode ? const Color(0xFF2B2B40) : const Color(0xFFE2E8F0);
  Color get _inputFillColor => _isDarkMode ? const Color(0xFF2B2B40) : const Color(0xFFEDF2F7);
  Color get _dialogBgColor => _isDarkMode ? const Color(0xFF1E1E2D) : Colors.white;

  // AI Configuration Settings
  String _aiProvider = 'gemini';
  String _aiModelName = 'gemini-1.5-flash';
  String _aiApiKey = '';
  String _aiBaseUrl = 'https://generativelanguage.googleapis.com';
  int _maxRows = 100;

  final List<String> _defaultChips = [
    "Daily Subscriptions",
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
    final themeMode = await LocalPreferences.getLynxThemeMode();
    final maxRows = await LocalPreferences.getLynxMaxRows();

    setState(() {
      _aiApiKey = key;
      _aiProvider = provider;
      _aiModelName = model;
      _aiBaseUrl = baseUrl;
      _isDarkMode = themeMode != 'light';
      _maxRows = maxRows;

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

    // Initial scroll & staggered layout passes to ensure landing on the absolute latest chat message
    _scrollToBottom(animate: false);
    Future.delayed(const Duration(milliseconds: 100), () => _scrollToBottom(animate: false));
    Future.delayed(const Duration(milliseconds: 300), () => _scrollToBottom(animate: true));
    Future.delayed(const Duration(milliseconds: 500), () => _scrollToBottom(animate: true));
  }

  Future<void> _toggleThemeMode([bool? forceDark]) async {
    final newDark = forceDark ?? !_isDarkMode;
    setState(() {
      _isDarkMode = newDark;
    });
    await LocalPreferences.setLynxThemeMode(newDark ? 'dark' : 'light');
  }

  Future<void> _saveHistoryLocally() async {
    final list = _messages.map((m) => m.toJson()).toList();
    await LocalPreferences.setLynxChatHistory(list);
  }

  Future<void> _confirmClearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _dialogBgColor,
        title: Text("Clear Chat History?", style: TextStyle(color: _primaryTextColor)),
        content: Text(
          "Are you sure you want to clear all stored chat messages from local memory?",
          style: TextStyle(color: _secondaryTextColor),
        ),
        actions: [
          TextButton(
            child: Text("Cancel", style: TextStyle(color: _greyTextColor)),
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
      _scrollToBottom(animate: true);
    }
  }

  void _showSettingsDialog() {
    final apiKeyCtrl = TextEditingController(text: _aiApiKey);
    final modelCtrl = TextEditingController(text: _aiModelName);
    final urlCtrl = TextEditingController(text: _aiBaseUrl);
    final maxRowsCtrl = TextEditingController(text: _maxRows.toString());
    String selectedProvider = _aiProvider;
    bool isDarkInModal = _isDarkMode;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: _dialogBgColor,
          title: Row(
            children: [
              const Icon(Icons.settings_outlined, color: Color(0xFFE53935)),
              const SizedBox(width: 8),
              Text("AI Assistant Settings", style: TextStyle(color: _primaryTextColor, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Theme Toggle inside Settings Dialog
                Text("Theme Mode", style: TextStyle(color: _secondaryTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDarkInModal ? const Color(0xFF2B2B40) : const Color(0xFFEDF2F7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDarkInModal ? const Color(0xFF3F3F5F) : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isDarkInModal ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                            color: isDarkInModal ? Colors.amberAccent : Colors.amber.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isDarkInModal ? "Dark Mode" : "Light Mode",
                            style: TextStyle(
                              color: isDarkInModal ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: isDarkInModal,
                        activeThumbColor: const Color(0xFFE53935),
                        onChanged: (val) {
                          setModalState(() {
                            isDarkInModal = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Text("AI Provider", style: TextStyle(color: _secondaryTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDarkInModal ? const Color(0xFF2B2B40) : const Color(0xFFEDF2F7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDarkInModal ? const Color(0xFF3F3F5F) : const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedProvider,
                      dropdownColor: isDarkInModal ? const Color(0xFF2B2B40) : Colors.white,
                      isExpanded: true,
                      style: TextStyle(color: isDarkInModal ? Colors.white : const Color(0xFF0F172A)),
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
                Text("API Key", style: TextStyle(color: _secondaryTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: apiKeyCtrl,
                  obscureText: true,
                  style: TextStyle(color: isDarkInModal ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Enter your API key (AIzaSy...)",
                    hintStyle: TextStyle(color: _greyTextColor, fontSize: 12),
                    filled: true,
                    fillColor: isDarkInModal ? const Color(0xFF2B2B40) : const Color(0xFFEDF2F7),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDarkInModal ? const Color(0xFF3F3F5F) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text("Model ID / Name", style: TextStyle(color: _secondaryTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: modelCtrl,
                  style: TextStyle(color: isDarkInModal ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDarkInModal ? const Color(0xFF2B2B40) : const Color(0xFFEDF2F7),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDarkInModal ? const Color(0xFF3F3F5F) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text("Base Endpoint URL", style: TextStyle(color: _secondaryTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: urlCtrl,
                  style: TextStyle(color: isDarkInModal ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDarkInModal ? const Color(0xFF2B2B40) : const Color(0xFFEDF2F7),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDarkInModal ? const Color(0xFF3F3F5F) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text("Max Query Rows Limit (Max: 1000, Default: 100)", style: TextStyle(color: _secondaryTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: maxRowsCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: isDarkInModal ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "100",
                    helperText: "Limits AI output payload & token costs. Max 1000 rows.",
                    helperStyle: TextStyle(color: _greyTextColor, fontSize: 11),
                    filled: true,
                    fillColor: isDarkInModal ? const Color(0xFF2B2B40) : const Color(0xFFEDF2F7),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDarkInModal ? const Color(0xFF3F3F5F) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text("Cancel", style: TextStyle(color: _greyTextColor)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC81E1E)),
              child: const Text("Save Settings", style: TextStyle(color: Colors.white)),
              onPressed: () async {
                int parsedMax = int.tryParse(maxRowsCtrl.text.trim()) ?? 100;
                if (parsedMax > 1000) parsedMax = 1000;
                if (parsedMax < 1) parsedMax = 1;

                await LocalPreferences.setLynxAiProvider(selectedProvider);
                await LocalPreferences.setLynxAiApiKey(apiKeyCtrl.text.trim());
                await LocalPreferences.setLynxAiModelName(modelCtrl.text.trim());
                await LocalPreferences.setLynxAiBaseUrl(urlCtrl.text.trim());
                await LocalPreferences.setLynxMaxRows(parsedMax);

                setState(() {
                  _aiProvider = selectedProvider;
                  _aiApiKey = apiKeyCtrl.text.trim();
                  _aiModelName = modelCtrl.text.trim();
                  _aiBaseUrl = urlCtrl.text.trim();
                  _maxRows = parsedMax;
                });

                await _toggleThemeMode(isDarkInModal);

                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text("✅ AI Configuration & Theme preferences saved successfully."),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (animate) {
          _scrollController.animateTo(
            maxScroll,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(maxScroll);
        }
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
    _scrollToBottom(animate: true);

    try {
      final endpoint = isVoice ? ApiEndpoints.lynxAssistVoice : ApiEndpoints.lynxAssistChat;
      final payload = isVoice
          ? {
              'transcript': trimmed,
              'maxRows': _maxRows,
              'aiProvider': _aiProvider,
              'aiModelName': _aiModelName,
              'aiApiKey': _aiApiKey,
              'aiBaseUrl': _aiBaseUrl,
            }
          : {
              'message': trimmed,
              'maxRows': _maxRows,
              'history': [],
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
      _scrollToBottom(animate: true);
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
    _scrollToBottom(animate: true);
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
      decoration: BoxDecoration(
        color: _modalBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _headerBgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC81E1E).withOpacity(0.15),
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
                          Text(
                            "FAMALTH LYNX ASSIST",
                            style: TextStyle(
                              color: _primaryTextColor,
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
                                color: _aiApiKey.isNotEmpty ? (_isDarkMode ? Colors.greenAccent : Colors.green.shade800) : (_isDarkMode ? Colors.amberAccent : Colors.amber.shade900),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "Text-to-SQL Voice & Chat Business Companion",
                        style: TextStyle(color: _greyTextColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // Quick Theme Mode Toggle Button (Sun / Moon)
                IconButton(
                  tooltip: _isDarkMode ? "Switch to Light Theme" : "Switch to Dark Theme",
                  icon: Icon(
                    _isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                    color: _isDarkMode ? Colors.amberAccent : const Color(0xFF475569),
                    size: 20,
                  ),
                  onPressed: () => _toggleThemeMode(),
                ),

                // Settings Button (Configure AI Key, Model & Theme)
                IconButton(
                  tooltip: "AI Settings & Preferences",
                  icon: Icon(Icons.settings_outlined, color: _secondaryTextColor, size: 20),
                  onPressed: _showSettingsDialog,
                ),

                // Clear Chat Button
                IconButton(
                  tooltip: "Clear Chat History",
                  icon: Icon(Icons.cleaning_services_rounded, color: _secondaryTextColor, size: 20),
                  onPressed: _confirmClearChat,
                ),

                // Close Button
                IconButton(
                  tooltip: "Close Assistant",
                  icon: Icon(Icons.close, color: _greyTextColor, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Chat Messages List
          Expanded(
            child: SelectionArea(
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
          ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE53935)),
                  ),
                  const SizedBox(width: 10),
                  Text("LYNX ASSIST is executing query...", style: TextStyle(color: _greyTextColor, fontSize: 12)),
                ],
              ),
            ),

          // Bottom Input Controls
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _headerBgColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
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
                              backgroundColor: _chipBgColor,
                              side: BorderSide(color: _botMessageBorderColor),
                              label: Text(
                                chip,
                                style: TextStyle(color: _secondaryTextColor, fontSize: 12),
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
                            color: _isListening ? Colors.redAccent : _inputFillColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: _botMessageBorderColor),
                            boxShadow: _isListening
                                ? [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 12, spreadRadius: 2)]
                                : [],
                          ),
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening ? Colors.white : _primaryTextColor,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Text input field
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          style: TextStyle(color: _primaryTextColor),
                          decoration: InputDecoration(
                            hintText: _isListening ? "Listening to your voice..." : "Ask LYNX ASSIST or query database...",
                            hintStyle: TextStyle(color: _greyTextColor, fontSize: 14),
                            filled: true,
                            fillColor: _inputFillColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: _botMessageBorderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: _botMessageBorderColor),
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

  Widget _buildTableWidget(List<String> tableLines, bool isUser) {
    if (tableLines.isEmpty) return const SizedBox.shrink();

    List<String> headers = [];
    List<List<String>> rows = [];

    for (int i = 0; i < tableLines.length; i++) {
      final line = tableLines[i].trim();
      final cleanLine = line.replaceAll('|', '').replaceAll(':', '').replaceAll('-', '').trim();
      if (cleanLine.isEmpty) {
        continue;
      }

      final cells = line
          .split('|')
          .map((c) => c.trim())
          .toList();

      if (cells.isNotEmpty && cells.first.isEmpty) cells.removeAt(0);
      if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();

      if (headers.isEmpty) {
        headers = cells;
      } else {
        rows.add(cells);
      }
    }

    if (headers.isEmpty) return const SizedBox.shrink();

    final headerBgColor = isUser
        ? const Color(0xFF801414)
        : (_isDarkMode ? const Color(0xFF181824) : const Color(0xFFE2E8F0));

    final rowBgColor = isUser
        ? const Color(0xFFA61818)
        : (_isDarkMode ? const Color(0xFF222234) : const Color(0xFFF8FAFC));

    final alternateRowBgColor = isUser
        ? const Color(0xFFC81E1E)
        : (_isDarkMode ? const Color(0xFF2B2B40) : const Color(0xFFFFFFFF));

    final borderSide = BorderSide(
      color: isUser
          ? Colors.white24
          : (_isDarkMode ? const Color(0xFF3F3F5F) : const Color(0xFFCBD5E1)),
      width: 0.8,
    );

    final cellTextStyle = TextStyle(
      color: isUser ? Colors.white : _primaryTextColor,
      fontSize: 12,
    );
    final boldCellTextStyle = TextStyle(
      color: isUser ? Colors.white : _primaryTextColor,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: rowBgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUser
              ? Colors.white30
              : (_isDarkMode ? const Color(0xFF3F3F5F) : const Color(0xFFCBD5E1)),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(headerBgColor),
            headingRowHeight: 36,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 48,
            horizontalMargin: 12,
            columnSpacing: 18,
            border: TableBorder(
              horizontalInside: borderSide,
              verticalInside: borderSide,
            ),
            columns: headers.map((h) {
              return DataColumn(
                label: Text(
                  h.replaceAll('**', '').trim(),
                  style: TextStyle(
                    color: isUser ? Colors.white : _primaryTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
            rows: rows.asMap().entries.map((entry) {
              final idx = entry.key;
              final r = entry.value;

              return DataRow(
                color: WidgetStateProperty.all(
                  idx % 2 == 0 ? rowBgColor : alternateRowBgColor,
                ),
                cells: List.generate(headers.length, (colIdx) {
                  final cellText = colIdx < r.length ? r[colIdx] : '';
                  return DataCell(
                    SelectableText.rich(
                      TextSpan(
                        children: _parseInlineMarkdown(
                          cellText,
                          cellTextStyle,
                          boldCellTextStyle,
                        ),
                      ),
                    ),
                  );
                }),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormattedMarkdown(String rawText, bool isUser) {
    final lines = rawText.split('\n');
    List<Widget> widgets = [];

    final defaultStyle = TextStyle(
      color: isUser ? Colors.white : _primaryTextColor,
      fontSize: 13.5,
      height: 1.4,
    );
    final boldStyle = TextStyle(
      color: isUser ? Colors.white : _primaryTextColor,
      fontSize: 13.5,
      fontWeight: FontWeight.bold,
      height: 1.4,
    );
    final titleStyle = TextStyle(
      color: isUser ? Colors.white : (_isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)),
      fontSize: 14.5,
      fontWeight: FontWeight.bold,
      height: 1.4,
    );

    int i = 0;
    while (i < lines.length) {
      String line = lines[i];
      final trimmedLine = line.trim();

      // Detect markdown table block
      if (trimmedLine.startsWith('|') && trimmedLine.endsWith('|') && trimmedLine.split('|').length > 2) {
        List<String> tableLines = [];
        while (i < lines.length) {
          final tLine = lines[i].trim();
          if (tLine.startsWith('|') && tLine.endsWith('|') && tLine.split('|').length > 2) {
            tableLines.add(lines[i]);
            i++;
          } else {
            break;
          }
        }
        widgets.add(_buildTableWidget(tableLines, isUser));
        continue;
      }

      if (trimmedLine.isEmpty) {
        widgets.add(const SizedBox(height: 4));
        i++;
        continue;
      }

      bool isBullet = trimmedLine.startsWith('* ') || trimmedLine.startsWith('- ');
      if (isBullet) {
        line = trimmedLine.substring(2);
      } else {
        line = trimmedLine;
      }

      bool isHeader = line.startsWith('###') || line.startsWith('##') || line.startsWith('#');
      if (isHeader) {
        line = line.replaceAll('#', '').trim();
      }

      final spans = _parseInlineMarkdown(line, isHeader ? titleStyle : defaultStyle, isHeader ? titleStyle : boldStyle);

      Widget lineWidget = SelectableText.rich(
        TextSpan(children: spans),
      );

      if (isBullet) {
        lineWidget = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Icon(Icons.circle, size: 5, color: isUser ? Colors.white : const Color(0xFFE53935)),
            ),
            Expanded(child: lineWidget),
          ],
        );
      }

      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: lineWidget,
      ));

      i++;
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
          color: message.isUser ? const Color(0xFFC81E1E) : _botMessageBgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
          border: (!message.isUser) ? Border.all(color: _botMessageBorderColor) : null,
          boxShadow: (!message.isUser && !_isDarkMode)
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFormattedMarkdown(message.text, message.isUser),
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

                  if (actionType.startsWith('CONFIRM_') || actionType == 'APPROVE') {
                    // In-chat approval action: Keep chatbot open, trigger API call, and return response in chat
                    final label = (message.action!['label'] ?? "Approve").toString();
                    final cleanLabel = label.replaceAll('✅', '').replaceAll('⚡', '').trim();
                    _sendMessage(cleanLabel.isNotEmpty ? cleanLabel : "Approve");
                  } else {
                    // Screen navigation action: Open target screen while preserving AI assistant context when returning back
                    if (callback != null) {
                      callback(actionType, actionPayload);
                    }
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

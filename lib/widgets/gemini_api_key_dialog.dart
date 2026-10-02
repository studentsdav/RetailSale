import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/settings/local_preferences.dart';

/// A theme-adaptive dialog prompting the user to enter their Gemini API Key.
/// Shows step-by-step instructions to get a free API key from Google AI Studio.
class GeminiApiKeyDialog extends StatefulWidget {
  final String? initialKey;
  final bool? isDarkMode;
  final ValueChanged<String>? onKeySaved;

  const GeminiApiKeyDialog({
    super.key,
    this.initialKey,
    this.isDarkMode,
    this.onKeySaved,
  });

  /// Displays the Gemini API Key dialog and returns the saved key (or null if cancelled).
  static Future<String?> show(
    BuildContext context, {
    String? initialKey,
    bool? isDarkMode,
    ValueChanged<String>? onKeySaved,
  }) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => GeminiApiKeyDialog(
        initialKey: initialKey,
        isDarkMode: isDarkMode,
        onKeySaved: onKeySaved,
      ),
    );
  }

  @override
  State<GeminiApiKeyDialog> createState() => _GeminiApiKeyDialogState();
}

class _GeminiApiKeyDialogState extends State<GeminiApiKeyDialog> {
  late final TextEditingController _keyController;
  bool _obscureText = true;
  String? _errorMessage;
  bool _isSaving = false;

  // Primary purple accent matching Lynx AI branding
  static const Color _primaryPurple = Color(0xFF9333EA);
  static const Color _lightPurpleBg = Color(0xFFFAF5FF);
  static const Color _lightPurpleBorder = Color(0xFFE9D5FF);
  static const Color _darkPurpleBg = Color(0xFF2B1B4A);
  static const Color _darkPurpleBorder = Color(0xFF6B21A8);

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.initialKey ?? '');
    if (_keyController.text.isEmpty) {
      _loadExistingKey();
    }
  }

  Future<void> _loadExistingKey() async {
    final key = await LocalPreferences.getLynxAiApiKey();
    if (mounted && key.isNotEmpty) {
      setState(() {
        _keyController.text = key;
      });
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.trim().isNotEmpty) {
        setState(() {
          _keyController.text = data.text!.trim();
          _errorMessage = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pasted API Key from clipboard'),
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _copyUrlToClipboard() async {
    try {
      await Clipboard.setData(const ClipboardData(text: 'https://aistudio.google.com'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied "https://aistudio.google.com" to clipboard!'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _saveAndContinue() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter or paste your Gemini API Key';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await LocalPreferences.setLynxAiApiKey(key);
      widget.onKeySaved?.call(key);

      if (mounted) {
        Navigator.of(context).pop(key);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save key: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);
    final dialogBg = isDark ? const Color(0xFF1E1E2D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF475569);
    final infoBg = isDark ? _darkPurpleBg.withOpacity(0.6) : _lightPurpleBg;
    final infoBorder = isDark ? _darkPurpleBorder.withOpacity(0.5) : _lightPurpleBorder;
    final inputBg = isDark ? const Color(0xFF2A2A3C) : const Color(0xFFF8FAFC);
    final inputBorderColor = isDark ? const Color(0xFF3F3F5F) : const Color(0xFFCBD5E1);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: dialogBg,
      elevation: 10,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Title with Purple Key Icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryPurple.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.vpn_key_rounded,
                      color: _primaryPurple,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Gemini API Key Required',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFC084FC) : _primaryPurple,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Step-by-Step Instructions Container
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: infoBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: infoBorder, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('💡', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 8),
                        Text(
                          'How to get a free Gemini API Key:',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildStepRow(
                      number: '1.',
                      text: 'Go to Google AI Studio (aistudio.google.com)',
                      textColor: subtitleColor,
                      onTapUrl: _copyUrlToClipboard,
                    ),
                    const SizedBox(height: 6),
                    _buildStepRow(
                      number: '2.',
                      text: 'Log in with your Gmail account',
                      textColor: subtitleColor,
                    ),
                    const SizedBox(height: 6),
                    _buildStepRow(
                      number: '3.',
                      text: 'Click "Get API Key" -> Create API Key',
                      textColor: subtitleColor,
                    ),
                    const SizedBox(height: 6),
                    _buildStepRow(
                      number: '4.',
                      text: 'Copy and paste your key below.',
                      textColor: subtitleColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // API Key Input Field
              TextField(
                controller: _keyController,
                obscureText: _obscureText,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  color: textColor,
                ),
                decoration: InputDecoration(
                  labelText: 'Gemini API Key',
                  hintText: 'AIzaSy...',
                  hintStyle: TextStyle(color: subtitleColor.withOpacity(0.5)),
                  labelStyle: TextStyle(color: subtitleColor),
                  filled: true,
                  fillColor: inputBg,
                  prefixIcon: const Icon(
                    Icons.vpn_key_outlined,
                    color: _primaryPurple,
                    size: 20,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 19,
                          color: subtitleColor,
                        ),
                        tooltip: _obscureText ? 'Show Key' : 'Hide Key',
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.content_paste_rounded,
                          size: 19,
                          color: _primaryPurple,
                        ),
                        tooltip: 'Paste from clipboard',
                        onPressed: _pasteFromClipboard,
                      ),
                    ],
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: inputBorderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: inputBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primaryPurple, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                  ),
                ),
                onChanged: (val) {
                  if (_errorMessage != null) {
                    setState(() {
                      _errorMessage = null;
                    });
                  }
                },
                onSubmitted: (_) => _saveAndContinue(),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 22),

              // Action Buttons: Cancel and Save & Continue
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(null),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      foregroundColor: subtitleColor,
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveAndContinue,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 18, color: Colors.white),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save & Continue',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryPurple,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required String number,
    required String text,
    required Color textColor,
    VoidCallback? onTapUrl,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          child: Text(
            number,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
        Expanded(
          child: onTapUrl != null
              ? InkWell(
                  onTap: onTapUrl,
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.copy_rounded,
                        size: 13,
                        color: _primaryPurple,
                      ),
                    ],
                  ),
                )
              : Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor,
                    height: 1.35,
                  ),
                ),
        ),
      ],
    );
  }
}

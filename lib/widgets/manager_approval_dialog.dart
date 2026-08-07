import 'package:flutter/material.dart';
import '../core/api/api_client.dart';

class ManagerApprovalDialog extends StatefulWidget {
  const ManagerApprovalDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ManagerApprovalDialog(),
    );
    return result ?? false;
  }

  @override
  State<ManagerApprovalDialog> createState() => _ManagerApprovalDialogState();
}

class _ManagerApprovalDialogState extends State<ManagerApprovalDialog> {
  String _pin = '';
  bool _verifying = false;
  String _errorMessage = '';

  void _onKeyPress(String val) {
    if (_pin.length < 4) {
      setState(() {
        _pin += val;
        _errorMessage = '';
      });
      if (_pin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = '';
      });
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _verifying = true);
    try {
      // Direct call to manager PIN verification route
      final res = await ApiClient.post('/api/users/verify-pin', {'pin': _pin});
      if (res['success'] == true) {
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() {
          _pin = '';
          _errorMessage = res['message'] ?? 'Invalid Manager PIN code';
        });
      }
    } catch (e) {
      setState(() {
        _pin = '';
        _errorMessage = 'Connection error. Please try again.';
      });
    } finally {
      setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, color: colorScheme.primary, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Manager Override Required',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              'Input security PIN to approve restricted action',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 20),
            // Pin indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final active = index < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? colorScheme.primary : Colors.grey.shade300,
                  ),
                );
              }),
            ),
            const SizedBox(height: 15),
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 20),
            // Number Pad
            if (_verifying)
              const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  if (index == 9) {
                    // Cancel button
                    return TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                    );
                  }
                  if (index == 11) {
                    // Backspace
                    return IconButton(
                      icon: const Icon(Icons.backspace_outlined),
                      onPressed: _onBackspace,
                    );
                  }
                  final number = index == 10 ? '0' : '${index + 1}';
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _onKeyPress(number),
                    child: Text(number, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:inventory/screens/recovery/full_recovery_screen.dart';
import 'package:provider/provider.dart';

import '../../controllers/security/recovery_controller.dart';

class AutoReinstallScreen extends StatefulWidget {
  const AutoReinstallScreen({super.key});

  @override
  State<AutoReinstallScreen> createState() => _AutoReinstallScreenState();
}

class _AutoReinstallScreenState extends State<AutoReinstallScreen> {
  String statusText = "Initializing recovery protocols...";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerReinstall();
    });
  }

  Future<void> _triggerReinstall() async {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const FullRecoveryScreen(
                  message: "Partial Recovery",
                )));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RecoveryController>();

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.system_update_alt_rounded,
                    size: 80, color: Colors.blueAccent),
                const SizedBox(height: 32),
                const Text(
                  "System Recovery in Progress",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                if (controller.errorMessage != null)
                  Text(
                    controller.errorMessage!,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 16),
                  )
                else
                  Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),

                const SizedBox(height: 40),

                // Enterprise Linear Progress Bar
                if (controller.isLoading)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: const LinearProgressIndicator(
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      color: Colors.blueAccent,
                    ),
                  )
                else if (controller.errorMessage != null)
                  ElevatedButton.icon(
                    onPressed: _triggerReinstall,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retry Recovery"),
                  ),

                const SizedBox(height: 40),
                const Text(
                  "Please do not turn off the terminal.",
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

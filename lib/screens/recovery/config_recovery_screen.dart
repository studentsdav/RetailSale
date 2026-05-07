import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/security/recovery_controller.dart';
import '../../core/config/app_config.dart';
import '../splash_screen.dart';

class ConfigRecoveryScreen extends StatefulWidget {
  final String message;
  const ConfigRecoveryScreen({super.key, required this.message});

  @override
  State<ConfigRecoveryScreen> createState() => _ConfigRecoveryScreenState();
}

class _ConfigRecoveryScreenState extends State<ConfigRecoveryScreen> {
  final TextEditingController _outletController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // Enterprise form validation

  @override
  void dispose() {
    _outletController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleAction() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final controller = context.read<RecoveryController>();

    if (!controller.otpSent) {
      // Step A: Request OTP
      final success =
          await controller.requestOtp(_outletController.text.trim());
      if (success && mounted) {
        _otpController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("OTP Sent to Admin Email"),
              backgroundColor: Colors.green),
        );
      }
    } else {
      // Step B: Verify OTP
      final success = await controller.verifyOtp(_otpController.text.trim());

      if (success && mounted) {
        addOutletToConfig(_outletController.text);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("System Recovered! Restarting..."),
              backgroundColor: Colors.green),
        );

        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const SplashScreen()));
      }
    }
  }

  Future<void> addOutletToConfig(String newOutletCode) async {
    if (!AppConfig.outlets.contains(newOutletCode)) {
      List<String> updatedOutlets = List.from(AppConfig.outlets)
        ..add(newOutletCode);
      await AppConfig.saveConfig(AppConfig.baseUrl, updatedOutlets);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RecoveryController>(); // Listen to state

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Card(
            elevation: 8,
            shadowColor: Colors.black26,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 64, color: Colors.orange),
                    const SizedBox(height: 24),
                    Text(
                      "Security Verification",
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      controller.otpSent
                          ? "Enter the 6-digit OTP sent to the registered email."
                          : widget.message,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.black54, height: 1.5),
                    ),
                    const SizedBox(height: 32),

                    if (controller.errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          controller.errorMessage!,
                          style: TextStyle(color: Colors.red.shade900),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Input Field
                    TextFormField(
                      controller: controller.otpSent
                          ? _otpController
                          : _outletController,
                      keyboardType: controller.otpSent
                          ? TextInputType.number
                          : TextInputType.text,
                      decoration: InputDecoration(
                        labelText: controller.otpSent
                            ? 'Enter 6-Digit OTP'
                            : 'Outlet Code',
                        prefixIcon: Icon(
                            controller.otpSent ? Icons.password : Icons.store),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return controller.otpSent
                              ? 'Please enter the OTP'
                              : 'Please enter the Outlet Code';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Action Button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: controller.isLoading ? null : _handleAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: controller.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(
                                controller.otpSent
                                    ? "Verify & Recover"
                                    : "Send Recovery Code",
                                style: const TextStyle(fontSize: 16)),
                      ),
                    ),

                    // Secondary Action
                    if (controller.otpSent && !controller.isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: TextButton(
                          onPressed: () {
                            controller.resetState();
                            _otpController.clear();
                          },
                          child: const Text("Use a different Outlet Code"),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/token_storage.dart';
import '../../core/config/app_config.dart';
import '../../core/navigation/home_route_helper.dart';
import '../dashboard/server_config_screen.dart';

class SupplierOtpLoginScreen extends StatefulWidget {
  const SupplierOtpLoginScreen({super.key});

  @override
  State<SupplierOtpLoginScreen> createState() => _SupplierOtpLoginScreenState();
}

class _SupplierOtpLoginScreenState extends State<SupplierOtpLoginScreen> {
  final _outletCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  final _requestFormKey = GlobalKey<FormState>();
  final _verifyFormKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _otpSent = false;
  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (AppConfig.outlets.isNotEmpty) {
      _outletCtrl.text = AppConfig.outlets.first;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _outletCtrl.dispose();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _countdown = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        timer.cancel();
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  Future<void> _requestOtp() async {
    if (!_requestFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final body = {
        'outlet_code': _outletCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      };

      final res = await ApiClient.post('/api/auth/supplier/request-otp', body);
      if (res['success'] == true) {
        setState(() {
          _otpSent = true;
        });
        _startTimer();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'OTP sent successfully.'),
            backgroundColor: Colors.indigo.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('OTP Request error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (!_verifyFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final body = {
        'outlet_code': _outletCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'otp': _otpCtrl.text.trim(),
      };

      final res = await ApiClient.post('/api/auth/supplier/verify-otp', body);
      if (res['success'] == true) {
        final token = res['token'];
        final user = res['user'];

        // Save token & user session details
        await TokenStorage.save(token);
        await TokenStorage.saveRole(user['role']);
        await TokenStorage.savePermissions(List<String>.from(user['permissions']));
        await TokenStorage.saveUser(user);

        // Update local app config to match the logged-in outlet
        if (!AppConfig.outlets.contains(user['outlet_code'])) {
          AppConfig.outlets.add(user['outlet_code']);
          await AppConfig.saveConfig(AppConfig.baseUrl, AppConfig.outlets);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login successful! Welcome back, ${user['name']}.'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Resolve home dashboard and navigate
        final nextWidget = await HomeRouteHelper.resolve();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => nextWidget),
        );
      }
    } catch (e) {
      debugPrint('OTP verification error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = Colors.indigo.shade700; // Supplier App Indigo theme

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: Colors.grey.shade700),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ServerConfigScreen()),
              );
            },
            tooltip: "Server Config",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warehouse,
                          size: 48,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "FreshConsole Supplier",
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Passwordless manager secure authentication",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                Card(
                  elevation: 4,
                  shadowColor: Colors.black.withOpacity(0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: AnimatedCrossFade(
                      duration: const Duration(milliseconds: 300),
                      crossFadeState: _otpSent ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      firstChild: _buildRequestForm(theme, primaryColor),
                      secondChild: _buildVerifyForm(theme, primaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestForm(ThemeData theme, Color accentColor) {
    return Form(
      key: _requestFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Request Access OTP",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Enter your business Outlet ID and registered email to receive a secure login key.",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _outletCtrl,
            decoration: InputDecoration(
              labelText: "Outlet Code / ID",
              prefixIcon: const Icon(Icons.storefront_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? "Enter your outlet code" : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: "Registered Email",
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return "Enter your registered email";
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return "Enter a valid email address";
              return null;
            },
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _isLoading ? null : _requestOtp,
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Send OTP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyForm(ThemeData theme, Color accentColor) {
    return Form(
      key: _verifyFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _otpSent = false),
              ),
              const SizedBox(width: 8),
              const Text(
                "Verify OTP",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "We have sent a 6-digit OTP code to ${_emailCtrl.text}. Enter the code below to log in.",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
            decoration: InputDecoration(
              counterText: "",
              labelText: "Verification OTP Code",
              prefixIcon: const Icon(Icons.security_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) => value == null || value.trim().length != 6 ? "Enter 6-digit OTP" : null,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _countdown > 0 ? "Resend code in ${_countdown}s" : "Didn't receive code?",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              if (_countdown == 0)
                TextButton(
                  onPressed: _requestOtp,
                  child: const Text("Resend OTP", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isLoading ? null : _verifyOtp,
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Verify & Login", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

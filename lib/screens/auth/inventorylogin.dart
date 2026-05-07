import 'package:flutter/material.dart';
import 'dart:io';
import 'package:inventory/core/auth/auth_service.dart';
import 'package:inventory/core/config/app_brand.dart';
import 'package:inventory/core/config/app_config.dart';
import 'package:inventory/core/navigation/home_route_helper.dart';
import 'package:inventory/screens/settings/outlet_setup_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../controllers/security/password_recovery_controller.dart';
import '../../utils/branding_storage.dart';

class InventoryLoginScreen extends StatefulWidget {
  const InventoryLoginScreen({super.key});

  @override
  State<InventoryLoginScreen> createState() => _InventoryLoginScreenState();
}

class _InventoryLoginScreenState extends State<InventoryLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  String _role = 'STORE';
  String? _selectedOutlet;
  bool _obscure = true;
  String? _logoPath;

  late final AnimationController _logoCtrl;
  late final Animation<double> _logoAnim;

  final List<String> _roles = [
    'ADMIN',
    'STORE',
    'ACCOUNTS',
  ];

  bool _isloading = false;
  String currentVersion = "";

  @override
  void initState() {
    super.initState();
    getVersion();

    if (AppConfig.outlets.isNotEmpty) {
      _selectedOutlet = AppConfig.outlets.first;
    }
    _loadOutletLogo();

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _logoAnim = CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut);
    _logoCtrl.forward();
  }

  void getVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    currentVersion = packageInfo.version;
    setState(() {});
  }

  Future<void> _loadOutletLogo() async {
    final outletCode = _selectedOutlet;
    if (outletCode == null) return;
    final path = await BrandingStorage.getLogoPathForOutlet(outletCode);
    if (!mounted) return;
    setState(() => _logoPath = path);
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOutlet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select an outlet'),
            backgroundColor: Colors.red),
      );
      return;
    }

    try {
      setState(() {
        _isloading = true;
      });

      final result = await AuthService.login(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text.trim(),
        _role,
        _selectedOutlet!,
      );

      if (!mounted) return;

      if (result.success) {
        if (result.licenseStatus == 'WARNING') {
          await _showExpiryWarningDialog(result.daysRemaining);
        }

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FutureBuilder<Widget>(
              future: HomeRouteHelper.resolve(),
              builder: (context, snapshot) =>
                  snapshot.data ??
                  const Scaffold(
                      body: Center(child: CircularProgressIndicator())),
            ),
          ),
        );
      } else if (result.licenseStatus == 'EXPIRED') {
        _showExpiredDialog(result.message);
      }
    } catch (e) {
      if (e.toString().toLowerCase().contains("expired")) {
        _showExpiredDialog(e.toString());
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        _isloading = false;
        setState(() {});
      }
    }
  }

  Future<void> _showExpiryWarningDialog(int daysRemaining) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 48),
          title: const Text('License Expiring Soon'),
          content: Text(
            'Your software license will expire in $daysRemaining days.\n\n'
            'Please renew your subscription to avoid any business interruption.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue to Dashboard'),
            ),
          ],
        );
      },
    );
  }

  void _showExpiredDialog(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(Icons.lock_clock, color: Colors.red, size: 48),
          title: const Text('License Expired'),
          content: Text(
            message,
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return _isloading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(
                      height: 5,
                    ),
                    Text("Verifying....")
                  ],
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Card(
                    elevation: 14,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    child: isDesktop ? _desktopLayout() : _mobileLayout(),
                  ),
                ),
              );
      }),
    );
  }

  Widget _desktopLayout() {
    return SizedBox(
      height: 580,
      child: Row(
        children: [
          Container(
            width: 420,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScaleTransition(
                  scale: _logoAnim,
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: Colors.white24,
                    backgroundImage:
                        _logoPath != null && File(_logoPath!).existsSync()
                            ? FileImage(File(_logoPath!))
                            : null,
                    child: _logoPath == null || !File(_logoPath!).existsSync()
                        ? const Icon(Icons.inventory_2,
                            size: 42, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppBrand.productName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Retail, inventory, accounting, and reporting in one secure flow.',
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.4,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    _HeroPill(label: 'Enterprise Ready'),
                    _HeroPill(label: 'Fast Billing'),
                    _HeroPill(label: 'Live Stock'),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Powered by @Famalth',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Since 2024',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: _loginForm(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          ScaleTransition(
            scale: _logoAnim,
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage:
                  _logoPath != null && File(_logoPath!).existsSync()
                      ? FileImage(File(_logoPath!))
                      : null,
              child: _logoPath == null || !File(_logoPath!).existsSync()
                  ? Icon(Icons.inventory_2,
                      size: 36,
                      color: Theme.of(context).colorScheme.onPrimaryContainer)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(AppBrand.productName,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Retail, inventory, accounting, and reporting in one secure flow.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), height: 1.35),
          ),
          const SizedBox(height: 16),
          _loginForm(),
        ],
      ),
    );
  }

  Widget _loginForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedOutlet,
                  decoration: const InputDecoration(
                    labelText: 'Outlet Code',
                    prefixIcon: Icon(Icons.storefront),
                  ),
                  items: AppConfig.outlets
                      .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _selectedOutlet = v);
                    _loadOutletLogo();
                  },
                  validator: (v) => v == null ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const OutletSetupScreen()),
                  ).then((_) {
                    setState(() {
                      if (AppConfig.outlets.isNotEmpty) {
                        _selectedOutlet = AppConfig.outlets.first;
                      }
                    });
                    _loadOutletLogo();
                  });
                },
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Add new Outlet',
              )
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _usernameCtrl,
            focusNode: _usernameFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _login(),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) =>
                v == null || v.length < 4 ? 'Invalid password' : null,
          ),

          // ==========================================

          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(
              labelText: 'Role',
              prefixIcon: Icon(Icons.badge),
            ),
            items: _roles
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) => setState(() => _role = v ?? _role),
          ),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  if (_selectedOutlet == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please select an Outlet Code first.')),
                    );
                    return;
                  }
                  _showForgotUsernameDialog(context); // NEW DIALOG
                },
                style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                child: const Text('Forgot Username?',
                    style: TextStyle(fontSize: 12)),
              ),
              const Text('|', style: TextStyle(color: Colors.grey)),
              TextButton(
                onPressed: () {
                  if (_selectedOutlet == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please select an Outlet Code first.')),
                    );
                    return;
                  }
                  _showForgotPasswordDialog(context); // EXISTING DIALOG
                },
                style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                child: const Text('Forgot Password?',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.login),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('LOGIN'),
              ),
              onPressed: _login,
            ),
          ),
          const SizedBox(height: 14),
          const Spacer(),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Powered by @Famalth • Since 2024',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppBrand.productName} v$currentVersion',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // FORGOT USERNAME
  // =====================================================================
  Future<void> _showForgotUsernameDialog(BuildContext context) async {
    final passRecoveryCtrl = PasswordRecoveryController();
    bool isProcessing = false;
    final emailCtrl = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submitRecovery() async {
              if (!dialogFormKey.currentState!.validate()) return;
              setDialogState(() => isProcessing = true);

              try {
                final msg = await passRecoveryCtrl.recoverUsername(
                  outletCode: _selectedOutlet!,
                  email: emailCtrl.text.trim(),
                );

                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(msg), backgroundColor: Colors.green));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString()), backgroundColor: Colors.red));
              } finally {
                setDialogState(() => isProcessing = false);
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.person_search,
                      color: Theme.of(context).primaryColor),
                  const SizedBox(width: 12),
                  const Text('Recover Username'),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: dialogFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text(
                            "Enter the registered email for this outlet. We will email you a list of all active usernames.",
                            style: TextStyle(
                                color: Colors.deepOrange, fontSize: 13)),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => submitRecovery(),
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                        decoration: const InputDecoration(
                            labelText: 'Registered Email *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email_outlined)),
                        validator: (v) =>
                            v == null || v.isEmpty || !v.contains('@')
                                ? 'Enter a valid email'
                                : null,
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              actions: [
                TextButton(
                  onPressed:
                      isProcessing ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isProcessing ? null : submitRecovery,
                  child: isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Send Recovery Email'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =====================================================================
  // FORGOT PASSWORD DIALOG
  // =====================================================================
  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    final passRecoveryCtrl = PasswordRecoveryController();
    int currentStep = 1;
    bool isProcessing = false;
    String backendMessage = "";
    bool obscureNew = true;
    bool obscureConfirm = true;

    final resetUserCtrl =
        TextEditingController(text: _usernameCtrl.text.trim());
    final otpCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> requestOtp({bool isResend = false}) async {
              if (resetUserCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Username required"),
                    backgroundColor: Colors.red));
                return;
              }
              setDialogState(() => isProcessing = true);

              try {
                final msg = await passRecoveryCtrl.requestOtp(
                  outletCode: _selectedOutlet!,
                  username: resetUserCtrl.text.trim(),
                );

                backendMessage = msg;
                setDialogState(() => currentStep = 2);

                if (isResend && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('OTP Resent!'),
                      backgroundColor: Colors.blue));
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString()), backgroundColor: Colors.red));
              } finally {
                setDialogState(() => isProcessing = false);
              }
            }

            Future<void> submitReset() async {
              if (!dialogFormKey.currentState!.validate()) return;

              if (newPassCtrl.text != confirmPassCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Passwords do not match!'),
                    backgroundColor: Colors.red));
                return;
              }

              setDialogState(() => isProcessing = true);

              try {
                final msg = await passRecoveryCtrl.resetPassword(
                  outletCode: _selectedOutlet!,
                  username: resetUserCtrl.text.trim(),
                  otp: otpCtrl.text.trim(),
                  newPassword: newPassCtrl.text,
                );

                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(msg), backgroundColor: Colors.green));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString()), backgroundColor: Colors.red));
              } finally {
                setDialogState(() => isProcessing = false);
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.lock_reset, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 12),
                  const Text('Password Recovery'),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: dialogFormKey,
                  child: currentStep == 1
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Text(
                                  "Enter your username. We will send a secure OTP to the system administrator's registered email.",
                                  style: TextStyle(
                                      color: Colors.blue, fontSize: 13)),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              initialValue: _selectedOutlet,
                              readOnly: true,
                              decoration: const InputDecoration(
                                  labelText: 'Outlet Code',
                                  filled: true,
                                  fillColor: Color(0xFFF1F5F9),
                                  border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: resetUserCtrl,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => requestOtp(),
                              onTapOutside: (_) =>
                                  FocusScope.of(context).unfocus(),
                              decoration: const InputDecoration(
                                  labelText: 'Username *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person_outline)),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.green.shade200)),
                              child: Row(
                                children: [
                                  const Icon(Icons.mark_email_read,
                                      color: Colors.green),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Text(backendMessage,
                                          style: const TextStyle(
                                              color: Colors.green,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: otpCtrl,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) =>
                                  FocusScope.of(context).nextFocus(),
                              onTapOutside: (_) =>
                                  FocusScope.of(context).unfocus(),
                              decoration: const InputDecoration(
                                  labelText: '6-Digit OTP *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.password)),
                              validator: (v) => v == null || v.length < 4
                                  ? 'Enter valid OTP'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: newPassCtrl,
                              obscureText: obscureNew,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) =>
                                  FocusScope.of(context).nextFocus(),
                              onTapOutside: (_) =>
                                  FocusScope.of(context).unfocus(),
                              decoration: InputDecoration(
                                labelText: 'New Password *',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(obscureNew
                                      ? Icons.visibility
                                      : Icons.visibility_off),
                                  onPressed: () => setDialogState(
                                      () => obscureNew = !obscureNew),
                                ),
                              ),
                              validator: (v) => v == null || v.length < 8
                                  ? 'Min 8 characters'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: confirmPassCtrl,
                              obscureText: obscureConfirm,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => submitReset(),
                              onTapOutside: (_) =>
                                  FocusScope.of(context).unfocus(),
                              decoration: InputDecoration(
                                labelText: 'Confirm Password *',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(obscureConfirm
                                      ? Icons.visibility
                                      : Icons.visibility_off),
                                  onPressed: () => setDialogState(
                                      () => obscureConfirm = !obscureConfirm),
                                ),
                              ),
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ],
                        ),
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              actions: [
                currentStep == 1
                    ? TextButton(
                        onPressed: isProcessing
                            ? null
                            : () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      )
                    : TextButton.icon(
                        onPressed: isProcessing
                            ? null
                            : () => setDialogState(() {
                                  currentStep = 1;
                                  otpCtrl.clear();
                                  newPassCtrl.clear();
                                  confirmPassCtrl.clear();
                                  backendMessage = "";
                                }),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit Username'),
                      ),
                currentStep == 1
                    ? FilledButton(
                        onPressed: isProcessing ? null : requestOtp,
                        child: isProcessing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Send Recovery Email'),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            onPressed: isProcessing
                                ? null
                                : () => requestOtp(isResend: true),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Resend OTP'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: isProcessing ? null : submitReset,
                            child: isProcessing
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text('Verify & Reset'),
                          ),
                        ],
                      ),
              ],
            );
          },
        );
      },
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;

  const _HeroPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

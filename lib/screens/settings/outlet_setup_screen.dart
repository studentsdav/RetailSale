import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:retailpos/screens/auth/login_screen.dart';

import '../../controllers/public/outlet_controller.dart';
import '../../controllers/public/recovery_controller.dart';
import '../../controllers/settings/theme_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_download_helper.dart';
import '../recovery/backup_service.dart';

enum SetupMode { newClient, existingClient, recoverId, restoreLocal }

enum FlowStep { initial, otpVerification }

class OutletSetupScreen extends StatefulWidget {
  const OutletSetupScreen({super.key});

  @override
  State<OutletSetupScreen> createState() => _OutletSetupScreenState();
}

class _OutletSetupScreenState extends State<OutletSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Base Fields
  final _outletCode = TextEditingController();
  final _outletName = TextEditingController();
  String _outletType = 'HOTEL';
  String _businessModule = 'ALL';

  // Enterprise Recovery Fields
  final _contactEmail = TextEditingController();
  final _contactPhone = TextEditingController();
  final _recoveryPin = TextEditingController();
  final _taxId = TextEditingController();
  bool _isEmailVerified = false;
  bool _isOtpSentForSetup = false;
  final _setupOtpCode = TextEditingController();

  // OTP Verification Field
  final _otpCode = TextEditingController();

  // State Management
  SetupMode _mode = SetupMode.newClient;
  FlowStep _step = FlowStep.initial;

  bool _isLoading = false;
  bool _isRestoringLocalEnc = false;
  bool _obscurePin = true;
  bool _forgotPinMode = false;
  String? _restoreEncName;
  List<int>? _restoreEncBytes;

  final outletCtrl = OutletController();
  final recoveryCtrl = RecoveryController();
  bool get _isLocalSetupServer => AppConfig.isLocalServer;

  @override
  void initState() {
    super.initState();
    _generateAndSetNewCode();
  }

  @override
  void dispose() {
    _outletCode.dispose();
    _outletName.dispose();
    _contactEmail.dispose();
    _contactPhone.dispose();
    _recoveryPin.dispose();
    _taxId.dispose();
    _otpCode.dispose();
    _setupOtpCode.dispose();
    super.dispose();
  }

  // ================= STATE SWITCHERS =================

  void _generateAndSetNewCode() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    _outletCode.text =
        "OUTLET${now.year}${two(now.month)}${two(now.day)}${two(now.hour)}${two(now.minute)}";
  }

  void _switchMode(SetupMode newMode) {
    setState(() {
      _mode = newMode;
      _step = FlowStep.initial;
      _forgotPinMode = false;

      _formKey.currentState?.reset();
      _outletName.clear();
      _contactEmail.clear();
      _contactPhone.clear();
      _recoveryPin.clear();
      _taxId.clear();
      _otpCode.clear();
      _setupOtpCode.clear();
      _isEmailVerified = false;
      _isOtpSentForSetup = false;
      _restoreEncName = null;
      _restoreEncBytes = null;

      if (newMode == SetupMode.newClient) {
        _generateAndSetNewCode();
      } else {
        _outletCode.clear();
      }
    });
  }

  // ================= API ACTIONS =================

  Future<void> _saveNew() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isEmailVerified) {
      _showError("Please verify your contact email address before proceeding.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await outletCtrl.createOutlet({
        'outlet_code': _outletCode.text.trim(),
        'outlet_name': _outletName.text.trim(),
        'outlet_type': _outletType,
        'business_module': _businessModule,
        'contact_email': _contactEmail.text.trim(),
        'contact_phone': _contactPhone.text.trim(),
        'recovery_pin': _recoveryPin.text.trim(),
        'tax_id': _taxId.text.trim(),
      });

      Map<String, dynamic>? dataMap;
      if (res['data'] is Map<String, dynamic>) {
        dataMap = res['data'] as Map<String, dynamic>;
      } else if (res['data'] is Map) {
        dataMap = Map<String, dynamic>.from(res['data']);
      }

      Map<String, dynamic>? adminCreds;
      if (dataMap?['admin_credentials'] is Map) {
        adminCreds = Map<String, dynamic>.from(dataMap!['admin_credentials']);
      } else if (res['admin_credentials'] is Map) {
        adminCreds = Map<String, dynamic>.from(res['admin_credentials']);
      }

      final adminUsername = adminCreds?['username']?.toString() ??
          res['admin_username']?.toString() ??
          dataMap?['admin_username']?.toString() ??
          'admin_${_outletCode.text.trim()}';

      final adminPassword = adminCreds?['password']?.toString() ??
          res['admin_password']?.toString() ??
          dataMap?['admin_password']?.toString() ??
          '';

      final code = _outletCode.text.trim();
      final currentOutlets = List<String>.from(AppConfig.outlets);
      if (!currentOutlets.contains(code)) {
        currentOutlets.add(code);
        await AppConfig.saveConfig(AppConfig.baseUrl, currentOutlets);
      }

      if (!mounted) return;

      await _showCredentialsDialog(
        code,
        adminUsername,
        adminPassword,
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyExistingPin() async {
    if (_outletCode.text.trim().isEmpty || _recoveryPin.text.trim().isEmpty) {
      _showError("Please enter both Business ID and Recovery PIN.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final verifyRes = await recoveryCtrl.verifyPin(
        _outletCode.text.trim(),
        _recoveryPin.text.trim(),
      );

      if (verifyRes['success'] == true) {
        await _submitExistingClient();
      } else {
        throw verifyRes['message'] ?? "PIN verification failed.";
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitExistingClient() async {
    final code = _outletCode.text.trim();

    try {
      final currentOutlets = List<String>.from(AppConfig.outlets);
      if (!currentOutlets.contains(code)) {
        currentOutlets.add(code);
        await AppConfig.saveConfig(AppConfig.baseUrl, currentOutlets);
      }

      if (!mounted) return;
      _showLinkCompleteDialog();
    } catch (e) {
      _showError("Device link failed: ${e.toString()}");
    }
  }

  Future<void> _requestOtpForExisting({bool isResend = false}) async {
    if (_outletCode.text.trim().isEmpty) {
      _showError("Please enter a Business ID first.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await recoveryCtrl.requestOtp(
        outletCode: _outletCode.text.trim(),
      );

      if (!mounted) return;

      setState(() => _step = FlowStep.otpVerification);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isResend
                ? "OTP Resent Successfully!"
                : (response['message'] ?? "OTP sent to registered contact!"),
          ),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtpAndLink() async {
    if (_otpCode.text.trim().isEmpty) {
      _showError("Please enter the 6-digit OTP code.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await recoveryCtrl.verifyOtp(
        outletCode: _outletCode.text.trim(),
        otp: _otpCode.text.trim(),
      );

      if (response['success'] == true) {
        await _submitExistingClient();
      } else {
        throw response['message'] ?? "OTP verification failed.";
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _findOutletAndSendOtp({bool isResend = false}) async {
    final contactStr = _contactEmail.text.trim();
    if (contactStr.isEmpty) {
      _showError("Please enter your registered Email or Phone.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await recoveryCtrl.requestOtp(contactStr: contactStr);

      if (!mounted) return;

      setState(() => _step = FlowStep.otpVerification);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isResend
                ? "OTP Resent Successfully!"
                : (response['message'] ?? "OTP sent to your registered contact!"),
          ),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyRecoveryOtp() async {
    if (_otpCode.text.trim().isEmpty) {
      _showError("Please enter the 6-digit OTP code.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await recoveryCtrl.verifyOtp(
        contactStr: _contactEmail.text.trim(),
        otp: _otpCode.text.trim(),
      );

      List<dynamic> recoveredOutlets =
          response['data']['outlets'] ?? [response['data']];

      if (!mounted) return;

      _showRecoveredOutletsDialog(recoveredOutlets);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message.replaceAll('Exception:', '').trim())),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _sendSetupOtp(Color primaryColor) async {
    final email = _contactEmail.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError("Please enter a valid email address first.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final msg = await outletCtrl.sendSetupOtp(email);

      if (!mounted) return;
      setState(() => _isOtpSentForSetup = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.mark_email_read_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifySetupOtp() async {
    if (_setupOtpCode.text.trim().isEmpty) {
      _showError("Please enter the OTP code received on your email.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await outletCtrl.verifySetupOtp(
        _contactEmail.text.trim(),
        _setupOtpCode.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _isEmailVerified = true;
        _isOtpSentForSetup = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.verified, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Email verified successfully!'),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetEmailVerification() {
    setState(() {
      _isEmailVerified = false;
      _isOtpSentForSetup = false;
      _setupOtpCode.clear();
    });
  }

  Future<void> _pickRestoreEncFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['enc'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final name = file.name.trim();
    if (!name.toLowerCase().endsWith('.enc')) {
      _showError('Only .enc backup file is allowed.');
      return;
    }
    final bytes = file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null || bytes.isEmpty) {
      _showError('Selected backup file is empty or unreadable.');
      return;
    }
    setState(() {
      _restoreEncName = name;
      _restoreEncBytes = bytes;
    });
  }

  Future<void> _restoreFromLocalEnc() async {
    if (_restoreEncName == null ||
        _restoreEncName!.isEmpty ||
        _restoreEncBytes == null ||
        _restoreEncBytes!.isEmpty) {
      _showError('Please select a valid .enc backup file first.');
      return;
    }

    setState(() => _isRestoringLocalEnc = true);
    try {
      await BackupService.restoreFromLocalEnc(
        fileName: _restoreEncName!,
        bytes: _restoreEncBytes!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Database and configurations restored successfully!'),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isRestoringLocalEnc = false);
    }
  }

  // ================= MAIN DESKTOP / MOBILE BUILD =================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final themeCtrl = context.watch<ThemeController?>();
    final themeKey = themeCtrl?.themeKey ?? AppTheme.famalthClassic;
    final heroColors = AppTheme.getHeroGradientColors(themeKey);

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 960;
    final isWideDesktop = size.width >= 1200;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF8FAFC),
                Color(0xFFEFF6FF),
                Color(0xFFF1F5F9),
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 16,
                vertical: isDesktop ? 36 : 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWideDesktop ? 1220 : (isDesktop ? 1060 : 640),
                ),
                child: isDesktop
                    ? _buildDesktopLayout(scheme, heroColors)
                    : _buildMobileLayout(scheme, heroColors),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- DESKTOP SPLIT VIEW ----------------
  Widget _buildDesktopLayout(ColorScheme scheme, List<Color> heroColors) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 36,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: scheme.secondary.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Hero & Mode Showcase (Matched with Sales Screen Theme)
          Expanded(
            flex: 42,
            child: _buildLeftHeroPanel(scheme, heroColors),
          ),
          // Divider line
          Container(
            width: 1,
            color: const Color(0xFFE2E8F0),
          ),
          // Right Form Panel
          Expanded(
            flex: 58,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFormHeader(scheme),
                    const SizedBox(height: 24),
                    _buildDynamicFormBody(scheme),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- MOBILE / TABLET SINGLE COLUMN VIEW ----------------
  Widget _buildMobileLayout(ColorScheme scheme, List<Color> heroColors) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMobileTopBrandHeader(scheme),
            const SizedBox(height: 20),
            _buildModeSelectorTabs(scheme),
            const SizedBox(height: 24),
            _buildFormHeader(scheme),
            const SizedBox(height: 20),
            _buildDynamicFormBody(scheme),
          ],
        ),
      ),
    );
  }

  // ---------------- LEFT HERO PANEL (MATCHED WITH SALES SCREEN) ----------------
  Widget _buildLeftHeroPanel(ColorScheme scheme, List<Color> heroColors) {
    final gradientColors = heroColors.isNotEmpty
        ? heroColors
        : [scheme.primary, scheme.primary.withValues(alpha: 0.85), scheme.secondary];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Logo & System Pill
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(Icons.storefront_rounded, color: scheme.primary, size: 26),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "FAMALTH LYNX",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    "Enterprise Business OS",
                    style: TextStyle(
                      color: Color(0xFFE0E7FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (AppConfig.outlets.isNotEmpty)
                IconButton(
                  tooltip: "Back to App",
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            "Setup & Provisioning",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Choose a provisioning mode to configure your outlet workstation.",
            style: TextStyle(
              color: Color(0xFFE0E7FF),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Interactive Setup Mode Cards
          _buildHeroModeCard(
            scheme: scheme,
            mode: SetupMode.newClient,
            title: "New Registration",
            subtitle: "Create a new business outlet with auto-generated ID",
            icon: Icons.add_business_rounded,
            badge: "Recommended",
          ),
          const SizedBox(height: 10),
          _buildHeroModeCard(
            scheme: scheme,
            mode: SetupMode.existingClient,
            title: "Link Existing Outlet",
            subtitle: "Connect this workstation using your Business ID & PIN",
            icon: Icons.link_rounded,
          ),
          const SizedBox(height: 10),
          _buildHeroModeCard(
            scheme: scheme,
            mode: SetupMode.recoverId,
            title: "Find Business ID",
            subtitle: "Look up your outlet code via registered email or mobile",
            icon: Icons.search_rounded,
          ),
          if (_isLocalSetupServer) ...[
            const SizedBox(height: 10),
            _buildHeroModeCard(
              scheme: scheme,
              mode: SetupMode.restoreLocal,
              title: "Restore Snapshot",
              subtitle: "Disaster recovery from an encrypted .enc backup file",
              icon: Icons.restore_rounded,
            ),
          ],

          const SizedBox(height: 32),

          // Enterprise Protection Footer (No Bank reference)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Enterprise Protection Active",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        "Bcrypt 12 Hashing · Multi-Tenant Isolation",
                        style: TextStyle(
                          color: Color(0xFFE0E7FF),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroModeCard({
    required ColorScheme scheme,
    required SetupMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    String? badge,
  }) {
    final isSelected = _mode == mode;

    return InkWell(
      onTap: () => _switchMode(mode),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.15),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? scheme.primary : Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFFE0E7FF),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  // ---------------- MOBILE HEADER & TABS ----------------
  Widget _buildMobileTopBrandHeader(ColorScheme scheme) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.secondary],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "FAMALTH LYNX",
              style: TextStyle(
                color: scheme.primary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const Text(
              "Enterprise Outlet Setup",
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (AppConfig.outlets.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
            onPressed: () => Navigator.pop(context),
          ),
      ],
    );
  }

  Widget _buildModeSelectorTabs(ColorScheme scheme) {
    final options = <_ModeOption>[
      const _ModeOption(
        mode: SetupMode.newClient,
        label: "New Outlet",
        icon: Icons.add_business_rounded,
      ),
      const _ModeOption(
        mode: SetupMode.existingClient,
        label: "Link Device",
        icon: Icons.link_rounded,
      ),
      const _ModeOption(
        mode: SetupMode.recoverId,
        label: "Find ID",
        icon: Icons.search_rounded,
      ),
      if (_isLocalSetupServer)
        const _ModeOption(
          mode: SetupMode.restoreLocal,
          label: "Restore",
          icon: Icons.restore_rounded,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = _mode == opt.mode;
          return Expanded(
            child: InkWell(
              onTap: () => _switchMode(opt.mode),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      opt.icon,
                      size: 15,
                      color: isSelected
                          ? scheme.primary
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        opt.label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? scheme.primary
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------- FORM HEADER ----------------
  Widget _buildFormHeader(ColorScheme scheme) {
    String title;
    String subtitle;
    IconData icon;

    switch (_mode) {
      case SetupMode.newClient:
        title = "Create Business Profile";
        subtitle = "Fill in your store details to initialize your local and cloud database.";
        icon = Icons.domain_add_rounded;
        break;
      case SetupMode.existingClient:
        title = _step == FlowStep.otpVerification
            ? "Two-Factor Verification"
            : "Link Existing Workstation";
        subtitle = _step == FlowStep.otpVerification
            ? "Enter the 6-digit one-time passcode sent to your registered contact."
            : "Enter your registered Business ID and PIN to synchronize this terminal.";
        icon = Icons.devices_rounded;
        break;
      case SetupMode.recoverId:
        title = _step == FlowStep.otpVerification
            ? "Verify Identity"
            : "Recover Business ID";
        subtitle = _step == FlowStep.otpVerification
            ? "Enter the code sent to your email/phone to view your Business ID."
            : "Search by your registered email or phone to locate your account.";
        icon = Icons.vpn_key_rounded;
        break;
      case SetupMode.restoreLocal:
        title = "Disaster Recovery (.enc)";
        subtitle = "Upload an encrypted snapshot file to restore local database and settings.";
        icon = Icons.settings_backup_restore_rounded;
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDBEAFE)),
          ),
          child: Icon(icon, color: scheme.primary, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicFormBody(ColorScheme scheme) {
    switch (_mode) {
      case SetupMode.newClient:
        return _buildNewSetupForm(scheme);
      case SetupMode.existingClient:
        return _buildExistingClientForm(scheme);
      case SetupMode.recoverId:
        return _buildRecoverIdForm(scheme);
      case SetupMode.restoreLocal:
        return _buildRestoreLocalForm(scheme);
    }
  }

  // ---------------- 1. FORM: NEW OUTLET REGISTRATION ----------------
  Widget _buildNewSetupForm(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("1. Business Identity", Icons.store_rounded, scheme),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _modernInputField(
                controller: _outletCode,
                label: "Business ID (Auto-Generated)",
                hint: "OUTLET...",
                icon: Icons.tag_rounded,
                readOnly: true,
                scheme: scheme,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: "Copy ID",
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _outletCode.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Business ID Copied to Clipboard')),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _modernInputField(
                controller: _outletName,
                label: "Business / Outlet Name *",
                hint: "e.g. Royal Grand Hotel & Spa",
                icon: Icons.business_rounded,
                required: true,
                scheme: scheme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _modernDropdown(scheme)),
            const SizedBox(width: 14),
            Expanded(child: _modernModuleDropdown(scheme)),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionTitle("2. Security & Verification", Icons.admin_panel_settings_rounded, scheme),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _modernInputField(
                controller: _recoveryPin,
                label: "Master Recovery PIN (Min 4 Digits) *",
                hint: "Create a secret PIN",
                icon: Icons.lock_outline_rounded,
                obscureText: _obscurePin,
                scheme: scheme,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscurePin = !_obscurePin),
                ),
                validator: (v) =>
                    v == null || v.trim().length < 4 ? "Min 4 characters required." : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _modernInputField(
                controller: _contactPhone,
                label: "Contact Mobile / WhatsApp (Opt)",
                hint: "+91 98765 43210",
                icon: Icons.phone_android_rounded,
                required: false,
                scheme: scheme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Email Verification Card
        _buildEmailVerificationCard(scheme),
        const SizedBox(height: 28),
        _buildActionButton(
          "Complete Setup & Launch Business",
          Icons.rocket_launch_rounded,
          scheme,
          _isEmailVerified
              ? _saveNew
              : () {
                  _showError(
                    "Please verify your contact email address before completing registration.",
                  );
                },
        ),
      ],
    );
  }

  Widget _buildEmailVerificationCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isEmailVerified
            ? const Color(0xFFF0FDF4)
            : (_isOtpSentForSetup ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isEmailVerified
              ? const Color(0xFFBBF7D0)
              : (_isOtpSentForSetup ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isEmailVerified
                    ? Icons.verified_user_rounded
                    : (_isOtpSentForSetup ? Icons.mark_email_unread_rounded : Icons.mail_outline_rounded),
                color: _isEmailVerified
                    ? const Color(0xFF16A34A)
                    : (_isOtpSentForSetup ? scheme.primary : const Color(0xFF475569)),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "Registered Admin Email Verification",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _isEmailVerified
                      ? const Color(0xFF166534)
                      : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              if (_isEmailVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 13, color: Color(0xFF15803D)),
                      SizedBox(width: 4),
                      Text(
                        "Verified",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _modernInputField(
                  controller: _contactEmail,
                  label: "Admin Email *",
                  hint: "admin@hotel.com",
                  icon: Icons.alternate_email_rounded,
                  required: true,
                  readOnly: _isEmailVerified || _isOtpSentForSetup,
                  scheme: scheme,
                ),
              ),
              const SizedBox(width: 10),
              if (_isEmailVerified)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _resetEmailVerification,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text("Change"),
                  ),
                )
              else if (_isOtpSentForSetup)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _resetEmailVerification,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text("Edit"),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isLoading ? null : () => _sendSetupOtp(scheme.primary),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text("Send Code"),
                  ),
                ),
            ],
          ),
          if (_isOtpSentForSetup && !_isEmailVerified) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _modernInputField(
                    controller: _setupOtpCode,
                    label: "Enter 6-Digit Email Code *",
                    hint: "123456",
                    icon: Icons.pin_outlined,
                    isNumber: true,
                    required: true,
                    scheme: scheme,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isLoading ? null : _verifySetupOtp,
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text("Verify Code"),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------- 2. FORM: LINK EXISTING OUTLET ----------------
  Widget _buildExistingClientForm(ColorScheme scheme) {
    if (_step == FlowStep.otpVerification) {
      return _buildOtpVerificationSection(
        _isLocalSetupServer
            ? "Verify & Recover Full Database"
            : "Verify & Link Terminal",
        _verifyOtpAndLink,
        () => _requestOtpForExisting(isResend: true),
        scheme,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _modernInputField(
          controller: _outletCode,
          label: "Business ID *",
          hint: "e.g. OUTLET20260901",
          icon: Icons.tag_rounded,
          scheme: scheme,
        ),
        const SizedBox(height: 16),
        if (!_forgotPinMode) ...[
          _modernInputField(
            controller: _recoveryPin,
            label: "Recovery Master PIN *",
            hint: "Enter your 4+ digit security PIN",
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePin,
            scheme: scheme,
            suffixIcon: IconButton(
              icon: Icon(_obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscurePin = !_obscurePin),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => _forgotPinMode = true),
              icon: const Icon(Icons.help_outline_rounded, size: 16),
              label: const Text("Forgot PIN? Verify with Email/SMS OTP"),
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            _isLocalSetupServer ? "Verify & Restore System" : "Verify & Link Workstation",
            Icons.sync_rounded,
            scheme,
            _verifyExistingPin,
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: scheme.primary, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "We will send a one-time passcode to the registered contact on file for this Business ID.",
                    style: TextStyle(color: Color(0xFF1E40AF), fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _forgotPinMode = false),
              child: const Text("I remember my PIN"),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            "Send Verification Passcode",
            Icons.send_rounded,
            scheme,
            _requestOtpForExisting,
          ),
        ],
      ],
    );
  }

  // ---------------- 3. FORM: RECOVER BUSINESS ID ----------------
  Widget _buildRecoverIdForm(ColorScheme scheme) {
    if (_step == FlowStep.otpVerification) {
      return _buildOtpVerificationSection(
        "Verify OTP & Retrieve Business ID",
        _verifyRecoveryOtp,
        () => _findOutletAndSendOtp(isResend: true),
        scheme,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFD97706), size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Forgot your Business ID? Enter your registered email or phone to search the cloud registry.",
                  style: TextStyle(color: Color(0xFF92400E), fontSize: 12.5, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _modernInputField(
          controller: _contactEmail,
          label: "Registered Email or Phone *",
          hint: "admin@hotel.com or +91 9876543210",
          icon: Icons.search_rounded,
          scheme: scheme,
        ),
        const SizedBox(height: 24),
        _buildActionButton(
          "Lookup Outlets & Send OTP",
          Icons.manage_search_rounded,
          scheme,
          _findOutletAndSendOtp,
        ),
      ],
    );
  }

  // ---------------- 4. FORM: RESTORE SNAPSHOT ----------------
  Widget _buildRestoreLocalForm(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              Icon(Icons.folder_zip_outlined, color: scheme.primary, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Select an encrypted disaster recovery backup (.enc) to restore the local database on this server.",
                  style: TextStyle(color: Color(0xFF1E40AF), fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        InkWell(
          onTap: _isRestoringLocalEnc ? null : _pickRestoreEncFile,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _restoreEncName != null ? scheme.primary : const Color(0xFFCBD5E1),
                width: _restoreEncName != null ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _restoreEncName != null ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _restoreEncName != null ? Icons.file_present_rounded : Icons.upload_file_rounded,
                    color: _restoreEncName != null ? scheme.primary : const Color(0xFF64748B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _restoreEncName ?? "Click to browse .enc file",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _restoreEncName != null ? const Color(0xFF0F172A) : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _restoreEncName != null
                            ? "${(_restoreEncBytes?.length ?? 0) ~/ 1024} KB · Ready to restore"
                            : "Supports Famalth encrypted backup archives",
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _isRestoringLocalEnc ? null : _pickRestoreEncFile,
                  child: Text(_restoreEncName != null ? "Change" : "Browse"),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        _buildActionButton(
          _isRestoringLocalEnc ? "Restoring Database..." : "Restore Backup (.enc)",
          Icons.restore_page_rounded,
          scheme,
          _isRestoringLocalEnc ? () {} : _restoreFromLocalEnc,
        ),
      ],
    );
  }

  // ---------------- SHARED UI COMPONENTS ----------------

  Widget _buildSectionTitle(String title, IconData icon, ColorScheme scheme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _modernInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ColorScheme scheme,
    bool readOnly = false,
    bool obscureText = false,
    bool required = true,
    bool isNumber = false,
    Widget? suffixIcon,
    TextInputAction textInputAction = TextInputAction.next,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      obscureText: obscureText,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      textInputAction: textInputAction,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: readOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A),
      ),
      validator: validator ??
          (required
              ? (v) => v == null || v.trim().isEmpty ? "Required field" : null
              : null),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
    );
  }

  Widget _modernDropdown(ColorScheme scheme) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _outletType,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: "Business Type",
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        prefixIcon: const Icon(Icons.category_rounded, size: 20, color: Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'HOTEL', child: Text('Hotel & Lodging')),
        DropdownMenuItem(value: 'RESTAURANT', child: Text('Restaurant & Dining')),
        DropdownMenuItem(value: 'CAFE', child: Text('Cafe & Bakery')),
        DropdownMenuItem(value: 'BAR', child: Text('Bar & Lounge')),
        DropdownMenuItem(value: 'MART', child: Text('Supermarket & Mart')),
        DropdownMenuItem(value: 'KIRANA', child: Text('Kirana & Grocery')),
        DropdownMenuItem(value: 'RETAIL', child: Text('Retail Store')),
        DropdownMenuItem(value: 'CLOTHES', child: Text('Apparel & Fashion')),
        DropdownMenuItem(value: 'SHOES', child: Text('Footwear Store')),
        DropdownMenuItem(value: 'MEDICAL', child: Text('Pharmacy & Medical')),
        DropdownMenuItem(value: 'WAREHOUSE', child: Text('Warehouse & Logistics')),
        DropdownMenuItem(value: 'PARTS', child: Text('Spare Parts Seller')),
        DropdownMenuItem(value: 'MACHINERY', child: Text('Industrial Machinery')),
        DropdownMenuItem(value: 'PETS', child: Text('Pet Care & Supplies')),
        DropdownMenuItem(value: 'SOFTWARE', child: Text('IT & Digital Services')),
      ],
      onChanged: (v) => setState(() => _outletType = v!),
    );
  }

  Widget _modernModuleDropdown(ColorScheme scheme) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _businessModule,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: "Feature Set & Module *",
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        prefixIcon: const Icon(Icons.widgets_rounded, size: 20, color: Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      items: const [
        DropdownMenuItem(
          value: 'ALL',
          child: Text('All Features (Retail + Restaurant + Inventory)'),
        ),
        DropdownMenuItem(
          value: 'RETAIL',
          child: Text('Retail POS (Billing + Stock Inventory)'),
        ),
        DropdownMenuItem(
          value: 'RESTAURANT',
          child: Text('Restaurant & Cafe (KDS, KOTs, Tables + POS)'),
        ),
        DropdownMenuItem(
          value: 'INVENTORY',
          child: Text('Inventory Only (Stock, PO, HRMS & Reports)'),
        ),
      ],
      onChanged: (v) => setState(() => _businessModule = v!),
    );
  }

  Widget _buildOtpVerificationSection(
      String buttonLabel, VoidCallback onSubmit, VoidCallback onResend, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.mark_email_read_rounded, color: Color(0xFF16A34A), size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "A verification code has been dispatched. Enter it below to complete authentication.",
                  style: TextStyle(color: Color(0xFF166534), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _modernInputField(
          controller: _otpCode,
          label: "6-Digit Passcode *",
          hint: "123456",
          icon: Icons.pin_outlined,
          isNumber: true,
          scheme: scheme,
          validator: (v) => v == null || v.length < 4 ? "Invalid OTP code" : null,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _step = FlowStep.initial),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text("Edit Details"),
            ),
            TextButton.icon(
              onPressed: _isLoading ? null : onResend,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text("Resend Code"),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildActionButton(buttonLabel, Icons.check_circle_rounded, scheme, onSubmit),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, ColorScheme scheme, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          elevation: 2,
          shadowColor: scheme.primary.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: (_isLoading || _isRestoringLocalEnc) ? null : onPressed,
        icon: (_isLoading || _isRestoringLocalEnc)
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, size: 20),
        label: (_isLoading || _isRestoringLocalEnc)
            ? const SizedBox.shrink()
            : Text(
                label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  // ================= MODALS & DIALOGS =================

  void _showLinkCompleteDialog() {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
            SizedBox(width: 12),
            Text("Terminal Linked"),
          ],
        ),
        content: const Text(
          "Your workstation has been successfully verified and linked to this business.",
          style: TextStyle(color: Color(0xFF475569)),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text("Proceed to Login"),
          ),
        ],
      ),
    );
  }

  Future<void> _showRecoveredOutletsDialog(List<dynamic> outlets) async {
    final scheme = Theme.of(context).colorScheme;
    int? selectedIndex = outlets.length == 1 ? 0 : null;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Icon(Icons.fact_check_rounded, color: scheme.primary),
                const SizedBox(width: 12),
                const Text('Select Business Outlet', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: const Text(
                      "The following business outlets were located under your verified account. Choose the outlet to link to this workstation:",
                      style: TextStyle(color: Color(0xFF1E40AF), fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: outlets.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        itemBuilder: (context, index) {
                          final outlet = outlets[index];
                          final code = outlet['outlet_code'] ?? 'UNKNOWN';
                          final name = outlet['property_name'] ?? 'Unknown Outlet';
                          final isSelected = selectedIndex == index;

                          return InkWell(
                            onTap: () => setDialogState(() => selectedIndex = index),
                            child: Container(
                              color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color: isSelected ? scheme.primary : const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "ID: $code",
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: selectedIndex == null
                    ? null
                    : () {
                        final selectedCode = outlets[selectedIndex!]['outlet_code'];
                        Navigator.pop(context);
                        setState(() {
                          _outletCode.text = selectedCode;
                          _mode = SetupMode.existingClient;
                          _step = FlowStep.initial;
                          _forgotPinMode = false;
                        });
                      },
                child: const Text("Use Selected Outlet"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCredentialsDialog(
      String outletCode, String username, String password) async {
    final scheme = Theme.of(context).colorScheme;
    final String exportText =
        "=== SYSTEM SETUP CREDENTIALS ===\nDate: ${DateTime.now().toString().split('.')[0]}\nBusiness ID: $outletCode\nAdmin Username: $username\nAdmin Password: $password\n================================\nPlease keep this file secure.";

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool hasSaved = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 30),
                  SizedBox(width: 12),
                  Text('Setup Complete & Credentials Ready', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mark_email_read_rounded, color: Color(0xFF2563EB), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _contactEmail.text.trim().isNotEmpty
                                  ? "Login credentials have been sent to: ${_contactEmail.text.trim()}"
                                  : "Credentials generated. Please save or copy them before logging in.",
                              style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Save these credentials now. The password is encrypted and cannot be displayed again.",
                              style: TextStyle(color: Color(0xFF92400E), fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _credentialRow('Business ID', outletCode),
                          const Divider(height: 20, color: Color(0xFFE2E8F0)),
                          _credentialRow('Username', username),
                          const Divider(height: 20, color: Color(0xFFE2E8F0)),
                          _credentialRow('Password', password),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: exportText));
                            setState(() => hasSaved = true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Credentials copied to clipboard!'),
                                backgroundColor: Color(0xFF059669),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text("Copy"),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final success = await saveOrDownloadTextFile(
                                filename: 'Admin_Credentials_$outletCode.txt',
                                content: exportText,
                              );
                              setState(() => hasSaved = true);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success
                                      ? 'Credentials file downloaded successfully (.txt)!'
                                      : 'Credentials copied to clipboard.'),
                                  backgroundColor: const Color(0xFF059669),
                                ),
                              );
                            } catch (_) {
                              setState(() => hasSaved = true);
                            }
                          },
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text("Save File (.txt)"),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: hasSaved
                          ? () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LoginScreen(
                                    initialOutletCode: outletCode,
                                    initialUsername: username,
                                    initialPassword: password,
                                    initialRole: 'ADMIN',
                                  ),
                                ),
                              )
                          : null,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text("Continue to Login"),
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

  Widget _credentialRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF0F172A),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeOption {
  final SetupMode mode;
  final String label;
  final IconData icon;

  const _ModeOption({
    required this.mode,
    required this.label,
    required this.icon,
  });
}

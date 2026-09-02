import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:retailpos/core/api/api_client.dart';
import 'package:retailpos/core/api/endpoints.dart';
import 'package:retailpos/core/auth/auth_service.dart';
import 'package:retailpos/core/auth/token_storage.dart';
import 'package:retailpos/core/config/app_brand.dart';
import 'package:retailpos/core/config/app_config.dart';
import 'package:retailpos/core/config/app_constants.dart';
import 'package:retailpos/core/navigation/home_route_helper.dart';
import 'package:retailpos/widgets/famalth_watermark.dart';
import 'package:retailpos/screens/settings/outlet_setup_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;

import 'package:provider/provider.dart';
import '../../controllers/settings/theme_controller.dart';
import '../../core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retailpos/widgets/brand_logo_widget.dart';
import '../../controllers/security/password_recovery_controller.dart';
import '../../utils/branding_storage.dart';
import '../../core/settings/local_preferences.dart';
import '../../core/config/server_check.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
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
  String? _bgCoverImagePath;

  late final AnimationController _logoCtrl;

  bool _isloading = false;
  String currentVersion = "";

  String _activeModule = 'ALL';

  HealthResponse? _serverHealth;
  bool _isCheckingServer = false;

  @override
  void initState() {
    super.initState();
    getVersion();
    _checkServerHealth();

    if (AppConfig.outlets.isNotEmpty) {
      _selectedOutlet = AppConfig.outlets.first;
    }
    _loadOutletLogo();

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _logoCtrl.forward();
  }

  Future<void> _checkServerHealth() async {
    if (!mounted) return;
    setState(() => _isCheckingServer = true);
    try {
      final res = await checkServer();
      if (mounted) {
        setState(() {
          _serverHealth = res;
          _isCheckingServer = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCheckingServer = false);
      }
    }
  }

  void getVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    currentVersion = packageInfo.version;
    setState(() {});
  }

  Future<void> _loadOutletLogo() async {
    String mod = 'ALL';
    String? fetchedPath = _logoPath;

    if (_selectedOutlet != null) {
      final localPath = await BrandingStorage.getLogoPathForOutlet(_selectedOutlet!);
      if (localPath != null && localPath.isNotEmpty) {
        fetchedPath = localPath;
      }

      try {
        final res = await ApiClient.get(
          '${ApiEndpoints.propertyInfo}?outlet_code=$_selectedOutlet',
        );
        if (res != null && res['success'] == true && res['data'] != null) {
          final data = res['data'];
          mod = data['business_module'] ?? data['outlet_module'] ?? 'ALL';
          final serverLogo = data['logo_path']?.toString();
          if (serverLogo != null && serverLogo.trim().isNotEmpty) {
            fetchedPath = serverLogo.trim();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('brand_logo_$_selectedOutlet', fetchedPath);
          }
        }
      } catch (_) {
        try {
          final res = await ApiClient.post(
            ApiEndpoints.checkOutlet,
            {'outlet_code': _selectedOutlet!},
          );
          if (res != null && res['success'] == true && res['data'] != null) {
            mod = res['data']['business_module'] ?? 'ALL';
            final serverLogo = res['data']['logo_path']?.toString();
            if (serverLogo != null && serverLogo.trim().isNotEmpty) {
              fetchedPath = serverLogo.trim();
            }
          }
        } catch (_) {}
      }
    }

    if (mod == 'ALL') {
      final user = await TokenStorage.getUser();
      mod = user?['business_module'] ?? user?['outlet_module'] ?? 'ALL';
    }

    final branding = await LocalPreferences.getAppBranding();
    if (!mounted) return;

    if (_logoPath != fetchedPath ||
        _activeModule != mod ||
        _bgCoverImagePath != branding.homeBgImagePath) {
      setState(() {
        _logoPath = fetchedPath;
        _activeModule = mod;
        _bgCoverImagePath = branding.homeBgImagePath;
      });
    }
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
        if (_selectedOutlet != null && !AppConfig.outlets.contains(_selectedOutlet)) {
          final updated = List<String>.from(AppConfig.outlets)..add(_selectedOutlet!);
          await AppConfig.saveConfig(AppConfig.baseUrl, updated);
        }

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

  ImageProvider? _getHeroBgImageProvider(String? rawPath) {
    if (rawPath == null || rawPath.trim().isEmpty) return null;
    final path = rawPath.trim();

    // 1. Base64
    if (path.startsWith('data:image') ||
        path.contains(';base64,') ||
        (path.length > 200 && !path.contains(' '))) {
      try {
        final base64Str = path.contains(',') ? path.split(',').last : path;
        final bytes = base64Decode(base64Str.trim());
        return MemoryImage(bytes);
      } catch (_) {}
    }

    // 2. Full Network URL
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }

    // 3. Relative Server Path
    if (path.startsWith('/') || path.startsWith('uploads/')) {
      final baseUrl = AppConfig.baseUrl.replaceAll(RegExp(r'/$'), '');
      final fullUrl = path.startsWith('/') ? '$baseUrl$path' : '$baseUrl/$path';
      return NetworkImage(fullUrl);
    }

    // 4. Native File Path
    if (!kIsWeb && File(path).existsSync()) {
      return FileImage(File(path));
    }

    return null;
  }

  Widget _buildBrandLogoWidget({double size = 76}) {
    return BrandLogoWidget(logoPath: _logoPath, size: size);
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

  bool get _shouldShowServerBadge {
    if (kIsWeb) return false;
    return Platform.isWindows;
  }

  Widget _desktopLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeKey = context.watch<ThemeController>().themeKey;
    final heroColors = AppTheme.getHeroGradientColors(themeKey);

    return SizedBox(
      height: 610,
      child: Row(
        children: [
          // ==================== LEFT HERO PANEL ====================
          Container(
            width: 420,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: heroColors,
              ),
              image: _getHeroBgImageProvider(_bgCoverImagePath) != null
                  ? DecorationImage(
                      image: _getHeroBgImageProvider(_bgCoverImagePath)!,
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.45),
                        BlendMode.darken,
                      ),
                    )
                  : null,
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo Halo Container
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withOpacity(0.18),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: Colors.white,
                    child: _buildBrandLogoWidget(size: 76),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  AppBrand.productName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'POS, billing, accounting, and multi-outlet reporting in one secure flow.',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    height: 1.45,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _HeroPill(icon: Icons.bolt_rounded, label: 'Fast POS Billing'),
                    _HeroPill(icon: Icons.cloud_sync_rounded, label: 'Cloud & Offline Sync'),
                    _HeroPill(icon: Icons.security_rounded, label: 'Enterprise Security'),
                  ],
                ),
                const Spacer(),
                const FamalthWatermark(
                  showVersion: true,
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                ),
              ],
            ),
          ),

          // ==================== RIGHT FORM PANEL ====================
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Server Connectivity Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Access your store terminal & workstation',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        if (_shouldShowServerBadge) _buildServerStatusBadge(),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _loginForm(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          if (_shouldShowServerBadge)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildServerStatusBadge(isCompact: true),
              ],
            ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 38,
              backgroundColor: Colors.white,
              child: _buildBrandLogoWidget(size: 64),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            AppBrand.productName,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            'FAMALTH LYNX - Cloud & Offline POS Ecosystem',
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), height: 1.35, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('New to FAMALTH LYNX? ',
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569), fontSize: 13)),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const OutletSetupScreen()),
                  );
                },
                child: Text(
                  'Register Now',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Mobile recommendation banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFF59E0B).withOpacity(0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.desktop_windows_outlined, color: Color(0xFFD97706), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Desktop Mode Recommended for POS Terminals',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'For best billing experience on mobile browsers, switch to "Desktop Site".',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _loginForm(),
        ],
      ),
    );
  }

  Widget _buildServerStatusBadge({bool isCompact = false}) {
    if (!_shouldShowServerBadge) return const SizedBox.shrink();

    final isChecking = _isCheckingServer;
    final isOnline = _serverHealth?.isRunning == true;
    final isLocal = AppConfig.isLocalServer;
    final isLan = !isLocal && !kIsWeb && (AppConfig.baseUrl.contains('192.168.') || AppConfig.baseUrl.contains('10.'));

    Color badgeBg;
    Color badgeBorder;
    Color dotColor;
    Color textColor;
    String label;
    IconData icon;

    if (isChecking) {
      badgeBg = const Color(0xFFF1F5F9);
      badgeBorder = const Color(0xFFCBD5E1);
      dotColor = const Color(0xFF94A3B8);
      textColor = const Color(0xFF475569);
      label = 'Checking...';
      icon = Icons.sync;
    } else if (isOnline) {
      badgeBg = const Color(0xFFECFDF5);
      badgeBorder = const Color(0xFFA7F3D0);
      dotColor = const Color(0xFF10B981);
      textColor = const Color(0xFF065F46);
      if (isLocal) {
        label = isCompact ? 'Local POS' : 'Local Engine • Online';
        icon = Icons.computer;
      } else if (isLan) {
        label = isCompact ? 'LAN Server' : 'LAN Server • Online';
        icon = Icons.lan_outlined;
      } else {
        label = isCompact ? 'Cloud Sync' : 'Cloud Server • Connected';
        icon = Icons.cloud_done_outlined;
      }
    } else {
      badgeBg = const Color(0xFFFEF2F2);
      badgeBorder = const Color(0xFFFECACA);
      dotColor = const Color(0xFFEF4444);
      textColor = const Color(0xFF991B1B);
      label = isCompact ? 'Offline' : 'Server Offline • Click to Fix';
      icon = Icons.cloud_off_outlined;
    }

    return Tooltip(
      message: 'Active API: ${AppConfig.baseUrl}\nClick to test or change server',
      child: InkWell(
        onTap: () => _showServerConfigDialog(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12, vertical: isCompact ? 5 : 6),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: badgeBorder, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isChecking)
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF64748B)),
                )
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withOpacity(0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 7),
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: isCompact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.tune_rounded, size: 12, color: textColor.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showServerConfigDialog(BuildContext context) async {
    final urlCtrl = TextEditingController(text: AppConfig.baseUrl);
    bool isTesting = false;
    String? testMsg;
    bool? testSuccess;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> runTest(String testUrl) async {
              setDialogState(() {
                isTesting = true;
                testMsg = null;
                testSuccess = null;
              });
              try {
                final uri = Uri.parse('$testUrl/health');
                final res = await http.get(uri).timeout(const Duration(seconds: 4));
                if (res.statusCode == 200) {
                  setDialogState(() {
                    testSuccess = true;
                    testMsg = 'Connected successfully! Server is healthy.';
                  });
                } else {
                  setDialogState(() {
                    testSuccess = false;
                    testMsg = 'Server responded with status ${res.statusCode}.';
                  });
                }
              } catch (e) {
                setDialogState(() {
                  testSuccess = false;
                  testMsg = 'Failed to connect: Server unreachable or offline.';
                });
              } finally {
                setDialogState(() => isTesting = false);
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.dns_rounded, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Server & Connectivity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configure the active server endpoint URL for this workstation.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    const Text('Target Server URL / IP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: urlCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. http://127.0.0.1:3000 or https://api.store.com',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: const Icon(Icons.link, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF2563EB)),
                          tooltip: 'Test Connection',
                          onPressed: isTesting ? null : () => runTest(urlCtrl.text.trim()),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    if (isTesting) ...[
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Pinging server...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ] else if (testMsg != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: testSuccess == true ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: testSuccess == true ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            Icon(testSuccess == true ? Icons.check_circle : Icons.error_outline, size: 16, color: testSuccess == true ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                testMsg!,
                                style: TextStyle(fontSize: 12, color: testSuccess == true ? const Color(0xFF065F46) : const Color(0xFF991B1B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final newUrl = urlCtrl.text.trim();
                    if (newUrl.isNotEmpty) {
                      await AppConfig.saveConfig(newUrl, AppConfig.outlets);
                      if (context.mounted) {
                        Navigator.pop(dialogCtx);
                        _checkServerHealth();
                        _loadOutletLogo();
                      }
                    }
                  },
                  child: const Text('Save & Reconnect'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _enterpriseInputDecoration({
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
    String? hintText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
      floatingLabelStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
      ),
      prefixIcon: Icon(prefixIcon, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
      ),
    );
  }

  Widget _loginForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Visibility(
            visible: kIsWeb || (!Platform.isAndroid && !Platform.isIOS),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedOutlet,
              decoration: _enterpriseInputDecoration(
                labelText: 'Outlet Code',
                prefixIcon: Icons.storefront_rounded,
              ),
              items: AppConfig.outlets
                  .map((o) => DropdownMenuItem(value: o, child: Text(o, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: isDark ? Colors.white : Colors.black))))
                  .toList(),
              onChanged: (v) {
                setState(() => _selectedOutlet = v);
                _loadOutletLogo();
              },
              validator: (v) => v == null ? 'Required' : null,
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _usernameCtrl,
            focusNode: _usernameFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: _enterpriseInputDecoration(
              labelText: 'Username',
              prefixIcon: Icons.person_outline_rounded,
              hintText: 'Enter your operator or cashier ID',
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
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: _enterpriseInputDecoration(
              labelText: 'Password',
              prefixIcon: Icons.lock_outline_rounded,
              hintText: 'Enter your password',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) =>
                v == null || v.length < 4 ? 'Invalid password' : null,
          ),

          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: () {
              final roles = AppConstants.getRolesForModule(_activeModule);
              return roles.contains(_role) ? _role : roles.first;
            }(),
            decoration: _enterpriseInputDecoration(
              labelText: 'Workstation Role',
              prefixIcon: Icons.badge_outlined,
            ),
            items: (() {
              final roles = AppConstants.getRolesForModule(_activeModule);
              final list = roles.contains(_role) ? roles : [...roles, _role];
              return list
                  .map((r) => DropdownMenuItem(value: r, child: Text(r, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: isDark ? Colors.white : Colors.black))))
                  .toList();
            })(),
            onChanged: (v) => setState(() => _role = v ?? _role),
          ),

          const SizedBox(height: 10),

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
                  _showForgotUsernameDialog(context);
                },
                style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                child: Text('Forgot Username?',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ),
              Text('|', style: TextStyle(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))),
              TextButton(
                onPressed: () {
                  if (_selectedOutlet == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please select an Outlet Code first.')),
                    );
                    return;
                  }
                  _showForgotPasswordDialog(context);
                },
                style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                child: Text('Forgot Password?',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Enterprise Primary Sign In Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF2563EB) : primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                shadowColor: primaryColor.withOpacity(0.35),
              ),
              onPressed: _login,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'SIGN IN TO WORKSTATION',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Register Outlet Button (High-Visibility High-Contrast Tonal Button)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
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
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: isDark ? const Color(0xFF0F172A) : primaryColor.withOpacity(0.08),
                side: BorderSide(color: isDark ? const Color(0xFF3B82F6) : primaryColor, width: 1.4),
                foregroundColor: isDark ? const Color(0xFF60A5FA) : primaryColor,
                elevation: 0,
              ),
              icon: Icon(Icons.add_business_rounded, size: 19, color: isDark ? const Color(0xFF60A5FA) : primaryColor),
              label: Text(
                'Register New Business / Outlet',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: isDark ? const Color(0xFF60A5FA) : primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
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
                            Visibility(
                              visible: kIsWeb || (!Platform.isAndroid && !Platform.isIOS),
                              child: TextFormField(
                                initialValue: _selectedOutlet,
                                readOnly: true,
                                decoration: const InputDecoration(
                                    labelText: 'Outlet Code',
                                    filled: true,
                                    fillColor: Color(0xFFF1F5F9),
                                    border: OutlineInputBorder()),
                              ),
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
  final IconData? icon;

  const _HeroPill({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: const Color(0xFF38BDF8)),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}



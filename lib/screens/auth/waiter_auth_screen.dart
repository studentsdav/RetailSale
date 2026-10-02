import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/auth/auth_service.dart';
import '../../core/config/app_config.dart';
import '../dashboard/server_config_screen.dart';
import '../restaurant/waiter_app_screen.dart';

class WaiterAuthScreen extends StatefulWidget {
  const WaiterAuthScreen({super.key});

  @override
  State<WaiterAuthScreen> createState() => _WaiterAuthScreenState();
}

class _WaiterAuthScreenState extends State<WaiterAuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String _pinCode = '';
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _outletCtrl = TextEditingController();
  bool _obscurePassword = true;

  static const Color primaryTeal = Color(0xFF0D9488);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final defaultOutlet = AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : 'OUTLET001';
    _outletCtrl.text = defaultOutlet;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _outletCtrl.dispose();
    super.dispose();
  }

  void _onPinKeyPress(String digit) {
    if (_isLoading) return;
    if (_pinCode.length < 6) {
      HapticFeedback.lightImpact();
      setState(() {
        _pinCode += digit;
      });
      if (_pinCode.length >= 4) {
        // Option to auto submit on 4 or 6 digits if desired, or let user press Login
      }
    }
  }

  void _onPinBackspace() {
    if (_isLoading || _pinCode.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pinCode = _pinCode.substring(0, _pinCode.length - 1);
    });
  }

  void _onPinClear() {
    if (_isLoading || _pinCode.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _pinCode = '';
    });
  }

  Future<void> _loginWithPin() async {
    if (_pinCode.isEmpty) {
      _showError('Please enter your Waiter PIN code.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final outlet = _outletCtrl.text.trim().isNotEmpty ? _outletCtrl.text.trim() : 'OUTLET001';
      final result = await AuthService.pinLogin(_pinCode, outlet);

      if (!mounted) return;

      if (result.success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WaiterAppScreen()),
        );
      } else {
        _showError(result.message);
        setState(() => _pinCode = '');
      }
    } catch (e) {
      _showError(e.toString());
      setState(() => _pinCode = '');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithPassword() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final outlet = _outletCtrl.text.trim().isNotEmpty ? _outletCtrl.text.trim() : 'OUTLET001';

    if (username.isEmpty || password.isEmpty) {
      _showError('Please enter both username and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await AuthService.login(username, password, 'WAITER', outlet);

      if (!mounted) return;

      if (result.success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WaiterAppScreen()),
        );
      } else {
        _showError(result.message);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient = isDark
        ? [const Color(0xFF0F172A), const Color(0xFF020617)]
        : [const Color(0xFFF0FDFA), const Color(0xFFF8FAFC)];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bgGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar with Server Config and Brand
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryTeal.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.restaurant_menu_rounded, color: primaryTeal, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "RetailPOS Floor App",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          "Kitchen & Captain Console",
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: "Server Configuration",
                      icon: const Icon(Icons.settings_ethernet_rounded, color: primaryTeal),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ServerConfigScreen(
                              nextScreen: WaiterAuthScreen(),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Tab Selector: PIN Login vs Username Login
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: primaryTeal,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(icon: Icon(Icons.pin_rounded, size: 18), text: "Quick PIN"),
                    Tab(icon: Icon(Icons.person_rounded, size: 18), text: "Staff Login"),
                  ],
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPinLoginTab(isDark),
                    _buildPasswordLoginTab(isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinLoginTab(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          const Text(
            "Enter Waiter / Staff PIN",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),

          // PIN Dots Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              final isFilled = index < _pinCode.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? primaryTeal : Colors.transparent,
                  border: Border.all(
                    color: isFilled ? primaryTeal : (isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                    width: 2,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // Numeric Keypad
          _buildNumericKeypad(isDark),
          const SizedBox(height: 16),

          // Submit PIN Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _loginWithPin,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(
                _isLoading ? "Verifying..." : "Login to Floor",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumericKeypad(bool isDark) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(
        children: keys.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((k) {
                if (k == 'C') {
                  return _buildKeyButton(
                    child: const Text("CLEAR", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    onTap: _onPinClear,
                    isDark: isDark,
                  );
                } else if (k == '⌫') {
                  return _buildKeyButton(
                    child: const Icon(Icons.backspace_outlined, size: 20),
                    onTap: _onPinBackspace,
                    isDark: isDark,
                  );
                } else {
                  return _buildKeyButton(
                    child: Text(k, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    onTap: () => _onPinKeyPress(k),
                    isDark: isDark,
                  );
                }
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKeyButton({required Widget child, required VoidCallback onTap, required bool isDark}) {
    return SizedBox(
      width: 76,
      height: 56,
      child: Material(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 1,
        shadowColor: Colors.black12,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildPasswordLoginTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _usernameCtrl,
            decoration: InputDecoration(
              labelText: "Username",
              prefixIcon: const Icon(Icons.person_outline_rounded, color: primaryTeal),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: "Password",
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: primaryTeal),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _outletCtrl,
            decoration: InputDecoration(
              labelText: "Outlet Code",
              prefixIcon: const Icon(Icons.storefront_rounded, color: primaryTeal),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _loginWithPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(
                _isLoading ? "Signing in..." : "Sign In",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/security/user_controller.dart';
import '../../models/security/app_user_model.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/token_storage.dart';
import '../../core/config/app_config.dart';
import '../dashboard/server_config_screen.dart';
import '../restaurant/captain_dashboard_screen.dart';

class WaiterAuthScreen extends StatefulWidget {
  const WaiterAuthScreen({super.key});

  @override
  State<WaiterAuthScreen> createState() => _WaiterAuthScreenState();
}

class _WaiterAuthScreenState extends State<WaiterAuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String _pinCode = '';
  String _selectedRole = 'WAITER'; // 'WAITER' or 'CAPTAIN'
  int _activeTabIndex = 0;

  List<QuickUser> _quickUsers = [];
  QuickUser? _selectedUser;
  bool _isLoadingUsers = false;

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _outletCtrl = TextEditingController();
  bool _obscurePassword = true;

  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color primaryTealDark = Color(0xFF0F766E);
  static const Color accentTeal = Color(0xFF14B8A6);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _activeTabIndex != _tabController.index) {
        setState(() {
          _activeTabIndex = _tabController.index;
        });
      }
    });
    final defaultOutlet = AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : 'OUTLET001';
    _outletCtrl.text = defaultOutlet;
    _loadQuickUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _outletCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuickUsers() async {
    if (!mounted) return;
    setState(() => _isLoadingUsers = true);
    try {
      final outlet = _outletCtrl.text.trim().isNotEmpty ? _outletCtrl.text.trim() : 'OUTLET001';
      final users = await UserController.fetchQuickUsers(
        outletCode: outlet,
        role: _selectedRole,
      );
      if (!mounted) return;
      setState(() {
        _quickUsers = users;
        if (_quickUsers.isNotEmpty) {
          final existing = _quickUsers.where((u) => u.username == _selectedUser?.username);
          if (existing.isNotEmpty) {
            _selectedUser = existing.first;
          } else {
            _selectedUser = _quickUsers.first;
          }
        } else {
          _selectedUser = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _quickUsers = []);
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  void _onPinKeyPress(String digit) {
    if (_isLoading) return;
    if (_pinCode.length < 6) {
      HapticFeedback.lightImpact();
      setState(() {
        _pinCode += digit;
      });
      if (_pinCode.length == 6) {
        _loginWithPin();
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

  bool _isAuthorizedRole(String? role) {
    final r = (role ?? '').toUpperCase().trim();
    return r == 'WAITER' ||
        r == 'CAPTAIN' ||
        r == 'CAPTION' ||
        r == 'STEWARD' ||
        r == 'SERVER' ||
        r == 'ADMIN' ||
        r == 'MANAGER';
  }

  Future<void> _loginWithPin() async {
    if (_pinCode.isEmpty) {
      _showError('Please enter your PIN code.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final outlet = _outletCtrl.text.trim().isNotEmpty ? _outletCtrl.text.trim() : 'OUTLET001';
      final result = await AuthService.pinLogin(
        _pinCode,
        outlet,
        username: _selectedUser?.username,
        role: _selectedRole,
      );

      if (!mounted) return;

      if (result.success) {
        final user = await TokenStorage.getUser();
        final userRole = user?['role']?.toString();

        if (!_isAuthorizedRole(userRole)) {
          await TokenStorage.clear();
          _showError(
            'Access Denied: Account is assigned role "$userRole", which is not authorized for $_selectedRole console.',
          );
          setState(() => _pinCode = '');
          return;
        }

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CaptainDashboardScreen()),
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
      final result = await AuthService.login(username, password, _selectedRole, outlet);

      if (!mounted) return;

      if (result.success) {
        final user = await TokenStorage.getUser();
        final userRole = user?['role']?.toString();

        if (!_isAuthorizedRole(userRole)) {
          await TokenStorage.clear();
          _showError(
            'Access Denied: User is assigned role "$userRole", not Waiter / Captain for this outlet.',
          );
          return;
        }

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CaptainDashboardScreen()),
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
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient = isDark
        ? [const Color(0xFF0F172A), const Color(0xFF020617)]
        : [const Color(0xFFF4FBF9), const Color(0xFFF8FAFC)];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: bgGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Sleek Top Header Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryTeal.withValues(alpha: 0.2),
                            accentTeal.withValues(alpha: 0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryTeal.withValues(alpha: 0.3)),
                      ),
                      child: const Center(
                        child: Icon(Icons.restaurant_menu_rounded, color: primaryTeal, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "RetailPOS Floor App",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            "Captain & Waiter Mobile Console",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                      ),
                      child: IconButton(
                        tooltip: "Server Configuration",
                        icon: const Icon(Icons.settings_ethernet_rounded, color: primaryTeal, size: 20),
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
                    ),
                  ],
                ),
              ),

              // Role Selector Segmented Switch (Waiter Floor vs Captain Console)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE6EEEC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildRoleSelectButton(
                          label: 'Waiter Floor',
                          role: 'WAITER',
                          icon: Icons.person_pin_circle_rounded,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildRoleSelectButton(
                          label: 'Captain Console',
                          role: 'CAPTAIN',
                          icon: Icons.star_rounded,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Mode Selector Tabs (Quick PIN vs Staff Login)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTabButton(
                          index: 0,
                          icon: Icons.dialpad_rounded,
                          label: "Quick PIN",
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildTabButton(
                          index: 1,
                          icon: Icons.badge_outlined,
                          label: "Staff Login",
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 4),

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

  Widget _buildRoleSelectButton({
    required String label,
    required String role,
    required IconData icon,
    required bool isDark,
  }) {
    final bool isSelected = _selectedRole == role;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedRole = role;
          _pinCode = '';
        });
        _loadQuickUsers();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF0F766E) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? (isDark ? Colors.white : primaryTealDark)
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : primaryTealDark)
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final bool isSelected = _activeTabIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _activeTabIndex = index;
          _tabController.animateTo(index);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryTeal.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSelectorCard(bool isDark) {
    if (_isLoadingUsers) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryTeal.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: primaryTeal)),
            SizedBox(width: 8),
            Text("Loading staff members...", style: TextStyle(fontSize: 12, color: primaryTeal)),
          ],
        ),
      );
    }

    if (_quickUsers.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryTeal.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: primaryTeal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Enter your PIN below to auto-authenticate",
                style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryTeal.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: primaryTeal.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<QuickUser>(
          value: _selectedUser,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primaryTeal, size: 22),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: _quickUsers.map((user) {
            final initial = (user.fullName.isNotEmpty ? user.fullName[0] : (user.username.isNotEmpty ? user.username[0] : 'U')).toUpperCase();
            return DropdownMenuItem<QuickUser>(
              value: user,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: primaryTeal.withValues(alpha: 0.15),
                    child: Text(
                      initial,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryTealDark),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          user.fullName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "@${user.username} • ${user.role}",
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      user.role,
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: primaryTealDark),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (QuickUser? val) {
            setState(() {
              _selectedUser = val;
              _pinCode = '';
            });
          },
        ),
      ),
    );
  }

  Widget _buildPinLoginTab(bool isDark) {
    final displayName = _selectedUser?.fullName ?? _selectedRole;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Column(
        children: [
          // User Selector Dropdown
          _buildUserSelectorCard(isDark),

          // Instruction label
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_clock_outlined,
                size: 15,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                "Enter PIN for $displayName",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Sleek PIN Dots Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              final isFilled = index < _pinCode.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: isFilled ? 16 : 13,
                height: isFilled ? 16 : 13,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? primaryTeal : Colors.transparent,
                  border: Border.all(
                    color: isFilled ? primaryTeal : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                    width: 2,
                  ),
                  boxShadow: isFilled
                      ? [
                          BoxShadow(
                            color: primaryTeal.withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          // Modern Numeric Keypad
          _buildNumericKeypad(isDark),
          const SizedBox(height: 12),

          // Gradient Login Button
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: primaryTeal.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _loginWithPin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                _isLoading ? "Verifying PIN..." : "Login as $displayName",
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
      ['CLEAR', '0', '⌫'],
    ];

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        children: keys.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((k) {
                if (k == 'CLEAR') {
                  return _buildKeyButton(
                    child: const Text(
                      "CLEAR",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEF4444),
                        letterSpacing: 0.4,
                      ),
                    ),
                    onTap: _onPinClear,
                    isDark: isDark,
                    isSpecial: true,
                  );
                } else if (k == '⌫') {
                  return _buildKeyButton(
                    child: Icon(
                      Icons.backspace_outlined,
                      size: 19,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                    ),
                    onTap: _onPinBackspace,
                    isDark: isDark,
                    isSpecial: true,
                  );
                } else {
                  return _buildKeyButton(
                    child: Text(
                      k,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
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

  Widget _buildKeyButton({
    required Widget child,
    required VoidCallback onTap,
    required bool isDark,
    bool isSpecial = false,
  }) {
    return SizedBox(
      width: 78,
      height: 50,
      child: Material(
        color: isSpecial
            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        elevation: isDark ? 0 : (isSpecial ? 0.5 : 1.5),
        shadowColor: Colors.black.withValues(alpha: 0.06),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashColor: primaryTeal.withValues(alpha: 0.15),
          highlightColor: primaryTeal.withValues(alpha: 0.08),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : (isSpecial ? Colors.grey.shade300 : Colors.grey.shade200),
                width: 1,
              ),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordLoginTab(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: "Staff Username",
                prefixIcon: Icon(Icons.person_outline_rounded, color: primaryTeal),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: "Password",
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: primaryTeal),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _outletCtrl,
              decoration: const InputDecoration(
                labelText: "Outlet Code",
                prefixIcon: Icon(Icons.storefront_rounded, color: primaryTeal),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (_) => _loadQuickUsers(),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: primaryTeal.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _loginWithPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.login_rounded, size: 20),
              label: Text(
                _isLoading ? "Signing in..." : "Sign In as $_selectedRole",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

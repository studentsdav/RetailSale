import 'package:flutter/material.dart';
import 'package:retailpos/controllers/security/user_controller.dart';

import '../../controllers/public/outlet_controller.dart' show OutletController;
import '../../models/security/app_user_model.dart';

/// ================= SCREEN =================
class Permission1 {
  String key;
  String label;
  Permission1(this.key, this.label);
}

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _search = TextEditingController();
  final UserController userCtrl = UserController();
  final password = TextEditingController();
  List<AppUser> users = [];
  final outletCtrl = OutletController();

  /// -------- ALL PERMISSIONS --------
  final allPermissions = <Permission1>[
    /// ================= INVENTORY TRANSACTIONS =================
    Permission1('ITEM_REQUEST', 'Item Request'),
    Permission1('PURCHASE_ORDER', 'Purchase Order'),
    Permission1('STOCK_IN', 'Stock In (Receiving)'),
    Permission1('STOCK_OUT', 'Stock Out'),
    Permission1('RETAIL_SALES', 'Retail Sales'),
    Permission1('RETURN', 'Department Return'),
    Permission1('DAMAGE', 'Damage Items'),
    Permission1('SUPPLIER_PAYMENT', 'Supplier Payment'),

    /// ================= MODIFY MODULE =================
    Permission1('MODIFY_REQUEST', 'Modify Request'),
    Permission1('MODIFY_PURCHASE', 'Modify Purchase Order'),
    Permission1('MODIFY_RECEIVING', 'Modify Receiving'),
    Permission1('MODIFY_ISSUE', 'Modify Stock Out'),
    Permission1('REPRINT_REQUEST', 'Reprint Request'),
    Permission1('REPRINT_PURCHASE', 'Reprint Purchase Order'),
    Permission1('REPRINT_RECEIVING', 'Reprint Receiving'),
    Permission1('REPRINT_ISSUE', 'Reprint Stock Out'),
    Permission1('REPRINT_SALES_BILL', 'Reprint Sales Bill'),
    Permission1('MODIFY_SALES_BILL', 'Modify Sales Bill'),
    Permission1('MODIFY_SALES_PAYMENT', 'Modify Sales Payment'),

    /// ================= MASTER DATA =================
    Permission1('ITEM_MASTER', 'Item Master'),
    Permission1('SUPPLIER_MASTER', 'Supplier Master'),
    Permission1('STOCK_LOCATION', 'Stock Location'),

    /// ================= SETTINGS =================
    Permission1('NUMBERING_SETTINGS', 'Numbering Settings'),
    Permission1('PROPERTY_INFORMATION', 'Property Information'),

    /// ================= REPORTS =================
    Permission1('REPORTS', 'Reports'),
    Permission1('STOCK_BALANCE', 'Stock Balance'),
    Permission1('DAMAGE_SUMMARY', 'Damage Summary'),
    Permission1('STOCK_IN_REPORT', 'Stock In Report'),
    Permission1('STOCK_OUT_REPORT', 'Stock Out Report'),
    Permission1('RETAIL_SALES_REPORT', 'Retail Sales Report'),
    Permission1('CLOSING_REPORT', 'Closing Report'),
    Permission1('PURCHASE_REPORT', 'Purchase Report'),
    Permission1('RETURN_REPORT', 'Return Report'),
    Permission1('REQUEST_REPORT', 'Request Report'),
    Permission1('DAMAGE_REPORT', 'Damage Report'),

    /// ================= ADMIN =================
    Permission1('USER_MANAGEMENT', 'User Management'),

    /// ================= SYSTEM =================
    Permission1('SETTINGS', 'Settings'),
    Permission1('SYSTEM_UPDATE', 'System Update'),
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    await userCtrl.load();
    setState(() => users = userCtrl.list);
  }

  List<AppUser> get filteredUsers {
    if (_search.text.isEmpty) return users;
    return users
        .where((u) =>
            u.username.toLowerCase().contains(_search.text.toLowerCase()) ||
            u.fullName.toLowerCase().contains(_search.text.toLowerCase()))
        .toList();
  }

  /// ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('User Management'),
        centerTitle: true,
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.person_add),
            label: const Text('Add User'),
            onPressed: _openCreateUser,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _searchBar(),
            const SizedBox(height: 12),
            _userTable(),
          ],
        ),
      ),
    );
  }

  /// ================= SEARCH =================

  Widget _searchBar() {
    return SizedBox(
      width: 420,
      child: TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search user',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// ================= TABLE =================

  Widget _userTable() {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            columns: const [
              DataColumn(label: Text('Username')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Role')),
              DataColumn(label: Text('Mobile')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: filteredUsers.map((u) {
              return DataRow(
                color: WidgetStateProperty.all(
                  u.isActive ? Colors.white : Colors.grey.shade200,
                ),
                cells: [
                  DataCell(Text(u.username)),
                  DataCell(Text(u.fullName)),
                  DataCell(Text(u.role)),
                  DataCell(Text(u.mobile)),
                  DataCell(Text(u.email)),
                  DataCell(Chip(
                    label: Text(u.isActive ? 'ACTIVE' : 'INACTIVE'),
                    backgroundColor: u.isActive
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                  )),
                  DataCell(Row(
                    children: [
                      IconButton(
                        tooltip: 'Edit User',
                        icon: const Icon(Icons.edit),
                        onPressed: () => _openEditUser(u),
                      ),
                      IconButton(
                        tooltip: 'Permissions',
                        icon: const Icon(Icons.security),
                        onPressed: () => _openPermissions(u),
                      ),
                      IconButton(
                        tooltip: 'Reset Password',
                        icon: const Icon(Icons.lock_reset),
                        onPressed: () => _resetPassword(u),
                      ),
                      IconButton(
                        tooltip: 'Change Password',
                        icon: const Icon(Icons.lock),
                        onPressed: () => _changePassword(u),
                      ),
                      IconButton(
                        tooltip: u.isActive ? 'Disable User' : 'Enable User',
                        icon: Icon(
                          u.isActive ? Icons.block : Icons.check_circle,
                          color: u.isActive ? Colors.red : Colors.green,
                        ),
                        onPressed: () async {
                          await userCtrl.toggleStatus(u.id);
                          await _loadUsers();
                        },
                      ),
                      IconButton(
                        tooltip: 'View Details',
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => _viewDetails(u),
                      ),
                    ],
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// ================= CREATE USER =================

  void _openCreateUser() {
    final formKey = GlobalKey<FormState>();
    final username = TextEditingController();
    final name = TextEditingController();
    final mobile = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    final otpCtrl = TextEditingController();
    String role = 'STORE';

    bool isEmailVerified = false;
    bool isOtpSent = false;
    bool isLoading = false;
    bool obscurePass = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> sendOtp() async {
              if (email.text.trim().isEmpty || !email.text.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Enter a valid email first'),
                    backgroundColor: Colors.red));
                return;
              }
              setDialogState(() => isLoading = true);
              try {
                await outletCtrl.sendSetupOtp(email.text.trim());
                setDialogState(() => isOtpSent = true);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('OTP Sent!'), backgroundColor: Colors.blue));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString().replaceAll("Exception: ", "")),
                    backgroundColor: Colors.red));
              } finally {
                setDialogState(() => isLoading = false);
              }
            }

            Future<void> verifyOtp() async {
              if (otpCtrl.text.trim().isEmpty) return;
              setDialogState(() => isLoading = true);
              try {
                await outletCtrl.verifySetupOtp(
                    email.text.trim(), otpCtrl.text.trim());
                setDialogState(() {
                  isEmailVerified = true;
                  isOtpSent = false;
                });
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Email Verified!'),
                    backgroundColor: Colors.green));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString().replaceAll("Exception: ", "")),
                    backgroundColor: Colors.red));
              } finally {
                setDialogState(() => isLoading = false);
              }
            }

            return AlertDialog(
              title: const Text('Create User'),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                            controller: username,
                            decoration: const InputDecoration(
                                labelText: 'Username *',
                                border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? 'Required' : null),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: name,
                            decoration: const InputDecoration(
                                labelText: 'Full Name *',
                                border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? 'Required' : null),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: mobile,
                            decoration: const InputDecoration(
                                labelText: 'Mobile',
                                border: OutlineInputBorder())),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: role,
                          decoration: const InputDecoration(
                              labelText: 'Role', border: OutlineInputBorder()),
                          items: ['ADMIN', 'STORE', 'ACCOUNTS']
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => role = v!,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: password,
                          obscureText: obscurePass,
                          decoration: InputDecoration(
                            labelText: 'Password *',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                                icon: Icon(obscurePass
                                    ? Icons.visibility
                                    : Icons.visibility_off),
                                onPressed: () => setDialogState(
                                    () => obscurePass = !obscurePass)),
                          ),
                          validator: (v) =>
                              v!.length < 4 ? 'Min 4 chars' : null,
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),

                        // --- EMAIL VERIFICATION UI ---
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: email,
                                readOnly: isEmailVerified, // Lock if verified
                                decoration: InputDecoration(
                                    labelText: 'Email *',
                                    border: const OutlineInputBorder(),
                                    filled: isEmailVerified,
                                    fillColor: isEmailVerified
                                        ? Colors.grey.shade200
                                        : null),
                                validator: (v) => v!.isEmpty || !v.contains('@')
                                    ? 'Valid email required'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!isEmailVerified)
                              Expanded(
                                flex: 1,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: FilledButton.tonal(
                                      onPressed: isLoading || isOtpSent
                                          ? null
                                          : sendOtp,
                                      child: Text(
                                          isOtpSent ? 'Sent' : 'Send OTP')),
                                ),
                              )
                            else
                              const Padding(
                                  padding:
                                      EdgeInsets.only(top: 10.0, right: 8.0),
                                  child: Icon(Icons.check_circle,
                                      color: Colors.green, size: 32)),
                          ],
                        ),
                        if (isOtpSent && !isEmailVerified) ...[
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                      controller: otpCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                          labelText: '6-Digit OTP',
                                          border: OutlineInputBorder()))),
                              const SizedBox(width: 8),
                              Expanded(
                                  flex: 1,
                                  child: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: FilledButton(
                                          onPressed:
                                              isLoading ? null : verifyOtp,
                                          style: FilledButton.styleFrom(
                                              backgroundColor: Colors.green),
                                          child: const Text('Verify')))),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                  // DISABLE button if email is not verified
                  onPressed: isLoading || !isEmailVerified
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isLoading = true);
                          try {
                            await userCtrl.create(
                              username: username.text,
                              fullName: name.text,
                              mobile: mobile.text,
                              contact_email: email.text,
                              role: role,
                              password: password.text,
                            );
                            await _loadUsers();
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('User created'),
                                    backgroundColor: Colors.green));
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: Colors.red));
                          } finally {
                            setDialogState(() => isLoading = false);
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Create User'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// ================= PERMISSIONS =================

  Future<void> _openPermissions(AppUser u) async {
    final perms = await userCtrl.getPermissions(u.id);
    u.permissions = Set.from(perms);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Permissions - ${u.username}'),
              content: SizedBox(
                width: 400,
                child: ListView(
                  shrinkWrap: true,
                  children: allPermissions.map((p) {
                    final checked = u.permissions.contains('ALL') ||
                        u.permissions.contains(p.key);

                    return CheckboxListTile(
                      title: Text(p.label),
                      subtitle: Text(p.key),
                      value: checked,
                      onChanged: (v) {
                        setDialogState(() {
                          // ✅ correct setState
                          if (v == true) {
                            u.permissions.add(p.key);
                            u.permissions
                                .remove('ALL'); // remove ALL if manual select
                          } else {
                            u.permissions.remove(p.key);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () async {
                    await userCtrl.updatePermissions(u.id, u.permissions);
                    final freshPerms = await userCtrl.getPermissions(u.id);
                    u.permissions = freshPerms;

                    Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openEditUser(AppUser u) {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: u.fullName);
    final mobile = TextEditingController(text: u.mobile);
    final email = TextEditingController(text: u.email);
    final otpCtrl = TextEditingController();
    String role = u.role;

    String originalEmail = u.email ?? '';

    bool isEmailVerified = originalEmail.isNotEmpty;
    bool isOtpSent = false;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> sendOtp() async {
              if (email.text.trim().isEmpty || !email.text.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Enter a valid email first'),
                    backgroundColor: Colors.red));
                return;
              }
              setDialogState(() => isLoading = true);
              try {
                await outletCtrl.sendSetupOtp(email.text.trim());
                setDialogState(() => isOtpSent = true);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('OTP Sent!'), backgroundColor: Colors.blue));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString().replaceAll("Exception: ", "")),
                    backgroundColor: Colors.red));
              } finally {
                setDialogState(() => isLoading = false);
              }
            }

            Future<void> verifyOtp() async {
              if (otpCtrl.text.trim().isEmpty) return;
              setDialogState(() => isLoading = true);
              try {
                await outletCtrl.verifySetupOtp(
                    email.text.trim(), otpCtrl.text.trim());
                setDialogState(() {
                  isEmailVerified = true;
                  isOtpSent = false;
                  originalEmail = email.text.trim();
                });
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Email Verified!'),
                    backgroundColor: Colors.green));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString().replaceAll("Exception: ", "")),
                    backgroundColor: Colors.red));
              } finally {
                setDialogState(() => isLoading = false);
              }
            }

            return AlertDialog(
              title: Text('Edit User: ${u.username}'),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                            controller: name,
                            decoration: const InputDecoration(
                                labelText: 'Full Name *',
                                border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? 'Required' : null),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: mobile,
                            decoration: const InputDecoration(
                                labelText: 'Mobile',
                                border: OutlineInputBorder())),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: role,
                          decoration: const InputDecoration(
                              labelText: 'Role', border: OutlineInputBorder()),
                          items: ['ADMIN', 'STORE', 'ACCOUNTS']
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => role = v!,
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: email,
                                decoration: const InputDecoration(
                                    labelText: 'Email *',
                                    border: OutlineInputBorder()),
                                validator: (v) => v!.isEmpty || !v.contains('@')
                                    ? 'Valid email required'
                                    : null,
                                onChanged: (val) {
                                  // If they type the original email, it stays verified. If they change it, require OTP.
                                  if (val.trim() == originalEmail) {
                                    setDialogState(() {
                                      isEmailVerified = true;
                                      isOtpSent = false;
                                    });
                                  } else {
                                    setDialogState(() {
                                      isEmailVerified = false;
                                      isOtpSent = false;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!isEmailVerified)
                              Expanded(
                                flex: 1,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: FilledButton.tonal(
                                      onPressed: isLoading || isOtpSent
                                          ? null
                                          : sendOtp,
                                      child:
                                          Text(isOtpSent ? 'Sent' : 'Verify')),
                                ),
                              )
                            else
                              const Padding(
                                  padding:
                                      EdgeInsets.only(top: 10.0, right: 8.0),
                                  child: Icon(Icons.check_circle,
                                      color: Colors.green, size: 32)),
                          ],
                        ),
                        if (isOtpSent && !isEmailVerified) ...[
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                      controller: otpCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                          labelText: '6-Digit OTP',
                                          border: OutlineInputBorder()))),
                              const SizedBox(width: 8),
                              Expanded(
                                  flex: 1,
                                  child: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: FilledButton(
                                          onPressed:
                                              isLoading ? null : verifyOtp,
                                          style: FilledButton.styleFrom(
                                              backgroundColor: Colors.green),
                                          child: const Text('Verify')))),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                  onPressed: isLoading || !isEmailVerified
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isLoading = true);
                          try {
                            await userCtrl.update(
                              u.id,
                              fullName: name.text,
                              mobile: mobile.text,
                              contact_email: email.text,
                              role: role,
                            );
                            await _loadUsers();
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('User updated'),
                                    backgroundColor: Colors.green));
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: Colors.red));
                          } finally {
                            setDialogState(() => isLoading = false);
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Update User'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// ================= RESET PASSWORD =================
  void _changePassword(AppUser u) {
    final oldPass = TextEditingController();
    final newPass = TextEditingController();
    final confirm = TextEditingController();

    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text('Change Password - ${u.username}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// OLD PASSWORD
                  TextField(
                    controller: oldPass,
                    obscureText: obscureOld,
                    decoration: InputDecoration(
                      labelText: 'Old Password',
                      suffixIcon: IconButton(
                        icon: Icon(obscureOld
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => obscureOld = !obscureOld),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// NEW PASSWORD
                  TextField(
                    controller: newPass,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// CONFIRM PASSWORD
                  TextField(
                    controller: confirm,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (newPass.text != confirm.text) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Passwords do not match')),
                            );
                            return;
                          }

                          setState(() => loading = true);

                          try {
                            await userCtrl.changePassword(
                                u.username, oldPass.text, newPass.text);

                            if (!context.mounted) return;

                            Navigator.pop(ctx);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password updated')),
                            );
                          } catch (e) {
                            setState(() => loading = false);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _resetPassword(AppUser u) {
    final newPass = TextEditingController();
    final confirm = TextEditingController();

    bool obscure1 = true;
    bool obscure2 = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text('Reset Password - ${u.username}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: newPass,
                    obscureText: obscure1,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscure1 ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => obscure1 = !obscure1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirm,
                    obscureText: obscure2,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscure2 ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => obscure2 = !obscure2),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (newPass.text != confirm.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Passwords do not match')),
                      );
                      return;
                    }

                    await userCtrl.resetPassword(
                      u.id,
                      newPass.text,
                    );

                    Navigator.pop(ctx);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Password reset for ${u.username}'),
                      ),
                    );
                  },
                  child: const Text('Reset'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// ================= DETAILS =================

  void _viewDetails(AppUser u) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('User Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _info('Username', u.username),
            _info('Name', u.fullName),
            _info('Role', u.role),
            _info('Mobile', u.mobile),
            _info('Mobile', u.email),
            _info('Status', u.isActive ? 'ACTIVE' : 'INACTIVE'),
            _info(
                'Permissions',
                u.permissions.contains('ALL')
                    ? 'ALL'
                    : u.permissions.join(', ')),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _info(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(l), Text(v)],
        ),
      );
}


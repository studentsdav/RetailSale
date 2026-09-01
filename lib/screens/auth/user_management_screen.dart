import 'package:flutter/material.dart';
import 'package:retailpos/controllers/security/user_controller.dart';

import '../../controllers/public/outlet_controller.dart' show OutletController;
import '../../models/security/app_user_model.dart';
import '../../core/permissions/module_capability.dart';
import '../../core/auth/token_storage.dart';
import '../../core/config/app_constants.dart';

/// ================= SCREEN =================
class Permission1 {
  String key;
  String label;
  Permission1(this.key, this.label);
}

class PermissionGroup {
  final String categoryName;
  final List<Permission1> items;
  PermissionGroup(this.categoryName, this.items);
}

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _search = TextEditingController();
  final UserController userCtrl = UserController();
  final _horizontalScrollController = ScrollController();
  final password = TextEditingController();
  List<AppUser> users = [];
  final outletCtrl = OutletController();

  /// -------- ALL PERMISSIONS GROUPED BY CATEGORY --------
  final List<PermissionGroup> permissionGroups = [
    PermissionGroup('Inventory & Stock', [
      Permission1('ITEM_REQUEST', 'Item Request'),
      Permission1('PURCHASE_ORDER', 'Purchase Order'),
      Permission1('STOCK_IN', 'Receive from Vendor (GRN)'),
      Permission1('STOCK_OUT', 'Stock Dispatch'),
      Permission1('STOCK_TRANSFER', 'Stock Transfer'),
      Permission1('PRODUCT_ASSEMBLY', 'Product Assembly / Recipe'),
      Permission1('RETURN', 'Department Return (Main Key)'),
      Permission1('RETURN_ISSUE', 'Return Department Items'),
      Permission1('SUPPLIER_RETURN', 'Return Purchase to Vendor'),
      Permission1('DAMAGE', 'Damage Items Entry'),
      Permission1('ITEM_MASTER', 'Item Master / Products'),
      Permission1('SUPPLIER_MASTER', 'Vendor Master'),
      Permission1('STOCK_LOCATION', 'Stock Location / Department'),
      Permission1('SUBMISSIONS_STATUS', 'My Submissions Status'),
      Permission1('ITEM_BARCODE_MANAGER', 'Item Barcode & Label Manager'),
      Permission1('APPROVAL_CENTER', 'Document Approval Center'),
    ]),
    PermissionGroup('Retail Sales & POS', [
      Permission1('RETAIL_SALES', 'Retail Sales (POS Billing)'),
      Permission1('ENTERPRISE_POS', 'Enterprise POS Terminal'),
      Permission1('REPRINT_SALES_BILL', 'Reprint Sales Bill'),
      Permission1('MODIFY_SALES_BILL', 'Modify Sales Bill'),
      Permission1('MODIFY_SALES_PAYMENT', 'Modify Sales Payment'),
      Permission1('CUSTOMER_LIST', 'Customer Master & Directory'),
      Permission1('ADD_CUSTOMER', 'Add New Customer'),
      Permission1('DRAFT_BILLS', 'Draft Bills & Saved Carts'),
      Permission1('POS_SUBSCRIPTIONS', 'Subscription Deliveries & Orders'),
      Permission1('SCHEME_MANAGEMENT', 'Create & Manage POS Schemes'),
      Permission1('CUSTOMER_APP', 'Customer App (Delivery)'),
      Permission1('RETAILER_CONSOLE', 'Supplier / Retailer Console'),
      Permission1('RIDER_PORTAL', 'Rider Delivery Portal'),
    ]),
    PermissionGroup('Accounts & Finance', [
      Permission1('SUPPLIER_PAYMENT', 'Vendor Payment'),
      Permission1('SUPPLIER_RETURN_REFUND', 'Vendor Return Refund'),
      Permission1('PENDING_REFUNDS', 'Pending Refunds View'),
      Permission1('CASH_LEDGER', 'Finance & Reports (Cash Ledger)'),
      Permission1('FINANCE_HUB', 'Finance & Accounting Hub (COA / P&L / Banks)'),
      Permission1('ACCOUNTING_VOUCHERS', 'Accounting Vouchers (F4-F9)'),
      Permission1('BANK_ACCOUNTS', 'Company Bank Accounts Master'),
      Permission1('LOAN_EMI', 'Loan & EMI Management'),
      Permission1('CREDIT_ANALYSIS', 'Credit Ledger & Customer Accounts'),
      Permission1('EXPENSE_ANALYTICS', 'Expense Analytics & Cost Control'),
      Permission1('HR_PAYROLL', 'Payroll Processing'),
      Permission1('RETAIL_SALES_REPORT', 'Retail Sales Report'),
      Permission1('CLOSING_REPORT', 'Closing Report'),
      Permission1('CASHIER_HANDOVER', 'Cashier Shift Handover Report'),
      Permission1('NIGHT_AUDIT', 'Night Audit Report (EOD)'),
      Permission1('STOCK_LEDGER_REPORT', 'Stock Ledger Report'),
      Permission1('VENDOR_PAYMENT_REPORT', 'Vendor Payment Report'),
      Permission1('PURCHASE_REPORT', 'Vendor Purchase Order Report'),
      Permission1('RETURN_REPORT', 'Return Report'),
      Permission1('REQUEST_REPORT', 'Request Report'),
      Permission1('DAMAGE_REPORT', 'Damage Report'),
    ]),
    PermissionGroup('Modify Documents', [
      Permission1('MODIFY_REQUEST', 'Modify Request'),
      Permission1('MODIFY_PURCHASE', 'Modify Purchase Order'),
      Permission1('MODIFY_RECEIVING', 'Modify Receiving'),
      Permission1('MODIFY_ISSUE', 'Modify Stock Dispatch'),
      Permission1('REPRINT_REQUEST', 'Reprint Request'),
      Permission1('REPRINT_PURCHASE', 'Reprint Purchase Order'),
      Permission1('REPRINT_RECEIVING', 'Reprint Receiving'),
      Permission1('REPRINT_ISSUE', 'Reprint Stock Dispatch'),
    ]),
    PermissionGroup('HR & Attendance', [
      Permission1('HR_EMPLOYEES', 'Employee Directory'),
      Permission1('HR_ATTENDANCE', 'Attendance & Leaves'),
      Permission1('HR_MASTERS', 'HR Masters & Scales'),
      Permission1('PAY_SCHEDULE', 'Pay Schedule & Shift Timing'),
    ]),
    PermissionGroup('Restaurant & Dining', [
      Permission1('RESTAURANT_CONSOLE', 'Captain Console'),
      Permission1('RESTAURANT_FLOOR_DESIGN', 'Floor Designer'),
      Permission1('RESTAURANT_KDS', 'Kitchen KDS Queue'),
      Permission1('RESTAURANT_SETUP', 'Restaurant Setup'),
      Permission1('RESTAURANT_ANALYTICS', 'Restaurant Analytics & Reports'),
      Permission1('DELIVERY_CHALLANS', 'Delivery Challans'),
      Permission1('RECURRING_EXPENSES', 'Recurring Expenses'),
      Permission1('TABLE_RESERVATIONS', 'Table Reservations'),
      Permission1('RUNNING_ORDERS', 'Running Orders Monitor'),
      Permission1('KOTS_HISTORY', 'KOT History Log'),
    ]),
    PermissionGroup('Marketing & Campaigns', [
      Permission1('WHATSAPP_INTEGRATION', 'WhatsApp Dashboard & Automation'),
      Permission1('LUCKY_DRAW', 'Lucky Draw Campaigns'),
      Permission1('PROMO_VOUCHERS', 'Bill Value Promos & Vouchers'),
      Permission1('HAPPY_HOUR', 'Happy Hour Pricing Rules'),
      Permission1('COMMISSION_RULES', 'Commission Rules & Sales Reps'),
      Permission1('SCHEME_REPORT', 'Scheme Report'),
      Permission1('SCHEME_ANALYSIS', 'Scheme Analysis'),
      Permission1('SUBSCRIPTION_REPORT', 'Subscription Report'),
      Permission1('LOYALTY_PROGRAM', 'Loyalty Program Setup'),
      Permission1('LOYALTY_REPORT', 'Loyalty Report'),
      Permission1('STORE_ANALYSIS', 'Store Analysis'),
      Permission1('BRAND_ANALYSIS', 'Brand Analysis'),
      Permission1('SOURCE_ANALYSIS', 'Sale Source Analysis'),
    ]),
    PermissionGroup('Reports & Intelligence', [
      Permission1('STOCK_BALANCE', 'Stock Balance'),
      Permission1('ITEM_ADVANCE_REPORT', 'Item Advance & Batch Movement'),
      Permission1('OPERATIONS_INTELLIGENCE', 'Operations Intelligence'),
      Permission1('DAMAGE_SUMMARY', 'Damage Summary Report'),
      Permission1('STOCK_IN_REPORT', 'Receiving Report'),
      Permission1('STOCK_OUT_REPORT', 'Stock Dispatch Report'),
      Permission1('STOCK_TRANSFER_REPORT', 'Stock Transfer Report'),
      Permission1('COMMISSION_REPORT', 'Commission Report'),
      Permission1('PAYMENT_ANALYSIS', 'Payment Method Analysis'),
      Permission1('AI_QUERY_ANALYTICS', 'AI Query Analytics'),
      Permission1('LYNX_TESTING', 'LYNX Feature Testing Hub'),
      Permission1('AUTONOMOUS_AGENT', 'Autonomous AI Agent'),
    ]),
    PermissionGroup('Settings & Customizer', [
      Permission1('PROPERTY_INFORMATION', 'Property Information'),
      Permission1('NUMBERING_SETTINGS', 'Document Sequence Settings'),
      Permission1('SETTINGS', 'System Settings & Customizer'),
      Permission1('SYSTEM_UPDATE', 'System Update & Versioning'),
      Permission1('SMTP_SETTINGS', 'SMTP & Email Configuration'),
      Permission1('WORKFLOW_AUTOMATION', 'Workflow Automation Rules'),
      Permission1('DEVELOPER_ECOSYSTEM', 'Developer REST APIs & Webhooks'),
      Permission1('PLUGIN_MARKETPLACE', 'Add-on Plugin Marketplace'),
      Permission1('USER_MANAGEMENT', 'User Management & Roles'),
    ]),
  ];

  String _userBusinessModule = 'ALL';

  List<PermissionGroup> get filteredPermissionGroups {
    return permissionGroups.where((group) {
      if (group.categoryName == 'Retail Sales' &&
          !ModuleCapability.hasRetail(_userBusinessModule)) {
        return false;
      }
      if (group.categoryName == 'Restaurant (Beta)' &&
          !ModuleCapability.hasRestaurant(_userBusinessModule)) {
        return false;
      }
      return true;
    }).map((group) {
      final filteredItems = group.items
          .where((p) =>
              ModuleCapability.isPermissionAllowed(p.key, _userBusinessModule))
          .toList();
      return PermissionGroup(group.categoryName, filteredItems);
    }).where((group) => group.items.isNotEmpty).toList();
  }

  List<Permission1> get allPermissions {
    final list = <Permission1>[];
    for (final gp in filteredPermissionGroups) {
      list.addAll(gp.items);
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _loadActiveModule();
    _loadUsers();
  }

  Future<void> _loadActiveModule() async {
    final userMap = await TokenStorage.getUser();
    final mod = userMap?['business_module'] ?? userMap?['outlet_module'] ?? 'ALL';
    if (!mounted) return;
    setState(() => _userBusinessModule = mod);
  }

  @override
  void dispose() {
    _search.dispose();
    password.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
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
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFF7A1A)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.shield_outlined, color: Color(0xFFFF7A1A)),
            label: const Text('Supervisor PIN', style: TextStyle(color: Color(0xFFFF7A1A), fontWeight: FontWeight.bold)),
            onPressed: _openSupervisorPinDialog,
          ),
          const SizedBox(width: 8),
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
        child: Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
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
                DataColumn(label: Text('Max Disc %')),
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
                    DataCell(Text('${u.maxDiscountPercent.toStringAsFixed(0)}%')),
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
      ),
    );
  }

  /// ================= SUPERVISOR PIN SETUP =================
  void _openSupervisorPinDialog() async {
    final pinCtrl = TextEditingController();
    String pinType = 'STATIC';
    bool obscurePin = true;
    bool isLoading = true;
    String? statusMsg;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            if (isLoading) {
              userCtrl.getSupervisorPin().then((data) {
                if (ctx.mounted) {
                  setDialogState(() {
                    pinCtrl.text = data['pin'] ?? '1234';
                    pinType = data['type'] ?? 'STATIC';
                    isLoading = false;
                  });
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFFFF7A1A)),
                  SizedBox(width: 8),
                  Text('Supervisor Override Setup'),
                ],
              ),
              content: isLoading
                  ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Configure the security override PIN or One-Time Passcode (OTP) required for supervisor authorizations (e.g. order voids, bill discounts).',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 16),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'STATIC', label: Text('Reusable Store PIN'), icon: Icon(Icons.pin)),
                              ButtonSegment(value: 'ONE_TIME', label: Text('One-Time Email OTP'), icon: Icon(Icons.mark_email_unread)),
                            ],
                            selected: {pinType},
                            onSelectionChanged: (val) => setDialogState(() => pinType = val.first),
                          ),
                          const SizedBox(height: 16),
                          if (pinType == 'STATIC') ...[
                            TextField(
                              controller: pinCtrl,
                              obscureText: obscurePin,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Store Supervisor Override PIN',
                                hintText: 'e.g. 1234 or 8888',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.key),
                                suffixIcon: IconButton(
                                  icon: Icon(obscurePin ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setDialogState(() => obscurePin = !obscurePin),
                                ),
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.amber, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'When requesting supervisor override, a 6-digit OTP will be dispatched to the store contact email.',
                                      style: TextStyle(fontSize: 12, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (statusMsg != null) ...[
                            const SizedBox(height: 10),
                            Text(statusMsg!, style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A1A),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text('Save PIN Settings'),
                  onPressed: () async {
                    final targetPin = pinType == 'ONE_TIME'
                        ? (pinCtrl.text.trim().isEmpty ? '1234' : pinCtrl.text.trim())
                        : pinCtrl.text.trim();

                    if (pinType == 'STATIC' && targetPin.isEmpty) {
                      setDialogState(() {
                        statusMsg = 'Please enter a valid Supervisor PIN (e.g. 1234)';
                      });
                      return;
                    }

                    setDialogState(() => isLoading = true);
                    try {
                      await userCtrl.updateSupervisorPin(targetPin, pinType);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(pinType == 'ONE_TIME'
                                ? 'Supervisor One-Time Email OTP mode saved successfully!'
                                : 'Supervisor Override PIN saved successfully!'),
                            backgroundColor: Colors.teal,
                          ),
                        );
                      }
                    } catch (e) {
                      setDialogState(() {
                        isLoading = false;
                        statusMsg = 'Error saving PIN: ${e.toString().replaceAll("Exception: ", "")}';
                      });
                    }
                  },
                ),
              ],
            );
          },
        );
      },
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
    final maxDiscount = TextEditingController(text: '100');
    final otpCtrl = TextEditingController();
    String role = 'STORE';

    bool isEmailVerified = false;
    bool isOtpSent = false;
    bool isLoading = false;
    bool obscurePass = true;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> sendOtp() async {
              if (email.text.trim().isEmpty || !email.text.contains('@')) {
                setDialogState(() => dialogError = 'Enter a valid email address first');
                return;
              }
              setDialogState(() {
                isLoading = true;
                dialogError = null;
              });
              try {
                await outletCtrl.sendSetupOtp(email.text.trim());
                setDialogState(() => isOtpSent = true);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('OTP Sent!'), backgroundColor: Colors.blue));
              } catch (e) {
                final cleanErr = e.toString().replaceAll("Exception: ", "").replaceAll("Exception", "").trim();
                setDialogState(() => dialogError = cleanErr);
              } finally {
                setDialogState(() => isLoading = false);
              }
            }

            Future<void> verifyOtp() async {
              if (otpCtrl.text.trim().isEmpty) return;
              setDialogState(() {
                isLoading = true;
                dialogError = null;
              });
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
                final cleanErr = e.toString().replaceAll("Exception: ", "").replaceAll("Exception", "").trim();
                setDialogState(() => dialogError = cleanErr);
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
                        if (dialogError != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    dialogError!,
                                    style: TextStyle(color: Colors.red.shade900, fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                          initialValue: AppConstants.getRolesForModule(_userBusinessModule).contains(role)
                              ? role
                              : AppConstants.getRolesForModule(_userBusinessModule).first,
                          decoration: const InputDecoration(
                              labelText: 'Role', border: OutlineInputBorder()),
                          items: (() {
                            final validRoles = AppConstants.getRolesForModule(_userBusinessModule);
                            final list = validRoles.contains(role) ? validRoles : [...validRoles, role];
                            return list
                                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                .toList();
                          })(),
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
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: maxDiscount,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max Manual Discount (%)',
                            border: OutlineInputBorder(),
                            suffixText: '%',
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            final val = double.tryParse(v);
                            if (val == null || val < 0 || val > 100) {
                              return 'Enter 0 - 100%';
                            }
                            return null;
                          },
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
                              maxDiscountPercent: double.tryParse(maxDiscount.text.trim()) ?? 100.0,
                              permissions: AppConstants.getDefaultPermissionsForRole(role, _userBusinessModule),
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
                            final cleanErr = e.toString().replaceAll("Exception: ", "").replaceAll("Exception", "").trim();
                            setDialogState(() => dialogError = cleanErr);
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
    if (perms.isEmpty) {
      u.permissions = Set.from(AppConstants.getDefaultPermissionsForRole(u.role, _userBusinessModule));
    } else {
      u.permissions = Set.from(perms);
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Permissions - ${u.username}'),
              content: SizedBox(
                width: 450,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ...() {
                      final widgets = <Widget>[];
                      for (final group in filteredPermissionGroups) {
                        final hasAll = group.items.every((p) => u.permissions.contains(p.key));
                        final hasNone = group.items.every((p) => !u.permissions.contains(p.key));
                        
                        bool? groupChecked;
                        if (hasAll) {
                          groupChecked = true;
                        } else if (hasNone) {
                          groupChecked = false;
                        } else {
                          groupChecked = null;
                        }

                        widgets.add(
                          Container(
                            color: const Color(0xFFF3F4F6),
                            margin: const EdgeInsets.only(top: 12, bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  group.categoryName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Checkbox(
                                  value: groupChecked,
                                  tristate: true,
                                  onChanged: (v) {
                                    setDialogState(() {
                                      if (groupChecked == true || groupChecked == null) {
                                        for (final p in group.items) {
                                          u.permissions.remove(p.key);
                                        }
                                      } else {
                                        for (final p in group.items) {
                                          u.permissions.add(p.key);
                                        }
                                        u.permissions.remove('ALL');
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );

                        for (final p in group.items) {
                          final checked = u.permissions.contains('ALL') || u.permissions.contains(p.key);
                          widgets.add(
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: CheckboxListTile(
                                title: Text(p.label, style: const TextStyle(fontSize: 13)),
                                subtitle: Text(p.key, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                value: checked,
                                dense: true,
                                controlAffinity: ListTileControlAffinity.trailing,
                                onChanged: (v) {
                                  setDialogState(() {
                                    if (v == true) {
                                      u.permissions.add(p.key);
                                      u.permissions.remove('ALL');
                                    } else {
                                      u.permissions.remove(p.key);
                                    }
                                  });
                                },
                              ),
                            ),
                          );
                        }
                      }
                      return widgets;
                    }()
                  ],
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
    final maxDiscount = TextEditingController(text: u.maxDiscountPercent.toStringAsFixed(0));
    final otpCtrl = TextEditingController();
    String role = u.role;

    String originalEmail = u.email;

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
                          initialValue: AppConstants.getRolesForModule(_userBusinessModule).contains(role)
                              ? role
                              : AppConstants.getRolesForModule(_userBusinessModule).first,
                          decoration: const InputDecoration(
                              labelText: 'Role', border: OutlineInputBorder()),
                          items: (() {
                            final validRoles = AppConstants.getRolesForModule(_userBusinessModule);
                            final list = validRoles.contains(role) ? validRoles : [...validRoles, role];
                            return list
                                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                .toList();
                          })(),
                          onChanged: (v) => role = v!,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: maxDiscount,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max Manual Discount (%)',
                            border: OutlineInputBorder(),
                            suffixText: '%',
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            final val = double.tryParse(v);
                            if (val == null || val < 0 || val > 100) {
                              return 'Enter 0 - 100%';
                            }
                            return null;
                          },
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
                              maxDiscountPercent: double.tryParse(maxDiscount.text.trim()) ?? u.maxDiscountPercent,
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
                                content: Text(e.toString().replaceAll("Exception: ", "")),
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


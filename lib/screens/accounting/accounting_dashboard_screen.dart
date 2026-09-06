import 'package:flutter/material.dart';
import 'bank_accounts_screen.dart';
import 'chart_of_accounts_screen.dart';
import 'loan_emi_screen.dart';
import 'accounting_vouchers_screen.dart';
import 'trial_balance_screen.dart';
import 'profit_loss_screen.dart';
import 'balance_sheet_screen.dart';

import '../../controllers/inventory/stock_transfer_controller.dart';

class AccountingDashboardScreen extends StatefulWidget {
  const AccountingDashboardScreen({super.key});

  @override
  State<AccountingDashboardScreen> createState() => _AccountingDashboardScreenState();
}

class _AccountingDashboardScreenState extends State<AccountingDashboardScreen> {
  final StockTransferController _transferCtrl = StockTransferController();

  int? _selectedOutletId; // null means ALL combined
  List<dynamic> _allOutlets = [];
  bool _isLoadingOutlets = true;

  @override
  void initState() {
    super.initState();
    _loadOutlets();
  }

  Future<void> _loadOutlets() async {
    final hierarchy = await _transferCtrl.fetchHierarchy();
    if (mounted) {
      setState(() {
        _isLoadingOutlets = false;
        if (hierarchy != null) {
          final current = hierarchy['current_outlet'];
          final children = (hierarchy['child_outlets'] as List?) ?? [];
          final list = <dynamic>[];
          if (current != null) list.add(current);
          list.addAll(children);
          _allOutlets = list;
          if (_selectedOutletId == null && current != null && current['id'] != null) {
            _selectedOutletId = current['id'];
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0B5CAD);
    const tealColor = Color(0xFF0F766E);
    const bgColor = Color(0xFFF4F6F9);

    final selectedOutlet = _allOutlets.firstWhere(
      (o) => o['id'] == _selectedOutletId,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: primaryColor),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'RetailSale Enterprise Accounting Section',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'BETA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Company Bank Masters, Double-Entry Vouchers & Financial Statements',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Accounting Outlet Scope Filter Bar
              if (_allOutlets.length > 1) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_outlined, color: primaryColor),
                        const SizedBox(width: 12),
                        const Text(
                          'Accounting Scope:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              isExpanded: true,
                              value: _selectedOutletId,
                              hint: const Text('All Linked Outlets (Combined Accounting)'),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('🌐 All Outlets (Combined Enterprise Accounting)', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                ..._allOutlets.map<DropdownMenuItem<int?>>((outlet) {
                                  return DropdownMenuItem<int?>(
                                    value: outlet['id'],
                                    child: Text('🏬 ${outlet['outlet_name']} (${outlet['outlet_code']})'),
                                  );
                                }).toList(),
                              ],
                              onChanged: (val) {
                                setState(() => _selectedOutletId = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Welcome Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withOpacity(0.85)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            selectedOutlet == null
                                ? 'SCOPE: ALL LINKED OUTLETS (COMBINED)'
                                : 'SCOPE: ${selectedOutlet['outlet_name'].toString().toUpperCase()}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      selectedOutlet == null
                          ? 'Combined Financial Ledger & Enterprise Accounting'
                          : '${selectedOutlet['outlet_name']} Financial Ledger',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage Bank Masters, Double-Entry Vouchers, Trial Balance, P&L, and Balance Sheet seamlessly.',
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 1: Accounting Masters
              const Text('ACCOUNTING MASTERS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTile(
                      context,
                      title: 'Bank Accounts Master',
                      subtitle: 'Configure company bank accounts (HDFC, SBI, ICICI) & track live balances',
                      icon: Icons.account_balance,
                      color: primaryColor,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BankAccountsScreen(outletId: _selectedOutletId?.toString() ?? 'ALL'))),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTile(
                      context,
                      title: 'Chart of Accounts (COA)',
                      subtitle: 'View double-entry ledger accounts hierarchy and opening balances',
                      icon: Icons.account_tree,
                      color: tealColor,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChartOfAccountsScreen(outletId: _selectedOutletId?.toString() ?? 'ALL'))),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTile(
                      context,
                      title: 'Loans, Assets & EMI Master',
                      subtitle: 'Manage loans, capital asset investments, and auto-debit EMI schedules',
                      icon: Icons.domain,
                      color: Colors.indigo,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoanEmiScreen(outletId: _selectedOutletId?.toString() ?? 'ALL'))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section 2: Vouchers System
              const Text('ACCOUNTING VOUCHERS SYSTEM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              _buildTile(
                context,
                title: 'Accounting Voucher Hub (Contra, Payment, Receipt, Journal)',
                subtitle: 'Pass double-entry cash/bank vouchers with zero-difference balance validator and instant key shortcuts.',
                icon: Icons.receipt_long,
                color: const Color(0xFF0B5CAD),
                isFullWidth: true,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountingVouchersScreen(outletId: _selectedOutletId?.toString() ?? 'ALL'))),
              ),
              const SizedBox(height: 24),

              // Section 3: Financial Statements & Reports
              const Text('FINANCIAL STATEMENTS & REPORTS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTile(
                      context,
                      title: 'Trial Balance Report',
                      subtitle: 'Verify double-entry arithmetic accuracy across all debit & credit ledgers',
                      icon: Icons.balance,
                      color: Colors.indigo,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrialBalanceScreen(outletId: _selectedOutletId?.toString() ?? 'ALL'))),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTile(
                      context,
                      title: 'Profit & Loss Statement (P&L)',
                      subtitle: 'Real-time Trading revenue, Cost of Goods Sold, and Net Income statement',
                      icon: Icons.show_chart,
                      color: Colors.green.shade800,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfitLossScreen(outletId: _selectedOutletId?.toString() ?? 'ALL'))),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTile(
                      context,
                      title: 'Balance Sheet Statement',
                      subtitle: 'Comprehensive financial position report (Assets = Liabilities + Equity)',
                      icon: Icons.assessment,
                      color: Colors.purple.shade800,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BalanceSheetScreen(outletId: _selectedOutletId?.toString() ?? 'ALL'))),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

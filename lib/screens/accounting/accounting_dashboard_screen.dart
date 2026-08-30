import 'package:flutter/material.dart';
import 'bank_accounts_screen.dart';
import 'chart_of_accounts_screen.dart';
import 'loan_emi_screen.dart';
import 'accounting_vouchers_screen.dart';
import 'trial_balance_screen.dart';
import 'profit_loss_screen.dart';
import 'balance_sheet_screen.dart';

class AccountingDashboardScreen extends StatelessWidget {
  const AccountingDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0B5CAD);
    const tealColor = Color(0xFF0F766E);
    const bgColor = Color(0xFFF4F6F9);

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
                const Text(
                  'RetailSale Enterprise Accounting Section',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
                          child: const Text(
                            'NEW ACCOUNTING MODULE',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Complete Financial Ledger & Accounting Suite',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage Bank Masters, F4-F9 Double-Entry Vouchers, Trial Balance, P&L, and Balance Sheet seamlessly.',
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
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BankAccountsScreen())),
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
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChartOfAccountsScreen())),
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
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoanEmiScreen())),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section 2: Vouchers System (F4 - F9)
              const Text('ACCOUNTING VOUCHERS SYSTEM (F4 - F9)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              _buildTile(
                context,
                title: 'Accounting Voucher Hub (F4 Contra, F5 Payment, F6 Receipt, F7 Journal)',
                subtitle: 'Pass double-entry cash/bank vouchers with zero-difference balance validator and instant F4-F9 key shortcuts.',
                icon: Icons.receipt_long,
                color: const Color(0xFF0B5CAD),
                isFullWidth: true,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountingVouchersScreen())),
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
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrialBalanceScreen())),
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
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfitLossScreen())),
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
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BalanceSheetScreen())),
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

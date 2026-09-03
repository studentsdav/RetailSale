import 'package:flutter/material.dart';
import '../../controllers/accounting/financial_reports_controller.dart';

class ProfitLossScreen extends StatefulWidget {
  const ProfitLossScreen({super.key});

  @override
  State<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends State<ProfitLossScreen> {
  final FinancialReportsController ctrl = FinancialReportsController();

  @override
  void initState() {
    super.initState();
    ctrl.fetchProfitLoss();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0B5CAD);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('Statement of Profit & Loss (P&L)', style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          if (ctrl.loading) return const Center(child: CircularProgressIndicator());

          final data = ctrl.profitLossData;
          final trading = data['tradingAccount'] ?? {};
          final pl = data['profitAndLossAccount'] ?? {};

          final totalRevenue = double.tryParse((trading['totalRevenue'] ?? 0).toString()) ?? 0.0;
          final salesDiscounts = double.tryParse((trading['salesDiscounts'] ?? 0).toString()) ?? 0.0;
          final netSalesRevenue = double.tryParse((trading['netSalesRevenue'] ?? 0).toString()) ?? (totalRevenue - salesDiscounts);

          final openingStock = double.tryParse((trading['openingStock'] ?? 0).toString()) ?? 0.0;
          final purchases = double.tryParse((trading['purchases'] ?? 0).toString()) ?? 0.0;
          final directFreight = double.tryParse((trading['directFreight'] ?? 0).toString()) ?? 0.0;
          final closingStock = double.tryParse((trading['closingStock'] ?? 0).toString()) ?? 0.0;
          final cogs = double.tryParse((trading['costOfGoodsSold'] ?? 0).toString()) ?? 0.0;
          final grossProfit = double.tryParse((trading['grossProfit'] ?? 0).toString()) ?? 0.0;

          final indirectIncome = double.tryParse((pl['indirectIncome'] ?? 0).toString()) ?? 0.0;
          final totalOperatingIncome = double.tryParse((pl['totalOperatingIncome'] ?? 0).toString()) ?? grossProfit;
          final expenses = double.tryParse((pl['operatingExpenses'] ?? 0).toString()) ?? 0.0;
          final expenseBreakdown = pl['expenseBreakdown'] as List? ?? [];
          final netProfit = double.tryParse((pl['netProfit'] ?? 0).toString()) ?? 0.0;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                // PART I: TRADING ACCOUNT
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PART I: TRADING ACCOUNT (Gross Profit Calculation)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor)),
                        const Divider(height: 20),
                        _row('Sales Revenue (Net of GST)', '₹${totalRevenue.toStringAsFixed(2)}', Colors.black87),
                        _row('Less: Sales Returns / Discounts', '(₹${salesDiscounts.toStringAsFixed(2)})', Colors.red.shade700),
                        const Divider(height: 12),
                        _row('NET SALES REVENUE (A)', '₹${netSalesRevenue.toStringAsFixed(2)}', primaryColor, isBold: true),
                        const SizedBox(height: 12),
                        const Text('Cost of Goods Sold (COGS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                        _row('  Opening Stock', '₹${openingStock.toStringAsFixed(2)}', Colors.black54),
                        _row('  Add: Purchases (Net of GST)', '₹${purchases.toStringAsFixed(2)}', Colors.black54),
                        _row('  Add: Direct Freight & Freight Charges', '₹${directFreight.toStringAsFixed(2)}', Colors.black54),
                        _row('  Less: Closing Stock (Unsold Inventory)', '(₹${closingStock.toStringAsFixed(2)})', Colors.green.shade700),
                        _row('TOTAL COST OF GOODS SOLD (B)', '₹${cogs.toStringAsFixed(2)}', Colors.red.shade700, isBold: true),
                        const Divider(),
                        _row('GROSS PROFIT / (LOSS) [ A - B ]', '₹${grossProfit.toStringAsFixed(2)}', grossProfit >= 0 ? Colors.green.shade800 : Colors.red.shade800, isBold: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // PART II: PROFIT & LOSS ACCOUNT
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PART II: PROFIT & LOSS ACCOUNT (Net Income Calculation)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor)),
                        const Divider(height: 20),
                        _row('GROSS PROFIT B/F', '₹${grossProfit.toStringAsFixed(2)}', Colors.black87),
                        _row('Add: Indirect Income (Interest / Discounts Received)', '₹${indirectIncome.toStringAsFixed(2)}', Colors.green.shade700),
                        _row('TOTAL OPERATING INCOME (C)', '₹${totalOperatingIncome.toStringAsFixed(2)}', primaryColor, isBold: true),
                        const SizedBox(height: 12),
                        const Text('Less: Indirect & Operating Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                        if (expenseBreakdown.isEmpty)
                          _row('  General Operating Expenses', '₹${expenses.toStringAsFixed(2)}', Colors.red.shade700)
                        else
                          ...expenseBreakdown.map((e) => _row('  ${e['category'] ?? 'Expense'}', '₹${(double.tryParse((e['amount'] ?? 0).toString()) ?? 0.0).toStringAsFixed(2)}', Colors.red.shade700)),
                        const Divider(height: 12),
                        _row('TOTAL INDIRECT EXPENSES (D)', '₹${expenses.toStringAsFixed(2)}', Colors.red.shade700, isBold: true),
                        const Divider(),
                        _row('NET PROFIT / (LOSS) BEFORE TAX [ C - D ]', '₹${netProfit.toStringAsFixed(2)}', netProfit >= 0 ? Colors.green.shade800 : Colors.red.shade800, isBold: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

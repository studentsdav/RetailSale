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
        title: const Text('Profit & Loss Statement (P&L)', style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
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
          final cogs = double.tryParse((trading['costOfGoodsSold'] ?? 0).toString()) ?? 0.0;
          final grossProfit = double.tryParse((trading['grossProfit'] ?? 0).toString()) ?? 0.0;
          final expenses = double.tryParse((pl['operatingExpenses'] ?? 0).toString()) ?? 0.0;
          final netProfit = double.tryParse((pl['netProfit'] ?? 0).toString()) ?? 0.0;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TRADING ACCOUNT (Gross Profit)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor)),
                        const Divider(height: 20),
                        _row('Total Sales Revenue', '₹${totalRevenue.toStringAsFixed(2)}', Colors.black87),
                        _row('Less: Cost of Goods Sold (Purchases)', '₹${cogs.toStringAsFixed(2)}', Colors.red.shade700),
                        const Divider(),
                        _row('GROSS PROFIT', '₹${grossProfit.toStringAsFixed(2)}', Colors.green.shade800, isBold: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PROFIT & LOSS ACCOUNT (Net Income)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor)),
                        const Divider(height: 20),
                        _row('Gross Profit B/F', '₹${grossProfit.toStringAsFixed(2)}', Colors.black87),
                        _row('Less: Total Operating Expenses', '₹${expenses.toStringAsFixed(2)}', Colors.red.shade700),
                        const Divider(),
                        _row('NET PROFIT / (LOSS)', '₹${netProfit.toStringAsFixed(2)}', netProfit >= 0 ? Colors.green.shade800 : Colors.red.shade800, isBold: true),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
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

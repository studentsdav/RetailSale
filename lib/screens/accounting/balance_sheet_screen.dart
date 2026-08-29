import 'package:flutter/material.dart';
import '../../controllers/accounting/financial_reports_controller.dart';

class BalanceSheetScreen extends StatefulWidget {
  const BalanceSheetScreen({super.key});

  @override
  State<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends State<BalanceSheetScreen> {
  final FinancialReportsController ctrl = FinancialReportsController();

  @override
  void initState() {
    super.initState();
    ctrl.fetchBalanceSheet();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0B5CAD);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('Balance Sheet Statement', style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          if (ctrl.loading) return const Center(child: CircularProgressIndicator());

          final data = ctrl.balanceSheetData;
          final assets = data['assets'] as List? ?? [];
          final liabilities = data['liabilities'] as List? ?? [];
          final equity = data['equity'] as List? ?? [];
          final totals = data['totals'] ?? {};

          final totalAssets = double.tryParse((totals['totalAssets'] ?? 0).toString()) ?? 0.0;
          final totalLiab = double.tryParse((totals['totalLiabilities'] ?? 0).toString()) ?? 0.0;
          final totalEq = double.tryParse((totals['totalEquity'] ?? 0).toString()) ?? 0.0;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Assets
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ASSETS (Application of Funds)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor)),
                          const Divider(height: 20),
                          Expanded(
                            child: ListView.builder(
                              itemCount: assets.length,
                              itemBuilder: (context, i) {
                                final a = assets[i];
                                return ListTile(
                                  title: Text(a['name'] ?? ''),
                                  trailing: Text('₹${(a['amount'] ?? 0).toString()}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                                );
                              },
                            ),
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL ASSETS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('₹${totalAssets.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor, fontFamily: 'monospace')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Right: Liabilities & Equity
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('LIABILITIES & CAPITAL (Source of Funds)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor)),
                          const Divider(height: 20),
                          Expanded(
                            child: ListView(
                              children: [
                                const Text('Capital & Reserves', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                                ...equity.map((e) => ListTile(
                                  title: Text(e['name'] ?? ''),
                                  trailing: Text('₹${(e['amount'] ?? 0).toString()}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                                )),
                                const SizedBox(height: 12),
                                const Text('Liabilities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                                ...liabilities.map((l) => ListTile(
                                  title: Text(l['name'] ?? ''),
                                  trailing: Text('₹${(l['amount'] ?? 0).toString()}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                                )),
                              ],
                            ),
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL LIABILITIES & EQUITY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('₹${(totalLiab + totalEq).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor, fontFamily: 'monospace')),
                            ],
                          ),
                        ],
                      ),
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
}

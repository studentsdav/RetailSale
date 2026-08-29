import 'package:flutter/material.dart';
import '../../controllers/accounting/financial_reports_controller.dart';

class TrialBalanceScreen extends StatefulWidget {
  const TrialBalanceScreen({super.key});

  @override
  State<TrialBalanceScreen> createState() => _TrialBalanceScreenState();
}

class _TrialBalanceScreenState extends State<TrialBalanceScreen> {
  final FinancialReportsController ctrl = FinancialReportsController();

  @override
  void initState() {
    super.initState();
    ctrl.fetchTrialBalance();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0B5CAD);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('Trial Balance Report', style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          if (ctrl.loading) return const Center(child: CircularProgressIndicator());

          final rows = ctrl.trialBalanceData['data'] as List? ?? [];
          final summary = ctrl.trialBalanceData['summary'] ?? {};

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Trial Balance Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (summary['isBalanced'] ?? true) ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: (summary['isBalanced'] ?? true) ? Colors.green : Colors.red),
                          ),
                          child: Text(
                            (summary['isBalanced'] ?? true) ? 'STATUS: BALANCED' : 'UNBALANCED',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: (summary['isBalanced'] ?? true) ? Colors.green.shade900 : Colors.red.shade900),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Ledger Account', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Group', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(numeric: true, label: Text('Debit (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(numeric: true, label: Text('Credit (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: rows.map<DataRow>((r) {
                            return DataRow(
                              cells: [
                                DataCell(Text(r['account_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text(r['group_name'] ?? '', style: const TextStyle(color: Colors.grey))),
                                DataCell(Text(double.parse((r['debit'] ?? 0).toString()).toStringAsFixed(2), style: const TextStyle(fontFamily: 'monospace'))),
                                DataCell(Text(double.parse((r['credit'] ?? 0).toString()).toStringAsFixed(2), style: const TextStyle(fontFamily: 'monospace'))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Row(
                          children: [
                            Text('Debit: ₹${(summary['totalDebit'] ?? 0).toString()}', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontFamily: 'monospace')),
                            const SizedBox(width: 24),
                            Text('Credit: ₹${(summary['totalCredit'] ?? 0).toString()}', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontFamily: 'monospace')),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

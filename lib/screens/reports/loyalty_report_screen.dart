import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/reports/loyalty_report_controller.dart';
import '../../controllers/sales/sales_controller.dart';
import '../../models/reports/loyalty_report_model.dart';
import '../../widgets/sale_bill_preview_dialog.dart';

class LoyaltyReportScreen extends StatefulWidget {
  const LoyaltyReportScreen({super.key});

  @override
  State<LoyaltyReportScreen> createState() => _LoyaltyReportScreenState();
}

class _LoyaltyReportScreenState extends State<LoyaltyReportScreen> {
  final LoyaltyReportController _ctrl = LoyaltyReportController();
  final SalesController _salesCtrl = SalesController();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _openLedger(LoyaltyMasterRow row) async {
    try {
      final ledger = await _ctrl.getLedger(row.customerKey);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _LoyaltyLedgerDialog(
          customerName: row.customerName,
          rows: ledger,
          onOpenBill: (saleId) async {
            final details = await _salesCtrl.getSaleDetails(saleId);
            if (!mounted) return;
            await showSaleBillPreviewDialog(context, sale: details);
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loyalty Master Report')),
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Search customer',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                        ),
                        onSubmitted: (_) => _ctrl.load(search: _searchCtrl.text),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => _ctrl.load(search: _searchCtrl.text),
                      icon: const Icon(Icons.search),
                      label: const Text('Search'),
                    )
                  ],
                ),
              ),
              Expanded(
                child: _ctrl.loading
                    ? const Center(child: CircularProgressIndicator())
                    : _ctrl.rows.isEmpty
                        ? const Center(child: Text('No loyalty data found.'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Customer Name')),
                                DataColumn(label: Text('Lifetime Purchase')),
                                DataColumn(label: Text('Points Earned')),
                                DataColumn(label: Text('Points Redeemed')),
                                DataColumn(label: Text('Points Expired')),
                                DataColumn(label: Text('Active Balance')),
                                DataColumn(label: Text('Ledger')),
                              ],
                              rows: _ctrl.rows.map((row) {
                                return DataRow(cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 220,
                                      child: Text(
                                        row.customerName.isEmpty
                                            ? 'Walk-in Customer'
                                            : row.customerName,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(row.totalLifetimePurchase.toStringAsFixed(2))),
                                  DataCell(Text(row.totalPointsEarned.toString())),
                                  DataCell(Text(row.totalPointsRedeemed.toString())),
                                  DataCell(Text(row.pointsExpired.toString())),
                                  DataCell(
                                    Text(
                                      row.currentActiveBalance.toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    TextButton(
                                      onPressed: () => _openLedger(row),
                                      child: const Text('View'),
                                    ),
                                  ),
                                ]);
                              }).toList(),
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoyaltyLedgerDialog extends StatelessWidget {
  final String customerName;
  final List<LoyaltyLedgerRow> rows;
  final Future<void> Function(int saleId) onOpenBill;

  const _LoyaltyLedgerDialog({
    required this.customerName,
    required this.rows,
    required this.onOpenBill,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${customerName.trim().isEmpty ? 'Customer' : customerName} - Loyalty Ledger',
      ),
      content: SizedBox(
        width: 980,
        child: rows.isEmpty
            ? const Center(child: Text('No ledger entries found.'))
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Points')),
                    DataColumn(label: Text('Balance After')),
                    DataColumn(label: Text('Bill Number')),
                    DataColumn(label: Text('Expiry Date')),
                  ],
                  rows: rows.map((row) {
                    final pointsText = row.pointsDelta > 0
                        ? '+${row.pointsDelta}'
                        : row.pointsDelta.toString();
                    return DataRow(cells: [
                      DataCell(Text(DateFormat('dd-MMM-yyyy hh:mm a')
                          .format(row.transactionDate))),
                      DataCell(Text(row.transactionType)),
                      DataCell(
                        Text(
                          pointsText,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: row.pointsDelta >= 0
                                ? const Color(0xFF15803D)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                      DataCell(Text(row.pointsBalanceAfter.toString())),
                      DataCell(
                        row.saleId > 0
                            ? TextButton(
                                onPressed: () => onOpenBill(row.saleId),
                                child: Text(
                                  row.billNumber.isEmpty
                                      ? '#${row.saleId}'
                                      : row.billNumber,
                                ),
                              )
                            : Text(row.billNumber),
                      ),
                      DataCell(Text(row.expiryDate)),
                    ]);
                  }).toList(),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        )
      ],
    );
  }
}

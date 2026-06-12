import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/inventory/supplier_return_controller.dart';
import '../../models/inventory/supplier_return_model.dart';

class SupplierReturnRefundScreen extends StatefulWidget {
  const SupplierReturnRefundScreen({super.key});

  @override
  State<SupplierReturnRefundScreen> createState() =>
      _SupplierReturnRefundScreenState();
}

class _SupplierReturnRefundScreenState
    extends State<SupplierReturnRefundScreen> {
  final ctrl = SupplierReturnController();
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  final fromCtrl = TextEditingController();
  final toCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    fromCtrl.text = DateFormat('dd-MMM-yyyy').format(fromDate);
    toCtrl.text = DateFormat('dd-MMM-yyyy').format(toDate);
    _load();
  }

  Future<void> _load() async {
    await ctrl.loadReturns(fromDate: fromDate, toDate: toDate);
    setState(() {});
  }

  Future<void> _openRefundDialog(SupplierReturnRecord record) async {
    final amountCtrl =
        TextEditingController(text: record.pendingAmount.toStringAsFixed(2));
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime refundDate = DateTime.now();
    String mode = 'CASH';
    String? error;

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialog) {
            return AlertDialog(
              title: const Text('Receive Supplier Refund'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _info('Return No', record.returnNo),
                  _info('Supplier', record.supplierName),
                  _info('Pending', record.pendingAmount.toStringAsFixed(2)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Refund Amount',
                      errorText: error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: mode,
                    items: const ['CASH', 'CARD', 'UPI', 'BANK', 'CREDIT']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) => mode = value ?? 'CASH',
                    decoration:
                        const InputDecoration(labelText: 'Payment Mode'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: refCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Reference No'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Refund Date'),
                    subtitle:
                        Text(DateFormat('dd-MMM-yyyy').format(refundDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: refundDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialog(() => refundDate = picked);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text) ?? 0;
                    if (amount <= 0 || amount > record.pendingAmount) {
                      setDialog(() => error = 'Enter valid refund amount');
                      return;
                    }
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ctrl.receiveRefund(
                        returnId: record.id,
                        amount: amount,
                        refundDate: refundDate,
                        paymentMode: mode,
                        referenceNo: refCtrl.text.trim().isEmpty
                            ? null
                            : refCtrl.text.trim(),
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      );
                      navigator.pop();
                      await _load();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Refund received and ledger credited')),
                      );
                    } catch (e) {
                      setDialog(
                        () => error =
                            e.toString().replaceFirst('Exception: ', ''),
                      );
                    }
                  },
                  child: const Text('Receive'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showHistory(SupplierReturnRecord record) async {
    await ctrl.loadRefunds(record.id);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Refund History - ${record.returnNo}'),
        content: SizedBox(
          width: 520,
          child: ctrl.refunds.isEmpty
              ? const Text('No refunds received yet')
              : SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Mode')),
                      DataColumn(label: Text('Ref No')),
                      DataColumn(label: Text('Amount')),
                    ],
                    rows: ctrl.refunds
                        .map(
                          (e) => DataRow(
                            cells: [
                              DataCell(
                                Text(DateFormat('dd-MMM-yyyy')
                                    .format(e.refundDate)),
                              ),
                              DataCell(Text(e.paymentMode)),
                              DataCell(Text(e.referenceNo)),
                              DataCell(Text(e.amount.toStringAsFixed(2))),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Supplier Return Refund Ledger'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _filterCard(),
            const SizedBox(height: 12),
            Expanded(child: _tableCard()),
          ],
        ),
      ),
    );
  }

  Widget _filterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _dateField('From Date', fromCtrl, () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: fromDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() {
                  fromDate = picked;
                  fromCtrl.text = DateFormat('dd-MMM-yyyy').format(picked);
                });
              }
            }),
            _dateField('To Date', toCtrl, () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: toDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() {
                  toDate = picked;
                  toCtrl.text = DateFormat('dd-MMM-yyyy').format(picked);
                });
              }
            }),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.search),
              label: const Text('Load'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight,
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Return No')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Supplier')),
                  DataColumn(label: Text('GRN')),
                  DataColumn(label: Text('Bill No')),
                  DataColumn(label: Text('Total Return')),
                  DataColumn(label: Text('Refunded')),
                  DataColumn(label: Text('Pending')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Action')),
                ],
                rows: ctrl.returns.map((record) {
                  return DataRow(
                    cells: [
                      DataCell(Text(record.returnNo)),
                      DataCell(Text(
                          DateFormat('dd-MMM-yyyy').format(record.returnDate))),
                      DataCell(Text(record.supplierName)),
                      DataCell(Text(record.grnNo)),
                      DataCell(Text(record.billNo)),
                      DataCell(Text(record.totalAmount.toStringAsFixed(2))),
                      DataCell(Text(record.refundedAmount.toStringAsFixed(2))),
                      DataCell(Text(record.pendingAmount.toStringAsFixed(2))),
                      DataCell(Text(record.status)),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => _showHistory(record),
                              icon: const Icon(Icons.history),
                            ),
                            if (record.pendingAmount > 0)
                              FilledButton(
                                onPressed: () => _openRefundDialog(record),
                                child: const Text('Receive'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dateField(
    String label,
    TextEditingController controller,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: 180,
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _info(String label, String value) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('$label : $value'),
        ),
      );
}

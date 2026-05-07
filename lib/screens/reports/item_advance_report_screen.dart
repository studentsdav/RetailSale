import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../../controllers/reports/item_advance_report_controller.dart';
import '../../models/inventory/item_model.dart';

class ItemAdvanceReportScreen extends StatefulWidget {
  const ItemAdvanceReportScreen({super.key});

  @override
  State<ItemAdvanceReportScreen> createState() =>
      _ItemAdvanceReportScreenState();
}

class _ItemAdvanceReportScreenState extends State<ItemAdvanceReportScreen> {
  final ctrl = ItemAdvanceReportController();
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _customerGstin = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    ctrl.init();
    _fromCtrl.text = DateFormat('dd-MMM-yyyy').format(ctrl.fromDate);
    _toCtrl.text = DateFormat('dd-MMM-yyyy').format(ctrl.toDate);
  }

  @override
  void dispose() {
    _customerName.dispose();
    _customerPhone.dispose();
    _customerGstin.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  double _num(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Item Advance Report'),
        centerTitle: true,
      ),
      body: AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _filterCard(),
                const SizedBox(height: 12),
                Expanded(
                  child: ctrl.loading
                      ? const Center(child: CircularProgressIndicator())
                      : ctrl.selectedItem == null
                          ? const Center(
                              child: Text('Select a customer and item'))
                          : _reportBody(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              controller: _customerName,
              decoration: const InputDecoration(labelText: 'Customer Name'),
            ),
          ),
          SizedBox(
            width: 180,
            child: TextField(
              controller: _customerPhone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
          ),
          SizedBox(
            width: 180,
            child: TextField(
              controller: _customerGstin,
              decoration: const InputDecoration(labelText: 'GSTIN'),
            ),
          ),
          SizedBox(
            width: 320,
            child: DropdownSearch<Item>(
              selectedItem: ctrl.selectedItem,
              items: (filter, _) async {
                final q = filter.trim().toLowerCase();
                if (q.isEmpty) return ctrl.items.take(20).toList();
                return ctrl.items
                    .where((item) =>
                        item.itemCode.toLowerCase().contains(q) ||
                        item.itemName.toLowerCase().contains(q) ||
                        item.barcode.toLowerCase().contains(q))
                    .take(20)
                    .toList();
              },
              itemAsString: (item) => '${item.itemCode} - ${item.itemName}',
              compareFn: (a, b) => a.id == b.id,
              popupProps: const PopupProps.menu(showSearchBox: true),
              decoratorProps: const DropDownDecoratorProps(
                decoration: InputDecoration(labelText: 'Item'),
              ),
              onChanged: (item) {
                setState(() => ctrl.selectedItem = item);
              },
            ),
          ),
          SizedBox(
            width: 180,
            child: TextField(
              controller: _fromCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'From',
                suffixIcon: Icon(Icons.date_range),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: ctrl.fromDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() {
                    ctrl.fromDate = picked;
                    _fromCtrl.text = DateFormat('dd-MMM-yyyy').format(picked);
                  });
                }
              },
            ),
          ),
          SizedBox(
            width: 180,
            child: TextField(
              controller: _toCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'To',
                suffixIcon: Icon(Icons.date_range),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: ctrl.toDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() {
                    ctrl.toDate = picked;
                    _toCtrl.text = DateFormat('dd-MMM-yyyy').format(picked);
                  });
                }
              },
            ),
          ),
          FilledButton.icon(
            onPressed: ctrl.selectedItem == null
                ? null
                : () => ctrl.loadReport(
                      customerName: _customerName.text.trim(),
                      customerPhone: _customerPhone.text.trim(),
                      customerGstin: _customerGstin.text.trim(),
                    ),
            icon: const Icon(Icons.refresh),
            label: const Text('Load'),
          ),
        ],
      ),
    );
  }

  Widget _reportBody() {
    final advances = (ctrl.report['advances'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final consumptions = (ctrl.report['consumptions'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final purchasedQty =
        advances.fold<double>(0, (sum, row) => sum + _num(row['original_qty']));
    final consumedQty =
        consumptions.fold<double>(0, (sum, row) => sum + _num(row['qty']));
    double leftQty = (purchasedQty - consumedQty).clamp(0, double.infinity);

    return ListView(
      children: [
        _summaryCard(purchasedQty, consumedQty, leftQty),
        const SizedBox(height: 12),
        _ledgerTable(
          title: 'Advance Purchases',
          emptyText: 'No advance purchases in this period.',
          rows: advances.map((row) {
            final dt =
                DateTime.tryParse((row['advance_date'] ?? '').toString());
            return [
              dt == null ? '--' : DateFormat('dd-MMM-yyyy').format(dt),
              _num(row['original_qty']).toStringAsFixed(2),
              _num(row['available_qty']).toStringAsFixed(2),
              _num(row['rate']).toStringAsFixed(2),
              (row['note'] ?? '').toString(),
            ];
          }).toList(),
          headers: const ['Date', 'Qty', 'Available', 'Rate', 'Note'],
        ),
        const SizedBox(height: 12),
        _ledgerTable(
          title: 'Consumed In Bills',
          emptyText: 'No consumption in this period.',
          rows: consumptions.map((row) {
            final dt = DateTime.tryParse((row['sale_day'] ?? '').toString());
            return [
              dt == null ? '--' : DateFormat('dd-MMM-yyyy').format(dt),
              (row['sale_no'] ?? '').toString(),
              _num(row['qty']).toStringAsFixed(2),
            ];
          }).toList(),
          headers: const ['Date', 'Bill No', 'Qty'],
        ),
      ],
    );
  }

  Widget _summaryCard(double purchasedQty, double consumedQty, double leftQty) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 10,
        children: [
          Text(
            'Customer: ${_customerName.text.trim().isEmpty ? 'Walk-in' : _customerName.text.trim()}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text('Item: ${ctrl.selectedItem?.itemName ?? ''}'),
          Text('From: ${DateFormat('dd-MMM-yyyy').format(ctrl.fromDate)}'),
          Text('To: ${DateFormat('dd-MMM-yyyy').format(ctrl.toDate)}'),
          Text('Purchased: ${purchasedQty.toStringAsFixed(2)}'),
          Text('Consumed: ${consumedQty.toStringAsFixed(2)}'),
          Text('Left: ${leftQty.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _ledgerTable({
    required String title,
    required String emptyText,
    required List<List<String>> rows,
    required List<String> headers,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text(emptyText)
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns:
                    headers.map((e) => DataColumn(label: Text(e))).toList(),
                rows: rows
                    .map(
                      (row) => DataRow(
                        cells: row.map((cell) => DataCell(Text(cell))).toList(),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

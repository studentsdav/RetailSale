import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/sales/sales_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../core/printing/pos_invoice_printer.dart';
import '../../models/inventory/sale_order_model.dart';
import '../inventory/salescreen.dart';

class SalesReprintModifyScreen extends StatefulWidget {
  const SalesReprintModifyScreen({super.key});

  @override
  State<SalesReprintModifyScreen> createState() =>
      _SalesReprintModifyScreenState();
}

class _SalesReprintModifyScreenState extends State<SalesReprintModifyScreen> {
  final ctrl = SalesController();
  final propertyCtrl = PropertyInfoController();
  final _searchCtrl = TextEditingController();

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();
  bool _loading = false;
  List<Map<String, dynamic>> _sales = const [];
  Map<String, dynamic>? _selectedSale;
  Map<String, dynamic>? _selectedDetails;
  SaleOrder? _selectedOrder;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    await propertyCtrl.load();
    await _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _loading = true);
    try {
      final sales = await ctrl.listSales(
        status: 'COMPLETED',
        fromDate: _fromDate,
        toDate: _toDate,
        search: _searchCtrl.text,
      );
      setState(() {
        _sales = sales;
        final selectedId = _selectedSale?['id'];
        if (selectedId != null) {
          final refreshed = sales.cast<Map<String, dynamic>?>().firstWhere(
                (sale) => sale?['id'] == selectedId,
                orElse: () => null,
              );
          _selectedSale = refreshed;
        }
        if (_selectedSale == null) {
          _selectedOrder = null;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
  }

  Future<void> _selectSale(Map<String, dynamic> sale) async {
    setState(() {
      _selectedSale = sale;
      _selectedDetails = null;
      _selectedOrder = null;
      _loading = true;
    });
    try {
      final details = await ctrl.getSaleDetails(int.parse('${sale['id']}'));
      setState(() {
        _selectedDetails = details;
        _selectedOrder = SaleOrder.fromJson(details);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _printSelected() async {
    if (_selectedOrder == null) return;
    final paymentInfo = _paymentInfoText();
    await PosInvoicePrinter.printSaleInvoice(
      order: _selectedOrder!,
      property: propertyCtrl.data,
      termsAndConditions: paymentInfo,
    );
  }

  Future<void> _modifySelected() async {
    final saleId = int.tryParse('${_selectedSale?['id'] ?? ''}');
    if (saleId == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SaleScreen(editSaleId: saleId),
      ),
    );
    if (changed == true) {
      await _loadSales();
    }
  }

  void _closeScreen() {
    Navigator.of(context).maybePop();
  }

  String _fmtAmount(dynamic value) {
    final amount = double.tryParse(value?.toString() ?? '') ?? 0;
    return amount.toStringAsFixed(2);
  }

  String _paymentInfoText() {
    if (_selectedOrder == null) return 'Thank you for your business.';
    final repayments =
        (_selectedDetails?['repayments'] as List? ?? const []).cast<dynamic>();
    if (repayments.isEmpty) {
      return 'Payment Mode: ${_selectedOrder!.paymentMode} | Paid ${_selectedOrder!.amountPaid.toStringAsFixed(2)} on ${DateFormat('dd-MMM-yyyy').format(_selectedOrder!.saleDate)}';
    }

    final parts = <String>[
      'Initial ${_selectedOrder!.paymentMode}: ${_selectedOrder!.amountPaid.toStringAsFixed(2)} on ${DateFormat('dd-MMM-yyyy').format(_selectedOrder!.saleDate)}',
    ];
    for (final repayment in repayments) {
      final rawDate = DateTime.tryParse('${repayment['payment_date'] ?? ''}');
      final paymentDate = rawDate?.toLocal();
      final amount = double.tryParse('${repayment['amount'] ?? 0}') ?? 0;
      final mode = '${repayment['payment_mode'] ?? ''}'.trim();
      if (paymentDate != null) {
        parts.add(
          '$mode ${amount.toStringAsFixed(2)} on ${DateFormat('dd-MMM-yyyy').format(paymentDate)}',
        );
      }
    }
    return parts.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reprint / Modify Sales Bill')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickDate(isFrom: true),
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        'From ${DateFormat('dd-MMM-yyyy').format(_fromDate)}',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickDate(isFrom: false),
                      icon: const Icon(Icons.event),
                      label: Text(
                        'To ${DateFormat('dd-MMM-yyyy').format(_toDate)}',
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Bill No / Customer / Phone',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _loadSales(),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _loadSales,
                      icon: const Icon(Icons.search),
                      label: const Text('Search'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Card(
                      child: _loading && _sales.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : _sales.isEmpty
                              ? const Center(
                                  child: Text('No completed bills found.'),
                                )
                              : ListView.separated(
                                  itemCount: _sales.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final sale = _sales[index];
                                    final selected =
                                        sale['id'] == _selectedSale?['id'];
                                    final saleDate = DateTime.tryParse(
                                      sale['sale_date']?.toString() ?? '',
                                    );
                                    return ListTile(
                                      selected: selected,
                                      title:
                                          Text('${sale['sale_no'] ?? 'Bill'}'),
                                      subtitle: Text(
                                        '${sale['customer_name']?.toString().trim().isNotEmpty == true ? sale['customer_name'] : 'Walk-in Customer'} • ${saleDate == null ? '--' : DateFormat('dd-MMM-yyyy hh:mm a').format(saleDate)} • Rs. ${_fmtAmount(sale['net_amount'])}',
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => _selectSale(sale),
                                    );
                                  },
                                ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 5,
                    child: Card(
                      child: _selectedOrder == null
                          ? Center(
                              child: _loading
                                  ? const CircularProgressIndicator()
                                  : const Text(
                                      'Select a bill to preview, print, or modify.',
                                    ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Bill ${_selectedOrder!.saleNo}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge,
                                            ),
                                            Text(
                                              DateFormat('dd-MMM-yyyy hh:mm a')
                                                  .format(
                                                      _selectedOrder!.saleDate),
                                            ),
                                            Text(
                                              _selectedOrder!.customerName
                                                          ?.trim()
                                                          .isNotEmpty ==
                                                      true
                                                  ? _selectedOrder!
                                                      .customerName!
                                                  : 'Walk-in Customer',
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _paymentInfoText(),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      FilledButton.icon(
                                        onPressed: _printSelected,
                                        icon: const Icon(Icons.print_outlined),
                                        label: const Text('Print'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: _modifySelected,
                                        icon: const Icon(Icons.edit_outlined),
                                        label: const Text('Modify'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      _metricCard('Items',
                                          '${_selectedOrder!.items.length}'),
                                      _metricCard(
                                          'Qty',
                                          _selectedOrder!.totalQty
                                              .toStringAsFixed(2)),
                                      _metricCard('Sub Total',
                                          _fmtAmount(_selectedOrder!.subTotal)),
                                      _metricCard(
                                          'Discount',
                                          _fmtAmount(
                                              _selectedOrder!.totalDiscount)),
                                      _metricCard('Tax',
                                          _fmtAmount(_selectedOrder!.totalTax)),
                                      _metricCard(
                                          'Net Amount',
                                          _fmtAmount(
                                              _selectedOrder!.netAmount)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Bill Items',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: _selectedOrder!.items.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final item =
                                            _selectedOrder!.items[index];
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(item.itemName),
                                          subtitle: Text(
                                            '${item.itemCode} • Qty ${item.qty.toStringAsFixed(2)} • Rate ${item.rate.toStringAsFixed(2)}',
                                          ),
                                          trailing: Text(
                                            'Rs. ${item.netAmount.toStringAsFixed(2)}',
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SafeArea(
                                    top: false,
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      alignment: WrapAlignment.end,
                                      children: [
                                        Tooltip(
                                          message: 'Close modify screen',
                                          child: SizedBox(
                                            width: 170,
                                            height: 56,
                                            child: OutlinedButton.icon(
                                              onPressed: _closeScreen,
                                              icon: const Icon(
                                                Icons.close_outlined,
                                              ),
                                              label: const Text('Cancel'),
                                            ),
                                          ),
                                        ),
                                        Tooltip(
                                          message: 'Print selected bill',
                                          child: SizedBox(
                                            width: 180,
                                            height: 56,
                                            child: FilledButton.icon(
                                              onPressed: _printSelected,
                                              icon: const Icon(
                                                Icons.print_outlined,
                                              ),
                                              label: const Text('Print'),
                                            ),
                                          ),
                                        ),
                                        Tooltip(
                                          message: 'Open bill in modify mode',
                                          child: SizedBox(
                                            width: 190,
                                            height: 56,
                                            child: FilledButton.icon(
                                              onPressed: _modifySelected,
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                              label: const Text('Modify'),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

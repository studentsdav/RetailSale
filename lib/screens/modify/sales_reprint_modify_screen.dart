import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/sales/sales_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../core/printing/pos_invoice_printer.dart';
import '../../models/auth/permission_service.dart';
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
  bool get _canReprintSales =>
      PermissionService.can('REPRINT_SALES_BILL') ||
      PermissionService.can('RETAIL_SALES');
  bool get _canModifySales => PermissionService.can('MODIFY_SALES_BILL');
  bool get _canModifySalesPayment =>
      PermissionService.can('MODIFY_SALES_PAYMENT');

  int _saleNoNumericValue(String? saleNo) {
    final raw = (saleNo ?? '').trim();
    final match = RegExp(r'(\d+)(?!.*\d)').firstMatch(raw);
    if (match == null) return 1 << 30;
    return int.tryParse(match.group(1) ?? '') ?? (1 << 30);
  }

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
      sales.sort((a, b) {
        final aNo = _saleNoNumericValue(a['sale_no']?.toString());
        final bNo = _saleNoNumericValue(b['sale_no']?.toString());
        if (aNo != bNo) return aNo.compareTo(bNo);
        final aId = int.tryParse('${a['id'] ?? 0}') ?? 0;
        final bId = int.tryParse('${b['id'] ?? 0}') ?? 0;
        return aId.compareTo(bId);
      });
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

  Future<void> _printCreditNote(Map<String, dynamic> creditNote) async {
    try {
      setState(() => _loading = true);
      await PosInvoicePrinter.printCreditNote(
        creditNote: creditNote,
        property: propertyCtrl.data,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to print Credit Note: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  Future<void> _showReturnDialog() async {
    if (_selectedOrder == null) return;
    
    // Maintain a map of item_id -> (isSelected, returnQty)
    final itemsState = <int, Map<String, dynamic>>{};
    final rawItems = _selectedDetails?['items'] as List? ?? const [];
    for (final rawItem in rawItems) {
      final itemId = int.tryParse(rawItem['item_id']?.toString() ?? '') ?? 0;
      final originalQty = double.tryParse(rawItem['qty']?.toString() ?? '') ?? 0.0;
      final returnedQty = double.tryParse(rawItem['returned_qty']?.toString() ?? '') ?? 0.0;
      final remainingQty = originalQty - returnedQty;
      if (remainingQty <= 0) continue; // Item is already fully returned

      itemsState[itemId] = {
        'selected': true, // Default to selected
        'qty': remainingQty, // Default to remaining quantity
        'maxQty': remainingQty,
        'name': rawItem['item_name']?.toString() ?? '',
        'code': rawItem['item_code']?.toString() ?? '',
      };
    }

    if (itemsState.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All items in this bill have already been returned.')),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setInnerState) {
            final allSelected = itemsState.values.every((val) => val['selected'] == true);

            void toggleAll(bool? val) {
              setInnerState(() {
                for (final key in itemsState.keys) {
                  itemsState[key]!['selected'] = val ?? false;
                }
              });
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.assignment_return_outlined, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text('Select Items to Return'),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Choose which items to return and the quantity. Returned stock will be reverted to your inventory.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text('Select All / Deselect All', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: allSelected,
                      onChanged: toggleAll,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView(
                        shrinkWrap: true,
                        children: itemsState.entries.map((entry) {
                          final itemId = entry.key;
                          final state = entry.value;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: state['selected'],
                                  onChanged: (val) {
                                    setInnerState(() {
                                      state['selected'] = val ?? false;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(state['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                                      Text('${state['code']} • Max: ${state['maxQty']}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    initialValue: state['qty'].toString(),
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    enabled: state['selected'],
                                    onChanged: (val) {
                                      final parsed = double.tryParse(val) ?? 0.0;
                                      if (parsed > state['maxQty']) {
                                        setInnerState(() {
                                          state['qty'] = state['maxQty'];
                                        });
                                      } else if (parsed < 0) {
                                        setInnerState(() {
                                          state['qty'] = 0.0;
                                        });
                                      } else {
                                        state['qty'] = parsed;
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    // Check if at least one item is selected with > 0 quantity
                    final selectedEntries = itemsState.entries.where((e) => e.value['selected'] == true && e.value['qty'] > 0).toList();
                    if (selectedEntries.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select at least one item with quantity > 0 to return')),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Confirm Return'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final selectedItems = itemsState.entries
        .where((e) => e.value['selected'] == true && e.value['qty'] > 0)
        .map((e) => {
              'item_id': e.key,
              'qty_to_return': e.value['qty'],
            })
        .toList();

    setState(() => _loading = true);
    try {
      final saleId = int.parse('${_selectedSale!['id']}');
      await ctrl.returnSale(saleId: saleId, items: selectedItems);
      
      await _loadSales();
      if (_selectedSale != null) {
        await _selectSale(_selectedSale!);
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale items returned successfully and stock reverted to inventory!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to return sale: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _modifyPaymentSelected() async {
    final saleId = int.tryParse('${_selectedSale?['id'] ?? ''}');
    if (saleId == null || _selectedOrder == null) return;

    final selectedPayment = await _showPaymentModeDialog(
      initialMode: _selectedOrder!.paymentMode,
      netAmount: _selectedOrder!.netAmount,
      currentReference: _selectedOrder!.paymentReference,
      currentPaid: _selectedOrder!.amountPaid,
      currentDue: _selectedOrder!.balanceDue,
    );
    if (selectedPayment == null) return;

    setState(() => _loading = true);
    try {
      await ctrl.updateSalePaymentMode(
        saleId: saleId,
        paymentMode: selectedPayment['payment_mode'] as String,
        paymentLines:
            (selectedPayment['payment_lines'] as List? ?? const [])
                .map((entry) => Map<String, dynamic>.from(entry))
                .toList(),
      );
      await _loadSales();
      if (_selectedSale != null) {
        await _selectSale(_selectedSale!);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment updated and ledger synced.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update payment mode: $error')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _decodePaymentLines(
    String? paymentReference, {
    required String fallbackMode,
    required double fallbackPaid,
    required double fallbackDue,
  }) {
    final raw = (paymentReference ?? '').trim();
    if (raw.startsWith('POSPAY:')) {
      try {
        final decoded = jsonDecode(raw.substring(7));
        if (decoded is List) {
          final rows = decoded
              .map((entry) => {
                    'method': (entry['method'] ?? 'CASH').toString().trim().toUpperCase(),
                    'amount':
                        double.tryParse((entry['amount'] ?? 0).toString()) ?? 0,
                  })
              .where((entry) => (entry['amount'] as double) > 0)
              .toList();
          if (rows.isNotEmpty) return rows;
        }
      } catch (_) {}
    }

    final fallback = <Map<String, dynamic>>[];
    if (fallbackPaid > 0) {
      fallback.add({'method': fallbackMode.toUpperCase(), 'amount': fallbackPaid});
    }
    if (fallbackDue > 0) {
      fallback.add({'method': 'CREDIT', 'amount': fallbackDue});
    }
    return fallback;
  }

  Future<Map<String, dynamic>?> _showPaymentModeDialog({
    required String initialMode,
    required double netAmount,
    required String? currentReference,
    required double currentPaid,
    required double currentDue,
  }) async {
    final allowedModes = const ['CASH', 'CARD', 'UPI', 'BANK', 'CREDIT'];
    final initialLines = _decodePaymentLines(
      currentReference,
      fallbackMode: initialMode,
      fallbackPaid: currentPaid,
      fallbackDue: currentDue,
    );
    String mode1 =
        (initialLines.isNotEmpty ? '${initialLines[0]['method']}' : initialMode)
            .toUpperCase();
    String amount1 = initialLines.isNotEmpty
        ? (initialLines[0]['amount'] as double).toStringAsFixed(2)
        : netAmount.toStringAsFixed(2);
    String mode2 =
        initialLines.length > 1 ? '${initialLines[1]['method']}'.toUpperCase() : 'UPI';
    String amount2 = initialLines.length > 1
        ? (initialLines[1]['amount'] as double).toStringAsFixed(2)
        : '0.00';
    bool useSecond = initialLines.length > 1;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text('Modify Payment Mode'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update payment split. Ledger will be synced to these methods.',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: allowedModes.contains(mode1) ? mode1 : 'CASH',
                          decoration: const InputDecoration(
                            labelText: 'Method 1',
                            border: OutlineInputBorder(),
                          ),
                          items: allowedModes
                              .map((entry) => DropdownMenuItem(
                                    value: entry,
                                    child: Text(entry),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setInnerState(() => mode1 = value ?? 'CASH'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: amount1,
                          decoration: const InputDecoration(
                            labelText: 'Amount 1',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (value) => amount1 = value.trim(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: useSecond,
                        onChanged: (value) =>
                            setInnerState(() => useSecond = value ?? false),
                      ),
                      const Text('Use second payment method'),
                    ],
                  ),
                  if (useSecond) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: allowedModes.contains(mode2) ? mode2 : 'UPI',
                            decoration: const InputDecoration(
                              labelText: 'Method 2',
                              border: OutlineInputBorder(),
                            ),
                            items: allowedModes
                                .map((entry) => DropdownMenuItem(
                                      value: entry,
                                      child: Text(entry),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                setInnerState(() => mode2 = value ?? 'UPI'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: amount2,
                            decoration: const InputDecoration(
                              labelText: 'Amount 2',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (value) => amount2 = value.trim(),
                          ),
                        ),
                      ],
                    ),
                  ],
                  DropdownButtonFormField<String>(
                    value: allowedModes.contains(mode1) ? mode1 : 'CASH',
                    decoration: const InputDecoration(
                      labelText: 'Primary Mode (Bill Header)',
                      border: OutlineInputBorder(),
                    ),
                    items: allowedModes
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry,
                            child: Text(entry),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setInnerState(() => mode1 = value ?? 'CASH');
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final a1 = double.tryParse(amount1) ?? 0;
                    final a2 = useSecond ? (double.tryParse(amount2) ?? 0) : 0;
                    final lines = <Map<String, dynamic>>[];
                    if (a1 > 0) lines.add({'method': mode1, 'amount': a1});
                    if (useSecond && a2 > 0) {
                      lines.add({'method': mode2, 'amount': a2});
                    }
                    if (lines.isEmpty) return;
                    final total = a1 + (useSecond ? a2 : 0);
                    if ((total - netAmount).abs() > 0.01) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Payment total must match bill amount ${netAmount.toStringAsFixed(2)}',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop({
                      'payment_mode': mode1,
                      'payment_lines': lines,
                    });
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
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
                                        '${sale['customer_name']?.toString().trim().isNotEmpty == true ? sale['customer_name'] : 'Walk-in Customer'} • ${saleDate == null ? '--' : DateFormat('dd-MMM-yyyy hh:mm a').format(saleDate)} • Rs. ${_fmtAmount(sale['net_amount'])}${sale['status'] == 'RETURNED' ? ' • [RETURNED]' : ''}',
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
                                              'Bill ${_selectedOrder!.saleNo}${_selectedDetails?['status'] == 'RETURNED' ? ' (Returned)' : ''}',
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
                                    child: ListView(
                                      children: [
                                        ..._selectedOrder!.items.map((item) {
                                          final rawItem = (_selectedDetails?['items'] as List? ?? const []).firstWhere(
                                            (raw) => raw['item_id'] == item.itemId,
                                            orElse: () => null,
                                          );
                                          final returnedQty = double.tryParse(rawItem?['returned_qty']?.toString() ?? '') ?? 0.0;
                                          final returnSuffix = returnedQty > 0
                                              ? ' (Ret: ${returnedQty.toStringAsFixed(2)})'
                                              : '';

                                          return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(item.itemName),
                                            subtitle: Text(
                                              '${item.itemCode} • Qty ${item.qty.toStringAsFixed(2)}$returnSuffix • Rate ${item.rate.toStringAsFixed(2)}',
                                            ),
                                            trailing: Text(
                                              'Rs. ${item.netAmount.toStringAsFixed(2)}',
                                            ),
                                          );
                                        }),
                                        if (_selectedDetails?['credit_notes'] != null &&
                                            (_selectedDetails?['credit_notes'] as List).isNotEmpty) ...[
                                          const SizedBox(height: 16),
                                          const Divider(),
                                          const Text(
                                            'Credit Notes Issued',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...(_selectedDetails?['credit_notes'] as List).map((cn) {
                                            final cnMap = Map<String, dynamic>.from(cn);
                                            final cnDate = DateTime.tryParse(cnMap['credit_note_date']?.toString() ?? '') ?? DateTime.now();
                                            return ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text('${cnMap['credit_note_no']}'),
                                              subtitle: Text(
                                                'Date: ${DateFormat('dd-MMM-yyyy').format(cnDate)} • Reason: ${cnMap['reason'] ?? 'Sales Return'}',
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Rs. ${double.parse((cnMap['net_amount'] ?? 0).toString()).toStringAsFixed(2)}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    icon: const Icon(Icons.print, color: Colors.blue),
                                                    onPressed: () {
                                                      final mapWithSale = Map<String, dynamic>.from(cnMap);
                                                      mapWithSale['sale'] = _selectedDetails;
                                                      _printCreditNote(mapWithSale);
                                                    },
                                                    tooltip: 'Print Credit Note',
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ],
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
                                        if (_canModifySales ||
                                            _canModifySalesPayment)
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
                                        if (_canReprintSales)
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
                                        if (_canModifySalesPayment)
                                          Tooltip(
                                            message:
                                                'Correct bill payment mode and sync ledger',
                                            child: SizedBox(
                                              width: 210,
                                              height: 56,
                                              child: FilledButton.icon(
                                                onPressed:
                                                    _modifyPaymentSelected,
                                                icon: const Icon(
                                                  Icons.payments_outlined,
                                                ),
                                                label: const Text(
                                                    'Modify Payment'),
                                              ),
                                            ),
                                          ),
                                        if (_canModifySales)
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
                                        if (_canModifySales && _selectedDetails?['status'] != 'RETURNED')
                                          Tooltip(
                                            message: 'Return items from this bill',
                                            child: SizedBox(
                                              width: 170,
                                              height: 56,
                                              child: FilledButton.icon(
                                                onPressed: _showReturnDialog,
                                                icon: const Icon(
                                                  Icons.assignment_return_outlined,
                                                ),
                                                label: const Text('Return'),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: Colors.orange,
                                                  foregroundColor: Colors.white,
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

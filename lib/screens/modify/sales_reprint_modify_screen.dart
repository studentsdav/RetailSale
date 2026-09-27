import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/sales/sales_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../controllers/settings/system_settings_controller.dart';
import '../../controllers/security/user_controller.dart';
import '../../core/config/date_time_service.dart';
import '../../core/utils/timezone_utils.dart';
import '../../core/api/api_client.dart';
import 'package:printing/printing.dart';
import '../../core/currency/currency_service.dart';
import '../../core/settings/local_preferences.dart';
import '../../core/printing/pos_invoice_printer.dart';
import '../../core/printing/device_printer_routing.dart';
import '../../models/auth/permission_service.dart';
import '../../models/inventory/sale_order_model.dart';
import '../../models/security/app_user_model.dart';
import '../inventory/salescreen.dart';
import '../../core/printing/pdf_preview_dialog.dart';

class SalesReprintModifyScreen extends StatefulWidget {
  const SalesReprintModifyScreen({super.key});

  @override
  State<SalesReprintModifyScreen> createState() =>
      _SalesReprintModifyScreenState();
}

class _SalesReprintModifyScreenState extends State<SalesReprintModifyScreen> {
  final ctrl = SalesController();
  final propertyCtrl = PropertyInfoController();
  final settingsCtrl = SystemSettingsController();
  final userCtrl = UserController();

  final _searchCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();

  DateTime _fromDate = DateTimeService.instance.nowInTimeZone;
  DateTime _toDate = DateTimeService.instance.nowInTimeZone;
  bool _loading = false;

  // Filter States
  String _orderStatusFilter = 'ALL'; // 'ALL', 'RUNNING', 'COMPLETED'
  String _selectedSourceFilter = 'ALL';
  String _selectedUserFilter = 'ALL';

  List<String> _availablePaymentMethods = [
    'CASH',
    'CARD',
    'MPESA_TILL',
    'MPESA_PAYBILL',
    'UPI',
    'BANK',
    'CREDIT'
  ];
  List<AppUser> _usersList = [];
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
    final parts = raw.split('-');
    if (parts.length > 1) {
      for (int i = 1; i < parts.length; i++) {
        final val = int.tryParse(parts[i]);
        if (val != null) return val;
      }
    }
    final match = RegExp(r'\d+').firstMatch(raw);
    if (match == null) return 1 << 30;
    return int.tryParse(match.group(0) ?? '') ?? (1 << 30);
  }

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _customerPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    await propertyCtrl.load();
    await settingsCtrl.load();
    try {
      await userCtrl.load();
      if (mounted) {
        setState(() {
          _usersList = userCtrl.list;
        });
      }
    } catch (_) {}

    try {
      final methods = await ctrl.listPaymentMethods();
      final activeMethods = methods
          .where((e) => e['is_active'] == true)
          .map((e) => e['name'].toString().toUpperCase())
          .toList();
      if (activeMethods.isNotEmpty) {
        setState(() {
          _availablePaymentMethods = activeMethods;
        });
      }
    } catch (_) {}
    await _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _loading = true);
    try {
      final querySearch = _searchCtrl.text.trim().isNotEmpty
          ? _searchCtrl.text.trim()
          : (_customerPhoneCtrl.text.trim().isNotEmpty ? _customerPhoneCtrl.text.trim() : null);

      final sales = await ctrl.listSales(
        status: _orderStatusFilter,
        fromDate: _fromDate,
        toDate: _toDate,
        search: querySearch,
        source: _selectedSourceFilter != 'ALL' ? _selectedSourceFilter : null,
        userId: _selectedUserFilter != 'ALL' ? _selectedUserFilter : null,
        latestOnly: _orderStatusFilter != 'RUNNING',
      );

      sales.sort((a, b) {
        final aDate = a['sale_date']?.toString() ?? '';
        final bDate = b['sale_date']?.toString() ?? '';
        final cmpDate = bDate.compareTo(aDate);
        if (cmpDate != 0) return cmpDate;

        final aNo = _saleNoNumericValue(a['sale_no']?.toString());
        final bNo = _saleNoNumericValue(b['sale_no']?.toString());
        if (aNo != bNo) return bNo.compareTo(aNo);
        final aId = int.tryParse('${a['id'] ?? 0}') ?? 0;
        final bId = int.tryParse('${b['id'] ?? 0}') ?? 0;
        return bId.compareTo(aId);
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
        if (_selectedSale == null && sales.isNotEmpty) {
          _selectSale(sales.first);
        } else if (_selectedSale == null) {
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
    _loadSales();
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

  bool _isUnsettled(Map<String, dynamic>? sale) {
    if (sale == null) return false;
    final status = (sale['status'] ?? '').toString().toUpperCase().trim();
    return status == 'DRAFT' || status == 'RUNNING' || status == 'BILLED' || status == 'PRINTED' || status == 'PENDING';
  }

  Future<void> _showSettleBillDialog() async {
    if (_selectedSale == null || _selectedOrder == null) return;

    final saleId = int.parse('${_selectedSale!['id']}');
    final double netAmount = _selectedOrder!.netAmount;
    final String initialMode = (_selectedSale!['payment_mode'] ?? 'CASH').toString().trim();

    final List<Map<String, dynamic>> lines = [];
    final parsedSplits = _parseSplitPaymentsForOrder(_selectedOrder!);
    if (parsedSplits.isNotEmpty) {
      for (final s in parsedSplits) {
        lines.add({
          'mode': _availablePaymentMethods.contains(s['method']) ? s['method'] : 'CASH',
          'ctrl': TextEditingController(text: (s['amount'] as double).toStringAsFixed(2)),
        });
      }
    }

    if (lines.isEmpty) {
      lines.add({
        'mode': _availablePaymentMethods.contains(initialMode.toUpperCase()) && initialMode.toUpperCase() != 'SPLIT'
            ? initialMode.toUpperCase()
            : 'CASH',
        'ctrl': TextEditingController(text: netAmount.toStringAsFixed(2)),
      });
    }

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setInnerState) {
          double totalAllocated = 0.0;
          for (final l in lines) {
            totalAllocated += double.tryParse((l['ctrl'] as TextEditingController).text) ?? 0.0;
          }
          final double diff = netAmount - totalAllocated;
          final bool isBalanced = diff.abs() <= 0.05;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.point_of_sale, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Settle Bill #${_selectedOrder!.saleNo}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isBalanced ? Colors.green.shade50 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isBalanced ? Colors.green.shade300 : Colors.amber.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Net Bill Amount', style: TextStyle(fontSize: 11, color: Colors.black54)),
                              Text(CurrencyService.format(netAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isBalanced ? 'Allocated (Matched)' : 'Remaining to Allocate',
                                style: TextStyle(fontSize: 11, color: isBalanced ? Colors.green.shade800 : Colors.deepOrange),
                              ),
                              Text(
                                isBalanced ? CurrencyService.format(totalAllocated) : CurrencyService.format(diff),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isBalanced ? Colors.green.shade800 : Colors.deepOrange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Payment Method(s):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    ...lines.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final line = entry.value;
                      final ctrl = line['ctrl'] as TextEditingController;
                      final currentM = line['mode'] as String;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: DropdownButtonFormField<String>(
                                value: _availablePaymentMethods.contains(currentM) ? currentM : 'CASH',
                                isDense: true,
                                decoration: InputDecoration(
                                  labelText: 'Method #${idx + 1}',
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                items: _availablePaymentMethods
                                    .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12.5))))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setInnerState(() => line['mode'] = val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: TextField(
                                controller: ctrl,
                                decoration: const InputDecoration(
                                  labelText: 'Amount',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setInnerState(() {}),
                              ),
                            ),
                            if (lines.length > 1) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () {
                                  setInnerState(() => lines.removeAt(idx));
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade800,
                        side: BorderSide(color: Colors.green.shade800),
                      ),
                      onPressed: () {
                        final rem = diff > 0 ? diff : 0.0;
                        setInnerState(() {
                          lines.add({
                            'mode': lines.any((l) => l['mode'] == 'CARD') ? 'MPESA_TILL' : 'CARD',
                            'ctrl': TextEditingController(text: rem.toStringAsFixed(2)),
                          });
                        });
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('+ Add Payment Method (Split Bill)'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: () async {
                  final List<Map<String, dynamic>> paymentLines = [];
                  for (final l in lines) {
                    final amt = double.tryParse((l['ctrl'] as TextEditingController).text) ?? 0.0;
                    if (amt > 0) {
                      paymentLines.add({
                        'method': l['mode'],
                        'amount': amt,
                      });
                    }
                  }

                  if (paymentLines.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter at least one valid payment amount.')),
                    );
                    return;
                  }

                  final totalEntered = paymentLines.fold<double>(0.0, (sum, p) => sum + (p['amount'] as double));
                  if ((totalEntered - netAmount).abs() > 0.05) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Total payments (${CurrencyService.format(totalEntered)}) must equal Net Payable (${CurrencyService.format(netAmount)})'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final String finalMode = paymentLines.length > 1 ? 'SPLIT' : (paymentLines.first['method'] as String);

                  Navigator.pop(dialogContext, true);
                  setState(() => _loading = true);
                  try {
                    await ctrl.settleSaleBill(
                      saleId: saleId,
                      paymentMode: finalMode,
                      paymentLines: paymentLines,
                      amountPaid: netAmount,
                    );

                    // 1. Immediately fetch fresh settled sale details from server
                    final updatedDetails = await ctrl.getSaleDetails(saleId);
                    final updatedSale = Map<String, dynamic>.from(updatedDetails['details'] ?? updatedDetails);
                    final updatedOrder = SaleOrder.fromJson(updatedSale);

                    if (mounted) {
                      setState(() {
                        _selectedSale = updatedSale;
                        _selectedDetails = updatedDetails;
                        _selectedOrder = updatedOrder;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Bill #${updatedOrder.saleNo} Settled & Paid Successfully!'), backgroundColor: Colors.green),
                      );
                    }

                    // 2. Print the settled bill (guaranteed COMPLETED status and exact payments)
                    await _printSelected(updatedDetails);

                    // 3. Reload sales list so running badge / filters update
                    await _loadSales();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to settle bill: $e'), backgroundColor: Colors.red),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('Confirm Settlement & Print', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _printSelected([Map<String, dynamic>? specificDetails]) async {
    final detailsToUse = specificDetails ?? _selectedDetails;
    if (detailsToUse == null || !mounted) return;

    final reprintJson = Map<String, dynamic>.from(detailsToUse['details'] ?? detailsToUse);
    final paymentInfo = _paymentInfoText(detailsToUse);

    String currentBillFormat = reprintJson['bill_format']?.toString() ?? (_selectedOrder?.billFormat ?? 'THERMAL_80');
    try {
      final sysRes = await ApiClient.get('/api/inventory/settings');
      if (sysRes['data'] != null) {
        currentBillFormat = sysRes['data']['bill_format']?.toString() ?? currentBillFormat;
      }
    } catch (_) {}

    reprintJson['bill_format'] = currentBillFormat;
    if (detailsToUse['items'] != null) reprintJson['items'] = detailsToUse['items'];
    if (detailsToUse['repayments'] != null) reprintJson['repayments'] = detailsToUse['repayments'];
    final luckyVouchers = detailsToUse['lucky_draw_vouchers'] ?? detailsToUse['luckyDrawVouchers'];
    if (luckyVouchers != null) reprintJson['lucky_draw_vouchers'] = luckyVouchers;

    final reprintOrder = SaleOrder.fromJson(reprintJson);
    final settings = settingsCtrl.settings;

    if (settings?.printMode == 'DIRECT_DEFAULT') {
      try {
        final machineId = await LocalPreferences.getMachineId();
        final machineBillPrinter = DevicePrinterRouting.getBillPrinter(settings!, machineId).trim();
        final targetName = machineBillPrinter.isNotEmpty ? machineBillPrinter : settings.defaultPrinterName.trim();
        final targetUrl = settings.defaultPrinterUrl.trim();

        if (targetName.isNotEmpty || targetUrl.isNotEmpty) {
          final printers = await Printing.listPrinters();
          final printer = printers.cast<Printer?>().firstWhere(
                (p) =>
                    (targetName.isNotEmpty && p?.name.trim().toLowerCase() == targetName.toLowerCase()) ||
                    (targetUrl.isNotEmpty && p?.url == targetUrl),
                orElse: () => null,
              );
          if (printer != null) {
            final pdfBytes = await PosInvoicePrinter.buildSaleInvoicePdf(
              order: reprintOrder,
              property: propertyCtrl.data,
              copyCount: settings.billCopiesCount,
              termsAndConditions: paymentInfo,
            );
            await Printing.directPrintPdf(
              printer: printer,
              name: reprintOrder.saleNo,
              onLayout: (_) async => pdfBytes,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Bill sent to ${printer.name}')),
              );
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('Direct reprint error: $e');
      }
    }

    await showPdfPreviewDialog(
      context: context,
      name: reprintOrder.saleNo,
      pageFormat: PosInvoicePrinter.pageFormatFor(reprintOrder.billFormat),
      buildPdf: (_) async => await PosInvoicePrinter.buildSaleInvoicePdf(
        order: reprintOrder,
        property: propertyCtrl.data,
        copyCount: settingsCtrl.settings?.billCopiesCount ?? 1,
        termsAndConditions: paymentInfo,
      ),
    );
  }

  Future<void> _printCreditNote(Map<String, dynamic> creditNote) async {
    if (!mounted) return;
    try {
      setState(() => _loading = true);
      final pdfBytes = await PosInvoicePrinter.buildCreditNotePdf(
        creditNote: creditNote,
        property: propertyCtrl.data,
      );
      if (!mounted) return;
      await showPdfPreviewDialog(
        context: context,
        name: creditNote['credit_note_no']?.toString() ?? 'CreditNote',
        prebuiltBytes: pdfBytes,
        buildPdf: (_) async => pdfBytes,
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

    final itemsState = <int, Map<String, dynamic>>{};
    final rawItems = _selectedDetails?['items'] as List? ?? const [];
    for (final rawItem in rawItems) {
      final itemId = int.tryParse(rawItem['item_id']?.toString() ?? '') ?? 0;
      final originalQty = double.tryParse(rawItem['qty']?.toString() ?? '') ?? 0.0;
      final returnedQty = double.tryParse(rawItem['returned_qty']?.toString() ?? '') ?? 0.0;
      final remainingQty = originalQty - returnedQty;
      if (remainingQty <= 0) continue;

      final brand = rawItem['item']?['brand']?.toString() ?? '';
      itemsState[itemId] = {
        'selected': true,
        'qty': remainingQty,
        'maxQty': remainingQty,
        'name': '${rawItem['item_name']?.toString() ?? ''}${brand.isNotEmpty ? ' ($brand)' : ''}',
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
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setInnerState) {
          final allSelected = itemsState.values.every((val) => val['selected'] == true);

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.assignment_return_outlined, color: Colors.orange),
                SizedBox(width: 8),
                Text('Select Items to Return'),
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
                    onChanged: (val) {
                      setInnerState(() {
                        for (final key in itemsState.keys) {
                          itemsState[key]!['selected'] = val ?? false;
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      shrinkWrap: true,
                      children: itemsState.entries.map((entry) {
                        final state = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Checkbox(
                                value: state['selected'],
                                onChanged: (val) {
                                  setInnerState(() => state['selected'] = val ?? false);
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
                                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  enabled: state['selected'],
                                  onChanged: (val) {
                                    final parsed = double.tryParse(val) ?? 0.0;
                                    setInnerState(() => state['qty'] = parsed.clamp(0.0, state['maxQty']));
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
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final selectedEntries = itemsState.entries.where((e) => e.value['selected'] == true && e.value['qty'] > 0).toList();
                  if (selectedEntries.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select at least one item to return')),
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
      ),
    );

    if (result != true) return;

    final selectedItems = itemsState.entries
        .where((e) => e.value['selected'] == true && e.value['qty'] > 0)
        .map((e) => {'item_id': e.key, 'qty_to_return': e.value['qty']})
        .toList();

    setState(() => _loading = true);
    try {
      final saleId = int.parse('${_selectedSale!['id']}');
      await ctrl.returnSale(saleId: saleId, items: selectedItems);
      await _loadSales();
      if (_selectedSale != null) await _selectSale(_selectedSale!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale items returned successfully and stock reverted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to return sale: $e')));
      }
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
        paymentLines: (selectedPayment['payment_lines'] as List? ?? const [])
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(),
      );
      await _loadSales();
      if (_selectedSale != null) await _selectSale(_selectedSale!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment updated and ledger synced.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update payment mode: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _parseSplitPaymentsForOrder(SaleOrder order) {
    final List<Map<String, dynamic>> result = [];

    // 1. Check if backend provided explicit decoded payment_lines
    if (_selectedDetails != null && _selectedDetails!['payment_lines'] is List) {
      final List lines = _selectedDetails!['payment_lines'] as List;
      for (final item in lines) {
        if (item is Map) {
          final String method = (item['method'] ?? item['mode'] ?? 'CASH').toString().toUpperCase().trim();
          final double amt = double.tryParse((item['amount'] ?? 0).toString()) ?? 0.0;
          if (amt > 0) {
            result.add({'method': method, 'amount': amt});
          }
        }
      }
      if (result.isNotEmpty) return result;
    }

    // 2. Check payment_reference (with POSPAY: or JSON array)
    String ref = (order.paymentReference ?? _selectedDetails?['payment_reference'] ?? _selectedSale?['payment_reference'] ?? '').toString().trim();
    if (ref.startsWith('POSPAY:')) {
      ref = ref.substring(7).trim();
    }
    if (ref.startsWith('[') && ref.endsWith(']')) {
      try {
        final List decoded = jsonDecode(ref);
        for (final item in decoded) {
          if (item is Map) {
            final String method = (item['method'] ?? item['mode'] ?? 'CASH').toString().toUpperCase().trim();
            final double amt = double.tryParse((item['amount'] ?? 0).toString()) ?? 0.0;
            if (amt > 0) {
              result.add({'method': method, 'amount': amt});
            }
          }
        }
      } catch (_) {}
    }

    // 3. Fallback: Parse from notes ("Payment: CASH 2056.00, CARD 100.00" or "Payment: CASH 2056.00 | CARD 100.00")
    if (result.isEmpty) {
      final notesStr = (order.notes ?? _selectedDetails?['notes'] ?? _selectedSale?['notes'] ?? '').toString();
      if (notesStr.contains('Payment:')) {
        try {
          final pIdx = notesStr.indexOf('Payment:');
          if (pIdx != -1) {
            final pSub = notesStr.substring(pIdx + 8).split('\n').first;
            final parts = pSub.contains(',') ? pSub.split(',') : pSub.split('|');
            for (final part in parts) {
              final tokens = part.trim().split(RegExp(r'\s+'));
              if (tokens.length >= 2) {
                final String mode = tokens.first.toUpperCase().trim();
                final double amt = double.tryParse(tokens.last.replaceAll(',', '')) ?? 0.0;
                if (amt > 0) {
                  result.add({'method': mode, 'amount': amt});
                }
              }
            }
          }
        } catch (_) {}
      }
    }
    return result;
  }

  Future<Map<String, dynamic>?> _showPaymentModeDialog({
    required String initialMode,
    required double netAmount,
    required String? currentReference,
    required double currentPaid,
    required double currentDue,
  }) async {
    // 1. Initial list of payment lines
    final List<Map<String, dynamic>> lines = [];
    
    // Check if current bill has split lines already
    if (_selectedOrder != null) {
      final parsedSplits = _parseSplitPaymentsForOrder(_selectedOrder!);
      if (parsedSplits.isNotEmpty) {
        for (final s in parsedSplits) {
          lines.add({
            'mode': _availablePaymentMethods.contains(s['method']) ? s['method'] : 'CASH',
            'ctrl': TextEditingController(text: (s['amount'] as double).toStringAsFixed(2)),
          });
        }
      }
    }

    if (lines.isEmpty) {
      lines.add({
        'mode': _availablePaymentMethods.contains(initialMode.toUpperCase()) ? initialMode.toUpperCase() : 'CASH',
        'ctrl': TextEditingController(text: netAmount.toStringAsFixed(2)),
      });
    }

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setInnerState) {
          double totalAllocated = 0.0;
          for (final l in lines) {
            totalAllocated += double.tryParse((l['ctrl'] as TextEditingController).text) ?? 0.0;
          }
          final double diff = netAmount - totalAllocated;
          final bool isBalanced = diff.abs() <= 0.05;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.payments, color: Color(0xFF0B5CAD)),
                SizedBox(width: 8),
                Text('Modify Payment Mode & Splits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isBalanced ? Colors.green.shade50 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isBalanced ? Colors.green.shade300 : Colors.amber.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Net Bill Amount', style: TextStyle(fontSize: 11, color: Colors.black54)),
                              Text(CurrencyService.format(netAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(isBalanced ? 'Allocated (Matched)' : 'Remaining to Allocate', style: TextStyle(fontSize: 11, color: isBalanced ? Colors.green.shade800 : Colors.deepOrange)),
                              Text(
                                isBalanced ? CurrencyService.format(totalAllocated) : CurrencyService.format(diff),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isBalanced ? Colors.green.shade800 : Colors.deepOrange),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Payment Method(s):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    ...lines.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final line = entry.value;
                      final ctrl = line['ctrl'] as TextEditingController;
                      final currentM = line['mode'] as String;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: DropdownButtonFormField<String>(
                                value: _availablePaymentMethods.contains(currentM) ? currentM : 'CASH',
                                isDense: true,
                                decoration: InputDecoration(
                                  labelText: 'Method #${idx + 1}',
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                items: _availablePaymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12.5)))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setInnerState(() => line['mode'] = val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: TextField(
                                controller: ctrl,
                                decoration: const InputDecoration(
                                  labelText: 'Amount',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setInnerState(() {}),
                              ),
                            ),
                            if (lines.length > 1) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () {
                                  setInnerState(() => lines.removeAt(idx));
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0B5CAD),
                        side: const BorderSide(color: Color(0xFF0B5CAD)),
                      ),
                      onPressed: () {
                        final rem = diff > 0 ? diff : 0.0;
                        setInnerState(() {
                          lines.add({
                            'mode': lines.any((l) => l['mode'] == 'CARD') ? 'MPESA_TILL' : 'CARD',
                            'ctrl': TextEditingController(text: rem.toStringAsFixed(2)),
                          });
                        });
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('+ Add Payment Method (Split Bill)'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0B5CAD)),
                onPressed: () {
                  final List<Map<String, dynamic>> paymentLines = [];
                  for (final l in lines) {
                    final amt = double.tryParse((l['ctrl'] as TextEditingController).text) ?? 0.0;
                    if (amt > 0) {
                      paymentLines.add({
                        'method': l['mode'],
                        'amount': amt,
                      });
                    }
                  }

                  if (paymentLines.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter at least one valid payment amount.')),
                    );
                    return;
                  }

                  final totalEntered = paymentLines.fold<double>(0.0, (sum, p) => sum + (p['amount'] as double));
                  if ((totalEntered - netAmount).abs() > 0.05) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Total payments (${CurrencyService.format(totalEntered)}) must equal Net Payable (${CurrencyService.format(netAmount)})'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final String finalMode = paymentLines.length > 1 ? 'SPLIT' : (paymentLines.first['method'] as String);
                  Navigator.pop(dialogContext, {
                    'payment_mode': finalMode,
                    'payment_lines': paymentLines,
                  });
                },
                child: const Text('Save & Update Payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmtAmount(dynamic value) {
    final amount = double.tryParse(value?.toString() ?? '') ?? 0;
    return CurrencyService.format(amount);
  }

  String _paymentInfoText([Map<String, dynamic>? specificDetails]) {
    final detailsToUse = specificDetails ?? _selectedDetails;
    final saleToUse = specificDetails ?? _selectedSale;
    if (detailsToUse == null) return 'Thank you for your business.';

    final isUnsettledBill = _isUnsettled(saleToUse);
    if (isUnsettledBill) {
      return '⚠️ UNSETTLED RUNNING BILL • KOT / Bill Printed • Awaiting Cashier Settlement';
    }

    final reprintJson = Map<String, dynamic>.from(detailsToUse['details'] ?? detailsToUse);
    final orderToUse = SaleOrder.fromJson(reprintJson);

    final splits = _parseSplitPaymentsForOrder(orderToUse);
    if (splits.length > 1) {
      final splitDesc = splits.map((s) => '${s['method']}: ${CurrencyService.format(s['amount'])}').join(', ');
      return 'Payment Mode: SPLIT ($splitDesc) • Total Paid: ${CurrencyService.format(orderToUse.amountPaid)}';
    }

    final repayments = (detailsToUse['repayments'] as List? ?? const []).cast<dynamic>();
    if (repayments.isEmpty) {
      return 'Payment Mode: ${orderToUse.paymentMode} | Paid ${CurrencyService.format(orderToUse.amountPaid)} on ${DateFormat('dd-MMM-yyyy').format(orderToUse.saleDate)}';
    }
    return 'Payment Mode: ${orderToUse.paymentMode} (Repaid) | Paid ${CurrencyService.format(orderToUse.amountPaid)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Reprint / Modify Sales Bill & Running Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0B5CAD),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status Tabs / Segmented Control with Live Counts & Notification Badges
            Builder(
              builder: (context) {
                final int runningCount = _sales.where((s) => _isUnsettled(s)).length;
                final int completedCount = _sales.where((s) => (s['status'] ?? '').toString().toUpperCase() == 'COMPLETED').length;

                return Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton('ALL', 'All Bills & Orders (${_sales.length})'),
                      _buildTabButton('RUNNING', 'Running / Unsettled', badgeCount: runningCount),
                      _buildTabButton('COMPLETED', 'Completed & Settled ($completedCount)'),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Filter Toolbar (Professional Uniform 42px Controls, Zero Overflow)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // From Date Picker
                    InkWell(
                      onTap: () => _pickDate(isFrom: true),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF0B5CAD)),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('From Date', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600)),
                                Text(DateFormat('dd-MMM-yyyy').format(_fromDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // To Date Picker
                    InkWell(
                      onTap: () => _pickDate(isFrom: false),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event_outlined, size: 15, color: Color(0xFF0B5CAD)),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('To Date', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600)),
                                Text(DateFormat('dd-MMM-yyyy').format(_toDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Search Box
                    SizedBox(
                      width: 210,
                      height: 42,
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Bill / KOT / Cust / Phone...',
                          hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          prefixIcon: const Icon(Icons.search, size: 17, color: Color(0xFF0B5CAD)),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 15),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _loadSales();
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0B5CAD), width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        onSubmitted: (_) => _loadSales(),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Source Dropdown
                    Container(
                      width: 140,
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSourceFilter,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('All Sources')),
                            DropdownMenuItem(value: 'DINE_IN', child: Text('Dine-In')),
                            DropdownMenuItem(value: 'TAKEAWAY', child: Text('Takeaway')),
                            DropdownMenuItem(value: 'DELIVERY', child: Text('Delivery')),
                            DropdownMenuItem(value: 'COUNTER', child: Text('Counter')),
                            DropdownMenuItem(value: 'RESTAURANT', child: Text('Restaurant')),
                            DropdownMenuItem(value: 'APP', child: Text('App / Online')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedSourceFilter = val);
                              _loadSales();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Staff / Waiter Dropdown
                    Container(
                      width: 165,
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedUserFilter,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                          items: [
                            const DropdownMenuItem(value: 'ALL', child: Text('All Staff / Waiters')),
                            ..._usersList.map((u) => DropdownMenuItem(
                                  value: u.id.toString(),
                                  child: Text(
                                    u.fullName.isNotEmpty ? u.fullName : u.username,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedUserFilter = val);
                              _loadSales();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Filter Action Button
                    SizedBox(
                      height: 42,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0B5CAD),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: _loadSales,
                        icon: const Icon(Icons.filter_alt_outlined, size: 16),
                        label: const Text('Filter', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Reset Filters Button
                    SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () {
                          setState(() {
                            _searchCtrl.clear();
                            _customerPhoneCtrl.clear();
                            _selectedSourceFilter = 'ALL';
                            _selectedUserFilter = 'ALL';
                            _fromDate = DateTime.now();
                            _toDate = DateTime.now();
                          });
                          _loadSales();
                        },
                        icon: const Icon(Icons.refresh, size: 15),
                        label: const Text('Reset', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Main Body: Left Bills List + Right Order Detail Panel
            Expanded(
              child: Row(
                children: [
                  // Left Side List
                  Expanded(
                    flex: 4,
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: _loading && _sales.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : _sales.isEmpty
                              ? Center(
                                  child: Text(_orderStatusFilter == 'RUNNING'
                                      ? 'No open running orders awaiting settlement.'
                                      : 'No bills found matching filters.'),
                                )
                              : ListView.separated(
                                  itemCount: _sales.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final sale = _sales[index];
                                    final selected = sale['id'] == _selectedSale?['id'];
                                    final isUnsettledOrder = _isUnsettled(sale);
                                    final isReturned = sale['status'] == 'RETURNED';
                                    final hasReturns = isReturned || (sale['has_returns'] == true) || (sale['credit_notes'] != null && (sale['credit_notes'] as List).isNotEmpty);
                                    final rawSaleDate = sale['sale_date']?.toString();
                                    final saleDate = (rawSaleDate != null && rawSaleDate.trim().isNotEmpty)
                                        ? DateTimeService.instance.parseToConfiguredTimeZone(rawSaleDate)
                                        : null;

                                    return ListTile(
                                      selected: selected,
                                      selectedTileColor: const Color(0xFF0B5CAD).withOpacity(0.08),
                                      title: Row(
                                        children: [
                                          Text(
                                            '${sale['sale_no'] ?? 'Order #${sale['id']}'}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isReturned ? Colors.red.shade800 : (isUnsettledOrder ? Colors.deepOrange : Colors.black87),
                                              decoration: isReturned ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _buildSourceTag(sale['sale_source'], orderType: sale['order_type']),
                                          if (isReturned) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                              child: const Text('RETURNED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)),
                                            ),
                                          ] else if (hasReturns) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                                              child: const Text('CN ISSUED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                                            ),
                                          ],
                                          if (isUnsettledOrder) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                                              child: const Text('UNSETTLED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      subtitle: Text(
                                        '${sale['customer_name']?.toString().trim().isNotEmpty == true ? sale['customer_name'] : 'Walk-in'} • ${saleDate == null ? '--' : TimeZoneUtils.formatInTimeZone(saleDate, DateTimeService.instance.currentTimeZone, pattern: 'hh:mm a')} • ${_fmtAmount(sale['net_amount'])}${isReturned ? " • [RETURNED]" : ""}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      trailing: isUnsettledOrder
                                          ? ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                              onPressed: () {
                                                _selectSale(sale).then((_) => _showSettleBillDialog());
                                              },
                                              child: const Text('Settle Now', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                            )
                                          : const Icon(Icons.chevron_right),
                                      onTap: () => _selectSale(sale),
                                    );
                                  },
                                ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Right Side Details
                  Expanded(
                    flex: 6,
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: _selectedOrder == null
                          ? Center(
                              child: _loading
                                  ? const CircularProgressIndicator()
                                  : const Text('Select an order or bill to view details and settle.'),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header Card
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 8,
                                              children: [
                                                Text(
                                                  'Bill ${_selectedOrder!.saleNo}',
                                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B5CAD)),
                                                ),
                                                _buildSourceTag(_selectedOrder!.saleSource, orderType: _selectedOrder!.orderType),
                                                if (_selectedDetails?['status'] == 'RETURNED')
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                                    child: const Text('BILL FULLY RETURNED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                                                  )
                                                else if ((_selectedDetails?['credit_notes'] as List? ?? []).isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                                                    child: const Text('CREDIT NOTE ISSUED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                                                  ),
                                                if (_isUnsettled(_selectedSale))
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                                                    child: const Text('AWAITING SETTLEMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Date: ${TimeZoneUtils.formatInTimeZone(_selectedOrder!.saleDate, DateTimeService.instance.currentTimeZone, pattern: 'dd-MMM-yyyy hh:mm a')} • Customer: ${_selectedOrder!.customerName ?? 'Walk-in Customer'}',
                                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(_paymentInfoText(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Metric Cards
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _metricCard('Items', '${_selectedOrder!.items.length} Items'),
                                      _metricCard('Quantity', _selectedOrder!.totalQty.toStringAsFixed(2)),
                                      _metricCard('Sub Total', _fmtAmount(_selectedOrder!.subTotal)),
                                      if (_selectedOrder!.totalDiscount > 0) _metricCard('Discount', _fmtAmount(_selectedOrder!.totalDiscount)),
                                      _metricCard('Tax Amount', _fmtAmount(_selectedOrder!.totalTax)),
                                      _metricCard('Net Payable', _fmtAmount(_selectedOrder!.netAmount)),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  const Text('Bill Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const Divider(height: 8),

                                  // Items List
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: _selectedOrder!.items.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, idx) {
                                        final item = _selectedOrder!.items[idx];
                                        
                                        // Match returned quantity from raw items detail
                                        final rawItems = _selectedDetails?['items'] as List? ?? [];
                                        Map<String, dynamic>? rawMatch;
                                        for (final r in rawItems) {
                                          if (r is Map && (r['item_id']?.toString() == item.itemId.toString() || r['item_code']?.toString() == item.itemCode)) {
                                            rawMatch = Map<String, dynamic>.from(r);
                                            break;
                                          }
                                        }
                                        final double retQty = double.tryParse(rawMatch?['returned_qty']?.toString() ?? '0') ?? 0.0;
                                        final bool isFullyReturned = retQty >= item.qty && retQty > 0;
                                        final bool isPartiallyReturned = retQty > 0 && retQty < item.qty;

                                        return ListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          title: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.brand != null && item.brand!.isNotEmpty ? '${item.itemName} (${item.brand})' : item.itemName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    decoration: isFullyReturned ? TextDecoration.lineThrough : null,
                                                    color: isFullyReturned ? Colors.grey.shade600 : Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              if (isFullyReturned) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                                  child: Text('RETURNED (${retQty % 1 == 0 ? retQty.toInt() : retQty})', style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 10)),
                                                ),
                                              ] else if (isPartiallyReturned) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                                                  child: Text('RETURNED: ${retQty % 1 == 0 ? retQty.toInt() : retQty} / ${item.qty % 1 == 0 ? item.qty.toInt() : item.qty}', style: TextStyle(color: Colors.deepOrange.shade900, fontWeight: FontWeight.bold, fontSize: 10)),
                                                ),
                                              ],
                                            ],
                                          ),
                                          subtitle: Text(
                                            '${item.itemCode} • Qty ${item.qty.toStringAsFixed(2)} x ${CurrencyService.format(item.rate)}${retQty > 0 ? " • (Returned: ${retQty.toStringAsFixed(2)})" : ""}',
                                            style: TextStyle(fontSize: 11, color: isFullyReturned ? Colors.grey : Colors.black54),
                                          ),
                                          trailing: Text(
                                            CurrencyService.format(item.netAmount),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              decoration: isFullyReturned ? TextDecoration.lineThrough : null,
                                              color: isFullyReturned ? Colors.grey : Colors.black87,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),

                                  // Credit Notes / Returns section
                                  if ((_selectedDetails?['credit_notes'] as List? ?? []).isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    const Divider(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.assignment_return, size: 16, color: Colors.deepOrange),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Issued Credit Notes (${(_selectedDetails!['credit_notes'] as List).length})',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepOrange),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ...(_selectedDetails!['credit_notes'] as List).map((cn) {
                                      final cnMap = Map<String, dynamic>.from(cn);
                                      final cnNo = cnMap['credit_note_no'] ?? 'CN';
                                      final rawCnDate = cnMap['credit_note_date']?.toString();
                                      final cnDate = (rawCnDate != null && rawCnDate.isNotEmpty)
                                          ? DateTimeService.instance.parseToConfiguredTimeZone(rawCnDate)
                                          : null;
                                      final cnAmt = double.tryParse(cnMap['net_amount']?.toString() ?? '0') ?? 0.0;
                                      final cnStatus = (cnMap['status'] ?? 'Active').toString().toUpperCase();

                                      return Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.orange.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Credit Note #$cnNo',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepOrange),
                                                  ),
                                                  Text(
                                                    '${cnDate == null ? "" : DateFormat("dd-MMM-yyyy").format(cnDate)} • Amount: ${CurrencyService.format(cnAmt)} • Status: $cnStatus',
                                                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.deepOrange,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                minimumSize: const Size(0, 30),
                                              ),
                                              onPressed: () => _printCreditNote(cnMap),
                                              icon: const Icon(Icons.print, size: 14),
                                              label: const Text('Print Credit Note', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                  const SizedBox(height: 10),

                                  // Action Buttons
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.end,
                                    children: [
                                      if (_isUnsettled(_selectedSale)) ...[
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                                          onPressed: _showSettleBillDialog,
                                          icon: const Icon(Icons.point_of_sale, color: Colors.white, size: 18),
                                          label: const Text('Settle Bill Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                      if (_canReprintSales)
                                        FilledButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5CAD)),
                                          onPressed: _printSelected,
                                          icon: const Icon(Icons.print, size: 18),
                                          label: const Text('Reprint Bill / KOT'),
                                        ),
                                      if (_canModifySales)
                                        FilledButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                                          onPressed: _modifySelected,
                                          icon: const Icon(Icons.edit, size: 18),
                                          label: const Text('Modify Order'),
                                        ),
                                      if (_canModifySalesPayment && !_isUnsettled(_selectedSale))
                                        FilledButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                                          onPressed: _modifyPaymentSelected,
                                          icon: const Icon(Icons.payments, size: 18),
                                          label: const Text('Modify Payment'),
                                        ),
                                      if (_canModifySales && !_isUnsettled(_selectedSale) && _selectedDetails?['status'] != 'RETURNED')
                                        FilledButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                          onPressed: _showReturnDialog,
                                          icon: const Icon(Icons.assignment_return, size: 18),
                                          label: const Text('Return Items'),
                                        ),
                                    ],
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

  Widget _buildTabButton(String filterKey, String label, {int? badgeCount}) {
    final isSelected = _orderStatusFilter == filterKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _orderStatusFilter = filterKey);
          _loadSales();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0B5CAD) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (badgeCount != null && badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.amber.shade300 : Colors.deepOrange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      color: isSelected ? Colors.black87 : Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFFF6F8FC), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSourceTag(String? source, {String? orderType}) {
    final effective = (source != null && source.trim().isNotEmpty) ? source.trim().toUpperCase() : 'STORE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade200)),
      child: Text(effective, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
    );
  }
}

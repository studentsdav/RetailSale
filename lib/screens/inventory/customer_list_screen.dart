import 'dart:io';

import 'package:excel/excel.dart' as exc;
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/sales/sales_controller.dart';
import '../../models/inventory/item_model.dart';
import '../../models/inventory/sale_customer_model.dart';
import 'subscription_screen.dart';
import '../../widgets/sale_bill_preview_dialog.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final SalesController ctrl = SalesController();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _horizontalTableScroll = ScrollController();
  final ScrollController _verticalTableScroll = ScrollController();

  bool _loading = true;
  List<SaleCustomer> _customers = const [];
  final Map<String, bool> _hasSubscriptionByCustomer = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _horizontalTableScroll.dispose();
    _verticalTableScroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    await ctrl.loadInitialData();
    await ctrl.refreshCustomers(search: _searchCtrl.text.trim());
    await _refreshSubscriptionFlags(ctrl.customers);
    if (!mounted) return;
    setState(() {
      _customers = List<SaleCustomer>.from(ctrl.customers);
      _loading = false;
    });
  }

  Future<void> _loadCustomers([String search = '']) async {
    setState(() => _loading = true);
    await ctrl.refreshCustomers(search: search);
    await _refreshSubscriptionFlags(ctrl.customers);
    if (!mounted) return;
    setState(() {
      _customers = List<SaleCustomer>.from(ctrl.customers);
      _loading = false;
    });
  }

  Future<void> _refreshSubscriptionFlags(List<SaleCustomer> customers) async {
    _hasSubscriptionByCustomer.clear();
    for (final customer in customers) {
      final key = _customerKey(customer);
      if (key.isEmpty) continue;
      try {
        final rows = await ctrl.listCustomerSubscriptions(
          customerName: customer.customerName,
          customerPhone: customer.customerPhone,
          customerGstin: customer.customerGstin,
          date: DateTime.now(),
        );
        _hasSubscriptionByCustomer[key] = rows.isNotEmpty;
      } catch (_) {
        _hasSubscriptionByCustomer[key] = false;
      }
    }
  }

  String _customerKey(SaleCustomer customer) {
    if (customer.customerPhone.trim().isNotEmpty) return customer.customerPhone.trim();
    if (customer.customerGstin.trim().isNotEmpty) return customer.customerGstin.trim();
    return customer.customerName.trim();
  }

  Future<void> _openSubscriptionForm(
    SaleCustomer customer, {
    bool renewMode = false,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubscriptionScreen(
          initialCustomer: customer,
          renewMode: renewMode,
        ),
      ),
    );
    await _loadCustomers(_searchCtrl.text.trim());
  }

  Future<void> _showSubscriptionTransactions(SaleCustomer customer) async {
    final rows = await ctrl.listCustomerSubscriptions(
      customerName: customer.customerName,
      customerPhone: customer.customerPhone,
      customerGstin: customer.customerGstin,
      date: DateTime.now(),
    );
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Subscription Transactions - ${customer.customerName.isEmpty ? customer.customerPhone : customer.customerName}'),
        content: SizedBox(
          width: 920,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows.isEmpty
                  ? [const Text('No subscription transactions found.')]
                  : rows.map((subscription) {
                      final consumptions = (subscription['consumption'] as List? ?? const [])
                          .map((entry) => Map<String, dynamic>.from(entry))
                          .toList();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          title: Text('${subscription['item_name'] ?? ''}'),
                          subtitle: Text(
                            '${subscription['start_date']} to ${subscription['end_date']} | '
                            'Consumed ${subscription['consumed_days'] ?? 0}/${subscription['total_days'] ?? 0} | '
                            'Left ${subscription['days_left'] ?? 0}',
                          ),
                          children: consumptions.isEmpty
                              ? [const ListTile(title: Text('No raw logs available.'))]
                              : consumptions.map((row) {
                                  final saleNo = (row['sale_no'] ?? '').toString();
                                  final saleId = int.tryParse(row['sale_id']?.toString() ?? '') ?? 0;
                                  final consumedQty = row['covered_qty'] ?? 0;
                                  return ListTile(
                                    title: Text('${row['txn_date']} | Qty $consumedQty'),
                                    subtitle: Text('Rate ${row['rate']} | Bill ${saleNo.isEmpty ? '-' : saleNo}'),
                                    trailing: saleId > 0 && saleNo.isNotEmpty
                                        ? TextButton(
                                            onPressed: () async {
                                              final sale = await ctrl.getSaleDetails(saleId);
                                              if (!mounted) return;
                                              await showSaleBillPreviewDialog(
                                                context,
                                                sale: sale,
                                              );
                                            },
                                            child: const Text('Bill'),
                                          )
                                        : null,
                                  );
                                }).toList(),
                        ),
                      );
                    }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _addItemAdvance(SaleCustomer customer) async {
    if (ctrl.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading items, please try again.')),
      );
      return;
    }

    Item? selectedItem;
    final qtyCtrl = TextEditingController(text: '1');
    final rateCtrl = TextEditingController(text: '0');
    final amountCtrl = TextEditingController(text: '0');
    final noteCtrl = TextEditingController(text: 'Item advance');
    final dateCtrl = TextEditingController(
      text: DateFormat('dd-MMM-yyyy').format(DateTime.now()),
    );
    DateTime selectedDate = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add Item Advance - ${customer.customerName.isEmpty ? customer.customerPhone : customer.customerName}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownSearch<Item>(
                    selectedItem: selectedItem,
                    items: (filter, _) async {
                      final q = filter.trim().toLowerCase();
                      if (q.isEmpty) return ctrl.items.take(20).toList();
                      return ctrl.items.where((item) {
                        return item.itemCode.toLowerCase().contains(q) ||
                            item.itemName.toLowerCase().contains(q) ||
                            item.barcode.toLowerCase().contains(q);
                      }).take(20).toList();
                    },
                    itemAsString: (item) => '${item.itemCode} - ${item.itemName}',
                    compareFn: (a, b) => a.id == b.id,
                    popupProps: const PopupProps.menu(showSearchBox: true),
                    decoratorProps: const DropDownDecoratorProps(
                      decoration: InputDecoration(labelText: 'Item'),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedItem = value;
                        final rate = value == null
                            ? 0
                            : (value.retailSalePrice > 0
                                ? value.retailSalePrice
                                : value.rate);
                        rateCtrl.text = rate.toStringAsFixed(rate % 1 == 0 ? 0 : 2);
                        final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                        final amount = qty * rate;
                        amountCtrl.text = amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Advance Qty',
                      helperText: 'Example: 30 qty for 1200 amount',
                    ),
                    onChanged: (_) {
                      final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                      final rate = double.tryParse(rateCtrl.text.trim()) ?? 0;
                      amountCtrl.text = (qty * rate).toStringAsFixed(2);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Rate',
                    ),
                    onChanged: (_) {
                      final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                      final rate = double.tryParse(rateCtrl.text.trim()) ?? 0;
                      amountCtrl.text = (qty * rate).toStringAsFixed(2);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Advance Amount',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dateCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Advance Date',
                      suffixIcon: Icon(Icons.date_range),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                          dateCtrl.text = DateFormat('dd-MMM-yyyy').format(picked);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: 'Note'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedItem == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && selectedItem != null) {
      final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
      if (qty > 0) {
        await ctrl.createItemAdvance(
          customerName: customer.customerName,
          customerPhone: customer.customerPhone,
          customerGstin: customer.customerGstin,
          itemId: selectedItem!.id,
          qty: qty,
          advanceDate: selectedDate,
          rate: amount > 0 ? amount / qty : 0,
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Advance saved for ${selectedItem!.itemName}',
              ),
            ),
          );
        }
      }
    }

    qtyCtrl.dispose();
    rateCtrl.dispose();
    amountCtrl.dispose();
    noteCtrl.dispose();
    dateCtrl.dispose();
  }

  Future<void> _showAdvanceHistory(SaleCustomer customer) async {
    final advances = await ctrl.listItemAdvances(
      customerName: customer.customerName,
      customerPhone: customer.customerPhone,
      customerGstin: customer.customerGstin,
    );

    if (!mounted) return;

    double totalQty = 0;
    double totalLeft = 0;
    for (final row in advances) {
      totalQty += double.tryParse(row['original_qty']?.toString() ?? '') ?? 0;
      totalLeft += double.tryParse(
            row['remaining_qty_total']?.toString() ??
                row['available_qty']?.toString() ??
                '',
          ) ??
          0;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Item Advance History - ${customer.customerName.isEmpty ? customer.customerPhone : customer.customerName}'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer: ${_customerKey(customer)}'),
                const SizedBox(height: 8),
                Text(
                  'Total Qty: ${totalQty.toStringAsFixed(totalQty % 1 == 0 ? 0 : 2)} | Left Qty: ${totalLeft.toStringAsFixed(totalLeft % 1 == 0 ? 0 : 2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Divider(height: 22),
                if (advances.isEmpty)
                  const Text('No item advance history found.')
                else
                  ...advances.map((row) {
                    final itemInfo = row['item'];
                    final itemName = itemInfo is Map
                        ? (itemInfo['item_name'] ?? '').toString()
                        : (row['item_name'] ?? '').toString();
                    final itemCode = (row['item_code'] ?? '').toString();
                    final qty = double.tryParse(row['original_qty']?.toString() ?? '') ?? 0;
                    final left = double.tryParse(
                          row['remaining_qty_total']?.toString() ??
                              row['available_qty']?.toString() ??
                              '',
                        ) ??
                        0;
                    final rate = double.tryParse(row['rate']?.toString() ?? '') ?? 0;
                    final amount = qty * rate;
                    final dt = DateTime.tryParse((row['advance_date'] ?? '').toString());
                    final dateText = dt == null ? '--' : DateFormat('dd-MMM-yyyy').format(dt);
                    final note = (row['note'] ?? '').toString();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        title: Text('$itemName${itemCode.isEmpty ? '' : ' ($itemCode)'}'),
                        subtitle: Text(
                          '$dateText | Qty ${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2)} | Left ${left.toStringAsFixed(left % 1 == 0 ? 0 : 2)} | Amount ${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)} | Rate ${rate.toStringAsFixed(2)}${note.isEmpty ? '' : ' | $note'}',
                        ),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            IconButton(
                              tooltip: 'Edit advance',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editItemAdvance(customer, row),
                            ),
                            IconButton(
                              tooltip: 'Delete advance',
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteItemAdvance(customer, row),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _editItemAdvance(SaleCustomer customer, Map<String, dynamic> row) async {
    final id = int.tryParse(row['id']?.toString() ?? '') ?? 0;
    if (id <= 0) return;
    if (ctrl.items.isEmpty) {
      await ctrl.loadInitialData();
    }
    if (ctrl.items.isEmpty) return;

    final itemId = int.tryParse(row['item_id']?.toString() ?? '') ?? 0;
    Item? selectedItem;
    for (final item in ctrl.items) {
      if (item.id == itemId) {
        selectedItem = item;
        break;
      }
    }
    selectedItem ??= ctrl.items.first;

    final qtyCtrl = TextEditingController(text: (row['original_qty'] ?? '1').toString());
    final rateCtrl = TextEditingController(text: (row['rate'] ?? '0').toString());
    final amountCtrl = TextEditingController(
      text: ((double.tryParse(qtyCtrl.text) ?? 0) * (double.tryParse(rateCtrl.text) ?? 0)).toStringAsFixed(2),
    );
    final noteCtrl = TextEditingController(text: (row['note'] ?? '').toString());
    final dateCtrl = TextEditingController(text: (row['advance_date'] ?? '').toString());
    DateTime selectedDate = DateTime.tryParse(dateCtrl.text) ?? DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Item Advance'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownSearch<Item>(
                    selectedItem: selectedItem,
                    items: (filter, _) async => ctrl.items,
                    itemAsString: (item) => '${item.itemCode} - ${item.itemName}',
                    compareFn: (a, b) => a.id == b.id,
                    popupProps: const PopupProps.menu(showSearchBox: true),
                    decoratorProps: const DropDownDecoratorProps(
                      decoration: InputDecoration(labelText: 'Item'),
                    ),
                    onChanged: (value) => setDialogState(() => selectedItem = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Advance Qty'),
                    onChanged: (_) {
                      final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                      final rate = double.tryParse(rateCtrl.text.trim()) ?? 0;
                      amountCtrl.text = (qty * rate).toStringAsFixed(2);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Rate'),
                    onChanged: (_) {
                      final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                      final rate = double.tryParse(rateCtrl.text.trim()) ?? 0;
                      amountCtrl.text = (qty * rate).toStringAsFixed(2);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Advance Amount'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dateCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Advance Date'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                          dateCtrl.text = DateFormat('dd-MMM-yyyy').format(picked);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: 'Note'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedItem == null ? null : () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && selectedItem != null) {
      await ctrl.updateItemAdvance(
        id: id,
        customerName: customer.customerName,
        customerPhone: customer.customerPhone,
        customerGstin: customer.customerGstin,
        itemId: selectedItem!.id,
        qty: double.tryParse(qtyCtrl.text.trim()) ?? 0,
        advanceDate: selectedDate,
        rate: double.tryParse(rateCtrl.text.trim()) ?? 0,
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item advance updated')),
        );
      }
      await _loadCustomers(_searchCtrl.text.trim());
    }

    qtyCtrl.dispose();
    rateCtrl.dispose();
    amountCtrl.dispose();
    noteCtrl.dispose();
    dateCtrl.dispose();
  }

  Future<void> _deleteItemAdvance(SaleCustomer customer, Map<String, dynamic> row) async {
    final id = int.tryParse(row['id']?.toString() ?? '') ?? 0;
    if (id <= 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Item Advance'),
        content: Text('Cancel ${row['item_name'] ?? row['item_code'] ?? 'this item advance'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ctrl.deleteItemAdvance(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item advance cancelled')),
    );
    await _loadCustomers(_searchCtrl.text.trim());
  }

  Future<void> _addCustomer() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final gstCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Customer'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Customer Name')),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
                decoration: const InputDecoration(labelText: 'Contact No'),
              ),
              const SizedBox(height: 12),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 12),
              TextField(controller: gstCtrl, decoration: const InputDecoration(labelText: 'GST No')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final phone = phoneCtrl.text.trim();
              if (phone.isNotEmpty) {
                final exists = ctrl.customers.any((c) => c.customerPhone.trim() == phone);
                if (exists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('This phone number is already registered.')),
                  );
                  return;
                }
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      await ctrl.createCustomer(
        customerName: nameCtrl.text.trim(),
        customerPhone: phoneCtrl.text.trim(),
        customerAddress: addressCtrl.text.trim(),
        customerGstin: gstCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer created')),
        );
      }
      await _loadCustomers(_searchCtrl.text.trim());
    }

    nameCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    gstCtrl.dispose();
  }

  Future<void> _exportCustomerListExcel() async {
    final excel = exc.Excel.createExcel();
    final sheet = excel['Customers'];
    const headers = ['Name', 'Number', 'Address', 'GSTIN'];

    for (var i = 0; i < headers.length; i++) {
      sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = exc.TextCellValue(headers[i]);
    }

    for (var row = 0; row < _customers.length; row++) {
      final customer = _customers[row];
      final values = [
        customer.customerName.trim().isEmpty
            ? 'Walk-in Customer'
            : customer.customerName.trim(),
        customer.customerPhone,
        customer.customerAddress,
        customer.customerGstin,
      ];

      for (var col = 0; col < values.length; col++) {
        sheet
            .cell(
              exc.CellIndex.indexByColumnRow(
                columnIndex: col,
                rowIndex: row + 1,
              ),
            )
            .value = exc.TextCellValue(values[col]);
      }
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/customer_list.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    await OpenFile.open(file.path);
  }

  pw.Document _buildCustomerPdf() {
    final pdf = pw.Document();
    final rows = _customers
        .map(
          (customer) => [
            customer.customerName.trim().isEmpty
                ? 'Walk-in Customer'
                : customer.customerName.trim(),
            customer.customerPhone,
            customer.customerAddress,
            customer.customerGstin,
          ],
        )
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Text(
            'Customer List',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: const ['Name', 'Number', 'Address', 'GSTIN'],
            data: rows,
          ),
        ],
      ),
    );

    return pdf;
  }

  Future<void> _exportCustomerListPdf() async {
    final pdf = _buildCustomerPdf();
    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/customer_list.pdf');
    await file.writeAsBytes(bytes, flush: true);
    await OpenFile.open(file.path);
  }

  Future<void> _printCustomerList() async {
    final pdf = _buildCustomerPdf();
    await Printing.layoutPdf(name: 'Customer_List', onLayout: (format) async => pdf.save());
  }

  Future<void> _editCustomer(SaleCustomer customer) async {
    final nameCtrl = TextEditingController(text: customer.customerName);
    final phoneCtrl = TextEditingController(text: customer.customerPhone);
    final addressCtrl = TextEditingController(text: customer.customerAddress);
    final gstCtrl = TextEditingController(text: customer.customerGstin);
    var hasExistingBills = false;

    try {
      final searchKey = customer.customerPhone.trim().isNotEmpty
          ? customer.customerPhone.trim()
          : customer.customerName.trim();
      if (searchKey.isNotEmpty) {
        final sales = await ctrl.listSales(search: searchKey, latestOnly: false);
        hasExistingBills = sales.any((sale) {
          final saleStatus = (sale['status'] ?? '').toString().toUpperCase();
          if (saleStatus == 'CUSTOMER') return false;
          final salePhone = (sale['customer_phone'] ?? '').toString().trim();
          final saleName = (sale['customer_name'] ?? '').toString().trim();
          if (customer.customerPhone.trim().isNotEmpty) {
            return salePhone == customer.customerPhone.trim();
          } else {
            return saleName.toLowerCase() == customer.customerName.trim().toLowerCase();
          }
        });
      }
    } catch (_) {
      hasExistingBills = false;
    }

    final hasSubscription = _hasSubscriptionByCustomer[_customerKey(customer)] ?? false;
    final isPhoneLocked = hasExistingBills || hasSubscription;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Customer'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Customer Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                readOnly: isPhoneLocked,
                keyboardType: TextInputType.phone,
                inputFormatters: isPhoneLocked
                    ? null
                    : [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(15),
                      ],
                decoration: InputDecoration(
                  labelText: 'Contact No',
                  helperText: isPhoneLocked
                      ? 'Phone number is locked because bills or subscriptions exist.'
                      : 'Phone number can be updated because no bills or subscriptions exist.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gstCtrl,
                decoration: const InputDecoration(labelText: 'GST No'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ctrl.updateCustomer(
                customer.id,
                customerName: nameCtrl.text.trim(),
                customerPhone: phoneCtrl.text.trim(),
                customerAddress: addressCtrl.text.trim(),
                customerGstin: gstCtrl.text.trim(),
              );
              if (!mounted) return;
              Navigator.pop(dialogContext);
              await _loadCustomers(_searchCtrl.text.trim());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Customer updated successfully')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCustomer(SaleCustomer customer) async {
    var hasExistingBills = false;
    setState(() => _loading = true);
    try {
      final searchKey = customer.customerPhone.trim().isNotEmpty
          ? customer.customerPhone.trim()
          : customer.customerName.trim();
      if (searchKey.isNotEmpty) {
        final sales = await ctrl.listSales(search: searchKey, latestOnly: false);
        hasExistingBills = sales.any((sale) {
          final saleStatus = (sale['status'] ?? '').toString().toUpperCase();
          if (saleStatus == 'CUSTOMER') return false;
          final salePhone = (sale['customer_phone'] ?? '').toString().trim();
          final saleName = (sale['customer_name'] ?? '').toString().trim();
          if (customer.customerPhone.trim().isNotEmpty) {
            return salePhone == customer.customerPhone.trim();
          } else {
            return saleName.toLowerCase() == customer.customerName.trim().toLowerCase();
          }
        });
      }
    } catch (_) {
      hasExistingBills = false;
    }
    setState(() => _loading = false);

    final hasSubscription = _hasSubscriptionByCustomer[_customerKey(customer)] ?? false;
    if (hasExistingBills || hasSubscription) {
      if (!mounted) return;
      String message = 'This customer cannot be deleted because they have associated bills.';
      if (hasSubscription && hasExistingBills) {
        message = 'This customer cannot be deleted because they have associated bills and subscriptions.';
      } else if (hasSubscription) {
        message = 'This customer cannot be deleted because they have associated subscriptions.';
      }
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cannot Delete Customer'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text(
          'Delete ${customer.customerName.trim().isEmpty ? customer.customerPhone : customer.customerName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ctrl.deleteCustomer(customer.id);
      if (!mounted) return;
      await _loadCustomers(_searchCtrl.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer deleted successfully')),
      );
    } catch (_) {
      // ApiClient already shows server message; no-op here to avoid duplicate snackbars.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F2),
      appBar: AppBar(
        title: const Text('Customer List'),
        actions: [
          Tooltip(
            message: 'Refresh customer list',
            child: IconButton(
              onPressed: () => _loadCustomers(_searchCtrl.text.trim()),
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 16,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Search customer',
                        hintText: 'Name, phone, address, GSTIN',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: _loadCustomers,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      _searchCtrl.clear();
                      _loadCustomers('');
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear All'),
                  ),
                  Tooltip(
                    message: 'Export customer list to Excel',
                    child: OutlinedButton.icon(
                      onPressed:
                          _customers.isEmpty ? null : _exportCustomerListExcel,
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('Excel'),
                    ),
                  ),
                  Tooltip(
                    message: 'Export customer list to PDF',
                    child: OutlinedButton.icon(
                      onPressed:
                          _customers.isEmpty ? null : _exportCustomerListPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF'),
                    ),
                  ),
                  Tooltip(
                    message: 'Print customer list',
                    child: OutlinedButton.icon(
                      onPressed: _customers.isEmpty ? null : _printCustomerList,
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Print'),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _addCustomer,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('New Customer'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x120F172A),
                      blurRadius: 18,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _customers.isEmpty
                        ? const Center(child: Text('No customers found'))
                        : Scrollbar(
                            controller: _verticalTableScroll,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _verticalTableScroll,
                              child: Scrollbar(
                                controller: _horizontalTableScroll,
                                thumbVisibility: true,
                                notificationPredicate: (notification) =>
                                    notification.metrics.axis ==
                                    Axis.horizontal,
                                child: SingleChildScrollView(
                                  controller: _horizontalTableScroll,
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth:
                                          MediaQuery.of(context).size.width -
                                              96,
                                    ),
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(
                                        const Color(0xFFFFF1E6),
                                      ),
                                      dataRowMinHeight: 76,
                                      dataRowMaxHeight: 98,
                                      columnSpacing: 18,
                                      columns: const [
                                        DataColumn(label: Text('Name')),
                                        DataColumn(label: Text('Number')),
                                        DataColumn(label: Text('Address')),
                                        DataColumn(label: Text('GSTIN')),
                                        DataColumn(label: Text('Action')),
                                      ],
                                      rows:
                                          List.generate(_customers.length, (index) {
                                        final customer = _customers[index];
                                        final hasSubscription =
                                            _hasSubscriptionByCustomer[
                                                    _customerKey(customer)] ==
                                                true;
                                        final shade = index.isEven
                                            ? const Color(0xFFFFFBF7)
                                            : const Color(0xFFF8FAFC);
                                        return DataRow(
                                          color: WidgetStateProperty.all(shade),
                                          cells: [
                                            DataCell(
                                              Text(
                                                customer.customerName
                                                        .trim()
                                                        .isEmpty
                                                    ? 'Walk-in Customer'
                                                    : customer.customerName
                                                        .trim(),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            DataCell(Text(customer.customerPhone)),
                                            DataCell(
                                              SizedBox(
                                                width: 300,
                                                child:
                                                    Text(customer.customerAddress),
                                              ),
                                            ),
                                            DataCell(Text(customer.customerGstin)),
                                            DataCell(
                                              SizedBox(
                                                width: 860,
                                                child: Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: [
                                              Tooltip(
                                                message:
                                                    'Use this customer in current bill',
                                                child: FilledButton.icon(
                                                  onPressed: () => Navigator.pop(
                                                    context,
                                                    customer,
                                                  ),
                                                  icon: const Icon(
                                                    Icons.check_circle_outline,
                                                    size: 18,
                                                  ),
                                                  label: const Text('Use'),
                                                  style: FilledButton.styleFrom(
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Tooltip(
                                                message: 'Edit customer details',
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _editCustomer(customer),
                                                  icon: const Icon(
                                                    Icons.edit_outlined,
                                                    size: 18,
                                                  ),
                                                  label: const Text('Edit'),
                                                  style: OutlinedButton.styleFrom(
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (!hasSubscription)
                                                Tooltip(
                                                  message: 'Delete customer',
                                                  child: OutlinedButton.icon(
                                                    onPressed: () =>
                                                        _deleteCustomer(customer),
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.red,
                                                      size: 18,
                                                    ),
                                                    label: const Text('Delete'),
                                                    style: OutlinedButton.styleFrom(
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 10,
                                                        vertical: 8,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              Tooltip(
                                                message: 'Start a subscription',
                                                child: FilledButton.tonalIcon(
                                                  onPressed: () =>
                                                      _openSubscriptionForm(
                                                    customer,
                                                  ),
                                                  icon: const Icon(
                                                    Icons.water_drop_outlined,
                                                    size: 18,
                                                  ),
                                                  label: const Text(
                                                    'Subscription',
                                                  ),
                                                  style: FilledButton.styleFrom(
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (hasSubscription)
                                                Tooltip(
                                                  message:
                                                      'Renew subscription cycle',
                                                  child: FilledButton.tonalIcon(
                                                    onPressed: () =>
                                                        _openSubscriptionForm(
                                                      customer,
                                                      renewMode: true,
                                                    ),
                                                    icon: const Icon(
                                                      Icons.restart_alt_outlined,
                                                      size: 18,
                                                    ),
                                                    label: const Text('Renew'),
                                                    style:
                                                        FilledButton.styleFrom(
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 10,
                                                        vertical: 8,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (hasSubscription)
                                                Tooltip(
                                                  message:
                                                      'View subscription transactions',
                                                  child: OutlinedButton.icon(
                                                    onPressed: () =>
                                                        _showSubscriptionTransactions(
                                                      customer,
                                                    ),
                                                    icon: const Icon(
                                                      Icons.receipt_long_outlined,
                                                      size: 18,
                                                    ),
                                                    label: const Text('History'),
                                                    style:
                                                        OutlinedButton.styleFrom(
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 10,
                                                        vertical: 8,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

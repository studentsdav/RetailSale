import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/inventory/supplier_controller.dart';
import '../../controllers/purchase/purchase_order_modify_controller.dart';
import '../../models/auth/permission_service.dart';
import '../../controllers/settings/property_info_controller.dart'
    show PropertyInfoController;
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/common/property_info_model.dart';
import '../../models/inventory/purchase_order_model.dart';
import '../../models/inventory/supplier_model.dart';

class PurchaseOrderModifyScreen extends StatefulWidget {
  const PurchaseOrderModifyScreen({super.key});

  @override
  State<PurchaseOrderModifyScreen> createState() =>
      _PurchaseOrderModifyScreenState();
}

class _PurchaseOrderModifyScreenState extends State<PurchaseOrderModifyScreen> {
  final ctrl = PurchaseOrderModifyController();
  bool get _canReprint =>
      PermissionService.can('REPRINT_PURCHASE') || PermissionService.can('MODIFY_PURCHASE');
  bool get _canModify => PermissionService.can('MODIFY_PURCHASE');
  final supplierCtrl = SupplierController();
  final propertyCtrl = PropertyInfoController();
  PropertyInfo? propertyInfo;
  DateTime selectedDate = DateTime.now();
  int? selectedPoId;
  int? supplierId;

  List items = [];

  int? _singleMatchOrNull(Iterable<int?> values, int? selected) {
    if (selected == null) return null;
    final matches = values.where((value) => value == selected).length;
    return matches == 1 ? selected : null;
  }

  @override
  void initState() {
    super.initState();
    _loadPOs();
    _loadPropertyInfo();
    supplierCtrl.load();
  }

  Future<void> _loadPropertyInfo() async {
    await propertyCtrl.load();
    setState(() {
      propertyInfo = propertyCtrl.data;
    });
  }

  Future<void> _loadPOs() async {
    final date = DateFormat('yyyy-MM-dd').format(selectedDate);
    await ctrl.loadPOByDate(date);
    setState(() {
      selectedPoId = null;
      supplierId = null;
      items = [];
    });
  }

  Future<void> _loadDetails(int id) async {
    setState(() {
      selectedPoId = id;
      supplierId = null;
      items = [];
    });

    await ctrl.loadPODetails(id);

    setState(() {
      supplierId = ctrl.poDetails['supplier_id'];
      items = List.from(ctrl.items);
    });
  }

  double get total {
    double t = 0;
    for (var i in items) {
      t += (double.parse(i['qty'].toString()) *
          double.parse(i['rate'].toString()));
    }
    return t;
  }

  Future<void> _save() async {
    if (selectedPoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select Purchase Order")),
      );
      return;
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("At least 1 item is required")),
      );
      return;
    }

    await ctrl.modifyPO(
      poId: selectedPoId!,
      supplierId: supplierId!,
      items: items,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Purchase Order Updated")),
    );
  }

  void _msg(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _reprint() {
    if (selectedPoId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Select PO first")));
      return;
    }

    reprintPO(selectedPoId!);
  }

  Future<void> _cancelPo() async {
    if (selectedPoId == null) {
      _msg("Select PO first");
      return;
    }

    final status = ctrl.poDetails['status'] ?? ''.toUpperCase();
    if (status == 'CLOSED' || status == 'CANCELLED') {
      _msg("Only open or partial PO can be cancelled");
      return;
    }

    try {
      await ctrl.cancelPO(selectedPoId!);
      _msg("Purchase Order cancelled");
      await _loadPOs();
      setState(() {
        selectedPoId = null;
        supplierId = null;
        items = [];
      });
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> reprintPO(int poId) async {
    final res = await ApiClient.get(
      '${ApiEndpoints.purchaseOrders}/$poId/print',
    );

    if (res['success'] != true) {
      throw Exception("Failed to fetch PO");
    }

    final po = PurchaseOrder.fromJson(res['data']);

    await _printPurchaseOrder(po);
  }

  Future<void> _printPurchaseOrder(PurchaseOrder po) async {
    final pdf = pw.Document();

    final supplier = supplierCtrl.list.firstWhere((e) => e.id == po.supplierId);

    final subTotal =
        po.items.fold<double>(0, (sum, item) => sum + (item.qty * item.rate));
    final totalGST = po.items.fold<double>(
      0,
      (sum, item) => sum + ((item.qty * item.rate) * (item.tax / 100)),
    );
    final grandTotal = subTotal + totalGST;

    final property = propertyInfo;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          /// ================= HEADER =================

          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      property?.propertyName ?? '',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text("${property?.address}"),
                    pw.Text("Mobile: ${property?.mobile}"),
                    pw.Text("Email: ${property?.email}"),
                    pw.Text("GSTIN: ${property?.gstNo}"),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Text(
                  "PURCHASE ORDER",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "REPRINT",
              style: pw.TextStyle(
                color: PdfColors.red,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.SizedBox(height: 20),

          /// ================= SUPPLIER & PO INFO =================
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("To,",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(supplier.supplierName),
                    pw.Text(supplier.address ?? ""),
                    pw.Text("GSTIN: ${supplier.gstin ?? ""}"),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("PO No: ${po.poNo}"),
                  pw.Text(
                      "Date: ${DateFormat('dd-MMM-yyyy').format(po.createdAt ?? po.poDate)}"),
                  pw.Text(
                      "Time: ${DateFormat('hh:mm a').format(po.createdAt ?? DateTime.now())}"),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= ITEM TABLE =================
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(1),
              6: const pw.FlexColumnWidth(1),
              7: const pw.FlexColumnWidth(1),
              8: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _tableCell("S.No", bold: true),
                  _tableCell("Item"),
                  _tableCell("Brand"),
                  _tableCell("Unit"),
                  _tableCell("Qty"),
                  _tableCell("Rate"),
                  _tableCell("GST %"),
                  _tableCell("GST Amt"),
                  _tableCell("Amount"),
                ],
              ),
              ...List.generate(po.items.length, (i) {
                final item = po.items[i];
                final gstAmount = (item.qty * item.rate) * (item.tax / 100);
                return pw.TableRow(
                  children: [
                    _tableCell("${i + 1}"),
                    _tableCell(item.itemName),
                    _tableCell(item.brand),
                    _tableCell(item.unit),
                    _tableCell(item.qty.toString()),
                    _tableCell(item.rate.toStringAsFixed(2)),
                    _tableCell(item.tax.toStringAsFixed(2)),
                    _tableCell(gstAmount.toStringAsFixed(2)),
                    _tableCell(item.amount.toStringAsFixed(2)),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= TOTAL SECTION =================
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 250,
              child: pw.Column(
                children: [
                  _totalRow("Sub Total", subTotal),
                  _totalRow("GST", totalGST),
                  pw.Divider(),
                  _totalRow("Grand Total", grandTotal, bold: true),
                ],
              ),
            ),
          ),

          pw.SizedBox(height: 30),

          /// ================= FOOTER =================
          pw.Text(
            "Thank you for your business. Please supply the above items as per agreed terms.",
          ),

          pw.SizedBox(height: 40),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                children: [
                  pw.Text("Authorized Signature"),
                  pw.SizedBox(height: 30),
                  pw.Text(property!.legalName,
                      style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text("Supplier Signature"),
                  pw.SizedBox(height: 30),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(name: 'PO_${po.poNo}', onLayout: (format) async => pdf.save());
  }

  pw.Widget _tableCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _totalRow(String label, double value, {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(value.toStringAsFixed(2),
            style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedPoValue = _singleMatchOrNull(
      ctrl.purchaseOrders.map((e) => e['id'] as int?),
      selectedPoId,
    );
    final selectedSupplierValue = _singleMatchOrNull(
      supplierCtrl.list.map((s) => s.id),
      supplierId,
    );

    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        title: const Text("Modify Purchase Order"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            /// ================= FILTER BAR =================
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    /// DATE
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Date",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 38,
                          width: 160,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 14),
                            label: Text(
                              DateFormat('dd-MMM-yyyy').format(selectedDate),
                              style: const TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );

                              if (d != null) {
                                selectedDate = d;
                                await _loadPOs();
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    /// PO
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Purchase Order",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 38,
                          width: 220,
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('po-$selectedPoId'),
                            initialValue: selectedPoValue,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: ctrl.purchaseOrders
                                .map((e) => DropdownMenuItem<int>(
                                      value: e['id'],
                                      child: Text(e['po_no'], style: const TextStyle(fontSize: 13)),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) _loadDetails(v);
                            },
                          ),
                        ),
                      ],
                    ),

                    /// SUPPLIER
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Supplier",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 38,
                          width: 260,
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('po-supplier-$selectedPoId-$supplierId'),
                            initialValue: selectedSupplierValue,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: supplierCtrl.list
                                .map((Supplier s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(s.supplierName, style: const TextStyle(fontSize: 13)),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                supplierId = v;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// ================= MODERN GRID =================
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(scheme.surfaceContainerHighest),
                        columnSpacing: 40,
                        columns: const [
                          DataColumn(label: Text("S.No")),
                          DataColumn(label: Text("Item")),
                          DataColumn(label: Text("Qty")),
                          DataColumn(label: Text("Rate")),
                          DataColumn(label: Text("Amount")),
                          DataColumn(label: Text("")),
                        ],
                        rows: List.generate(items.length, (i) {
                          final item = items[i];

                          final amount = (double.parse(item['qty'].toString()) *
                              double.parse(item['rate'].toString()));

                          return DataRow(
                            color: WidgetStateProperty.resolveWith((states) {
                              if (i.isEven) {
                                return const Color(0xffFAFBFD);
                              }
                              return Colors.white;
                            }),
                            cells: [
                              DataCell(Text("${i + 1}")),
                              DataCell(Text(
                                '${item['item_name']}${item['brand'] != null && item['brand'].toString().isNotEmpty ? ' (${item['brand']})' : ''}'
                              )),
                              DataCell(
                                SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    key: ValueKey(
                                      'po-$selectedPoId-${item['id'] ?? item['item_code'] ?? item['item_name']}-qty',
                                    ),
                                    initialValue: item['qty'].toString(),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    onChanged: (v) {
                                      item['qty'] = double.tryParse(v) ?? 0;
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 90,
                                  child: TextFormField(
                                    key: ValueKey(
                                      'po-$selectedPoId-${item['id'] ?? item['item_code'] ?? item['item_name']}-rate',
                                    ),
                                    initialValue: item['rate'].toString(),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    onChanged: (v) {
                                      item['rate'] = double.tryParse(v) ?? 0;
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  amount.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: Colors.red,
                                  onPressed: () {
                                    items.removeAt(i);
                                    setState(() {});
                                  },
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

            const SizedBox(height: 16),

            /// ================= TOTAL BAR =================
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 300,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "Total Amount",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        "₹ ${total.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SafeArea(
              top: false,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.end,
                children: [
                  if (_canModify)
                    Tooltip(
                      message: 'Cancel purchase order',
                      child: SizedBox(
                        width: 140,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _cancelPo,
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Cancel PO'),
                        ),
                      ),
                    ),
                  if (_canReprint)
                    Tooltip(
                      message: 'Print purchase order',
                      child: SizedBox(
                        width: 140,
                        height: 44,
                        child: FilledButton.icon(
                          onPressed: _reprint,
                          icon: const Icon(Icons.print_outlined, size: 18),
                          label: const Text('Print'),
                        ),
                      ),
                    ),
                  if (_canModify)
                    Tooltip(
                      message: 'Save purchase order changes',
                      child: SizedBox(
                        width: 140,
                        height: 44,
                        child: FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: const Text('Save'),
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
}

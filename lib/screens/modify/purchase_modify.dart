import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../controllers/inventory/supplier_controller.dart';
import '../../controllers/purchase/purchase_order_modify_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../controllers/settings/system_settings_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/config/date_time_service.dart';
import '../../core/currency/currency_service.dart';
import '../../core/printing/pos_invoice_printer.dart';
import '../../core/utils/country_tax_helper.dart';
import '../../models/auth/permission_service.dart';
import '../../models/common/property_info_model.dart';
import '../../models/inventory/purchase_order_model.dart';
import '../../models/inventory/supplier_model.dart';
import '../../utils/branding_storage.dart';

class PurchaseOrderModifyScreen extends StatefulWidget {
  const PurchaseOrderModifyScreen({super.key});

  @override
  State<PurchaseOrderModifyScreen> createState() =>
      _PurchaseOrderModifyScreenState();
}

class _PurchaseOrderModifyScreenState extends State<PurchaseOrderModifyScreen> {
  final ctrl = PurchaseOrderModifyController();
  final supplierCtrl = SupplierController();
  final propertyCtrl = PropertyInfoController();
  final settingsCtrl = SystemSettingsController();

  final _searchCtrl = TextEditingController();

  DateTime _fromDate = DateTimeService.instance.nowInTimeZone.subtract(const Duration(days: 7));
  bool _loading = false;
  String _statusFilter = 'ALL';
  String _selectedSupplierFilter = 'ALL';

  PropertyInfo? propertyInfo;
  int? selectedPoId;
  int? selectedSupplierId;
  List items = [];
  Map<String, dynamic>? selectedPoData;

  bool get _canReprint =>
      PermissionService.can('REPRINT_PURCHASE') || PermissionService.can('MODIFY_PURCHASE');
  bool get _canModify => PermissionService.can('MODIFY_PURCHASE');

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initLoad() async {
    await supplierCtrl.load();
    await propertyCtrl.load();
    await settingsCtrl.load();
    propertyInfo = propertyCtrl.data;
    await _loadPOs();
  }

  Future<void> _loadPOs() async {
    setState(() => _loading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_fromDate);
      await ctrl.loadPOByDate(dateStr);

      final pos = List.from(ctrl.purchaseOrders);
      if (selectedPoId != null) {
        final match = pos.cast<Map?>().firstWhere(
              (p) => int.tryParse(p?['id']?.toString() ?? '') == selectedPoId,
              orElse: () => null,
            );
        if (match != null) {
          await _loadDetails(selectedPoId!);
        } else if (pos.isNotEmpty) {
          final firstId = int.tryParse(pos.first['id']?.toString() ?? '');
          if (firstId != null) await _loadDetails(firstId);
        } else {
          setState(() {
            selectedPoId = null;
            selectedSupplierId = null;
            selectedPoData = null;
            items = [];
          });
        }
      } else if (pos.isNotEmpty) {
        final firstId = int.tryParse(pos.first['id']?.toString() ?? '');
        if (firstId != null) await _loadDetails(firstId);
      } else {
        setState(() {
          selectedPoId = null;
          selectedSupplierId = null;
          selectedPoData = null;
          items = [];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDetails(int id) async {
    setState(() {
      selectedPoId = id;
      items = [];
    });

    try {
      await ctrl.loadPODetails(id);
      final suppId = ctrl.poDetails['supplier_id'];

      final matchedSummary = ctrl.purchaseOrders.cast<Map?>().firstWhere(
            (p) => int.tryParse(p?['id']?.toString() ?? '') == id,
            orElse: () => null,
          );

      setState(() {
        selectedSupplierId = suppId is int ? suppId : int.tryParse(suppId?.toString() ?? '');
        items = List.from(ctrl.items);
        selectedPoData = Map<String, dynamic>.from(
          ctrl.poDetails.isNotEmpty ? ctrl.poDetails : (matchedSummary ?? {}),
        );
      });
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filteredPOs {
    final query = _searchCtrl.text.trim().toLowerCase();
    return ctrl.purchaseOrders.cast<Map<String, dynamic>>().where((p) {
      final status = (p['status'] ?? 'OPEN').toString().toUpperCase().trim();
      final suppName = (p['supplier_name'] ?? p['supplier']?['supplier_name'] ?? '').toString().toLowerCase().trim();
      final suppId = (p['supplier_id'] ?? '').toString().trim();
      final poNo = (p['po_no'] ?? '').toString().toLowerCase().trim();

      if (_statusFilter != 'ALL') {
        if (_statusFilter == 'OPEN' && status != 'OPEN' && status != 'PENDING') return false;
        if (_statusFilter == 'PARTIAL' && status != 'PARTIAL') return false;
        if (_statusFilter == 'CLOSED' && status != 'CLOSED' && status != 'COMPLETED') return false;
        if (_statusFilter == 'CANCELLED' && status != 'CANCELLED') return false;
      }

      if (_selectedSupplierFilter != 'ALL' && suppId != _selectedSupplierFilter) {
        return false;
      }

      if (query.isNotEmpty) {
        final matchesPoNo = poNo.contains(query);
        final matchesSupp = suppName.contains(query);
        final matchesId = (p['id']?.toString() ?? '').contains(query);
        if (!matchesPoNo && !matchesSupp && !matchesId) return false;
      }

      return true;
    }).toList();
  }

  double get subTotal {
    double t = 0;
    for (var i in items) {
      final qty = double.tryParse(i['qty']?.toString() ?? '0') ?? 0;
      final rate = double.tryParse(i['rate']?.toString() ?? '0') ?? 0;
      t += qty * rate;
    }
    return t;
  }

  double get totalTax {
    double t = 0;
    for (var i in items) {
      final qty = double.tryParse(i['qty']?.toString() ?? '0') ?? 0;
      final rate = double.tryParse(i['rate']?.toString() ?? '0') ?? 0;
      final tax = double.tryParse(i['tax']?.toString() ?? '0') ?? 0;
      t += (qty * rate) * (tax / 100);
    }
    return t;
  }

  double get grandTotal => subTotal + totalTax;

  Future<void> _save() async {
    if (selectedPoId == null) {
      _msg("Select a Purchase Order first");
      return;
    }

    if (selectedSupplierId == null) {
      _msg("Select a Supplier");
      return;
    }

    if (items.isEmpty) {
      _msg("At least 1 item is required");
      return;
    }

    setState(() => _loading = true);
    try {
      await ctrl.modifyPO(
        poId: selectedPoId!,
        supplierId: selectedSupplierId!,
        items: items,
      );

      if (!mounted) return;
      _msg("Purchase Order Updated Successfully");
      await _loadPOs();
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelPo() async {
    if (selectedPoId == null) {
      _msg("Select a Purchase Order first");
      return;
    }

    final status = (selectedPoData?['status'] ?? ctrl.poDetails['status'] ?? '').toString().toUpperCase();
    if (status == 'CLOSED' || status == 'CANCELLED') {
      _msg("Only open or partial Purchase Orders can be cancelled");
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text("Cancel Purchase Order?"),
          ],
        ),
        content: Text("Are you sure you want to cancel PO #${selectedPoData?['po_no'] ?? selectedPoId}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No, Keep")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Yes, Cancel PO"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await ctrl.cancelPO(selectedPoId!);
      _msg("Purchase Order cancelled successfully");
      await _loadPOs();
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _msg(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _reprint(int poId) async {
    try {
      final res = await ApiClient.get('${ApiEndpoints.purchaseOrders}/$poId/print');
      if (res['success'] != true) {
        throw Exception("Failed to fetch PO print data");
      }
      final po = PurchaseOrder.fromJson(res['data']);
      await _printPurchaseOrder(po);
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _printPurchaseOrder(PurchaseOrder po) async {
    final pdf = await PosInvoicePrinter.createDocument();
    final supplier = supplierCtrl.list.firstWhere(
      (e) => e.id == po.supplierId,
      orElse: () => Supplier(
        id: po.supplierId,
        supplierCode: 'SUP-${po.supplierId}',
        supplierName: 'Supplier #${po.supplierId}',
        address: '',
        phone: '',
      ),
    );

    final settings = mounted ? context.read<SystemSettingsController>().settings : null;
    final country = settings?.billingCountry;
    final taxMode = settings?.billingTaxMode;
    final taxName = CountryTaxHelper.taxName(country, taxMode);
    final taxPercentLabel = CountryTaxHelper.taxPercentLabel(country, taxMode);
    final taxAmtLabel = CountryTaxHelper.taxAmountLabel(country, taxMode);
    final taxIdLabel = CountryTaxHelper.taxIdLabel(country);

    final subTot = po.items.fold<double>(0, (sum, item) => sum + (item.qty * item.rate));
    final totalGST = po.items.fold<double>(
      0,
      (sum, item) => sum + ((item.qty * item.rate) * (item.tax / 100)),
    );
    final grTotal = subTot + totalGST;

    final property = propertyInfo;
    final logo = await BrandingStorage.loadPdfLogo(property?.logoPath);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          PosInvoicePrinter.buildStandardA4Header(
            property: property,
            logo: logo,
            country: country,
            rightWidget: pw.Text(
              "PURCHASE ORDER",
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.deepOrange700,
              ),
            ),
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "REPRINT",
              style: pw.TextStyle(
                color: PdfColors.red,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              color: PdfColors.grey50,
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("VENDOR / BILL FROM", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.blueGrey800)),
                      pw.SizedBox(height: 4),
                      pw.Text(supplier.supplierName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.blueGrey900)),
                      if ((supplier.address ?? '').trim().isNotEmpty)
                        pw.Text(supplier.address!.trim(), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                      if ((supplier.gstin ?? '').trim().isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text("$taxIdLabel: ${supplier.gstin!.trim()}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                        ),
                    ],
                  ),
                ),
                pw.Container(width: 0.5, height: 45, color: PdfColors.grey300, margin: const pw.EdgeInsets.symmetric(horizontal: 16)),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("ORDER DETAILS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.blueGrey800)),
                      pw.SizedBox(height: 4),
                      _pdfMetaRow("PO No", po.poNo),
                      _pdfMetaRow("Date", PosInvoicePrinter.formatTzDate(po.createdAt ?? po.poDate)),
                      _pdfMetaRow("Time", PosInvoicePrinter.formatTzTime(po.createdAt ?? DateTime.now())),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1.2),
              5: const pw.FlexColumnWidth(1.2),
              6: const pw.FlexColumnWidth(1),
              7: const pw.FlexColumnWidth(1.2),
              8: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                children: [
                  _pdfTableCell("S.No", bold: true, alignment: pw.Alignment.center),
                  _pdfTableCell("Item", bold: true),
                  _pdfTableCell("Brand", bold: true),
                  _pdfTableCell("Unit", bold: true, alignment: pw.Alignment.center),
                  _pdfTableCell("Qty", bold: true, alignment: pw.Alignment.centerRight),
                  _pdfTableCell("Rate", bold: true, alignment: pw.Alignment.centerRight),
                  _pdfTableCell(taxPercentLabel, bold: true, alignment: pw.Alignment.centerRight),
                  _pdfTableCell(taxAmtLabel, bold: true, alignment: pw.Alignment.centerRight),
                  _pdfTableCell("Amount", bold: true, alignment: pw.Alignment.centerRight),
                ],
              ),
              ...List.generate(po.items.length, (i) {
                final item = po.items[i];
                final gstAmount = (item.qty * item.rate) * (item.tax / 100);
                return pw.TableRow(
                  children: [
                    _pdfTableCell("${i + 1}", alignment: pw.Alignment.center),
                    _pdfTableCell(item.itemName),
                    _pdfTableCell(item.brand),
                    _pdfTableCell(item.unit, alignment: pw.Alignment.center),
                    _pdfTableCell(item.qty.toString(), alignment: pw.Alignment.centerRight),
                    _pdfTableCell(CurrencyService.format(item.rate), alignment: pw.Alignment.centerRight),
                    _pdfTableCell(item.tax.toStringAsFixed(2), alignment: pw.Alignment.centerRight),
                    _pdfTableCell(CurrencyService.format(gstAmount), alignment: pw.Alignment.centerRight),
                    _pdfTableCell(CurrencyService.format(item.amount), alignment: pw.Alignment.centerRight),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 250,
              child: pw.Column(
                children: [
                  _pdfTotalRow("Sub Total", subTot),
                  _pdfTotalRow(taxName, totalGST),
                  pw.Divider(color: PdfColors.grey400, thickness: 0.5),
                  _pdfTotalRow("Grand Total", grTotal, bold: true),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 30),
          pw.Text(
            "Thank you for your business. Please supply the above items as per agreed terms.",
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Authorized Signature", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.SizedBox(height: 30),
                  pw.Text(property?.legalName ?? '', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text("Supplier Signature", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
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

  pw.Widget _pdfTableCell(String text, {bool bold = false, pw.Alignment alignment = pw.Alignment.centerLeft}) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: bold ? PdfColors.blueGrey900 : PdfColors.grey900,
        ),
      ),
    );
  }

  pw.Widget _pdfTotalRow(String label, double value, {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(CurrencyService.format(value), style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    );
  }

  pw.Widget _pdfMetaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: 45,
            child: pw.Text("$label:", style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          ),
          pw.Text(value, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase().trim()) {
      case 'OPEN':
      case 'PENDING':
        return Colors.orange;
      case 'PARTIAL':
        return Colors.blue;
      case 'CLOSED':
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          "Modify & Reprint Purchase Order",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: _loadPOs,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusTabs(),
          _buildToolbar(theme),
          _buildKpiBanner(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 380,
                            child: _buildPoListPanel(),
                          ),
                          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                          Expanded(
                            child: _buildPoDetailsPanel(),
                          ),
                        ],
                      )
                    : _buildPoListPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTabs() {
    final pos = ctrl.purchaseOrders.cast<Map<String, dynamic>>();
    int totalCount = pos.length;
    int openCount = 0;
    int partialCount = 0;
    int closedCount = 0;
    int cancelledCount = 0;

    for (var p in pos) {
      final st = (p['status'] ?? 'OPEN').toString().toUpperCase().trim();
      if (st == 'OPEN' || st == 'PENDING') openCount++;
      else if (st == 'PARTIAL') partialCount++;
      else if (st == 'CLOSED' || st == 'COMPLETED') closedCount++;
      else if (st == 'CANCELLED') cancelledCount++;
    }

    final tabs = [
      {'key': 'ALL', 'label': 'All POs', 'count': totalCount, 'color': Colors.blueGrey},
      {'key': 'OPEN', 'label': 'Open', 'count': openCount, 'color': Colors.orange},
      {'key': 'PARTIAL', 'label': 'Partial', 'count': partialCount, 'color': Colors.blue},
      {'key': 'CLOSED', 'label': 'Closed', 'count': closedCount, 'color': Colors.green},
      {'key': 'CANCELLED', 'label': 'Cancelled', 'count': cancelledCount, 'color': Colors.red},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((tab) {
            final isSelected = _statusFilter == tab['key'];
            final color = tab['color'] as MaterialColor;
            final count = tab['count'] as int;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _statusFilter = tab['key'] as String;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? color.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? color.shade400 : Colors.grey.shade300,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        tab['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? color.shade900 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected ? color.shade600 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Date Range picker
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range, size: 16),
            label: Text(
              DateFormat('dd-MMM-yyyy').format(_fromDate),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _fromDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (d != null) {
                setState(() => _fromDate = d);
                await _loadPOs();
              }
            },
          ),
          // Search Box
          SizedBox(
            width: 220,
            height: 38,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "Search PO #, Supplier...",
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 16, color: Colors.grey),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // Supplier dropdown
          SizedBox(
            width: 200,
            height: 38,
            child: DropdownButtonFormField<String>(
              key: ValueKey('filter-supplier-$_selectedSupplierFilter'),
              initialValue: _selectedSupplierFilter,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              items: [
                const DropdownMenuItem(value: 'ALL', child: Text("All Suppliers", style: TextStyle(fontSize: 12))),
                ...supplierCtrl.list.map(
                  (s) => DropdownMenuItem(
                    value: s.id.toString(),
                    child: Text(s.supplierName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _selectedSupplierFilter = v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiBanner() {
    final filtered = _filteredPOs;
    int totalCount = filtered.length;
    double totalValue = 0;
    int openCount = 0;
    int closedCount = 0;

    for (var p in filtered) {
      final st = (p['status'] ?? 'OPEN').toString().toUpperCase().trim();
      final amt = double.tryParse(p['total_amount']?.toString() ?? p['grand_total']?.toString() ?? '0') ?? 0;
      totalValue += amt;
      if (st == 'OPEN' || st == 'PENDING') openCount++;
      if (st == 'CLOSED' || st == 'COMPLETED') closedCount++;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _buildKpiCard("TOTAL POs", "$totalCount", Icons.receipt_long, Colors.blue),
          const SizedBox(width: 8),
          _buildKpiCard("TOTAL VALUE", CurrencyService.format(totalValue), Icons.payments_outlined, Colors.purple),
          const SizedBox(width: 8),
          _buildKpiCard("OPEN", "$openCount", Icons.timelapse, Colors.orange),
          const SizedBox(width: 8),
          _buildKpiCard("CLOSED", "$closedCount", Icons.check_circle_outline, Colors.green),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String val, IconData icon, MaterialColor color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 18, color: color.shade700),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                  const SizedBox(height: 2),
                  Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color.shade900), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoListPanel() {
    final list = _filteredPOs;

    if (list.isEmpty) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text("No purchase orders found", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (ctx, i) {
          final po = list[i];
          final id = int.tryParse(po['id']?.toString() ?? '');
          final poNo = po['po_no']?.toString() ?? 'PO #$id';
          final suppName = po['supplier_name'] ?? po['supplier']?['supplier_name'] ?? 'Supplier #${po['supplier_id']}';
          final status = (po['status'] ?? 'OPEN').toString().toUpperCase().trim();
          final isSelected = selectedPoId == id;
          final statusColor = _getStatusColor(status);
          final rawDate = po['po_date'] ?? po['created_at'];
          DateTime? poDate;
          if (rawDate != null) {
            poDate = DateTime.tryParse(rawDate.toString());
          }
          final dateStr = poDate != null ? DateFormat('dd MMM yyyy').format(poDate) : '';
          final totalAmt = double.tryParse(po['total_amount']?.toString() ?? po['grand_total']?.toString() ?? '0') ?? 0;

          return InkWell(
            onTap: id != null ? () => _loadDetails(id) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: isSelected ? Colors.blue.shade600 : Colors.transparent,
                    width: 4,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          poNo,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.blue.shade900 : Colors.black87,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor.withOpacity(0.4), width: 0.5),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.store_mall_directory_outlined, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          suppName.toString(),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(dateStr, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      Row(
                        children: [
                          Text(
                            CurrencyService.format(totalAmt),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
                          ),
                          if (_canReprint && id != null) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _reprint(id),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(Icons.print_outlined, size: 15, color: Colors.blue),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPoDetailsPanel() {
    if (selectedPoId == null) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app_outlined, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text("Select a Purchase Order to view or modify", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final status = (selectedPoData?['status'] ?? ctrl.poDetails['status'] ?? 'OPEN').toString().toUpperCase().trim();
    final statusColor = _getStatusColor(status);
    final isEditable = _canModify && (status == 'OPEN' || status == 'PENDING');

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              color: Color(0xFFFAFAFA),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            selectedPoData?['po_no']?.toString() ?? 'PO #$selectedPoId',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: statusColor.withOpacity(0.4), width: 0.5),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Supplier selection / display
                      if (isEditable)
                        Row(
                          children: [
                            const Text("Supplier: ", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 220,
                              height: 32,
                              child: DropdownButtonFormField<int>(
                                key: ValueKey('edit-supp-$selectedPoId-$selectedSupplierId'),
                                initialValue: selectedSupplierId,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  border: OutlineInputBorder(),
                                ),
                                items: supplierCtrl.list
                                    .map((Supplier s) => DropdownMenuItem(
                                          value: s.id,
                                          child: Text(s.supplierName, style: const TextStyle(fontSize: 11)),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  setState(() => selectedSupplierId = v);
                                },
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          "Supplier: ${selectedPoData?['supplier_name'] ?? selectedPoData?['supplier']?['supplier_name'] ?? 'Supplier #$selectedSupplierId'}",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
                // Action Buttons Toolbar
                Wrap(
                  spacing: 8,
                  children: [
                    if (_canReprint && selectedPoId != null)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.print_outlined, size: 14),
                        label: const Text("Print", style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        onPressed: () => _reprint(selectedPoId!),
                      ),
                    if (isEditable) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.cancel_outlined, size: 14, color: Colors.red),
                        label: const Text("Cancel PO", style: TextStyle(fontSize: 11, color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: _cancelPo,
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.save_outlined, size: 14),
                        label: const Text("Save Changes", style: TextStyle(fontSize: 11)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: _save,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Items Table
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      columnSpacing: 28,
                      horizontalMargin: 14,
                      headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)),
                      dataTextStyle: const TextStyle(fontSize: 12),
                      columns: [
                        const DataColumn(label: Text("#")),
                        const DataColumn(label: Text("Item Name")),
                        const DataColumn(label: Text("Brand")),
                        const DataColumn(label: Text("Unit")),
                        const DataColumn(label: Text("Qty")),
                        const DataColumn(label: Text("Rate")),
                        DataColumn(
                          label: Text(
                            CountryTaxHelper.taxPercentLabel(
                              context.watch<SystemSettingsController>().settings?.billingCountry,
                              context.watch<SystemSettingsController>().settings?.billingTaxMode,
                            ),
                          ),
                        ),
                        const DataColumn(label: Text("Tax Amt")),
                        const DataColumn(label: Text("Line Total")),
                        if (isEditable) const DataColumn(label: Text("Action")),
                      ],
                      rows: List.generate(items.length, (i) {
                        final item = items[i];
                        final qty = double.tryParse(item['qty']?.toString() ?? '0') ?? 0;
                        final rate = double.tryParse(item['rate']?.toString() ?? '0') ?? 0;
                        final tax = double.tryParse(item['tax']?.toString() ?? '0') ?? 0;
                        final taxAmt = (qty * rate) * (tax / 100);
                        final lineTotal = (qty * rate) + taxAmt;

                        return DataRow(
                          color: WidgetStateProperty.resolveWith(
                            (states) => i.isEven ? const Color(0xFFFAFBFD) : Colors.white,
                          ),
                          cells: [
                            DataCell(Text("${i + 1}")),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 160),
                                child: Text(
                                  item['item_name']?.toString() ?? item['itemName']?.toString() ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            DataCell(Text(item['brand']?.toString() ?? '-')),
                            DataCell(Text(item['unit']?.toString() ?? '-')),
                            DataCell(
                              isEditable
                                  ? SizedBox(
                                      width: 70,
                                      child: TextFormField(
                                        key: ValueKey('po-qty-$selectedPoId-$i-${item['id']}'),
                                        initialValue: qty.toString(),
                                        style: const TextStyle(fontSize: 12),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (v) {
                                          item['qty'] = double.tryParse(v) ?? 0;
                                          setState(() {});
                                        },
                                      ),
                                    )
                                  : Text(qty.toString()),
                            ),
                            DataCell(
                              isEditable
                                  ? SizedBox(
                                      width: 80,
                                      child: TextFormField(
                                        key: ValueKey('po-rate-$selectedPoId-$i-${item['id']}'),
                                        initialValue: rate.toString(),
                                        style: const TextStyle(fontSize: 12),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (v) {
                                          item['rate'] = double.tryParse(v) ?? 0;
                                          setState(() {});
                                        },
                                      ),
                                    )
                                  : Text(CurrencyService.format(rate)),
                            ),
                            DataCell(Text("${tax.toStringAsFixed(1)}%")),
                            DataCell(Text(CurrencyService.format(taxAmt))),
                            DataCell(
                              Text(
                                CurrencyService.format(lineTotal),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (isEditable)
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
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
          // Total Summary Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildSummaryBadge("Total Items", "${items.length}"),
                const SizedBox(width: 16),
                _buildSummaryBadge("Sub Total", CurrencyService.format(subTotal)),
                const SizedBox(width: 16),
                _buildSummaryBadge(
                  CountryTaxHelper.taxName(
                    context.watch<SystemSettingsController>().settings?.billingCountry,
                    context.watch<SystemSettingsController>().settings?.billingTaxMode,
                  ),
                  CurrencyService.format(totalTax),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Text("Grand Total: ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                      Text(
                        CurrencyService.format(grandTotal),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBadge(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
      ],
    );
  }
}

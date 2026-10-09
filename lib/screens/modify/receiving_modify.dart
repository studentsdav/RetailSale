import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../controllers/inventory/supplier_controller.dart';
import '../../controllers/modify/receiving_modify_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../controllers/settings/system_settings_controller.dart';
import '../../core/config/date_time_service.dart';
import '../../core/currency/currency_service.dart';
import '../../core/printing/pos_invoice_printer.dart';
import '../../core/utils/country_tax_helper.dart';
import '../../models/auth/permission_service.dart';
import '../../models/common/property_info_model.dart';
import '../../models/inventory/supplier_model.dart';
import '../../utils/branding_storage.dart';

class ModifyReceivingScreen extends StatefulWidget {
  final int? initialGrnId;
  final DateTime? initialReceiptDate;

  const ModifyReceivingScreen({
    super.key,
    this.initialGrnId,
    this.initialReceiptDate,
  });

  @override
  State<ModifyReceivingScreen> createState() => _ModifyReceivingScreenState();
}

class _ModifyReceivingScreenState extends State<ModifyReceivingScreen> {
  final ctrl = ReceivingModifyController();
  final supplierCtrl = SupplierController();
  final propertyCtrl = PropertyInfoController();
  final settingsCtrl = SystemSettingsController();

  final _searchCtrl = TextEditingController();

  DateTime _fromDate = DateTimeService.instance.nowInTimeZone.subtract(const Duration(days: 7));
  bool _loading = false;
  String _statusFilter = 'ALL';
  String _selectedSupplierFilter = 'ALL';

  PropertyInfo? propertyInfo;
  int? selectedGrnId;
  int? selectedSupplierId;
  List items = [];
  Map<String, dynamic>? selectedGrnData;

  bool get _canReprint =>
      PermissionService.can('REPRINT_RECEIVING') || PermissionService.can('MODIFY_RECEIVING');
  bool get _canModify => PermissionService.can('MODIFY_RECEIVING');

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await supplierCtrl.load();
    await propertyCtrl.load();
    await settingsCtrl.load();
    propertyInfo = propertyCtrl.data;

    if (widget.initialGrnId != null) {
      if (widget.initialReceiptDate != null) {
        _fromDate = widget.initialReceiptDate!;
      }
      await _loadGRNs();
      await _loadDetails(widget.initialGrnId!);
    } else {
      await _loadGRNs();
    }
  }

  Future<void> _loadGRNs() async {
    setState(() => _loading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_fromDate);
      await ctrl.loadGRNByDate(dateStr);

      final grns = List.from(ctrl.grns);
      if (selectedGrnId != null) {
        final match = grns.cast<Map?>().firstWhere(
              (g) => int.tryParse(g?['id']?.toString() ?? '') == selectedGrnId,
              orElse: () => null,
            );
        if (match != null) {
          await _loadDetails(selectedGrnId!);
        } else if (grns.isNotEmpty) {
          final firstId = int.tryParse(grns.first['id']?.toString() ?? '');
          if (firstId != null) await _loadDetails(firstId);
        } else {
          setState(() {
            selectedGrnId = null;
            selectedSupplierId = null;
            selectedGrnData = null;
            items = [];
          });
        }
      } else if (grns.isNotEmpty) {
        final firstId = int.tryParse(grns.first['id']?.toString() ?? '');
        if (firstId != null) await _loadDetails(firstId);
      } else {
        setState(() {
          selectedGrnId = null;
          selectedSupplierId = null;
          selectedGrnData = null;
          items = [];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDetails(int id) async {
    setState(() {
      selectedGrnId = id;
      items = [];
    });

    try {
      await ctrl.loadGRNDetails(id);
      final suppId = ctrl.grnDetails['supplier_id'];

      final matchedSummary = ctrl.grns.cast<Map?>().firstWhere(
            (g) => int.tryParse(g?['id']?.toString() ?? '') == id,
            orElse: () => null,
          );

      setState(() {
        selectedSupplierId = suppId is int ? suppId : int.tryParse(suppId?.toString() ?? '');
        items = List.from(ctrl.items);
        selectedGrnData = Map<String, dynamic>.from(
          ctrl.grnDetails.isNotEmpty ? ctrl.grnDetails : (matchedSummary ?? {}),
        );
      });
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filteredGRNs {
    final query = _searchCtrl.text.trim().toLowerCase();
    return ctrl.grns.cast<Map<String, dynamic>>().where((g) {
      final status = (g['status'] ?? 'COMPLETED').toString().toUpperCase().trim();
      final suppName = (g['supplier_name'] ?? g['supplier']?['supplier_name'] ?? '').toString().toLowerCase().trim();
      final suppId = (g['supplier_id'] ?? '').toString().trim();
      final grnNo = (g['grn_no'] ?? '').toString().toLowerCase().trim();
      final billNo = (g['supplier_bill_no'] ?? '').toString().toLowerCase().trim();

      if (_statusFilter != 'ALL') {
        if (_statusFilter == 'COMPLETED' && status != 'COMPLETED' && status != 'RECEIVED' && status != 'CLOSED') return false;
        if (_statusFilter == 'CANCELLED' && status != 'CANCELLED') return false;
      }

      if (_selectedSupplierFilter != 'ALL' && suppId != _selectedSupplierFilter) {
        return false;
      }

      if (query.isNotEmpty) {
        final matchesGrn = grnNo.contains(query);
        final matchesBill = billNo.contains(query);
        final matchesSupp = suppName.contains(query);
        final matchesId = (g['id']?.toString() ?? '').contains(query);
        if (!matchesGrn && !matchesBill && !matchesSupp && !matchesId) return false;
      }

      return true;
    }).toList();
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    return double.tryParse(val.toString()) ?? 0.0;
  }

  double get subTotal {
    double t = 0;
    for (var i in items) {
      t += _parseDouble(i['qty']) * _parseDouble(i['rate']);
    }
    return t;
  }

  double get totalGST {
    double g = 0;
    for (var i in items) {
      final qty = _parseDouble(i['qty']);
      final rate = _parseDouble(i['rate']);
      final tax = _parseDouble(i['tax']);
      g += (qty * rate) * tax / 100;
    }
    return g;
  }

  double get netAmount => subTotal + totalGST;

  Future<void> _save() async {
    if (selectedGrnId == null) {
      _msg("Select a Goods Receipt Note first");
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
      await ctrl.modifyGRN(
        id: selectedGrnId!,
        supplierId: selectedSupplierId!,
        items: items,
      );

      if (!mounted) return;
      _msg("Receiving Updated Successfully");
      await _loadGRNs();
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

  Future<void> _printReceiving() async {
    if (selectedGrnId == null) {
      _msg("Select GRN first");
      return;
    }

    final pdf = await PosInvoicePrinter.createDocument();
    final supplier = supplierCtrl.list.firstWhere(
      (e) => e.id == selectedSupplierId,
      orElse: () => Supplier(
        id: selectedSupplierId ?? 0,
        supplierCode: 'SUP-${selectedSupplierId ?? 0}',
        supplierName: 'Supplier #${selectedSupplierId ?? 0}',
        address: '',
        phone: '',
      ),
    );

    final property = propertyInfo ?? propertyCtrl.data;
    final logo = await BrandingStorage.loadPdfLogo(property?.logoPath);

    final grn = selectedGrnData ?? ctrl.grnDetails;
    final poNumber = grn['po_no'] ?? '';
    final rawDate = grn['receipt_date'] ?? grn['created_at'] ?? DateTime.now().toIso8601String();
    final receiptDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();

    final settings = mounted ? context.read<SystemSettingsController>().settings : null;
    final country = settings?.billingCountry;
    final taxMode = settings?.billingTaxMode;
    final taxName = CountryTaxHelper.taxName(country, taxMode);
    final taxPercentLabel = CountryTaxHelper.taxPercentLabel(country, taxMode);
    final taxIdLabel = CountryTaxHelper.taxIdLabel(country);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          PosInvoicePrinter.buildStandardA4Header(
            property: property,
            logo: logo,
            country: country,
            rightWidget: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blueGrey800)),
              child: pw.Text(
                "GOODS RECEIPT NOTE",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.blueGrey900),
              ),
            ),
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "REPRINT",
              style: pw.TextStyle(color: PdfColors.red, fontWeight: pw.FontWeight.bold, fontSize: 9),
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
                      if ((grn['supplier_bill_no'] ?? '').toString().trim().isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text("Supplier Bill No: ${grn['supplier_bill_no'].toString().trim()}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
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
                      pw.Text("RECEIVING DETAILS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.blueGrey800)),
                      pw.SizedBox(height: 4),
                      _pdfMetaRow("GRN No", grn['grn_no']?.toString() ?? ''),
                      _pdfMetaRow("Date", DateFormat('dd-MMM-yyyy').format(receiptDate)),
                      if ((poNumber).toString().trim().isNotEmpty)
                        _pdfMetaRow("PO No", poNumber.toString().trim()),
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
              0: const pw.FixedColumnWidth(25),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(40),
              3: const pw.FixedColumnWidth(40),
              4: const pw.FixedColumnWidth(50),
              5: const pw.FixedColumnWidth(45),
              6: const pw.FixedColumnWidth(60),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                children: [
                  _pdfCell("S.No", bold: true, alignment: pw.Alignment.center),
                  _pdfCell("Item", bold: true),
                  _pdfCell("Unit", bold: true, alignment: pw.Alignment.center),
                  _pdfCell("Qty", bold: true, alignment: pw.Alignment.centerRight),
                  _pdfCell("Rate", bold: true, alignment: pw.Alignment.centerRight),
                  _pdfCell(taxPercentLabel, bold: true, alignment: pw.Alignment.centerRight),
                  _pdfCell("Amount", bold: true, alignment: pw.Alignment.centerRight),
                ],
              ),
              ...List.generate(items.length, (i) {
                final r = items[i];
                final qty = _parseDouble(r['qty']);
                final rate = _parseDouble(r['rate']);
                final tax = _parseDouble(r['tax']);
                final amount = qty * rate;

                return pw.TableRow(
                  children: [
                    _pdfCell("${i + 1}", alignment: pw.Alignment.center),
                    _pdfCell('${r['item_name'] ?? ''}${r['brand'] != null && r['brand'].toString().isNotEmpty ? ' (${r['brand']})' : ''}'),
                    _pdfCell(r['unit'] ?? "", alignment: pw.Alignment.center),
                    _pdfCell(qty.toString(), alignment: pw.Alignment.centerRight),
                    _pdfCell(CurrencyService.format(rate), alignment: pw.Alignment.centerRight),
                    _pdfCell(tax.toStringAsFixed(2), alignment: pw.Alignment.centerRight),
                    _pdfCell(CurrencyService.format(amount), alignment: pw.Alignment.centerRight),
                  ],
                );
              })
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 250,
              child: pw.Column(
                children: [
                  _pdfTotalRow("Sub Total", subTotal),
                  _pdfTotalRow(taxName, totalGST),
                  pw.Divider(color: PdfColors.grey400, thickness: 0.5),
                  _pdfTotalRow("Net Amount", netAmount, bold: true),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 30),
          pw.Text("Goods received in good condition.", style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Store Incharge", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.SizedBox(height: 30),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text("Authorized Signatory", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.SizedBox(height: 30),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(name: 'GRN_${grn['grn_no']}', onLayout: (format) async => pdf.save());
  }

  pw.Widget _pdfCell(String text, {bool bold = false, pw.Alignment alignment = pw.Alignment.centerLeft}) {
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
      case 'RECEIVED':
      case 'COMPLETED':
      case 'CLOSED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      case 'PENDING':
        return Colors.orange;
      default:
        return Colors.blueGrey;
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
          "Modify & Reprint Receiving (GRN)",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: _loadGRNs,
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
                            child: _buildGrnListPanel(),
                          ),
                          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                          Expanded(
                            child: _buildGrnDetailsPanel(),
                          ),
                        ],
                      )
                    : _buildGrnListPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTabs() {
    final grns = ctrl.grns.cast<Map<String, dynamic>>();
    int totalCount = grns.length;
    int completedCount = 0;
    int cancelledCount = 0;

    for (var g in grns) {
      final st = (g['status'] ?? 'COMPLETED').toString().toUpperCase().trim();
      if (st == 'CANCELLED') cancelledCount++;
      else completedCount++;
    }

    final tabs = [
      {'key': 'ALL', 'label': 'All GRNs', 'count': totalCount, 'color': Colors.blueGrey},
      {'key': 'COMPLETED', 'label': 'Received / Closed', 'count': completedCount, 'color': Colors.green},
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
          // Date Range button
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
                await _loadGRNs();
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
                hintText: "Search GRN #, Bill #, Supplier...",
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
    final filtered = _filteredGRNs;
    int totalCount = filtered.length;
    double totalValue = 0;
    int receivedCount = 0;

    for (var g in filtered) {
      final st = (g['status'] ?? 'COMPLETED').toString().toUpperCase().trim();
      final amt = _parseDouble(g['net_amount'] ?? g['total_amount'] ?? g['grand_total']);
      totalValue += amt;
      if (st != 'CANCELLED') receivedCount++;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _buildKpiCard("TOTAL GRNs", "$totalCount", Icons.receipt_long, Colors.blue),
          const SizedBox(width: 8),
          _buildKpiCard("TOTAL VALUE", CurrencyService.format(totalValue), Icons.payments_outlined, Colors.purple),
          const SizedBox(width: 8),
          _buildKpiCard("RECEIVED", "$receivedCount", Icons.check_circle_outline, Colors.green),
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

  Widget _buildGrnListPanel() {
    final list = _filteredGRNs;

    if (list.isEmpty) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text("No receiving records found", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
          final grn = list[i];
          final id = int.tryParse(grn['id']?.toString() ?? '');
          final grnNo = grn['grn_no']?.toString() ?? 'GRN #$id';
          final suppName = grn['supplier_name'] ?? grn['supplier']?['supplier_name'] ?? 'Supplier #${grn['supplier_id']}';
          final status = (grn['status'] ?? 'COMPLETED').toString().toUpperCase().trim();
          final isSelected = selectedGrnId == id;
          final statusColor = _getStatusColor(status);
          final rawDate = grn['receipt_date'] ?? grn['created_at'];
          DateTime? receiptDate;
          if (rawDate != null) {
            receiptDate = DateTime.tryParse(rawDate.toString());
          }
          final dateStr = receiptDate != null ? DateFormat('dd MMM yyyy').format(receiptDate) : '';
          final totalAmt = _parseDouble(grn['net_amount'] ?? grn['total_amount'] ?? grn['grand_total']);
          final billNo = (grn['supplier_bill_no'] ?? '').toString().trim();

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
                          grnNo,
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
                  if (billNo.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      "Bill No: $billNo",
                      style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade600),
                    ),
                  ],
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
                              onTap: () {
                                _loadDetails(id).then((_) => _printReceiving());
                              },
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

  Widget _buildGrnDetailsPanel() {
    if (selectedGrnId == null) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app_outlined, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text("Select a Goods Receipt Note to view or modify", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final status = (selectedGrnData?['status'] ?? ctrl.grnDetails['status'] ?? 'COMPLETED').toString().toUpperCase().trim();
    final statusColor = _getStatusColor(status);
    final isEditable = _canModify && status != 'CANCELLED';

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
                            selectedGrnData?['grn_no']?.toString() ?? 'GRN #$selectedGrnId',
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
                      if (isEditable)
                        Row(
                          children: [
                            const Text("Supplier: ", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 220,
                              height: 32,
                              child: DropdownButtonFormField<int>(
                                key: ValueKey('edit-supp-grn-$selectedGrnId-$selectedSupplierId'),
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
                          "Supplier: ${selectedGrnData?['supplier_name'] ?? selectedGrnData?['supplier']?['supplier_name'] ?? 'Supplier #$selectedSupplierId'}",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
                // Action Buttons
                Wrap(
                  spacing: 8,
                  children: [
                    if (_canReprint && selectedGrnId != null)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.print_outlined, size: 14),
                        label: const Text("Print", style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        onPressed: _printReceiving,
                      ),
                    if (isEditable)
                      FilledButton.icon(
                        icon: const Icon(Icons.save_outlined, size: 14),
                        label: const Text("Save Changes", style: TextStyle(fontSize: 11)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: _save,
                      ),
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
                        const DataColumn(label: Text("Remarks")),
                        const DataColumn(label: Text("Amount")),
                        if (isEditable) const DataColumn(label: Text("Action")),
                      ],
                      rows: List.generate(items.length, (i) {
                        final item = items[i];
                        final qty = _parseDouble(item['qty']);
                        final rate = _parseDouble(item['rate']);
                        final tax = _parseDouble(item['tax']);
                        final amount = qty * rate;

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
                                  '${item['item_name'] ?? ''}${item['brand'] != null && item['brand'].toString().isNotEmpty ? ' (${item['brand']})' : ''}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            DataCell(Text(item['unit']?.toString() ?? '')),
                            DataCell(
                              isEditable
                                  ? SizedBox(
                                      width: 70,
                                      child: TextFormField(
                                        key: ValueKey('grn-qty-$selectedGrnId-$i-${item['id']}'),
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
                                        key: ValueKey('grn-rate-$selectedGrnId-$i-${item['id']}'),
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
                            DataCell(
                              isEditable
                                  ? SizedBox(
                                      width: 70,
                                      child: TextFormField(
                                        key: ValueKey('grn-tax-$selectedGrnId-$i-${item['id']}'),
                                        initialValue: tax.toString(),
                                        style: const TextStyle(fontSize: 12),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (v) {
                                          item['tax'] = double.tryParse(v) ?? 0;
                                          setState(() {});
                                        },
                                      ),
                                    )
                                  : Text("${tax.toStringAsFixed(1)}%"),
                            ),
                            DataCell(
                              isEditable
                                  ? SizedBox(
                                      width: 130,
                                      child: TextFormField(
                                        key: ValueKey('grn-remarks-$selectedGrnId-$i-${item['id']}'),
                                        initialValue: (item['remarks'] ?? '').toString(),
                                        style: const TextStyle(fontSize: 12),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (v) {
                                          item['remarks'] = v;
                                          setState(() {});
                                        },
                                      ),
                                    )
                                  : Text((item['remarks'] ?? '').toString()),
                            ),
                            DataCell(
                              Text(
                                CurrencyService.format(amount),
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
          // Summary Bar
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
                  CurrencyService.format(totalGST),
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
                      Text("Net Amount: ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                      Text(
                        CurrencyService.format(netAmount),
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

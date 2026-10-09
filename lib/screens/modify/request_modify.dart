import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../controllers/inventory/issue_controller.dart';
import '../../controllers/modify/request_modify-controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../controllers/settings/system_settings_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/config/date_time_service.dart';
import '../../core/currency/currency_service.dart';
import '../../core/printing/pos_invoice_printer.dart';
import '../../models/auth/permission_service.dart';
import '../../models/common/property_info_model.dart';
import '../../models/inventory/request_detail_model.dart';
import '../../models/inventory/stock_location_model.dart';
import '../../utils/branding_storage.dart';

class RequestModifyScreen extends StatefulWidget {
  const RequestModifyScreen({super.key});

  @override
  State<RequestModifyScreen> createState() => _RequestModifyScreenState();
}

class _RequestModifyScreenState extends State<RequestModifyScreen> {
  final ctrl = RequestModifyController();
  final issueCtrl = IssueController();
  final propertyCtrl = PropertyInfoController();
  final settingsCtrl = SystemSettingsController();

  final _searchCtrl = TextEditingController();

  DateTime _fromDate = DateTimeService.instance.nowInTimeZone.subtract(const Duration(days: 7));
  DateTime _toDate = DateTimeService.instance.nowInTimeZone;
  bool _loading = false;
  String _statusFilter = 'ALL';
  String _selectedDeptFilter = 'ALL';

  PropertyInfo? propertyInfo;
  int? selectedRequestId;
  StockLocationdata? selectedDepartment;
  List items = [];
  Map<String, dynamic>? selectedRequestData;

  bool get _canReprint =>
      PermissionService.can('REPRINT_REQUEST') || PermissionService.can('MODIFY_REQUEST');
  bool get _canModify => PermissionService.can('MODIFY_REQUEST');

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
    await issueCtrl.getdepartment();
    await propertyCtrl.load();
    await settingsCtrl.load();
    propertyInfo = propertyCtrl.data;
    await _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_fromDate);
      await ctrl.loadRequestsByDate(dateStr);

      final requests = List.from(ctrl.requests);
      if (selectedRequestId != null) {
        final match = requests.cast<Map?>().firstWhere(
              (r) => int.tryParse(r?['id']?.toString() ?? '') == selectedRequestId,
              orElse: () => null,
            );
        if (match != null) {
          await _loadDetails(selectedRequestId!);
        } else if (requests.isNotEmpty) {
          final firstId = int.tryParse(requests.first['id']?.toString() ?? '');
          if (firstId != null) await _loadDetails(firstId);
        } else {
          setState(() {
            selectedRequestId = null;
            selectedRequestData = null;
            items = [];
          });
        }
      } else if (requests.isNotEmpty) {
        final firstId = int.tryParse(requests.first['id']?.toString() ?? '');
        if (firstId != null) await _loadDetails(firstId);
      } else {
        setState(() {
          selectedRequestId = null;
          selectedRequestData = null;
          items = [];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDetails(int id) async {
    setState(() {
      selectedRequestId = id;
      items = [];
    });

    try {
      await ctrl.loadRequestDetails(id);
      final deptId = ctrl.requestDetails['department'];
      StockLocationdata? nextDepartment;
      try {
        nextDepartment = issueCtrl.departments.firstWhere(
          (e) => e.locationName.toString().toLowerCase() == deptId.toString().toLowerCase(),
        );
      } catch (_) {
        nextDepartment = null;
      }

      final matchedSummary = ctrl.requests.cast<Map?>().firstWhere(
            (r) => int.tryParse(r?['id']?.toString() ?? '') == id,
            orElse: () => null,
          );

      setState(() {
        items = List.from(ctrl.items);
        selectedDepartment = nextDepartment;
        selectedRequestData = Map<String, dynamic>.from(ctrl.requestDetails.isNotEmpty ? ctrl.requestDetails : (matchedSummary ?? {}));
      });
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filteredRequests {
    final query = _searchCtrl.text.trim().toLowerCase();
    return ctrl.requests.cast<Map<String, dynamic>>().where((r) {
      final status = (r['status'] ?? 'PENDING').toString().toUpperCase().trim();
      final dept = (r['department'] ?? '').toString().toLowerCase().trim();
      final reqNo = (r['request_no'] ?? r['id'] ?? '').toString().toLowerCase().trim();

      if (_statusFilter == 'PENDING' && status != 'PENDING' && status != 'AUTO') return false;
      if (_statusFilter == 'APPROVED' && status != 'APPROVED' && status != 'COMPLETED') return false;
      if (_statusFilter == 'CANCELLED' && status != 'CANCELLED' && status != 'REJECTED') return false;

      if (_selectedDeptFilter != 'ALL' && !dept.contains(_selectedDeptFilter.toLowerCase())) {
        return false;
      }

      if (query.isNotEmpty) {
        if (!reqNo.contains(query) && !dept.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  double get totalAmount {
    double sum = 0.0;
    for (var i in items) {
      final q = double.tryParse(i['qty']?.toString() ?? '0') ?? 0.0;
      final r = double.tryParse(i['rate']?.toString() ?? '0') ?? 0.0;
      sum += (q * r);
    }
    return sum;
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
    _loadRequests();
  }

  Future<void> _save() async {
    if (selectedRequestId == null) {
      _msg("Please select a request first");
      return;
    }
    if (items.isEmpty) {
      _msg("At least one item is required in the request");
      return;
    }

    try {
      await ctrl.modifyRequest(
        requestId: selectedRequestId!,
        department: selectedDepartment?.locationName ?? selectedRequestData?['department'] ?? '',
        items: items,
      );
      _msg("Material Request updated successfully", isError: false);
      await _loadRequests();
    } catch (e) {
      _msg("Error updating request: $e");
    }
  }

  Future<void> _cancelRequest() async {
    if (selectedRequestId == null) {
      _msg("Please select a request first");
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Cancel Request', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Are you sure you want to cancel Request #${selectedRequestData?['request_no'] ?? selectedRequestId}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No, Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel Request'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ctrl.cancelRequest(selectedRequestId!);
      _msg("Material Request cancelled", isError: false);
      await _loadRequests();
    } catch (e) {
      _msg("Error cancelling request: $e");
    }
  }

  void _msg(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> reprintRequest(int reqId) async {
    final res = await ApiClient.get('${ApiEndpoints.requests}/$reqId');
    final data = res['data'];
    final request = RequestDetail.fromJson(data);

    final resInfo = await ApiClient.get(ApiEndpoints.propertyInfo);
    final property = PropertyInfo.fromJson(resInfo['data']);
    final logo = await BrandingStorage.loadPdfLogo(property.logoPath);

    final sysSettings = mounted ? Provider.of<SystemSettingsController>(context, listen: false).settings : null;
    final sysCountry = sysSettings?.billingCountry.isNotEmpty == true ? sysSettings!.billingCountry : 'Kenya';

    final pdf = await PosInvoicePrinter.createDocument();

    double totalAmt = 0;
    for (var it in request.items) {
      totalAmt += (it.qty * it.rate);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          PosInvoicePrinter.buildStandardA4Header(
            property: property,
            logo: logo,
            country: sysCountry,
            rightWidget: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey800, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                color: PdfColors.blueGrey50,
              ),
              child: pw.Text(
                "MATERIAL REQUEST",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blueGrey900),
              ),
            ),
          ),
          pw.SizedBox(height: 16),
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
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("DEPARTMENT / LOCATION", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.blueGrey800)),
                      pw.SizedBox(height: 4),
                      pw.Text(request.department ?? 'N/A', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.blueGrey900)),
                    ],
                  ),
                ),
                pw.Container(width: 0.5, height: 40, color: PdfColors.grey300, margin: const pw.EdgeInsets.symmetric(horizontal: 16)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("REQUEST METADATA", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.blueGrey800)),
                    pw.SizedBox(height: 4),
                    _pdfMetaRow("Request No", request.requestNo.toString()),
                    _pdfMetaRow("Date", DateFormat('dd-MMM-yyyy').format(request.requestDate)),
                    _pdfMetaRow("Status", request.status ?? 'Auto'),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(45),
              3: const pw.FixedColumnWidth(55),
              4: const pw.FixedColumnWidth(70),
              5: const pw.FixedColumnWidth(80),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                children: [
                  _pdfCell("S.No", bold: true, alignment: pw.Alignment.center),
                  _pdfCell("Item Description", bold: true),
                  _pdfCell("Unit", bold: true, alignment: pw.Alignment.center),
                  _pdfCell("Qty", bold: true, alignment: pw.Alignment.centerRight),
                  _pdfCell("Rate", bold: true, alignment: pw.Alignment.centerRight),
                  _pdfCell("Amount", bold: true, alignment: pw.Alignment.centerRight),
                ],
              ),
              ...List.generate(request.items.length, (i) {
                final r = request.items[i];
                final lineAmt = r.qty * r.rate;
                return pw.TableRow(
                  children: [
                    _pdfCell("${i + 1}", alignment: pw.Alignment.center),
                    _pdfCell(r.name),
                    _pdfCell(r.unit, alignment: pw.Alignment.center),
                    _pdfCell(r.qty.toString(), alignment: pw.Alignment.centerRight),
                    _pdfCell(CurrencyService.format(r.rate), alignment: pw.Alignment.centerRight),
                    _pdfCell(CurrencyService.format(lineAmt), alignment: pw.Alignment.centerRight),
                  ],
                );
              })
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey800, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                color: PdfColors.blueGrey50,
              ),
              child: pw.Text(
                "Total Amount: ${CurrencyService.format(totalAmt)}",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blueGrey900),
              ),
            ),
          ),
          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 120, height: 1, color: PdfColors.grey500),
                  pw.SizedBox(height: 4),
                  pw.Text("Requested By", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(width: 120, height: 1, color: PdfColors.grey500),
                  pw.SizedBox(height: 4),
                  pw.Text("Store Incharge", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(width: 120, height: 1, color: PdfColors.grey500),
                  pw.SizedBox(height: 4),
                  pw.Text("Approved By", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(name: 'Request_${request.requestNo}', onLayout: (format) async => pdf.save());
  }

  pw.Widget _pdfCell(String text, {bool bold = false, pw.Alignment alignment = pw.Alignment.centerLeft}) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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

  pw.Widget _pdfMetaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: 55,
            child: pw.Text("$label:", style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          ),
          pw.Text(value, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
        ],
      ),
    );
  }

  Widget _buildTabButton(String key, String label, {int? badgeCount}) {
    final bool isSelected = _statusFilter == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _statusFilter = key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0B5CAD) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
              if (badgeCount != null && badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.red.shade600,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF0B5CAD) : Colors.white,
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

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRequests;
    final int pendingCount = ctrl.requests.where((r) {
      final s = (r['status'] ?? 'PENDING').toString().toUpperCase().trim();
      return s == 'PENDING' || s == 'AUTO';
    }).length;
    final int approvedCount = ctrl.requests.where((r) {
      final s = (r['status'] ?? '').toString().toUpperCase().trim();
      return s == 'APPROVED' || s == 'COMPLETED';
    }).length;

    double grandTotalAll = 0.0;
    int totalItemsAll = 0;
    for (var r in ctrl.requests) {
      final rItems = r['items'] as List? ?? [];
      totalItemsAll += rItems.length;
      for (var it in rItems) {
        final q = double.tryParse(it['qty']?.toString() ?? '0') ?? 0.0;
        final rt = double.tryParse(it['rate']?.toString() ?? '0') ?? 0.0;
        grandTotalAll += (q * rt);
      }
    }

    final isWide = MediaQuery.of(context).size.width >= 960;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Modify & Reprint Material Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0B5CAD),
        elevation: 1,
        actions: [
          IconButton(
            tooltip: 'Refresh Requests',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadRequests,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  _buildTabButton('ALL', 'All Requests (${ctrl.requests.length})'),
                  _buildTabButton('PENDING', 'Pending / Open', badgeCount: pendingCount),
                  _buildTabButton('APPROVED', 'Approved ($approvedCount)'),
                  _buildTabButton('CANCELLED', 'Cancelled'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Filter Toolbar
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
                                const Text('Date', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600)),
                                Text(DateFormat('dd-MMM-yyyy').format(_fromDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Search Box
                    SizedBox(
                      width: 240,
                      height: 42,
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Search Request # / Dept...',
                          hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          prefixIcon: const Icon(Icons.search, size: 17, color: Color(0xFF0B5CAD)),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 15),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {});
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
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Department Dropdown
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDeptFilter,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                          items: [
                            const DropdownMenuItem(value: 'ALL', child: Text('All Departments')),
                            ...issueCtrl.departments.map((d) => DropdownMenuItem(
                                  value: d.locationName,
                                  child: Text(d.locationName),
                                )),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedDeptFilter = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Refresh Button
                    SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: _loadRequests,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0B5CAD),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // KPI Stats Row
            Row(
              children: [
                _buildKpiCard(
                  title: 'Total Requests',
                  value: '${ctrl.requests.length}',
                  icon: Icons.assignment_outlined,
                  color: const Color(0xFF0B5CAD),
                  bgColor: const Color(0xFF0B5CAD).withOpacity(0.1),
                ),
                const SizedBox(width: 10),
                _buildKpiCard(
                  title: 'Pending Open',
                  value: '$pendingCount',
                  icon: Icons.pending_actions_outlined,
                  color: Colors.orange.shade800,
                  bgColor: Colors.orange.shade50,
                ),
                const SizedBox(width: 10),
                _buildKpiCard(
                  title: 'Approved / Done',
                  value: '$approvedCount',
                  icon: Icons.check_circle_outline,
                  color: Colors.green.shade800,
                  bgColor: Colors.green.shade50,
                ),
                const SizedBox(width: 10),
                _buildKpiCard(
                  title: 'Est. Total Value',
                  value: CurrencyService.format(grandTotalAll),
                  icon: Icons.account_balance_wallet_outlined,
                  color: Colors.purple.shade800,
                  bgColor: Colors.purple.shade50,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Master-Detail Split Pane
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_late_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text('No Material Requests found for this criteria', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                            ],
                          ),
                        )
                      : isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left List (Master)
                                Expanded(
                                  flex: 5,
                                  child: _buildRequestsTable(filtered),
                                ),
                                const SizedBox(width: 14),
                                // Right Details / Modify Panel
                                Expanded(
                                  flex: 6,
                                  child: _buildDetailPanel(),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(child: _buildRequestsTable(filtered)),
                                if (selectedRequestId != null) ...[
                                  const SizedBox(height: 12),
                                  Expanded(child: _buildDetailPanel()),
                                ],
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTable(List<Map<String, dynamic>> requests) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ListView.separated(
          itemCount: requests.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
          itemBuilder: (context, idx) {
            final r = requests[idx];
            final id = int.tryParse(r['id']?.toString() ?? '') ?? 0;
            final isSelected = selectedRequestId == id;
            final reqNo = (r['request_no'] ?? r['id'] ?? 'REQ-$id').toString();
            final dept = (r['department'] ?? 'General').toString();
            final status = (r['status'] ?? 'PENDING').toString().toUpperCase().trim();
            final reqItems = r['items'] as List? ?? [];

            double reqTotal = 0.0;
            for (var it in reqItems) {
              final q = double.tryParse(it['qty']?.toString() ?? '0') ?? 0.0;
              final rt = double.tryParse(it['rate']?.toString() ?? '0') ?? 0.0;
              reqTotal += (q * rt);
            }

            final isPending = status == 'PENDING' || status == 'AUTO';
            final isApproved = status == 'APPROVED' || status == 'COMPLETED';

            return InkWell(
              onTap: () => _loadDetails(id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0B5CAD).withOpacity(0.06) : Colors.transparent,
                  border: isSelected ? const Border(left: BorderSide(color: Color(0xFF0B5CAD), width: 3.5)) : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0B5CAD).withOpacity(0.15) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        color: isSelected ? const Color(0xFF0B5CAD) : Colors.grey.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                reqNo,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isApproved
                                      ? Colors.green.shade50
                                      : isPending
                                          ? Colors.orange.shade50
                                          : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isApproved
                                        ? Colors.green.shade200
                                        : isPending
                                            ? Colors.orange.shade200
                                            : Colors.red.shade200,
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: isApproved
                                        ? Colors.green.shade800
                                        : isPending
                                            ? Colors.orange.shade800
                                            : Colors.red.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.storefront_outlined, size: 13, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(dept, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                              const SizedBox(width: 10),
                              Text('•', style: TextStyle(color: Colors.grey.shade400)),
                              const SizedBox(width: 10),
                              Text('${reqItems.length} items', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyService.format(reqTotal),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0B5CAD)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_canReprint)
                              IconButton(
                                icon: const Icon(Icons.print_outlined, size: 17),
                                color: const Color(0xFF0B5CAD),
                                tooltip: 'Print Request Slip',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                onPressed: () => reprintRequest(id),
                              ),
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
      ),
    );
  }

  Widget _buildDetailPanel() {
    if (selectedRequestId == null || selectedRequestData == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(child: Text('Select a material request on the left to review or edit.')),
      );
    }

    final reqNo = (selectedRequestData?['request_no'] ?? selectedRequestId).toString();
    final status = (selectedRequestData?['status'] ?? 'PENDING').toString().toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Detail Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Request #$reqNo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            backgroundColor: status == 'APPROVED' ? Colors.green.shade100 : Colors.orange.shade100,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Department: ${selectedDepartment?.locationName ?? selectedRequestData?['department'] ?? 'General'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                if (_canReprint)
                  FilledButton.icon(
                    onPressed: () => reprintRequest(selectedRequestId!),
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Print A4 / Slip', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0B5CAD),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
              ],
            ),
          ),

          // Department selector when editing
          if (_canModify)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Text('Target Department: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<StockLocationdata>(
                          value: selectedDepartment,
                          isExpanded: true,
                          hint: const Text('Select Department', style: TextStyle(fontSize: 12)),
                          style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                          items: issueCtrl.departments.map((dept) {
                            return DropdownMenuItem(value: dept, child: Text(dept.locationName));
                          }).toList(),
                          onChanged: (val) {
                            setState(() => selectedDepartment = val);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Items Table
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No items in this request.'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(4),
                        1: FixedColumnWidth(80),
                        2: FixedColumnWidth(90),
                        3: FixedColumnWidth(90),
                        4: FixedColumnWidth(40),
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1.5))),
                          children: const [
                            Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Rate', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            SizedBox(),
                          ],
                        ),
                        ...items.asMap().entries.map((entry) {
                          final i = entry.key;
                          final item = entry.value;
                          final itemName = item['item_master']?['item_name'] ?? item['item_name'] ?? 'Item';
                          final brand = item['item_master']?['brand'] ?? item['brand'];
                          final unit = item['item_master']?['unit'] ?? item['unit'] ?? '';
                          final q = double.tryParse(item['qty']?.toString() ?? '0') ?? 0.0;
                          final r = double.tryParse(item['rate']?.toString() ?? '0') ?? 0.0;
                          final lineTotal = q * r;

                          return TableRow(
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5))),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('$itemName ${brand != null && brand.isNotEmpty ? "($brand)" : ""}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                                    if (unit.isNotEmpty) Text('Unit: $unit', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: _canModify
                                    ? SizedBox(
                                        height: 32,
                                        child: TextFormField(
                                          initialValue: '$q',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                          ),
                                          onChanged: (val) {
                                            item['qty'] = double.tryParse(val) ?? 0.0;
                                            setState(() {});
                                          },
                                        ),
                                      )
                                    : Text('$q', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: _canModify
                                    ? SizedBox(
                                        height: 32,
                                        child: TextFormField(
                                          initialValue: '$r',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontSize: 12),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                          ),
                                          onChanged: (val) {
                                            item['rate'] = double.tryParse(val) ?? 0.0;
                                            setState(() {});
                                          },
                                        ),
                                      )
                                    : Text(CurrencyService.format(r), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(CurrencyService.format(lineTotal), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: _canModify
                                    ? IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                        onPressed: () {
                                          if (items.length == 1) {
                                            _msg("At least one item is required in the request.");
                                            return;
                                          }
                                          setState(() => items.removeAt(i));
                                        },
                                      )
                                    : const SizedBox(),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
          ),

          // Total Bar & Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Estimate', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                    Text(
                      CurrencyService.format(totalAmount),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0B5CAD)),
                    ),
                  ],
                ),
                const Spacer(),
                if (_canModify) ...[
                  OutlinedButton.icon(
                    onPressed: _cancelRequest,
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Cancel Request', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Save Changes', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0B5CAD),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

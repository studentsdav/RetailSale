import 'dart:io';
import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class CashierHandoverReportScreen extends StatefulWidget {
  const CashierHandoverReportScreen({super.key});

  @override
  State<CashierHandoverReportScreen> createState() => _CashierHandoverReportScreenState();
}

class _CashierHandoverReportScreenState extends State<CashierHandoverReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NumberFormat _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final DateFormat _df = DateFormat('yyyy-MM-dd');

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  bool _isLoading = false;
  List<dynamic> _handovers = [];
  Map<String, dynamic> _summary = {};

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Retail POS Theme Palette
  static const Color posBgColor = Color(0xFFF4EEE8);
  static const Color posOrange = Color(0xFFFF7A1A);
  static const Color posCardBg = Colors.white;
  static const Color posTextDark = Color(0xFF1E293B);
  static const Color posTextMuted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final fromStr = _df.format(_fromDate);
      final toStr = _df.format(_toDate);
      final response = await ApiClient.get(
        '${ApiEndpoints.hrmsHandovers}?from_date=$fromStr&to_date=$toStr',
      );

      if (mounted) {
        setState(() {
          _handovers = response['data'] ?? [];
          _summary = response['summary'] ?? {};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading handover report: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: posOrange,
              onPrimary: Colors.white,
              onSurface: posTextDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _loadReport();
    }
  }

  List<dynamic> get _filteredHandovers {
    if (_searchQuery.trim().isEmpty) return _handovers;
    final q = _searchQuery.toLowerCase();
    return _handovers.where((h) {
      final cashierName = (h['cashier']?['full_name'] ?? h['cashier']?['username'] ?? '').toString().toLowerCase();
      final dateStr = (h['handover_date'] ?? '').toString().toLowerCase();
      return cashierName.contains(q) || dateStr.contains(q);
    }).toList();
  }

  void _showDenominationsModal(Map<String, dynamic> item) {
    final Map<String, dynamic> denoms = Map<String, dynamic>.from(item['denominations'] ?? {});
    final cashierName = item['cashier']?['full_name'] ?? item['cashier']?['username'] ?? 'Cashier #${item['cashier_id']}';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.point_of_sale_outlined, color: posOrange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Denomination Breakdown - $cashierName',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: posTextDark),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Handover Date: ${item['handover_date']}', style: const TextStyle(fontSize: 13, color: posTextMuted)),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: denoms.entries.map((e) {
                    final keyLabel = e.key == 'coins' ? 'Coins' : '₹${e.key}';
                    final count = int.tryParse(e.value.toString()) ?? 0;
                    final multiplier = e.key == 'coins' ? 1.0 : (double.tryParse(e.key) ?? 0);
                    final subtotal = count * multiplier;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$keyLabel  ×  $count', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(_inr.format(subtotal), style: const TextStyle(fontWeight: FontWeight.bold, color: posOrange)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Physical Cash:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    _inr.format(double.tryParse(item['physical_cash']?.toString() ?? '') ?? 0),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: posOrange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportExcel() async {
    try {
      var excel = exc.Excel.createExcel();
      exc.Sheet sheet = excel['Cashier Handovers'];
      excel.setDefaultSheet('Cashier Handovers');

      sheet.appendRow([
        exc.TextCellValue('Handover Date'),
        exc.TextCellValue('Cashier Name'),
        exc.TextCellValue('Expected Cash (₹)'),
        exc.TextCellValue('Physical Cash (₹)'),
        exc.TextCellValue('Variance (₹)'),
        exc.TextCellValue('Status'),
      ]);

      for (var h in _filteredHandovers) {
        final cName = h['cashier']?['full_name'] ?? h['cashier']?['username'] ?? 'Cashier #${h['cashier_id']}';
        sheet.appendRow([
          exc.TextCellValue((h['handover_date'] ?? '').toString()),
          exc.TextCellValue(cName.toString()),
          exc.DoubleCellValue(double.tryParse(h['expected_cash']?.toString() ?? '') ?? 0),
          exc.DoubleCellValue(double.tryParse(h['physical_cash']?.toString() ?? '') ?? 0),
          exc.DoubleCellValue(double.tryParse(h['variance']?.toString() ?? '') ?? 0),
          exc.TextCellValue((h['shortage_status'] ?? '').toString()),
        ]);
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Cashier_Handover_Report_${_df.format(DateTime.now())}.xlsx');
      await file.writeAsBytes(excel.encode()!);
      await OpenFile.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel Export Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportPdf() async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Cashier Handover Day-Wise Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Period: ${_df.format(_fromDate)} to ${_df.format(_toDate)}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: ['Date', 'Cashier Name', 'Expected (₹)', 'Physical (₹)', 'Variance (₹)', 'Status'],
                data: _filteredHandovers.map((h) {
                  final cName = h['cashier']?['full_name'] ?? h['cashier']?['username'] ?? 'Cashier #${h['cashier_id']}';
                  final exp = double.tryParse(h['expected_cash']?.toString() ?? '') ?? 0;
                  final phy = double.tryParse(h['physical_cash']?.toString() ?? '') ?? 0;
                  final vrc = double.tryParse(h['variance']?.toString() ?? '') ?? 0;
                  return [
                    h['handover_date'] ?? '',
                    cName,
                    exp.toStringAsFixed(2),
                    phy.toStringAsFixed(2),
                    vrc.toStringAsFixed(2),
                    h['shortage_status'] ?? '',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
                cellHeight: 25,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.center,
                },
              ),
            ];
          },
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Cashier_Handover_Report_${_df.format(DateTime.now())}.pdf');
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Export Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: posBgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: posTextDark),
        title: const Row(
          children: [
            Icon(Icons.badge_outlined, color: posOrange),
            SizedBox(width: 10),
            Text(
              'Cashier Shift Handover Analytics',
              style: TextStyle(color: posTextDark, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFDC2626)),
            tooltip: 'Export PDF Report',
            onPressed: _exportPdf,
          ),
          IconButton(
            icon: const Icon(Icons.table_chart_outlined, color: Color(0xFF16A34A)),
            tooltip: 'Export Excel Spreadsheet',
            onPressed: _exportExcel,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: posOrange),
            tooltip: 'Refresh Data',
            onPressed: _loadReport,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: posOrange,
          unselectedLabelColor: posTextMuted,
          indicatorColor: posOrange,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_today_rounded, size: 18), text: 'Day-Wise Handover Logs'),
            Tab(icon: Icon(Icons.group_outlined, size: 18), text: 'Cashier-Wise Performance Summary'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: posOrange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderFilterBar(),
                  const SizedBox(height: 16),
                  _buildKpiMetricsGrid(),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 600,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDayWiseTableTab(),
                        _buildCashierSummaryTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: posCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search cashier name or date...',
                prefixIcon: const Icon(Icons.search, color: posTextMuted),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
          ),
          const SizedBox(width: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              side: const BorderSide(color: posOrange),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _selectDateRange(context),
            icon: const Icon(Icons.date_range, color: posOrange, size: 18),
            label: Text(
              '${_df.format(_fromDate)}  ➜  ${_df.format(_toDate)}',
              style: const TextStyle(color: posTextDark, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiMetricsGrid() {
    final double totalExp = double.tryParse(_summary['total_expected_cash']?.toString() ?? '') ?? 0;
    final double totalPhy = double.tryParse(_summary['total_physical_cash']?.toString() ?? '') ?? 0;
    final double totalVrc = double.tryParse(_summary['total_variance']?.toString() ?? '') ?? 0;
    final int shortageCnt = int.tryParse(_summary['shortage_count']?.toString() ?? '') ?? 0;

    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            title: 'Total Handover Days',
            value: '${_summary['total_handovers'] ?? 0}',
            subtext: 'Completed shift records',
            icon: Icons.receipt_long,
            iconBg: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _kpiCard(
            title: 'Expected Cash',
            value: _inr.format(totalExp),
            subtext: 'Calculated POS sales',
            icon: Icons.account_balance_wallet_outlined,
            iconBg: const Color(0xFFF0FDF4),
            iconColor: const Color(0xFF16A34A),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _kpiCard(
            title: 'Physical Cash Collected',
            value: _inr.format(totalPhy),
            subtext: 'Counted by cashiers',
            icon: Icons.payments_outlined,
            iconBg: const Color(0xFFFFF7ED),
            iconColor: posOrange,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _kpiCard(
            title: 'Net Variance (Surplus/Shortage)',
            value: _inr.format(totalVrc),
            subtext: shortageCnt > 0 ? '$shortageCnt shift shortage alert(s)' : 'All shifts matched',
            icon: totalVrc < 0 ? Icons.warning_rounded : Icons.check_circle_rounded,
            iconBg: totalVrc < 0 ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
            iconColor: totalVrc < 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
          ),
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: posCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: iconBg,
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: posTextMuted)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: posTextDark)),
                const SizedBox(height: 2),
                Text(subtext, style: TextStyle(fontSize: 11, color: iconColor, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayWiseTableTab() {
    final list = _filteredHandovers;
    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: posCardBg, borderRadius: BorderRadius.circular(16)),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: posTextMuted),
              SizedBox(height: 10),
              Text('No cashier shift handovers found for the selected period.', style: TextStyle(color: posTextMuted, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: posCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F1EB)),
              headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: posTextDark, fontSize: 13),
              dataRowMaxHeight: 56,
              columns: const [
                DataColumn(label: Text('Handover Date')),
                DataColumn(label: Text('Cashier Name')),
                DataColumn(label: Text('Expected Cash (POS)')),
                DataColumn(label: Text('Physical Cash (Drawer)')),
                DataColumn(label: Text('Variance')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Denominations Breakdown')),
              ],
              rows: list.map((item) {
                final cName = item['cashier']?['full_name'] ?? item['cashier']?['username'] ?? 'Cashier #${item['cashier_id']}';
                final exp = double.tryParse(item['expected_cash']?.toString() ?? '') ?? 0;
                final phy = double.tryParse(item['physical_cash']?.toString() ?? '') ?? 0;
                final vrc = double.tryParse(item['variance']?.toString() ?? '') ?? 0;
                final isShortage = vrc < 0;

                return DataRow(
                  cells: [
                    DataCell(Text(item['handover_date'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: const Color(0xFFFFEAD5),
                            child: Text(cName.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: posOrange)),
                          ),
                          const SizedBox(width: 8),
                          Text(cName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    DataCell(Text(_inr.format(exp), style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(_inr.format(phy), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                    DataCell(
                      Text(
                        _inr.format(vrc),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isShortage ? Colors.red : (vrc > 0 ? Colors.blue : posTextDark),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isShortage ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isShortage ? 'Shortage' : (vrc > 0 ? 'Surplus' : 'Matched'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isShortage ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFF7ED),
                          foregroundColor: posOrange,
                          elevation: 0,
                          side: const BorderSide(color: Color(0xFFFFEDD5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _showDenominationsModal(item),
                        icon: const Icon(Icons.remove_red_eye_outlined, size: 14),
                        label: const Text('View Breakdown', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCashierSummaryTab() {
    final List<dynamic> breakdown = _summary['cashier_breakdown'] ?? [];
    if (breakdown.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: posCardBg, borderRadius: BorderRadius.circular(16)),
        child: const Center(
          child: Text('No cashier performance summary data available.', style: TextStyle(color: posTextMuted, fontSize: 14)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: posCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: breakdown.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
          itemBuilder: (ctx, index) {
            final c = breakdown[index];
            final cName = c['cashier_name'] ?? 'Cashier #${c['cashier_id']}';
            final int handoversCount = c['total_handovers'] ?? 0;
            final double expTotal = double.tryParse(c['total_expected']?.toString() ?? '') ?? 0;
            final double phyTotal = double.tryParse(c['total_physical']?.toString() ?? '') ?? 0;
            final double vrcTotal = double.tryParse(c['total_variance']?.toString() ?? '') ?? 0;
            final int shortages = c['shortage_count'] ?? 0;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFFFEAD5),
                child: Text(
                  cName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: posOrange),
                ),
              ),
              title: Text(cName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: posTextDark)),
              subtitle: Text(
                'Total Handovers: $handoversCount  •  Shortage Incidents: $shortages',
                style: const TextStyle(fontSize: 12, color: posTextMuted),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_inr.format(phyTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                  const SizedBox(height: 2),
                  Text(
                    'Variance: ${_inr.format(vrcTotal)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: vrcTotal < 0 ? Colors.red : (vrcTotal > 0 ? Colors.blue : posTextMuted),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

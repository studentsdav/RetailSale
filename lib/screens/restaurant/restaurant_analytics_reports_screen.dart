import 'dart:io';
import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../controllers/restaurant/restaurant_analytics_reports_controller.dart';
import '../../models/reports/sales_report_model.dart';

class RestaurantAnalyticsReportsScreen extends StatefulWidget {
  const RestaurantAnalyticsReportsScreen({super.key});

  @override
  State<RestaurantAnalyticsReportsScreen> createState() =>
      _RestaurantAnalyticsReportsScreenState();
}

class _RestaurantAnalyticsReportsScreenState
    extends State<RestaurantAnalyticsReportsScreen> {
  final RestaurantAnalyticsReportsController _controller =
      RestaurantAnalyticsReportsController();

  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  int _selectedTab = 0;
  bool _isLoading = false;

  final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  final List<String> _tabs = [
    'Category Wise',
    'Item Wise',
    'Waiter Wise',
    'Cashier Wise',
    'Time Wise',
    'Table Wise',
    'Takeaway',
    'NC Analysis',
    'Cancel Order',
    'Business Growth',
    'Revenue Sources',
  ];

  @override
  void initState() {
    super.initState();
    _syncDates();
    _loadData();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _syncDates() {
    _fromCtrl.text = DateFormat('dd-MM-yyyy').format(_controller.fromDate);
    _toCtrl.text = DateFormat('dd-MM-yyyy').format(_controller.toDate);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _controller.load();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _controller.fromDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _controller.fromDate = picked;
      _syncDates();
      await _loadData();
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _controller.toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _controller.toDate = picked;
      _syncDates();
      await _loadData();
    }
  }

  String _money(double val) => _inr.format(val);

  // Helper getters for filtered sales
  List<SalesReport> get _sales => _controller.salesList;

  // 1. Category Wise Rows
  List<_AggRow> get _categoryRows {
    final Map<String, _AggRow> map = {};
    for (final sale in _sales) {
      for (final item in sale.items) {
        final cat = item.itemGroup.trim().isEmpty ? 'General' : item.itemGroup.trim();
        final current = map[cat] ?? _AggRow(name: cat);
        map[cat] = current.copyWith(
          qty: current.qty + item.qty,
          amount: current.amount + item.netAmount,
          count: current.count + 1,
        );
      }
    }
    final list = map.values.toList();
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  // 2. Item Wise Rows
  List<_AggRow> get _itemRows {
    final Map<String, _AggRow> map = {};
    for (final sale in _sales) {
      for (final item in sale.items) {
        final name = item.itemName.trim().isEmpty ? 'Unknown Item' : item.itemName.trim();
        final current = map[name] ?? _AggRow(name: name, code: item.itemCode, group: item.itemGroup);
        map[name] = current.copyWith(
          qty: current.qty + item.qty,
          amount: current.amount + item.netAmount,
          count: current.count + 1,
        );
      }
    }
    final list = map.values.toList();
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  // 3. Waiter Wise Rows
  List<_AggRow> get _waiterRows {
    final Map<String, _AggRow> map = {};
    for (final sale in _sales) {
      String waiter = 'Default Captain';
      final ref = sale.paymentReference;
      if (ref.contains('CAPTAIN:')) {
        waiter = ref.split('CAPTAIN:').last.split(';').first.trim();
      } else if (sale.notes.contains('Captain:')) {
        waiter = sale.notes.split('Captain:').last.split('\n').first.trim();
      }
      final current = map[waiter] ?? _AggRow(name: waiter);
      map[waiter] = current.copyWith(
        amount: current.amount + sale.netAmount,
        count: current.count + 1,
        qty: current.qty + sale.totalQty,
      );
    }
    final list = map.values.toList();
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  // 4. Cashier Wise Rows
  List<_AggRow> get _cashierRows {
    final Map<String, _AggRow> map = {};
    for (final sale in _sales) {
      String cashier = 'Main Counter';
      if (sale.notes.contains('Cashier:')) {
        cashier = sale.notes.split('Cashier:').last.split('\n').first.trim();
      } else if (sale.customerName.startsWith('Cashier:')) {
        cashier = sale.customerName.replaceFirst('Cashier:', '').trim();
      }
      final current = map[cashier] ?? _AggRow(name: cashier);
      map[cashier] = current.copyWith(
        amount: current.amount + sale.netAmount,
        count: current.count + 1,
        qty: current.qty + sale.totalQty,
      );
    }
    final list = map.values.toList();
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  // 5. Time Wise Rows
  List<_AggRow> get _timeZoneRows {
    final Map<String, _AggRow> map = {
      'Morning (5 AM - 11 AM)': _AggRow(name: 'Morning (5 AM - 11 AM)'),
      'Afternoon (12 PM - 4 PM)': _AggRow(name: 'Afternoon (12 PM - 4 PM)'),
      'Evening (5 PM - 8 PM)': _AggRow(name: 'Evening (5 PM - 8 PM)'),
      'Night (9 PM - 4 AM)': _AggRow(name: 'Night (9 PM - 4 AM)'),
    };
    for (final sale in _sales) {
      final hour = sale.saleDate.hour;
      String zoneKey = 'Night (9 PM - 4 AM)';
      if (hour >= 5 && hour <= 11) zoneKey = 'Morning (5 AM - 11 AM)';
      else if (hour >= 12 && hour <= 16) zoneKey = 'Afternoon (12 PM - 4 PM)';
      else if (hour >= 17 && hour <= 20) zoneKey = 'Evening (5 PM - 8 PM)';

      final current = map[zoneKey]!;
      map[zoneKey] = current.copyWith(
        amount: current.amount + sale.netAmount,
        count: current.count + 1,
        qty: current.qty + sale.totalQty,
      );
    }
    return map.values.toList();
  }

  // 6. Table Wise Rows
  List<_AggRow> get _tableRows {
    final Map<String, _AggRow> map = {};
    for (final sale in _sales) {
      if (sale.orderType.toUpperCase() == 'DINE_IN' || sale.notes.contains('Table:')) {
        String tableNo = 'Table Main';
        if (sale.notes.contains('Table:')) {
          tableNo = 'Table ${sale.notes.split('Table:').last.split(';').first.trim()}';
        }
        final current = map[tableNo] ?? _AggRow(name: tableNo);
        map[tableNo] = current.copyWith(
          amount: current.amount + sale.netAmount,
          count: current.count + 1,
          qty: current.qty + sale.totalQty,
        );
      }
    }
    final list = map.values.toList();
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  // 7. Takeaway / Order Type Rows
  List<_AggRow> get _takeawayRows {
    final Map<String, _AggRow> map = {};
    for (final sale in _sales) {
      final type = sale.orderType.trim().isEmpty ? 'DINE_IN' : sale.orderType.toUpperCase();
      final current = map[type] ?? _AggRow(name: type);
      map[type] = current.copyWith(
        amount: current.amount + sale.netAmount,
        count: current.count + 1,
        qty: current.qty + sale.totalQty,
      );
    }
    final list = map.values.toList();
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  // 8. NC Analysis Rows
  List<_AggRow> get _ncRows {
    final List<_AggRow> list = [];
    for (final sale in _sales) {
      if (sale.orderType.toUpperCase() == 'NC' || sale.paymentMode.toUpperCase() == 'NC' || sale.notes.toLowerCase().contains('nc') || sale.notes.toLowerCase().contains('complimentary')) {
        list.add(_AggRow(
          name: sale.saleNo,
          group: DateFormat('dd-MM-yyyy hh:mm a').format(sale.saleDate),
          code: sale.customerName.isEmpty ? 'Walk-in' : sale.customerName,
          amount: sale.netAmount,
          count: 1,
          qty: sale.totalQty,
        ));
      }
    }
    return list;
  }

  // 9. Cancel Order Rows
  List<_AggRow> get _cancelRows {
    final List<_AggRow> list = [];
    for (final sale in _sales) {
      if (sale.notes.toLowerCase().contains('cancel') || sale.notes.toLowerCase().contains('void') || sale.notes.toLowerCase().contains('refund')) {
        list.add(_AggRow(
          name: sale.saleNo,
          group: DateFormat('dd-MM-yyyy hh:mm a').format(sale.saleDate),
          code: sale.customerName.isEmpty ? 'Customer' : sale.customerName,
          amount: sale.netAmount,
          count: 1,
          qty: sale.totalQty,
        ));
      }
    }
    return list;
  }

  // 10. Growth Rows (DoD / MoM)
  List<_AggRow> get _growthRows {
    final Map<String, _AggRow> map = {};
    for (final sale in _sales) {
      final dayKey = DateFormat('dd-MM-yyyy').format(sale.saleDate);
      final current = map[dayKey] ?? _AggRow(name: dayKey);
      map[dayKey] = current.copyWith(
        amount: current.amount + sale.netAmount,
        count: current.count + 1,
        qty: current.qty + sale.totalQty,
      );
    }
    final list = map.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  // 11. Revenue Sources
  List<_AggRow> get _revenueSourceRows {
    double dineIn = 0;
    double takeaway = 0;
    double delivery = 0;
    double nc = 0;
    for (final sale in _sales) {
      final type = sale.orderType.toUpperCase();
      if (type == 'NC' || sale.paymentMode.toUpperCase() == 'NC') {
        nc += sale.netAmount;
      } else if (type == 'TAKEAWAY') {
        takeaway += sale.netAmount;
      } else if (type == 'DELIVERY') {
        delivery += sale.netAmount;
      } else {
        dineIn += sale.netAmount;
      }
    }
    return [
      _AggRow(name: 'Restaurant Dine-In', amount: dineIn, count: 1),
      _AggRow(name: 'Takeaway Orders', amount: takeaway, count: 1),
      _AggRow(name: 'Delivery Orders', amount: delivery, count: 1),
      _AggRow(name: 'NC / Complimentary', amount: nc, count: 1),
    ];
  }

  // --- Export Excel ---
  Future<void> _exportExcel() async {
    final workbook = exc.Excel.createExcel();
    final tabName = _tabs[_selectedTab].replaceAll(' ', '_');
    final defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null) {
      workbook.rename(defaultSheet, tabName);
    }
    final sheet = workbook[tabName];

    sheet.appendRow([
      'Name / Parameter',
      'Detail / Code',
      'Txn Count',
      'Quantity',
      'Total Amount (₹)'
    ].map(exc.TextCellValue.new).toList());

    final currentRows = _getCurrentActiveRows();
    double totalAmt = 0;
    double totalQty = 0;
    int totalCount = 0;

    for (final r in currentRows) {
      totalAmt += r.amount;
      totalQty += r.qty;
      totalCount += r.count;
      sheet.appendRow([
        exc.TextCellValue(r.name),
        exc.TextCellValue(r.group.isNotEmpty ? r.group : r.code),
        exc.IntCellValue(r.count),
        exc.DoubleCellValue(r.qty),
        exc.DoubleCellValue(r.amount),
      ]);
    }

    sheet.appendRow([
      exc.TextCellValue('TOTAL'),
      exc.TextCellValue(''),
      exc.IntCellValue(totalCount),
      exc.DoubleCellValue(totalQty),
      exc.DoubleCellValue(totalAmt),
    ]);

    final bytes = workbook.encode();
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}${Platform.pathSeparator}restaurant_${tabName}_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    await file.writeAsBytes(bytes, flush: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Excel exported: ${file.path}')),
    );
    await OpenFile.open(file.path);
  }

  String _pdfMoney(double val) => val.toStringAsFixed(2);

  // --- Export PDF ---
  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final tabTitle = '${_tabs[_selectedTab]} Sales Analysis';
    final activeRows = _getCurrentActiveRows();

    double totalAmt = 0;
    double totalQty = 0;
    int totalCount = 0;

    final dataList = activeRows.map((r) {
      totalAmt += r.amount;
      totalQty += r.qty;
      totalCount += r.count;
      return [
        r.name,
        r.group.isNotEmpty ? r.group : r.code,
        '${r.count}',
        r.qty.toStringAsFixed(2),
        _pdfMoney(r.amount),
      ];
    }).toList();

    dataList.add([
      'TOTAL',
      '',
      '$totalCount',
      totalQty.toStringAsFixed(2),
      _pdfMoney(totalAmt),
    ]);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(16),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              'Restaurant $tabTitle',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Period: ${DateFormat('dd-MM-yyyy').format(_controller.fromDate)} to ${DateFormat('dd-MM-yyyy').format(_controller.toDate)}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey600),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfBlock('Total Revenue', _pdfMoney(totalAmt)),
                  _pdfBlock('Total Transactions', '$totalCount Txns'),
                  _pdfBlock('Total Quantity', totalQty.toStringAsFixed(2)),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              headers: ['Name / Label', 'Group / Detail', 'Txns', 'Quantity', 'Total Sales'],
              data: dataList,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
            ),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}${Platform.pathSeparator}restaurant_${_selectedTab}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save(), flush: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF exported: ${file.path}')),
    );
    await OpenFile.open(file.path);
  }

  pw.Widget _pdfBlock(String label, String val) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 3),
        pw.Text(val, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  List<_AggRow> _getCurrentActiveRows() {
    switch (_selectedTab) {
      case 0: return _categoryRows;
      case 1: return _itemRows;
      case 2: return _waiterRows;
      case 3: return _cashierRows;
      case 4: return _timeZoneRows;
      case 5: return _tableRows;
      case 6: return _takeawayRows;
      case 7: return _ncRows;
      case 8: return _cancelRows;
      case 9: return _growthRows;
      case 10: return _revenueSourceRows;
      default: return _categoryRows;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeRows = _getCurrentActiveRows();
    final double grandTotalRevenue = activeRows.fold(0.0, (s, r) => s + r.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Analytics & Sales Reports'),
        actions: [
          IconButton(
            tooltip: 'Export Excel',
            icon: const Icon(Icons.table_chart_outlined, color: Colors.green),
            onPressed: _exportExcel,
          ),
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
            onPressed: _exportPdf,
          ),
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top Filters
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _dateField('From Date', _fromCtrl, _pickFromDate),
                        _dateField('To Date', _toCtrl, _pickToDate),
                        SizedBox(
                          width: 240,
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Filter Reports',
                              hintText: 'Search menu item, waiter, table...',
                              prefixIcon: const Icon(Icons.search),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Executive KPI Cards
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      SizedBox(width: 230, child: _kpiCard('Total Revenue', _money(grandTotalRevenue), Icons.account_balance_wallet, const Color(0xFF16A34A))),
                      SizedBox(width: 230, child: _kpiCard('Total Active Categories', '${_categoryRows.length}', Icons.category, const Color(0xFF2563EB))),
                      SizedBox(width: 230, child: _kpiCard('Dine-In Sales', _money(_takeawayRows.firstWhere((r) => r.name == 'DINE_IN', orElse: () => const _AggRow(name: 'DINE_IN')).amount), Icons.restaurant, const Color(0xFF0F766E))),
                      SizedBox(width: 230, child: _kpiCard('Takeaway Sales', _money(_takeawayRows.firstWhere((r) => r.name == 'TAKEAWAY', orElse: () => const _AggRow(name: 'TAKEAWAY')).amount), Icons.takeout_dining, const Color(0xFFEA580C))),
                      SizedBox(width: 230, child: _kpiCard('NC Consumption', _money(_ncRows.fold(0.0, (s, r) => s + r.amount)), Icons.card_giftcard, const Color(0xFF7C3AED))),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. Category Tab Bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_tabs.length, (index) {
                        final selected = _selectedTab == index;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(_tabs[index]),
                            selected: selected,
                            onSelected: (_) => setState(() => _selectedTab = index),
                            selectedColor: const Color(0xFF17324D),
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : const Color(0xFF17324D),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Analytics Visualizations (Store Analysis Style Chart)
                  Container(
                    height: 360,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_tabs[_selectedTab]} Leaderboard & Distribution',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        const Text('Visual revenue breakdown by top contributors', style: TextStyle(color: Color(0xFF64748B))),
                        const SizedBox(height: 12),
                        Expanded(
                          child: SfCartesianChart(
                            primaryXAxis: CategoryAxis(labelRotation: -25),
                            tooltipBehavior: TooltipBehavior(enable: true),
                            series: <CartesianSeries<_AggRow, String>>[
                              ColumnSeries<_AggRow, String>(
                                dataSource: activeRows.take(10).toList(),
                                xValueMapper: (_AggRow data, _) => data.name.length > 15 ? '${data.name.substring(0, 12)}...' : data.name,
                                yValueMapper: (_AggRow data, _) => data.amount,
                                name: 'Sales Revenue (₹)',
                                color: const Color(0xFF0F766E),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. Detailed Data Table
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_tabs[_selectedTab]} Detailed Table',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                            columns: const [
                              DataColumn(label: Text('Name / Label')),
                              DataColumn(label: Text('Group / Detail')),
                              DataColumn(label: Text('Txn Count')),
                              DataColumn(label: Text('Quantity')),
                              DataColumn(label: Text('Total Amount')),
                            ],
                            rows: [
                              ...activeRows.map(
                                (r) => DataRow(
                                  cells: [
                                    DataCell(Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                                    DataCell(Text(r.group.isNotEmpty ? r.group : r.code)),
                                    DataCell(Text('${r.count}')),
                                    DataCell(Text(r.qty.toStringAsFixed(2))),
                                    DataCell(Text(_money(r.amount), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F766E)))),
                                  ],
                                ),
                              ),
                              DataRow(
                                color: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                cells: [
                                  const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w800))),
                                  const DataCell(Text('')),
                                  DataCell(Text('${activeRows.fold<int>(0, (s, r) => s + r.count)}', style: const TextStyle(fontWeight: FontWeight.w800))),
                                  DataCell(Text(activeRows.fold<double>(0, (s, r) => s + r.qty).toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w800))),
                                  DataCell(Text(_money(grandTotalRevenue), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F766E)))),
                                ],
                              ),
                            ],
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

  Widget _dateField(String label, TextEditingController controller, VoidCallback onTap) {
    return SizedBox(
      width: 170,
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_month_outlined, size: 18),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AggRow {
  final String name;
  final String group;
  final String code;
  final double qty;
  final double amount;
  final int count;

  const _AggRow({
    required this.name,
    this.group = '',
    this.code = '',
    this.qty = 0,
    this.amount = 0,
    this.count = 0,
  });

  _AggRow copyWith({
    String? name,
    String? group,
    String? code,
    double? qty,
    double? amount,
    int? count,
  }) {
    return _AggRow(
      name: name ?? this.name,
      group: group ?? this.group,
      code: code ?? this.code,
      qty: qty ?? this.qty,
      amount: amount ?? this.amount,
      count: count ?? this.count,
    );
  }
}

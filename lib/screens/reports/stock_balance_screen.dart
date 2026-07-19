import 'dart:io';

import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../controllers/reports/stock_balance_controller.dart';
import '../../models/reports/stock_item_model.dart';

class StockBalanceScreen extends StatefulWidget {
  const StockBalanceScreen({super.key});

  @override
  State<StockBalanceScreen> createState() => _StockBalanceScreenState();
}

class _StockBalanceScreenState extends State<StockBalanceScreen> {
  final ctrl = StockBalanceController();
  final searchCtrl = TextEditingController();

  String statusFilter = 'ALL';
  String categoryFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    ctrl.load();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _categories =>
      ctrl.items.map((item) => item.category).toSet().toList()..sort();

  List<StockItem> get _filteredItems {
    final query = searchCtrl.text.trim().toLowerCase();
    final items = ctrl.items.where((item) {
      final matchesSearch = query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query);
      final matchesCategory =
          categoryFilter == 'ALL' || item.category == categoryFilter;
      final matchesStatus = switch (statusFilter) {
        'REORDER' => item.stockStatus == 'REORDER',
        'LOW_BUFFER' => item.stockStatus == 'LOW_BUFFER',
        'HEALTHY' => item.stockStatus == 'HEALTHY',
        'NO_MIN' => item.stockStatus == 'NO_MIN',
        _ => true,
      };
      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();

    items.sort((a, b) {
      const rank = {
        'REORDER': 0,
        'LOW_BUFFER': 1,
        'HEALTHY': 2,
        'NO_MIN': 3,
      };
      final byStatus =
          (rank[a.stockStatus] ?? 9).compareTo(rank[b.stockStatus] ?? 9);
      if (byStatus != 0) return byStatus;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }

  List<CategoryStock> get _filteredCategoryData {
    final map = <String, double>{};
    for (final item in _filteredItems) {
      map[item.category] = (map[item.category] ?? 0) + item.value;
    }
    return map.entries
        .map((entry) => CategoryStock(entry.key, entry.value))
        .toList();
  }

  List<StockItem> get _topFilteredItems {
    final items = [..._filteredItems];
    items.sort((a, b) => b.value.compareTo(a.value));
    return items.take(5).toList();
  }

  int get _visibleQty =>
      _filteredItems.fold(0, (sum, item) => sum + item.qty.toInt());

  double get _visibleValue =>
      _filteredItems.fold(0, (sum, item) => sum + item.value);

  int get _reorderCount =>
      _filteredItems.where((item) => item.stockStatus == 'REORDER').length;

  double get _shortfall =>
      _filteredItems.fold(0, (sum, item) => sum + item.shortfall);

  String _money(double value) => 'Rs. ${value.toStringAsFixed(2)}';

  String _qty(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  String _statusLabel(StockItem item) {
    switch (item.stockStatus) {
      case 'REORDER':
        return 'At Reorder';
      case 'LOW_BUFFER':
        return 'Near Minimum';
      case 'HEALTHY':
        return 'Healthy';
      default:
        return 'No Minimum';
    }
  }

  Color _statusColor(StockItem item) {
    switch (item.stockStatus) {
      case 'REORDER':
        return Colors.red.shade700;
      case 'LOW_BUFFER':
        return Colors.orange.shade700;
      case 'HEALTHY':
        return Colors.green.shade700;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  Color _rowShade(StockItem item) {
    switch (item.stockStatus) {
      case 'REORDER':
        return Colors.red.withOpacity(.10);
      case 'LOW_BUFFER':
        return Colors.orange.withOpacity(.10);
      case 'HEALTHY':
        return Colors.green.withOpacity(.06);
      default:
        return Colors.blueGrey.withOpacity(.06);
    }
  }

  Future<void> _exportExcel() async {
    final excel = exc.Excel.createExcel();
    final sheet = excel['Reorder Report'];
    int row = 0;

    void setTextCell(int column, int rowIndex, String value,
        {String? backgroundHex, String? fontHex, bool bold = false}) {
      final cell = sheet.cell(
        exc.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: rowIndex),
      );
      cell.value = exc.TextCellValue(value);

      // HELPER: Safely parses the hex string to Excel format or returns 'none'
      exc.ExcelColor parseColor(String? hex) {
        if (hex == null) return exc.ExcelColor.none; // Replaces 'null'

        // Remove '#' and force 8-character ARGB format (FF = 100% opacity)
        String cleanHex = hex.replaceAll('#', '');
        if (cleanHex.length == 6) {
          cleanHex = 'FF$cleanHex';
        }
        return exc.ExcelColor.fromHexString(cleanHex);
      }

      // Assign the style using our safe parser
      cell.cellStyle = exc.CellStyle(
        bold: bold,
        backgroundColorHex: parseColor(backgroundHex),
        fontColorHex: parseColor(fontHex),
      );
    }

    setTextCell(0, row, 'REORDER / MINIMUM LEVEL STOCK REPORT',
        bold: true, fontHex: '#1F2937');
    row += 2;

    setTextCell(
      0,
      row,
      'Status: $statusFilter    Category: $categoryFilter    Search: ${searchCtrl.text.trim().isEmpty ? 'ALL' : searchCtrl.text.trim()}',
    );
    row += 2;

    const headers = [
      'Item',
      'Category',
      'Unit',
      'Minimum Level',
      'Balance Stock',
      'Shortfall',
      'Rate',
      'Value',
      'Status',
    ];

    for (int i = 0; i < headers.length; i++) {
      setTextCell(i, row, headers[i],
          bold: true, backgroundHex: '#1D4ED8', fontHex: '#FFFFFF');
      sheet.setColumnWidth(i, i == 0 ? 28 : 16);
    }
    row++;

    for (final item in _filteredItems) {
      final bgHex = item.stockStatus == 'REORDER'
          ? '#FEE2E2'
          : item.stockStatus == 'LOW_BUFFER'
              ? '#FEF3C7'
              : item.stockStatus == 'HEALTHY'
                  ? '#DCFCE7'
                  : '#E2E8F0';
      final values = [
        '${item.name}${item.brand.isNotEmpty ? ' (${item.brand})' : ''}',
        item.category,
        item.unit,
        _qty(item.reorder),
        _qty(item.qty),
        item.shortfall > 0 ? _qty(item.shortfall) : '-',
        item.rate.toStringAsFixed(2),
        item.value.toStringAsFixed(2),
        _statusLabel(item),
      ];
      for (int i = 0; i < values.length; i++) {
        setTextCell(i, row, values[i], backgroundHex: bgHex);
      }
      row++;
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/reorder_report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    await file.writeAsBytes(excel.encode()!);
    await OpenFile.open(file.path);
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (_) => [
          pw.Text(
            'Reorder / Minimum Level Stock Report',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Status: $statusFilter   Category: $categoryFilter   Search: ${searchCtrl.text.trim().isEmpty ? 'ALL' : searchCtrl.text.trim()}',
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.3),
              1: pw.FlexColumnWidth(1.5),
              8: pw.FlexColumnWidth(1.4),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue700),
                children: [
                  for (final header in const [
                    'Item',
                    'Category',
                    'Unit',
                    'Minimum',
                    'Balance',
                    'Shortfall',
                    'Rate',
                    'Value',
                    'Status',
                  ])
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        header,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              for (final item in _filteredItems)
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: item.stockStatus == 'REORDER'
                        ? PdfColors.red50
                        : item.stockStatus == 'LOW_BUFFER'
                            ? PdfColors.amber50
                            : item.stockStatus == 'HEALTHY'
                                ? PdfColors.green50
                                : PdfColors.blueGrey50,
                  ),
                  children: [
                    for (final value in [
                       '${item.name}${item.brand.isNotEmpty ? ' (${item.brand})' : ''}',
                      item.category,
                      item.unit,
                      _qty(item.reorder),
                      _qty(item.qty),
                      item.shortfall > 0 ? _qty(item.shortfall) : '-',
                      item.rate.toStringAsFixed(2),
                      item.value.toStringAsFixed(2),
                      _statusLabel(item),
                    ])
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(value),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(name: 'Stock_Balance_Report', onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text('Stock Balance & Reorder Report'),
        actions: [
          IconButton(
            onPressed: _exportExcel,
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            onPressed: ctrl.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: ctrl,
        builder: (context, _) {
          if (ctrl.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _filterBar(),
                const SizedBox(height: 12),
                _kpiWrap(),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final vertical = constraints.maxWidth < 980;
                      if (vertical) {
                        return Column(
                          children: [
                            Expanded(child: _categoryChart()),
                            const SizedBox(height: 12),
                            Expanded(child: _topItemsChart()),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: _categoryChart()),
                          const SizedBox(width: 12),
                          Expanded(child: _topItemsChart()),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(child: _stockTable()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Search item or category',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String>(
              initialValue: statusFilter,
              decoration: const InputDecoration(labelText: 'Stock Status'),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Items')),
                DropdownMenuItem(value: 'REORDER', child: Text('At Reorder')),
                DropdownMenuItem(
                    value: 'LOW_BUFFER', child: Text('Near Minimum')),
                DropdownMenuItem(value: 'HEALTHY', child: Text('Healthy')),
                DropdownMenuItem(value: 'NO_MIN', child: Text('No Minimum')),
              ],
              onChanged: (value) =>
                  setState(() => statusFilter = value ?? 'ALL'),
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              initialValue: categoryFilter,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem(
                    value: 'ALL', child: Text('All Categories')),
                ..._categories.map(
                  (category) =>
                      DropdownMenuItem(value: category, child: Text(category)),
                ),
              ],
              onChanged: (value) =>
                  setState(() => categoryFilter = value ?? 'ALL'),
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () => setState(() {
              statusFilter = 'REORDER';
              categoryFilter = 'ALL';
              searchCtrl.clear();
            }),
            icon: const Icon(Icons.warning_amber_rounded),
            label: const Text('Reorder Only'),
          ),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              statusFilter = 'ALL';
              categoryFilter = 'ALL';
              searchCtrl.clear();
            }),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Widget _kpiWrap() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _kpiCard('Visible Items', '${_filteredItems.length}',
            Icons.inventory_2_outlined, Colors.blue),
        _kpiCard('Visible Qty', '$_visibleQty', Icons.numbers, Colors.teal),
        _kpiCard('At Reorder', '$_reorderCount', Icons.warning_amber_rounded,
            Colors.red),
        _kpiCard(
            'Shortfall', _qty(_shortfall), Icons.trending_down, Colors.orange),
        _kpiCard('Stock Value', _money(_visibleValue), Icons.currency_rupee,
            Colors.indigo),
      ],
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return SizedBox(
      width: 250,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color,
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _categoryChart() {
    return Card(
      child: SfCircularChart(
        title: const ChartTitle(text: 'Filtered Stock Value by Category'),
        legend: const Legend(isVisible: true),
        series: [
          DoughnutSeries<CategoryStock, String>(
            dataSource: _filteredCategoryData,
            xValueMapper: (d, _) => d.category,
            yValueMapper: (d, _) => d.value,
            dataLabelSettings: const DataLabelSettings(isVisible: true),
          )
        ],
      ),
    );
  }

  Widget _topItemsChart() {
    return Card(
      child: SfCartesianChart(
        title: const ChartTitle(text: 'Top Filtered Items by Stock Value'),
        primaryXAxis: const CategoryAxis(),
        series: [
          BarSeries<StockItem, String>(
            dataSource: _topFilteredItems,
            xValueMapper: (d, _) => d.name,
            yValueMapper: (d, _) => d.value,
            dataLabelSettings: const DataLabelSettings(isVisible: true),
          )
        ],
      ),
    );
  }

  Widget _stockTable() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: constraints.maxHeight,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  columns: const [
                    DataColumn(label: Text('Item')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Unit')),
                    DataColumn(label: Text('Minimum')),
                    DataColumn(label: Text('Balance')),
                    DataColumn(label: Text('Shortfall')),
                    DataColumn(label: Text('Rate')),
                    DataColumn(label: Text('Value')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: _filteredItems.map((item) {
                    return DataRow(
                      color: WidgetStateProperty.all(_rowShade(item)),
                      cells: [
                         DataCell(Text('${item.name}${item.brand.isNotEmpty ? ' (${item.brand})' : ''}')),
                        DataCell(Text(item.category)),
                        DataCell(Text(item.unit)),
                        DataCell(Text(_qty(item.reorder))),
                        DataCell(Text(_qty(item.qty))),
                        DataCell(Text(
                          item.shortfall > 0 ? _qty(item.shortfall) : '-',
                          style: TextStyle(
                            color: item.shortfall > 0
                                ? Colors.red.shade700
                                : Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        )),
                        DataCell(Text(item.rate.toStringAsFixed(2))),
                        DataCell(Text(item.value.toStringAsFixed(2))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _statusColor(item).withOpacity(.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _statusLabel(item),
                              style: TextStyle(
                                color: _statusColor(item),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

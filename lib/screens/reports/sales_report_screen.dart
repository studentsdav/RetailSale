import 'dart:io';

import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../controllers/reports/sales_report_controller.dart';
import '../../models/reports/sales_report_model.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final ctrl = SalesReportController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _itemSearchCtrl = TextEditingController();
  final ScrollController _gstVerticalController = ScrollController();
  final ScrollController _gstHorizontalController = ScrollController();

  String _gstFilter = 'ALL';
  String _selectedGroup = 'ALL';
  String _selectedSubCategory = 'ALL';
  String _groupBy = 'ITEM';
  int _reportTabIndex = 0;
  final int _rowsPerPage = 20;
  final int _currentPage = 0;

  static const List<_HeatmapZone> _heatmapZones = [
    _HeatmapZone(
      key: 'MORNING',
      label: 'Morning\n8AM-12PM',
      startHour: 8,
      endHourExclusive: 12,
    ),
    _HeatmapZone(
      key: 'AFTERNOON',
      label: 'Afternoon\n12PM-4PM',
      startHour: 12,
      endHourExclusive: 16,
    ),
    _HeatmapZone(
      key: 'EVENING',
      label: 'Evening\n4PM-8PM',
      startHour: 16,
      endHourExclusive: 20,
    ),
    _HeatmapZone(
      key: 'NIGHT',
      label: 'Night\n8PM-12AM',
      startHour: 20,
      endHourExclusive: 24,
    ),
  ];

  static const List<String> _gstHeaders = [
    'Invoice Date (DD-MM-YYYY)',
    'Invoice Number',
    'Customer Name',
    'Customer GSTIN',
    'Place of Supply (State Name/Code)',
    'Item Description',
    'HSN/SAC Code',
    'Quantity & UQC (Unit)',
    'Taxable Value',
    'CGST Amount',
    'SGST Amount',
    'IGST Amount',
    'Total Invoice Value',
  ];

  @override
  void initState() {
    super.initState();
    ctrl.init();
    _syncDates();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _itemSearchCtrl.dispose();
    _gstVerticalController.dispose();
    _gstHorizontalController.dispose();
    ctrl.dispose();
    super.dispose();
  }

  void _syncDates() {
    _fromCtrl.text = DateFormat('dd-MM-yyyy').format(ctrl.fromDate);
    _toCtrl.text = DateFormat('dd-MM-yyyy').format(ctrl.toDate);
  }

  List<_GstSalesRow> get _rows {
    final flattened = <_GstSalesRow>[];
    for (final sale in ctrl.list) {
      final customerGstin = sale.customerGstin.trim();
      if (_gstFilter == 'B2B_ONLY' && customerGstin.isEmpty) continue;
      if (_gstFilter == 'B2C_ONLY' && customerGstin.isNotEmpty) continue;

      final placeOfSupply = _derivePlaceOfSupply(sale);
      for (final item in sale.items) {
        flattened.add(
          _GstSalesRow(
            invoiceDate: sale.saleDate,
            invoiceNumber: sale.saleNo,
            customerName: sale.customerName.trim().isEmpty
                ? 'Walk-in Customer'
                : sale.customerName.trim(),
            customerGstin: customerGstin,
            placeOfSupply: placeOfSupply,
            itemDescription: item.itemName.trim(),
            itemGroup:
                item.itemGroup.trim().isEmpty ? 'Ungrouped' : item.itemGroup.trim(),
            subCategory: item.subCategory.trim().isEmpty
                ? 'Uncategorized'
                : item.subCategory.trim(),
            hsnSacCode: item.hsnSacCode.trim(),
            quantity: item.qty,
            unit: item.unit.trim(),
            taxableValue: item.taxableAmount,
            taxSaleValue: item.taxableAmount > 0.009 ? item.netAmount : 0,
            nonTaxSaleValue: item.taxableAmount <= 0.009 ? item.netAmount : 0,
            cgstAmount: _taxAmountFor(item, 'CGST'),
            sgstAmount: _taxAmountFor(item, 'SGST'),
            igstAmount: _taxAmountFor(item, 'IGST'),
            totalInvoiceValue: item.netAmount,
            saleDateTime: sale.saleDate,
          ),
        );
      }
    }
    final query = _itemSearchCtrl.text.trim().toLowerCase();
    return flattened.where((row) {
      if (_selectedGroup != 'ALL' && row.itemGroup != _selectedGroup) {
        return false;
      }
      if (_selectedSubCategory != 'ALL' &&
          row.subCategory != _selectedSubCategory) {
        return false;
      }
      if (query.isEmpty) return true;
      return row.itemDescription.toLowerCase().contains(query) ||
          row.itemGroup.toLowerCase().contains(query) ||
          row.subCategory.toLowerCase().contains(query) ||
          row.hsnSacCode.toLowerCase().contains(query) ||
          row.invoiceNumber.toLowerCase().contains(query);
    }).toList();
  }

  List<String> get _availableGroups {
    final groups = _rows.map((row) => row.itemGroup).toSet().toList()..sort();
    return ['ALL', ...groups];
  }

  List<String> get _availableSubCategories {
    final filtered = _selectedGroup == 'ALL'
        ? _rows
        : _rows.where((row) => row.itemGroup == _selectedGroup).toList();
    final subCategories =
        filtered.map((row) => row.subCategory).toSet().toList()..sort();
    return ['ALL', ...subCategories];
  }

  List<_GroupedSalesRow> get _groupedRows {
    final grouped = <String, _GroupedSalesRow>{};
    for (final row in _rows) {
      final key = switch (_groupBy) {
        'GROUP' => row.itemGroup,
        'SUBCATEGORY' => row.subCategory,
        _ => '${row.itemDescription}|${row.hsnSacCode}|${row.unit}',
      };
      final current = grouped[key];
      if (current == null) {
        grouped[key] = _GroupedSalesRow(
          label: _groupBy == 'GROUP'
              ? row.itemGroup
              : _groupBy == 'SUBCATEGORY'
                  ? row.subCategory
                  : row.itemDescription,
          itemGroup: row.itemGroup,
          subCategory: row.subCategory,
          hsnSacCode: row.hsnSacCode,
          unit: row.unit,
          quantity: row.quantity,
          taxableValue: row.taxableValue,
          taxSaleValue: row.taxableValue > 0.009 ? row.totalInvoiceValue : 0,
          nonTaxSaleValue: row.taxableValue <= 0.009 ? row.totalInvoiceValue : 0,
          cgstAmount: row.cgstAmount,
          sgstAmount: row.sgstAmount,
          igstAmount: row.igstAmount,
          totalInvoiceValue: row.totalInvoiceValue,
          lineCount: 1,
        );
      } else {
        grouped[key] = current.copyWith(
          quantity: current.quantity + row.quantity,
          taxableValue: current.taxableValue + row.taxableValue,
          taxSaleValue: current.taxSaleValue + (row.taxableValue > 0.009 ? row.totalInvoiceValue : 0),
          nonTaxSaleValue:
              current.nonTaxSaleValue + (row.taxableValue <= 0.009 ? row.totalInvoiceValue : 0),
          cgstAmount: current.cgstAmount + row.cgstAmount,
          sgstAmount: current.sgstAmount + row.sgstAmount,
          igstAmount: current.igstAmount + row.igstAmount,
          totalInvoiceValue: current.totalInvoiceValue + row.totalInvoiceValue,
          lineCount: current.lineCount + 1,
        );
      }
    }
    final rows = grouped.values.toList()
      ..sort((a, b) => b.totalInvoiceValue.compareTo(a.totalInvoiceValue));
    return rows;
  }

  List<_GstSalesRow> get _pagedRows {
    final start = _currentPage * _rowsPerPage;
    if (start >= _rows.length) return const [];
    final end = (start + _rowsPerPage) > _rows.length
        ? _rows.length
        : (start + _rowsPerPage);
    return _rows.sublist(start, end);
  }

  int get _totalPages =>
      _rows.isEmpty ? 1 : ((_rows.length - 1) ~/ _rowsPerPage) + 1;

  double get _taxSaleTotal => ctrl.list
      .where((sale) => sale.totalTax > 0.009)
      .fold<double>(0, (sum, sale) => sum + sale.netAmount);

  double get _nonTaxSaleTotal => ctrl.list
      .where((sale) => sale.totalTax <= 0.009)
      .fold<double>(0, (sum, sale) => sum + sale.netAmount);
  double get _headerTaxableTotal =>
      ctrl.list.fold<double>(0, (sum, sale) => sum + sale.taxableAmount);
  double get _headerCgstTotal =>
      ctrl.list.fold<double>(0, (sum, sale) => sum + sale.cgstAmount);
  double get _headerSgstTotal =>
      ctrl.list.fold<double>(0, (sum, sale) => sum + sale.sgstAmount);
  double get _headerRevenueTotal =>
      ctrl.list.fold<double>(0, (sum, sale) => sum + sale.netAmount);

  List<SalesReport> get _billWiseSales {
    final query = _itemSearchCtrl.text.trim().toLowerCase();
    return ctrl.list.where((sale) {
      if (ctrl.paymentMode != null &&
          ctrl.paymentMode!.isNotEmpty &&
          sale.paymentMode.toUpperCase() != ctrl.paymentMode!.toUpperCase()) {
        return false;
      }
      if (query.isEmpty) return true;
      return sale.saleNo.toLowerCase().contains(query) ||
          sale.customerName.toLowerCase().contains(query) ||
          sale.customerPhone.toLowerCase().contains(query) ||
          sale.paymentMode.toLowerCase().contains(query);
    }).toList();
  }

  double get _billWiseNetTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.netAmount);
  double get _billWiseTaxTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.totalTax);
  double get _billWiseDiscountTotal => _billWiseSales.fold<double>(
      0, (sum, sale) => sum + sale.totalDiscount);
  double get _billWiseQtyTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.totalQty);
  double get _billWiseTaxableSaleTotal => _billWiseSales.fold<double>(
      0, (sum, sale) => sum + (sale.taxableAmount > 0.009 ? sale.netAmount : 0));
  double get _billWiseNonTaxableSaleTotal => _billWiseSales.fold<double>(
      0, (sum, sale) => sum + (sale.taxableAmount <= 0.009 ? sale.netAmount : 0));
  int get _paymentWiseCountTotal =>
      ctrl.paymentModes.fold<int>(0, (sum, entry) => sum + entry.count);
  double get _paymentWiseAmountTotal =>
      ctrl.paymentModes.fold<double>(0, (sum, entry) => sum + entry.amount);
  double get _paymentReportTaxSaleTotal => _billWiseSales.fold<double>(
      0, (sum, sale) => sum + (sale.totalTax > 0.009 ? sale.netAmount : 0));
  double get _paymentReportNonTaxSaleTotal => _billWiseSales.fold<double>(
      0, (sum, sale) => sum + (sale.totalTax <= 0.009 ? sale.netAmount : 0));
  double get _itemWiseLineCountTotal =>
      _groupedRows.fold<double>(0, (sum, row) => sum + row.lineCount);
  double get _itemWiseQtyTotal =>
      _groupedRows.fold<double>(0, (sum, row) => sum + row.quantity);
  double get _itemWiseTaxableTotal =>
      _groupedRows.fold<double>(0, (sum, row) => sum + row.taxableValue);
  double get _itemWiseCgstTotal =>
      _groupedRows.fold<double>(0, (sum, row) => sum + row.cgstAmount);
  double get _itemWiseSgstTotal =>
      _groupedRows.fold<double>(0, (sum, row) => sum + row.sgstAmount);
  double get _itemWiseIgstTotal =>
      _groupedRows.fold<double>(0, (sum, row) => sum + row.igstAmount);
  double get _itemWiseSalesTotal =>
      _groupedRows.fold<double>(0, (sum, row) => sum + row.totalInvoiceValue);
  double get _itemWiseTaxableSaleTotal => _groupedRows.fold<double>(
      0, (sum, row) => sum + row.taxSaleValue);
  double get _itemWiseNonTaxableSaleTotal => _groupedRows.fold<double>(
      0, (sum, row) => sum + row.nonTaxSaleValue);

  double _billWiseTaxSaleValue(SalesReport sale) {
    return sale.items.fold<double>(
      0,
      (sum, item) => sum + (item.taxableAmount > 0.009 ? item.netAmount : 0),
    );
  }

  double _billWiseNonTaxSaleValue(SalesReport sale) {
    return sale.items.fold<double>(
      0,
      (sum, item) => sum + (item.taxableAmount <= 0.009 ? item.netAmount : 0),
    );
  }

  double _itemWiseTaxSaleValue(_GroupedSalesRow row) {
    return row.taxSaleValue;
  }

  double _itemWiseNonTaxSaleValue(_GroupedSalesRow row) {
    return row.nonTaxSaleValue;
  }

  _GstSummary get _summary {
    return _rows.fold(
      const _GstSummary(),
      (sum, row) => _GstSummary(
        taxableValue: sum.taxableValue + row.taxableValue,
        cgstAmount: sum.cgstAmount + row.cgstAmount,
        sgstAmount: sum.sgstAmount + row.sgstAmount,
        igstAmount: sum.igstAmount + row.igstAmount,
        totalRevenue: sum.totalRevenue + row.totalInvoiceValue,
      ),
    );
  }

  List<_HeatmapMatrixRow> get _heatmapData {
    final grouped = <String, _HeatmapAccumulator>{};
    for (final row in _rows) {
      final key = '${row.itemDescription}|${row.hsnSacCode}|${row.unit}';
      final bucket = _resolveZoneKey(row.saleDateTime);
      final entry = grouped.putIfAbsent(
        key,
        () => _HeatmapAccumulator(
          label: row.itemDescription,
          subLabel: row.hsnSacCode.trim().isEmpty ? row.unit : row.hsnSacCode,
        ),
      );
      entry.values[bucket] =
          (entry.values[bucket] ?? 0) + row.totalInvoiceValue;
      entry.total += row.totalInvoiceValue;
    }

    final rows = grouped.values
        .map(
          (entry) => _HeatmapMatrixRow(
            label: entry.label,
            subLabel: entry.subLabel,
            values: entry.values,
            total: entry.total,
          ),
        )
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return rows.take(20).toList();
  }

  double get _heatmapMaxValue {
    var maxValue = 0.0;
    for (final row in _heatmapData) {
      for (final zone in _heatmapZones) {
        final value = row.values[zone.key] ?? 0;
        if (value > maxValue) maxValue = value;
      }
    }
    return maxValue <= 0 ? 1 : maxValue;
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: ctrl.fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      ctrl.fromDate = picked;
      _syncDates();
    });
    await ctrl.load();
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: ctrl.toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      ctrl.toDate = picked;
      _syncDates();
    });
    await ctrl.load();
  }

  Future<void> _exportExcel() async {
    final workbook = exc.Excel.createExcel();
    final sheetName = switch (_reportTabIndex) {
      0 => 'Payment_Wise_Sales',
      1 => 'Bill_Wise_Sales',
      _ => 'Item_Wise_Sales',
    };
    final defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null) {
      workbook.rename(defaultSheet, sheetName);
    }
    final sheet = workbook[sheetName];

    if (_reportTabIndex == 0) {
      sheet.appendRow(
        ['Payment Mode', 'Sales Count', 'Amount']
            .map(exc.TextCellValue.new)
            .toList(),
      );
      for (final entry in ctrl.paymentModes) {
        sheet.appendRow([
          exc.TextCellValue(entry.label),
          exc.IntCellValue(entry.count),
          exc.DoubleCellValue(entry.amount),
        ]);
      }
      sheet.appendRow([
        exc.TextCellValue('TOTAL'),
        exc.IntCellValue(_paymentWiseCountTotal),
        exc.DoubleCellValue(_paymentWiseAmountTotal),
      ]);
    } else if (_reportTabIndex == 1) {
      sheet.appendRow(
        [
          'Date',
          'Bill No',
          'Customer',
          'Payment',
          'Qty',
          'Tax Sale',
          'Non Tax Sale',
          'Discount',
          'Tax',
          'Net Amount',
        ].map(exc.TextCellValue.new).toList(),
      );
      for (final sale in _billWiseSales) {
        sheet.appendRow([
          exc.TextCellValue(DateFormat('dd-MM-yyyy').format(sale.saleDate)),
          exc.TextCellValue(sale.saleNo),
          exc.TextCellValue(
            sale.customerName.trim().isEmpty
                ? 'Walk-in Customer'
                : sale.customerName,
          ),
          exc.TextCellValue(sale.paymentMode),
          exc.DoubleCellValue(sale.totalQty),
          exc.DoubleCellValue(_billWiseTaxSaleValue(sale)),
          exc.DoubleCellValue(_billWiseNonTaxSaleValue(sale)),
          exc.DoubleCellValue(sale.totalDiscount),
          exc.DoubleCellValue(sale.totalTax),
          exc.DoubleCellValue(sale.netAmount),
        ]);
      }
      sheet.appendRow([
        exc.TextCellValue('TOTAL'),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.DoubleCellValue(_billWiseQtyTotal),
        exc.DoubleCellValue(_billWiseTaxableSaleTotal),
        exc.DoubleCellValue(_billWiseNonTaxableSaleTotal),
        exc.DoubleCellValue(_billWiseDiscountTotal),
        exc.DoubleCellValue(_billWiseTaxTotal),
        exc.DoubleCellValue(_billWiseNetTotal),
      ]);
      sheet.appendRow([
        exc.TextCellValue('TAXABLE SALE TOTAL'),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.DoubleCellValue(_billWiseTaxableSaleTotal),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
      ]);
      sheet.appendRow([
        exc.TextCellValue('NON-TAXABLE SALE TOTAL'),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.DoubleCellValue(_billWiseNonTaxableSaleTotal),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
      ]);
    } else {
      sheet.appendRow(
        [
          'Label',
          'Group',
          'Subcategory',
          'HSN/SAC',
          'Rows',
          'Qty',
          'Unit',
          'Tax Sale',
          'Non Tax Sale',
          'Taxable Value',
          'CGST',
          'SGST',
          'IGST',
          'Total Sales',
        ].map(exc.TextCellValue.new).toList(),
      );
      for (final row in _groupedRows) {
        sheet.appendRow([
          exc.TextCellValue(row.label),
          exc.TextCellValue(row.itemGroup),
          exc.TextCellValue(row.subCategory),
          exc.TextCellValue(row.hsnSacCode),
          exc.IntCellValue(row.lineCount),
          exc.DoubleCellValue(row.quantity),
          exc.TextCellValue(row.unit),
          exc.DoubleCellValue(_itemWiseTaxSaleValue(row)),
          exc.DoubleCellValue(_itemWiseNonTaxSaleValue(row)),
          exc.DoubleCellValue(row.taxableValue),
          exc.DoubleCellValue(row.cgstAmount),
          exc.DoubleCellValue(row.sgstAmount),
          exc.DoubleCellValue(row.igstAmount),
          exc.DoubleCellValue(row.totalInvoiceValue),
        ]);
      }
      sheet.appendRow([
        exc.TextCellValue('TOTAL'),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.DoubleCellValue(_itemWiseLineCountTotal),
        exc.DoubleCellValue(_itemWiseQtyTotal),
        exc.TextCellValue(''),
        exc.DoubleCellValue(_itemWiseTaxableSaleTotal),
        exc.DoubleCellValue(_itemWiseNonTaxableSaleTotal),
        exc.DoubleCellValue(_itemWiseTaxableTotal),
        exc.DoubleCellValue(_itemWiseCgstTotal),
        exc.DoubleCellValue(_itemWiseSgstTotal),
        exc.DoubleCellValue(_itemWiseIgstTotal),
        exc.DoubleCellValue(_itemWiseSalesTotal),
      ]);
      sheet.appendRow([
        exc.TextCellValue('TAXABLE SALE TOTAL'),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.DoubleCellValue(_itemWiseTaxableSaleTotal),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
      ]);
      sheet.appendRow([
        exc.TextCellValue('NON-TAXABLE SALE TOTAL'),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.DoubleCellValue(_itemWiseNonTaxableSaleTotal),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
      ]);
    }

    final bytes = workbook.encode();
    if (bytes == null) return;

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}sales_report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    await file.writeAsBytes(bytes, flush: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Excel exported: ${file.path}')),
    );
    await OpenFile.open(file.path);
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final summary = _summary;
    final title = switch (_reportTabIndex) {
      0 => 'Payment Wise Sales Report',
      1 => 'Bill Wise Sales Report',
      _ => 'Item Wise Sales Report',
    };
    final headers = switch (_reportTabIndex) {
      0 => ['Payment Mode', 'Sales Count', 'Amount'],
      1 => ['Date', 'Bill No', 'Customer', 'Payment', 'Qty', 'Tax Sale', 'Non Tax Sale', 'Discount', 'Tax', 'Net Amount'],
      _ => ['Label', 'Group', 'Subcategory', 'HSN/SAC', 'Rows', 'Qty', 'Unit', 'Tax Sale', 'Non Tax Sale', 'Taxable', 'CGST', 'SGST', 'IGST', 'Sales'],
    };
    final data = switch (_reportTabIndex) {
      0 => ctrl.paymentModes
          .map((entry) => [entry.label, '${entry.count}', _money(entry.amount)])
          .toList()
        ..add([
          'TOTAL',
          '$_paymentWiseCountTotal',
          _money(_paymentWiseAmountTotal),
        ]),
      1 => _billWiseSales
          .map(
            (sale) => [
              DateFormat('dd-MM-yyyy').format(sale.saleDate),
              sale.saleNo,
              sale.customerName.trim().isEmpty
                  ? 'Walk-in Customer'
                  : sale.customerName,
              sale.paymentMode,
              _formatQty(sale.totalQty),
              _money(_billWiseTaxSaleValue(sale)),
              _money(_billWiseNonTaxSaleValue(sale)),
              _money(sale.totalDiscount),
              _money(sale.totalTax),
              _money(sale.netAmount),
            ],
          )
          .toList()
        ..add([
          'TOTAL',
          '',
          '',
          '',
          _formatQty(_billWiseQtyTotal),
          _money(_billWiseTaxableSaleTotal),
          _money(_billWiseNonTaxableSaleTotal),
          _money(_billWiseDiscountTotal),
          _money(_billWiseTaxTotal),
          _money(_billWiseNetTotal),
        ])
        ..add([
          'TAXABLE SALE TOTAL',
          '',
          '',
          '',
          '',
          _money(_billWiseTaxableSaleTotal),
          '',
          '',
          '',
          '',
        ])
        ..add([
          'NON-TAXABLE SALE TOTAL',
          '',
          '',
          '',
          '',
          '',
          _money(_billWiseNonTaxableSaleTotal),
          '',
          '',
          '',
        ]),
      _ => _groupedRows
          .map(
            (row) => [
              row.label,
              row.itemGroup,
              row.subCategory,
              row.hsnSacCode,
              '${row.lineCount}',
              _formatQty(row.quantity),
              row.unit,
              _money(_itemWiseTaxSaleValue(row)),
              _money(_itemWiseNonTaxSaleValue(row)),
              _money(row.taxableValue),
              _money(row.cgstAmount),
              _money(row.sgstAmount),
              _money(row.igstAmount),
              _money(row.totalInvoiceValue),
            ],
          )
          .toList()
        ..add([
          'TOTAL',
          '',
          '',
          '',
          _formatQty(_itemWiseLineCountTotal),
          _formatQty(_itemWiseQtyTotal),
          '',
          _money(_itemWiseTaxableSaleTotal),
          _money(_itemWiseNonTaxableSaleTotal),
          _money(_itemWiseTaxableTotal),
          _money(_itemWiseCgstTotal),
          _money(_itemWiseSgstTotal),
          _money(_itemWiseIgstTotal),
          _money(_itemWiseSalesTotal),
        ])
        ..add([
          'TAXABLE SALE TOTAL',
          '',
          '',
          '',
          '',
          '',
          '',
          _money(_itemWiseTaxableSaleTotal),
          '',
          '',
          '',
          '',
          '',
          '',
        ])
        ..add([
          'NON-TAXABLE SALE TOTAL',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          _money(_itemWiseNonTaxableSaleTotal),
          '',
          '',
          '',
          '',
          '',
        ]),
    };

    final rowsPerPage = _reportTabIndex == 1 ? 24 : 22;
    final chunks = <List<List<String>>>[];
    for (int i = 0; i < data.length; i += rowsPerPage) {
      chunks.add(
        data.sublist(
          i,
          i + rowsPerPage > data.length ? data.length : i + rowsPerPage,
        ),
      );
    }
    if (chunks.isEmpty) {
      chunks.add(<List<String>>[]);
    }

    for (int pageIndex = 0; pageIndex < chunks.length; pageIndex++) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(14),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                title,
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Period: ${DateFormat('dd-MM-yyyy').format(ctrl.fromDate)} to ${DateFormat('dd-MM-yyyy').format(ctrl.toDate)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Page ${pageIndex + 1} of ${chunks.length}',
                style: const pw.TextStyle(fontSize: 9),
                textAlign: pw.TextAlign.right,
              ),
              if (pageIndex == 0) ...[
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey600),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _pdfSummaryBlock('Total Taxable', summary.taxableValue),
                      _pdfSummaryBlock('Total CGST', summary.cgstAmount),
                      _pdfSummaryBlock('Total SGST', summary.sgstAmount),
                      _pdfSummaryBlock('Grand Revenue', summary.totalRevenue),
                    ],
                  ),
                ),
              ],
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: chunks[pageIndex],
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.blueGrey100),
                headerStyle:
                    pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 6.6),
                border:
                    pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
                cellPadding:
                    const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              ),
            ],
          ),
        ),
      );
    }

    final bytes = await pdf.save();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Retail Sales Report'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: FilledButton.icon(
              onPressed: _exportExcel,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export Excel'),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.only(left: 6, right: 16, top: 8, bottom: 8),
            child: FilledButton.icon(
              onPressed: _exportPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Export PDF'),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          if (ctrl.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildTopFilters(),
              const SizedBox(height: 16),
              _buildSummaryRow(),
              const SizedBox(height: 16),
              _buildReportTabs(),
              const SizedBox(height: 16),
              _buildCurrentReportSection(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReportTabs() {
    final tabs = const [
      'Payment Wise',
      'Bill Wise',
      'Item Wise',
    ];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final selected = _reportTabIndex == index;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      selected ? const Color(0xFF17324D) : const Color(0xFFF8FAFC),
                  foregroundColor:
                      selected ? Colors.white : const Color(0xFF17324D),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () => setState(() => _reportTabIndex = index),
                child: Text(
                  tabs[index],
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentReportSection() {
    if (_reportTabIndex == 0) {
      return _buildPaymentBreakdownSection();
    }
    if (_reportTabIndex == 1) {
      return SizedBox(height: 560, child: _buildBillWiseDataTableSection());
    }
    return SizedBox(height: 560, child: _buildItemWiseDataTableSection());
  }

  Widget _buildTopFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _dateField('From', _fromCtrl, _pickFromDate),
          _dateField('To', _toCtrl, _pickToDate),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              initialValue: _gstFilter,
              decoration: const InputDecoration(labelText: 'Sales Type'),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Sales')),
                DropdownMenuItem(value: 'B2B_ONLY', child: Text('B2B Only')),
                DropdownMenuItem(value: 'B2C_ONLY', child: Text('B2C Only')),
              ],
              onChanged: (value) {
                setState(() => _gstFilter = value ?? 'ALL');
              },
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              initialValue: _groupBy,
              decoration: const InputDecoration(labelText: 'Group By'),
              items: const [
                DropdownMenuItem(value: 'ITEM', child: Text('Item Wise')),
                DropdownMenuItem(value: 'GROUP', child: Text('Group Wise')),
                DropdownMenuItem(
                  value: 'SUBCATEGORY',
                  child: Text('Subcategory Wise'),
                ),
              ],
              onChanged: (value) {
                setState(() => _groupBy = value ?? 'ITEM');
              },
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedGroup,
              decoration: const InputDecoration(labelText: 'Filter Group'),
              items: _availableGroups
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value == 'ALL' ? 'All Groups' : value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedGroup = value ?? 'ALL';
                  if (!_availableSubCategories.contains(_selectedSubCategory)) {
                    _selectedSubCategory = 'ALL';
                  }
                });
              },
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              initialValue:
                  ctrl.paymentMode?.isNotEmpty == true ? ctrl.paymentMode : 'ALL',
              decoration:
                  const InputDecoration(labelText: 'Payment Method Filter'),
              items: [
                const DropdownMenuItem(value: 'ALL', child: Text('All Modes')),
                ...ctrl.paymentModes.map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.label),
                  ),
                ),
              ],
              onChanged: (value) async {
                ctrl.paymentMode = value == null || value == 'ALL' ? null : value;
                await ctrl.load();
                setState(() {});
              },
            ),
          ),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedSubCategory,
              decoration:
                  const InputDecoration(labelText: 'Filter Subcategory'),
              items: _availableSubCategories
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(
                        value == 'ALL' ? 'All Subcategories' : value,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedSubCategory = value ?? 'ALL');
              },
            ),
          ),
          SizedBox(
            width: 260,
            child: TextField(
              controller: _itemSearchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Search Item',
                hintText: 'Item, HSN, group, subcategory',
                suffixIcon: Icon(Icons.search),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, TextEditingController controller,
      Future<void> Function() onTap) {
    return SizedBox(
      width: 180,
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_month_outlined),
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Row(
      children: [
        Expanded(
            child: _metricCard('Total Taxable Value', _headerTaxableTotal,
                const Color(0xFF0F766E))),
        const SizedBox(width: 12),
        Expanded(
            child: _metricCard(
                'Total CGST', _headerCgstTotal, const Color(0xFF2563EB))),
        const SizedBox(width: 12),
        Expanded(
            child: _metricCard(
                'Total SGST', _headerSgstTotal, const Color(0xFF7C3AED))),
        const SizedBox(width: 12),
        Expanded(
            child: _metricCard('Grand Total Revenue', _headerRevenueTotal,
                const Color(0xFFEA580C))),
        const SizedBox(width: 12),
        Expanded(
            child: _metricCard(
                'Tax Sale', _taxSaleTotal, const Color(0xFF16A34A))),
        const SizedBox(width: 12),
        Expanded(
            child: _metricCard(
                'Non Tax Sale', _nonTaxSaleTotal, const Color(0xFF64748B))),
      ],
    );
  }

  Widget _metricCard(String label, double value, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _money(value),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCharts() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildSalesOverviewChart()),
            const SizedBox(width: 16),
            Expanded(child: _buildComparisonChart('Month On Month', ctrl.monthOnMonth)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildComparisonChart('Week On Week', ctrl.weekOnWeek)),
            const SizedBox(width: 16),
            Expanded(child: _buildComparisonChart('Day On Day', ctrl.dayOnDay)),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentBreakdownSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Breakdown Report',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ctrl.paymentModes
                .map(
                  (entry) => SizedBox(
                    width: 190,
                    child: _metricCard(
                      entry.label,
                      entry.amount,
                      _paymentColor(entry.key),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                const Color(0xFFF1F5F9),
              ),
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Bill No')),
                DataColumn(label: Text('Customer')),
                DataColumn(label: Text('Payment')),
                DataColumn(label: Text('Tax Sale')),
                DataColumn(label: Text('Non Tax Sale')),
                DataColumn(label: Text('Tax')),
                DataColumn(label: Text('Net Amount')),
              ],
              rows: _billWiseSales
                  .map(
                    (sale) => DataRow(
                      color: WidgetStateProperty.all(
                        _paymentColor(sale.paymentMode).withOpacity(0.10),
                      ),
                      cells: [
                        DataCell(
                          Text(DateFormat('dd-MM-yyyy').format(sale.saleDate)),
                        ),
                        DataCell(Text(sale.saleNo)),
                        DataCell(
                          Text(
                            sale.customerName.trim().isEmpty
                                ? 'Walk-in Customer'
                                : sale.customerName,
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _paymentColor(sale.paymentMode).withOpacity(0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              sale.paymentMode,
                              style: TextStyle(
                                color: _paymentColor(sale.paymentMode),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(_money(sale.totalTax > 0.009 ? sale.netAmount : 0)),
                        ),
                        DataCell(
                          Text(_money(sale.totalTax <= 0.009 ? sale.netAmount : 0)),
                        ),
                        DataCell(Text(_money(sale.totalTax))),
                        DataCell(
                          Text(
                            _money(sale.netAmount),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList()
                ..add(
                  DataRow(
                    color: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    cells: [
                      const DataCell(
                        Text(
                          'TOTAL',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                      DataCell(
                        Text(
                          _money(_paymentReportTaxSaleTotal),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      DataCell(
                        Text(
                          _money(_paymentReportNonTaxSaleTotal),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      DataCell(
                        Text(
                          _money(_billWiseTaxTotal),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      DataCell(
                        Text(
                          _money(_billWiseNetTotal),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesOverviewChart() {
    final summary = ctrl.summary;
    final points = <_ChartBarPoint>[
      _ChartBarPoint('Sales', summary.totalRevenue, const Color(0xFF2563EB)),
      _ChartBarPoint('Discount', summary.totalDiscount, const Color(0xFFF59E0B)),
      _ChartBarPoint('Profit', summary.estimatedProfit, const Color(0xFF16A34A)),
      _ChartBarPoint('Loss', summary.estimatedLoss, const Color(0xFFDC2626)),
    ];

    return _chartCard(
      title: 'Sales / Discount / Profit / Loss',
      child: SfCartesianChart(
        primaryXAxis: CategoryAxis(),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries<_ChartBarPoint, String>>[
          ColumnSeries<_ChartBarPoint, String>(
            dataSource: points,
            xValueMapper: (point, _) => point.label,
            yValueMapper: (point, _) => point.value,
            pointColorMapper: (point, _) => point.color,
            dataLabelSettings: const DataLabelSettings(isVisible: true),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonChart(
    String title,
    List<SalesComparisonPoint> points,
  ) {
    return _chartCard(
      title: title,
      child: points.isEmpty
          ? const Center(child: Text('No comparison data available.'))
          : SfCartesianChart(
              legend: const Legend(isVisible: true),
              tooltipBehavior: TooltipBehavior(enable: true),
              primaryXAxis: CategoryAxis(),
              series: <CartesianSeries<SalesComparisonPoint, String>>[
                LineSeries<SalesComparisonPoint, String>(
                  name: 'Sales',
                  dataSource: points,
                  xValueMapper: (point, _) => point.period,
                  yValueMapper: (point, _) => point.sales,
                ),
                LineSeries<SalesComparisonPoint, String>(
                  name: 'Profit',
                  dataSource: points,
                  xValueMapper: (point, _) => point.period,
                  yValueMapper: (point, _) => point.profit,
                ),
                LineSeries<SalesComparisonPoint, String>(
                  name: 'Loss',
                  dataSource: points,
                  xValueMapper: (point, _) => point.period,
                  yValueMapper: (point, _) => point.loss,
                ),
              ],
            ),
    );
  }

  Widget _chartCard({required String title, required Widget child}) {
    return Container(
      height: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildHeatmapSection() {
    final rows = _heatmapData;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220, maxHeight: 320),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: rows.isEmpty
          ? const Center(
              child: Text(
                  'No sales available for analytics in the selected range.'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Peak Hours Heatmap',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Rows show top selling items. Cells show total sales amount by time zone.',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 760),
                      child: SingleChildScrollView(
                        child: Table(
                          columnWidths: const {
                            0: FixedColumnWidth(260),
                          },
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              children: [
                                _heatHeaderCell('Top Items / Categories'),
                                ..._heatmapZones
                                    .map((zone) => _heatHeaderCell(zone.label)),
                              ],
                            ),
                            ...rows.map(
                              (row) => TableRow(
                                children: [
                                  _itemLabelCell(row),
                                  ..._heatmapZones.map(
                                    (zone) => _heatValueCell(
                                        row.values[zone.key] ?? 0),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _heatHeaderCell(String text) {
    return Container(
      height: 54,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _itemLabelCell(_HeatmapMatrixRow row) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (row.subLabel.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                row.subLabel,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _heatValueCell(double value) {
    final normalized = (value / _heatmapMaxValue).clamp(0.0, 1.0);
    const low = Color(0xFFDFF7E2);
    const high = Color(0xFF15803D);
    final background = Color.lerp(low, high, normalized) ?? low;
    final foreground =
        normalized > 0.55 ? Colors.white : const Color(0xFF14532D);

    return Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        _money(value),
        style: TextStyle(fontWeight: FontWeight.w800, color: foreground),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBillWiseDataTableSection() {
    final rows = _billWiseSales;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bill Wise Sales Report',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Bills: ${rows.length} | Sales: ${_money(_billWiseNetTotal)}',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text('No bill rows found for the selected range.'),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFFF8FAFC),
                        ),
                        dataRowMinHeight: 52,
                        dataRowMaxHeight: 68,
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Bill No')),
                          DataColumn(label: Text('Customer')),
                          DataColumn(label: Text('Payment')),
                          DataColumn(label: Text('Qty')),
                          DataColumn(label: Text('Tax Sale')),
                          DataColumn(label: Text('Non Tax Sale')),
                          DataColumn(label: Text('Discount')),
                          DataColumn(label: Text('Tax')),
                          DataColumn(label: Text('Net Amount')),
                        ],
                        rows: [
                          ...rows.map(
                            (sale) => DataRow(
                              color: WidgetStateProperty.all(
                                _paymentColor(sale.paymentMode)
                                    .withOpacity(0.08),
                              ),
                              cells: [
                                DataCell(
                                  Text(
                                    DateFormat('dd-MM-yyyy')
                                        .format(sale.saleDate),
                                  ),
                                ),
                                DataCell(Text(sale.saleNo)),
                                DataCell(
                                  SizedBox(
                                    width: 190,
                                    child: Text(
                                      sale.customerName.trim().isEmpty
                                          ? 'Walk-in Customer'
                                          : sale.customerName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(Text(sale.paymentMode)),
                                DataCell(Text(_formatQty(sale.totalQty))),
                                DataCell(
                                  Text(_money(_billWiseTaxSaleValue(sale))),
                                ),
                                DataCell(
                                  Text(_money(_billWiseNonTaxSaleValue(sale))),
                                ),
                                DataCell(Text(_money(sale.totalDiscount))),
                                DataCell(Text(_money(sale.totalTax))),
                                DataCell(
                                  Text(
                                    _money(sale.netAmount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataRow(
                            color: WidgetStateProperty.all(
                              const Color(0xFFF8FAFC),
                            ),
                            cells: [
                              const DataCell(
                                Text(
                                  'TOTAL',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              const DataCell(Text('')),
                              const DataCell(Text('')),
                              const DataCell(Text('')),
                              DataCell(
                                Text(
                                  _formatQty(_billWiseQtyTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _money(_billWiseTaxableSaleTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _money(_billWiseNonTaxableSaleTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _money(_billWiseDiscountTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _money(_billWiseTaxTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _money(_billWiseNetTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          DataRow(
                            color: WidgetStateProperty.all(
                              const Color(0xFFF1F5F9),
                            ),
                            cells: [
                              const DataCell(
                                Text(
                                  'TAXABLE SALE TOTAL',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              const DataCell(Text('')),
                              const DataCell(Text('')),
                              const DataCell(Text('')),
                              const DataCell(Text('')),
                              DataCell(
                                Text(
                                  _money(_billWiseTaxableSaleTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const DataCell(Text('')),
                              const DataCell(Text('')),
                              const DataCell(Text('')),
                              const DataCell(Text('')),
                            ],
                          ),
                          DataRow(
                            color: WidgetStateProperty.all(
                              const Color(0xFFF8FAFC),
                            ),
                            cells: [
                              const DataCell(
                                Text(
                                  'NON-TAXABLE SALE TOTAL',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              const DataCell(Text('')),
                              const DataCell(Text('')),
                              const DataCell(Text('')),
                              const DataCell(Text('')),
                              const DataCell(Text('')),
                              DataCell(
                                Text(
                                  _money(_billWiseNonTaxableSaleTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const DataCell(Text('')),
                              const DataCell(Text('')),
                              const DataCell(Text('')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
        ],
      ),
    );
  }

  Widget _buildItemWiseDataTableSection() {
    final groupedRows = _groupedRows;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Item Wise Sales Report',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Rows: ${groupedRows.length} | Group By: ${_groupBy == 'ITEM' ? 'Item Wise' : _groupBy == 'GROUP' ? 'Group Wise' : 'Subcategory Wise'} | Sales: ${_gstFilter == 'ALL' ? 'All Sales' : _gstFilter == 'B2B_ONLY' ? 'B2B Only' : 'B2C Only'}',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: groupedRows.isEmpty
                ? const Center(
                    child: Text('No item sales rows found for the selected range.'),
                  )
                : Scrollbar(
                    controller: _gstVerticalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _gstVerticalController,
                      primary: false,
                      scrollDirection: Axis.vertical,
                      child: Scrollbar(
                        controller: _gstHorizontalController,
                        thumbVisibility: true,
                        notificationPredicate: (notification) =>
                            notification.metrics.axis == Axis.horizontal,
                        child: SingleChildScrollView(
                          controller: _gstHorizontalController,
                          primary: false,
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 1280),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                const Color(0xFFF8FAFC),
                              ),
                              dataRowMinHeight: 52,
                              dataRowMaxHeight: 68,
                              columns: const [
                                DataColumn(label: Text('Label')),
                                DataColumn(label: Text('Group')),
                                DataColumn(label: Text('Subcategory')),
                                DataColumn(label: Text('HSN/SAC')),
                                DataColumn(label: Text('Rows')),
                                DataColumn(label: Text('Qty')),
                                DataColumn(label: Text('Unit')),
                                DataColumn(label: Text('Tax Sale')),
                                DataColumn(label: Text('Non Tax Sale')),
                                DataColumn(label: Text('Taxable Value')),
                                DataColumn(label: Text('CGST')),
                                DataColumn(label: Text('SGST')),
                                DataColumn(label: Text('IGST')),
                                DataColumn(label: Text('Total Sales')),
                              ],
                              rows: [
                                ...groupedRows.map(
                                  (row) => DataRow(
                                    cells: [
                                      DataCell(
                                        SizedBox(
                                          width: 220,
                                          child: Text(
                                            row.label,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 140,
                                          child: Text(
                                            row.itemGroup,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 170,
                                          child: Text(
                                            row.subCategory,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(row.hsnSacCode)),
                                      DataCell(Text('${row.lineCount}')),
                                      DataCell(Text(_formatQty(row.quantity))),
                                      DataCell(Text(row.unit)),
                                      DataCell(
                                        Text(_money(_itemWiseTaxSaleValue(row))),
                                      ),
                                      DataCell(
                                        Text(_money(_itemWiseNonTaxSaleValue(row))),
                                      ),
                                      DataCell(Text(_money(row.taxableValue))),
                                      DataCell(Text(_money(row.cgstAmount))),
                                      DataCell(Text(_money(row.sgstAmount))),
                                      DataCell(Text(_money(row.igstAmount))),
                                      DataCell(
                                        Text(_money(row.totalInvoiceValue)),
                                      ),
                                    ],
                                  ),
                                ),
                                DataRow(
                                  color: WidgetStateProperty.all(
                                    const Color(0xFFF8FAFC),
                                  ),
                                  cells: [
                                    const DataCell(
                                      Text(
                                        'TOTAL',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    DataCell(
                                      Text(
                                        _formatQty(_itemWiseLineCountTotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _formatQty(_itemWiseQtyTotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const DataCell(Text('')),
                                    DataCell(
                                      Text(
                                        _money(_itemWiseTaxableSaleTotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _money(_itemWiseNonTaxableSaleTotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _money(_itemWiseTaxableTotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _money(_itemWiseCgstTotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _money(_itemWiseSgstTotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _money(_itemWiseIgstTotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _money(_itemWiseSalesTotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                DataRow(
                                  color: WidgetStateProperty.all(
                                    const Color(0xFFF1F5F9),
                                  ),
                                  cells: [
                                    const DataCell(
                                      Text(
                                        'TAXABLE SALE TOTAL',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    DataCell(
                                      Text(
                                        _money(_itemWiseTaxableSaleTotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                  ],
                                ),
                                DataRow(
                                  color: WidgetStateProperty.all(
                                    const Color(0xFFF8FAFC),
                                  ),
                                  cells: [
                                    const DataCell(
                                      Text(
                                        'NON-TAXABLE SALE TOTAL',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    DataCell(
                                      Text(
                                        _money(_itemWiseNonTaxableSaleTotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTableSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GST Sales Register',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Rows: ${_rows.length} � Filter: ${_gstFilter == 'ALL' ? 'All Sales' : _gstFilter == 'B2B_ONLY' ? 'B2B Only' : 'B2C Only'}',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _rows.isEmpty
                ? const Center(
                    child:
                        Text('No GST sales rows found for the selected range.'))
                : Scrollbar(
                    controller: _gstVerticalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _gstVerticalController,
                      primary: false,
                      scrollDirection: Axis.vertical,
                      child: Scrollbar(
                        controller: _gstHorizontalController,
                        thumbVisibility: true,
                        notificationPredicate: (notification) =>
                            notification.metrics.axis == Axis.horizontal,
                        child: SingleChildScrollView(
                          controller: _gstHorizontalController,
                          primary: false,
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 1500),
                            child: SingleChildScrollView(
                              primary: false,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                    const Color(0xFFF8FAFC)),
                                dataRowMinHeight: 52,
                                dataRowMaxHeight: 68,
                                columns: _gstHeaders
                                    .map((header) =>
                                        DataColumn(label: Text(header)))
                                    .toList(),
                                rows: _rows
                                    .map(
                                      (row) => DataRow(
                                        cells: [
                                          DataCell(Text(DateFormat('dd-MM-yyyy')
                                              .format(row.invoiceDate))),
                                          DataCell(Text(row.invoiceNumber)),
                                          DataCell(SizedBox(
                                              width: 150,
                                              child: Text(row.customerName,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis))),
                                          DataCell(Text(
                                              row.customerGstin.isEmpty
                                                  ? 'B2C'
                                                  : row.customerGstin)),
                                          DataCell(SizedBox(
                                              width: 160,
                                              child: Text(row.placeOfSupply,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis))),
                                          DataCell(SizedBox(
                                              width: 170,
                                              child: Text(row.itemDescription,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis))),
                                          DataCell(Text(row.hsnSacCode)),
                                          DataCell(Text(
                                              '${_formatQty(row.quantity)} ${row.unit}')),
                                          DataCell(
                                              Text(_money(row.taxableValue))),
                                          DataCell(
                                              Text(_money(row.cgstAmount))),
                                          DataCell(
                                              Text(_money(row.sgstAmount))),
                                          DataCell(
                                              Text(_money(row.igstAmount))),
                                          DataCell(Text(
                                              _money(row.totalInvoiceValue))),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          )
        ],
      ),
    );
  }

  pw.Widget _pdfSummaryBlock(String label, double value) {
    return pw.Column(
      children: [
        pw.Text(label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        pw.SizedBox(height: 4),
        pw.Text(_money(value), style: const pw.TextStyle(fontSize: 11)),
      ],
    );
  }

  double _taxAmountFor(SalesReportItem item, String code) {
    return item.taxBreakup
        .where((tax) => tax.code.toUpperCase() == code)
        .fold<double>(0, (sum, tax) => sum + tax.taxAmount);
  }

  String _derivePlaceOfSupply(SalesReport sale) {
    final gst = sale.customerGstin.trim();
    if (gst.length >= 2) {
      final code = gst.substring(0, 2);
      final state = _stateNameByCode[code];
      if (state != null) return '$state / $code';
    }

    final address = sale.customerAddress.trim().toLowerCase();
    for (final entry in _stateCodes.entries) {
      if (address.contains(entry.key)) {
        return '${_titleCase(entry.key)} / ${entry.value}';
      }
    }

    return 'Unknown / --';
  }

  String _resolveZoneKey(DateTime dateTime) {
    final hour = dateTime.hour;
    for (final zone in _heatmapZones) {
      if (hour >= zone.startHour && hour < zone.endHourExclusive) {
        return zone.key;
      }
    }
    return 'NIGHT';
  }

  String _formatQty(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  String _money(double value) => value.toStringAsFixed(2);

  Color _paymentColor(String paymentMode) {
    switch (paymentMode.toUpperCase()) {
      case 'CASH':
        return const Color(0xFF15803D);
      case 'CARD':
        return const Color(0xFF2563EB);
      case 'UPI':
        return const Color(0xFF7C3AED);
      case 'BANK':
        return const Color(0xFF0F766E);
      case 'CREDIT':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF475569);
    }
  }

  String _titleCase(String value) {
    return value
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _GstSalesRow {
  final DateTime invoiceDate;
  final String invoiceNumber;
  final String customerName;
  final String customerGstin;
  final String placeOfSupply;
  final String itemDescription;
  final String itemGroup;
  final String subCategory;
  final String hsnSacCode;
  final double quantity;
  final String unit;
  final double taxableValue;
  final double taxSaleValue;
  final double nonTaxSaleValue;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalInvoiceValue;
  final DateTime saleDateTime;

  const _GstSalesRow({
    required this.invoiceDate,
    required this.invoiceNumber,
    required this.customerName,
    required this.customerGstin,
    required this.placeOfSupply,
    required this.itemDescription,
    required this.itemGroup,
    required this.subCategory,
    required this.hsnSacCode,
    required this.quantity,
    required this.unit,
    required this.taxableValue,
    required this.taxSaleValue,
    required this.nonTaxSaleValue,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.totalInvoiceValue,
    required this.saleDateTime,
  });
}

class _GroupedSalesRow {
  final String label;
  final String itemGroup;
  final String subCategory;
  final String hsnSacCode;
  final int lineCount;
  final double quantity;
  final String unit;
  final double taxableValue;
  final double taxSaleValue;
  final double nonTaxSaleValue;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalInvoiceValue;

  const _GroupedSalesRow({
    required this.label,
    required this.itemGroup,
    required this.subCategory,
    required this.hsnSacCode,
    required this.lineCount,
    required this.quantity,
    required this.unit,
    required this.taxableValue,
    required this.taxSaleValue,
    required this.nonTaxSaleValue,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.totalInvoiceValue,
  });

  _GroupedSalesRow copyWith({
    int? lineCount,
    double? quantity,
    double? taxableValue,
    double? taxSaleValue,
    double? nonTaxSaleValue,
    double? cgstAmount,
    double? sgstAmount,
    double? igstAmount,
    double? totalInvoiceValue,
  }) {
    return _GroupedSalesRow(
      label: label,
      itemGroup: itemGroup,
      subCategory: subCategory,
      hsnSacCode: hsnSacCode,
      lineCount: lineCount ?? this.lineCount,
      quantity: quantity ?? this.quantity,
      unit: unit,
      taxableValue: taxableValue ?? this.taxableValue,
      taxSaleValue: taxSaleValue ?? this.taxSaleValue,
      nonTaxSaleValue: nonTaxSaleValue ?? this.nonTaxSaleValue,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      igstAmount: igstAmount ?? this.igstAmount,
      totalInvoiceValue: totalInvoiceValue ?? this.totalInvoiceValue,
    );
  }
}

class _GstSummary {
  final double taxableValue;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalRevenue;

  const _GstSummary({
    this.taxableValue = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.totalRevenue = 0,
  });
}

class _HeatmapZone {
  final String key;
  final String label;
  final int startHour;
  final int endHourExclusive;

  const _HeatmapZone({
    required this.key,
    required this.label,
    required this.startHour,
    required this.endHourExclusive,
  });
}

class _ChartBarPoint {
  final String label;
  final double value;
  final Color color;

  const _ChartBarPoint(this.label, this.value, this.color);
}

class _HeatmapAccumulator {
  final String label;
  final String subLabel;
  final Map<String, double> values = {};
  double total = 0;

  _HeatmapAccumulator({required this.label, required this.subLabel});
}

class _HeatmapMatrixRow {
  final String label;
  final String subLabel;
  final Map<String, double> values;
  final double total;

  const _HeatmapMatrixRow({
    required this.label,
    required this.subLabel,
    required this.values,
    required this.total,
  });
}

const Map<String, String> _stateCodes = {
  'jammu and kashmir': '01',
  'himachal pradesh': '02',
  'punjab': '03',
  'chandigarh': '04',
  'uttarakhand': '05',
  'haryana': '06',
  'delhi': '07',
  'rajasthan': '08',
  'uttar pradesh': '09',
  'bihar': '10',
  'sikkim': '11',
  'arunachal pradesh': '12',
  'nagaland': '13',
  'manipur': '14',
  'mizoram': '15',
  'tripura': '16',
  'meghalaya': '17',
  'assam': '18',
  'west bengal': '19',
  'jharkhand': '20',
  'odisha': '21',
  'chhattisgarh': '22',
  'madhya pradesh': '23',
  'gujarat': '24',
  'daman and diu': '25',
  'dadra and nagar haveli and daman and diu': '26',
  'maharashtra': '27',
  'andhra pradesh': '37',
  'karnataka': '29',
  'goa': '30',
  'lakshadweep': '31',
  'kerala': '32',
  'tamil nadu': '33',
  'puducherry': '34',
  'andaman and nicobar islands': '35',
  'telangana': '36',
  'ladakh': '38',
};

final Map<String, String> _stateNameByCode = {
  for (final entry in _stateCodes.entries)
    entry.value: entry.key
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' '),
};

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
import '../../controllers/reports/stock_in_report_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../models/reports/sales_report_model.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final ctrl = SalesReportController();
  final purchaseCtrl = StockInReportController();
  final propertyCtrl = PropertyInfoController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _itemSearchCtrl = TextEditingController();
  final ScrollController _gstVerticalController = ScrollController();
  final ScrollController _gstHorizontalController = ScrollController();
  final ScrollController _billWiseHorizontalController = ScrollController();
  final ScrollController _dateWiseHorizontalController = ScrollController();
  final ScrollController _gstr2VerticalController = ScrollController();
  final ScrollController _gstr2HorizontalController = ScrollController();

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
    propertyCtrl.load();
    _syncDates();
    _loadReports();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _itemSearchCtrl.dispose();
    _gstVerticalController.dispose();
    _gstHorizontalController.dispose();
    _billWiseHorizontalController.dispose();
    _dateWiseHorizontalController.dispose();
    _gstr2VerticalController.dispose();
    _gstr2HorizontalController.dispose();
    purchaseCtrl.dispose();
    ctrl.dispose();
    super.dispose();
  }

  void _syncDates() {
    _fromCtrl.text = DateFormat('dd-MM-yyyy').format(ctrl.fromDate);
    _toCtrl.text = DateFormat('dd-MM-yyyy').format(ctrl.toDate);
  }

  Future<void> _loadReports() async {
    purchaseCtrl.fromDate = ctrl.fromDate;
    purchaseCtrl.toDate = ctrl.toDate;
    await Future.wait([
      ctrl.load().catchError((_) {}),
      purchaseCtrl.load().catchError((_) {}),
    ]);
    if (mounted) setState(() {});
  }

  Future<void> _reloadReports() async {
    _syncDates();
    await _loadReports();
  }

  bool _isTaxedItem(SalesReportItem item) {
    return item.taxAmount > 0.009;
  }

  bool _isTaxedSale(SalesReport sale) {
    if (sale.totalTax > 0.009) return true;
    return sale.items.any(_isTaxedItem);
  }

  double _normalizeTaxRate(double rate) {
    return double.parse(rate.toStringAsFixed(2));
  }

  double _itemTaxRate(SalesReportItem item) {
    final rate = item.taxBreakup.fold<double>(0, (sum, tax) => sum + tax.rate);
    return _normalizeTaxRate(rate);
  }

  Map<double, _TaxBandSummary> _saleTaxBands(SalesReport sale) {
    final bands = <double, _TaxBandSummary>{};

    for (final item in sale.items) {
      final rate = _itemTaxRate(item);
      final band = bands.putIfAbsent(rate, _TaxBandSummary.new);
      band.taxableValue += item.taxableAmount;
      band.taxAmount += item.taxAmount;
    }

    return bands;
  }

  Map<double, _TaxBandSummary> _mergeTaxBands(
    Map<double, _TaxBandSummary> current,
    Map<double, _TaxBandSummary> incoming,
  ) {
    for (final entry in incoming.entries) {
      final band = current.putIfAbsent(entry.key, _TaxBandSummary.new);
      band.taxableValue += entry.value.taxableValue;
      band.taxAmount += entry.value.taxAmount;
    }
    return current;
  }

  List<double> get _availableTaxRates {
    final rates = <double>{};
    for (final sale in _billWiseSales) {
      for (final item in sale.items) {
        rates.add(_itemTaxRate(item));
      }
    }
    final list = rates.toList()..sort();
    return list;
  }

  String _formatTaxPercent(double rate) {
    return rate % 1 == 0 ? rate.toStringAsFixed(0) : rate.toStringAsFixed(2);
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
            itemGroup: item.itemGroup.trim().isEmpty
                ? 'Ungrouped'
                : item.itemGroup.trim(),
            subCategory: item.subCategory.trim().isEmpty
                ? 'Uncategorized'
                : item.subCategory.trim(),
            brand: item.brand.trim().isEmpty
                ? 'No Brand'
                : item.brand.trim(),
            hsnSacCode: item.hsnSacCode.trim(),
            quantity: item.qty,
            unit: item.unit.trim(),
            taxableValue: _isTaxedItem(item) ? item.taxableAmount : 0,
            taxSaleValue: _isTaxedItem(item) ? item.netAmount : 0,
            nonTaxSaleValue: _isTaxedItem(item) ? 0 : item.netAmount,
            cgstAmount: _taxAmountFor(item, 'CGST'),
            sgstAmount: _taxAmountFor(item, 'SGST'),
            igstAmount: _taxAmountFor(item, 'IGST'),
            totalInvoiceValue: item.netAmount,
            saleDateTime: sale.saleDate,
            paymentMode: sale.paymentMode,
            discount: item.lineDiscount,
            subTotal: item.amount,
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
          row.brand.toLowerCase().contains(query) ||
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
        'BRAND' => row.brand,
        _ => '${row.itemDescription}|${row.hsnSacCode}|${row.unit}',
      };
      final current = grouped[key];
      if (current == null) {
        grouped[key] = _GroupedSalesRow(
          label: _groupBy == 'GROUP'
              ? row.itemGroup
              : _groupBy == 'SUBCATEGORY'
                  ? row.subCategory
                  : _groupBy == 'BRAND'
                      ? row.brand
                      : row.itemDescription,
          itemGroup: row.itemGroup,
          subCategory: row.subCategory,
          brand: row.brand,
          hsnSacCode: row.hsnSacCode,
          unit: row.unit,
          quantity: row.quantity,
          taxableValue: row.taxableValue,
          taxSaleValue: row.taxSaleValue,
          nonTaxSaleValue: row.nonTaxSaleValue,
          cgstAmount: row.cgstAmount,
          sgstAmount: row.sgstAmount,
          igstAmount: row.igstAmount,
          totalInvoiceValue: row.totalInvoiceValue,
          lineCount: 1,
          paymentModes: {row.paymentMode},
          discount: row.discount,
          subTotal: row.subTotal,
        );
      } else {
        grouped[key] = current.copyWith(
          quantity: current.quantity + row.quantity,
          taxableValue: current.taxableValue + row.taxableValue,
          taxSaleValue: current.taxSaleValue + row.taxSaleValue,
          nonTaxSaleValue: current.nonTaxSaleValue + row.nonTaxSaleValue,
          cgstAmount: current.cgstAmount + row.cgstAmount,
          sgstAmount: current.sgstAmount + row.sgstAmount,
          igstAmount: current.igstAmount + row.igstAmount,
          totalInvoiceValue: current.totalInvoiceValue + row.totalInvoiceValue,
          lineCount: current.lineCount + 1,
          paymentModes: Set<String>.from(current.paymentModes)..add(row.paymentMode),
          discount: current.discount + row.discount,
          subTotal: current.subTotal + row.subTotal,
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

  double get _taxSaleTotal => _billWiseSales.fold<double>(
      0,
      (sum, sale) =>
          sum +
          sale.items.fold<double>(
            0,
            (itemSum, item) =>
                itemSum + (_isTaxedItem(item) ? item.netAmount : 0),
          ));

  double get _nonTaxSaleTotal => _billWiseSales.fold<double>(
      0,
      (sum, sale) =>
          sum +
          sale.items.fold<double>(
            0,
            (itemSum, item) =>
                itemSum + (_isTaxedItem(item) ? 0 : item.netAmount),
          ));
  double get _headerTaxableTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + _taxableSaleValue(sale));
  double get _headerCgstTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.cgstAmount);
  double get _headerSgstTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.sgstAmount);
  double get _headerIgstTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.igstAmount);
  double get _headerTaxTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.totalTax);
  double get _headerRevenueTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.netAmount);
  double get _headerDiscountTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.totalDiscount);
  double get _headerChargeTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.chargeTotal);

  List<SalesReport> get _billWiseSales {
    final query = _itemSearchCtrl.text.trim().toLowerCase();
    final filtered = ctrl.list.where((sale) {
      if (_isCustomerDataRow(sale)) return false;
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
    filtered.sort((a, b) {
      final aNo = _saleNoNumericValue(a.saleNo);
      final bNo = _saleNoNumericValue(b.saleNo);
      if (aNo != bNo) return aNo.compareTo(bNo);
      return a.saleNo.compareTo(b.saleNo);
    });
    return filtered;
  }

  int _saleNoNumericValue(String saleNo) {
    final raw = saleNo.trim();
    final match = RegExp(r'(\d+)').firstMatch(raw);
    if (match == null) return 1 << 30;
    return int.tryParse(match.group(1) ?? '') ?? (1 << 30);
  }

  bool _isCustomerDataRow(SalesReport sale) {
    return sale.saleNo.trim().toUpperCase().startsWith('CUST-');
  }

  double get _billWiseNetTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.netAmount);
  double get _billWiseTaxTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.totalTax);
  double get _billWiseDiscountTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.totalDiscount);
  double get _billWiseSubTotalTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.subTotal);
  double get _billWiseChargeTotalTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.chargeTotal);
  double get _billWiseQtyTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.totalQty);
  double get _billWiseTaxableSaleTotal => _billWiseSales.fold<double>(
      0, (sum, sale) => sum + _billWiseTaxSaleValue(sale));
  double get _billWiseNonTaxableSaleTotal => _billWiseSales.fold<double>(
      0, (sum, sale) => sum + _billWiseNonTaxSaleValue(sale));
  double get _billWiseGst5Total => _billWiseTaxBandsTotal[5]?.taxableValue ?? 0;
  double get _billWiseGst0Total => _billWiseTaxBandsTotal[0]?.taxableValue ?? 0;
  double get _billWiseGst18Total =>
      _billWiseTaxBandsTotal[18]?.taxableValue ?? 0;
  double get _billWiseGst40Total =>
      _billWiseTaxBandsTotal[40]?.taxableValue ?? 0;
  double get _billWiseGst5TaxTotal => _billWiseTaxBandsTotal[5]?.taxAmount ?? 0;
  double get _billWiseGst18TaxTotal =>
      _billWiseTaxBandsTotal[18]?.taxAmount ?? 0;
  double get _billWiseGst40TaxTotal =>
      _billWiseTaxBandsTotal[40]?.taxAmount ?? 0;
  int get _paymentWiseCountTotal =>
      ctrl.paymentModes.fold<int>(0, (sum, entry) => sum + entry.count);
  double get _paymentWiseAmountTotal =>
      ctrl.paymentModes.fold<double>(0, (sum, entry) => sum + entry.amount);
  double get _paymentReportTaxSaleTotal => _billWiseSales.fold<double>(
      0, (sum, sale) => sum + _billWiseTaxSaleValue(sale));
  double get _paymentReportNonTaxSaleTotal => _billWiseSales.fold<double>(
      0, (sum, sale) => sum + _billWiseNonTaxSaleValue(sale));
  double get _itemWiseLineCountTotal =>
      _groupedRows.fold<double>(0, (sum, row) => sum + row.lineCount);
  double get _itemWiseQtyTotal =>
      _groupedRows.fold<double>(0, (sum, row) => sum + row.quantity);
  double get _itemWiseSubTotalTotal =>
      _groupedRows.fold<double>(0, (sum, row) => sum + row.subTotal);
  double get _itemWiseDiscountTotal =>
      _groupedRows.fold<double>(0, (sum, row) => sum + row.discount);
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
  double get _itemWiseTaxableSaleTotal =>
      _groupedRows.fold<double>(0, (sum, row) => sum + row.taxSaleValue);
  double get _itemWiseNonTaxableSaleTotal =>
      _groupedRows.fold<double>(0, (sum, row) => sum + row.nonTaxSaleValue);
  Map<double, _TaxBandSummary> get _billWiseTaxBandsTotal {
    final bands = <double, _TaxBandSummary>{};
    for (final sale in _billWiseSales) {
      _mergeTaxBands(bands, _saleTaxBands(sale));
    }
    return bands;
  }

  Map<double, _TaxBandSummary> get _dateWiseTaxBandsTotal {
    final bands = <double, _TaxBandSummary>{};
    for (final row in _dateWiseSalesRows) {
      _mergeTaxBands(bands, row.taxBands);
    }
    return bands;
  }

  double get _billWiseIgstTotal => _billWiseSales.fold<double>(
      0, (sum, sale) => sum + _saleIgstAmount(sale));
  double get _dateWiseIgstTotal =>
      _dateWiseSalesRows.fold<double>(0, (sum, row) => sum + row.igstAmount);
  double get _gstr2TaxableTotal =>
      _gstr2Rows.fold<double>(0, (sum, row) => sum + row.taxableValue);
  double get _gstr2TaxTotal =>
      _gstr2Rows.fold<double>(0, (sum, row) => sum + row.taxAmount);
  double get _gstr2NetTotal =>
      _gstr2Rows.fold<double>(0, (sum, row) => sum + row.totalAfterTax);
  double get _gstr2OutstandingTotal =>
      _gstr2Rows.fold<double>(0, (sum, row) => sum + row.outstandingAmount);
  int get _gstr2BillCount =>
      _gstr2Rows.fold<int>(0, (sum, row) => sum + row.billCount);

  double _billWiseTaxSaleValue(SalesReport sale) {
    return sale.items.fold<double>(
      0,
      (sum, item) => sum + (_isTaxedItem(item) ? item.netAmount : 0),
    );
  }

  double _billWiseNonTaxSaleValue(SalesReport sale) {
    return sale.items.fold<double>(
      0,
      (sum, item) => sum + (_isTaxedItem(item) ? 0 : item.netAmount),
    );
  }

  double _taxableSaleValue(SalesReport sale) {
    return sale.items.fold<double>(
      0,
      (sum, item) => sum + (_isTaxedItem(item) ? item.taxableAmount : 0),
    );
  }

  List<_Gstr2Row> get _gstr2Rows {
    final grouped = <String, _Gstr2Row>{};
    for (final row in purchaseCtrl.filteredData) {
      final key = row.inwardsNo.toString();
      final existing = grouped[key];
      final taxableValue = row.rate * row.qty;
      if (existing == null) {
        grouped[key] = _Gstr2Row(
          invoiceDate: row.date,
          grnNo: row.grnNo,
          billNo: row.billNo,
          supplier: row.supplier,
          supplierGstin: row.supplierGstin,
          supplierState: row.supplierState,
          billStatus: row.billStatus,
          paidAmount: row.paidAmount,
          outstandingAmount: row.outstandingAmount,
          taxableValue: taxableValue,
          taxAmount: row.taxAmount,
          totalAfterTax: row.netAmount,
          billCount: 1,
          itemCount: 1,
          qty: row.qty,
        );
      } else {
        grouped[key] = existing.copyWith(
          taxableValue: existing.taxableValue + taxableValue,
          taxAmount: existing.taxAmount + row.taxAmount,
          totalAfterTax: existing.totalAfterTax + row.netAmount,
          itemCount: existing.itemCount + 1,
          qty: existing.qty + row.qty,
        );
      }
    }

    return grouped.values.toList()
      ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
  }

  double _saleTaxBandValue(SalesReport sale, double rate) {
    return _saleTaxBands(sale)[_normalizeTaxRate(rate)]?.taxableValue ?? 0;
  }

  double _saleTaxBandTax(SalesReport sale, double rate) {
    return _saleTaxBands(sale)[_normalizeTaxRate(rate)]?.taxAmount ?? 0;
  }

  double _saleIgstAmount(SalesReport sale) {
    return sale.items.fold<double>(
      0,
      (sum, item) =>
          sum +
          item.taxBreakup
              .where((tax) => tax.code.toUpperCase() == 'IGST')
              .fold<double>(0, (taxSum, tax) => taxSum + tax.taxAmount),
    );
  }

  double _bandTaxable(Map<double, _TaxBandSummary> bands, double rate) {
    return bands[_normalizeTaxRate(rate)]?.taxableValue ?? 0;
  }

  double _bandTax(Map<double, _TaxBandSummary> bands, double rate) {
    return bands[_normalizeTaxRate(rate)]?.taxAmount ?? 0;
  }

  double _bandSale(Map<double, _TaxBandSummary> bands, double rate) {
    final band = bands[_normalizeTaxRate(rate)];
    return band == null ? 0 : band.taxableValue + band.taxAmount;
  }

  List<_DateWiseSalesRow> get _dateWiseSalesRows {
    final grouped = <String, _DateWiseSalesRow>{};
    for (final sale in _billWiseSales) {
      final dateOnly =
          DateTime(sale.saleDate.year, sale.saleDate.month, sale.saleDate.day);
      final key = DateFormat('yyyy-MM-dd').format(dateOnly);
      final current = grouped[key];
      final saleBands = _saleTaxBands(sale);
      if (current == null) {
        grouped[key] = _DateWiseSalesRow(
          date: dateOnly,
          bills: 1,
          qty: sale.totalQty,
          taxBands: saleBands,
          igstAmount: _saleIgstAmount(sale),
          taxAmount: sale.totalTax,
          netAmount: sale.netAmount,
          paymentModes: {sale.paymentMode},
          subTotal: sale.subTotal,
          discount: sale.totalDiscount,
          chargeTotal: sale.chargeTotal,
        );
      } else {
        grouped[key] = current.copyWith(
          bills: current.bills + 1,
          qty: current.qty + sale.totalQty,
          taxBands: _mergeTaxBands(current.taxBands, saleBands),
          igstAmount: current.igstAmount + _saleIgstAmount(sale),
          taxAmount: current.taxAmount + sale.totalTax,
          netAmount: current.netAmount + sale.netAmount,
          paymentModes: Set<String>.from(current.paymentModes)..add(sale.paymentMode),
          subTotal: current.subTotal + sale.subTotal,
          discount: current.discount + sale.totalDiscount,
          chargeTotal: current.chargeTotal + sale.chargeTotal,
        );
      }
    }
    final rows = grouped.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return rows;
  }

  int get _dateWiseBillsTotal =>
      _dateWiseSalesRows.fold<int>(0, (sum, row) => sum + row.bills);
  double get _dateWiseQtyTotal =>
      _dateWiseSalesRows.fold<double>(0, (sum, row) => sum + row.qty);
  double get _dateWiseTaxTotal =>
      _dateWiseSalesRows.fold<double>(0, (sum, row) => sum + row.taxAmount);
  double get _dateWiseSubTotalTotal =>
      _dateWiseSalesRows.fold<double>(0, (sum, row) => sum + row.subTotal);
  double get _dateWiseDiscountTotal =>
      _dateWiseSalesRows.fold<double>(0, (sum, row) => sum + row.discount);
  double get _dateWiseChargeTotalTotal =>
      _dateWiseSalesRows.fold<double>(0, (sum, row) => sum + row.chargeTotal);
  double get _dateWiseNetTotal =>
      _dateWiseSalesRows.fold<double>(0, (sum, row) => sum + row.netAmount);

  String _maskedBillNo(String billNo) {
    final value = billNo.trim();
    if (value.toUpperCase().startsWith('CUST-')) return '-';
    return value;
  }

  double _itemWiseTaxSaleValue(_GroupedSalesRow row) {
    return row.taxSaleValue;
  }

  double _itemWiseNonTaxSaleValue(_GroupedSalesRow row) {
    return row.nonTaxSaleValue;
  }

  _GstSummary get _summary {
    return _billWiseSales.fold(
      const _GstSummary(),
      (sum, sale) {
        final itemDiscounts = sale.items.fold<double>(0, (isum, item) => isum + item.lineDiscount);
        final billDiscount = sale.totalDiscount - itemDiscounts;
        return _GstSummary(
          taxableValue: sum.taxableValue + _taxableSaleValue(sale),
          cgstAmount: sum.cgstAmount + sale.cgstAmount,
          sgstAmount: sum.sgstAmount + sale.sgstAmount,
          igstAmount: sum.igstAmount + sale.igstAmount,
          totalRevenue: sum.totalRevenue + sale.netAmount,
          billDiscount: sum.billDiscount + billDiscount,
          chargeTotal: sum.chargeTotal + sale.chargeTotal,
        );
      },
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
    });
    await _reloadReports();
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
    });
    await _reloadReports();
  }

  Future<void> _exportExcel() async {
    final workbook = exc.Excel.createExcel();
    final taxRates = _availableTaxRates;
    final sheetName = switch (_reportTabIndex) {
      0 => 'Payment_Wise_Sales',
      1 => 'Bill_Wise_Sales',
      2 => 'Item_Wise_Sales',
      3 => 'Date_Wise_Sales',
      4 => 'GSTR_1_Sales',
      _ => 'GSTR_2_Purchases',
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
          'Payment',
          'Subtotal',
          'Discount',
          'Charges',
          ...taxRates.expand(
            (rate) => [
              '${_formatTaxPercent(rate)}% Sale',
              if (rate > 0.009) '${_formatTaxPercent(rate)}% GST',
            ],
          ),
          'IGST',
          'Tax',
          'Net Amount',
        ].map(exc.TextCellValue.new).toList(),
      );
      for (final sale in _billWiseSales) {
        final bands = _saleTaxBands(sale);
        sheet.appendRow([
          exc.TextCellValue(DateFormat('dd-MM-yyyy').format(sale.saleDate)),
          exc.TextCellValue(_maskedBillNo(sale.saleNo)),
          exc.TextCellValue(sale.paymentMode),
          exc.DoubleCellValue(sale.subTotal),
          exc.DoubleCellValue(sale.totalDiscount),
          exc.DoubleCellValue(sale.chargeTotal),
          ...taxRates.expand(
            (rate) => [
              exc.DoubleCellValue(_bandTaxable(bands, rate)),
              if (rate > 0.009) exc.DoubleCellValue(_bandTax(bands, rate)),
            ],
          ),
          exc.DoubleCellValue(_saleIgstAmount(sale)),
          exc.DoubleCellValue(sale.totalTax),
          exc.DoubleCellValue(sale.netAmount),
        ]);
      }
      sheet.appendRow([
        exc.TextCellValue('TOTAL'),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.DoubleCellValue(_billWiseSubTotalTotal),
        exc.DoubleCellValue(_billWiseDiscountTotal),
        exc.DoubleCellValue(_billWiseChargeTotalTotal),
        ...taxRates.expand(
          (rate) => [
            exc.DoubleCellValue(_billWiseTaxBandsTotal[rate]?.taxableValue ?? 0),
            if (rate > 0.009)
              exc.DoubleCellValue(_billWiseTaxBandsTotal[rate]?.taxAmount ?? 0),
          ],
        ),
        exc.DoubleCellValue(_billWiseIgstTotal),
        exc.DoubleCellValue(_billWiseTaxTotal),
        exc.DoubleCellValue(_billWiseNetTotal),
      ]);
    } else if (_reportTabIndex == 2) {
      sheet.appendRow(
        [
          'Label',
          'HSN/SAC',
          'Rows',
          'Qty',
          'Unit',
          'Payment',
          'Subtotal',
          'Discount',
          'Taxed Sales',
          'Non-Tax Sales',
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
          exc.TextCellValue(row.hsnSacCode),
          exc.IntCellValue(row.lineCount),
          exc.DoubleCellValue(row.quantity),
          exc.TextCellValue(row.unit),
          exc.TextCellValue(row.paymentModes.join(', ')),
          exc.DoubleCellValue(row.subTotal),
          exc.DoubleCellValue(row.discount),
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
        exc.DoubleCellValue(_itemWiseLineCountTotal),
        exc.DoubleCellValue(_itemWiseQtyTotal),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.DoubleCellValue(_itemWiseSubTotalTotal),
        exc.DoubleCellValue(_itemWiseDiscountTotal),
        exc.DoubleCellValue(_itemWiseTaxableSaleTotal),
        exc.DoubleCellValue(_itemWiseNonTaxableSaleTotal),
        exc.DoubleCellValue(_itemWiseTaxableTotal),
        exc.DoubleCellValue(_itemWiseCgstTotal),
        exc.DoubleCellValue(_itemWiseSgstTotal),
        exc.DoubleCellValue(_itemWiseIgstTotal),
        exc.DoubleCellValue(_itemWiseSalesTotal),
      ]);
    } else if (_reportTabIndex == 4) {
      sheet.appendRow(
        _gstHeaders.map(exc.TextCellValue.new).toList(),
      );
      for (final row in _rows) {
        sheet.appendRow([
          exc.TextCellValue(DateFormat('dd-MM-yyyy').format(row.invoiceDate)),
          exc.TextCellValue(row.invoiceNumber),
          exc.TextCellValue(row.customerName),
          exc.TextCellValue(
              row.customerGstin.isEmpty ? 'B2C' : row.customerGstin),
          exc.TextCellValue(row.placeOfSupply),
          exc.TextCellValue(row.itemDescription),
          exc.TextCellValue(row.hsnSacCode),
          exc.TextCellValue('${_formatQty(row.quantity)} ${row.unit}'),
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
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.DoubleCellValue(_headerTaxableTotal),
        exc.DoubleCellValue(_headerCgstTotal),
        exc.DoubleCellValue(_headerSgstTotal),
        exc.DoubleCellValue(
            _rows.fold<double>(0, (sum, row) => sum + row.igstAmount)),
        exc.DoubleCellValue(
            _rows.fold<double>(0, (sum, row) => sum + row.totalInvoiceValue)),
      ]);
    } else if (_reportTabIndex == 5) {
      sheet.appendRow([
        'Date',
        'GRN No',
        'Bill No',
        'Supplier',
        'GSTIN',
        'State',
        'Items',
        'Qty',
        'Taxable Value',
        'GST Amount',
        'Net Amount',
        'Paid',
        'Outstanding',
        'Status',
      ].map(exc.TextCellValue.new).toList());
      for (final row in _gstr2Rows) {
        sheet.appendRow([
          exc.TextCellValue(DateFormat('dd-MM-yyyy').format(row.invoiceDate)),
          exc.TextCellValue(row.grnNo),
          exc.TextCellValue(row.billNo),
          exc.TextCellValue(row.supplier),
          exc.TextCellValue(row.supplierGstin),
          exc.TextCellValue(row.supplierState),
          exc.IntCellValue(row.itemCount),
          exc.DoubleCellValue(row.qty),
          exc.DoubleCellValue(row.taxableValue),
          exc.DoubleCellValue(row.taxAmount),
          exc.DoubleCellValue(row.totalAfterTax),
          exc.DoubleCellValue(row.paidAmount),
          exc.DoubleCellValue(row.outstandingAmount),
          exc.TextCellValue(row.billStatus),
        ]);
      }
      sheet.appendRow([
        exc.TextCellValue('TOTAL'),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.TextCellValue(''),
        exc.DoubleCellValue(_gstr2Rows
            .fold<int>(0, (sum, row) => sum + row.itemCount)
            .toDouble()),
        exc.DoubleCellValue(
            _gstr2Rows.fold<double>(0, (sum, row) => sum + row.qty)),
        exc.DoubleCellValue(_gstr2TaxableTotal),
        exc.DoubleCellValue(_gstr2TaxTotal),
        exc.DoubleCellValue(_gstr2NetTotal),
        exc.DoubleCellValue(
            _gstr2Rows.fold<double>(0, (sum, row) => sum + row.paidAmount)),
        exc.DoubleCellValue(_gstr2OutstandingTotal),
        exc.TextCellValue(''),
      ]);
    } else {
      sheet.appendRow(
        [
          'Date',
          'Bills',
          'Qty',
          'Payment',
          'Subtotal',
          'Discount',
          'Charges',
          ...taxRates.expand(
            (rate) => [
              '${_formatTaxPercent(rate)}% Sale',
              if (rate > 0.009) '${_formatTaxPercent(rate)}% GST',
            ],
          ),
          'IGST',
          'Tax',
          'Net Amount',
        ].map(exc.TextCellValue.new).toList(),
      );
      for (final row in _dateWiseSalesRows) {
        final bands = row.taxBands;
        sheet.appendRow([
          exc.TextCellValue(DateFormat('dd-MM-yyyy').format(row.date)),
          exc.IntCellValue(row.bills),
          exc.DoubleCellValue(row.qty),
          exc.TextCellValue(row.paymentModes.join(', ')),
          exc.DoubleCellValue(row.subTotal),
          exc.DoubleCellValue(row.discount),
          exc.DoubleCellValue(row.chargeTotal),
          ...taxRates.expand(
            (rate) => [
              exc.DoubleCellValue(_bandTaxable(bands, rate)),
              if (rate > 0.009) exc.DoubleCellValue(_bandTax(bands, rate)),
            ],
          ),
          exc.DoubleCellValue(row.igstAmount),
          exc.DoubleCellValue(row.taxAmount),
          exc.DoubleCellValue(row.netAmount),
        ]);
      }
      sheet.appendRow([
        exc.TextCellValue('TOTAL'),
        exc.IntCellValue(_dateWiseBillsTotal),
        exc.DoubleCellValue(_dateWiseQtyTotal),
        exc.TextCellValue(''),
        exc.DoubleCellValue(_dateWiseSubTotalTotal),
        exc.DoubleCellValue(_dateWiseDiscountTotal),
        exc.DoubleCellValue(_dateWiseChargeTotalTotal),
        ...taxRates.expand(
          (rate) => [
            exc.DoubleCellValue(_dateWiseTaxBandsTotal[rate]?.taxableValue ?? 0),
            if (rate > 0.009)
              exc.DoubleCellValue(_dateWiseTaxBandsTotal[rate]?.taxAmount ?? 0),
          ],
        ),
        exc.DoubleCellValue(_dateWiseIgstTotal),
        exc.DoubleCellValue(_dateWiseTaxTotal),
        exc.DoubleCellValue(_dateWiseNetTotal),
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
    final taxRates = _availableTaxRates;
    final title = switch (_reportTabIndex) {
      0 => 'Payment Wise Sales Report',
      1 => 'Bill Wise Sales Report',
      2 => 'Item Wise Sales Report',
      3 => 'Date Wise Sales Report',
      4 => 'GSTR-1 Sales Report',
      _ => 'GSTR-2 Purchase Report',
    };
    final headers = switch (_reportTabIndex) {
      0 => ['Payment Mode', 'Sales Count', 'Amount'],
      1 => [
          'Date',
          'Bill No',
          'Payment',
          'Subtotal',
          'Discount',
          'Charges',
          ...taxRates.expand(
            (rate) => [
              '${_formatTaxPercent(rate)}% Sale',
              '${_formatTaxPercent(rate)}% GST',
            ],
          ),
          'IGST',
          'Tax',
          'Net Amount'
        ],
      2 => [
          'Label',
          'HSN/SAC',
          'Rows',
          'Qty',
          'Unit',
          'Payment',
          'Subtotal',
          'Discount',
          'Taxed Sales',
          'Non-Tax Sales',
          'Taxable',
          'CGST',
          'SGST',
          'IGST',
          'Sales'
        ],
      3 => [
          'Date',
          'Bills',
          'Qty',
          'Payment',
          'Subtotal',
          'Discount',
          'Charges',
          ...taxRates.expand(
            (rate) => [
              '${_formatTaxPercent(rate)}% Sale',
              '${_formatTaxPercent(rate)}% GST',
            ],
          ),
          'IGST',
          'Tax',
          'Net Amount'
        ],
      4 => _gstHeaders,
      _ => [
          'Date',
          'GRN No',
          'Bill No',
          'Supplier',
          'GSTIN',
          'State',
          'Items',
          'Qty',
          'Taxable Value',
          'GST Amount',
          'Net Amount',
          'Paid',
          'Outstanding',
          'Status'
        ],
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
      1 => _billWiseSales.map(
          (sale) {
            final bands = _saleTaxBands(sale);
            return [
              DateFormat('dd-MM-yyyy').format(sale.saleDate),
              _maskedBillNo(sale.saleNo),
              sale.paymentMode,
              _money(sale.subTotal),
              _money(sale.totalDiscount),
              _money(sale.chargeTotal),
              ...taxRates.expand(
                (rate) => [
                  _money(_bandTaxable(bands, rate)),
                  _money(_bandTax(bands, rate)),
                ],
              ),
              _money(_saleIgstAmount(sale)),
              _money(sale.totalTax),
              _money(sale.netAmount),
            ];
          },
        ).toList()
          ..add([
            'TOTAL',
            '',
            '',
            _money(_billWiseSubTotalTotal),
            _money(_billWiseDiscountTotal),
            _money(_billWiseChargeTotalTotal),
            ...taxRates.expand(
              (rate) => [
                _money(_billWiseTaxBandsTotal[rate]?.taxableValue ?? 0),
                _money(_billWiseTaxBandsTotal[rate]?.taxAmount ?? 0),
              ],
            ),
            _money(_billWiseIgstTotal),
            _money(_billWiseTaxTotal),
            _money(_billWiseNetTotal),
          ]),
      2 => _groupedRows
          .map(
            (row) => [
              row.label,
              row.hsnSacCode,
              '${row.lineCount}',
              _formatQty(row.quantity),
              row.unit,
              row.paymentModes.join(', '),
              _money(row.subTotal),
              _money(row.discount),
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
          _formatQty(_itemWiseLineCountTotal),
          _formatQty(_itemWiseQtyTotal),
          '',
          '',
          _money(_itemWiseSubTotalTotal),
          _money(_itemWiseDiscountTotal),
          _money(_itemWiseTaxableSaleTotal),
          _money(_itemWiseNonTaxableSaleTotal),
          _money(_itemWiseTaxableTotal),
          _money(_itemWiseCgstTotal),
          _money(_itemWiseSgstTotal),
          _money(_itemWiseIgstTotal),
          _money(_itemWiseSalesTotal),
        ]),
      3 => _dateWiseSalesRows
          .map(
            (row) => [
              DateFormat('dd-MM-yyyy').format(row.date),
              '${row.bills}',
              _formatQty(row.qty),
              row.paymentModes.join(', '),
              _money(row.subTotal),
              _money(row.discount),
              _money(row.chargeTotal),
              ...taxRates.expand(
                (rate) => [
                  _money(_bandTaxable(row.taxBands, rate)),
                  _money(_bandTax(row.taxBands, rate)),
                ],
              ),
              _money(row.igstAmount),
              _money(row.taxAmount),
              _money(row.netAmount),
            ],
          )
          .toList()
        ..add([
          'TOTAL',
          '$_dateWiseBillsTotal',
          _formatQty(_dateWiseQtyTotal),
          '',
          _money(_dateWiseSubTotalTotal),
          _money(_dateWiseDiscountTotal),
          _money(_dateWiseChargeTotalTotal),
          ...taxRates.expand(
            (rate) => [
              _money(_dateWiseTaxBandsTotal[rate]?.taxableValue ?? 0),
              _money(_dateWiseTaxBandsTotal[rate]?.taxAmount ?? 0),
            ],
          ),
          _money(_dateWiseIgstTotal),
          _money(_dateWiseTaxTotal),
          _money(_dateWiseNetTotal),
        ]),
      4 => _rows
          .map(
            (row) => [
              DateFormat('dd-MM-yyyy').format(row.invoiceDate),
              row.invoiceNumber,
              row.customerName,
              row.customerGstin.isEmpty ? 'B2C' : row.customerGstin,
              row.placeOfSupply,
              row.itemDescription,
              row.hsnSacCode,
              '${_formatQty(row.quantity)} ${row.unit}',
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
          '',
          '',
          '',
          '',
          _money(_headerTaxableTotal),
          _money(_headerCgstTotal),
          _money(_headerSgstTotal),
          _money(_rows.fold<double>(0, (sum, row) => sum + row.igstAmount)),
          _money(
              _rows.fold<double>(0, (sum, row) => sum + row.totalInvoiceValue)),
        ]),
      _ => _gstr2Rows
          .map(
            (row) => [
              DateFormat('dd-MM-yyyy').format(row.invoiceDate),
              row.grnNo,
              row.billNo,
              row.supplier,
              row.supplierGstin,
              row.supplierState,
              '${row.itemCount}',
              _formatQty(row.qty),
              _money(row.taxableValue),
              _money(row.taxAmount),
              _money(row.totalAfterTax),
              _money(row.paidAmount),
              _money(row.outstandingAmount),
              row.billStatus,
            ],
          )
          .toList()
        ..add([
          'TOTAL',
          '',
          '',
          '',
          '',
          '',
          '${_gstr2Rows.fold<int>(0, (sum, row) => sum + row.itemCount)}',
          _formatQty(_gstr2Rows.fold<double>(0, (sum, row) => sum + row.qty)),
          _money(_gstr2TaxableTotal),
          _money(_gstr2TaxTotal),
          _money(_gstr2NetTotal),
          _money(
              _gstr2Rows.fold<double>(0, (sum, row) => sum + row.paidAmount)),
          _money(_gstr2OutstandingTotal),
          '',
        ]),
    };

    final rowsPerPage = _reportTabIndex == 1
        ? 24
        : _reportTabIndex == 4 || _reportTabIndex == 5
            ? 18
            : 22;
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
                      _pdfSummaryBlock('Taxable Value', summary.taxableValue),
                      _pdfSummaryBlock('Total CGST', summary.cgstAmount),
                      _pdfSummaryBlock('Total SGST', summary.sgstAmount),
                      _pdfSummaryBlock('Non-Tax Sales', _nonTaxSaleTotal),
                      _pdfSummaryBlock('Subscription Sale', ctrl.summary.subscriptionRealized),
                      _pdfSummaryBlock('Charges', summary.chargeTotal),
                      _pdfSummaryBlock('Net Sales', summary.totalRevenue + ctrl.summary.subscriptionRealized),
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
        animation: Listenable.merge([ctrl, purchaseCtrl]),
        builder: (_, __) {
          if (ctrl.loading || purchaseCtrl.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildTopFilters(),
              const SizedBox(height: 16),
              _buildSummaryRow(),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Formula: Net Sales = Taxable Value + CGST + SGST + IGST + Non-Tax Sales + Subscription Sale - Discount + Charges.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ),
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
    const tabs = [
      'Payment Wise',
      'Bill Wise',
      'Item Wise',
      'Date Wise',
      'GSTR-1',
      'GSTR-2',
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
                  backgroundColor: selected
                      ? const Color(0xFF17324D)
                      : const Color(0xFFF8FAFC),
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
    if (_reportTabIndex == 2) {
      return SizedBox(height: 560, child: _buildItemWiseDataTableSection());
    }
    if (_reportTabIndex == 3) {
      return SizedBox(height: 560, child: _buildDateWiseDataTableSection());
    }
    if (_reportTabIndex == 4) {
      return SizedBox(height: 560, child: _buildGstr1Section());
    }
    return SizedBox(height: 560, child: _buildGstr2Section());
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
                DropdownMenuItem(
                  value: 'BRAND',
                  child: Text('Brand Wise'),
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
              initialValue: ctrl.paymentMode?.isNotEmpty == true
                  ? ctrl.paymentMode
                  : 'ALL',
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
                ctrl.paymentMode =
                    value == null || value == 'ALL' ? null : value;
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
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 240,
          child: _metricCard(
            'Taxable Value',
            _headerTaxableTotal,
            const Color(0xFF0F766E),
          ),
        ),
        SizedBox(
          width: 240,
          child: _metricCard(
            'Total CGST',
            _headerCgstTotal,
            const Color(0xFF2563EB),
          ),
        ),
        SizedBox(
          width: 240,
          child: _metricCard(
            'Total SGST',
            _headerSgstTotal,
            const Color(0xFF7C3AED),
          ),
        ),
        SizedBox(
          width: 240,
          child: _metricCard(
            'Total IGST',
            _headerIgstTotal,
            const Color(0xFF0EA5E9),
          ),
        ),
        SizedBox(
          width: 240,
          child: _metricCard(
            'GST Total',
            _headerTaxTotal,
            const Color(0xFFEA580C),
          ),
        ),
        SizedBox(
          width: 240,
          child: _metricCard(
            'Net Sales (Standard)',
            _headerRevenueTotal,
            const Color(0xFFEA580C),
          ),
        ),
        SizedBox(
          width: 240,
          child: _metricCard(
            'Subscription Realized',
            ctrl.summary.subscriptionRealized,
            const Color(0xFF0EA5E9),
          ),
        ),
        SizedBox(
          width: 240,
          child: _metricCard(
            'Total Revenue',
            _headerRevenueTotal + ctrl.summary.subscriptionRealized,
            const Color(0xFF16A34A),
          ),
        ),
        SizedBox(
          width: 240,
          child: _metricCard(
            'Taxed Sales After GST',
            _taxSaleTotal,
            const Color(0xFF16A34A),
          ),
        ),
        SizedBox(
          width: 240,
          child: _metricCard(
            'Non-Tax Sales',
            _nonTaxSaleTotal,
            const Color(0xFF64748B),
          ),
        ),
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
            Expanded(
                child:
                    _buildComparisonChart('Month On Month', ctrl.monthOnMonth)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _buildComparisonChart('Week On Week', ctrl.weekOnWeek)),
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
                DataColumn(label: Text('Payment')),
                DataColumn(label: Text('Taxed Sales')),
                DataColumn(label: Text('Non-Tax Sales')),
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
                        DataCell(Text(_maskedBillNo(sale.saleNo))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _paymentColor(sale.paymentMode)
                                  .withOpacity(0.14),
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
                          Text(_money(_billWiseTaxSaleValue(sale))),
                        ),
                        DataCell(
                          Text(_money(_billWiseNonTaxSaleValue(sale))),
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
      _ChartBarPoint(
          'Discount', summary.totalDiscount, const Color(0xFFF59E0B)),
      _ChartBarPoint(
          'Profit', summary.estimatedProfit, const Color(0xFF16A34A)),
      _ChartBarPoint('Loss', summary.estimatedLoss, const Color(0xFFDC2626)),
    ];

    return _chartCard(
      title: 'Sales / Discount / Profit / Loss',
      child: SfCartesianChart(
        primaryXAxis: const CategoryAxis(),
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
              primaryXAxis: const CategoryAxis(),
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
    final taxRates = _availableTaxRates;
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
                      child: Scrollbar(
                          controller: _billWiseHorizontalController,
                          thumbVisibility: true,
                          notificationPredicate: (notification) =>
                              notification.metrics.axis == Axis.horizontal,
                          child: SingleChildScrollView(
                            controller: _billWiseHorizontalController,
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 1800),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFF8FAFC),
                                ),
                                dataRowMinHeight: 52,
                                dataRowMaxHeight: 68,
                                columns: [
                                  const DataColumn(label: Text('Date')),
                                  const DataColumn(label: Text('Bill No')),
                                  const DataColumn(label: Text('Payment')),
                                  const DataColumn(label: Text('Subtotal')),
                                  const DataColumn(label: Text('Discount')),
                                  const DataColumn(label: Text('Charges')),
                                  ...taxRates.expand(
                                    (rate) => [
                                      DataColumn(
                                          label: Text(
                                              '${_formatTaxPercent(rate)}% Sale')),
                                      if (rate > 0.009)
                                        DataColumn(
                                            label: Text(
                                                '${_formatTaxPercent(rate)}% GST')),
                                    ],
                                  ),
                                  const DataColumn(label: Text('IGST')),
                                  const DataColumn(label: Text('Tax')),
                                  const DataColumn(label: Text('Net Amount')),
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
                                        DataCell(
                                            Text(_maskedBillNo(sale.saleNo))),
                                        DataCell(Text(sale.paymentMode)),
                                        DataCell(Text(_money(sale.subTotal))),
                                        DataCell(Text(_money(sale.totalDiscount))),
                                        DataCell(Text(_money(sale.chargeTotal))),
                                        ...taxRates.expand(
                                          (rate) => [
                                            DataCell(Text(_money(
                                                _saleTaxBandValue(
                                                    sale, rate)))),
                                            if (rate > 0.009)
                                              DataCell(Text(_money(
                                                  _saleTaxBandTax(
                                                      sale, rate)))),
                                          ],
                                        ),
                                        DataCell(Text(
                                            _money(_saleIgstAmount(sale)))),
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
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      const DataCell(Text('')),
                                      const DataCell(Text('')),
                                      DataCell(
                                        Text(
                                          _money(_billWiseSubTotalTotal),
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
                                          _money(_billWiseChargeTotalTotal),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      ...taxRates.expand(
                                        (rate) => [
                                          DataCell(
                                            Text(
                                              _money(_billWiseTaxBandsTotal[rate]
                                                      ?.taxableValue ??
                                                  0),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800),
                                            ),
                                          ),
                                          if (rate > 0.009)
                                            DataCell(
                                              Text(
                                                _money(
                                                    _billWiseTaxBandsTotal[rate]
                                                            ?.taxAmount ??
                                                        0),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w800),
                                              ),
                                            ),
                                        ],
                                      ),
                                      DataCell(
                                        Text(
                                          _money(_billWiseIgstTotal),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800),
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
                                            color: Color(0xFF16A34A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )),
                    ))
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
            'Rows: ${groupedRows.length} | Group By: ${_groupBy == 'ITEM' ? 'Item Wise' : _groupBy == 'GROUP' ? 'Group Wise' : _groupBy == 'BRAND' ? 'Brand Wise' : 'Subcategory Wise'} | Sales: ${_gstFilter == 'ALL' ? 'All Sales' : _gstFilter == 'B2B_ONLY' ? 'B2B Only' : 'B2C Only'}',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: groupedRows.isEmpty
                ? const Center(
                    child: Text(
                        'No item sales rows found for the selected range.'),
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
                            constraints: const BoxConstraints(minWidth: 2000),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                const Color(0xFFF8FAFC),
                              ),
                              dataRowMinHeight: 52,
                              dataRowMaxHeight: 68,
                              columns: [
                                const DataColumn(label: Text('Label')),
                                if (_groupBy == 'ITEM')
                                  const DataColumn(label: Text('Brand')),
                                const DataColumn(label: Text('HSN/SAC')),
                                const DataColumn(label: Text('Rows')),
                                const DataColumn(label: Text('Qty')),
                                const DataColumn(label: Text('Unit')),
                                const DataColumn(label: Text('Payment')),
                                const DataColumn(label: Text('Subtotal')),
                                const DataColumn(label: Text('Discount')),
                                const DataColumn(label: Text('Taxed Sales')),
                                const DataColumn(label: Text('Non-Tax Sales')),
                                const DataColumn(label: Text('Taxable Value')),
                                const DataColumn(label: Text('CGST')),
                                const DataColumn(label: Text('SGST')),
                                const DataColumn(label: Text('IGST')),
                                const DataColumn(label: Text('Total Sales')),
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
                                      if (_groupBy == 'ITEM')
                                        DataCell(Text(row.brand)),
                                      DataCell(Text(row.hsnSacCode)),
                                      DataCell(Text('${row.lineCount}')),
                                      DataCell(Text(_formatQty(row.quantity))),
                                      DataCell(Text(row.unit)),
                                      DataCell(Text(row.paymentModes.join(', '))),
                                      DataCell(Text(_money(row.subTotal))),
                                      DataCell(Text(_money(row.discount))),
                                      DataCell(
                                        Text(
                                            _money(_itemWiseTaxSaleValue(row))),
                                      ),
                                      DataCell(
                                        Text(_money(
                                            _itemWiseNonTaxSaleValue(row))),
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
                                    if (_groupBy == 'ITEM')
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
                                    const DataCell(Text('')),
                                    DataCell(
                                      Text(
                                        _money(_itemWiseSubTotalTotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _money(_itemWiseDiscountTotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
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

  Widget _buildDateWiseDataTableSection() {
    final rows = _dateWiseSalesRows;
    final taxRates = _availableTaxRates;
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
            'Date Wise Sales Report',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Days: ${rows.length} | Sales: ${_money(_dateWiseNetTotal)}',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child:
                        Text('No date-wise rows found for the selected range.'),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Scrollbar(
                      controller: _dateWiseHorizontalController,
                      thumbVisibility: true,
                      notificationPredicate: (notification) =>
                          notification.metrics.axis == Axis.horizontal,
                      child: SingleChildScrollView(
                        controller: _dateWiseHorizontalController,
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 2000),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              const Color(0xFFF8FAFC),
                            ),
                            columns: [
                              const DataColumn(label: Text('Date')),
                              const DataColumn(label: Text('Bills')),
                              const DataColumn(label: Text('Qty')),
                              const DataColumn(label: Text('Payment')),
                              const DataColumn(label: Text('Subtotal')),
                              const DataColumn(label: Text('Discount')),
                              const DataColumn(label: Text('Charges')),
                              ...taxRates.expand(
                                (rate) => [
                                  DataColumn(
                                      label: Text(
                                          '${_formatTaxPercent(rate)}% Sale')),
                                  if (rate > 0.009)
                                    DataColumn(
                                        label: Text(
                                            '${_formatTaxPercent(rate)}% GST')),
                                ],
                              ),
                              const DataColumn(label: Text('IGST')),
                              const DataColumn(label: Text('Tax')),
                              const DataColumn(label: Text('Net Amount')),
                            ],
                            rows: [
                              ...rows.map(
                                (row) => DataRow(
                                  cells: [
                                    DataCell(
                                      Text(DateFormat('dd-MM-yyyy')
                                          .format(row.date)),
                                    ),
                                    DataCell(Text('${row.bills}')),
                                    DataCell(Text(_formatQty(row.qty))),
                                    DataCell(Text(row.paymentModes.join(', '))),
                                    DataCell(Text(_money(row.subTotal))),
                                    DataCell(Text(_money(row.discount))),
                                    DataCell(Text(_money(row.chargeTotal))),
                                    ...taxRates.expand(
                                      (rate) => [
                                        DataCell(Text(_money(
                                            _bandTaxable(row.taxBands, rate)))),
                                        if (rate > 0.009)
                                          DataCell(Text(_money(
                                              _bandTax(row.taxBands, rate)))),
                                      ],
                                    ),
                                    DataCell(Text(_money(row.igstAmount))),
                                    DataCell(Text(_money(row.taxAmount))),
                                    DataCell(
                                      Text(
                                        _money(row.netAmount),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataRow(
                                color: WidgetStateProperty.all(
                                    const Color(0xFFF8FAFC)),
                                cells: [
                                  const DataCell(
                                    Text('TOTAL',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  DataCell(
                                    Text('$_dateWiseBillsTotal',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  DataCell(
                                    Text(_formatQty(_dateWiseQtyTotal),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  const DataCell(Text('')),
                                  DataCell(
                                    Text(
                                      _money(_dateWiseSubTotalTotal),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _money(_dateWiseDiscountTotal),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _money(_dateWiseChargeTotalTotal),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  ...taxRates.expand(
                                    (rate) => [
                                      DataCell(
                                        Text(
                                          _money(_dateWiseTaxBandsTotal[rate]
                                                  ?.taxableValue ??
                                              0),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      if (rate > 0.009)
                                        DataCell(
                                          Text(
                                            _money(_dateWiseTaxBandsTotal[rate]
                                                    ?.taxAmount ??
                                                0),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                    ],
                                  ),
                                  DataCell(
                                    Text(
                                      _money(_dateWiseIgstTotal),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  DataCell(
                                    Text(_money(_dateWiseTaxTotal),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  DataCell(
                                    Text(_money(_dateWiseNetTotal),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF16A34A))),
                                  ),
                                ],
                              ),
                            ],
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

  Widget _buildGstr1Section() {
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
            'GSTR-1 Sales Register',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Rows: ${_rows.length} | Filter: ${_gstFilter == 'ALL' ? 'All Sales' : _gstFilter == 'B2B_ONLY' ? 'B2B Only' : 'B2C Only'}',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _rows.isEmpty
                ? const Center(
                    child: Text('No GSTR-1 rows found for the selected range.'))
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

  Widget _buildGstr2Section() {
    final rows = _gstr2Rows;
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
            'GSTR-2 Purchase Register',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Bills: $_gstr2BillCount | Rows: ${rows.length} | Taxable: ${_money(_gstr2TaxableTotal)}',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text(
                      'No purchase rows found for the selected range.',
                    ),
                  )
                : Scrollbar(
                    controller: _gstr2VerticalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _gstr2VerticalController,
                      primary: false,
                      scrollDirection: Axis.vertical,
                      child: Scrollbar(
                        controller: _gstr2HorizontalController,
                        thumbVisibility: true,
                        notificationPredicate: (notification) =>
                            notification.metrics.axis == Axis.horizontal,
                        child: SingleChildScrollView(
                          controller: _gstr2HorizontalController,
                          primary: false,
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 1600),
                            child: SingleChildScrollView(
                              primary: false,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                    const Color(0xFFF8FAFC)),
                                dataRowMinHeight: 52,
                                dataRowMaxHeight: 68,
                                columns: const [
                                  DataColumn(label: Text('Date')),
                                  DataColumn(label: Text('GRN No')),
                                  DataColumn(label: Text('Bill No')),
                                  DataColumn(label: Text('Supplier')),
                                  DataColumn(label: Text('GSTIN')),
                                  DataColumn(label: Text('State')),
                                  DataColumn(label: Text('Items')),
                                  DataColumn(label: Text('Qty')),
                                  DataColumn(label: Text('Taxable Value')),
                                  DataColumn(label: Text('GST Amount')),
                                  DataColumn(label: Text('Net Amount')),
                                  DataColumn(label: Text('Paid')),
                                  DataColumn(label: Text('Outstanding')),
                                  DataColumn(label: Text('Status')),
                                ],
                                rows: rows
                                    .map(
                                      (row) => DataRow(
                                        cells: [
                                          DataCell(Text(DateFormat('dd-MM-yyyy')
                                              .format(row.invoiceDate))),
                                          DataCell(Text(row.grnNo.isEmpty
                                              ? '-'
                                              : row.grnNo)),
                                          DataCell(Text(row.billNo.isEmpty
                                              ? '-'
                                              : row.billNo)),
                                          DataCell(SizedBox(
                                            width: 180,
                                            child: Text(
                                              row.supplier,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          )),
                                          DataCell(Text(
                                              row.supplierGstin.isEmpty
                                                  ? 'B2B/B2C'
                                                  : row.supplierGstin)),
                                          DataCell(Text(
                                              row.supplierState.isEmpty
                                                  ? '-'
                                                  : row.supplierState)),
                                          DataCell(Text('${row.itemCount}')),
                                          DataCell(Text(_formatQty(row.qty))),
                                          DataCell(
                                              Text(_money(row.taxableValue))),
                                          DataCell(Text(_money(row.taxAmount))),
                                          DataCell(
                                              Text(_money(row.totalAfterTax))),
                                          DataCell(
                                              Text(_money(row.paidAmount))),
                                          DataCell(Text(
                                              _money(row.outstandingAmount))),
                                          DataCell(Text(row.billStatus)),
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
          ),
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

    if (sale.billingTaxMode != 'IGST' && propertyCtrl.data?.state != null) {
      final stateName = propertyCtrl.data!.state!;
      final stateCode = _stateCodes[stateName.toLowerCase()] ?? '--';
      return '${_titleCase(stateName)} / $stateCode';
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
  final String brand;
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
  final String paymentMode;
  final double discount;
  final double subTotal;

  const _GstSalesRow({
    required this.invoiceDate,
    required this.invoiceNumber,
    required this.customerName,
    required this.customerGstin,
    required this.placeOfSupply,
    required this.itemDescription,
    required this.itemGroup,
    required this.subCategory,
    required this.brand,
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
    required this.paymentMode,
    required this.discount,
    required this.subTotal,
  });
}

class _GroupedSalesRow {
  final String label;
  final String itemGroup;
  final String subCategory;
  final String brand;
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
  final Set<String> paymentModes;
  final double discount;
  final double subTotal;

  const _GroupedSalesRow({
    required this.label,
    required this.itemGroup,
    required this.subCategory,
    required this.brand,
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
    required this.paymentModes,
    required this.discount,
    required this.subTotal,
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
    Set<String>? paymentModes,
    double? discount,
    double? subTotal,
  }) {
    return _GroupedSalesRow(
      label: label,
      itemGroup: itemGroup,
      subCategory: subCategory,
      brand: brand,
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
      paymentModes: paymentModes ?? this.paymentModes,
      discount: discount ?? this.discount,
      subTotal: subTotal ?? this.subTotal,
    );
  }
}

class _TaxBandSummary {
  double taxableValue;
  double taxAmount;

  _TaxBandSummary({
    this.taxableValue = 0,
    this.taxAmount = 0,
  });
}

class _DateWiseSalesRow {
  final DateTime date;
  final int bills;
  final double qty;
  final Map<double, _TaxBandSummary> taxBands;
  final double igstAmount;
  final double taxAmount;
  final double netAmount;
  final Set<String> paymentModes;
  final double subTotal;
  final double discount;
  final double chargeTotal;

  const _DateWiseSalesRow({
    required this.date,
    required this.bills,
    required this.qty,
    required this.taxBands,
    required this.igstAmount,
    required this.taxAmount,
    required this.netAmount,
    required this.paymentModes,
    required this.subTotal,
    required this.discount,
    required this.chargeTotal,
  });

  _DateWiseSalesRow copyWith({
    int? bills,
    double? qty,
    Map<double, _TaxBandSummary>? taxBands,
    double? igstAmount,
    double? taxAmount,
    double? netAmount,
    Set<String>? paymentModes,
    double? subTotal,
    double? discount,
    double? chargeTotal,
  }) {
    return _DateWiseSalesRow(
      date: date,
      bills: bills ?? this.bills,
      qty: qty ?? this.qty,
      taxBands: taxBands ?? this.taxBands,
      igstAmount: igstAmount ?? this.igstAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      netAmount: netAmount ?? this.netAmount,
      paymentModes: paymentModes ?? this.paymentModes,
      subTotal: subTotal ?? this.subTotal,
      discount: discount ?? this.discount,
      chargeTotal: chargeTotal ?? this.chargeTotal,
    );
  }
}

class _Gstr2Row {
  final DateTime invoiceDate;
  final String grnNo;
  final String billNo;
  final String supplier;
  final String supplierGstin;
  final String supplierState;
  final String billStatus;
  final double paidAmount;
  final double outstandingAmount;
  final double taxableValue;
  final double taxAmount;
  final double totalAfterTax;
  final int billCount;
  final int itemCount;
  final double qty;

  const _Gstr2Row({
    required this.invoiceDate,
    required this.grnNo,
    required this.billNo,
    required this.supplier,
    required this.supplierGstin,
    required this.supplierState,
    required this.billStatus,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.taxableValue,
    required this.taxAmount,
    required this.totalAfterTax,
    required this.billCount,
    required this.itemCount,
    required this.qty,
  });

  _Gstr2Row copyWith({
    DateTime? invoiceDate,
    String? grnNo,
    String? billNo,
    String? supplier,
    String? supplierGstin,
    String? supplierState,
    String? billStatus,
    double? paidAmount,
    double? outstandingAmount,
    double? taxableValue,
    double? taxAmount,
    double? totalAfterTax,
    int? billCount,
    int? itemCount,
    double? qty,
  }) {
    return _Gstr2Row(
      invoiceDate: invoiceDate ?? this.invoiceDate,
      grnNo: grnNo ?? this.grnNo,
      billNo: billNo ?? this.billNo,
      supplier: supplier ?? this.supplier,
      supplierGstin: supplierGstin ?? this.supplierGstin,
      supplierState: supplierState ?? this.supplierState,
      billStatus: billStatus ?? this.billStatus,
      paidAmount: paidAmount ?? this.paidAmount,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      taxableValue: taxableValue ?? this.taxableValue,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAfterTax: totalAfterTax ?? this.totalAfterTax,
      billCount: billCount ?? this.billCount,
      itemCount: itemCount ?? this.itemCount,
      qty: qty ?? this.qty,
    );
  }
}

class _GstSummary {
  final double taxableValue;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalRevenue;
  final double billDiscount;
  final double chargeTotal;

  const _GstSummary({
    this.taxableValue = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.totalRevenue = 0,
    this.billDiscount = 0,
    this.chargeTotal = 0,
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

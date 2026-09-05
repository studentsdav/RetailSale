import 'dart:convert';
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
import '../../controllers/sales/sales_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../models/reports/sales_report_model.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class PaymentBreakdownRow {
  final DateTime saleDate;
  final String saleNo;
  final String paymentMode;
  final double taxedSales;
  final double nonTaxSales;
  final double tax;
  final double netAmount;

  PaymentBreakdownRow({
    required this.saleDate,
    required this.saleNo,
    required this.paymentMode,
    required this.taxedSales,
    required this.nonTaxSales,
    required this.tax,
    required this.netAmount,
  });
}

class PivotedBillPaymentRow {
  final DateTime saleDate;
  final String saleNo;
  final Map<String, double> modeAmounts;
  final double netAmount;

  PivotedBillPaymentRow({
    required this.saleDate,
    required this.saleNo,
    required this.modeAmounts,
    required this.netAmount,
  });
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
  String _gstr1SubTab = 'REGISTER';
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
    'Invoice Value',
    'Place of Supply (State Name/Code)',
    'Item Description',
    'HSN/SAC Code',
    'Quantity & UQC (Unit)',
    'Taxable Value',
    'CGST Amount',
    'SGST/UTGST Amount',
    'IGST Amount',
    'Total Line Value',
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

  List<String> _masterPaymentMethods = [];

  Future<void> _loadMasterPaymentMethods() async {
    try {
      final methods = await SalesController().listPaymentMethods();
      final activeList = methods
          .where((m) => m['is_active'] != false)
          .map((m) => (m['name'] ?? m['method_name'] ?? '').toString().trim().toUpperCase())
          .where((name) => name.isNotEmpty)
          .toList();
      if (mounted) {
        setState(() {
          _masterPaymentMethods = activeList;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadReports() async {
    purchaseCtrl.fromDate = ctrl.fromDate;
    purchaseCtrl.toDate = ctrl.toDate;
    await Future.wait([
      ctrl.load().catchError((_) {}),
      purchaseCtrl.load().catchError((_) {}),
      _loadMasterPaymentMethods().catchError((_) {}),
    ]);
    if (mounted) setState(() {});
  }

  Future<void> _reloadReports() async {
    _syncDates();
    await _loadReports();
  }

  bool _isTaxedItem(SalesReportItem item) {
    if (item.taxAmount > 0.009 || item.taxableAmount > 0.009) return true;
    if (item.taxPercent > 0.009) return true;
    if (item.taxBreakup.any((t) => t.rate > 0 || t.taxAmount.abs() > 0.009)) return true;
    return false;
  }

  bool _isTaxedSale(SalesReport sale) {
    if (sale.totalTax > 0.009) return true;
    return sale.items.any(_isTaxedItem);
  }

  double _normalizeTaxRate(double rate) {
    return double.parse(rate.toStringAsFixed(2));
  }

  double _itemTaxRate(SalesReportItem item) {
    double rate = item.taxBreakup.fold<double>(0, (sum, tax) => sum + tax.rate);
    if (rate <= 0.009) {
      rate = item.taxPercent;
    }
    if (rate <= 0.009 && item.taxAmount > 0.009 && item.taxableAmount > 0.009) {
      rate = (item.taxAmount / item.taxableAmount) * 100;
    }
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
        final itemTaxable = _isTaxedItem(item) ? item.taxableAmount : 0.0;
        double cgst = _taxAmountFor(item, 'CGST');
        double sgst = _taxAmountFor(item, 'SGST');
        double igst = _taxAmountFor(item, 'IGST');
        if (item.taxAmount > 0.009 && ((cgst + sgst + igst) - item.taxAmount).abs() > 0.01) {
          if (igst > 0.009) {
            igst = item.taxAmount;
            cgst = 0;
            sgst = 0;
          } else {
            cgst = item.taxAmount / 2;
            sgst = item.taxAmount / 2;
            igst = 0;
          }
        }
        final double effectiveDiscount = item.lineDiscount;
        final double grossMinusDiscount = (item.amount - effectiveDiscount).clamp(0.0, double.infinity);
        final double itemNetVal;
        if (item.netAmount > 0.009) {
          itemNetVal = item.netAmount;
        } else if (effectiveDiscount > 0.009 || grossMinusDiscount <= 0.009) {
          itemNetVal = grossMinusDiscount;
        } else if (itemTaxable + cgst + sgst + igst > 0.009) {
          itemNetVal = itemTaxable + cgst + sgst + igst;
        } else {
          itemNetVal = item.amount;
        }
        final lineVal = _isTaxedItem(item)
            ? (itemTaxable + cgst + sgst + igst)
            : itemNetVal;

        flattened.add(
          _GstSalesRow(
            invoiceDate: sale.saleDate,
            invoiceNumber: sale.saleNo,
            customerName: sale.customerName.trim().isEmpty
                ? 'Walk-in Customer'
                : sale.customerName.trim(),
            customerGstin: customerGstin,
            invoiceValue: sale.netAmount,
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
            taxableValue: itemTaxable,
            taxSaleValue: _isTaxedItem(item) ? itemNetVal : 0,
            nonTaxSaleValue: _isTaxedItem(item) ? 0 : itemNetVal,
            cgstAmount: cgst,
            sgstAmount: sgst,
            igstAmount: igst,
            totalLineValue: lineVal,
            totalInvoiceValue: itemNetVal,
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

  List<_Gstr1B2bRow> get _gstr1B2bRows {
    final rows = <_Gstr1B2bRow>[];
    for (final sale in _billWiseSales) {
      if (sale.customerGstin.trim().isEmpty) continue;
      final placeOfSupply = _derivePlaceOfSupply(sale);
      final isIgst = sale.igstAmount > 0.009;

      final rateGroups = <double, _TaxBandSummary>{};
      for (final item in sale.items) {
        if (!_isTaxedItem(item)) continue;
        final r = _itemTaxRate(item);
        final current = rateGroups[r] ?? _TaxBandSummary();
        current.taxableValue += item.taxableAmount;
        current.taxAmount += item.taxAmount;
        rateGroups[r] = current;
      }
      for (final charge in sale.charges) {
        if (charge.amount <= 0 || !charge.taxable) continue;
        final r = _normalizeTaxRate(charge.taxPercent);
        final current = rateGroups[r] ?? _TaxBandSummary();
        current.taxableValue += charge.amount;
        current.taxAmount += charge.taxAmount;
        rateGroups[r] = current;
      }

      for (final entry in rateGroups.entries) {
        final rate = entry.key;
        final taxable = entry.value.taxableValue;
        final tax = entry.value.taxAmount;
        final cgst = isIgst ? 0.0 : tax / 2;
        final sgst = isIgst ? 0.0 : tax / 2;
        final igst = isIgst ? tax : 0.0;

        rows.add(
          _Gstr1B2bRow(
            customerGstin: sale.customerGstin.trim(),
            customerName: sale.customerName.trim().isEmpty
                ? 'B2B Customer'
                : sale.customerName.trim(),
            invoiceNumber: sale.saleNo,
            invoiceDate: sale.saleDate,
            invoiceValue: sale.netAmount,
            placeOfSupply: placeOfSupply,
            reverseCharge: 'N',
            invoiceType: 'Regular',
            rate: rate,
            taxableValue: taxable,
            cgst: cgst,
            sgst: sgst,
            igst: igst,
          ),
        );
      }
    }
    return rows;
  }

  List<_Gstr1B2csRow> get _gstr1B2csRows {
    final grouped = <String, _Gstr1B2csRow>{};
    for (final sale in _billWiseSales) {
      if (sale.customerGstin.trim().isNotEmpty) continue;
      final pos = _derivePlaceOfSupply(sale);
      final isIgst = sale.igstAmount > 0.009;

      for (final item in sale.items) {
        final rate = _normalizeTaxRate(_isTaxedItem(item) ? _itemTaxRate(item) : 0.0);
        final taxable = _isTaxedItem(item) ? item.taxableAmount : item.netAmount;
        final tax = _isTaxedItem(item) ? item.taxAmount : 0.0;
        final cgst = isIgst ? 0.0 : tax / 2;
        final sgst = isIgst ? 0.0 : tax / 2;
        final igst = isIgst ? tax : 0.0;

        final key = '$pos|${_formatTaxPercent(rate)}';
        final current = grouped[key];
        if (current == null) {
          grouped[key] = _Gstr1B2csRow(
            type: 'OE',
            placeOfSupply: pos,
            rate: rate,
            taxableValue: taxable,
            cgst: cgst,
            sgst: sgst,
            igst: igst,
          );
        } else {
          grouped[key] = current.copyWith(
            taxableValue: current.taxableValue + taxable,
            cgst: current.cgst + cgst,
            sgst: current.sgst + sgst,
            igst: current.igst + igst,
          );
        }
      }
      for (final charge in sale.charges) {
        if (charge.amount <= 0) continue;
        final rate = _normalizeTaxRate(charge.taxable ? charge.taxPercent : 0.0);
        final taxable = charge.amount;
        final tax = charge.taxable ? charge.taxAmount : 0.0;
        final cgst = isIgst ? 0.0 : tax / 2;
        final sgst = isIgst ? 0.0 : tax / 2;
        final igst = isIgst ? tax : 0.0;

        final key = '$pos|${_formatTaxPercent(rate)}';
        final current = grouped[key];
        if (current == null) {
          grouped[key] = _Gstr1B2csRow(
            type: 'OE',
            placeOfSupply: pos,
            rate: rate,
            taxableValue: taxable,
            cgst: cgst,
            sgst: sgst,
            igst: igst,
          );
        } else {
          grouped[key] = current.copyWith(
            taxableValue: current.taxableValue + taxable,
            cgst: current.cgst + cgst,
            sgst: current.sgst + sgst,
            igst: current.igst + igst,
          );
        }
      }
    }
    return grouped.values.toList()
      ..sort((a, b) => a.placeOfSupply.compareTo(b.placeOfSupply));
  }

  List<_Gstr1HsnRow> get _gstr1HsnRows {
    final grouped = <String, _Gstr1HsnRow>{};
    for (final sale in _billWiseSales) {
      final isIgst = sale.igstAmount > 0.009;
      for (final item in sale.items) {
        final code =
            item.hsnSacCode.trim().isEmpty ? 'NA' : item.hsnSacCode.trim();
        final desc = item.itemName.trim();
        final unit = item.unit.trim().isEmpty ? 'NOS' : item.unit.trim();
        final taxable = _isTaxedItem(item) ? item.taxableAmount : item.netAmount;
        final tax = _isTaxedItem(item) ? item.taxAmount : 0.0;
        final cgst = isIgst ? 0.0 : tax / 2;
        final sgst = isIgst ? 0.0 : tax / 2;
        final igst = isIgst ? tax : 0.0;
        final totalVal = taxable + tax;

        final key = '$code|$unit';
        final current = grouped[key];
        if (current == null) {
          grouped[key] = _Gstr1HsnRow(
            hsnSacCode: code,
            description: desc,
            unit: unit,
            totalQty: item.qty,
            totalValue: totalVal,
            taxableValue: taxable,
            cgst: cgst,
            sgst: sgst,
            igst: igst,
          );
        } else {
          grouped[key] = current.copyWith(
            totalQty: current.totalQty + item.qty,
            totalValue: current.totalValue + totalVal,
            taxableValue: current.taxableValue + taxable,
            cgst: current.cgst + cgst,
            sgst: current.sgst + sgst,
            igst: current.igst + igst,
          );
        }
      }
      for (final charge in sale.charges) {
        if (charge.amount <= 0) continue;
        final code =
            charge.code.trim().isNotEmpty ? charge.code.trim() : 'SAC 9968';
        final desc =
            charge.name.trim().isEmpty ? 'Delivery Charge' : charge.name.trim();
        final unit = 'NOS';
        final taxable = charge.amount;
        final tax = charge.taxable ? charge.taxAmount : 0.0;
        final cgst = isIgst ? 0.0 : tax / 2;
        final sgst = isIgst ? 0.0 : tax / 2;
        final igst = isIgst ? tax : 0.0;
        final totalVal = taxable + tax;

        final key = '$code|$unit';
        final current = grouped[key];
        if (current == null) {
          grouped[key] = _Gstr1HsnRow(
            hsnSacCode: code,
            description: desc,
            unit: unit,
            totalQty: 1,
            totalValue: totalVal,
            taxableValue: taxable,
            cgst: cgst,
            sgst: sgst,
            igst: igst,
          );
        } else {
          grouped[key] = current.copyWith(
            totalQty: current.totalQty + 1,
            totalValue: current.totalValue + totalVal,
            taxableValue: current.taxableValue + taxable,
            cgst: current.cgst + cgst,
            sgst: current.sgst + sgst,
            igst: current.igst + igst,
          );
        }
      }
    }
    return grouped.values.toList()
      ..sort((a, b) => a.hsnSacCode.compareTo(b.hsnSacCode));
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

  // Non-Tax Sales: sum of item line amounts for zero-tax items (bill-level)
  double get _nonTaxSaleTotal => _billWiseSales.fold<double>(
      0,
      (sum, sale) => sum + sale.items.fold<double>(
            0,
            (itemSum, item) {
              if (_isTaxedItem(item)) return itemSum;
              final disc = item.lineDiscount;
              final grossMinusDisc = (item.amount - disc).clamp(0.0, double.infinity);
              final net = item.netAmount > 0.009
                  ? item.netAmount
                  : ((disc > 0.009 || grossMinusDisc <= 0.009) ? grossMinusDisc : item.amount);
              return itemSum + net;
            },
          ));

  // Taxed Sales After GST = Net Sales (Standard) − Non-Tax Sales
  // Computed at bill level for consistency with discount allocation
  double get _taxSaleTotal => _headerItemNetAmount - _nonTaxSaleTotal;
  double get _headerTaxableTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + _taxableSaleValue(sale));
  // All figures from header-level columns (consistent with DB, dashboard, and payment breakdown)
  double get _headerCgstTotal => _billWiseSales.fold<double>(
        0,
        (sum, sale) => sum + sale.items.fold<double>(0, (s, item) => s + _taxAmountFor(item, 'CGST')),
      );
  double get _headerSgstTotal => _billWiseSales.fold<double>(
        0,
        (sum, sale) => sum + sale.items.fold<double>(0, (s, item) => s + _taxAmountFor(item, 'SGST')),
      );
  double get _headerIgstTotal => _billWiseSales.fold<double>(
        0,
        (sum, sale) => sum + sale.items.fold<double>(0, (s, item) => s + _taxAmountFor(item, 'IGST')),
      );
  double get _headerDiscountTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.totalDiscount);
  double get _headerChargeTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.chargeTotal);
  double _saleItemTaxTotal(SalesReport sale) => sale.items.fold<double>(
        0,
        (sum, item) => sum + item.taxAmount,
      );
  double _saleChargeTaxTotal(SalesReport sale) => sale.chargeTaxTotal;
  double _saleTotalTax(SalesReport sale) =>
      _saleItemTaxTotal(sale) + _saleChargeTaxTotal(sale);

  // Total tax across all bills (Items GST + Charges GST)
  double get _headerTaxTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.totalTax);
  double get _headerChargeTaxTotal => _billWiseSales.fold<double>(
        0,
        (sum, sale) => sum + _saleChargeTaxTotal(sale),
      );
  double get _headerItemTaxTotal => _headerTaxTotal - _headerChargeTaxTotal;
  // Total Revenue = sum of header net_amount (matches payment breakdown)
  double get _headerRevenueTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.netAmount);
  // Net Sales = Revenue − Charges − ChargesGST
  double get _headerItemNetAmount =>
      _headerRevenueTotal - _headerChargeTotal - _headerChargeTaxTotal;
  // Item-level taxable for Taxable Value card only
  double get _headerItemTaxableTotal => _billWiseSales.fold<double>(
        0,
        (sum, sale) => sum + sale.items.fold<double>(0, (s, item) => s + item.taxableAmount),
      );

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
      _billWiseSales.fold<double>(0, (sum, sale) => sum + _saleTotalTax(sale));
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
  double get _billWiseCashTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.cashAmount);
  double get _billWiseCardTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.cardAmount);
  double get _billWiseUpiTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.upiAmount);
  double get _billWiseOtherTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.otherAmount);
  double get _billWiseAdvAddedTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.advanceAmount);
  double get _billWiseAdvDepositTotal => _billWiseAdvAddedTotal;
  double get _billWiseAdvAdjTotal =>
      _billWiseSales.fold<double>(0, (sum, sale) => sum + sale.advanceAdjustmentAmount);
  double get _billWiseAdvAdjustedTotal => _billWiseAdvAdjTotal;

  int get _paymentWiseCountTotal =>
      ctrl.paymentModes.fold<int>(0, (sum, entry) => sum + entry.count);
  double get _paymentWiseAmountTotal =>
      ctrl.paymentModes.fold<double>(0, (sum, entry) => sum + entry.amount);
  List<Map<String, dynamic>> _extractPaymentSplits(SalesReport sale) {
    final List<Map<String, dynamic>> splits = [];
    if (sale.paymentReference.startsWith('POSPAY:')) {
      try {
        final decoded = jsonDecode(sale.paymentReference.substring(7));
        if (decoded is List) {
          for (final row in decoded) {
            final mode = (row['method'] ?? 'CASH').toString().toUpperCase();
            final amt = double.tryParse(row['amount']?.toString() ?? '') ?? 0;
            if (amt > 0.009) {
              splits.add({'mode': mode, 'amount': amt});
            }
          }
        }
      } catch (_) {}
    }

    final double subCoverage = (sale.paymentMode.toUpperCase() != 'SUBSCRIPTION')
        ? (sale.advanceAdjustmentAmount > 0.009
            ? sale.advanceAdjustmentAmount
            : (sale.subscription > 0.009 ? sale.subscription : 0.0))
        : 0.0;

    if (splits.isEmpty) {
      if (sale.cashAmount > 0.009) splits.add({'mode': 'CASH', 'amount': sale.cashAmount});
      if (sale.cardAmount > 0.009) splits.add({'mode': 'CARD', 'amount': sale.cardAmount});
      if (sale.upiAmount > 0.009) splits.add({'mode': 'UPI', 'amount': sale.upiAmount});
      if (sale.otherAmount > 0.009) splits.add({'mode': 'OTHER', 'amount': sale.otherAmount});
      if (sale.advanceAmount > 0.009) splits.add({'mode': 'ADVANCE_DEPOSIT', 'amount': sale.advanceAmount});
      if (sale.advanceAdjustmentAmount > 0.009) splits.add({'mode': 'ADVANCE_ADJUSTMENT', 'amount': sale.advanceAdjustmentAmount});
    }

    if (subCoverage > 0.009) {
      final bool hasSubSplit = splits.any((s) => s['mode'] == 'ADVANCE_ADJUSTMENT' || s['mode'] == 'SUBSCRIPTION');
      if (!hasSubSplit) {
        splits.add({'mode': 'ADVANCE_ADJUSTMENT', 'amount': subCoverage});
        final cashIndex = splits.indexWhere((s) => s['mode'] == 'CASH');
        if (cashIndex != -1) {
          final double curCash = (splits[cashIndex]['amount'] as num).toDouble();
          final double newCash = curCash - subCoverage;
          if (newCash > 0.009) {
            splits[cashIndex]['amount'] = newCash;
          } else {
            splits.removeAt(cashIndex);
          }
        }
      }
    }

    final double targetGrossNet = sale.netAmount;
    final double paidSum = splits.fold<double>(0, (sum, item) => sum + (item['amount'] as double));
    final double rem = targetGrossNet - paidSum;
    if (rem > 0.009) {
      final String mode = (sale.paymentMode.isNotEmpty && sale.paymentMode != 'SPLIT') ? sale.paymentMode : 'CASH';
      splits.add({'mode': mode, 'amount': rem});
    }

    if (splits.isEmpty && targetGrossNet > 0) {
      splits.add({
        'mode': (sale.paymentMode.isNotEmpty && sale.paymentMode != 'SPLIT') ? sale.paymentMode : 'CASH',
        'amount': targetGrossNet
      });
    }

    // Consolidate duplicate mode entries (e.g. CARD 23.50 + CARD 0.10 roundoff) into a single row per payment mode
    final Map<String, double> consolidated = {};
    for (final item in splits) {
      final String m = (item['mode'] ?? 'CASH').toString().toUpperCase();
      final double a = (item['amount'] as num).toDouble();
      consolidated[m] = (consolidated[m] ?? 0.0) + a;
    }
    return consolidated.entries
        .where((e) => e.value.abs() > 0.001)
        .map((e) => {'mode': e.key, 'amount': e.value})
        .toList();
  }

  String _formatPaymentModeHeader(String modeKey) {
    final upper = modeKey.toUpperCase();
    switch (upper) {
      case 'CASH':
        return 'Cash';
      case 'CARD':
        return 'Card';
      case 'UPI':
        return 'UPI';
      case 'CREDIT':
        return 'Credit';
      case 'ADVANCE_DEPOSIT':
        return 'Advance Deposit';
      case 'ADVANCE_ADJUSTMENT':
        return 'Advance Adjustment';
      case 'SUBSCRIPTION':
        return 'Subscription';
      case 'PAYTM':
        return 'Paytm';
      case 'PHONEPE':
        return 'PhonePe';
      case 'GPAY':
      case 'GOOGLE_PAY':
        return 'Google Pay';
      case 'BANK_TRANSFER':
      case 'BANK':
        return 'Bank Transfer';
      default:
        final words = upper.split(RegExp(r'[\s_]+'));
        return words.map((w) => w.isEmpty ? '' : '${w[0]}${w.substring(1).toLowerCase()}').join(' ');
    }
  }

  List<String> get _pivotedPaymentModes {
    final Set<String> modes = {};
    for (final m in _masterPaymentMethods) {
      if (m.isNotEmpty) modes.add(m.toUpperCase());
    }
    for (final sale in _billWiseSales) {
      final splits = _extractPaymentSplits(sale);
      for (final split in splits) {
        final mode = (split['mode'] as String).toUpperCase();
        if ((split['amount'] as double).abs() > 0.009) {
          modes.add(mode);
        }
      }
    }
    final preferredOrder = [
      'CASH',
      'CARD',
      'UPI',
      'CREDIT',
      'ADVANCE_DEPOSIT',
      'ADVANCE_ADJUSTMENT',
      'SUBSCRIPTION'
    ];
    final List<String> sorted = modes.toList();
    sorted.sort((a, b) {
      int idxA = preferredOrder.indexOf(a);
      int idxB = preferredOrder.indexOf(b);
      if (idxA == -1) idxA = 999;
      if (idxB == -1) idxB = 999;
      if (idxA != idxB) return idxA.compareTo(idxB);
      return a.compareTo(b);
    });
    return sorted;
  }

  List<PivotedBillPaymentRow> get _pivotedBillPaymentRows {
    final List<PivotedBillPaymentRow> rows = [];
    for (final sale in _billWiseSales) {
      final splits = _extractPaymentSplits(sale);
      final Map<String, double> modeAmounts = {};
      double totalNet = 0;
      for (final split in splits) {
        final String mode = (split['mode'] as String).toUpperCase();
        final double amt = split['amount'] as double;
        modeAmounts[mode] = (modeAmounts[mode] ?? 0.0) + amt;
        totalNet += amt;
      }
      rows.add(PivotedBillPaymentRow(
        saleDate: sale.saleDate,
        saleNo: sale.saleNo,
        modeAmounts: modeAmounts,
        netAmount: totalNet > 0 ? totalNet : sale.netAmount,
      ));
    }
    return rows;
  }

  List<PaymentBreakdownRow> get _paymentBreakdownRows {
    final List<PaymentBreakdownRow> rows = [];
    for (final sale in _billWiseSales) {
      final splits = _extractPaymentSplits(sale);
      final double totalBillNet = sale.netAmount;
      for (final split in splits) {
        final String mode = split['mode'] as String;
        final double amt = split['amount'] as double;
        final double ratio = totalBillNet > 0 ? (amt / totalBillNet) : 0;

        rows.add(PaymentBreakdownRow(
          saleDate: sale.saleDate,
          saleNo: sale.saleNo,
          paymentMode: mode,
          taxedSales: _billWiseTaxSaleValue(sale) * ratio,
          nonTaxSales: _billWiseNonTaxSaleValue(sale) * ratio,
          tax: sale.totalTax * ratio,
          netAmount: amt,
        ));
      }
    }
    return rows;
  }

  List<Map<String, dynamic>> get _uniquePaymentModeSummaries {
    final Map<String, double> totals = {};
    for (final sale in _billWiseSales) {
      final splits = _extractPaymentSplits(sale);
      for (final split in splits) {
        final mode = (split['mode'] as String).toUpperCase();
        final amt = split['amount'] as double;
        totals[mode] = (totals[mode] ?? 0) + amt;
      }
    }
    if (totals.isEmpty) {
      for (final entry in ctrl.paymentModes) {
        if (entry.amount > 0) {
          totals[entry.key.toUpperCase()] = entry.amount;
        }
      }
    }
    final List<Map<String, dynamic>> list = [];
    totals.forEach((modeKey, amount) {
      if (amount.abs() > 0.009) {
        list.add({
          'key': modeKey,
          'label': _formatPaymentModeHeader(modeKey),
          'amount': amount,
        });
      }
    });
    return list;
  }

  double get _paymentReportTaxSaleTotal => _paymentBreakdownRows.fold<double>(
      0, (sum, row) => sum + row.taxedSales);
  double get _paymentReportNonTaxSaleTotal => _paymentBreakdownRows.fold<double>(
      0, (sum, row) => sum + row.nonTaxSales);
  double get _paymentReportTaxTotal => _paymentBreakdownRows.fold<double>(
      0, (sum, row) => sum + row.tax);
  double get _paymentReportNetTotal => _paymentBreakdownRows.fold<double>(
      0, (sum, row) => sum + row.netAmount);
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
    final rawTaxed = sale.items.fold<double>(
      0,
      (sum, item) => sum + (_isTaxedItem(item) ? item.netAmount : 0),
    );
    final rawNonTax = sale.items.fold<double>(
      0,
      (sum, item) => sum + (_isTaxedItem(item) ? 0 : item.netAmount),
    );
    final rawTotal = rawTaxed + rawNonTax;
    if (rawTotal <= 0.009) return 0;
    return (rawTaxed / rawTotal) * sale.netAmount;
  }

  double _billWiseNonTaxSaleValue(SalesReport sale) {
    final rawTaxed = sale.items.fold<double>(
      0,
      (sum, item) => sum + (_isTaxedItem(item) ? item.netAmount : 0),
    );
    final rawNonTax = sale.items.fold<double>(
      0,
      (sum, item) => sum + (_isTaxedItem(item) ? 0 : item.netAmount),
    );
    final rawTotal = rawTaxed + rawNonTax;
    if (rawTotal <= 0.009) return 0;
    return (rawNonTax / rawTotal) * sale.netAmount;
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
      final taxableValue = (row.gst > 0) ? row.rate * row.qty : 0.0;
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

      double c = sale.cashAmount;
      double cr = sale.cardAmount;
      double u = sale.upiAmount;
      double o = sale.otherAmount;
      final adv = sale.advanceAmount;
      double advAdj = sale.advanceAdjustmentAmount;

      if (advAdj == 0 && sale.subscription > 0) {
        advAdj = sale.subscription;
      }

      final nonSubNet = (sale.netAmount - sale.subscription) > 0.009
          ? (sale.netAmount - sale.subscription)
          : 0.0;

      if (c == 0 && cr == 0 && u == 0 && o == 0 && adv == 0 && (advAdj == 0 || nonSubNet > 0)) {
        final rem = nonSubNet > 0 ? nonSubNet : sale.netAmount;
        final pm = sale.paymentMode.toUpperCase();
        if (pm.contains('CASH')) {
          c = rem;
        } else if (pm.contains('CARD')) {
          cr = rem;
        } else if (pm.contains('UPI')) {
          u = rem;
        } else if (pm.contains('SUBSCRIPTION') || pm.contains('ADVANCE')) {
          advAdj = sale.netAmount;
        } else {
          o = rem;
        }
      }

      if (current == null) {
        grouped[key] = _DateWiseSalesRow(
          date: dateOnly,
          bills: 1,
          qty: sale.totalQty,
          cashAmount: c,
          cardAmount: cr,
          upiAmount: u,
          otherAmount: o,
          advanceAmount: adv,
          advanceAdjustmentAmount: advAdj,
          taxBands: saleBands,
          igstAmount: _saleIgstAmount(sale),
          taxAmount: _saleTotalTax(sale),
          netAmount: sale.netAmount,
          subscription: sale.subscription,
          paymentModes: {sale.paymentMode},
          subTotal: sale.subTotal,
          discount: sale.totalDiscount,
          chargeTotal: sale.chargeTotal,
          chargeTaxTotal: _saleChargeTaxTotal(sale),
        );
      } else {
        grouped[key] = current.copyWith(
          bills: current.bills + 1,
          qty: current.qty + sale.totalQty,
          cashAmount: current.cashAmount + c,
          cardAmount: current.cardAmount + cr,
          upiAmount: current.upiAmount + u,
          otherAmount: current.otherAmount + o,
          advanceAmount: current.advanceAmount + adv,
          advanceAdjustmentAmount: current.advanceAdjustmentAmount + advAdj,
          taxBands: _mergeTaxBands(current.taxBands, saleBands),
          igstAmount: current.igstAmount + _saleIgstAmount(sale),
          taxAmount: current.taxAmount + _saleTotalTax(sale),
          netAmount: current.netAmount + sale.netAmount,
          subscription: current.subscription + sale.subscription,
          paymentModes: Set<String>.from(current.paymentModes)..add(sale.paymentMode),
          subTotal: current.subTotal + sale.subTotal,
          discount: current.discount + sale.totalDiscount,
          chargeTotal: current.chargeTotal + sale.chargeTotal,
          chargeTaxTotal: current.chargeTaxTotal + _saleChargeTaxTotal(sale),
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
  double get _dateWiseCashTotal =>
      _dateWiseSalesRows.fold<double>(0, (sum, row) => sum + row.cashAmount);
  double get _dateWiseCardTotal =>
      _dateWiseSalesRows.fold<double>(0, (sum, row) => sum + row.cardAmount);
  double get _dateWiseUpiTotal =>
      _dateWiseSalesRows.fold<double>(0, (sum, row) => sum + row.upiAmount);
  double get _dateWiseOtherTotal =>
      _dateWiseSalesRows.fold<double>(0, (sum, row) => sum + row.otherAmount);
  double get _dateWiseAdvDepositTotal =>
      _dateWiseSalesRows.fold<double>(0, (sum, row) => sum + row.advanceAmount);
  double get _dateWiseAdvAdjustedTotal =>
      _dateWiseSalesRows.fold<double>(0, (sum, row) => sum + row.advanceAdjustmentAmount);
  double get _dateWiseTaxTotal =>
      _dateWiseSalesRows.fold<double>(0, (sum, row) => sum + row.taxAmount);
  double get _dateWiseSubTotalTotal =>
      _dateWiseSalesRows.fold<double>(0, (sum, row) => sum + row.subTotal);
  double get _dateWiseDiscountTotal =>
      _dateWiseSalesRows.fold<double>(0, (sum, row) => sum + row.discount);
  double get _dateWiseChargeTotalTotal =>
      _dateWiseSalesRows.fold<double>(0, (sum, row) => sum + row.chargeTotal);
  double get _dateWiseChargeTaxTotal =>
      _dateWiseSalesRows.fold<double>(0, (sum, row) => sum + row.chargeTaxTotal);
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
      final modes = _pivotedPaymentModes;
      sheet.appendRow(
        [
          'Date',
          'Bill No',
          ...modes.map(_formatPaymentModeHeader),
          'Net Amount',
        ].map(exc.TextCellValue.new).toList(),
      );
      for (final row in _pivotedBillPaymentRows) {
        sheet.appendRow([
          exc.TextCellValue(DateFormat('dd-MM-yyyy').format(row.saleDate)),
          exc.TextCellValue(_maskedBillNo(row.saleNo)),
          ...modes.map((m) => exc.DoubleCellValue(row.modeAmounts[m] ?? 0.0)),
          exc.DoubleCellValue(row.netAmount),
        ]);
      }
      sheet.appendRow([
        exc.TextCellValue('TOTAL'),
        exc.TextCellValue(''),
        ...modes.map((m) {
          final modeTotal = _pivotedBillPaymentRows.fold<double>(
            0, (sum, r) => sum + (r.modeAmounts[m] ?? 0.0),
          );
          return exc.DoubleCellValue(modeTotal);
        }),
        exc.DoubleCellValue(_paymentReportNetTotal),
      ]);
    } else if (_reportTabIndex == 1) {
      sheet.appendRow(
        [
          'Date',
          'Bill No',
          'Cash',
          'Card',
          'UPI',
          'Other',
          'Adv Deposit',
          'Adv Adjusted',
          'Subtotal',
          'Discount',
          'Charges',
          'Charges GST',
          ...taxRates.expand(
            (rate) => [
              '${_formatTaxPercent(rate)}% Sale',
              if (rate > 0.009) '${_formatTaxPercent(rate)}% GST',
            ],
          ),
          'IGST',
          'Tax',
          'Net Amount',
          'Sub Sale',
          'Net Revenue',
        ].map(exc.TextCellValue.new).toList(),
      );
      for (final sale in _billWiseSales) {
        final bands = _saleTaxBands(sale);
        sheet.appendRow([
          exc.TextCellValue(DateFormat('dd-MM-yyyy').format(sale.saleDate)),
          exc.TextCellValue(_maskedBillNo(sale.saleNo)),
          exc.DoubleCellValue(sale.cashAmount),
          exc.DoubleCellValue(sale.cardAmount),
          exc.DoubleCellValue(sale.upiAmount),
          exc.DoubleCellValue(sale.otherAmount),
          exc.DoubleCellValue(sale.advanceAmount),
          exc.DoubleCellValue(sale.advanceAdjustmentAmount),
          exc.DoubleCellValue(sale.subTotal),
          exc.DoubleCellValue(sale.totalDiscount),
          exc.DoubleCellValue(sale.chargeTotal),
          exc.DoubleCellValue(_saleChargeTaxTotal(sale)),
          ...taxRates.expand(
            (rate) => [
              exc.DoubleCellValue(_bandTaxable(bands, rate)),
              if (rate > 0.009) exc.DoubleCellValue(_bandTax(bands, rate)),
            ],
          ),
          exc.DoubleCellValue(_saleIgstAmount(sale)),
          exc.DoubleCellValue(_saleTotalTax(sale)),
          exc.DoubleCellValue(sale.netAmount),
          exc.DoubleCellValue(sale.subscription),
          exc.DoubleCellValue(sale.netAmount - sale.subscription),
        ]);
      }
      sheet.appendRow([
        exc.TextCellValue('TOTAL'),
        exc.TextCellValue(''),
        exc.DoubleCellValue(_billWiseCashTotal),
        exc.DoubleCellValue(_billWiseCardTotal),
        exc.DoubleCellValue(_billWiseUpiTotal),
        exc.DoubleCellValue(_billWiseOtherTotal),
        exc.DoubleCellValue(_billWiseAdvDepositTotal),
        exc.DoubleCellValue(_billWiseAdvAdjustedTotal),
        exc.DoubleCellValue(_billWiseSubTotalTotal),
        exc.DoubleCellValue(_billWiseDiscountTotal),
        exc.DoubleCellValue(_billWiseChargeTotalTotal),
        exc.DoubleCellValue(_headerChargeTaxTotal),
        ...taxRates.expand(
          (rate) => [
            exc.DoubleCellValue(_billWiseTaxBandsTotal[rate]?.taxableValue ?? 0),
            if (rate > 0.009)
              exc.DoubleCellValue(_billWiseTaxBandsTotal[rate]?.taxAmount ?? 0),
          ],
        ),
        exc.DoubleCellValue(_billWiseIgstTotal),
        exc.DoubleCellValue(_headerTaxTotal),
        exc.DoubleCellValue(_billWiseNetTotal),
        exc.DoubleCellValue(_billWiseSales.fold<double>(0, (sum, s) => sum + s.subscription)),
        exc.DoubleCellValue(_billWiseSales.fold<double>(0, (sum, s) => sum + (s.netAmount - s.subscription))),
      ]);
    } else if (_reportTabIndex == 2) {
      sheet.appendRow(
        [
          'Label',
          'HSN/SAC',
          'Rows',
          'Qty',
          'Unit',
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
    } else if (_reportTabIndex == 3) {
      sheet.appendRow(
        [
          'Date',
          'Bills',
          'Qty',
          'Cash',
          'Card',
          'UPI',
          'Other',
          'Adv Deposit',
          'Adv Adjusted',
          'Subtotal',
          'Discount',
          'Charges',
          'Charges GST',
          ...taxRates.expand(
            (rate) => [
              '${_formatTaxPercent(rate)}% Sale',
              if (rate > 0.009) '${_formatTaxPercent(rate)}% GST',
            ],
          ),
          'IGST',
          'Tax',
          'Net Amount',
          'Sub Sale',
          'Net Revenue',
        ].map(exc.TextCellValue.new).toList(),
      );
      for (final row in _dateWiseSalesRows) {
        sheet.appendRow([
          exc.TextCellValue(DateFormat('dd-MM-yyyy').format(row.date)),
          exc.IntCellValue(row.bills),
          exc.DoubleCellValue(row.qty),
          exc.DoubleCellValue(row.cashAmount),
          exc.DoubleCellValue(row.cardAmount),
          exc.DoubleCellValue(row.upiAmount),
          exc.DoubleCellValue(row.otherAmount),
          exc.DoubleCellValue(row.advanceAmount),
          exc.DoubleCellValue(row.advanceAdjustmentAmount),
          exc.DoubleCellValue(row.subTotal),
          exc.DoubleCellValue(row.discount),
          exc.DoubleCellValue(row.chargeTotal),
          exc.DoubleCellValue(row.chargeTaxTotal),
          ...taxRates.expand(
            (rate) => [
              exc.DoubleCellValue(_bandTaxable(row.taxBands, rate)),
              if (rate > 0.009) exc.DoubleCellValue(_bandTax(row.taxBands, rate)),
            ],
          ),
          exc.DoubleCellValue(row.igstAmount),
          exc.DoubleCellValue(row.taxAmount),
          exc.DoubleCellValue(row.netAmount),
          exc.DoubleCellValue(row.subscription),
          exc.DoubleCellValue(row.netAmount - row.subscription),
        ]);
      }
      sheet.appendRow([
        exc.TextCellValue('TOTAL'),
        exc.IntCellValue(_dateWiseBillsTotal),
        exc.DoubleCellValue(_dateWiseQtyTotal),
        exc.DoubleCellValue(_dateWiseCashTotal),
        exc.DoubleCellValue(_dateWiseCardTotal),
        exc.DoubleCellValue(_dateWiseUpiTotal),
        exc.DoubleCellValue(_dateWiseOtherTotal),
        exc.DoubleCellValue(_dateWiseAdvDepositTotal),
        exc.DoubleCellValue(_dateWiseAdvAdjustedTotal),
        exc.DoubleCellValue(_dateWiseSubTotalTotal),
        exc.DoubleCellValue(_dateWiseDiscountTotal),
        exc.DoubleCellValue(_dateWiseChargeTotalTotal),
        exc.DoubleCellValue(_dateWiseChargeTaxTotal),
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
        exc.DoubleCellValue(_dateWiseSalesRows.fold<double>(0, (sum, r) => sum + r.subscription)),
        exc.DoubleCellValue(_dateWiseSalesRows.fold<double>(0, (sum, r) => sum + (r.netAmount - r.subscription))),
      ]);
    } else if (_reportTabIndex == 4) {
      // 1. b2b Sheet (GST Portal Table 4)
      final sheetB2b = workbook['b2b'];
      sheetB2b.appendRow([
        exc.TextCellValue('GSTIN/UIN of Recipient'),
        exc.TextCellValue('Receiver Name'),
        exc.TextCellValue('Invoice Number'),
        exc.TextCellValue('Invoice Date'),
        exc.TextCellValue('Invoice Value'),
        exc.TextCellValue('Place Of Supply'),
        exc.TextCellValue('Reverse Charge'),
        exc.TextCellValue('Applicable % of Tax Rate'),
        exc.TextCellValue('Invoice Type'),
        exc.TextCellValue('E-Commerce GSTIN'),
        exc.TextCellValue('Rate'),
        exc.TextCellValue('Taxable Value'),
        exc.TextCellValue('Cess Amount'),
        exc.TextCellValue('Integrated Tax'),
        exc.TextCellValue('Central Tax'),
        exc.TextCellValue('State/UT Tax'),
      ]);
      for (final r in _gstr1B2bRows) {
        sheetB2b.appendRow([
          exc.TextCellValue(r.customerGstin),
          exc.TextCellValue(r.customerName),
          exc.TextCellValue(r.invoiceNumber),
          exc.TextCellValue(DateFormat('dd-MM-yyyy').format(r.invoiceDate)),
          exc.DoubleCellValue(r.invoiceValue),
          exc.TextCellValue(r.placeOfSupply),
          exc.TextCellValue(r.reverseCharge),
          exc.TextCellValue(''),
          exc.TextCellValue(r.invoiceType),
          exc.TextCellValue(''),
          exc.DoubleCellValue(r.rate),
          exc.DoubleCellValue(r.taxableValue),
          exc.DoubleCellValue(0.0),
          exc.DoubleCellValue(r.igst),
          exc.DoubleCellValue(r.cgst),
          exc.DoubleCellValue(r.sgst),
        ]);
      }

      // 2. b2cs Sheet (GST Portal Table 7)
      final sheetB2cs = workbook['b2cs'];
      sheetB2cs.appendRow([
        exc.TextCellValue('Type'),
        exc.TextCellValue('Place Of Supply'),
        exc.TextCellValue('Applicable % of Tax Rate'),
        exc.TextCellValue('Rate'),
        exc.TextCellValue('Taxable Value'),
        exc.TextCellValue('Cess Amount'),
        exc.TextCellValue('Central Tax'),
        exc.TextCellValue('State/UT Tax'),
        exc.TextCellValue('Integrated Tax'),
      ]);
      for (final r in _gstr1B2csRows) {
        sheetB2cs.appendRow([
          exc.TextCellValue(r.type),
          exc.TextCellValue(r.placeOfSupply),
          exc.TextCellValue(''),
          exc.DoubleCellValue(r.rate),
          exc.DoubleCellValue(r.taxableValue),
          exc.DoubleCellValue(0.0),
          exc.DoubleCellValue(r.cgst),
          exc.DoubleCellValue(r.sgst),
          exc.DoubleCellValue(r.igst),
        ]);
      }

      // 3. hsn Sheet (GST Portal Table 12)
      final sheetHsn = workbook['hsn'];
      sheetHsn.appendRow([
        exc.TextCellValue('HSN'),
        exc.TextCellValue('Description'),
        exc.TextCellValue('UQC'),
        exc.TextCellValue('Total Quantity'),
        exc.TextCellValue('Total Value'),
        exc.TextCellValue('Taxable Value'),
        exc.TextCellValue('Integrated Tax Amount'),
        exc.TextCellValue('Central Tax Amount'),
        exc.TextCellValue('State/UT Tax Amount'),
        exc.TextCellValue('Cess Amount'),
      ]);
      for (final r in _gstr1HsnRows) {
        sheetHsn.appendRow([
          exc.TextCellValue(r.hsnSacCode),
          exc.TextCellValue(r.description),
          exc.TextCellValue(r.unit),
          exc.DoubleCellValue(r.totalQty),
          exc.DoubleCellValue(r.totalValue),
          exc.DoubleCellValue(r.taxableValue),
          exc.DoubleCellValue(r.igst),
          exc.DoubleCellValue(r.cgst),
          exc.DoubleCellValue(r.sgst),
          exc.DoubleCellValue(0.0),
        ]);
      }

      // 4. Detailed Sales Register Sheet
      final sheetRegister = workbook['gstr1_register'];
      sheetRegister.appendRow(_gstHeaders.map(exc.TextCellValue.new).toList());
      for (final row in _rows) {
        sheetRegister.appendRow([
          exc.TextCellValue(DateFormat('dd-MM-yyyy').format(row.invoiceDate)),
          exc.TextCellValue(row.invoiceNumber),
          exc.TextCellValue(row.customerName),
          exc.TextCellValue(
              row.customerGstin.isEmpty ? 'B2C' : row.customerGstin),
          exc.DoubleCellValue(row.invoiceValue),
          exc.TextCellValue(row.placeOfSupply),
          exc.TextCellValue(row.itemDescription),
          exc.TextCellValue(row.hsnSacCode),
          exc.TextCellValue('${_formatQty(row.quantity)} ${row.unit}'),
          exc.DoubleCellValue(row.taxableValue),
          exc.DoubleCellValue(row.cgstAmount),
          exc.DoubleCellValue(row.sgstAmount),
          exc.DoubleCellValue(row.igstAmount),
          exc.DoubleCellValue(row.totalLineValue),
        ]);
      }
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
          'Cash',
          'Card',
          'UPI',
          'Other',
          'Adv Deposit',
          'Adv Adjusted',
          'Subtotal',
          'Discount',
          'Charges',
          'Charges GST',
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
          exc.DoubleCellValue(row.cashAmount),
          exc.DoubleCellValue(row.cardAmount),
          exc.DoubleCellValue(row.upiAmount),
          exc.DoubleCellValue(row.otherAmount),
          exc.DoubleCellValue(row.advanceAmount),
          exc.DoubleCellValue(row.advanceAdjustmentAmount),
          exc.DoubleCellValue(row.subTotal),
          exc.DoubleCellValue(row.discount),
          exc.DoubleCellValue(row.chargeTotal),
          exc.DoubleCellValue(row.chargeTaxTotal),
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
        exc.DoubleCellValue(_dateWiseCashTotal),
        exc.DoubleCellValue(_dateWiseCardTotal),
        exc.DoubleCellValue(_dateWiseUpiTotal),
        exc.DoubleCellValue(_dateWiseOtherTotal),
        exc.DoubleCellValue(_dateWiseAdvDepositTotal),
        exc.DoubleCellValue(_dateWiseAdvAdjustedTotal),
        exc.DoubleCellValue(_dateWiseSubTotalTotal),
        exc.DoubleCellValue(_dateWiseDiscountTotal),
        exc.DoubleCellValue(_dateWiseChargeTotalTotal),
        exc.DoubleCellValue(_dateWiseChargeTaxTotal),
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
    final modes = _pivotedPaymentModes;
    final headers = switch (_reportTabIndex) {
      0 => [
          'Date',
          'Bill No',
          ...modes.map(_formatPaymentModeHeader),
          'Net Amount'
        ],
      1 => [
          'Date',
          'Bill No',
          'Cash',
          'Card',
          'UPI',
          'Other',
          'Adv Deposit',
          'Adv Adjusted',
          'Subtotal',
          'Discount',
          'Charges',
          'Charges GST',
          ...taxRates.expand(
            (rate) => [
              '${_formatTaxPercent(rate)}% Sale',
              '${_formatTaxPercent(rate)}% GST',
            ],
          ),
          'IGST',
          'Tax',
          'Net Amount',
          'Sub Sale',
          'Net Revenue',
        ],
      2 => [
          'Label',
          'HSN/SAC',
          'Rows',
          'Qty',
          'Unit',
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
          'Cash',
          'Card',
          'UPI',
          'Other',
          'Adv Deposit',
          'Adv Adjusted',
          'Subtotal',
          'Discount',
          'Charges',
          'Charges GST',
          ...taxRates.expand(
            (rate) => [
              '${_formatTaxPercent(rate)}% Sale',
              '${_formatTaxPercent(rate)}% GST',
            ],
          ),
          'IGST',
          'Tax',
          'Net Amount',
          'Sub Sale',
          'Net Revenue',
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
      0 => [
          ..._pivotedBillPaymentRows.map(
            (row) => [
              DateFormat('dd-MM-yyyy').format(row.saleDate),
              _maskedBillNo(row.saleNo),
              ...modes.map((m) => _money(row.modeAmounts[m] ?? 0.0)),
              _money(row.netAmount),
            ],
          ),
          [
            'TOTAL',
            '',
            ...modes.map((m) {
              final modeTotal = _pivotedBillPaymentRows.fold<double>(
                0, (sum, r) => sum + (r.modeAmounts[m] ?? 0.0),
              );
              return _money(modeTotal);
            }),
            _money(_paymentReportNetTotal),
          ],
        ],
      1 => _billWiseSales.map(
          (sale) {
            final bands = _saleTaxBands(sale);
            return [
              DateFormat('dd-MM-yyyy').format(sale.saleDate),
              _maskedBillNo(sale.saleNo),
              _money(sale.cashAmount),
              _money(sale.cardAmount),
              _money(sale.upiAmount),
              _money(sale.otherAmount),
              _money(sale.advanceAmount),
              _money(sale.advanceAdjustmentAmount),
              _money(sale.subTotal),
              _money(sale.totalDiscount),
              _money(sale.chargeTotal),
              _money(_saleChargeTaxTotal(sale)),
              ...taxRates.expand(
                (rate) => [
                  _money(_bandTaxable(bands, rate)),
                  _money(_bandTax(bands, rate)),
                ],
              ),
              _money(_saleIgstAmount(sale)),
              _money(_saleTotalTax(sale)),
              _money(sale.netAmount),
              _money(sale.subscription),
              _money(sale.netAmount - sale.subscription),
            ];
          },
        ).toList()
          ..add([
            'TOTAL',
            '',
            _money(_billWiseCashTotal),
            _money(_billWiseCardTotal),
            _money(_billWiseUpiTotal),
            _money(_billWiseOtherTotal),
            _money(_billWiseAdvDepositTotal),
            _money(_billWiseAdvAdjustedTotal),
            _money(_billWiseSubTotalTotal),
            _money(_billWiseDiscountTotal),
            _money(_billWiseChargeTotalTotal),
            _money(_headerChargeTaxTotal),
            ...taxRates.expand(
              (rate) => [
                _money(_billWiseTaxBandsTotal[rate]?.taxableValue ?? 0),
                _money(_billWiseTaxBandsTotal[rate]?.taxAmount ?? 0),
              ],
            ),
            _money(_billWiseIgstTotal),
            _money(_headerTaxTotal),
            _money(_billWiseNetTotal),
            _money(_billWiseSales.fold<double>(0, (sum, s) => sum + s.subscription)),
            _money(_billWiseSales.fold<double>(0, (sum, s) => sum + (s.netAmount - s.subscription))),
          ]),
      2 => _groupedRows
          .map(
            (row) => [
              row.label,
              row.hsnSacCode,
              '${row.lineCount}',
              _formatQty(row.quantity),
              row.unit,
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
              _money(row.cashAmount),
              _money(row.cardAmount),
              _money(row.upiAmount),
              _money(row.otherAmount),
              _money(row.advanceAmount),
              _money(row.advanceAdjustmentAmount),
              _money(row.subTotal),
              _money(row.discount),
              _money(row.chargeTotal),
              _money(row.chargeTaxTotal),
              ...taxRates.expand(
                (rate) => [
                  _money(_bandTaxable(row.taxBands, rate)),
                  _money(_bandTax(row.taxBands, rate)),
                ],
              ),
              _money(row.igstAmount),
              _money(row.taxAmount),
              _money(row.netAmount),
              _money(row.subscription),
              _money(row.netAmount - row.subscription),
            ],
          )
          .toList()
        ..add([
          'TOTAL',
          '$_dateWiseBillsTotal',
          _formatQty(_dateWiseQtyTotal),
          _money(_dateWiseCashTotal),
          _money(_dateWiseCardTotal),
          _money(_dateWiseUpiTotal),
          _money(_dateWiseOtherTotal),
          _money(_dateWiseAdvDepositTotal),
          _money(_dateWiseAdvAdjustedTotal),
          _money(_dateWiseSubTotalTotal),
          _money(_dateWiseDiscountTotal),
          _money(_dateWiseChargeTotalTotal),
          _money(_dateWiseChargeTaxTotal),
          ...taxRates.expand(
            (rate) => [
              _money(_dateWiseTaxBandsTotal[rate]?.taxableValue ?? 0),
              _money(_dateWiseTaxBandsTotal[rate]?.taxAmount ?? 0),
            ],
          ),
          _money(_dateWiseIgstTotal),
          _money(_dateWiseTaxTotal),
          _money(_dateWiseNetTotal),
          _money(_dateWiseSalesRows.fold<double>(0, (sum, r) => sum + r.subscription)),
          _money(_dateWiseSalesRows.fold<double>(0, (sum, r) => sum + (r.netAmount - r.subscription))),
        ]),
      4 => _rows
          .map(
            (row) => [
              DateFormat('dd-MM-yyyy').format(row.invoiceDate),
              row.invoiceNumber,
              row.customerName,
              row.customerGstin.isEmpty ? 'B2C' : row.customerGstin,
              _money(row.invoiceValue),
              row.placeOfSupply,
              row.itemDescription,
              row.hsnSacCode,
              '${_formatQty(row.quantity)} ${row.unit}',
              _money(row.taxableValue),
              _money(row.cgstAmount),
              _money(row.sgstAmount),
              _money(row.igstAmount),
              _money(row.totalLineValue),
            ],
          )
          .toList()
        ..add([
          'TOTAL',
          '',
          '',
          '',
          _money(_billWiseNetTotal),
          '',
          '',
          '',
          '',
          _money(_headerTaxableTotal),
          _money(_headerCgstTotal),
          _money(_headerSgstTotal),
          _money(_rows.fold<double>(0, (sum, row) => sum + row.igstAmount)),
          _money(
              _rows.fold<double>(0, (sum, row) => sum + row.totalLineValue)),
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
                    children: (_reportTabIndex == 0 && _uniquePaymentModeSummaries.isNotEmpty)
                        ? _uniquePaymentModeSummaries
                            .map((item) => _pdfSummaryBlock(
                                  item['label'] as String,
                                  item['amount'] as double,
                                ))
                            .toList()
                        : [
                            _pdfSummaryBlock('Taxable Value', summary.taxableValue),
                            _pdfSummaryBlock('Total CGST', summary.cgstAmount),
                            _pdfSummaryBlock('Total SGST/UTGST', summary.sgstAmount),
                            _pdfSummaryBlock('Non-Tax Sales', _nonTaxSaleTotal),
                            _pdfSummaryBlock('Sub Sale (Adv.)', ctrl.summary.subscriptionRealized),
                            _pdfSummaryBlock('Charges', summary.chargeTotal),
                            _pdfSummaryBlock('Net', summary.totalRevenue - ctrl.summary.subscriptionRealized),
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
    await Printing.layoutPdf(name: title, onLayout: (_) async => bytes);
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
                  'Net Sales = Sub-Total − Discount + GST (Includes Subscription)  •  Subscription = Advance-Paid Sale  •  Net = Net Sales − Subscription',
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
    final subTotal = _headerItemTaxableTotal + _headerDiscountTotal;
    final discount = _headerDiscountTotal;   // header total_discount
    final gst      = _headerItemTaxTotal;    // item GST
    final netSales = _headerItemNetAmount;   // Revenue − Charges − ChargeGST

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Bill Breakdown Panel ─────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bill Breakdown',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 14),
              // Equation row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _breakdownChip(
                      label: 'Sub-Total',
                      value: subTotal,
                      accent: const Color(0xFF0F766E),
                      icon: Icons.receipt_long_outlined,
                    ),
                    _breakdownOp('−', const Color(0xFFDC2626)),
                    _breakdownChip(
                      label: 'Discount',
                      value: discount,
                      accent: const Color(0xFFDC2626),
                      icon: Icons.local_offer_outlined,
                      isDeduction: true,
                    ),
                    _breakdownOp('+', const Color(0xFF2563EB)),
                    _breakdownChip(
                      label: 'GST',
                      value: gst,
                      accent: const Color(0xFF2563EB),
                      icon: Icons.account_balance_outlined,
                    ),
                    _breakdownOp('=', const Color(0xFF334155)),
                    _breakdownChip(
                      label: 'Net Sales',
                      value: netSales,
                      accent: const Color(0xFFEA580C),
                      icon: Icons.payments_outlined,
                      isResult: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Metric Cards ─────────────────────────────────────────────────
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(width: 220, child: _metricCard('Taxable Value', _headerTaxableTotal, const Color(0xFF0F766E))),
            SizedBox(width: 220, child: _metricCard('Total CGST', _headerCgstTotal, const Color(0xFF2563EB))),
            SizedBox(width: 220, child: _metricCard('Total SGST/UTGST', _headerSgstTotal, const Color(0xFF7C3AED))),
            SizedBox(width: 220, child: _metricCard('Total IGST', _headerIgstTotal, const Color(0xFF0EA5E9))),
            SizedBox(width: 220, child: _metricCard('GST Total', _headerTaxTotal, const Color(0xFFEA580C))),
            SizedBox(
              width: 220,
              child: _metricCard('Total Discount', _headerDiscountTotal, const Color(0xFFDC2626),
                  subtitle: 'applied across all bills'),
            ),
            SizedBox(
              width: 220,
              child: _metricCard(
                _headerChargeTotal >= 0 ? 'Total Charges' : 'Charge Adj. (Net Refund)',
                _headerChargeTotal.abs(),
                _headerChargeTotal >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                subtitle: _headerChargeTotal >= 0
                    ? 'packing, delivery & other'
                    : 'charges reversed due to returns',
              ),
            ),
            SizedBox(width: 220, child: _metricCard('Charges GST', _headerChargeTaxTotal, const Color(0xFF7C3AED))),
            SizedBox(width: 220, child: _metricCard('Net Sales (Standard)', _headerItemNetAmount, const Color(0xFFEA580C))),
            SizedBox(width: 220, child: _metricCard('Taxed Sales After GST', _taxSaleTotal, const Color(0xFF16A34A))),
            SizedBox(width: 220, child: _metricCard('Non-Tax Sales', _nonTaxSaleTotal, const Color(0xFF64748B))),
            SizedBox(
              width: 220,
              child: _metricCard(
                'Subscription Sale (Advance Paid)',
                ctrl.summary.subscriptionRealized,
                const Color(0xFF0EA5E9),
                subtitle: 'Actual sale — advance collected, GST applicable',
              ),
            ),
            SizedBox(
              width: 220,
              child: _metricCard(
                'Total Revenue',
                _headerRevenueTotal,
                const Color(0xFF16A34A),
                subtitle: 'Net Sales + Charges',
              ),
            ),
            SizedBox(
              width: 220,
              child: _metricCard(
                'Net Revenue',
                _headerRevenueTotal - ctrl.summary.subscriptionRealized,
                const Color(0xFF0D9488),
                subtitle: 'Total Revenue - Subscription (all payment methods)',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _breakdownChip({
    required String label,
    required double value,
    required Color accent,
    required IconData icon,
    bool isDeduction = false,
    bool isResult = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isResult
            ? accent.withOpacity(0.1)
            : isDeduction
                ? const Color(0xFFFEF2F2)
                : accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withOpacity(isResult ? 0.4 : 0.2),
          width: isResult ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: accent),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _money(value),
            style: TextStyle(
              fontSize: isResult ? 17 : 15,
              fontWeight: isResult ? FontWeight.w900 : FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownOp(String op, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        op,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _metricCard(String label, double value, Color accent,
      {String? subtitle}) {
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
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF94A3B8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
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
            children: _uniquePaymentModeSummaries
                .map(
                  (entry) => SizedBox(
                    width: 190,
                    child: _metricCard(
                      entry['label'] as String,
                      entry['amount'] as double,
                      _paymentColor(entry['key'] as String),
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
              columns: [
                const DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('Bill No', style: TextStyle(fontWeight: FontWeight.bold))),
                ..._pivotedPaymentModes.map(
                  (mode) => DataColumn(
                    label: Text(
                      _formatPaymentModeHeader(mode),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const DataColumn(label: Text('Net Amount', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: [
                ..._pivotedBillPaymentRows.map(
                  (row) => DataRow(
                    cells: [
                      DataCell(
                        Text(DateFormat('dd-MM-yyyy').format(row.saleDate)),
                      ),
                      DataCell(Text(_maskedBillNo(row.saleNo))),
                      ..._pivotedPaymentModes.map(
                        (mode) {
                          final amt = row.modeAmounts[mode] ?? 0.0;
                          return DataCell(
                            Text(
                              _money(amt),
                              style: TextStyle(
                                color: amt > 0 ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                fontWeight: amt > 0 ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          );
                        },
                      ),
                      DataCell(
                        Text(
                          _money(row.netAmount),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
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
                    ..._pivotedPaymentModes.map(
                      (mode) {
                        final modeTotal = _pivotedBillPaymentRows.fold<double>(
                          0, (sum, row) => sum + (row.modeAmounts[mode] ?? 0.0),
                        );
                        return DataCell(
                          Text(
                            _money(modeTotal),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        );
                      },
                    ),
                    DataCell(
                      Text(
                        _money(_paymentReportNetTotal),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
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
            'Bills: ${rows.length} | Net Sales: ${_money(_billWiseNetTotal)} | Subscription Sale: ${_money(ctrl.summary.subscriptionRealized)} | Net: ${_money(_billWiseNetTotal - ctrl.summary.subscriptionRealized)}',
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
                                  const DataColumn(label: Text('Cash')),
                                  const DataColumn(label: Text('Card')),
                                  const DataColumn(label: Text('UPI')),
                                  const DataColumn(label: Text('Other')),
                                  const DataColumn(label: Text('Adv Deposit')),
                                  const DataColumn(label: Text('Adv Adjusted')),
                                  const DataColumn(label: Text('Subtotal')),
                                  const DataColumn(label: Text('Discount')),
                                  const DataColumn(label: Text('Charges')),
                                  const DataColumn(label: Text('Charges GST')),
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
                                  const DataColumn(
                                    label: Tooltip(
                                      message: 'Subscription = advance-paid sale. Customer GST applicable. Counted in total sales.',
                                      child: Text('Sub Sale', style: TextStyle(color: Color(0xFF0EA5E9))),
                                    ),
                                  ),
                                  const DataColumn(
                                    label: Tooltip(
                                      message: 'Net Amount - Subscription Sale (Total revenue collected for this bill across all payment methods)',
                                      child: Text('Net Revenue', style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.w700)),
                                    ),
                                  ),
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
                                        DataCell(Text(_money(sale.cashAmount))),
                                        DataCell(Text(_money(sale.cardAmount))),
                                        DataCell(Text(_money(sale.upiAmount))),
                                        DataCell(Text(_money(sale.otherAmount))),
                                        DataCell(Text(_money(sale.advanceAmount))),
                                        DataCell(Text(_money(sale.advanceAdjustmentAmount))),
                                        DataCell(Text(_money(sale.subTotal))),
                                        DataCell(Text(_money(sale.totalDiscount))),
                                        DataCell(Text(_money(sale.chargeTotal))),
                                        DataCell(Text(_money(_saleChargeTaxTotal(sale)))),
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
                                        DataCell(Text(_money(_saleTotalTax(sale)))),
                                        DataCell(
                                          Text(
                                            _money(sale.netAmount),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(_money(sale.subscription))),
                                        DataCell(
                                          Text(
                                            _money(sale.netAmount - sale.subscription),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0D9488),
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
                                      DataCell(
                                        Text(
                                          _money(_billWiseCashTotal),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _money(_billWiseCardTotal),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _money(_billWiseUpiTotal),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _money(_billWiseOtherTotal),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _money(_billWiseAdvAddedTotal),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _money(_billWiseAdvAdjTotal),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
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
                                      DataCell(
                                        Text(
                                          _money(_headerChargeTaxTotal),
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
                                      DataCell(
                                        Text(
                                          _money(ctrl.summary.subscriptionRealized),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0EA5E9),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _money(_billWiseNetTotal - ctrl.summary.subscriptionRealized),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0D9488),
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
                                const DataColumn(label: Text('Subtotal')),
                                const DataColumn(label: Text('Discount')),
                                const DataColumn(label: Text('Taxed Sales')),
                                const DataColumn(label: Text('Non-Tax Sales')),
                                const DataColumn(label: Text('Taxable Value')),
                                const DataColumn(label: Text('CGST')),
                                const DataColumn(label: Text('SGST/UTGST')),
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
            'Days: ${rows.length} | Net Sales: ${_money(_dateWiseNetTotal)} | Subscription Sale (Advance Paid): ${_money(ctrl.summary.subscriptionRealized)} | Net: ${_money(_dateWiseNetTotal - ctrl.summary.subscriptionRealized)}',
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
                              const DataColumn(label: Text('Cash')),
                              const DataColumn(label: Text('Card')),
                              const DataColumn(label: Text('UPI')),
                              const DataColumn(label: Text('Other')),
                              const DataColumn(label: Text('Adv Deposit')),
                              const DataColumn(label: Text('Adv Adjusted')),
                              const DataColumn(label: Text('Subtotal')),
                              const DataColumn(label: Text('Discount')),
                              const DataColumn(label: Text('Charges')),
                              const DataColumn(label: Text('Charges GST')),
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
                              const DataColumn(
                                label: Tooltip(
                                  message: 'Subscription = advance-paid sale. Customer GST applicable. Counted in total sales.',
                                  child: Text('Sub Sale', style: TextStyle(color: Color(0xFF0EA5E9))),
                                ),
                              ),
                              const DataColumn(
                                label: Tooltip(
                                  message: 'Net Amount - Subscription Sale (Total revenue collected for this date across all payment methods)',
                                  child: Text('Net Revenue', style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.w700)),
                                ),
                              ),
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
                                    DataCell(Text(_money(row.cashAmount))),
                                    DataCell(Text(_money(row.cardAmount))),
                                    DataCell(Text(_money(row.upiAmount))),
                                    DataCell(Text(_money(row.otherAmount))),
                                    DataCell(Text(_money(row.advanceAmount))),
                                    DataCell(Text(_money(row.advanceAdjustmentAmount))),
                                    DataCell(Text(_money(row.subTotal))),
                                    DataCell(Text(_money(row.discount))),
                                    DataCell(Text(_money(row.chargeTotal))),
                                    DataCell(Text(_money(row.chargeTaxTotal))),
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
                                    DataCell(Text(_money(row.subscription))),
                                    DataCell(
                                      Text(
                                        _money(row.netAmount - row.subscription),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0D9488),
                                        ),
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
                                    Text(
                                      'TOTAL',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800),
                                    ),
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
                                  DataCell(
                                    Text(_money(_dateWiseCashTotal),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  DataCell(
                                    Text(_money(_dateWiseCardTotal),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  DataCell(
                                    Text(_money(_dateWiseUpiTotal),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  DataCell(
                                    Text(_money(_dateWiseOtherTotal),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  DataCell(
                                    Text(_money(_dateWiseAdvDepositTotal),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  DataCell(
                                    Text(_money(_dateWiseAdvAdjustedTotal),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                  ),
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
                                  DataCell(
                                    Text(
                                      _money(_dateWiseChargeTaxTotal),
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
                                  DataCell(
                                    Text(
                                      _money(ctrl.summary.subscriptionRealized),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0EA5E9),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _money(_dateWiseNetTotal - ctrl.summary.subscriptionRealized),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0D9488),
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
        ],
      ),
    );
  }

  Widget _buildGstr1SubTabButton(String tabKey, String label) {
    final isSelected = _gstr1SubTab == tabKey;
    return InkWell(
      onTap: () => setState(() => _gstr1SubTab = tabKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GSTR-1 Portal Sales Report',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Wrap(
                spacing: 8,
                children: [
                  _buildGstr1SubTabButton('REGISTER', 'Sales Register'),
                  _buildGstr1SubTabButton('B2B', 'B2B (Table 4)'),
                  _buildGstr1SubTabButton('B2CS', 'B2C Small (Table 7)'),
                  _buildGstr1SubTabButton('HSN', 'HSN Summary (Table 12)'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Section: ${_gstr1SubTab == 'B2B' ? 'B2B Taxable Supplies (Table 4)' : _gstr1SubTab == 'B2CS' ? 'B2C Small Supplies (Table 7)' : _gstr1SubTab == 'HSN' ? 'HSN/SAC Summary (Table 12)' : 'All Sales Register'} | Exporting Excel creates standard GST Portal sheets (b2b, b2cs, hsn, register).',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _buildGstr1TableContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildGstr1TableContent() {
    if (_gstr1SubTab == 'B2B') {
      final b2bRows = _gstr1B2bRows;
      if (b2bRows.isEmpty) {
        return const Center(child: Text('No B2B sales found for selected range.'));
      }
      return _buildScrollableTable(
        minWidth: 1600,
        columns: const [
          DataColumn(label: Text('GSTIN/UIN of Recipient')),
          DataColumn(label: Text('Receiver Name')),
          DataColumn(label: Text('Invoice Number')),
          DataColumn(label: Text('Invoice Date')),
          DataColumn(label: Text('Invoice Value')),
          DataColumn(label: Text('Place Of Supply')),
          DataColumn(label: Text('Reverse Charge')),
          DataColumn(label: Text('Invoice Type')),
          DataColumn(label: Text('Rate')),
          DataColumn(label: Text('Taxable Value')),
          DataColumn(label: Text('CGST Amount')),
          DataColumn(label: Text('SGST Amount')),
          DataColumn(label: Text('IGST Amount')),
        ],
        rows: [
          ...b2bRows.map((r) => DataRow(cells: [
                DataCell(Text(r.customerGstin)),
                DataCell(Text(r.customerName)),
                DataCell(Text(r.invoiceNumber)),
                DataCell(Text(DateFormat('dd-MM-yyyy').format(r.invoiceDate))),
                DataCell(Text(_money(r.invoiceValue), style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(r.placeOfSupply)),
                DataCell(Text(r.reverseCharge)),
                DataCell(Text(r.invoiceType)),
                DataCell(Text('${_formatTaxPercent(r.rate)}%')),
                DataCell(Text(_money(r.taxableValue))),
                DataCell(Text(_money(r.cgst))),
                DataCell(Text(_money(r.sgst))),
                DataCell(Text(_money(r.igst))),
              ])),
          DataRow(
            color: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            cells: [
              const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataCell(Text('')),
              const DataCell(Text('')),
              const DataCell(Text('')),
              const DataCell(Text('')),
              const DataCell(Text('')),
              const DataCell(Text('')),
              const DataCell(Text('')),
              const DataCell(Text('')),
              DataCell(Text(_money(b2bRows.fold<double>(0, (sum, r) => sum + r.taxableValue)), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(_money(b2bRows.fold<double>(0, (sum, r) => sum + r.cgst)), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(_money(b2bRows.fold<double>(0, (sum, r) => sum + r.sgst)), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(_money(b2bRows.fold<double>(0, (sum, r) => sum + r.igst)), style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          )
        ],
      );
    } else if (_gstr1SubTab == 'B2CS') {
      final b2csRows = _gstr1B2csRows;
      if (b2csRows.isEmpty) {
        return const Center(child: Text('No B2C sales found for selected range.'));
      }
      return _buildScrollableTable(
        minWidth: 1000,
        columns: const [
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Place Of Supply')),
          DataColumn(label: Text('Rate')),
          DataColumn(label: Text('Taxable Value')),
          DataColumn(label: Text('CGST Amount')),
          DataColumn(label: Text('SGST Amount')),
          DataColumn(label: Text('IGST Amount')),
        ],
        rows: [
          ...b2csRows.map((r) => DataRow(cells: [
                DataCell(Text(r.type)),
                DataCell(Text(r.placeOfSupply)),
                DataCell(Text('${_formatTaxPercent(r.rate)}%')),
                DataCell(Text(_money(r.taxableValue))),
                DataCell(Text(_money(r.cgst))),
                DataCell(Text(_money(r.sgst))),
                DataCell(Text(_money(r.igst))),
              ])),
          DataRow(
            color: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            cells: [
              const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataCell(Text('')),
              const DataCell(Text('')),
              DataCell(Text(_money(b2csRows.fold<double>(0, (sum, r) => sum + r.taxableValue)), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(_money(b2csRows.fold<double>(0, (sum, r) => sum + r.cgst)), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(_money(b2csRows.fold<double>(0, (sum, r) => sum + r.sgst)), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(_money(b2csRows.fold<double>(0, (sum, r) => sum + r.igst)), style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          )
        ],
      );
    } else if (_gstr1SubTab == 'HSN') {
      final hsnRows = _gstr1HsnRows;
      if (hsnRows.isEmpty) {
        return const Center(child: Text('No HSN/SAC records found for selected range.'));
      }
      return _buildScrollableTable(
        minWidth: 1200,
        columns: const [
          DataColumn(label: Text('HSN/SAC Code')),
          DataColumn(label: Text('Description')),
          DataColumn(label: Text('UQC (Unit)')),
          DataColumn(label: Text('Total Quantity')),
          DataColumn(label: Text('Total Value')),
          DataColumn(label: Text('Taxable Value')),
          DataColumn(label: Text('CGST Amount')),
          DataColumn(label: Text('SGST Amount')),
          DataColumn(label: Text('IGST Amount')),
        ],
        rows: [
          ...hsnRows.map((r) => DataRow(cells: [
                DataCell(Text(r.hsnSacCode)),
                DataCell(SizedBox(width: 180, child: Text(r.description, maxLines: 2, overflow: TextOverflow.ellipsis))),
                DataCell(Text(r.unit)),
                DataCell(Text(_formatQty(r.totalQty))),
                DataCell(Text(_money(r.totalValue), style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(_money(r.taxableValue))),
                DataCell(Text(_money(r.cgst))),
                DataCell(Text(_money(r.sgst))),
                DataCell(Text(_money(r.igst))),
              ])),
          DataRow(
            color: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            cells: [
              const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataCell(Text('')),
              const DataCell(Text('')),
              DataCell(Text(_formatQty(hsnRows.fold<double>(0, (sum, r) => sum + r.totalQty)), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(_money(hsnRows.fold<double>(0, (sum, r) => sum + r.totalValue)), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(_money(hsnRows.fold<double>(0, (sum, r) => sum + r.taxableValue)), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(_money(hsnRows.fold<double>(0, (sum, r) => sum + r.cgst)), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(_money(hsnRows.fold<double>(0, (sum, r) => sum + r.sgst)), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(_money(hsnRows.fold<double>(0, (sum, r) => sum + r.igst)), style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          )
        ],
      );
    } else {
      if (_rows.isEmpty) {
        return const Center(child: Text('No GSTR-1 rows found for the selected range.'));
      }
      return _buildScrollableTable(
        minWidth: 1500,
        columns: _gstHeaders.map((header) => DataColumn(label: Text(header))).toList(),
        rows: [
          ..._rows.map((row) => DataRow(cells: [
                DataCell(Text(DateFormat('dd-MM-yyyy').format(row.invoiceDate))),
                DataCell(Text(row.invoiceNumber)),
                DataCell(SizedBox(width: 150, child: Text(row.customerName, maxLines: 2, overflow: TextOverflow.ellipsis))),
                DataCell(Text(row.customerGstin.isEmpty ? 'B2C' : row.customerGstin)),
                DataCell(Text(_money(row.invoiceValue), style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(SizedBox(width: 160, child: Text(row.placeOfSupply, maxLines: 2, overflow: TextOverflow.ellipsis))),
                DataCell(SizedBox(width: 170, child: Text(row.itemDescription, maxLines: 2, overflow: TextOverflow.ellipsis))),
                DataCell(Text(row.hsnSacCode)),
                DataCell(Text('${_formatQty(row.quantity)} ${row.unit}')),
                DataCell(Text(_money(row.taxableValue))),
                DataCell(Text(_money(row.cgstAmount))),
                DataCell(Text(_money(row.sgstAmount))),
                DataCell(Text(_money(row.igstAmount))),
                DataCell(Text(_money(row.totalLineValue))),
              ])),
          if (_rows.isNotEmpty)
            DataRow(
              color: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              cells: [
                const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                DataCell(Text(_money(_billWiseNetTotal), style: const TextStyle(fontWeight: FontWeight.bold))),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                DataCell(Text(_formatQty(_rows.fold<double>(0, (sum, row) => sum + row.quantity)), style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(_money(_rows.fold<double>(0, (sum, row) => sum + row.taxableValue)), style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(_money(_rows.fold<double>(0, (sum, row) => sum + row.cgstAmount)), style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(_money(_rows.fold<double>(0, (sum, row) => sum + row.sgstAmount)), style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(_money(_rows.fold<double>(0, (sum, row) => sum + row.igstAmount)), style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(_money(_rows.fold<double>(0, (sum, row) => sum + row.totalLineValue)), style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
        ],
      );
    }
  }

  Widget _buildScrollableTable({
    required double minWidth,
    required List<DataColumn> columns,
    required List<DataRow> rows,
  }) {
    return Scrollbar(
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
              constraints: BoxConstraints(minWidth: minWidth),
              child: SingleChildScrollView(
                primary: false,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 68,
                  columns: columns,
                  rows: rows,
                ),
              ),
            ),
          ),
        ),
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
                                rows: [
                                  ...rows.map(
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
                                  ).toList(),
                                  if (rows.isNotEmpty)
                                    DataRow(
                                      color: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                      cells: [
                                        const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                                        const DataCell(Text('')),
                                        const DataCell(Text('')),
                                        const DataCell(Text('')),
                                        const DataCell(Text('')),
                                        const DataCell(Text('')),
                                        DataCell(Text('${rows.fold<int>(0, (sum, r) => sum + r.itemCount)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                        DataCell(Text(_formatQty(rows.fold<double>(0, (sum, r) => sum + r.qty)), style: const TextStyle(fontWeight: FontWeight.bold))),
                                        DataCell(Text(_money(rows.fold<double>(0, (sum, r) => sum + r.taxableValue)), style: const TextStyle(fontWeight: FontWeight.bold))),
                                        DataCell(Text(_money(rows.fold<double>(0, (sum, r) => sum + r.taxAmount)), style: const TextStyle(fontWeight: FontWeight.bold))),
                                        DataCell(Text(_money(rows.fold<double>(0, (sum, r) => sum + r.totalAfterTax)), style: const TextStyle(fontWeight: FontWeight.bold))),
                                        DataCell(Text(_money(rows.fold<double>(0, (sum, r) => sum + r.paidAmount)), style: const TextStyle(fontWeight: FontWeight.bold))),
                                        DataCell(Text(_money(rows.fold<double>(0, (sum, r) => sum + r.outstandingAmount)), style: const TextStyle(fontWeight: FontWeight.bold))),
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
    final list = item.taxBreakup
        .where((tax) => tax.code.toUpperCase() == code);
    if (list.isNotEmpty) {
      return list.fold<double>(0, (sum, tax) => sum + tax.taxAmount);
    }
    if (code == 'CGST' || code == 'SGST') {
      return (item.taxAmount / 2);
    }
    return 0.0;
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
      case 'ADVANCE_DEPOSIT':
      case 'ADVANCE':
        return const Color(0xFFD97706);
      case 'ADVANCE_ADJUSTMENT':
        return const Color(0xFF0284C7);
      case 'SUBSCRIPTION':
        return const Color(0xFF0D9488);
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
  final double invoiceValue;
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
  final double totalLineValue;
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
    required this.invoiceValue,
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
    required this.totalLineValue,
    required this.totalInvoiceValue,
    required this.saleDateTime,
    required this.paymentMode,
    required this.discount,
    required this.subTotal,
  });
}

class _Gstr1B2bRow {
  final String customerGstin;
  final String customerName;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final double invoiceValue;
  final String placeOfSupply;
  final String reverseCharge;
  final String invoiceType;
  final double rate;
  final double taxableValue;
  final double cgst;
  final double sgst;
  final double igst;

  const _Gstr1B2bRow({
    required this.customerGstin,
    required this.customerName,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.invoiceValue,
    required this.placeOfSupply,
    required this.reverseCharge,
    required this.invoiceType,
    required this.rate,
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
    required this.igst,
  });
}

class _Gstr1B2csRow {
  final String type;
  final String placeOfSupply;
  final double rate;
  final double taxableValue;
  final double cgst;
  final double sgst;
  final double igst;

  const _Gstr1B2csRow({
    required this.type,
    required this.placeOfSupply,
    required this.rate,
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
    required this.igst,
  });

  _Gstr1B2csRow copyWith({
    double? taxableValue,
    double? cgst,
    double? sgst,
    double? igst,
  }) {
    return _Gstr1B2csRow(
      type: type,
      placeOfSupply: placeOfSupply,
      rate: rate,
      taxableValue: taxableValue ?? this.taxableValue,
      cgst: cgst ?? this.cgst,
      sgst: sgst ?? this.sgst,
      igst: igst ?? this.igst,
    );
  }
}

class _Gstr1HsnRow {
  final String hsnSacCode;
  final String description;
  final String unit;
  final double totalQty;
  final double totalValue;
  final double taxableValue;
  final double cgst;
  final double sgst;
  final double igst;

  const _Gstr1HsnRow({
    required this.hsnSacCode,
    required this.description,
    required this.unit,
    required this.totalQty,
    required this.totalValue,
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
    required this.igst,
  });

  _Gstr1HsnRow copyWith({
    double? totalQty,
    double? totalValue,
    double? taxableValue,
    double? cgst,
    double? sgst,
    double? igst,
  }) {
    return _Gstr1HsnRow(
      hsnSacCode: hsnSacCode,
      description: description,
      unit: unit,
      totalQty: totalQty ?? this.totalQty,
      totalValue: totalValue ?? this.totalValue,
      taxableValue: taxableValue ?? this.taxableValue,
      cgst: cgst ?? this.cgst,
      sgst: sgst ?? this.sgst,
      igst: igst ?? this.igst,
    );
  }
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
  final double cashAmount;
  final double cardAmount;
  final double upiAmount;
  final double otherAmount;
  final double advanceAmount;
  final double advanceAdjustmentAmount;
  final Map<double, _TaxBandSummary> taxBands;
  final double igstAmount;
  final double taxAmount;
  final double netAmount;
  final double subscription;
  final Set<String> paymentModes;
  final double subTotal;
  final double discount;
  final double chargeTotal;
  final double chargeTaxTotal;

  const _DateWiseSalesRow({
    required this.date,
    required this.bills,
    required this.qty,
    this.cashAmount = 0,
    this.cardAmount = 0,
    this.upiAmount = 0,
    this.otherAmount = 0,
    this.advanceAmount = 0,
    this.advanceAdjustmentAmount = 0,
    required this.taxBands,
    required this.igstAmount,
    required this.taxAmount,
    required this.netAmount,
    required this.subscription,
    required this.paymentModes,
    required this.subTotal,
    required this.discount,
    required this.chargeTotal,
    this.chargeTaxTotal = 0,
  });

  _DateWiseSalesRow copyWith({
    int? bills,
    double? qty,
    double? cashAmount,
    double? cardAmount,
    double? upiAmount,
    double? otherAmount,
    double? advanceAmount,
    double? advanceAdjustmentAmount,
    Map<double, _TaxBandSummary>? taxBands,
    double? igstAmount,
    double? taxAmount,
    double? netAmount,
    double? subscription,
    Set<String>? paymentModes,
    double? subTotal,
    double? discount,
    double? chargeTotal,
    double? chargeTaxTotal,
  }) {
    return _DateWiseSalesRow(
      date: date,
      bills: bills ?? this.bills,
      qty: qty ?? this.qty,
      cashAmount: cashAmount ?? this.cashAmount,
      cardAmount: cardAmount ?? this.cardAmount,
      upiAmount: upiAmount ?? this.upiAmount,
      otherAmount: otherAmount ?? this.otherAmount,
      advanceAmount: advanceAmount ?? this.advanceAmount,
      advanceAdjustmentAmount: advanceAdjustmentAmount ?? this.advanceAdjustmentAmount,
      taxBands: taxBands ?? this.taxBands,
      igstAmount: igstAmount ?? this.igstAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      netAmount: netAmount ?? this.netAmount,
      subscription: subscription ?? this.subscription,
      paymentModes: paymentModes ?? this.paymentModes,
      subTotal: subTotal ?? this.subTotal,
      discount: discount ?? this.discount,
      chargeTotal: chargeTotal ?? this.chargeTotal,
      chargeTaxTotal: chargeTaxTotal ?? this.chargeTaxTotal,
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

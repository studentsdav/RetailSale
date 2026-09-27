import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/common/property_info_model.dart';
import '../../models/inventory/sale_item_model.dart';
import '../../models/inventory/sale_order_model.dart';
import '../../models/inventory/tax_breakdown_model.dart';
import '../../models/inventory/settings/system_settings_model.dart';
import 'device_printer_routing.dart';
import '../config/app_brand.dart';
import '../config/date_time_service.dart';
import '../utils/timezone_utils.dart';
import '../../utils/branding_storage.dart';
import '../../controllers/settings/system_settings_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../currency/currency_service.dart';
import '../utils/country_tax_helper.dart';

class PosInvoicePrinter {
  PosInvoicePrinter._();
  static const PdfColor _thermalPrimary = PdfColors.black;
  static const PdfColor _thermalSecondary = PdfColors.grey800;
  static const PdfColor _thermalDivider = PdfColors.grey500;
  static const Map<String, double> _thermalWidths = {
    'THERMAL_58': 58,
    'THERMAL_72': 72,
    'THERMAL_76': 76,
    'THERMAL_80': 80,
  };

  static final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 2);
  static String formatTzDate(DateTime dt) =>
      TimeZoneUtils.formatInTimeZone(dt, DateTimeService.instance.currentTimeZone, pattern: 'dd-MMM-yyyy');
  static String formatTzTime(DateTime dt) =>
      TimeZoneUtils.formatInTimeZone(dt, DateTimeService.instance.currentTimeZone, pattern: 'hh:mm a');
  static String formatTzDateTime(DateTime dt) =>
      TimeZoneUtils.formatInTimeZone(dt, DateTimeService.instance.currentTimeZone, pattern: 'dd-MMM-yyyy hh:mm a');

  static final DateFormat _date = DateFormat('dd-MMM-yyyy');
  static final DateFormat _time = DateFormat('hh:mm a');
  static final DateFormat _dateTime = DateFormat('dd-MMM-yyyy hh:mm a');

  static bool _isThermalFormat(String billFormat) {
    final f = billFormat.toUpperCase();
    return _thermalWidths.containsKey(billFormat) || f.contains('THERMAL') || f.contains('80MM') || f.contains('58MM') || f.contains('76MM');
  }

  static PdfPageFormat _thermalSheetFor(String billFormat, [String? configWidth]) {
    double widthMm = 80;
    if (configWidth != null && configWidth.isNotEmpty) {
      final cw = configWidth.toLowerCase();
      if (cw.contains('58')) widthMm = 58;
      if (cw.contains('76')) widthMm = 76;
      if (cw.contains('80')) widthMm = 80;
    } else {
      widthMm = _thermalWidths[billFormat] ?? (billFormat.toUpperCase().contains('58') ? 58 : 80);
    }
    final horizontalMargin = widthMm <= 58 ? 2.0 : 3.0;
    return PdfPageFormat(
      widthMm * PdfPageFormat.mm,
      297 * PdfPageFormat.mm,
      marginLeft: horizontalMargin * PdfPageFormat.mm,
      marginRight: horizontalMargin * PdfPageFormat.mm,
      marginTop: 4 * PdfPageFormat.mm,
      marginBottom: 4 * PdfPageFormat.mm,
    );
  }

  /// Returns the [PdfPageFormat] that matches [billFormat].
  /// Thermal formats (THERMAL_58 / 72 / 76 / 80) return the correct narrow
  /// roll width; everything else returns [PdfPageFormat.a4].
  static PdfPageFormat pageFormatFor(String billFormat, [String? configWidth]) {
    if (_isThermalFormat(billFormat)) return _thermalSheetFor(billFormat, configWidth);
    return PdfPageFormat.a4;
  }

  static pw.Font? _cachedRegular;
  static pw.Font? _cachedBold;

  /// Loads and caches Unicode-compatible TrueType fonts (Noto Sans / Roboto)
  /// so that currency symbols such as ₹ (Indian Rupee), € (Euro), ₽, etc.
  /// are rendered properly without falling back to broken glyphs or WinAnsi limitations.
  static Future<({pw.Font regular, pw.Font bold})> getInvoiceFonts() async {
    if (_cachedRegular != null && _cachedBold != null) {
      return (regular: _cachedRegular!, bold: _cachedBold!);
    }
    try {
      final reg = await PdfGoogleFonts.notoSansRegular();
      final bld = await PdfGoogleFonts.notoSansBold();
      _cachedRegular = reg;
      _cachedBold = bld;
      return (regular: reg, bold: bld);
    } catch (_) {
      try {
        final reg = await PdfGoogleFonts.robotoRegular();
        final bld = await PdfGoogleFonts.robotoBold();
        _cachedRegular = reg;
        _cachedBold = bld;
        return (regular: reg, bold: bld);
      } catch (_) {
        final reg = pw.Font.helvetica();
        final bld = pw.Font.helveticaBold();
        return (regular: reg, bold: bld);
      }
    }
  }

  /// Creates a [pw.Document] pre-configured with Unicode TrueType fonts
  /// so currency symbols (₹, €, $, £, ¥, etc.) render properly across all PDFs.
  static Future<pw.Document> createDocument() async {
    final fonts = await getInvoiceFonts();
    return pw.Document(
      theme: pw.ThemeData.withFont(
        base: fonts.regular,
        bold: fonts.bold,
      ),
    );
  }

  static Future<void> printSaleInvoice({
    required SaleOrder order,
    required PropertyInfo? property,
    Printer? printer,
    bool directPrint = false,
    String cashierName = 'System',
    String? terminalNo,
    String? cashierId,
    double? amountReceived,
    double? changeDue,
    String? sellerStateCode,
    String? buyerState,
    String? buyerStateCode,
    String bankName = '',
    String bankAccountNo = '',
    String bankIfscCode = '',
    String termsAndConditions =
        'Goods once sold will not be taken back or exchanged.',
    String thankYouMessage = 'Thank you for your business.',
    String authorizedSignatureLabel = 'Authorized Signatory',
  }) async {
    final pdfBytes = await buildSaleInvoicePdf(
      order: order,
      property: property,
      cashierName: cashierName,
      terminalNo: terminalNo,
      cashierId: cashierId,
      amountReceived: amountReceived,
      changeDue: changeDue,
      sellerStateCode: sellerStateCode,
      buyerState: buyerState,
      buyerStateCode: buyerStateCode,
      bankName: bankName,
      bankAccountNo: bankAccountNo,
      bankIfscCode: bankIfscCode,
      termsAndConditions: termsAndConditions,
      thankYouMessage: thankYouMessage,
      authorizedSignatureLabel: authorizedSignatureLabel,
    );

    if (directPrint && printer != null) {
      await Printing.directPrintPdf(
        printer: printer,
        name: order.saleNo,
        onLayout: (_) async => pdfBytes,
      );
      return;
    }

    await Printing.layoutPdf(name: order.saleNo, onLayout: (_) async => pdfBytes);
  }

  static Future<Uint8List> buildSaleInvoicePdf({
    required SaleOrder order,
    required PropertyInfo? property,
    String cashierName = 'System',
    String? terminalNo,
    String? cashierId,
    double? amountReceived,
    double? changeDue,
    String? sellerStateCode,
    String? buyerState,
    String? buyerStateCode,
    String bankName = '',
    String bankAccountNo = '',
    String bankIfscCode = '',
    String termsAndConditions =
        'Goods once sold will not be taken back or exchanged.',
    String thankYouMessage = 'Thank you for your business.',
    String authorizedSignatureLabel = 'Authorized Signatory',
    int copyCount = 1,
    SystemSettings? settings,
  }) async {
    SystemSettings? sysSettings = settings;
    if (sysSettings == null) {
      final settingsCtrl = SystemSettingsController();
      await settingsCtrl.load();
      sysSettings = settingsCtrl.settings;
    }

    PropertyInfo? prop = property;
    if (prop == null) {
      final propCtrl = PropertyInfoController();
      await propCtrl.load();
      prop = propCtrl.data;
    }

    final receiptConfig = sysSettings?.receiptTemplateConfig ?? {};
    final a4Config = sysSettings?.a4TemplateConfig ?? {};
    final bool showBrandName = receiptConfig['show_brand'] ?? (sysSettings?.showBrandName ?? true);
    final bool enableTokenSystem = receiptConfig['show_token'] ?? (sysSettings?.enableTokenSystem ?? false);

    final fonts = await getInvoiceFonts();
    final document = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fonts.regular,
        bold: fonts.bold,
      ),
    );
    final logo = await BrandingStorage.loadPdfLogo(prop?.logoPath);
    final invoiceData = _InvoiceContext(
      order: order,
      property: prop,
      cashierName: cashierName,
      terminalNo: terminalNo,
      cashierId: cashierId,
      amountReceived: amountReceived,
      changeDue: changeDue,
      sellerStateCode: sellerStateCode ?? _stateCodeFor(prop?.state),
      buyerState: buyerState ?? _deriveBuyerState(order, prop),
      buyerStateCode: buyerStateCode ??
          _stateCodeFor(buyerState) ??
          _stateCodeFromGstin(order.customerGstin) ??
          _stateCodeFor(_deriveBuyerState(order, prop)),
      bankName: (a4Config['bank_name']?.toString().trim().isNotEmpty == true)
          ? a4Config['bank_name'].toString().trim()
          : (bankName.isNotEmpty ? bankName : (prop?.bankName ?? '')),
      bankAccountNo: (a4Config['bank_account_no']?.toString().trim().isNotEmpty == true)
          ? a4Config['bank_account_no'].toString().trim()
          : (bankAccountNo.isNotEmpty ? bankAccountNo : (prop?.bankAccNo ?? '')),
      bankIfscCode: (a4Config['bank_ifsc']?.toString().trim().isNotEmpty == true)
          ? a4Config['bank_ifsc'].toString().trim()
          : (bankIfscCode.isNotEmpty ? bankIfscCode : (prop?.bankIfsc ?? '')),
      termsAndConditions: (receiptConfig['terms_and_conditions']?.toString().trim().isNotEmpty == true)
          ? receiptConfig['terms_and_conditions'].toString().trim()
          : ((a4Config['terms_and_conditions']?.toString().trim().isNotEmpty == true)
              ? a4Config['terms_and_conditions'].toString().trim()
              : (prop?.termsAndConditions.isNotEmpty == true ? prop!.termsAndConditions : termsAndConditions)),
      thankYouMessage: (receiptConfig['footer_note']?.toString().trim().isNotEmpty == true)
          ? receiptConfig['footer_note'].toString().trim()
          : ((a4Config['footer_note']?.toString().trim().isNotEmpty == true)
              ? a4Config['footer_note'].toString().trim()
              : (prop?.thermalFooterNote.isNotEmpty == true ? prop!.thermalFooterNote : thankYouMessage)),
      authorizedSignatureLabel: (a4Config['signatory_label']?.toString().trim().isNotEmpty == true)
          ? a4Config['signatory_label'].toString().trim()
          : authorizedSignatureLabel,
      showBrandName: showBrandName,
      enableTokenSystem: enableTokenSystem,
      receiptTemplateConfig: receiptConfig,
      a4TemplateConfig: a4Config,
      regularFont: fonts.regular,
      boldFont: fonts.bold,
    );

    final String thermalWidthSetting = (receiptConfig['thermal_width'] ?? '').toString();

    final int numCopies = copyCount > 1 ? copyCount : 1;
    for (int c = 0; c < numCopies; c++) {
      if (_isThermalFormat(order.billFormat)) {
        document.addPage(
          pw.MultiPage(
            pageFormat: _thermalSheetFor(order.billFormat, thermalWidthSetting),
            build: (_) => [_buildThermalReceipt(invoiceData, logo)],
          ),
        );
      } else {
        document.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 30),
            footer: (_) => pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Generated on ${_dateTime.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ),
            build: (_) => [_buildA4Invoice(invoiceData, logo)],
          ),
        );
      }
    }

    return document.save();
  }

  static pw.Widget _buildThermalReceipt(
      _InvoiceContext data, pw.MemoryImage? logo) {
    final order = data.order;
    final cfg = data.receiptTemplateConfig;
    _currentShowCurrency = (cfg['show_currency_symbol'] == true || cfg['show_currency'] == true);

    // Dynamic typography scaling based on font_size in template config
    final String fontSizeSetting = (cfg['font_size'] ?? 'MEDIUM').toString().toUpperCase();
    double scale = 1.0;
    if (fontSizeSetting == 'SMALL') scale = 0.85;
    if (fontSizeSetting == 'LARGE') scale = 1.25;

    final regular = data.regularFont ?? _cachedRegular ?? pw.Font.helvetica();
    final bold = data.boldFont ?? _cachedBold ?? pw.Font.helveticaBold();
    final bodyStyle =
        pw.TextStyle(font: regular, fontSize: 8.9 * scale, color: _thermalSecondary);
    final emphasisStyle =
        pw.TextStyle(font: bold, fontSize: 9.6 * scale, color: _thermalPrimary);
    final storeStyle =
        pw.TextStyle(font: bold, fontSize: 12.8 * scale, color: _thermalPrimary);
    final grandStyle =
        pw.TextStyle(font: bold, fontSize: 14 * scale, color: _thermalPrimary);
    final totalItems = order.items.length;
    final roundOff = _billRoundOff(order);
    final subscriptionAdjustment = _subscriptionAdjustmentAmount(order);
    final savingsAmount = _displaySavingsAmount(order);
    final itemGroupedTaxes = _adjustedItemGroupedTaxes(order, _groupedTaxBreakup(order));
    final chargeGroupedTaxes = _groupedChargeTaxBreakup(order);
    final hasTaxData = itemGroupedTaxes.isNotEmpty;
    final hasChargeTaxData = chargeGroupedTaxes.isNotEmpty;
    final chargeTaxSummaryTotal = _groupTaxTotal(chargeGroupedTaxes);
    final cgstTotal = _taxAmountFromBreakup(itemGroupedTaxes, 'CGST') +
        _taxAmountFromBreakup(chargeGroupedTaxes, 'CGST');
    final sgstTotal = _taxAmountFromBreakup(itemGroupedTaxes, 'SGST') +
        _taxAmountFromBreakup(chargeGroupedTaxes, 'SGST');
    final igstTotal = _taxAmountFromBreakup(itemGroupedTaxes, 'IGST') +
        _taxAmountFromBreakup(chargeGroupedTaxes, 'IGST');
    final displayNetPayable = _displayNetPayable(
      order,
      chargeTaxTotal: chargeTaxSummaryTotal,
      summaryTaxTotal: cgstTotal + sgstTotal + igstTotal,
      subscriptionAdjustment: subscriptionAdjustment,
    );

    final bool showToken = cfg['show_token'] ?? (data.enableTokenSystem);

    return pw.DefaultTextStyle(
      style: bodyStyle,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          buildStandardThermalHeader(
            property: data.property,
            logo: logo,
            fontRegular: regular,
            fontBold: bold,
            country: order.billingCountry,
            receiptTemplateConfig: cfg,
            scale: scale,
          ),
          pw.Center(
            child: pw.Column(
              children: [
                pw.SizedBox(height: 4 * scale),
                pw.Text(
                  _receiptTitle(order, hasTaxData),
                  style: emphasisStyle,
                ),
                if (showToken && !_isRestaurantOrder(order) && (order.tokenNo ?? '').trim().isNotEmpty) ...[
                  pw.SizedBox(height: 4 * scale),
                  pw.Container(
                    padding: pw.EdgeInsets.symmetric(vertical: 3 * scale, horizontal: 8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.black, width: 1.5),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                    ),
                    child: pw.Text(
                      'TOKEN NO: ${order.tokenNo!.trim()}',
                      style: pw.TextStyle(font: bold, fontSize: 15 * scale, color: PdfColors.black),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _dashedDivider(),
          if (_refundStamp(order).isNotEmpty) ...[
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 4),
              padding: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
              ),
              child: pw.Center(
                child: pw.Text(
                  _refundStamp(order),
                  style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.black),
                ),
              ),
            ),
            _dashedDivider(),
          ],
          _thermalMetaRow(
            _receiptNumberLabel(order),
            order.saleNo,
            'Date',
            formatTzDate(order.saleDate),
          ),
          if (_isActualOrder(order) && order.orderId != null && order.hasBillNo)
            _thermalMetaRow(
              'Order No',
              '#${order.orderId}',
              '',
              '',
            ),
          if (_exchangeAgainstBillNo(order).isNotEmpty)
            _thermalMetaRow(
              'Against Bill No',
              _exchangeAgainstBillNo(order),
              '',
              '',
            ),
          if (cfg['show_cashier'] ?? true)
            _thermalMetaRow(
              'Cashier',
              data.cashierName.trim().isEmpty
                  ? 'System'
                  : data.cashierName.trim(),
              'Time',
              formatTzTime(order.saleDate),
            ),
          if ((cfg['show_customer'] ?? true) && ((order.customerName ?? '').trim().isNotEmpty ||
              (order.customerPhone ?? '').trim().isNotEmpty))
            _thermalMetaRow(
              'Customer',
              (order.customerName ?? '').trim().isEmpty
                  ? 'Walk-in'
                  : order.customerName!.trim(),
              'Phone',
              (order.customerPhone ?? '').trim().isEmpty
                  ? '--'
                  : order.customerPhone!.trim(),
            ),
          if ((order.customerGstin ?? '').trim().isNotEmpty)
            _thermalMetaRow(_taxIdLabel(order.billingCountry), order.customerGstin!.trim(), '', ''),
          if ((order.doctorName ?? '').trim().isNotEmpty ||
              (order.patientName ?? '').trim().isNotEmpty)
            _thermalMetaRow(
              'Dr. Name',
              (order.doctorName ?? '').trim().isEmpty
                  ? '--'
                  : order.doctorName!.trim(),
              'Patient',
              (order.patientName ?? '').trim().isEmpty
                  ? '--'
                  : order.patientName!.trim(),
            ),
          if (order.billingTaxMode == 'IGST' || (data.buyerState != null && data.buyerState!.isNotEmpty))
            _thermalMetaRow(
              'Place of Supply',
              data.buyerState != null && data.buyerState!.isNotEmpty
                  ? _titleCase(data.buyerState!)
                  : 'Local',
              'State Code',
              data.buyerState != null && data.buyerState!.isNotEmpty
                  ? (data.buyerStateCode ?? '-')
                  : (data.sellerStateCode ?? '-'),
            ),
          if (_cleanAddressForPrint(order.customerAddress).isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 1),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Address: ',
                    style: pw.TextStyle(
                      font: regular,
                      fontSize: 8,
                      color: _thermalSecondary,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      _cleanAddressForPrint(order.customerAddress),
                      style: pw.TextStyle(
                        font: regular,
                        fontSize: 8,
                        color: _thermalSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if ((order.voucherCode ?? '').trim().isNotEmpty)
            _thermalMetaRow('Voucher', order.voucherCode!.trim(), '', ''),
          if ((order.voucherFooterMessage ?? '').trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Text(
                order.voucherFooterMessage!.trim(),
                style: emphasisStyle,
                textAlign: pw.TextAlign.center,
              ),
            ),
          _dashedDivider(),
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(6),
              1: pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                children: [
                  _thermalHeaderCell(
                    'ITEM DETAILS',
                    align: pw.TextAlign.left,
                    style: emphasisStyle,
                  ),
                  _thermalHeaderCell(
                    'NET TOTAL',
                    align: pw.TextAlign.right,
                    style: emphasisStyle,
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          ...order.items.map((item) => _thermalItemRow(item, order, data.showBrandName)),
          _dashedDivider(),
          _thermalValueRow('Total Items', '$totalItems'),
          _thermalValueRow('Total Qty', order.totalQty % 1 == 0 ? order.totalQty.toInt().toString() : order.totalQty.toStringAsFixed(2)),
          ...(() {
            final double preTaxSum = order.items
                .where((item) => !item.isTaxInclusive && item.taxPercent > 0)
                .fold<double>(0, (sum, item) => sum + (item.rate > 0 ? (item.qty * item.rate) : (item.qty * _displayRate(item))));
            final double postTaxPreTaxSum = order.items
                .where((item) => item.isTaxInclusive && item.taxPercent > 0)
                .fold<double>(0, (sum, item) {
                  final rate = item.rate > 0 ? item.rate : _displayRate(item);
                  return sum + ((item.qty * rate) / (1 + item.taxPercent / 100));
                });
            final double postTaxGrossSum = order.items
                .where((item) => item.isTaxInclusive && item.taxPercent > 0)
                .fold<double>(0, (sum, item) => sum + (item.rate > 0 ? (item.qty * item.rate) : (item.qty * _displayRate(item))));
            final double nonTaxableSum = order.items
                .where((item) => item.taxPercent <= 0)
                .fold<double>(0, (sum, item) => sum + (item.rate > 0 ? (item.qty * item.rate) : (item.qty * _displayRate(item))));

            final bool isIndia = CountryTaxHelper.isIndiaCountry(order.billingCountry);
            final bool allInclusive = order.items.isNotEmpty && order.items.every((item) => item.isTaxInclusive);
            final String subtotalLabel = allInclusive ? 'Subtotal (Incl. ${CountryTaxHelper.taxName(order.billingCountry, order.billingTaxMode)})' : 'Subtotal';
            final double grossSub = _grossItemsSubtotal(order);
            final double rawSubtotal = grossSub > 0.0009
                ? grossSub
                : (order.subTotal > 0.0009 ? order.subTotal : (preTaxSum + postTaxGrossSum + nonTaxableSum));

            String? subTotalNote;
            final List<String> noteParts = [];
            if (preTaxSum > 0) noteParts.add('Pre-tax: ${_money(preTaxSum)}');
            if (postTaxGrossSum > 0) noteParts.add('Post-tax: ${_money(postTaxGrossSum)}');
            if (nonTaxableSum > 0) noteParts.add('Non-taxable: ${_money(nonTaxableSum)}');
            if (noteParts.length > 1) {
              subTotalNote = '(${noteParts.join(', ')})';
            }

            return [
              _thermalAmountRow(subtotalLabel, rawSubtotal),
              if (subTotalNote != null)
                pw.Container(
                  alignment: pw.Alignment.centerLeft,
                  margin: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(
                    subTotalNote,
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              if (savingsAmount > 0.0009)
                _thermalAmountRow(_savingLabel(order), savingsAmount),
              if (allInclusive)
                _thermalAmountRow('Net Amount (Incl. ${CountryTaxHelper.taxName(order.billingCountry, order.billingTaxMode)})', (rawSubtotal - savingsAmount).clamp(0.0, double.infinity)),
              if (order.refundAmount > 0) ...[
                _dashedDivider(),
                _thermalAmountRow('Refunded Amt', order.refundAmount),
                _thermalAmountRow('Net Payable', order.netAmount - order.refundAmount),
              ],
              if (order.loyaltyPointsRedeemed > 0 &&
                  order.loyaltyDiscountAmount > 0)
                pw.Text(
                  'Savings by points redeemed: ${order.loyaltyPointsRedeemed} points (- ${order.loyaltyDiscountAmount.toStringAsFixed(2)})',
                  style: emphasisStyle,
                ),
              if (hasTaxData) _dashedDivider(),
              if (hasTaxData) _thermalAmountRow('Taxable Value', _adjustedItemTaxableTotal(order)),
              if (hasTaxData)
                ...itemGroupedTaxes.map((tax) => _thermalAmountRow(tax.label, tax.taxAmount)),
            ];
          })(),
          ...order.charges.where((charge) => charge.amount > 0).map(
                (charge) => _thermalAmountRow(
                  charge.name,
                  charge.amount,
                ),
              ),
          if (hasTaxData && itemGroupedTaxes.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text('Tax Breakup - Items', style: emphasisStyle),
            pw.SizedBox(height: 3),
            ..._groupedTaxBreakup(order).map(
              (tax) => _thermalTaxSummaryRow(
                tax.label,
                tax.taxableAmount,
                tax.taxAmount,
              ),
            ),
          ],
          if (hasChargeTaxData) ...[
            pw.SizedBox(height: 4),
            pw.Text('Tax Breakup - Charges', style: emphasisStyle),
            pw.SizedBox(height: 3),
            ...chargeGroupedTaxes.map(
              (tax) => _thermalTaxSummaryRow(
                tax.label,
                tax.taxableAmount,
                tax.taxAmount,
              ),
            ),
          ],
          if (roundOff.abs() > 0.0009)
            _thermalAmountRow(
              'Round Off',
              roundOff,
            ),
          if (subscriptionAdjustment > 0.0009)
            _thermalAmountRow('Subscription Adjustment', -subscriptionAdjustment),
          _dashedDivider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('NET PAYABLE', style: grandStyle),
              pw.Text(_money(displayNetPayable), style: grandStyle),
            ],
          ),
          pw.SizedBox(height: 5),
          ...(() {
            final rawStatus = order.status.trim().toUpperCase();
            final rawMode = order.paymentMode.trim().toUpperCase();
            final bool isUnsettled = rawMode == 'UNSETTLED' || rawStatus == 'PRINTED' || rawStatus == 'RUNNING' || (rawStatus == 'DRAFT' && rawMode != 'CREDIT');

            if (isUnsettled) {
              return [
                _thermalMetaRow(
                  'Payment Status',
                  'UNSETTLED / RUNNING',
                  'Amount Paid',
                  _money(order.amountPaid),
                ),
                _thermalMetaRow(
                  'Balance Due',
                  _money(order.balanceDue > 0 ? order.balanceDue : displayNetPayable),
                  '',
                  '',
                ),
                pw.SizedBox(height: 3),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey700, width: 0.5),
                  ),
                  child: pw.Text(
                    '*** AWAITING CASHIER SETTLEMENT ***',
                    style: emphasisStyle.copyWith(fontSize: 8.5),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ];
            }

            final pmts = _calculateActualPayments(order, data.amountReceived);
            final splits = _parseSplitPayments(order);
            if (splits.length > 1) {
              final nonCreditPaid = splits
                  .where((s) => s['method'].toString().toUpperCase() != 'CREDIT' && s['method'].toString().toUpperCase() != 'DUE')
                  .fold<double>(0, (sum, s) => sum + (s['amount'] as double));
              final creditDueAmt = splits
                  .where((s) => s['method'].toString().toUpperCase() == 'CREDIT' || s['method'].toString().toUpperCase() == 'DUE')
                  .fold<double>(0, (sum, s) => sum + (s['amount'] as double));

              return [
                _thermalMetaRow(
                  'Payment Mode',
                  'SPLIT PAYMENT (${splits.length} Modes)',
                  _isRefundedOrder(order)
                      ? 'Refund'
                      : (pmts['refund']! > 0 ? 'Refund (CASH)' : 'Refund'),
                  _money(pmts['refund']!),
                ),
                pw.SizedBox(height: 3),
                pw.Text('--- PAYMENT BREAKDOWN (SPLIT BILL) ---', style: emphasisStyle.copyWith(fontSize: 8.5), textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 2),
                ...splits.map((s) => _thermalMetaRow(
                  '${s['method']}',
                  _money(s['amount']),
                  '',
                  '',
                )),
                if (pmts['advanceCreated']! > 0.009)
                  _thermalMetaRow('Add to Advance', _money(pmts['advanceCreated']!), '', ''),
                if (_refundTimestamp(order).isNotEmpty)
                  _thermalMetaRow('Refunded On', _refundTimestamp(order), '', ''),
                if (nonCreditPaid > 0)
                  _thermalMetaRow('Total Received', _money(nonCreditPaid), '', ''),
                if (creditDueAmt > 0)
                  _thermalMetaRow('Balance Due (Credit)', _money(creditDueAmt), '', ''),
              ];
            }

            if (rawMode == 'CREDIT') {
              final double initialPaid = order.initialAmountPaid > 0
                  ? order.initialAmountPaid
                  : (order.amountPaid > 0 && order.repayments.isEmpty && order.balanceDue > 0 ? order.amountPaid : 0.0);
              final double dueAmt = order.balanceDue > 0 ? order.balanceDue : math.max(0.0, displayNetPayable - initialPaid);

              if (order.repayments.isNotEmpty) {
                final repaymentRows = <pw.Widget>[
                  _thermalMetaRow(
                    'Payment',
                    _displayPaymentMode(order),
                    'Initial Paid',
                    _money(initialPaid),
                  ),
                ];
                for (final rep in order.repayments) {
                  final rMode = (rep['payment_mode'] ?? 'REPAYMENT').toString().toUpperCase();
                  final rAmt = double.tryParse((rep['amount'] ?? 0).toString()) ?? 0.0;
                  repaymentRows.add(_thermalMetaRow(
                    'Repaid ($rMode)',
                    _money(rAmt),
                    '',
                    '',
                  ));
                }
                repaymentRows.add(_thermalMetaRow(
                  'Total Paid',
                  _money(order.amountPaid),
                  'Balance Due',
                  _money(order.balanceDue),
                ));
                return repaymentRows;
              }

              return [
                _thermalMetaRow(
                  'Payment',
                  'CREDIT',
                  _isRefundedOrder(order)
                      ? 'Refund'
                      : (pmts['refund']! > 0 ? 'Refund (CASH)' : 'Refund'),
                  _money(pmts['refund']!),
                ),
                if (initialPaid > 0)
                  _thermalMetaRow(
                    'Received',
                    _money(initialPaid),
                    'Balance Due (Credit)',
                    _money(dueAmt),
                  )
                else
                  _thermalMetaRow(
                    'Balance Due (Credit)',
                    _money(dueAmt),
                    '',
                    '',
                  ),
                if (_refundTimestamp(order).isNotEmpty)
                  _thermalMetaRow('Refunded On', _refundTimestamp(order), '', ''),
              ];
            }

            return [
              _thermalMetaRow(
                'Payment',
                _displayPaymentMode(order),
                _isRefundedOrder(order)
                    ? 'Refund'
                    : (pmts['refund']! > 0 ? 'Refund (CASH)' : 'Refund'),
                _money(pmts['refund']!),
              ),
              if (pmts['advanceCreated']! > 0.009)
                _thermalMetaRow(
                  'Add to Advance',
                  _money(pmts['advanceCreated']!),
                  '',
                  '',
                ),
              if (_refundTimestamp(order).isNotEmpty)
                _thermalMetaRow('Refunded On', _refundTimestamp(order), '', ''),
              if (pmts['received']! > 0)
                _thermalMetaRow(
                  'Received',
                  _money(pmts['received']!),
                  '',
                  '',
                ),
            ];
          })(),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.code128(),
              data: order.saleNo,
              width: 138,
              height: 30,
              drawText: false,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text(order.saleNo, style: emphasisStyle)),
          pw.SizedBox(height: 6),
          if ((order.notes ?? '').trim().isNotEmpty)
            pw.Text(
              'Note: ${order.notes!.trim()}',
              textAlign: pw.TextAlign.center,
            ),
          if ((order.notes ?? '').trim().isNotEmpty) pw.SizedBox(height: 4),

          // --- Custom Thermal Receipt Footer ---
          // UPI QR Code Section (if enabled)
          if ((cfg['show_upi_qr'] ?? (data.property?.printUpiQr == true)) && (data.property?.upiId ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 6 * scale),
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: 'upi://pay?pa=${data.property!.upiId.trim()}&pn=${Uri.encodeComponent(data.property!.upiPayeeName.isNotEmpty ? data.property!.upiPayeeName.trim() : (data.property!.legalName.isNotEmpty ? data.property!.legalName.trim() : data.property!.propertyName.trim()))}&am=${order.netAmount.toStringAsFixed(2)}&tr=${order.saleNo}&cu=INR',
                width: 65 * scale,
                height: 65 * scale,
              ),
            ),
            pw.SizedBox(height: 3 * scale),
            pw.Text('Scan to Pay via UPI', style: emphasisStyle.copyWith(fontSize: 8.5 * scale), textAlign: pw.TextAlign.center),
            pw.Text('UPI ID: ${data.property!.upiId.trim()}', style: bodyStyle.copyWith(fontSize: 8 * scale), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4 * scale),
          ],

          // Bank Details Section (if enabled)
          if ((cfg['show_bank_details'] ?? (data.property?.printBankDetails == true)) && 
              ((data.property?.bankName ?? '').trim().isNotEmpty || 
               (data.property?.bankAccNo ?? '').trim().isNotEmpty)) ...[
            pw.SizedBox(height: 4 * scale),
            pw.Text('--- Bank Details ---', style: emphasisStyle.copyWith(fontSize: 8.5 * scale), textAlign: pw.TextAlign.center),
            pw.Text('Bank: ${data.property!.bankName.trim()}', style: bodyStyle.copyWith(fontSize: 8 * scale), textAlign: pw.TextAlign.center),
            pw.Text('A/c No: ${data.property!.bankAccNo.trim()}', style: bodyStyle.copyWith(fontSize: 8 * scale), textAlign: pw.TextAlign.center),
            if (data.property!.bankIfsc.isNotEmpty)
              pw.Text('IFSC: ${data.property!.bankIfsc.trim()}', style: bodyStyle.copyWith(fontSize: 8 * scale), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 6 * scale),
          ],

          if ((data.termsAndConditions).trim().isNotEmpty) ...[
            pw.SizedBox(height: 4 * scale),
            pw.Text(
              data.termsAndConditions.trim(),
              style: pw.TextStyle(font: regular, fontSize: 8.0 * scale, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 4 * scale),
          ],

          if (data.thankYouMessage.trim().isNotEmpty)
            pw.Text(
              data.thankYouMessage.trim(),
              style: pw.TextStyle(font: bold, fontSize: 9.0 * scale, color: PdfColors.black),
              textAlign: pw.TextAlign.center,
            ),
          
          if (cfg['show_reseller_footer'] ?? true) ...[
            pw.SizedBox(height: 6 * scale),
            pw.Center(
              child: pw.Text(
                '--- ${_resellerFooterText(cfg)} ---',
                style: pw.TextStyle(font: regular, fontSize: 7.5 * scale, color: PdfColors.grey600),
              ),
            ),
          ],
          if (order.luckyDrawVouchers != null && order.luckyDrawVouchers!.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            _buildThermalVoucherTicketEmbedded(order, order.luckyDrawVouchers!, regular, bold, data.property, isCustomerCopy: true),
            pw.SizedBox(height: 8),
            _buildThermalVoucherTicketEmbedded(order, order.luckyDrawVouchers!, regular, bold, data.property, isCustomerCopy: false),
            pw.SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  static String _resellerFooterText(Map<String, dynamic> cfg) {
    String text = '';
    final custom = cfg['reseller_footer_text']?.toString().trim();
    if (custom != null && custom.isNotEmpty) {
      text = custom.startsWith('---') ? custom.replaceAll('---', '').trim() : custom;
    } else {
      final brand = AppBrand.poweredByLabel.trim();
      if (brand.isNotEmpty) {
        text = brand;
      } else {
        final company = AppBrand.companyName.trim();
        if (company.isNotEmpty) {
          text = 'Powered by $company';
        } else {
          text = 'Powered by RetailPOS Cloud';
        }
      }
    }
    // Clean unsupported PDF font unicode characters like bullets '•' to standard ASCII '|'
    return text.replaceAll('•', '|').replaceAll('·', '-').trim();
  }

  static pw.Widget _buildA4Invoice(_InvoiceContext data, pw.MemoryImage? logo) {
    final order = data.order;
    final a4Cfg = data.a4TemplateConfig;
    _currentShowCurrency = (a4Cfg['show_currency_symbol'] == true || a4Cfg['show_currency'] == true);
    final sellerState = data.property?.state ?? '';
    final buyerName = (order.customerName ?? '').trim().isEmpty
        ? 'Walk-in Customer'
        : order.customerName!.trim();
    final amountInWords = _amountInWords(order.netAmount);

    final String a4FontSizeSetting = (a4Cfg['font_size'] ?? 'MEDIUM').toString().toUpperCase();
    double a4Scale = 1.0;
    if (a4FontSizeSetting == 'SMALL') a4Scale = 0.85;
    if (a4FontSizeSetting == 'LARGE') a4Scale = 1.18;

    PdfColor themeColor = PdfColor.fromHex('#0B5CAD');
    final String themeKey = (a4Cfg['theme_color'] ?? 'BLUE').toString().toUpperCase();
    if (themeKey == 'SLATE') themeColor = PdfColor.fromHex('#1E293B');
    if (themeKey == 'EMERALD') themeColor = PdfColor.fromHex('#047857');
    if (themeKey == 'CRIMSON') themeColor = PdfColor.fromHex('#991B1B');

    final bool a4ShowLogo = a4Cfg['show_logo'] ?? true;
    final bool a4ShowAddress = a4Cfg['show_address'] ?? true;
    final bool a4ShowContact = a4Cfg['show_contact'] ?? true;
    final bool a4ShowTaxReg = a4Cfg['show_tax_reg'] ?? true;

    final sellerName = (a4Cfg['header_title']?.toString().trim().isNotEmpty == true)
        ? a4Cfg['header_title'].toString().trim()
        : (data.property?.legalName.isNotEmpty == true
            ? data.property!.legalName
            : data.property?.propertyName ?? AppBrand.productName);
    
    final sellerAddressStr = (a4Cfg['header_subtext']?.toString().trim().isNotEmpty == true)
        ? a4Cfg['header_subtext'].toString().trim()
        : _sellerAddress(data);

    final hasTaxData = _hasTaxData(order);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: pw.EdgeInsets.all(12 * a4Scale),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: themeColor, width: 1.5),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (a4ShowLogo) ...[
                pw.Container(
                  width: 74 * a4Scale,
                  height: 74 * a4Scale,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: themeColor.luminance > 0.5 ? PdfColors.grey400 : themeColor),
                  ),
                  child: logo == null
                      ? pw.Text(
                          'LOGO',
                          style: pw.TextStyle(
                            fontSize: 10 * a4Scale,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        )
                      : pw.Padding(
                          padding: pw.EdgeInsets.all(6 * a4Scale),
                          child: pw.Image(logo, fit: pw.BoxFit.contain),
                        ),
                ),
                pw.SizedBox(width: 12 * a4Scale),
              ],
              pw.Expanded(
                child: pw.Center(
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        _receiptTitle(order, hasTaxData)
                            .replaceFirst('BILL', 'INVOICE')
                            .replaceFirst('RECEIPT', 'INVOICE'),
                        style: pw.TextStyle(
                          fontSize: 20 * a4Scale,
                          fontWeight: pw.FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                      if (data.enableTokenSystem && (order.tokenNo ?? '').trim().isNotEmpty) ...[
                        pw.SizedBox(height: 4 * a4Scale),
                        pw.Container(
                          padding: pw.EdgeInsets.symmetric(horizontal: 10 * a4Scale, vertical: 4 * a4Scale),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.black, width: 1.5),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                          ),
                          child: pw.Text(
                            'TOKEN NO: ${order.tokenNo!.trim()}',
                            style: pw.TextStyle(
                              fontSize: 14 * a4Scale,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12 * a4Scale),
              pw.SizedBox(
                width: 220 * a4Scale,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      sellerName,
                      style: pw.TextStyle(
                        fontSize: 12 * a4Scale,
                        fontWeight: pw.FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                    pw.SizedBox(height: 3 * a4Scale),
                    if (a4ShowAddress && sellerAddressStr.isNotEmpty)
                      pw.Text(sellerAddressStr,
                          style: pw.TextStyle(fontSize: 8.8 * a4Scale)),
                    if (a4ShowContact) ...[
                      if (data.property?.printMobile != false && (data.property?.mobile ?? '').isNotEmpty)
                        pw.Text('Contact: ${data.property!.mobile}',
                            style: pw.TextStyle(fontSize: 8.8 * a4Scale)),
                      if (data.property?.printEmail != false && (data.property?.email ?? '').isNotEmpty)
                        pw.Text('Email: ${data.property!.email}',
                            style: pw.TextStyle(fontSize: 8.8 * a4Scale)),
                      if (data.property?.printWebsite != false && (data.property?.website ?? '').isNotEmpty)
                        pw.Text('Website: ${data.property!.website}',
                            style: pw.TextStyle(fontSize: 8.8 * a4Scale)),
                    ],
                    if (a4ShowTaxReg) ...[
                      pw.Text(
                        '${_taxIdLabel(order.billingCountry)}: ${(a4Cfg['tax_reg_no']?.toString().trim().isNotEmpty == true) ? a4Cfg['tax_reg_no'].toString().trim() : (((data.property?.gstNo ?? '').trim().isEmpty) ? '--' : data.property!.gstNo.trim())}',
                        style: pw.TextStyle(
                          fontSize: 8.8 * a4Scale,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if ((a4Cfg['pan_no']?.toString().trim().isNotEmpty == true) || (data.property?.panNo ?? '').trim().isNotEmpty)
                        pw.Text(
                          '${_businessRegLabel(order.billingCountry)}: ${(a4Cfg['pan_no']?.toString().trim().isNotEmpty == true) ? a4Cfg['pan_no'].toString().trim() : data.property!.panNo.trim()}',
                          style: pw.TextStyle(fontSize: 8.8 * a4Scale),
                        ),
                    ],
                    if ((data.property?.fssaiNo ?? '').trim().isNotEmpty && _isIndiaCountry(order.billingCountry))
                      pw.Text(
                        'FSSAI: ${data.property!.fssaiNo.trim()}',
                        style: pw.TextStyle(fontSize: 8.8 * a4Scale),
                      ),
                    if ((data.property?.drugLicenseNo ?? '').isNotEmpty)
                      pw.Text(
                        'DL No: ${data.property!.drugLicenseNo}',
                        style: pw.TextStyle(
                          fontSize: 8.8 * a4Scale,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    pw.Text(
                      'State: ${sellerState.isEmpty ? '--' : sellerState} / ${data.sellerStateCode ?? '--'}',
                      style: pw.TextStyle(fontSize: 8.8 * a4Scale),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        if (_refundStamp(order).isNotEmpty)
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            margin: const pw.EdgeInsets.only(bottom: 10),
            decoration: pw.BoxDecoration(
              color: order.status == 'CANCELLED' ? PdfColors.red100 : PdfColors.orange100,
              border: pw.Border.all(color: order.status == 'CANCELLED' ? PdfColors.red500 : PdfColors.orange500),
            ),
            child: pw.Center(
              child: pw.Text(
                _refundStamp(order),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: order.status == 'CANCELLED' ? PdfColors.red700 : PdfColors.orange700,
                ),
              ),
            ),
          ),
        if (order.status == 'DRAFT')
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            margin: const pw.EdgeInsets.only(bottom: 10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              border: pw.Border.all(color: PdfColors.grey500),
            ),
            child: pw.Text(
              'Draft copy for preparation only. Final payment and tax invoice pending.',
              style: const pw.TextStyle(fontSize: 9.5),
            ),
          ),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey600),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Invoice Info',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 6),
                      _a4MetaRow(
                        _receiptNumberLabel(order),
                        order.saleNo,
                      ),
                      if (data.enableTokenSystem && !_isRestaurantOrder(order) && (order.tokenNo ?? '').trim().isNotEmpty)
                        _a4MetaRow('Token No', order.tokenNo!.trim()),
                      if (_isActualOrder(order) && order.orderId != null && order.hasBillNo)
                        _a4MetaRow('Order No', '#${order.orderId}'),
                      if (_exchangeAgainstBillNo(order).isNotEmpty)
                        _a4MetaRow('Against Bill No', _exchangeAgainstBillNo(order)),
                      _a4MetaRow(
                        'Invoice Dt/Tm',
                        formatTzDateTime(order.saleDate),
                      ),
                      _a4MetaRow(
                        'Cashier/Terminal',
                        '${data.cashierId ?? data.cashierName}${(data.terminalNo ?? '').trim().isNotEmpty ? ' / ${data.terminalNo}' : ''}',
                      ),
                      _a4MetaRow('Payment Method', _displayPaymentMode(order)),
                      if (_refundTimestamp(order).isNotEmpty)
                        _a4MetaRow('Refunded On', _refundTimestamp(order)),
                      _a4MetaRow(
                        'Place of Supply',
                        data.buyerState != null && data.buyerState!.isNotEmpty
                            ? '${_titleCase(data.buyerState!)}${data.buyerStateCode != null ? ' / ${data.buyerStateCode}' : ''}'
                            : '-',
                      ),
                    ],
                  ),
                ),
              ),
              pw.Container(
                width: 1,
                color: PdfColors.grey600,
                height: 110,
              ),
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Billed To',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 6),
                      _a4MetaRow('Customer', buyerName),
                      _a4MetaRow(
                        'Address',
                        _cleanAddressForPrint(order.customerAddress).isEmpty
                            ? '--'
                            : _cleanAddressForPrint(order.customerAddress),
                      ),
                      _a4MetaRow(
                        'Phone',
                        (order.customerPhone ?? '').trim().isEmpty
                            ? '--'
                            : order.customerPhone!.trim(),
                      ),
                      _a4MetaRow(
                        'GSTIN',
                        (order.customerGstin ?? '').trim().isEmpty
                            ? 'URD'
                            : order.customerGstin!.trim(),
                      ),
                      if ((order.doctorName ?? '').trim().isNotEmpty)
                        _a4MetaRow('Doctor', order.doctorName!.trim()),
                      if ((order.patientName ?? '').trim().isNotEmpty)
                        _a4MetaRow('Patient', order.patientName!.trim()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        _buildA4ItemsTable(order, data.showBrandName),
        pw.SizedBox(height: 10),
        // Amount in Words
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(text: 'Amount in Words: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.blueGrey900)),
                pw.TextSpan(text: amountInWords, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 8),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Payment Details Box (Bank Transfer + UPI QR side-by-side)
                  if ((data.property?.printBankDetails == true && 
                        ((data.property?.bankName ?? '').trim().isNotEmpty || 
                         (data.property?.bankAccNo ?? '').trim().isNotEmpty)) ||
                      (data.property?.printUpiQr == true && (data.property?.upiId ?? '').trim().isNotEmpty)) ...[
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        color: PdfColors.grey50,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('PAYMENT DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.blueGrey800)),
                          pw.SizedBox(height: 5),
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              // Bank Details
                              if (data.property?.printBankDetails == true && 
                                  ((data.property?.bankName ?? '').trim().isNotEmpty || 
                                   (data.property?.bankAccNo ?? '').trim().isNotEmpty))
                                pw.Expanded(
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('Bank Transfer (NEFT/IMPS):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColors.grey700)),
                                      pw.SizedBox(height: 2),
                                      pw.Text('Bank: ${data.property!.bankName.trim()}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800)),
                                      pw.Text('A/c No: ${data.property!.bankAccNo.trim()}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800)),
                                      if (data.property!.bankIfsc.isNotEmpty)
                                        pw.Text('IFSC: ${data.property!.bankIfsc.trim()}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800)),
                                    ],
                                  ),
                                ),

                              // Divider between NEFT and UPI QR
                              if (data.property?.printBankDetails == true && 
                                  ((data.property?.bankName ?? '').trim().isNotEmpty || 
                                   (data.property?.bankAccNo ?? '').trim().isNotEmpty) &&
                                  data.property?.printUpiQr == true && 
                                  (data.property?.upiId ?? '').trim().isNotEmpty)
                                pw.Container(width: 0.5, height: 48, color: PdfColors.grey300, margin: const pw.EdgeInsets.symmetric(horizontal: 10)),

                              // UPI QR Code
                              if (data.property?.printUpiQr == true && (data.property?.upiId ?? '').trim().isNotEmpty)
                                pw.Row(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.BarcodeWidget(
                                      barcode: pw.Barcode.qrCode(),
                                      data: 'upi://pay?pa=${data.property!.upiId.trim()}&pn=${Uri.encodeComponent(data.property!.upiPayeeName.isNotEmpty ? data.property!.upiPayeeName.trim() : sellerName)}&am=${order.netAmount.toStringAsFixed(2)}&tr=${order.saleNo}&cu=INR',
                                      width: 48,
                                      height: 48,
                                    ),
                                    pw.SizedBox(width: 8),
                                    pw.Column(
                                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text('Scan to Pay (UPI):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColors.grey700)),
                                        pw.SizedBox(height: 2),
                                        pw.Text('UPI ID: ${data.property!.upiId.trim()}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800)),
                                        if (data.property!.upiPayeeName.isNotEmpty)
                                          pw.Text('Payee: ${data.property!.upiPayeeName.trim()}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                                      ],
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 8),
                  ],

                  // Terms & Conditions Block
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Terms & Conditions:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.blueGrey800)),
                      pw.SizedBox(height: 2),
                      ...() {
                        final terms = (data.property?.termsAndConditions.trim().isNotEmpty == true)
                            ? data.property!.termsAndConditions
                            : data.termsAndConditions;
                        return terms.split('\n').where((t) => t.trim().isNotEmpty).map(
                              (term) => pw.Text(
                                term.trim(),
                                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                              ),
                            );
                      }(),
                      if ((order.notes ?? '').trim().isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Note: ${order.notes!.trim()}',
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.SizedBox(
              width: 240,
              child: _buildTotalsBox(order),
            ),
          ],
        ),
        pw.SizedBox(height: 35),
        
        // Professional Signature Lines
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Customer Signature
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(width: 130, height: 0.5, color: PdfColors.grey400),
                pw.SizedBox(height: 3),
                pw.Text('Customer Signature', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ],
            ),
            // Authorized Signatory
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (data.property?.printDigitalSignature == true) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const pw.EdgeInsets.only(bottom: 2),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.green600, width: 0.8),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                      color: PdfColors.green50,
                    ),
                    child: pw.Text(
                      'DIGITALLY SIGNED',
                      style: pw.TextStyle(color: PdfColors.green700, fontSize: 6, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Text('Cashier: ${data.cashierName}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                  pw.SizedBox(height: 2),
                ] else ...[
                  pw.SizedBox(height: 18),
                ],
                pw.Container(width: 150, height: 0.5, color: PdfColors.grey400),
                pw.SizedBox(height: 3),
                pw.Text(data.authorizedSignatureLabel, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.blueGrey900)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static bool _isInterStateSale(SaleOrder order) {
    if (order.igstAmount > 0) return true;
    final mode = order.billingTaxMode.trim().toUpperCase();
    if (mode == 'IGST' || mode == 'INTER_STATE') return true;
    return false;
  }

  static pw.Widget _buildA4ItemsTable(SaleOrder order, bool showBrand) {
    final hasTaxData = _hasTaxData(order);
    final bool isIndia = CountryTaxHelper.isIndiaCountry(order.billingCountry);
    final bool isInterState = isIndia && _isInterStateSale(order);
    final String taxName = CountryTaxHelper.taxName(order.billingCountry, order.billingTaxMode);

    final bool hasExplicitSingleTax = order.items.any((item) =>
        item.taxGroup != null ||
        item.taxType.toUpperCase().contains('SALES_TAX') ||
        item.taxType.toUpperCase().contains('VAT') ||
        item.taxType.toUpperCase().contains('COMPOSITE') ||
        item.taxBreakup.any((tb) =>
            tb.label.toUpperCase().contains('SALES TAX') ||
            tb.label.toUpperCase().contains('VAT') ||
            tb.code.toUpperCase().contains('SALES_TAX') ||
            tb.code.toUpperCase().contains('VAT')));

    final bool isDualGst = isIndia &&
        !isInterState &&
        order.billingTaxMode != 'VAT' &&
        order.billingTaxMode != 'SALES_TAX' &&
        order.billingTaxMode != 'SINGLE' &&
        !hasExplicitSingleTax;

    final headers = hasTaxData
        ? (isDualGst
            ? [
                'S.No',
                'Description of Goods',
                'HSN / SAC Code',
                'Qty',
                'Unit',
                'Unit Rate',
                'Discount',
                'Taxable Value',
                'CGST (Rate% & Amt)',
                'SGST/UTGST (Rate% & Amt)',
                'Total Amount',
              ]
            : [
                'S.No',
                'Description of Goods',
                'HSN / SAC Code',
                'Qty',
                'Unit',
                'Unit Rate',
                'Discount',
                'Taxable Value',
                '${isInterState ? 'IGST' : (taxName.isNotEmpty ? taxName : 'Tax')} (Rate% & Amt)',
                'Total Amount',
              ])
        : [
            'S.No',
            'Description of Goods',
            'HSN / SAC Code',
            'Qty',
            'Unit',
            'Unit Rate',
            'Discount',
            'Amount',
          ];

    final data = order.items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      bool isReturned = false;
      bool isExchanged = false;
      if (order.returnedItems != null && order.returnedItems!.isNotEmpty) {
        for (var rit in order.returnedItems!) {
          if (rit['item_id']?.toString() == item.itemId.toString() ||
              rit['item_name']?.toString().toUpperCase() == item.itemName.toUpperCase() ||
              rit['item_code']?.toString() == item.itemCode) {
            if (order.returnType == 'EXCHANGE') {
              isExchanged = true;
            } else {
              isReturned = true;
            }
          }
        }
      }
      final suffix = isReturned ? ' (REFUNDED)' : (isExchanged ? ' (EXCHANGED)' : '');

      final brandStr = showBrand && item.brand != null && item.brand!.trim().isNotEmpty
          ? '${item.brand!.trim()} - '
          : '';
      final name =
          (item.isSchemeFree || item.isAdvanceFree) ? '$brandStr${item.itemName} (FREE)$suffix' : '$brandStr${item.itemName}$suffix';
      if (hasTaxData) {
        if (isDualGst) {
          final cgstRate = _taxRate(order, item, 'CGST');
          final cgstAmt = _taxAmount(order, item, 'CGST');
          final sgstRate = _taxRate(order, item, 'SGST');
          final sgstAmt = _taxAmount(order, item, 'SGST');

          // Fallback if item has tax but wasn't broken down into CGST/SGST
          final effCgstRate = (cgstRate == '-' && item.taxPercent > 0)
              ? '${_formatTaxPercent(item.taxPercent / 2)}%'
              : cgstRate;
          final effCgstAmt = (cgstAmt <= 0 && item.taxAmount > 0)
              ? item.taxAmount / 2
              : cgstAmt;
          final effSgstRate = (sgstRate == '-' && item.taxPercent > 0)
              ? '${_formatTaxPercent(item.taxPercent / 2)}%'
              : sgstRate;
          final effSgstAmt = (sgstAmt <= 0 && item.taxAmount > 0)
              ? item.taxAmount / 2
              : sgstAmt;

          return [
            '${index + 1}',
            name,
            item.hsnSacCode.isEmpty ? item.itemCode : item.hsnSacCode,
            _qty(item.qty),
            item.unit,
            item.isTaxInclusive ? '${_money(_displayRate(item))} (Incl.)' : _money(_displayRate(item)),
            _money(item.lineDiscount),
            _money(_taxableAmountForItem(item)),
            item.taxPercent <= 0 ? 'NILL' : '$effCgstRate / ${_money(effCgstAmt)}${item.isTaxInclusive ? ' (Incl.)' : ''}',
            item.taxPercent <= 0 ? 'NILL' : '$effSgstRate / ${_money(effSgstAmt)}${item.isTaxInclusive ? ' (Incl.)' : ''}',
            _money(_displayItemLineTotal(item)),
          ];
        } else {
          return [
            '${index + 1}',
            name,
            item.hsnSacCode.isEmpty ? item.itemCode : item.hsnSacCode,
            _qty(item.qty),
            item.unit,
            item.isTaxInclusive ? '${_money(_displayRate(item))} (Incl.)' : _money(_displayRate(item)),
            _money(item.lineDiscount),
            _money(_taxableAmountForItem(item)),
            item.taxPercent <= 0 ? 'NILL' : '${_formatTaxPercent(item.taxPercent)}% / ${_money(item.taxAmount)}${item.isTaxInclusive ? ' (Incl.)' : ''}',
            _money(_displayItemLineTotal(item)),
          ];
        }
      }
      return [
        '${index + 1}',
        name,
        item.hsnSacCode.isEmpty ? item.itemCode : item.hsnSacCode,
        _qty(item.qty),
        item.unit,
        item.isTaxInclusive ? '${_money(_displayRate(item))} (Incl.)' : _money(_displayRate(item)),
        _money(item.lineDiscount),
        _money(_displayItemLineTotal(item)),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 7.3),
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      columnWidths: {
        0: const pw.FixedColumnWidth(22),
        1: const pw.FlexColumnWidth(3.0),
        2: const pw.FixedColumnWidth(48),
        3: const pw.FixedColumnWidth(26),
        4: const pw.FixedColumnWidth(24),
        5: const pw.FixedColumnWidth(42),
        6: const pw.FixedColumnWidth(48),
        7: const pw.FixedColumnWidth(54),
        if (hasTaxData && isDualGst) ...{
          8: const pw.FixedColumnWidth(60),
          9: const pw.FixedColumnWidth(60),
          10: const pw.FixedColumnWidth(56),
        } else if (hasTaxData && !isDualGst) ...{
          8: const pw.FixedColumnWidth(70),
          9: const pw.FixedColumnWidth(56),
        },
      },
    );
  }

  static pw.Widget _buildTotalsBox(SaleOrder order) {
    final hasTaxData = _hasTaxData(order);
    final roundOff = _billRoundOff(order);
    final subscriptionAdjustment = _subscriptionAdjustmentAmount(order);
    final savingsAmount = _displaySavingsAmount(order);
    final savingsLabel = _savingLabel(order);
    final itemGroupedTaxes = _adjustedItemGroupedTaxes(order, _groupedTaxBreakup(order));
    final chargeGroupedTaxes = _groupedChargeTaxBreakup(order);
    final chargeTaxSummaryTotal = _groupTaxTotal(chargeGroupedTaxes);
    final bool isIndia = CountryTaxHelper.isIndiaCountry(order.billingCountry);
    final cgstTotal = _taxAmountFromBreakup(itemGroupedTaxes, 'CGST') +
        _taxAmountFromBreakup(chargeGroupedTaxes, 'CGST');
    final sgstTotal = _taxAmountFromBreakup(itemGroupedTaxes, 'SGST') +
        _taxAmountFromBreakup(chargeGroupedTaxes, 'SGST');
    final igstTotal = _taxAmountFromBreakup(itemGroupedTaxes, 'IGST') +
        _taxAmountFromBreakup(chargeGroupedTaxes, 'IGST');
    final summaryTaxTotal = isIndia
        ? (cgstTotal + sgstTotal + igstTotal)
        : (_groupTaxTotal(itemGroupedTaxes) + chargeTaxSummaryTotal);
    final displayNetPayable = _displayNetPayable(
      order,
      chargeTaxTotal: chargeTaxSummaryTotal,
      summaryTaxTotal: summaryTaxTotal,
      subscriptionAdjustment: subscriptionAdjustment,
    );
    final bool allInclusive = order.items.isNotEmpty && order.items.every((item) => item.isTaxInclusive);
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500),
      ),
      child: pw.Column(
        children: [
          if (allInclusive) ...[
            _a4AmountRow(
              'Subtotal (Incl. GST)',
              order.items.fold<double>(0, (sum, item) => sum + (item.rate > 0 ? (item.qty * item.rate) : (item.qty * _displayRate(item)))),
            ),
            if (savingsAmount > 0.0009)
              _a4AmountRow(savingsLabel, savingsAmount),
            _a4AmountRow(
              'Net Amount (Incl. GST)',
              order.items.fold<double>(0, (sum, item) => sum + (item.rate > 0 ? (item.qty * item.rate) : (item.qty * _displayRate(item)))) - savingsAmount,
            ),
            if (order.loyaltyPointsRedeemed > 0 &&
                order.loyaltyDiscountAmount > 0)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Text(
                  'Savings by points redeemed: ${order.loyaltyPointsRedeemed} points (- ${order.loyaltyDiscountAmount.toStringAsFixed(2)})',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            if (hasTaxData) _a4AmountRow('Taxable Value', _adjustedItemTaxableTotal(order)),
            if (hasTaxData)
              ...itemGroupedTaxes.map((tax) => _a4AmountRow('Total ${tax.label} Amount', tax.taxAmount)),
          ] else ...[
            _a4AmountRow(
              'Subtotal',
              _grossItemsSubtotal(order) > 0.0009
                  ? _grossItemsSubtotal(order)
                  : (order.subTotal > 0.0009 ? order.subTotal : _adjustedItemTaxableTotal(order)),
            ),
            if (savingsAmount > 0.0009)
              _a4AmountRow(savingsLabel, savingsAmount),
            if (order.loyaltyPointsRedeemed > 0 &&
                order.loyaltyDiscountAmount > 0)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Text(
                  'Savings by points redeemed: ${order.loyaltyPointsRedeemed} points (- ${order.loyaltyDiscountAmount.toStringAsFixed(2)})',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            if (hasTaxData) _a4AmountRow('Taxable Value', _adjustedItemTaxableTotal(order)),
            if (hasTaxData)
              ...itemGroupedTaxes.map((tax) => _a4AmountRow('Total ${tax.label} Amount', tax.taxAmount)),
          ],
          if (roundOff.abs() > 0.0009)
            _a4AmountRow(
              'Round Off',
              roundOff,
            ),
          if (subscriptionAdjustment > 0.0009)
            _a4AmountRow('Subscription Adjustment', -subscriptionAdjustment),
          pw.Divider(height: 10),
          _a4AmountRow('Grand Total', displayNetPayable, bold: true),
          if (_isRefundedOrder(order)) ...[
            pw.Divider(height: 10),
            _a4AmountRow('Refunded Amount', _refundAmountForDisplay(order)),
            _a4AmountRow(
              'Net Payable',
              displayNetPayable - _refundAmountForDisplay(order),
              bold: true,
            ),
          ],
          ...(() {
            final rawMode = order.paymentMode.trim().toUpperCase();
            final splits = _parseSplitPayments(order);
            if (splits.length > 1) {
              final nonCreditPaid = splits
                  .where((s) => s['method'].toString().toUpperCase() != 'CREDIT' && s['method'].toString().toUpperCase() != 'DUE')
                  .fold<double>(0, (sum, s) => sum + (s['amount'] as double));
              final creditDueAmt = splits
                  .where((s) => s['method'].toString().toUpperCase() == 'CREDIT' || s['method'].toString().toUpperCase() == 'DUE')
                  .fold<double>(0, (sum, s) => sum + (s['amount'] as double));
              final pmts = _calculateActualPayments(order);
              return [
                pw.Divider(height: 10),
                _a4ValueRow('Payment Mode', 'SPLIT (${splits.length} Modes)', bold: true),
                ...splits.map((s) => _a4AmountRow('  - ${s['method']}', s['amount'] as double)),
                if (nonCreditPaid > 0) _a4AmountRow('Total Received', nonCreditPaid, bold: true),
                if (creditDueAmt > 0) _a4AmountRow('Balance Due (Credit)', creditDueAmt, bold: true),
                if (pmts['refund']! > 0) _a4AmountRow('Refund (CASH)', pmts['refund']!),
                if (pmts['advanceCreated']! > 0.009) _a4AmountRow('Added to Advance', pmts['advanceCreated']!),
              ];
            }
            if (rawMode == 'CREDIT') {
              final double initialPaid = order.initialAmountPaid > 0
                  ? order.initialAmountPaid
                  : (order.amountPaid > 0 && order.repayments.isEmpty && order.balanceDue > 0 ? order.amountPaid : 0.0);
              final double dueAmt = order.balanceDue > 0 ? order.balanceDue : math.max(0.0, displayNetPayable - initialPaid);
              return [
                pw.Divider(height: 10),
                _a4ValueRow('Payment Mode', 'CREDIT', bold: true),
                if (initialPaid > 0) _a4AmountRow('Received', initialPaid),
                _a4AmountRow('Balance Due (Credit)', dueAmt, bold: true),
              ];
            }
            final pmts = _calculateActualPayments(order);
            return [
              if (pmts['received']! > 0) ...[
                pw.Divider(height: 10),
                _a4AmountRow(
                  order.paymentMode.isNotEmpty
                      ? 'Received (${order.paymentMode})'
                      : 'Received',
                  pmts['received']!,
                ),
              ],
              if (pmts['refund']! > 0)
                _a4AmountRow('Refund (CASH)', pmts['refund']!),
              if (pmts['advanceCreated']! > 0.009)
                _a4AmountRow('Added to Advance', pmts['advanceCreated']!),
            ];
          })(),
        ],
      ),
    );
  }

  static String _savingLabel(SaleOrder order) {
    if (_couponSavingsAmount(order) > 0.0009) {
      return 'Coupon Discount';
    }
    if (order.schemeDiscount > 0.0009) {
      return 'Scheme Discount';
    }
    return 'Total Savings';
  }

  static bool _isIndiaCountry(String? country) {
    if (country == null || country.trim().isEmpty) {
      return CurrencyService.symbol == '₹' || CurrencyService.code == 'INR';
    }
    final c = country.trim().toLowerCase();
    if (c == 'usa' || c == 'united states' || c == 'kenya' || c == 'uk' || c == 'united kingdom' || c == 'uae') {
      return false;
    }
    if (c == 'india') return true;
    return CurrencyService.symbol == '₹' || CurrencyService.code == 'INR';
  }

  static String _taxIdLabel([String? country]) {
    final c = (country ?? '').trim().toLowerCase();
    if (c == 'usa' || c == 'united states') return 'Tax ID';
    if (c == 'kenya') return 'PIN';
    if (c == 'uk' || c == 'united kingdom') return 'VAT Reg No';
    if (c == 'uae') return 'TRN';
    if (c == 'india' || _isIndiaCountry(country)) return 'GSTIN';
    if (CurrencyService.symbol == '\$') return 'Tax ID';
    if (CurrencyService.code == 'KES') return 'PIN';
    if (CurrencyService.symbol == '£') return 'VAT Reg No';
    if (CurrencyService.code == 'AED') return 'TRN';
    return 'Tax ID';
  }

  static String _businessRegLabel([String? country]) {
    final c = (country ?? '').trim().toLowerCase();
    if (c == 'usa' || c == 'united states') return 'State Tax ID';
    if (c == 'kenya') return 'Business Reg No';
    if (c == 'uk' || c == 'united kingdom') return 'CRN';
    if (c == 'uae') return 'Trade License';
    if (c == 'india' || _isIndiaCountry(country)) return 'PAN';
    if (CurrencyService.symbol == '\$') return 'State Tax ID';
    if (CurrencyService.code == 'KES') return 'Business Reg No';
    if (CurrencyService.symbol == '£') return 'CRN';
    if (CurrencyService.code == 'AED') return 'Trade License';
    return 'State Tax ID';
  }

  static bool _isExchangeOrder(SaleOrder order) {
    final paymentMode = order.paymentMode.trim().toUpperCase();
    return order.returnType == 'EXCHANGE' || paymentMode == 'EXCHANGE';
  }

  static String _receiptTitle(SaleOrder order, bool hasTaxData) {
    if (_isExchangeOrder(order)) {
      return 'EXCHANGE RECEIPT';
    }
    if (order.status == 'CANCELLED') {
      return 'CANCELLED BILL';
    }
    if (_isRefundedOrder(order)) {
      return 'REFUNDED BILL';
    }
    final isDraft = order.status == 'DRAFT' ||
        order.saleNo.trim().toUpperCase().startsWith('DRAFT-');
    if (isDraft) {
      return 'DRAFT / ESTIMATE BILL';
    }
    return hasTaxData ? 'TAX INVOICE' : 'INVOICE';
  }

  static String _receiptNumberLabel(SaleOrder order) {
    final isDraft = order.status == 'DRAFT' ||
        order.saleNo.trim().toUpperCase().startsWith('DRAFT-');
    if (isDraft) {
      return 'Draft No';
    }
    if (order.hasBillNo) {
      return 'Bill No';
    }
    return 'Order No';
  }

  static List<Map<String, dynamic>> _parseSplitPayments(SaleOrder order) {
    final rawStatus = order.status.trim().toUpperCase();
    final rawMode = order.paymentMode.trim().toUpperCase();
    if (rawMode == 'UNSETTLED' || rawStatus == 'PRINTED' || rawStatus == 'RUNNING' || rawStatus == 'DRAFT') {
      return [];
    }

    final List<Map<String, dynamic>> result = [];
    String ref = (order.paymentReference ?? '').trim();
    if (ref.startsWith('POSPAY:')) {
      ref = ref.substring(7).trim();
    }

    if (ref.startsWith('[') && ref.endsWith(']')) {
      try {
        final List decoded = jsonDecode(ref);
        for (final item in decoded) {
          if (item is Map) {
            final String method = (item['method'] ?? item['mode'] ?? 'CASH').toString().toUpperCase().trim();
            final double amt = double.tryParse((item['amount'] ?? 0).toString()) ?? 0.0;
            if (amt > 0) {
              result.add({'method': method, 'amount': amt});
            }
          }
        }
      } catch (_) {}
    }

    if (result.isEmpty && (order.notes ?? '').contains('Payment:')) {
      try {
        final notesStr = order.notes!;
        final pIdx = notesStr.indexOf('Payment:');
        if (pIdx != -1) {
          final pSub = notesStr.substring(pIdx + 8).split('\n').first;
          final parts = pSub.contains(',') ? pSub.split(',') : pSub.split('|');
          for (final part in parts) {
            final cleanPart = part.trim();
            if (cleanPart.toLowerCase().contains('retail round off') || cleanPart.toLowerCase().contains('round off')) {
              continue;
            }
            final tokens = cleanPart.split(RegExp(r'\s+'));
            if (tokens.length >= 2) {
              final String mode = tokens.first.toUpperCase().trim();
              final double amt = double.tryParse(tokens.last.replaceAll(',', '')) ?? 0.0;
              if (amt > 0 && mode != 'RETAIL') {
                result.add({'method': mode, 'amount': amt});
              }
            }
          }
        }
      } catch (_) {}
    }

    return result;
  }

  static String _displayPaymentMode(SaleOrder order) {
    final rawStatus = order.status.trim().toUpperCase();
    final rawMode = order.paymentMode.trim().toUpperCase();
    if (rawMode == 'UNSETTLED' || rawStatus == 'PRINTED' || rawStatus == 'RUNNING' || (rawStatus == 'DRAFT' && rawMode != 'CREDIT')) {
      return 'UNSETTLED (Awaiting Payment)';
    }
    if (_isExchangeOrder(order)) {
      return 'EXCHANGE';
    }
    final splits = _parseSplitPayments(order);
    if (splits.length > 1) {
      return 'SPLIT PAYMENT (${splits.length} Modes)';
    }
    if (rawMode == 'CREDIT') {
      if (order.balanceDue <= 0.009) {
        return 'CREDIT (FULLY REPAID)';
      } else if (order.repayments.isNotEmpty || order.amountPaid > (order.initialAmountPaid > 0 ? order.initialAmountPaid : 0)) {
        return 'CREDIT (PARTIALLY REPAID)';
      }
    }
    return rawMode;
  }

  static String _exchangeAgainstBillNo(SaleOrder order) {
    return (order.exchangeAgainstBillNo ?? '').trim();
  }

  static bool _isActualOrder(SaleOrder order) {
    // 1. Table order or KOT order is a restaurant order
    if (order.tableId != null) return true;
    if (order.kotIds != null && order.kotIds!.isNotEmpty) return true;

    final type = order.orderType.toUpperCase().trim();
    final source = (order.saleSource ?? '').toUpperCase().trim();

    // 2. Check if explicitly an App or Online or Delivery or Restaurant order
    final isAppOrOnline = type.contains('APP') ||
        type.contains('ONLINE') ||
        type.contains('SWIGGY') ||
        type.contains('ZOMATO') ||
        type.contains('DELIVERY') ||
        type.contains('UBER') ||
        source.contains('APP') ||
        source.contains('ONLINE');

    final isRestaurant = type.contains('DINE') ||
        type.contains('TABLE') ||
        type.contains('ROOM') ||
        type.contains('KOT');

    if (isAppOrOnline || isRestaurant) {
      return true;
    }

    // Otherwise, Retail / Store / Counter / POS sales return false (hide Order No)
    return false;
  }

  static bool _isRestaurantOrder(SaleOrder order) {
    if (order.tableId != null) return true;
    if (order.kotIds != null && order.kotIds!.isNotEmpty) return true;
    final type = order.orderType.toUpperCase().trim();
    return type.contains('DINE') || type.contains('TABLE') || type.contains('ROOM') || type.contains('KOT') || type.contains('RESTAURANT');
  }

  static String _refundStamp(SaleOrder order) {
    if (order.status == 'CANCELLED') {
      return '*** CANCELLED ***';
    }
    if (_isExchangeOrder(order)) {
      return '*** EXCHANGED ***';
    }
    if (_isRefundedOrder(order)) {
      return '*** REFUNDED ***';
    }
    return '';
  }

  static String _refundTimestamp(SaleOrder order) {
    final dt = order.refundPaidAt;
    if (dt == null) return '';
    return formatTzDateTime(dt);
  }

  static bool _isRefundedOrder(SaleOrder order) {
    final refundStatus = _refundStatus(order);
    return refundStatus == 'REFUNDED' ||
        refundStatus == 'PARTIALLY_REFUNDED' ||
        refundStatus == 'PAID' ||
        order.refundAmount > 0 ||
        order.refundPaidAt != null;
  }

  static String _refundStatus(SaleOrder order) {
    return (order.refundStatus ?? '').trim().toUpperCase();
  }

  static double _refundAmountForDisplay(SaleOrder order, [double? fallback]) {
    if (order.refundAmount > 0) {
      return order.refundAmount;
    }
    if (_isRefundedOrder(order) && (fallback ?? 0) > 0) {
      return fallback!;
    }
    if (_isRefundedOrder(order)) {
      return order.netAmount;
    }
    return order.changeAmount > 0 ? order.changeAmount : (fallback ?? 0.0);
  }

  static Map<String, double> _calculateActualPayments(SaleOrder order, [double? fallbackAmountReceived]) {
    final mode = order.paymentMode.trim().toUpperCase();
    double totalReceived = 0.0;
    if (mode == 'CREDIT') {
      totalReceived = order.initialAmountPaid > 0
          ? order.initialAmountPaid
          : (order.repayments.isNotEmpty ? order.amountPaid : 0.0);
    } else {
      totalReceived = fallbackAmountReceived ?? order.amountPaid;
    }

    final ref = (order.paymentReference ?? '').trim();
    if (ref.startsWith('POSPAY:')) {
      try {
        final rawJson = ref.substring(7);
        final dynamic decoded = jsonDecode(rawJson);
        if (decoded is List) {
          double sum = 0;
          for (final entry in decoded) {
            if (entry is Map) {
              final m = (entry['method'] ?? entry['mode'] ?? '').toString().toUpperCase().trim();
              if (m != 'CREDIT' && m != 'DUE') {
                sum += double.tryParse((entry['amount'] ?? 0).toString()) ?? 0.0;
              }
            }
          }
          if (sum > 0 || decoded.isNotEmpty) {
            totalReceived = sum;
          }
        }
      } catch (_) {}
    }

    final netPayable = order.netAmount;
    final refund = order.changeAmount;
    final advanceCreated = math.max(totalReceived - netPayable - refund, 0.0);

    return {
      'received': totalReceived,
      'refund': refund,
      'advanceCreated': advanceCreated,
    };
  }

  static bool _hasTaxData(SaleOrder order) {
    if (order.totalTax > 0.0009 ||
        order.cgstAmount > 0.0009 ||
        order.sgstAmount > 0.0009 ||
        order.igstAmount > 0.0009 ||
        order.chargeTaxTotal > 0.0009) {
      return true;
    }
    return _sourceTaxBreakup(order).any((tax) => tax.taxAmount.abs() > 0.0009) ||
        (order.items.any((item) => item.taxPercent > 0) && _adjustedItemTaxableTotal(order) > 0.0009);
  }

  static double _billRoundOff(SaleOrder order) {
    if (order.roundOffAmount.abs() > 0.0009 && order.roundOffAmount.abs() <= 0.99) {
      return order.roundOffAmount;
    }
    final computedTotal = _displayNetPayable(order);
    final diff = computedTotal - computedTotal.roundToDouble();
    if (diff.abs() > 0.50) {
      return 0.0;
    }
    return double.parse(diff.toStringAsFixed(2));
  }

  static pw.Widget _partyCard({
    required String title,
    required List<String> lines,
  }) {
    final filteredLines = lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          ...filteredLines.map(
            (line) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(line, style: const pw.TextStyle(fontSize: 9)),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _thermalItemRow(SaleItem item, SaleOrder order, bool showBrand) {
    bool isReturned = false;
    bool isExchanged = false;
    if (order.returnedItems != null && order.returnedItems!.isNotEmpty) {
      for (var rit in order.returnedItems!) {
        if (rit['item_id']?.toString() == item.itemId.toString() ||
            rit['item_name']?.toString().toUpperCase() == item.itemName.toUpperCase() ||
            rit['item_code']?.toString() == item.itemCode) {
          if (order.returnType == 'EXCHANGE') {
            isExchanged = true;
          } else {
            isReturned = true;
          }
        }
      }
    }
    final suffix = isReturned ? ' (REFUNDED)' : (isExchanged ? ' (EXCHANGED)' : '');

    final hsnOrCode = item.hsnSacCode.trim().isNotEmpty
        ? item.hsnSacCode.trim()
        : item.itemCode.trim();

    // 1. Group Qty, Unit, and Rate together beautifully
    final qtyUnitRate =
        '${_qty(item.qty)} ${item.unit.trim()} x ${_money(_displayRate(item))}${item.isTaxInclusive ? ' (Incl.)' : ''}';

    double itemDiscount = item.lineDiscount;
    if (itemDiscount <= 0 && !item.isSchemeFree && !item.isAdvanceFree) {
      final double grossExclusive = item.isTaxInclusive
          ? (item.qty * item.rate) / (1 + item.taxPercent / 100)
          : (item.qty * item.rate);
      final diff = grossExclusive - item.taxableAmount;
      if (diff > 0.01) {
        itemDiscount = diff;
      }
    }

    // 2. Build the secondary detail string separated by pipes (|) for a clean look
    final detailParts = <String>[
      if (hsnOrCode.isNotEmpty) 'HSN $hsnOrCode',
      qtyUnitRate,
      if (item.isSchemeFree || item.isAdvanceFree) 'FREE',
      if (item.taxPercent > 0)
        '${_taxPrefix(order, item)} ${_formatTaxPercent(item.taxPercent)}%${item.isTaxInclusive ? ' (Incl.)' : ''}'
            '${item.taxAmount > 0 ? ' = ${_money(item.taxAmount)}' : ''}'
      else
        '${_taxPrefix(order, item)} NILL',
      if (itemDiscount > 0.01) 'Disc ${_money(itemDiscount)}',
    ];

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3.0),
      // Switching from Table to Column+Row prevents layout crashes on thermal paper
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Top Row: Item Name (Expands) and Line Total (Right Aligned)
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  (item.isSchemeFree || item.isAdvanceFree)
                      ? '${showBrand && item.brand != null && item.brand!.trim().isNotEmpty ? '${item.brand!.trim()} - ' : ''}${item.itemName.trim()} (FREE)$suffix'
                      : '${showBrand && item.brand != null && item.brand!.trim().isNotEmpty ? '${item.brand!.trim()} - ' : ''}${item.itemName.trim()}$suffix',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8.7,
                    color: _thermalPrimary,
                  ),
                  softWrap: true,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                _money(_displayItemLineTotal(item)),
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8.7,
                  color: _thermalPrimary,
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 1.5), // Tiny gap between name and details

          // Bottom Row: The details (HSN, Qty + Unit + Rate, Taxes, etc.)
          pw.Text(
            detailParts
                .join('  |  '), // Pipes make it easy to read on narrow paper
            style: pw.TextStyle(
              fontSize: 7.8,
              color: _thermalSecondary,
            ),
            softWrap: true,
          ),
        ],
      ),
    );
  }

  static pw.Widget _thermalHeaderCell(
    String label, {
    pw.TextAlign align = pw.TextAlign.center,
    pw.TextStyle? style,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Text(
        label,
        textAlign: align,
        style: style,
      ),
    );
  }

  static pw.Widget _thermalMetaRow(
    String leftLabel,
    String leftValue,
    String rightLabel,
    String rightValue,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              '$leftLabel: $leftValue',
              style: pw.TextStyle(
                  fontSize: 8.1, color: _thermalSecondary),
              softWrap: true,
            ),
          ),
          if (rightLabel.isNotEmpty)
            pw.SizedBox(
              width: 92,
              child: pw.Text(
                '$rightLabel: $rightValue',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                    fontSize: 8.1, color: _thermalSecondary),
                softWrap: true,
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _thermalAmountRow(String label, double value,
      {bool bold = false}) {
    final style = pw.TextStyle(
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontSize: bold ? 9.4 : 8.5,
      color: bold ? _thermalPrimary : _thermalSecondary,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: style,
              maxLines: 1,
            ),
          ),
          pw.SizedBox(
            width: 86,
            child: pw.Text(
              _money(value),
              style: style,
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _thermalValueRow(String label, String value,
      {bool bold = false}) {
    final style = pw.TextStyle(
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontSize: bold ? 9.4 : 8.5,
      color: bold ? _thermalPrimary : _thermalSecondary,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: style,
              maxLines: 1,
            ),
          ),
          pw.SizedBox(
            width: 86,
            child: pw.Text(
              value,
              style: style,
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _thermalTaxSummaryRow(
      String label, double taxable, double tax) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Table(
        columnWidths: const {
          0: pw.FlexColumnWidth(4),
          1: pw.FlexColumnWidth(3),
          2: pw.FlexColumnWidth(3),
        },
        children: [
          pw.TableRow(
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 7.8,
                  color: _thermalSecondary,
                ),
              ),
              pw.Text(
                _money(taxable),
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 7.8,
                  color: _thermalSecondary,
                ),
              ),
              pw.Text(
                _money(tax),
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 7.8,
                  color: _thermalSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _a4MetaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 64,
            child: pw.Text(
              label,
              style:
                  pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 8.5),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _a4AmountRow(String label, double value,
      {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: 9,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(_money(value), style: style),
        ],
      ),
    );
  }

  static pw.Widget _a4ValueRow(String label, String value,
      {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: 9,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  static pw.Widget _dashedDivider() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Divider(
        height: 0,
        thickness: 0.7,
        borderStyle: pw.BorderStyle.dashed,
        color: _thermalDivider,
      ),
    );
  }

  static String _sellerAddress(_InvoiceContext data) {
    final property = data.property;
    if (property == null) return '';
    return [
      property.address,
      property.city,
      property.pinCode,
    ].where((part) => part.trim().isNotEmpty).join(', ');
  }

  static bool _currentShowCurrency = false;

  static String _money(double value, [bool? showCurrency]) {
    final useCurrency = showCurrency ?? _currentShowCurrency;
    if (useCurrency) {
      return CurrencyService.format(value);
    }
    return _currency.format(value);
  }

  static String _qty(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  static String _formatTaxPercent(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  static double _itemGrossValueWithTax(SaleItem item) {
    final baseRate = (item.originalRate != null && item.originalRate! > 0)
        ? item.originalRate!
        : ((item.referenceRate > 0) ? item.referenceRate : item.rate);
    final baseAmount = baseRate * item.qty;
    final isInclusive = item.isTaxInclusive || item.taxType.trim().toUpperCase().contains('INCLUSIVE');
    if (isInclusive) {
      if (baseAmount > 0.0009) return baseAmount;
      if (item.lineTotal > 0.0009) return item.lineTotal;
      return item.taxableAmount > 0.0009 ? item.taxableAmount : 0.0;
    } else {
      if (item.taxPercent > 0) {
        return baseAmount > 0.0009 ? (baseAmount * (1.0 + item.taxPercent / 100.0)) : item.lineTotal;
      }
      if (baseAmount > 0.0009) return baseAmount;
      return item.lineTotal > 0.0009 ? item.lineTotal : item.taxableAmount;
    }
  }

  static double _subscriptionAdjustmentAmount(SaleOrder order) {
    return order.items.fold<double>(
      0,
      (sum, item) => item.isAdvanceFree ? sum + _itemGrossValueWithTax(item) : sum,
    );
  }

  static double _appSubscriptionDiscountAmount(SaleOrder order) {
    return order.items.fold<double>(
      0,
      (sum, item) => item.isAdvanceFree ? sum + (_displayRate(item) * item.qty) : sum,
    );
  }

  static double _appSubscriptionTaxAdjustmentAmount(SaleOrder order) {
    return order.items.fold<double>(
      0,
      (sum, item) {
        if (!item.isAdvanceFree) return sum;
        final isInclusive = item.isTaxInclusive ||
            item.taxType.trim().toUpperCase().contains('INCLUSIVE') ||
            order.billingTaxMode.trim().toUpperCase().contains('INCLUSIVE') ||
            (order.items.isNotEmpty && order.items.every((i) => i.isTaxInclusive));
        if (isInclusive) {
          return sum;
        }
        return sum + ((_displayRate(item) * item.qty) * item.taxPercent / 100);
      },
    );
  }

  static double _groupTaxableTotal(List<TaxBreakdown> taxes) {
    double sum = 0;
    for (final tax in taxes) {
      final code = tax.code.toUpperCase();
      // Skip secondary component lines that share the primary taxable base (e.g. SGST/UTGST in CGST+SGST, CITY_TAX/COUNTY_TAX in multi-tier sales tax)
      if (code == 'SGST' || code == 'UTGST' || code == 'CITY_TAX' || code == 'COUNTY_TAX') {
        continue;
      }
      sum += tax.taxableAmount;
    }
    if (sum <= 0.0009 && taxes.isNotEmpty) {
      return taxes.first.taxableAmount;
    }
    return sum;
  }

  static double _adjustedItemTaxableTotal(SaleOrder order) {
    final hasSubscriptionItems = order.items.any((item) => item.isAdvanceFree);
    if (order.taxableAmount > 0.0009 && !hasSubscriptionItems) {
      return order.taxableAmount;
    }
    double total = 0.0;
    for (final item in order.items) {
      if (item.taxPercent > 0 || item.taxAmount > 0 || item.taxBreakup.isNotEmpty || item.taxGroup != null) {
        total += _displayItemTaxableAmount(order, item);
      }
    }
    if (total > 0.0009) {
      return total;
    }
    final grouped = _groupedTaxBreakup(order);
    if (grouped.isNotEmpty) {
      return _groupTaxableTotal(grouped);
    }
    final allItemsTotal = order.items.fold<double>(
      0.0,
      (sum, item) => sum + _displayItemTaxableAmount(order, item),
    );
    if (allItemsTotal > 0.0009) {
      return allItemsTotal;
    }
    return order.taxableAmount > 0.0009 ? order.taxableAmount : order.subTotal;
  }

  static List<TaxBreakdown> _adjustedItemGroupedTaxes(SaleOrder order, List<TaxBreakdown> original) {
    return original;
  }

  static double _couponSavingsAmount(SaleOrder order) {
    if (order.couponDiscountAmount > 0.0009) {
      return order.couponDiscountAmount;
    }

    final gatewayDetails = order.paymentGatewayDetails;
    if (gatewayDetails != null) {
      final gatewayCoupon = double.tryParse(
            gatewayDetails['coupon_discount_amount']?.toString() ?? '0',
          ) ??
          0.0;
      if (gatewayCoupon > 0.0009) {
        return gatewayCoupon;
      }
    }

    final chargeCoupon = order.charges.fold<double>(0, (sum, charge) {
      final code = charge.code.trim().toUpperCase();
      final name = charge.name.trim().toUpperCase();
      if (code == 'COUPON_DISCOUNT' || name.contains('COUPON DISCOUNT')) {
        return sum + charge.amount.abs();
      }
      return sum;
    });
    if (chargeCoupon > 0.0009) {
      return chargeCoupon;
    }

    return 0.0;
  }

  static double _displaySavingsAmount(SaleOrder order) {
    final coupon = _couponSavingsAmount(order);
    if (coupon > 0.0009) {
      return coupon;
    }
    final hasSubscriptionItems = order.items.any((item) => item.isAdvanceFree) ||
        order.paymentMode.trim().toUpperCase() == 'SUBSCRIPTION';
    if (hasSubscriptionItems) {
      final lineDiscount = order.items.fold<double>(
        0,
        (sum, item) => item.isAdvanceFree ? sum : sum + item.lineDiscount,
      );
      return lineDiscount > 0.0009 ? lineDiscount : 0.0;
    }
    if (order.schemeDiscount > 0.0009) {
      return order.schemeDiscount;
    }
    final lineDiscount = order.items.fold<double>(
      0,
      (sum, item) => sum + item.lineDiscount,
    );
    if (lineDiscount > 0.0009) {
      return lineDiscount;
    }
    final subAdj = _subscriptionAdjustmentAmount(order);
    final realManualDiscount = (order.manualDiscountAmount - subAdj).clamp(0.0, double.infinity);
    if (realManualDiscount > 0.0009) {
      return realManualDiscount;
    }
    return 0.0;
  }

  static bool _showSubscriptionAdjustmentRow(SaleOrder order, double subscriptionAdjustment) {
    return order.paymentMode.trim().toUpperCase() == 'SUBSCRIPTION' && subscriptionAdjustment > 0.0009;
  }

  static double _itemTaxableTotal(SaleOrder order) {
    return order.items.fold<double>(
      0,
      (sum, item) => sum + _displayItemTaxableAmount(order, item),
    );
  }

  static List<TaxBreakdown> _groupedChargeTaxBreakup(SaleOrder order) {
    final billingMode = order.billingTaxMode.trim().toUpperCase();
    final grouped = <String, TaxBreakdown>{};

    void addTax(TaxBreakdown tax) {
      final key = '${tax.code}|${tax.label}|${tax.rate}';
      final existing = grouped[key];
      if (existing == null) {
        grouped[key] = tax;
      } else {
        grouped[key] = TaxBreakdown(
          code: existing.code,
          label: existing.label,
          taxType: existing.taxType,
          rate: existing.rate,
          taxableAmount: existing.taxableAmount + tax.taxableAmount,
          taxAmount: existing.taxAmount + tax.taxAmount,
        );
      }
    }

    for (final charge in order.charges) {
      final taxableAmount = charge.amount.abs();
      final taxAmount = taxableAmount * charge.taxPercent / 100.0;
      if (taxableAmount <= 0 || taxAmount <= 0) continue;

      if (charge.taxBreakup.isNotEmpty) {
        for (final tax in charge.taxBreakup) {
          addTax(tax);
        }
        continue;
      }

      if (charge.taxGroup != null && charge.taxGroup!.components.isNotEmpty) {
        for (final comp in charge.taxGroup!.components) {
          final compAmount = taxableAmount * comp.rate / 100;
          addTax(
            TaxBreakdown(
              code: comp.componentCode.isNotEmpty ? comp.componentCode : 'TAX',
              label: '${comp.componentName} (${_formatTaxPercent(comp.rate)}%)',
              taxType: comp.componentCode,
              rate: comp.rate,
              taxableAmount: taxableAmount,
              taxAmount: compAmount,
            ),
          );
        }
        continue;
      }

      final normalizedType = charge.taxType.trim().toUpperCase();

      if (normalizedType.contains('USA') ||
          normalizedType.contains('US_') ||
          normalizedType.contains('SALES') ||
          normalizedType == 'COMPOSITE' ||
          billingMode == 'US_SALES_TAX' ||
          billingMode == 'SALES_TAX') {
        final stateRate = charge.taxPercent > 1.0 ? double.parse((charge.taxPercent - 1.0).toStringAsFixed(2)) : charge.taxPercent;
        final cityRate = charge.taxPercent > 1.0 ? 1.0 : 0.0;

        addTax(
          TaxBreakdown(
            code: 'STATE_TAX',
            label: 'STATE SALES TAX (${_formatTaxPercent(stateRate)}%)',
            taxType: 'STATE_TAX',
            rate: stateRate,
            taxableAmount: taxableAmount,
            taxAmount: taxableAmount * stateRate / 100,
          ),
        );
        if (cityRate > 0) {
          addTax(
            TaxBreakdown(
              code: 'CITY_TAX',
              label: 'CITY TAX (${_formatTaxPercent(cityRate)}%)',
              taxType: 'CITY_TAX',
              rate: cityRate,
              taxableAmount: taxableAmount,
              taxAmount: taxableAmount * cityRate / 100,
            ),
          );
        }
        continue;
      }

      if (billingMode == 'IGST' || normalizedType == 'IGST') {
        addTax(
          TaxBreakdown(
            code: 'IGST',
            label: 'IGST ${_formatTaxPercent(charge.taxPercent)}%',
            taxType: 'GST',
            rate: charge.taxPercent,
            taxableAmount: taxableAmount,
            taxAmount: taxAmount,
          ),
        );
        continue;
      }

      if (billingMode == 'VAT' || normalizedType == 'VAT') {
        addTax(
          TaxBreakdown(
            code: 'VAT',
            label: 'VAT ${_formatTaxPercent(charge.taxPercent)}%',
            taxType: 'VAT',
            rate: charge.taxPercent,
            taxableAmount: taxableAmount,
            taxAmount: taxAmount,
          ),
        );
        continue;
      }

      if (normalizedType == 'CESS') {
        addTax(
          TaxBreakdown(
            code: 'CESS',
            label: 'CESS ${_formatTaxPercent(charge.taxPercent)}%',
            taxType: 'CESS',
            rate: charge.taxPercent,
            taxableAmount: taxableAmount,
            taxAmount: taxAmount,
          ),
        );
        continue;
      }

      if (normalizedType != 'GST' && normalizedType != 'CGST_SGST' && billingMode != 'CGST_SGST') {
        addTax(
          TaxBreakdown(
            code: normalizedType.isNotEmpty ? normalizedType : 'TAX',
            label: '${normalizedType.isNotEmpty ? normalizedType : "Tax"} (${_formatTaxPercent(charge.taxPercent)}%)',
            taxType: normalizedType.isNotEmpty ? normalizedType : 'TAX',
            rate: charge.taxPercent,
            taxableAmount: taxableAmount,
            taxAmount: taxAmount,
          ),
        );
        continue;
      }

      final halfRate = charge.taxPercent / 2;
      final halfTaxAmount = taxAmount / 2;
      addTax(
        TaxBreakdown(
          code: 'CGST',
          label: 'CGST ${_formatTaxPercent(halfRate)}%',
          taxType: 'GST',
          rate: halfRate,
          taxableAmount: taxableAmount,
          taxAmount: halfTaxAmount,
        ),
      );
      addTax(
        TaxBreakdown(
          code: 'SGST',
          label: 'SGST/UTGST ${_formatTaxPercent(halfRate)}%',
          taxType: 'GST',
          rate: halfRate,
          taxableAmount: taxableAmount,
          taxAmount: halfTaxAmount,
        ),
      );
    }
    return grouped.values.toList();
  }


  static double _displayItemTaxableAmount(SaleOrder order, SaleItem item) {
    if (item.taxableAmount > 0.0009) {
      return item.taxableAmount;
    }
    final taxable = _taxableAmountForItem(item);
    final isFree = item.isSchemeFree || item.isAdvanceFree;
    if (isFree || item.lineDiscount > 0.0009 || taxable <= 0.0009) {
      return taxable;
    }
    final totalLineDiscount = order.items.fold<double>(0, (sum, i) => sum + i.lineDiscount);
    if (totalLineDiscount > 0.0009) {
      return taxable;
    }
    final totalOrderDiscount = order.manualDiscountAmount + order.schemeDiscount + order.totalDiscount;
    if (totalOrderDiscount > 0.0009) {
      final grossItemTotal = order.items.where((i) => !(i.isSchemeFree || i.isAdvanceFree)).fold<double>(
        0,
        (sum, entry) => sum + entry.amount,
      );
      if (grossItemTotal > 0.0009) {
        final discountShare = math.min(taxable, (item.amount / grossItemTotal) * totalOrderDiscount);
        return math.max(0, taxable - discountShare);
      }
    }
    if (order.couponDiscountAmount > 0.0009) {
      final grossItemTotal = order.items.where((i) => !(i.isSchemeFree || i.isAdvanceFree)).fold<double>(
        0,
        (sum, entry) => sum + entry.amount,
      );
      if (grossItemTotal > 0.0009) {
        final couponShare = math.min(taxable, (item.amount / grossItemTotal) * order.couponDiscountAmount);
        return math.max(0, taxable - couponShare);
      }
    }
    return taxable;
  }

  static double _displayNetPayable(
    SaleOrder order, {
    double? itemTaxableTotal,
    double? chargeTaxTotal,
    double? summaryTaxTotal,
    double? subscriptionAdjustment,
  }) {
    if (order.netAmount.abs() <= 0.0009 &&
        (order.items.isNotEmpty ||
            order.manualDiscountAmount > 0 ||
            order.totalDiscount > 0 ||
            order.schemeDiscount > 0)) {
      return 0.0;
    }
    if (order.netAmount > 0.0009) {
      return order.netAmount;
    }
    final itemBase = itemTaxableTotal ?? _itemTaxableTotal(order);
    final chargeBase = order.chargeTotal;
    final chargeTax = chargeTaxTotal ?? _groupTaxTotal(_groupedChargeTaxBreakup(order));
    final bool isIndia = CountryTaxHelper.isIndiaCountry(order.billingCountry);
    final summaryTax = summaryTaxTotal ?? (isIndia
        ? (_taxAmountFromBreakup(_groupedTaxBreakup(order), 'CGST') +
            _taxAmountFromBreakup(_groupedTaxBreakup(order), 'SGST') +
            _taxAmountFromBreakup(_groupedTaxBreakup(order), 'IGST') +
            _taxAmountFromBreakup(_groupedChargeTaxBreakup(order), 'CGST') +
            _taxAmountFromBreakup(_groupedChargeTaxBreakup(order), 'SGST') +
            _taxAmountFromBreakup(_groupedChargeTaxBreakup(order), 'IGST'))
        : (_groupTaxTotal(_groupedTaxBreakup(order)) +
            _groupTaxTotal(_groupedChargeTaxBreakup(order))));
    final subscription = subscriptionAdjustment ?? _subscriptionAdjustmentAmount(order);
    return math.max(0, itemBase + chargeBase + chargeTax + summaryTax - subscription);
  }

  static double _groupTaxTotal(List<TaxBreakdown> taxes) {
    return taxes.fold<double>(0, (sum, tax) => sum + tax.taxAmount);
  }

  static List<TaxBreakdown> _sourceTaxBreakup(SaleOrder order) {
    final hasSubscriptionItems = order.items.any((item) => item.isAdvanceFree);
    if (order.taxBreakup.isNotEmpty && !hasSubscriptionItems) {
      return order.taxBreakup;
    }
    return order.items
        .expand((item) => _itemTaxBreakup(order, item))
        .toList(growable: false);
  }

  static List<TaxBreakdown> _groupedTaxBreakup(SaleOrder order) {
    final grouped = <String, TaxBreakdown>{};
    for (final item in order.items) {
      for (final tax in _itemTaxBreakup(order, item)) {
        final key = '${tax.code}|${tax.label}|${tax.rate}';
        final existing = grouped[key];
        if (existing == null) {
          grouped[key] = tax;
        } else {
          grouped[key] = TaxBreakdown(
            code: tax.code,
            label: tax.label,
            taxType: tax.taxType,
            rate: tax.rate,
            taxableAmount: existing.taxableAmount + tax.taxableAmount,
            taxAmount: existing.taxAmount + tax.taxAmount,
          );
        }
      }
    }
    return grouped.values.toList();
  }

  static List<TaxBreakdown> _itemTaxBreakup(SaleOrder order, SaleItem item) {
    final taxPercent = item.taxPercent;
    if (taxPercent <= 0) return const <TaxBreakdown>[];

    final double taxableAmount;
    final double taxAmount;
    final isTaxInclusive = item.isTaxInclusive ||
        item.taxType.trim().toUpperCase().contains('INCLUSIVE') ||
        order.billingTaxMode.trim().toUpperCase().contains('INCLUSIVE') ||
        (order.items.isNotEmpty && order.items.every((i) => i.isTaxInclusive));
    if (item.isAdvanceFree) {
      final gross = item.referenceRate > 0
          ? item.referenceRate * item.qty
          : (item.taxableAmount > 0 ? (item.taxableAmount + item.taxAmount) : item.amount);
      if (isTaxInclusive && taxPercent > 0) {
        taxableAmount = gross / (1 + taxPercent / 100);
        taxAmount = gross - taxableAmount;
      } else {
        taxableAmount = gross;
        taxAmount = taxableAmount * taxPercent / 100;
      }
    } else {
      taxableAmount = _displayItemTaxableAmount(order, item);
      taxAmount = taxableAmount * taxPercent / 100;
    }
    if (taxableAmount <= 0) return const <TaxBreakdown>[];

    final bool isIndia = CountryTaxHelper.isIndiaCountry(order.billingCountry);

    if (item.taxGroup != null && item.taxGroup!.components.isNotEmpty) {
      final list = <TaxBreakdown>[];
      for (final comp in item.taxGroup!.components) {
        final compAmount = taxableAmount * comp.rate / 100;
        final compName = comp.componentName.isNotEmpty ? comp.componentName : (isIndia ? 'GST' : 'Sales Tax');
        list.add(
          TaxBreakdown(
            code: comp.componentCode.isNotEmpty ? comp.componentCode : 'TAX',
            label: '$compName (${_formatTaxPercent(comp.rate)}%)',
            taxType: comp.componentCode,
            rate: comp.rate,
            taxableAmount: taxableAmount,
            taxAmount: compAmount,
          ),
        );
      }
      return list;
    }

    if (item.taxBreakup.isNotEmpty) {
      return item.taxBreakup;
    }

    final normalizedType = item.taxType.trim().toUpperCase();

    if (normalizedType == 'US_SALES_TAX' ||
        normalizedType == 'COMPOSITE' ||
        normalizedType == 'SALES_TAX') {
      final stateRate = taxPercent > 1.0 ? double.parse((taxPercent - 1.0).toStringAsFixed(2)) : taxPercent;
      final cityRate = taxPercent > 1.0 ? 1.0 : 0.0;

      return [
        TaxBreakdown(
          code: 'STATE_TAX',
          label: 'STATE SALES TAX (${_formatTaxPercent(stateRate)}%)',
          taxType: 'STATE_TAX',
          rate: stateRate,
          taxableAmount: taxableAmount,
          taxAmount: taxableAmount * stateRate / 100,
        ),
        if (cityRate > 0)
          TaxBreakdown(
            code: 'CITY_TAX',
            label: 'CITY TAX (${_formatTaxPercent(cityRate)}%)',
            taxType: 'CITY_TAX',
            rate: cityRate,
            taxableAmount: taxableAmount,
            taxAmount: taxableAmount * cityRate / 100,
          ),
      ];
    }
    if (normalizedType == 'VAT') {
      return [
        TaxBreakdown(
          code: 'VAT',
          label: 'VAT ${_formatTaxPercent(taxPercent)}%',
          taxType: 'VAT',
          rate: taxPercent,
          taxableAmount: taxableAmount,
          taxAmount: taxAmount,
        ),
      ];
    }
    if (normalizedType == 'CESS') {
      return [
        TaxBreakdown(
          code: 'CESS',
          label: 'CESS ${_formatTaxPercent(taxPercent)}%',
          taxType: 'CESS',
          rate: taxPercent,
          taxableAmount: taxableAmount,
          taxAmount: taxAmount,
        ),
      ];
    }
    final billingMode = order.billingTaxMode.trim().toUpperCase();

    if (isIndia && (normalizedType == 'GST' || normalizedType == 'CGST_SGST')) {
      final halfRate = taxPercent / 2;
      final halfAmount = taxAmount / 2;
      return [
        TaxBreakdown(
          code: 'CGST',
          label: 'CGST ${_formatTaxPercent(halfRate)}%',
          taxType: 'GST',
          rate: halfRate,
          taxableAmount: taxableAmount,
          taxAmount: halfAmount,
        ),
        TaxBreakdown(
          code: 'SGST',
          label: 'SGST/UTGST ${_formatTaxPercent(halfRate)}%',
          taxType: 'GST',
          rate: halfRate,
          taxableAmount: taxableAmount,
          taxAmount: halfAmount,
        ),
      ];
    }
    if (normalizedType == 'IGST') {
      return [
        TaxBreakdown(
          code: 'IGST',
          label: 'IGST ${_formatTaxPercent(taxPercent)}%',
          taxType: 'GST',
          rate: taxPercent,
          taxableAmount: taxableAmount,
          taxAmount: taxAmount,
        ),
      ];
    }
    if (normalizedType == 'OTHER' || normalizedType == 'CUSTOM') {
      return [
        TaxBreakdown(
          code: 'CUSTOM',
          label: 'Custom Tax ${_formatTaxPercent(taxPercent)}%',
          taxType: 'CUSTOM',
          rate: taxPercent,
          taxableAmount: taxableAmount,
          taxAmount: taxAmount,
        ),
      ];
    }
    if (billingMode == 'IGST') {
      return [
        TaxBreakdown(
          code: 'IGST',
          label: 'IGST ${_formatTaxPercent(taxPercent)}%',
          taxType: 'GST',
          rate: taxPercent,
          taxableAmount: taxableAmount,
          taxAmount: taxAmount,
        ),
      ];
    }

    if (billingMode == 'VAT') {
      return [
        TaxBreakdown(
          code: 'VAT',
          label: 'VAT ${_formatTaxPercent(taxPercent)}%',
          taxType: 'VAT',
          rate: taxPercent,
          taxableAmount: taxableAmount,
          taxAmount: taxAmount,
        ),
      ];
    }

    if (!isIndia) {
      final tName = CountryTaxHelper.taxName(order.billingCountry, billingMode);
      return [
        TaxBreakdown(
          code: 'SALES_TAX',
          label: '$tName ${_formatTaxPercent(taxPercent)}%',
          taxType: 'SALES_TAX',
          rate: taxPercent,
          taxableAmount: taxableAmount,
          taxAmount: taxAmount,
        ),
      ];
    }

    final halfRate = taxPercent / 2;
    final halfAmount = taxAmount / 2;
    return [
      TaxBreakdown(
        code: 'CGST',
        label: 'CGST ${_formatTaxPercent(halfRate)}%',
        taxType: 'GST',
        rate: halfRate,
        taxableAmount: taxableAmount,
        taxAmount: halfAmount,
      ),
      TaxBreakdown(
        code: 'SGST',
        label: 'SGST/UTGST ${_formatTaxPercent(halfRate)}%',
        taxType: 'GST',
        rate: halfRate,
        taxableAmount: taxableAmount,
        taxAmount: halfAmount,
      ),
    ];
  }

  static String _taxPrefix(SaleOrder order, SaleItem item) {
    if (item.taxGroup != null && item.taxGroup!.groupName.isNotEmpty) {
      return item.taxGroup!.groupName;
    }
    final normType = item.taxType.trim().toUpperCase();
    if (normType == 'US_SALES_TAX' || normType == 'COMPOSITE' || normType == 'SALES_TAX') {
      return 'Sales Tax';
    }
    if (normType == 'VAT' || normType == 'VAT_ONLY' || normType == 'VAT_CTL' || order.billingTaxMode == 'VAT') {
      return 'VAT';
    }
    if (normType == 'CESS') return 'CESS';
    if (normType == 'CUSTOM' || normType == 'OTHER') return 'Tax';
    if (order.billingTaxMode == 'NONE') return 'Tax';
    return 'GST';
  }

  static TaxBreakdown? _itemTaxForCode(SaleOrder order, SaleItem item, String code) {
    for (final tax in _itemTaxBreakup(order, item)) {
      if (tax.code == code) return tax;
    }
    return null;
  }

  static String _taxRate(SaleOrder order, SaleItem item, String code) {
    final entry = _itemTaxForCode(order, item, code);
    if (entry == null || entry.rate <= 0) return '-';
    return '${entry.rate % 1 == 0 ? entry.rate.toStringAsFixed(0) : entry.rate.toStringAsFixed(2)}%';
  }

  static double _taxAmount(SaleOrder order, SaleItem item, String code) {
    return _itemTaxForCode(order, item, code)?.taxAmount ?? 0;
  }

  static double _taxableAmountForItem(SaleItem item) {
    final itemRate = (item.rate > 0)
        ? item.rate
        : ((item.referenceRate > 0)
            ? item.referenceRate
            : (item.originalRate != null && item.originalRate! > 0 ? item.originalRate! : 0.0));
    final itemGrossAmount = itemRate * item.qty;
    if (item.lineDiscount >= itemGrossAmount && itemGrossAmount > 0) {
      return 0.0;
    }
    if (item.taxableAmount.abs() > 0.0009) return item.taxableAmount;
    final gross = math.max(0.0, itemGrossAmount - item.lineDiscount);
    if (item.isTaxInclusive && item.taxPercent > 0 && gross > 0) {
      return gross / (1 + item.taxPercent / 100);
    }
    if (gross > 0) return gross;
    return 0.0;
  }

  static double _displayRate(SaleItem item) {
    if (item.rate > 0) return item.rate;
    if (item.originalRate != null && item.originalRate! > 0) return item.originalRate!;
    if (item.referenceRate > 0) return item.referenceRate;
    return item.rate;
  }

  static double _displayItemLineTotal(SaleItem item) {
    if (item.isSchemeFree || item.isAdvanceFree) {
      final rate = _displayRate(item);
      final calculated = rate * item.qty;
      if (calculated > 0) return calculated;
    }
    return item.lineTotal;
  }

  static double _grossItemsSubtotal(SaleOrder order) {
    return order.items.fold<double>(
      0,
      (acc, item) => acc + (_displayRate(item) * item.qty),
    );
  }

  static double _taxAmountFromBreakup(List<TaxBreakdown> taxes, String code) {
    return taxes
        .where((tax) => tax.code == code)
        .fold<double>(0, (sum, tax) => sum + tax.taxAmount);
  }

  static String _truncate(String value, int length) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= length) return normalized;
    return '${normalized.substring(0, length - 1)}…';
  }

  static pw.Widget buildStandardA4Header({
    required PropertyInfo? property,
    required pw.MemoryImage? logo,
    pw.Widget? rightWidget,
    String? country,
  }) {
    final sellerName = property?.legalName.isNotEmpty == true
        ? property!.legalName
        : property?.propertyName ?? '';

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 2),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logo != null)
            pw.Container(
              width: 60,
              height: 60,
              margin: const pw.EdgeInsets.only(right: 12),
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  sellerName,
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
                pw.SizedBox(height: 2),
                if (property?.address != null && property!.address.isNotEmpty)
                  pw.Text(property.address, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                pw.SizedBox(height: 2),
                
                // Contact Details Row
                () {
                  final contactWidgets = <pw.Widget>[];
                  if (property != null && property.printMobile != false && property.mobile.isNotEmpty) {
                    contactWidgets.add(pw.Text('Phone: ${property.mobile}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)));
                  }
                  if (property != null && property.printEmail != false && property.email.isNotEmpty) {
                    contactWidgets.add(pw.Text('Email: ${property.email}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)));
                  }
                  if (property != null && property.printWebsite != false && property.website.isNotEmpty) {
                    contactWidgets.add(pw.Text('Web: ${property.website}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)));
                  }
                  
                  if (contactWidgets.isEmpty) return pw.SizedBox();
                  
                  final List<pw.Widget> result = [];
                  for (int i = 0; i < contactWidgets.length; i++) {
                    result.add(contactWidgets[i]);
                    if (i < contactWidgets.length - 1) {
                      result.add(
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5),
                          child: pw.Text('|', style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 7.5)),
                        ),
                      );
                    }
                  }
                  return pw.Row(children: result);
                }(),
                
                pw.SizedBox(height: 1.5),
                
                // Tax ID / State Tax ID / FSSAI / DL No Row
                () {
                  final certWidgets = <pw.Widget>[];
                  if (property != null && property.gstNo.isNotEmpty) {
                    certWidgets.add(pw.Text('${_taxIdLabel(country)}: ${property.gstNo}', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)));
                  }
                  if (property != null && property.panNo.isNotEmpty) {
                    certWidgets.add(pw.Text('${_businessRegLabel(country)}: ${property.panNo}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800)));
                  }
                  if (property != null && property.fssaiNo.isNotEmpty && _isIndiaCountry(country)) {
                    certWidgets.add(pw.Text('FSSAI: ${property.fssaiNo}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800)));
                  }
                  if (property != null && property.drugLicenseNo.isNotEmpty) {
                    certWidgets.add(pw.Text('DL No: ${property.drugLicenseNo}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800)));
                  }
                  
                  if (certWidgets.isEmpty) return pw.SizedBox();
                  
                  final List<pw.Widget> result = [];
                  for (int i = 0; i < certWidgets.length; i++) {
                    result.add(certWidgets[i]);
                    if (i < certWidgets.length - 1) {
                      result.add(
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5),
                          child: pw.Text('|', style: pw.TextStyle(color: PdfColors.grey400, fontSize: 7.5)),
                        ),
                      );
                    }
                  }
                  return pw.Row(children: result);
                }(),
              ],
            ),
          ),
          if (rightWidget != null) ...[
            pw.SizedBox(width: 16),
            rightWidget,
          ],
        ],
      ),
    );
  }

  static pw.Widget buildStandardThermalHeader({
    required PropertyInfo? property,
    required pw.MemoryImage? logo,
    required pw.Font fontRegular,
    required pw.Font fontBold,
    String? country,
    Map<String, dynamic>? receiptTemplateConfig,
    double scale = 1.0,
  }) {
    final cfg = receiptTemplateConfig ?? {};
    final bool showLogo = cfg['show_logo'] ?? true;
    final bool showAddress = cfg['show_address'] ?? true;
    final bool showPhone = cfg['show_phone'] ?? (property?.printMobile ?? true);
    final bool showEmail = cfg['show_email'] ?? (property?.printEmail ?? true);

    final String headerTitle = (cfg['header_title']?.toString().trim().isNotEmpty == true)
        ? cfg['header_title'].toString().trim()
        : (property?.propertyName ?? '');
    final String headerSubtext = (cfg['header_subtext']?.toString().trim().isNotEmpty == true)
        ? cfg['header_subtext'].toString().trim()
        : (property?.address ?? '');
    final String taxRegNo = (cfg['tax_reg_no']?.toString().trim().isNotEmpty == true)
        ? cfg['tax_reg_no'].toString().trim()
        : '';

    final bodyStyle = pw.TextStyle(font: fontRegular, fontSize: 8.9 * scale, color: _thermalSecondary);
    final storeStyle = pw.TextStyle(font: fontBold, fontSize: 12.8 * scale, color: _thermalPrimary);

    return pw.DefaultTextStyle(
      style: bodyStyle,
      child: pw.Center(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (showLogo && logo != null)
              pw.Container(
                width: 44 * scale,
                height: 44 * scale,
                margin: pw.EdgeInsets.only(bottom: 4 * scale),
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
            if (headerTitle.isNotEmpty)
              pw.Text(
                headerTitle,
                textAlign: pw.TextAlign.center,
                style: storeStyle,
              ),
            if (showAddress && headerSubtext.isNotEmpty)
              pw.Padding(
                padding: pw.EdgeInsets.only(top: 2 * scale),
                child: pw.Text(
                  headerSubtext,
                  textAlign: pw.TextAlign.center,
                ),
              ),
            if (taxRegNo.isNotEmpty)
              pw.Padding(
                padding: pw.EdgeInsets.only(top: 2 * scale),
                child: pw.Text(
                  taxRegNo,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: fontBold, fontSize: 9.0 * scale, color: _thermalPrimary),
                ),
              )
            else if (property != null) ...[
              if (showPhone && property.printMobile != false && property.mobile.isNotEmpty)
                pw.Text(
                  'Phone: ${property.mobile}',
                  textAlign: pw.TextAlign.center,
                ),
              if (showEmail && property.printEmail != false && property.email.isNotEmpty)
                pw.Text(
                  'Email: ${property.email}',
                  textAlign: pw.TextAlign.center,
                ),
              if (property.printWebsite != false && property.website.isNotEmpty)
                pw.Text(
                  'Website: ${property.website}',
                  textAlign: pw.TextAlign.center,
                ),
              if (property.gstNo.isNotEmpty)
                pw.Text(
                  '${_taxIdLabel(country)}: ${property.gstNo}',
                  textAlign: pw.TextAlign.center,
                ),
              if (property.panNo.isNotEmpty)
                pw.Text(
                  '${_businessRegLabel(country)}: ${property.panNo}',
                  textAlign: pw.TextAlign.center,
                ),
              if (property.drugLicenseNo.isNotEmpty)
                pw.Text(
                  'DL No: ${property.drugLicenseNo}',
                  textAlign: pw.TextAlign.center,
                ),
              if (property.fssaiNo.isNotEmpty && _isIndiaCountry(country))
                pw.Text(
                  'FSSAI No: ${property.fssaiNo}',
                  textAlign: pw.TextAlign.center,
                ),
            ],
          ],
        ),
      ),
    );
  }

  static Future<void> printAccountingVoucherReceipt({
    required String voucherNo,
    required String voucherType,
    required String dateStr,
    required String partyName,
    required String paymentMode,
    required double amount,
    String note = '',
    String? referenceNo,
    List<dynamic> lines = const [],
  }) async {
    final propertyCtrl = PropertyInfoController();
    await propertyCtrl.load();
    final property = propertyCtrl.data;
    final logo = await BrandingStorage.loadPdfLogo(property?.logoPath);

    await Printing.layoutPdf(
      name: 'Voucher_${voucherNo.replaceAll('/', '_')}',
      onLayout: (format) async {
        final fonts = await getInvoiceFonts();
        final pdf = pw.Document(
          theme: pw.ThemeData.withFont(
            base: fonts.regular,
            bold: fonts.bold,
          ),
        );
        final bold = fonts.bold;
        final regular = fonts.regular;

        pw.Widget divider() => pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 4),
              width: double.infinity,
              height: 1,
              color: PdfColors.black,
            );

        pw.Widget kvLine(String label, String value, {bool boldFont = false}) {
          final style = pw.TextStyle(
            fontSize: 9,
            fontWeight: boldFont ? pw.FontWeight.bold : pw.FontWeight.normal,
          );
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: style),
              pw.Text(value, style: style),
            ],
          );
        }

        pdf.addPage(
          pw.MultiPage(
            pageFormat: const PdfPageFormat(
              80 * PdfPageFormat.mm,
              220 * PdfPageFormat.mm,
              marginLeft: 3 * PdfPageFormat.mm,
              marginRight: 3 * PdfPageFormat.mm,
              marginTop: 4 * PdfPageFormat.mm,
              marginBottom: 4 * PdfPageFormat.mm,
            ),
            build: (context) => [
              buildStandardThermalHeader(
                property: property,
                logo: logo,
                fontRegular: regular,
                fontBold: bold,
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  '${voucherType.toUpperCase()} VOUCHER',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              divider(),
              kvLine('Voucher No:', voucherNo, boldFont: true),
              kvLine('Date:', dateStr),
              kvLine('Party / Account:', partyName.isNotEmpty ? partyName : 'General Account'),
              kvLine('Payment Mode:', paymentMode),
              if (referenceNo != null && referenceNo.isNotEmpty)
                kvLine('Reference No:', referenceNo),
              divider(),
              if (lines.isNotEmpty) ...[
                pw.Text('LEDGER BREAKDOWN:',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                ...lines.map((l) {
                  final lineMap = l is Map ? l : (l.toJson != null ? l.toJson() : {});
                  final lineType = (lineMap['line_type'] ?? lineMap['lineType'] ?? 'DEBIT').toString().toUpperCase();
                  final accName = (lineMap['account_name'] ?? lineMap['accountName'] ?? '').toString();
                  final dr = double.tryParse((lineMap['debit_amount'] ?? lineMap['debitAmount'] ?? 0).toString()) ?? 0;
                  final cr = double.tryParse((lineMap['credit_amount'] ?? lineMap['creditAmount'] ?? 0).toString()) ?? 0;
                  final lineAmt = dr > 0 ? dr : cr;
                  final prefix = lineType == 'DEBIT' ? 'Dr' : 'Cr';
                  return pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text('[$prefix] $accName', style: const pw.TextStyle(fontSize: 8.5)),
                      ),
                      pw.Text(CurrencyService.format(lineAmt), style: const pw.TextStyle(fontSize: 8.5)),
                    ],
                  );
                }),
                divider(),
              ],
              kvLine('Total Amount:', CurrencyService.format(amount), boldFont: true),
              divider(),
              if (note.isNotEmpty) ...[
                pw.Text('Narration / Note:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(note, style: const pw.TextStyle(fontSize: 8)),
                divider(),
              ],
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text(
                  'Signature / Authorized Sign',
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Thank you!',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ],
          ),
        );
        return pdf.save();
      },
    );
  }

  static String _cleanAddressForPrint(String? rawAddress) {
    if (rawAddress == null || rawAddress.trim().isEmpty) return '';
    String address = rawAddress.trim();
    
    if (address.toLowerCase().startsWith('state:')) {
      final stateVal = address.substring(6).trim();
      return stateVal.isEmpty ? '' : stateVal;
    }

    while (true) {
      final stateIndex = address.toLowerCase().lastIndexOf(', state:');
      if (stateIndex != -1) {
        address = address.substring(0, stateIndex).trim();
      } else {
        break;
      }
    }
    
    return address.trim();
  }

  static String _deriveBuyerState(SaleOrder order, PropertyInfo? property) {
    final gstStateCode = _stateCodeFromGstin(order.customerGstin);
    if (gstStateCode != null) {
      return _stateNameByCode[gstStateCode] ?? '';
    }

    final address = order.customerAddress ?? '';
    for (final state in _stateCodes.keys) {
      if (address.toLowerCase().contains(state.toLowerCase())) {
        return state;
      }
    }

    return '';
  }

  static String? _stateCodeFromGstin(String? gstin) {
    if (gstin == null) return null;
    final normalized = gstin.trim();
    if (normalized.length < 2) return null;
    final code = normalized.substring(0, 2);
    return _stateNameByCode.containsKey(code) ? code : null;
  }

  static String? _stateCodeFor(String? state) {
    if (state == null || state.trim().isEmpty) return null;
    return _stateCodes[state.trim().toLowerCase()];
  }

  static String _amountInWords(double amount, [String? currencyCode]) {
    final curCode = currencyCode ?? CurrencyService.code;
    final String majorUnit;
    final String minorUnit;

    switch (curCode.toUpperCase()) {
      case 'INR':
        majorUnit = 'Indian Rupees';
        minorUnit = 'Paise';
        break;
      case 'USD':
        majorUnit = 'US Dollars';
        minorUnit = 'Cents';
        break;
      case 'EUR':
        majorUnit = 'Euros';
        minorUnit = 'Cents';
        break;
      case 'GBP':
        majorUnit = 'Pounds';
        minorUnit = 'Pence';
        break;
      case 'KES':
        majorUnit = 'Kenyan Shillings';
        minorUnit = 'Cents';
        break;
      case 'AED':
        majorUnit = 'UAE Dirhams';
        minorUnit = 'Fils';
        break;
      case 'JPY':
        majorUnit = 'Japanese Yen';
        minorUnit = '';
        break;
      default:
        majorUnit = curCode.isNotEmpty ? curCode : 'Units';
        minorUnit = 'Cents';
    }

    final mainVal = amount.floor();
    final subVal = ((amount - mainVal) * 100).round();
    final mainWords = _numberToWords(mainVal);
    final subWords = (subVal > 0 && minorUnit.isNotEmpty) ? ' and ${_numberToWords(subVal)} $minorUnit' : '';
    return '$majorUnit $mainWords$subWords Only';
  }

  static String _numberToWords(int number) {
    if (number == 0) return 'Zero';

    final parts = <String>[];
    final segments = [
      (10000000, 'Crore'),
      (100000, 'Lakh'),
      (1000, 'Thousand'),
      (100, 'Hundred'),
    ];

    var remaining = number;
    for (final (value, label) in segments) {
      if (remaining >= value) {
        parts.add('${_numberToWords(remaining ~/ value)} $label');
        remaining %= value;
      }
    }

    if (remaining > 0) {
      if (parts.isNotEmpty) {
        parts.add(remaining < 100
            ? 'and ${_twoDigitWords(remaining)}'
            : _twoDigitWords(remaining));
      } else {
        parts.add(_twoDigitWords(remaining));
      }
    }

    return parts.join(' ').trim();
  }

  static String _twoDigitWords(int number) {
    const units = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    const tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    if (number < 20) return units[number];
    if (number < 100) {
      final suffix = number % 10 == 0 ? '' : ' ${units[number % 10]}';
      return '${tens[number ~/ 10]}$suffix'.trim();
    }
    final remainder = number % 100;
    final hundredPart = '${units[number ~/ 100]} Hundred';
    if (remainder == 0) return hundredPart;
    return '$hundredPart and ${_twoDigitWords(remainder)}';
  }

  static const Map<String, String> _stateCodes = {
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

  static final Map<String, String> _stateNameByCode = {
    for (final entry in _stateCodes.entries) entry.value: _titleCase(entry.key),
  };

  static Future<void> printCreditNote({
    required Map<String, dynamic> creditNote,
    required PropertyInfo? property,
    Printer? printer,
    bool directPrint = false,
  }) async {
    final pdfBytes = await buildCreditNotePdf(
      creditNote: creditNote,
      property: property,
    );

    if (directPrint && printer != null) {
      await Printing.directPrintPdf(
        printer: printer,
        name: creditNote['credit_note_no'] ?? 'CreditNote',
        onLayout: (_) async => pdfBytes,
      );
      return;
    }

    await Printing.layoutPdf(name: creditNote['credit_note_no'] ?? 'CreditNote', onLayout: (_) async => pdfBytes);
  }

  static Future<Uint8List> buildCreditNotePdf({
    required Map<String, dynamic> creditNote,
    required PropertyInfo? property,
  }) async {
    final fonts = await getInvoiceFonts();
    final document = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fonts.regular,
        bold: fonts.bold,
      ),
    );
    final logo = await BrandingStorage.loadPdfLogo(property?.logoPath);

    final originalSale = creditNote['sale'] is Map ? creditNote['sale'] as Map<String, dynamic> : null;
    final billFormat = originalSale?['bill_format']?.toString() ?? 'A4';

    if (_isThermalFormat(billFormat)) {
      document.addPage(
        pw.MultiPage(
          pageFormat: _thermalSheetFor(billFormat),
          build: (_) => [_buildThermalCreditNoteReceipt(creditNote, property, logo, fontRegular: fonts.regular, fontBold: fonts.bold)],
        ),
      );
    } else {
      final cnNo = creditNote['credit_note_no']?.toString() ?? '';
      final cnDateRaw = creditNote['credit_note_date']?.toString() ?? '';
      final cnDate = DateTimeService.instance.parseToConfiguredTimeZone(cnDateRaw);

      final originalSaleNo = creditNote['sale'] is Map
          ? (creditNote['sale']['sale_no']?.toString() ?? '')
          : '';
      final originalSaleDateRaw = creditNote['sale'] is Map
          ? (creditNote['sale']['sale_date']?.toString() ?? '')
          : '';
      final originalSaleDate = DateTimeService.instance.parseToConfiguredTimeZone(originalSaleDateRaw);

      final customerName = creditNote['customer_name']?.toString() ?? 'Walk-in Customer';
      final customerPhone = creditNote['customer_phone']?.toString() ?? '--';
      final customerGstin = creditNote['customer_gstin']?.toString() ?? 'URD';

      final sellerName = property?.legalName.isNotEmpty == true
          ? property!.legalName
          : property?.propertyName ?? AppBrand.productName;

      final sellerAddressLines = [
        if ((property?.address ?? '').isNotEmpty) property!.address,
        if ((property?.city ?? '').isNotEmpty || (property?.pinCode ?? '').isNotEmpty)
          '${property?.city ?? ''} ${property?.pinCode ?? ''}'.trim(),
      ].join(', ');

      final itemsList = (creditNote['items'] as List? ?? const []).cast<Map<String, dynamic>>();

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 30),
          build: (_) => [
            // Header Row
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey700, width: 1),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 74,
                    height: 74,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.blueGrey700),
                    ),
                    child: logo == null
                        ? pw.Text(
                            'LOGO',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          )
                        : pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Image(logo, fit: pw.BoxFit.contain),
                          ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Center(
                      child: pw.Text(
                        'CREDIT NOTE',
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.SizedBox(
                    width: 170,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _a4MetaCNRow('CN Number', cnNo),
                        _a4MetaCNRow('Credit Note Dt', _date.format(cnDate)),
                        _a4MetaCNRow('Original Inv No', originalSaleNo),
                        _a4MetaCNRow('Original Inv Dt', _date.format(originalSaleDate)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Seller and Buyer Row
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Details of Seller', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                        pw.SizedBox(height: 4),
                        pw.Text(sellerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        pw.Text(sellerAddressLines, style: const pw.TextStyle(fontSize: 8.5)),
                        if (property?.printMobile != false && (property?.mobile ?? '').isNotEmpty) pw.Text('Phone: ${property!.mobile}', style: const pw.TextStyle(fontSize: 8.5)),
                        if (property?.printEmail != false && (property?.email ?? '').isNotEmpty) pw.Text('Email: ${property!.email}', style: const pw.TextStyle(fontSize: 8.5)),
                        if (property?.printWebsite != false && (property?.website ?? '').isNotEmpty) pw.Text('Website: ${property!.website}', style: const pw.TextStyle(fontSize: 8.5)),
                        if ((property?.gstNo ?? '').isNotEmpty) pw.Text('${_taxIdLabel()}: ${property!.gstNo}', style: const pw.TextStyle(fontSize: 8.5)),
                        if ((property?.panNo ?? '').isNotEmpty) pw.Text('${_businessRegLabel()}: ${property!.panNo}', style: const pw.TextStyle(fontSize: 8.5)),
                        if ((property?.drugLicenseNo ?? '').isNotEmpty) pw.Text('DL No: ${property!.drugLicenseNo}', style: const pw.TextStyle(fontSize: 8.5)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Details of Buyer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                        pw.SizedBox(height: 4),
                        pw.Text(customerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        pw.Text('Phone: $customerPhone', style: const pw.TextStyle(fontSize: 8.5)),
                        if (customerGstin.isNotEmpty) pw.Text('${_taxIdLabel()}: $customerGstin', style: const pw.TextStyle(fontSize: 8.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Items Table
            pw.Table.fromTextArray(
              headers: const [
                'S.No',
                'Description of Goods',
                'Qty',
                'Rate',
                'Taxable Value',
                'GST %',
                'CGST',
                'SGST',
                'IGST',
                'Total Amount'
              ],
              data: List.generate(itemsList.length, (index) {
                final it = itemsList[index];
                final qty = double.tryParse((it['qty'] ?? 0).toString()) ?? 0.0;
                final rate = double.tryParse((it['rate'] ?? 0).toString()) ?? 0.0;
                final taxable = double.tryParse((it['taxable_amount'] ?? 0).toString()) ?? 0.0;
                final taxPercent = double.tryParse((it['tax_percent'] ?? 0).toString()) ?? 0.0;
                final cgst = double.tryParse((it['cgst_amount'] ?? 0).toString()) ?? 0.0;
                final sgst = double.tryParse((it['sgst_amount'] ?? 0).toString()) ?? 0.0;
                final igst = double.tryParse((it['igst_amount'] ?? 0).toString()) ?? 0.0;
                final total = double.tryParse((it['line_total'] ?? 0).toString()) ?? 0.0;

                return [
                  '${index + 1}',
                  '${it['item_name'] ?? ''}',
                  qty.toStringAsFixed(2),
                  rate.toStringAsFixed(2),
                  taxable.toStringAsFixed(2),
                  '${taxPercent.toStringAsFixed(0)}%',
                  cgst > 0 ? cgst.toStringAsFixed(2) : '-',
                  sgst > 0 ? sgst.toStringAsFixed(2) : '-',
                  igst > 0 ? igst.toStringAsFixed(2) : '-',
                  total.toStringAsFixed(2),
                ];
              }),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
              cellStyle: const pw.TextStyle(fontSize: 8),
              columnWidths: const {
                0: pw.FixedColumnWidth(25),
                1: pw.FlexColumnWidth(4),
                2: pw.FixedColumnWidth(35),
                3: pw.FixedColumnWidth(45),
                4: pw.FixedColumnWidth(55),
                5: pw.FixedColumnWidth(35),
                6: pw.FixedColumnWidth(40),
                7: pw.FixedColumnWidth(40),
                8: pw.FixedColumnWidth(40),
                9: pw.FixedColumnWidth(60),
              },
              cellAlignment: pw.Alignment.centerRight,
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
              },
            ),
            pw.SizedBox(height: 12),

            // Bottom Section
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey500),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Amount in Words',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text(
                              _amountInWords(double.tryParse((creditNote['net_amount'] ?? 0).toString()) ?? 0.0),
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'Notes: ${creditNote['notes'] ?? ''}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.SizedBox(
                  width: 240,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey600),
                    ),
                    child: pw.Column(
                      children: [
                        _a4MetaCNRow('Total Qty Returned', '${double.tryParse((creditNote['total_qty'] ?? 0).toString())?.toStringAsFixed(2)}'),
                        _a4MetaCNRow('Taxable Value', '${double.tryParse((creditNote['taxable_amount'] ?? 0).toString())?.toStringAsFixed(2)}'),
                        if ((double.tryParse((creditNote['cgst_amount'] ?? 0).toString()) ?? 0) > 0)
                          _a4MetaCNRow('Total CGST', '${double.tryParse((creditNote['cgst_amount'] ?? 0).toString())?.toStringAsFixed(2)}'),
                        if ((double.tryParse((creditNote['sgst_amount'] ?? 0).toString()) ?? 0) > 0)
                          _a4MetaCNRow('Total SGST', '${double.tryParse((creditNote['sgst_amount'] ?? 0).toString())?.toStringAsFixed(2)}'),
                        if ((double.tryParse((creditNote['igst_amount'] ?? 0).toString()) ?? 0) > 0)
                          _a4MetaCNRow('Total IGST', '${double.tryParse((creditNote['igst_amount'] ?? 0).toString())?.toStringAsFixed(2)}'),
                        _a4MetaCNRow('Total Tax', '${double.tryParse((creditNote['total_tax'] ?? 0).toString())?.toStringAsFixed(2)}'),
                        pw.Divider(),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('REFUND VALUE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                            pw.Text(
                              _money(double.tryParse((creditNote['net_amount'] ?? 0).toString()) ?? 0.0),
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Row(
              children: [
                pw.Spacer(),
                pw.Expanded(
                  child: pw.Container(
                    height: 48,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey500),
                    ),
                    child: pw.Align(
                      alignment: pw.Alignment.bottomCenter,
                      child: pw.Text(
                        'Authorized Signatory',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return document.save();
  }

  static pw.Widget _buildThermalCreditNoteReceipt(
      Map<String, dynamic> creditNote, PropertyInfo? property, pw.MemoryImage? logo,
      {pw.Font? fontRegular, pw.Font? fontBold}) {
    final regular = fontRegular ?? _cachedRegular ?? pw.Font.helvetica();
    final bold = fontBold ?? _cachedBold ?? pw.Font.helveticaBold();
    final bodyStyle =
        pw.TextStyle(font: regular, fontSize: 8.9, color: _thermalSecondary);
    final emphasisStyle =
        pw.TextStyle(font: bold, fontSize: 9.6, color: _thermalPrimary);
    final storeStyle =
        pw.TextStyle(font: bold, fontSize: 12.8, color: _thermalPrimary);
    final grandStyle =
        pw.TextStyle(font: bold, fontSize: 14, color: _thermalPrimary);

    final cnNo = creditNote['credit_note_no']?.toString() ?? '';
    final cnDateRaw = creditNote['credit_note_date']?.toString() ?? '';
    final cnDate = DateTimeService.instance.parseToConfiguredTimeZone(cnDateRaw);

    final originalSaleNo = creditNote['sale'] is Map
        ? (creditNote['sale']['sale_no']?.toString() ?? '')
        : '';
    final originalSaleDateRaw = creditNote['sale'] is Map
        ? (creditNote['sale']['sale_date']?.toString() ?? '')
        : '';
    final originalSaleDate = DateTimeService.instance.parseToConfiguredTimeZone(originalSaleDateRaw);

    final customerName = creditNote['customer_name']?.toString() ?? 'Walk-in Customer';
    final customerPhone = creditNote['customer_phone']?.toString() ?? '--';
    final customerGstin = creditNote['customer_gstin']?.toString() ?? '';

    final itemsList = (creditNote['items'] as List? ?? const []).cast<Map<String, dynamic>>();

    final cgstTotal = double.tryParse((creditNote['cgst_amount'] ?? 0).toString()) ?? 0.0;
    final sgstTotal = double.tryParse((creditNote['sgst_amount'] ?? 0).toString()) ?? 0.0;
    final igstTotal = double.tryParse((creditNote['igst_amount'] ?? 0).toString()) ?? 0.0;

    return pw.DefaultTextStyle(
      style: bodyStyle,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Container(
                  width: logo == null ? 0 : 44,
                  height: logo == null ? 0 : 44,
                  margin: pw.EdgeInsets.only(bottom: logo == null ? 0 : 4),
                  child: logo == null
                      ? null
                      : pw.Image(logo, fit: pw.BoxFit.contain),
                ),
                pw.Text(
                  property?.legalName.isNotEmpty == true
                      ? property!.legalName
                      : property?.propertyName ?? AppBrand.productName,
                  textAlign: pw.TextAlign.center,
                  style: storeStyle,
                ),
                if (property?.address != null && property!.address.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Text(
                      property.address,
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                if (property?.printMobile != false && (property?.mobile ?? '').isNotEmpty)
                  pw.Text(
                    'Phone: ${property!.mobile}',
                    textAlign: pw.TextAlign.center,
                  ),
                if (property?.printEmail != false && (property?.email ?? '').isNotEmpty)
                  pw.Text(
                    'Email: ${property!.email}',
                    textAlign: pw.TextAlign.center,
                  ),
                if (property?.printWebsite != false && (property?.website ?? '').isNotEmpty)
                  pw.Text(
                    'Website: ${property!.website}',
                    textAlign: pw.TextAlign.center,
                  ),
                if ((property?.gstNo ?? '').isNotEmpty)
                  pw.Text(
                    '${_taxIdLabel()}: ${property!.gstNo}',
                    textAlign: pw.TextAlign.center,
                  ),
                if ((property?.panNo ?? '').isNotEmpty)
                  pw.Text(
                    '${_businessRegLabel()}: ${property!.panNo}',
                    textAlign: pw.TextAlign.center,
                  ),
                if ((property?.drugLicenseNo ?? '').isNotEmpty)
                  pw.Text(
                    'DL No: ${property!.drugLicenseNo}',
                    textAlign: pw.TextAlign.center,
                  ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'CREDIT NOTE',
                  style: emphasisStyle.copyWith(fontSize: 11),
                ),
                pw.Text(
                  _isIndiaCountry(null) ? 'GST COMPLIANT' : 'TAX COMPLIANT',
                  style: bodyStyle.copyWith(fontSize: 7.5),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: _thermalDivider, thickness: 0.8),
          
          // CN and Sale Details
          _thermalRow('CN No:', cnNo, bold: true),
          _thermalRow('CN Date:', formatTzDate(cnDate)),
          _thermalRow('Orig Bill No:', originalSaleNo),
          _thermalRow('Orig Bill Date:', formatTzDate(originalSaleDate)),
          pw.Divider(color: _thermalDivider, thickness: 0.8),

          // Customer Details
          if (customerName.isNotEmpty) _thermalRow('Customer:', customerName),
          if (customerPhone != '--') _thermalRow('Phone:', customerPhone),
          if (customerGstin.isNotEmpty) _thermalRow('${_taxIdLabel()}:', customerGstin),
          pw.Divider(color: _thermalDivider, thickness: 0.8),

          // Table Header
          pw.Row(
            children: [
              pw.Expanded(child: pw.Text('Item Description', style: emphasisStyle)),
              pw.Container(width: 35, alignment: pw.Alignment.centerRight, child: pw.Text('Qty', style: emphasisStyle)),
              pw.Container(width: 45, alignment: pw.Alignment.centerRight, child: pw.Text('Rate', style: emphasisStyle)),
              pw.Container(width: 50, alignment: pw.Alignment.centerRight, child: pw.Text('Total', style: emphasisStyle)),
            ],
          ),
          pw.Divider(color: _thermalDivider, thickness: 0.5),

          // Items List
          ...itemsList.map((it) {
            final name = it['item_name'] ?? '';
            final qty = double.tryParse((it['qty'] ?? 0).toString()) ?? 0.0;
            final rate = double.tryParse((it['rate'] ?? 0).toString()) ?? 0.0;
            final total = double.tryParse((it['line_total'] ?? 0).toString()) ?? 0.0;

            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(name, style: emphasisStyle.copyWith(fontSize: 8.5)),
                  pw.Row(
                    children: [
                      pw.Spacer(),
                      pw.Container(
                        width: 35,
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(qty.toStringAsFixed(2)),
                      ),
                      pw.Container(
                        width: 45,
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(rate.toStringAsFixed(2)),
                      ),
                      pw.Container(
                        width: 50,
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(total.toStringAsFixed(2)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          pw.Divider(color: _thermalDivider, thickness: 0.8),

          // Totals
          _thermalRow('Total Qty Returned:', '${double.tryParse((creditNote['total_qty'] ?? 0).toString())?.toStringAsFixed(2)}'),
          _thermalRow('Taxable Value:', '${double.tryParse((creditNote['taxable_amount'] ?? 0).toString())?.toStringAsFixed(2)}'),
          if (cgstTotal > 0) _thermalRow('Total CGST:', cgstTotal.toStringAsFixed(2)),
          if (sgstTotal > 0) _thermalRow('Total SGST/UTGST:', sgstTotal.toStringAsFixed(2)),
          if (igstTotal > 0) _thermalRow('Total IGST:', igstTotal.toStringAsFixed(2)),
          _thermalRow('Total Tax:', '${double.tryParse((creditNote['total_tax'] ?? 0).toString())?.toStringAsFixed(2)}'),
          pw.Divider(color: _thermalDivider, thickness: 0.5),

          // Grand Total / Refund
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('REFUND VALUE:', style: emphasisStyle.copyWith(fontSize: 11)),
              pw.Text(
                _money(double.tryParse((creditNote['net_amount'] ?? 0).toString()) ?? 0.0),
                style: grandStyle,
              ),
            ],
          ),
          pw.Divider(color: _thermalDivider, thickness: 0.8),

          // Amount in Words & Notes
          pw.Text('Amount in Words:', style: emphasisStyle.copyWith(fontSize: 8)),
          pw.Text(_amountInWords(double.tryParse((creditNote['net_amount'] ?? 0).toString()) ?? 0.0), style: bodyStyle.copyWith(fontSize: 8)),
          if ((creditNote['notes'] ?? '').toString().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text('Notes: ${creditNote['notes']}', style: bodyStyle.copyWith(fontSize: 8)),
          ],
          
          pw.SizedBox(height: 15),
          pw.Center(
            child: pw.Text('Authorized Signatory', style: emphasisStyle.copyWith(fontSize: 8)),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text('Thank You', style: emphasisStyle.copyWith(fontSize: 9)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _thermalRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
          pw.Text(value, style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
        ],
      ),
    );
  }

  static pw.Widget _a4MetaCNRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Text(
            '$label: ',
            style: pw.TextStyle(fontSize: 8.8, fontWeight: pw.FontWeight.bold),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 8.8),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  static String _titleCase(String value) {
    return value
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  static Future<void> printRefundReceipt({
    required Map<String, dynamic> order,
    required PropertyInfo? property,
    required double refundAmt,
    required String refundTxnId,
    required String refundedAt,
    required String pmDetails,
    required String gateway,
    String? creditNoteNo,
  }) async {
    final pdfBytes = await buildRefundReceiptPdf(
      order: order,
      property: property,
      refundAmt: refundAmt,
      refundTxnId: refundTxnId,
      refundedAt: refundedAt,
      pmDetails: pmDetails,
      gateway: gateway,
      creditNoteNo: creditNoteNo,
    );
    await Printing.layoutPdf(name: 'Refund_${order['sale_no'] ?? refundTxnId}', onLayout: (_) async => pdfBytes);
  }

  static Future<Uint8List> buildRefundReceiptPdf({
    required Map<String, dynamic> order,
    required PropertyInfo? property,
    required double refundAmt,
    required String refundTxnId,
    required String refundedAt,
    required String pmDetails,
    required String gateway,
    String? creditNoteNo,
  }) async {
    final fonts = await getInvoiceFonts();
    final document = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fonts.regular,
        bold: fonts.bold,
      ),
    );
    final pageFormat = _thermalSheetFor('THERMAL_80');
    final formattedDate = refundedAt.isNotEmpty ? refundedAt : DateTimeService.instance.formatNow('dd-MMM-yyyy hh:mm a');

    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        build: (_) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      property?.propertyName ?? AppBrand.companyName,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                    ),
                    if (property?.address != null && property!.address.isNotEmpty)
                      pw.Text(property.address, style: const pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.center),
                    if (property?.printMobile != false && property?.mobile != null && property!.mobile.isNotEmpty)
                      pw.Text('Phone: ${property.mobile}', style: const pw.TextStyle(fontSize: 7.5)),
                    if (property?.printEmail != false && property?.email != null && property!.email.isNotEmpty)
                      pw.Text('Email: ${property.email}', style: const pw.TextStyle(fontSize: 7.5)),
                    if (property?.printWebsite != false && property?.website != null && property!.website.isNotEmpty)
                      pw.Text('Website: ${property.website}', style: const pw.TextStyle(fontSize: 7.5)),
                    if (property?.gstNo != null && property!.gstNo.isNotEmpty)
                      pw.Text('${_taxIdLabel()}: ${property.gstNo}', style: const pw.TextStyle(fontSize: 7.5)),
                    if (property?.panNo != null && property!.panNo.isNotEmpty)
                      pw.Text('${_businessRegLabel()}: ${property.panNo}', style: const pw.TextStyle(fontSize: 7.5)),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'ONLINE REFUND RECEIPT',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                ),
              ),
              pw.SizedBox(height: 4),
              _thermalDividerWidget(),
              pw.SizedBox(height: 4),
              
              _thermalReceiptRow('Refund Date:', formattedDate),
              _thermalReceiptRow('Refund Txn ID:', refundTxnId),
              if (order['status'] == 'CANCELLED')
                _thermalReceiptRow('Order No:', '#${order['id'] ?? 'N/A'}')
              else if (order['status'] == 'DELIVERED')
                _thermalReceiptRow('Bill No:', '${order['bill_no'] ?? order['id'] ?? 'N/A'}')
              else
                _thermalReceiptRow('Original Order ID:', '#${order['id'] ?? 'N/A'}'),
              if (creditNoteNo != null && creditNoteNo.isNotEmpty && creditNoteNo != 'N/A')
                _thermalReceiptRow('Credit Note No:', creditNoteNo),
              _thermalReceiptRow('Gateway Provider:', gateway),
              _thermalReceiptRow('Payment Method:', pmDetails),
              
              pw.SizedBox(height: 4),
              _thermalDividerWidget(),
              pw.SizedBox(height: 4),
              
              pw.Text('Customer Info:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
              pw.SizedBox(height: 2),
              pw.Text('Name: ${order['customer_name'] ?? 'N/A'}', style: const pw.TextStyle(fontSize: 7.5)),
              pw.Text('Phone: ${order['customer_phone'] ?? 'N/A'}', style: const pw.TextStyle(fontSize: 7.5)),
              if (order['customer_address'] != null && order['customer_address'].toString().isNotEmpty)
                pw.Text('Address: ${order['customer_address']}', style: const pw.TextStyle(fontSize: 7.5)),
                
              pw.SizedBox(height: 4),
              _thermalDividerWidget(),
              pw.SizedBox(height: 4),

              _thermalReceiptRow('Original Amount Paid:', CurrencyService.format(double.tryParse(order['net_amount']?.toString() ?? '0.0') ?? 0.0)),
              _thermalReceiptRow('Refunded Amount:', CurrencyService.format(refundAmt), isBold: true),
              
              pw.SizedBox(height: 6),
              _thermalDividerWidget(),
              pw.SizedBox(height: 6),
              
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'The refund amount will be credited back to your source account/card/UPI within 3 business days.',
                      style: pw.TextStyle(fontSize: 6.8, fontStyle: pw.FontStyle.italic),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Thank you for your business.',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _thermalDividerWidget() {
    return pw.Container(
      height: 1,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 0.8, style: pw.BorderStyle.dashed, color: PdfColors.black),
        ),
      ),
    );
  }

  static pw.Widget _thermalReceiptRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 7.5, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 7.5, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  static pw.Widget _buildScissorsIcon() {
    return pw.Container(
      width: 16,
      height: 8,
      child: pw.Stack(
        alignment: pw.Alignment.center,
        children: [
          pw.Positioned(
            left: 0,
            top: 0,
            child: pw.Container(
              width: 4,
              height: 4,
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                border: pw.Border.all(width: 0.8, color: PdfColors.black),
              ),
            ),
          ),
          pw.Positioned(
            left: 0,
            bottom: 0,
            child: pw.Container(
              width: 4,
              height: 4,
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                border: pw.Border.all(width: 0.8, color: PdfColors.black),
              ),
            ),
          ),
          pw.Positioned(
            left: 3,
            top: 1.5,
            child: pw.Transform.rotate(
              angle: 0.25,
              child: pw.Container(
                width: 10,
                height: 0.8,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.Positioned(
            left: 3,
            bottom: 1.5,
            child: pw.Transform.rotate(
              angle: -0.25,
              child: pw.Container(
                width: 10,
                height: 0.8,
                color: PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCutLineWithScissors() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Divider(
              height: 0,
              thickness: 0.7,
              borderStyle: pw.BorderStyle.dashed,
              color: PdfColors.black,
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6),
            child: _buildScissorsIcon(),
          ),
          pw.Expanded(
            child: pw.Divider(
              height: 0,
              thickness: 0.7,
              borderStyle: pw.BorderStyle.dashed,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildThermalVoucherTicketEmbedded(
    SaleOrder order,
    List<dynamic> vouchers,
    pw.Font regular,
    pw.Font bold,
    PropertyInfo? property, {
    required bool isCustomerCopy,
  }) {
    if (vouchers.isEmpty) return pw.SizedBox();

    final firstVoucher = Map<String, dynamic>.from(vouchers.first as Map);
    final bodyStyle = pw.TextStyle(font: regular, fontSize: 8.5, color: _thermalSecondary);
    final boldStyle = pw.TextStyle(font: bold, fontSize: 8.5, color: _thermalPrimary);
    final titleStyle = pw.TextStyle(font: bold, fontSize: 10.0, color: _thermalPrimary);

    final campaignName = firstVoucher['campaign_name']?.toString() ?? 'Lucky Draw';
    final campaignDesc = firstVoucher['campaign_description']?.toString() ?? '';
    final customerPhone = firstVoucher['customer_phone']?.toString() ?? '--';
    final customerName = firstVoucher['customer_name']?.toString() ?? 'Walk-in';
    final billNo = order.saleNo;

    // Group voucher codes
    final List<String> codes = vouchers.map((v) {
      final vMap = Map<String, dynamic>.from(v as Map);
      return (vMap['code'] ?? vMap['voucher_code'] ?? '').toString();
    }).where((c) => c.isNotEmpty).toList();

    // Store Info
    final String storeName = property?.propertyName ?? '';
    final String storeAddress = property?.address ?? '';
    final String storeCity = property?.city ?? '';
    final String storePin = property?.pinCode ?? '';
    final String storePhone = property?.printMobile != false ? (property?.mobile ?? '') : '';
    final String cityPin = '$storeCity $storePin'.trim();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _buildCutLineWithScissors(),
        pw.SizedBox(height: 4),
        // Rounded grey container with thin border - watermark style background
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100, // Halftone background watermark representation
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (storeName.isNotEmpty) ...[
                pw.Text(
                  storeName.toUpperCase(),
                  style: pw.TextStyle(font: bold, fontSize: 9.5, color: _thermalPrimary),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 1.5),
              ],
              if (storeAddress.isNotEmpty) ...[
                pw.Text(
                  storeAddress,
                  style: pw.TextStyle(font: regular, fontSize: 7.0, color: _thermalSecondary),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 1.5),
              ],
              if (cityPin.isNotEmpty) ...[
                pw.Text(
                  cityPin,
                  style: pw.TextStyle(font: regular, fontSize: 7.0, color: _thermalSecondary),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 1.5),
              ],
              if (storePhone.isNotEmpty) ...[
                pw.Text(
                  'Phone: $storePhone',
                  style: pw.TextStyle(font: regular, fontSize: 7.0, color: _thermalSecondary),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 3),
              ],
              pw.Text(
                isCustomerCopy ? 'LUCKY DRAW TICKET (CUSTOMER COPY)' : 'LUCKY DRAW TICKET (STORE COPY)',
                style: titleStyle,
                textAlign: pw.TextAlign.center,
              ),
              if (campaignDesc.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text(
                  campaignDesc,
                  style: pw.TextStyle(font: regular, fontSize: 7.5, color: _thermalSecondary),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Campaign:', style: boldStyle),
                  pw.Text(campaignName, style: bodyStyle),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bill No:', style: boldStyle),
                  pw.Text(billNo, style: bodyStyle),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Customer Name:', style: boldStyle),
                  pw.Text(customerName, style: bodyStyle),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Customer Phone:', style: boldStyle),
                  pw.Text(customerPhone, style: bodyStyle),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(height: 0, thickness: 0.5, color: PdfColors.grey300),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Ticket Code:', style: boldStyle),
                  pw.Text(codes.isNotEmpty ? codes.first : 'LD-A7X9-123', style: pw.TextStyle(font: bold, fontSize: 10.0, color: _thermalPrimary)),
                ],
              ),
              pw.SizedBox(height: 6),
              if (isCustomerCopy)
                pw.Text(
                  'Keep this bill safe to claim your prize!',
                  style: pw.TextStyle(font: regular, fontSize: 7.5, color: _thermalSecondary),
                  textAlign: pw.TextAlign.center,
                )
              else
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Customer: _________', style: pw.TextStyle(font: regular, fontSize: 7.5, color: _thermalSecondary)),
                      pw.Text('Cashier: _________', style: pw.TextStyle(font: regular, fontSize: 7.5, color: _thermalSecondary)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static Future<Uint8List> buildTokenTicketPdf({
    required SaleOrder order,
    required PropertyInfo? property,
    required String stationLocation,
    required List<SaleItem> stationItems,
    SystemSettings? settings,
    Map<String, dynamic>? tokenTemplateConfig,
    int copyCount = 1,
  }) async {
    final fonts = await getInvoiceFonts();
    final document = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fonts.regular,
        bold: fonts.bold,
      ),
    );
    final regular = fonts.regular;
    final bold = fonts.bold;

    final config = tokenTemplateConfig ?? settings?.tokenTemplateConfig ?? {};
    final String headerTitle = (config['header_title']?.toString() ?? 'ORDER TOKEN').trim();
    final String subTitle = (config['sub_title']?.toString() ?? 'PLEASE WAIT FOR YOUR TURN').trim();
    final String counterTitle = (config['counter_title']?.toString() ?? 'COUNTER #1').trim();
    final String footerNote = (config['footer_note']?.toString() ?? 'Present this token when collecting your order').trim();
    final String badgeStyle = (config['badge_style']?.toString() ?? 'INVERTED_BOX').trim();
    final String fontSizeMode = (config['font_size']?.toString() ?? 'MEDIUM').trim();
    final String paperWidthMode = (config['paper_width']?.toString() ?? '80mm').trim();

    final bool showStoreName = config['show_store_name'] != false;
    final bool showBigNumber = config['show_big_number'] != false;
    final bool showOrderNo = config['show_order_no'] != false;
    final bool showTimestamp = config['show_timestamp'] != false;
    final bool showCounter = config['show_counter'] != false;
    final bool showCustomer = config['show_customer'] != false;
    final bool showItemsSummary = config['show_items_summary'] != false;
    final bool showItemCount = config['show_item_count'] != false;
    final bool showBarcode = config['show_barcode'] != false;
    final bool showCutLine = config['show_cut_line'] != false;

    final double fontScale = fontSizeMode == 'LARGE'
        ? 1.2
        : (fontSizeMode == 'SMALL' ? 0.85 : 1.0);

    final pageFormat = paperWidthMode == '58mm'
        ? const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 3 * PdfPageFormat.mm)
        : _thermalSheetFor(order.billFormat);

    final tokenNoStr = (order.tokenNo ?? '').trim().isNotEmpty
        ? order.tokenNo!.trim()
        : 'TK-${(order.orderId ?? 101).toString().padLeft(3, '0')}';

    pw.Widget buildTokenBadge() {
      if (badgeStyle == 'BORDER_BOX') {
        return pw.Container(
          padding: pw.EdgeInsets.symmetric(vertical: 8 * fontScale, horizontal: 12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 2),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'TOKEN NUMBER',
                style: pw.TextStyle(font: bold, fontSize: 9 * fontScale, color: PdfColors.grey800, letterSpacing: 1.2),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                tokenNoStr,
                style: pw.TextStyle(font: bold, fontSize: 28 * fontScale, color: PdfColors.black),
              ),
            ],
          ),
        );
      } else if (badgeStyle == 'CIRCLE') {
        return pw.Container(
          padding: pw.EdgeInsets.symmetric(vertical: 10 * fontScale, horizontal: 16),
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            border: pw.Border.all(color: PdfColors.black, width: 2.5),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'TOKEN',
                style: pw.TextStyle(font: bold, fontSize: 8 * fontScale, color: PdfColors.grey800),
              ),
              pw.Text(
                tokenNoStr,
                style: pw.TextStyle(font: bold, fontSize: 26 * fontScale, color: PdfColors.black),
              ),
            ],
          ),
        );
      } else if (badgeStyle == 'MINIMAL') {
        return pw.Container(
          padding: pw.EdgeInsets.symmetric(vertical: 6 * fontScale, horizontal: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.black, width: 1.5),
              bottom: pw.BorderSide(color: PdfColors.black, width: 1.5),
            ),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'TOKEN NO: $tokenNoStr',
                style: pw.TextStyle(font: bold, fontSize: 22 * fontScale, color: PdfColors.black),
              ),
            ],
          ),
        );
      } else {
        // INVERTED_BOX
        return pw.Container(
          padding: pw.EdgeInsets.symmetric(vertical: 8 * fontScale, horizontal: 12),
          decoration: const pw.BoxDecoration(
            color: PdfColors.black,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'TOKEN NUMBER',
                style: pw.TextStyle(font: bold, fontSize: 9 * fontScale, color: PdfColors.white, letterSpacing: 1.2),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                tokenNoStr,
                style: pw.TextStyle(font: bold, fontSize: 28 * fontScale, color: PdfColors.white),
              ),
            ],
          ),
        );
      }
    }

    for (int c = 0; c < math.max(1, copyCount); c++) {
      document.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          build: (_) => [
            pw.DefaultTextStyle(
              style: pw.TextStyle(font: regular, fontSize: 9 * fontScale, color: PdfColors.black),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // 1. SHOP HEADER
                  if (showStoreName) ...[
                    pw.Center(
                      child: pw.Text(
                        property?.propertyName.trim().isNotEmpty == true
                            ? property!.propertyName.trim().toUpperCase()
                            : AppBrand.productName.toUpperCase(),
                        style: pw.TextStyle(font: bold, fontSize: 12 * fontScale, color: PdfColors.black),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                  ],
                  if (headerTitle.isNotEmpty)
                    pw.Center(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey200,
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                        ),
                        child: pw.Text(
                          headerTitle.toUpperCase(),
                          style: pw.TextStyle(font: bold, fontSize: 9 * fontScale, color: PdfColors.black),
                        ),
                      ),
                    ),
                  if (subTitle.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Center(
                      child: pw.Text(
                        subTitle,
                        style: pw.TextStyle(font: regular, fontSize: 7.5 * fontScale, color: PdfColors.grey700),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 6),

                  // 2. TOKEN NUMBER BADGE
                  if (showBigNumber) buildTokenBadge(),
                  if (showCounter && counterTitle.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Center(
                      child: pw.Text(
                        counterTitle.toUpperCase(),
                        style: pw.TextStyle(font: bold, fontSize: 10 * fontScale, color: PdfColors.black),
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 6),
                  _dashedDivider(),

                  // 3. META DETAILS (BILL NO, STATION, TIME, CUSTOMER)
                  if (showOrderNo)
                    _thermalMetaRow('Bill No', order.saleNo, 'Station', stationLocation),
                  if (showTimestamp)
                    _thermalMetaRow('Date', formatTzDate(order.saleDate), 'Time', formatTzTime(order.saleDate)),
                  if (showCustomer && (order.customerName ?? '').trim().isNotEmpty)
                    _thermalMetaRow('Customer', order.customerName!.trim(), '', ''),
                  if (showItemCount)
                    _thermalMetaRow('Total Items', '${stationItems.length}', 'Total Qty', '${stationItems.fold<double>(0, (sum, it) => sum + it.qty)}'),
                  _dashedDivider(),

                  // 4. ITEM TABLE HEADER & LIST
                  if (showItemsSummary && stationItems.isNotEmpty) ...[
                    pw.Table(
                      columnWidths: const {
                        0: pw.FlexColumnWidth(2),
                        1: pw.FlexColumnWidth(7),
                      },
                      children: [
                        pw.TableRow(
                          children: [
                            _thermalHeaderCell('QTY', align: pw.TextAlign.left, style: pw.TextStyle(font: bold, fontSize: 8.5 * fontScale)),
                            _thermalHeaderCell('ITEM DESCRIPTION', align: pw.TextAlign.left, style: pw.TextStyle(font: bold, fontSize: 8.5 * fontScale)),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 3),
                    ...stationItems.map((item) {
                      final qtyStr = item.qty % 1 == 0 ? item.qty.toInt().toString() : item.qty.toStringAsFixed(2);
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.SizedBox(
                              width: 32,
                              child: pw.Text('${qtyStr}x', style: pw.TextStyle(font: bold, fontSize: 10 * fontScale)),
                            ),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    '${item.itemName}${(item.brand != null && item.brand!.trim().isNotEmpty) ? " (${item.brand!.trim()})" : ""}',
                                    style: pw.TextStyle(font: bold, fontSize: 9.5 * fontScale),
                                  ),
                                  if ((item.notes ?? '').trim().isNotEmpty)
                                    pw.Text('Note: ${item.notes!.trim()}', style: pw.TextStyle(font: regular, fontSize: 8 * fontScale, color: PdfColors.grey700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    _dashedDivider(),
                  ],

                  // 5. BARCODE & FOOTER INSTRUCTIONS
                  if (showBarcode) ...[
                    pw.SizedBox(height: 2),
                    pw.Center(
                      child: pw.SizedBox(
                        height: 26 * fontScale,
                        width: 140,
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.code128(),
                          data: tokenNoStr,
                          drawText: false,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                  ],
                  if (footerNote.isNotEmpty)
                    pw.Center(
                      child: pw.Text(
                        footerNote,
                        style: pw.TextStyle(font: bold, fontSize: 8 * fontScale),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  if (showCutLine) ...[
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Text('✂', style: pw.TextStyle(font: bold, fontSize: 9 * fontScale)),
                        pw.SizedBox(width: 4),
                        pw.Expanded(child: _dashedDivider()),
                        pw.SizedBox(width: 4),
                        pw.Text('CUT HERE', style: pw.TextStyle(font: bold, fontSize: 7 * fontScale)),
                        pw.SizedBox(width: 4),
                        pw.Expanded(child: _dashedDivider()),
                        pw.SizedBox(width: 4),
                        pw.Text('✂', style: pw.TextStyle(font: bold, fontSize: 9 * fontScale)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
    return document.save();
  }

  static Future<void> printTokenTickets({
    required SaleOrder order,
    required PropertyInfo? property,
    required SystemSettings settings,
    required String currentMachineId,
  }) async {
    if (!settings.enableTokenSystem || order.items.isEmpty || _isRestaurantOrder(order)) return;

    final allMappings = DevicePrinterRouting.getSectionMappings(settings, 'tokens');
    final Map<String, List<SaleItem>> stationGroups = {};

    if (allMappings.isNotEmpty) {
      final configuredLocs = allMappings
          .map((m) => m.location.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      for (final item in order.items) {
        final loc = (item.location ?? '').trim();
        String? targetLoc;
        if (loc.isNotEmpty) {
          for (final cLoc in configuredLocs) {
            if (cLoc.toLowerCase() == loc.toLowerCase()) {
              targetLoc = cLoc;
              break;
            }
          }
        }
        targetLoc ??= configuredLocs.first;
        stationGroups.putIfAbsent(targetLoc, () => []).add(item);
      }
    } else {
      stationGroups['General Counter'] = List.from(order.items);
    }

    if (stationGroups.isEmpty) return;

    final availablePrinters = await Printing.listPrinters();
    final deviceMappings = settings.devicePrinterMappings;
    final machineKey = currentMachineId.trim().toUpperCase();
    final Map<String, dynamic> machinePrinters = deviceMappings[machineKey] is Map
        ? Map<String, dynamic>.from(deviceMappings[machineKey])
        : (deviceMappings['DEFAULT'] is Map ? Map<String, dynamic>.from(deviceMappings['DEFAULT']) : {});

    final Map<String, dynamic> tokenStationPrinters = machinePrinters['tokens'] is Map
        ? Map<String, dynamic>.from(machinePrinters['tokens'])
        : {};

    for (final entry in stationGroups.entries) {
      final stationName = entry.key;
      final items = entry.value;

      final routings = DevicePrinterRouting.resolvePrinters(
        settings: settings,
        machineId: currentMachineId,
        sectionKey: 'tokens',
        location: stationName,
      );

      for (final routingInfo in routings) {
        final targetPrinterName = routingInfo.printer.trim();
        final copyCount = routingInfo.copies > 0 ? routingInfo.copies : settings.tokenCopiesCount;

        Printer? matchedPrinter;
        if (targetPrinterName.isNotEmpty) {
          matchedPrinter = availablePrinters.firstWhere(
            (p) => p.name.toLowerCase() == targetPrinterName.toLowerCase() || p.url.toLowerCase() == targetPrinterName.toLowerCase(),
            orElse: () => availablePrinters.isNotEmpty ? availablePrinters.first : Printer(name: targetPrinterName, url: targetPrinterName),
          );
        } else if (availablePrinters.isNotEmpty) {
          matchedPrinter = availablePrinters.first;
        }

        final pdfBytes = await buildTokenTicketPdf(
          order: order,
          property: property,
          settings: settings,
          tokenTemplateConfig: settings.tokenTemplateConfig,
          stationLocation: stationName,
          stationItems: items,
          copyCount: copyCount,
        );

        if (matchedPrinter != null) {
          try {
            await Printing.directPrintPdf(
              printer: matchedPrinter,
              name: 'TOKEN-${order.tokenNo ?? order.saleNo}-$stationName',
              onLayout: (_) async => pdfBytes,
            );
          } catch (_) {
            await Printing.layoutPdf(
              name: 'TOKEN-${order.tokenNo ?? order.saleNo}-$stationName',
              onLayout: (_) async => pdfBytes,
            );
          }
        } else {
          await Printing.layoutPdf(
            name: 'TOKEN-${order.tokenNo ?? order.saleNo}-$stationName',
            onLayout: (_) async => pdfBytes,
          );
        }
      }
    }
  }
}

class _InvoiceContext {
  final SaleOrder order;
  final PropertyInfo? property;
  final String cashierName;
  final String? terminalNo;
  final String? cashierId;
  final double? amountReceived;
  final double? changeDue;
  final String? sellerStateCode;
  final String? buyerState;
  final String? buyerStateCode;
  final String bankName;
  final String bankAccountNo;
  final String bankIfscCode;
  final String termsAndConditions;
  final String thankYouMessage;
  final String authorizedSignatureLabel;
  final bool showBrandName;
  final bool enableTokenSystem;
  final Map<String, dynamic> receiptTemplateConfig;
  final Map<String, dynamic> a4TemplateConfig;
  final pw.Font? regularFont;
  final pw.Font? boldFont;

  const _InvoiceContext({
    required this.order,
    required this.property,
    required this.cashierName,
    required this.terminalNo,
    required this.cashierId,
    required this.amountReceived,
    required this.changeDue,
    required this.sellerStateCode,
    required this.buyerState,
    required this.buyerStateCode,
    required this.bankName,
    required this.bankAccountNo,
    required this.bankIfscCode,
    required this.termsAndConditions,
    required this.thankYouMessage,
    required this.authorizedSignatureLabel,
    required this.showBrandName,
    required this.enableTokenSystem,
    this.receiptTemplateConfig = const {},
    this.a4TemplateConfig = const {},
    this.regularFont,
    this.boldFont,
  });
}

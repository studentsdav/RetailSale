import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/common/property_info_model.dart';
import '../../models/inventory/billing_charge_model.dart';
import '../../models/inventory/sale_item_model.dart';
import '../../models/inventory/sale_order_model.dart';
import '../../models/inventory/tax_breakdown_model.dart';
import '../config/app_brand.dart';
import '../../utils/branding_storage.dart';

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
  static final DateFormat _date = DateFormat('dd-MMM-yyyy');
  static final DateFormat _time = DateFormat('hh:mm a');
  static final DateFormat _dateTime = DateFormat('dd-MMM-yyyy hh:mm a');

  static bool _isThermalFormat(String billFormat) =>
      _thermalWidths.containsKey(billFormat);

  static PdfPageFormat _thermalSheetFor(String billFormat) {
    final widthMm = _thermalWidths[billFormat] ?? 80;
    final horizontalMargin = widthMm <= 58 ? 2.5 : 3.0;
    return PdfPageFormat(
      widthMm * PdfPageFormat.mm,
      297 * PdfPageFormat.mm,
      marginLeft: horizontalMargin * PdfPageFormat.mm,
      marginRight: horizontalMargin * PdfPageFormat.mm,
      marginTop: 4 * PdfPageFormat.mm,
      marginBottom: 4 * PdfPageFormat.mm,
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

    await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
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
  }) async {
    final document = pw.Document();
    final logo = await BrandingStorage.loadPdfLogo(property?.logoPath);
    final invoiceData = _InvoiceContext(
      order: order,
      property: property,
      cashierName: cashierName,
      terminalNo: terminalNo,
      cashierId: cashierId,
      amountReceived: amountReceived,
      changeDue: changeDue,
      sellerStateCode: sellerStateCode ?? _stateCodeFor(property?.state),
      buyerState: buyerState ?? _deriveBuyerState(order, property),
      buyerStateCode: buyerStateCode ??
          _stateCodeFor(buyerState) ??
          _stateCodeFromGstin(order.customerGstin) ??
          _stateCodeFor(_deriveBuyerState(order, property)),
      bankName: bankName,
      bankAccountNo: bankAccountNo,
      bankIfscCode: bankIfscCode,
      termsAndConditions: termsAndConditions,
      thankYouMessage: thankYouMessage,
      authorizedSignatureLabel: authorizedSignatureLabel,
    );

    if (_isThermalFormat(order.billFormat)) {
      document.addPage(
        pw.MultiPage(
          pageFormat: _thermalSheetFor(order.billFormat),
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

    return document.save();
  }

  static pw.Widget _buildThermalReceipt(
      _InvoiceContext data, pw.MemoryImage? logo) {
    final order = data.order;
    final regular = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();
    final bodyStyle =
        pw.TextStyle(font: regular, fontSize: 8.9, color: _thermalSecondary);
    final emphasisStyle =
        pw.TextStyle(font: bold, fontSize: 9.6, color: _thermalPrimary);
    final storeStyle =
        pw.TextStyle(font: bold, fontSize: 12.8, color: _thermalPrimary);
    final grandStyle =
        pw.TextStyle(font: bold, fontSize: 14, color: _thermalPrimary);
    final totalItems = order.items.length;
    final roundOff = _billRoundOff(order);
    final groupedTaxes = _groupedTaxBreakup(order);
    final hasTaxData = _hasTaxData(order);
    final cgstTotal = _taxAmountFromBreakup(groupedTaxes, 'CGST');
    final sgstTotal = _taxAmountFromBreakup(groupedTaxes, 'SGST');
    final igstTotal = _taxAmountFromBreakup(groupedTaxes, 'IGST');

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
                  data.property?.propertyName.isNotEmpty == true
                      ? data.property!.propertyName
                      : AppBrand.productName,
                  textAlign: pw.TextAlign.center,
                  style: storeStyle,
                ),
                if (_sellerAddress(data).isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Text(
                      _sellerAddress(data),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                if ((data.property?.mobile ?? '').isNotEmpty)
                  pw.Text(
                    'Phone: ${data.property!.mobile}',
                    textAlign: pw.TextAlign.center,
                  ),
                if ((data.property?.gstNo ?? '').isNotEmpty)
                  pw.Text(
                    'GSTIN: ${data.property!.gstNo}',
                    textAlign: pw.TextAlign.center,
                  ),
                if ((data.property?.drugLicenseNo ?? '').isNotEmpty)
                  pw.Text(
                    'DL No: ${data.property!.drugLicenseNo}',
                    textAlign: pw.TextAlign.center,
                  ),
                pw.SizedBox(height: 4),
                pw.Text(
                  order.status == 'CANCELLED'
                      ? 'CANCELLED BILL'
                      : order.status == 'DRAFT'
                          ? 'PROFORMA BILL'
                          : hasTaxData
                              ? 'TAX INVOICE'
                              : 'INVOICE',
                  style: emphasisStyle,
                ),
              ],
            ),
          ),
          _dashedDivider(),
          if (order.status == 'CANCELLED') ...[
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 4),
              padding: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
              ),
              child: pw.Center(
                child: pw.Text(
                  '*** CANCELLED ***',
                  style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.black),
                ),
              ),
            ),
            _dashedDivider(),
          ],
          _thermalMetaRow(
            (order.status == 'DELIVERED' || order.status == 'COMPLETED') ? 'Bill No' : 'Order No',
            order.saleNo,
            'Date',
            _date.format(order.saleDate),
          ),
          _thermalMetaRow(
            'Cashier',
            data.cashierName.trim().isEmpty
                ? 'System'
                : data.cashierName.trim(),
            'Time',
            _time.format(order.saleDate),
          ),
          if ((order.customerName ?? '').trim().isNotEmpty ||
              (order.customerPhone ?? '').trim().isNotEmpty)
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
            _thermalMetaRow('GSTIN', order.customerGstin!.trim(), '', ''),
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
          ...order.items.map((item) => _thermalItemRow(item, order)),
          _dashedDivider(),
          _thermalAmountRow('Total Items', totalItems.toDouble()),
          _thermalAmountRow('Total Qty', order.totalQty),
          _thermalAmountRow('Subtotal', order.subTotal),
          if (order.refundAmount > 0) ...[
            _dashedDivider(),
            _thermalAmountRow('Refunded Amt', order.refundAmount),
            _thermalAmountRow('Net Payable', order.netAmount - order.refundAmount),
          ],
          if (order.totalDiscount > 0)
            _thermalAmountRow(_savingLabel(order), order.totalDiscount),
          if (order.loyaltyPointsRedeemed > 0 &&
              order.loyaltyDiscountAmount > 0)
            pw.Text(
              'Savings by points redeemed: ${order.loyaltyPointsRedeemed} points (- ${order.loyaltyDiscountAmount.toStringAsFixed(2)})',
              style: emphasisStyle,
            ),
            if (hasTaxData) _dashedDivider(),
            if (hasTaxData) _thermalAmountRow('Taxable Amt', order.taxableAmount),
            if (hasTaxData && cgstTotal > 0)
              _thermalAmountRow('CGST', cgstTotal),
            if (hasTaxData && sgstTotal > 0)
              _thermalAmountRow('SGST', sgstTotal),
            if (hasTaxData && igstTotal > 0)
              _thermalAmountRow('IGST', igstTotal),
            ...order.charges.where((charge) => charge.amount > 0).map(
                  (charge) => _thermalAmountRow(
                    charge.name,
                    charge.amount,
                  ),
                ),
            if (hasTaxData && order.chargeTaxTotal > 0)
              _thermalAmountRow('Charge Tax', order.chargeTaxTotal),
          if (hasTaxData && groupedTaxes.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text('Tax Breakup', style: emphasisStyle),
            pw.SizedBox(height: 3),
            ...groupedTaxes.map(
              (tax) => _thermalTaxSummaryRow(
                tax.label,
                tax.taxableAmount,
                tax.taxAmount,
              ),
            ),
          ],
          if (roundOff.abs() > 0.0009)
            _thermalAmountRow(
              roundOff.abs() >= 1.0 ? 'Subscription Adj' : 'Round Off',
              roundOff,
            ),
          _dashedDivider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('NET PAYABLE', style: grandStyle),
              pw.Text(_money(order.netAmount), style: grandStyle),
            ],
          ),
          pw.SizedBox(height: 5),
          _thermalMetaRow(
            'Payment',
            order.paymentMode,
            order.refundAmount > 0
                ? 'Refund'
                : ((data.changeDue ?? order.changeAmount) > 0 ? 'Refund (CASH)' : 'Refund'),
            _money(order.refundAmount > 0
                ? order.refundAmount
                : (data.changeDue ?? order.changeAmount)),
          ),
          if ((data.amountReceived ?? order.amountPaid) > 0)
            _thermalMetaRow(
              'Received',
              _money(data.amountReceived ?? order.amountPaid),
              '',
              '',
            ),
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
          pw.Text(
            'Return Policy: Exchange within 7 days with original receipt',
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          if ((order.notes ?? '').trim().isNotEmpty)
            pw.Text(
              'Note: ${order.notes!.trim()}',
              textAlign: pw.TextAlign.center,
            ),
          if ((order.notes ?? '').trim().isNotEmpty) pw.SizedBox(height: 4),
          pw.Text(
            data.termsAndConditions,
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(data.thankYouMessage, textAlign: pw.TextAlign.center),
        ],
      ),
    );
  }

  static pw.Widget _buildA4Invoice(_InvoiceContext data, pw.MemoryImage? logo) {
    final order = data.order;
    final sellerState = data.property?.state ?? '';
    final buyerName = (order.customerName ?? '').trim().isEmpty
        ? 'Walk-in Customer'
        : order.customerName!.trim();
    final amountInWords = _amountInWords(order.netAmount);
    final sellerName = data.property?.legalName.isNotEmpty == true
        ? data.property!.legalName
        : data.property?.propertyName ?? AppBrand.productName;
    final hasTaxData = _hasTaxData(order);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
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
                    order.status == 'CANCELLED'
                        ? 'CANCELLED BILL'
                        : order.status == 'DRAFT'
                            ? 'DRAFT ORDER'
                            : hasTaxData
                                ? 'TAX INVOICE'
                                : 'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.SizedBox(
                width: 210,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      sellerName,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    if (_sellerAddress(data).isNotEmpty)
                      pw.Text(_sellerAddress(data),
                          style: const pw.TextStyle(fontSize: 8.8)),
                    if ((data.property?.mobile ?? '').isNotEmpty)
                      pw.Text('Contact: ${data.property!.mobile}',
                          style: const pw.TextStyle(fontSize: 8.8)),
                    if ((data.property?.email ?? '').isNotEmpty)
                      pw.Text('Email: ${data.property!.email}',
                          style: const pw.TextStyle(fontSize: 8.8)),
                    pw.Text(
                      'GSTIN: ${((data.property?.gstNo ?? '').trim().isEmpty) ? '--' : data.property!.gstNo.trim()}',
                      style: pw.TextStyle(
                        fontSize: 8.8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if ((data.property?.drugLicenseNo ?? '').isNotEmpty)
                      pw.Text(
                        'DL No: ${data.property!.drugLicenseNo}',
                        style: pw.TextStyle(
                          fontSize: 8.8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    pw.Text(
                      'State: ${sellerState.isEmpty ? '--' : sellerState} / ${data.sellerStateCode ?? '--'}',
                      style: const pw.TextStyle(fontSize: 8.8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        if (order.status == 'CANCELLED')
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            margin: const pw.EdgeInsets.only(bottom: 10),
            decoration: pw.BoxDecoration(
              color: PdfColors.red100,
              border: pw.Border.all(color: PdfColors.red500),
            ),
            child: pw.Center(
              child: pw.Text(
                'CANCELLED TRANSACTION / BILL',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red700),
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
                        (order.status == 'DELIVERED' || order.status == 'COMPLETED') ? 'Invoice No' : 'Order No',
                        order.saleNo,
                      ),
                      _a4MetaRow(
                        'Invoice Dt/Tm',
                        '${_date.format(order.saleDate)} ${_time.format(order.saleDate)}',
                      ),
                      _a4MetaRow(
                        'Cashier/Terminal',
                        '${data.cashierId ?? data.cashierName}${(data.terminalNo ?? '').trim().isNotEmpty ? ' / ${data.terminalNo}' : ''}',
                      ),
                      _a4MetaRow(
                        'Place of Supply',
                        data.buyerState != null && data.buyerState!.isNotEmpty
                            ? '${_titleCase(data.buyerState!)}${data.buyerStateCode != null ? ' / ${data.buyerStateCode}' : ''}'
                            : (sellerState.isNotEmpty ? '${_titleCase(sellerState)}${data.sellerStateCode != null ? ' / ${data.sellerStateCode}' : ''}' : '-'),
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
        _buildA4ItemsTable(order),
        pw.SizedBox(height: 12),
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
                        pw.Text(amountInWords,
                            style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey500),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Bank Details',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Bank: ${(data.bankName).trim().isEmpty ? '________________' : data.bankName}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          'A/c No: ${(data.bankAccountNo).trim().isEmpty ? '________________' : data.bankAccountNo}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          'IFSC: ${(data.bankIfscCode).trim().isEmpty ? '________________' : data.bankIfscCode}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey500),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Terms & Conditions',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          '1. Goods once sold will not be taken back.',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          '2. Subject to local jurisdiction.',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        if ((order.notes ?? '').trim().isNotEmpty) ...[
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'Note: ${order.notes!.trim()}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ],
                    ),
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
        pw.SizedBox(height: 14),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Container(
                height: 64,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey500),
                ),
                child: pw.Align(
                  alignment: pw.Alignment.bottomLeft,
                  child: pw.Text(
                    'Customer Signature',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Container(
                height: 64,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey500),
                ),
                child: pw.Align(
                  alignment: pw.Alignment.bottomRight,
                  child: pw.Text(
                    data.authorizedSignatureLabel,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildA4ItemsTable(SaleOrder order) {
    final hasTaxData = _hasTaxData(order);
    final headers = hasTaxData
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
            'SGST (Rate% & Amt)',
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

      final brandStr = item.brand != null && item.brand!.trim().isNotEmpty
          ? '${item.brand!.trim()} - '
          : '';
      final name =
          item.isSchemeFree ? '$brandStr${item.itemName} (FREE)$suffix' : '$brandStr${item.itemName}$suffix';
      if (hasTaxData) {
        return [
          '${index + 1}',
          name,
          item.hsnSacCode.isEmpty ? item.itemCode : item.hsnSacCode,
          _qty(item.qty),
          item.unit,
          _money(_displayRate(item)),
          _money(item.lineDiscount),
          _money(_taxableAmountForItem(item)),
          item.taxPercent <= 0 ? 'NILL' : '${_taxRate(order, item, 'CGST')} / ${_money(_taxAmount(order, item, 'CGST'))}',
          item.taxPercent <= 0 ? 'NILL' : '${_taxRate(order, item, 'SGST')} / ${_money(_taxAmount(order, item, 'SGST'))}',
          _money(item.lineTotal),
        ];
      }
      return [
        '${index + 1}',
        name,
        item.hsnSacCode.isEmpty ? item.itemCode : item.hsnSacCode,
        _qty(item.qty),
        item.unit,
        _money(_displayRate(item)),
        _money(item.lineDiscount),
        _money(item.lineTotal),
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
        0: const pw.FixedColumnWidth(24),
        1: const pw.FlexColumnWidth(2.8),
        2: const pw.FixedColumnWidth(52),
        3: const pw.FixedColumnWidth(30),
        4: const pw.FixedColumnWidth(26),
        5: const pw.FixedColumnWidth(42),
        6: const pw.FixedColumnWidth(42),
        7: const pw.FixedColumnWidth(56),
        if (hasTaxData) 8: const pw.FixedColumnWidth(62),
        if (hasTaxData) 9: const pw.FixedColumnWidth(62),
        if (hasTaxData) 10: const pw.FixedColumnWidth(56),
      },
    );
  }

  static pw.Widget _buildTotalsBox(SaleOrder order) {
    final hasTaxData = _hasTaxData(order);
    final roundOff = _billRoundOff(order);
    final savingsLabel = _savingLabel(order);
    final groupedTaxes = _groupedTaxBreakup(order);
    final cgstTotal = _taxAmountFromBreakup(groupedTaxes, 'CGST');
    final sgstTotal = _taxAmountFromBreakup(groupedTaxes, 'SGST');
    final igstTotal = _taxAmountFromBreakup(groupedTaxes, 'IGST');
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500),
      ),
      child: pw.Column(
        children: [
          if (order.totalDiscount > 0)
            _a4AmountRow(savingsLabel, order.totalDiscount),
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
          if (hasTaxData) _a4AmountRow('Taxable Value', order.taxableAmount),
          if (hasTaxData) _a4AmountRow('Total CGST Amount', cgstTotal),
          if (hasTaxData) _a4AmountRow('Total SGST Amount', sgstTotal),
          if (hasTaxData) _a4AmountRow('Total IGST Amount', igstTotal),
          if (roundOff.abs() > 0.0009)
            _a4AmountRow(
              roundOff.abs() >= 1.0 ? 'Subscription Adj' : 'Round Off',
              roundOff,
            ),
          pw.Divider(height: 10),
          _a4AmountRow('Grand Total', order.netAmount, bold: true),
          if (order.refundAmount > 0) ...[
            pw.Divider(height: 10),
            _a4AmountRow('Refunded Amount', order.refundAmount),
            _a4AmountRow('Net Payable', order.netAmount - order.refundAmount, bold: true),
          ],
          if (order.amountPaid > 0) ...[
            pw.Divider(height: 10),
            _a4AmountRow(
              order.paymentMode.isNotEmpty
                  ? 'Received (${order.paymentMode})'
                  : 'Received',
              order.amountPaid,
            ),
          ],
          if (order.changeAmount > 0)
            _a4AmountRow('Refund (CASH)', order.changeAmount),
        ],
      ),
    );
  }

  static String _savingLabel(SaleOrder order) {
    final mode = order.paymentMode.toUpperCase();
    if (mode == 'SUBSCRIPTION') {
      return 'Subscription Adjusted Amount';
    }
    if (mode == 'SCHEME') {
      return 'Scheme Savings';
    }
    return 'Total Savings';
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
        order.items.any((item) => item.taxPercent > 0);
  }

  static double _billRoundOff(SaleOrder order) {
    if (order.roundOffAmount.abs() > 0.0009) {
      return order.roundOffAmount;
    }
    final computedTotal = (order.subTotal - order.totalDiscount) +
        order.chargeTotal +
        order.totalTax;
    return double.parse((order.netAmount - computedTotal).toStringAsFixed(2));
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

  static pw.Widget _thermalItemRow(SaleItem item, SaleOrder order) {
    final font = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();

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
        '${_qty(item.qty)} ${item.unit.trim()} x ${_money(_displayRate(item))}';

    // 2. Build the secondary detail string separated by pipes (|) for a clean look
    final detailParts = <String>[
      if (hsnOrCode.isNotEmpty) 'HSN $hsnOrCode',
      qtyUnitRate,
      if (item.isSchemeFree) 'FREE',
      if (item.taxPercent > 0)
        // Show plain "GST 18% = Rs. X.XX" so customer clearly sees rate + amount
        'GST ${_formatTaxPercent(item.taxPercent)}%'
            '${item.taxAmount > 0 ? ' = ${_money(item.taxAmount)}' : ''}'
      else
        'GST NILL',
      if (item.lineDiscount > 0) 'Disc ${_money(item.lineDiscount)}',
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
                  item.isSchemeFree
                      ? '${item.brand != null && item.brand!.trim().isNotEmpty ? '${item.brand!.trim()} - ' : ''}${item.itemName.trim()} (FREE)${suffix}'
                      : '${item.brand != null && item.brand!.trim().isNotEmpty ? '${item.brand!.trim()} - ' : ''}${item.itemName.trim()}${suffix}',
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 8.7,
                    color: _thermalPrimary,
                  ),
                  softWrap: true,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                _money(item.lineTotal),
                style: pw.TextStyle(
                  font: bold,
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
              font: font,
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
    final font = pw.Font.helvetica();
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              '$leftLabel: $leftValue',
              style: pw.TextStyle(
                  font: font, fontSize: 8.1, color: _thermalSecondary),
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
                    font: font, fontSize: 8.1, color: _thermalSecondary),
                softWrap: true,
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _thermalAmountRow(String label, double value,
      {bool bold = false}) {
    final font = bold ? pw.Font.helveticaBold() : pw.Font.helvetica();
    final style = pw.TextStyle(
      font: font,
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

  static pw.Widget _thermalTaxSummaryRow(
      String label, double taxable, double tax) {
    final font = pw.Font.helvetica();
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
                  font: font,
                  fontSize: 7.8,
                  color: _thermalSecondary,
                ),
              ),
              pw.Text(
                _money(taxable),
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  font: font,
                  fontSize: 7.8,
                  color: _thermalSecondary,
                ),
              ),
              pw.Text(
                _money(tax),
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  font: font,
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

  static String _money(double value) => _currency.format(value);

  static String _qty(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  static String _formatTaxPercent(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  static List<TaxBreakdown> _sourceTaxBreakup(SaleOrder order) {
    if (order.taxBreakup.isNotEmpty) {
      return order.taxBreakup;
    }
    return order.items
        .expand((item) => _itemTaxBreakup(order, item))
        .toList(growable: false);
  }

  static List<TaxBreakdown> _groupedTaxBreakup(SaleOrder order) {
    final grouped = <String, TaxBreakdown>{};
    for (final tax in _sourceTaxBreakup(order)) {
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
    return grouped.values.toList();
  }

  static List<TaxBreakdown> _itemTaxBreakup(SaleOrder order, SaleItem item) {
    if (item.taxBreakup.isNotEmpty) {
      return item.taxBreakup;
    }

    final taxPercent = item.taxPercent;
    if (taxPercent <= 0) return const <TaxBreakdown>[];

    final taxableAmount = item.taxableAmount.abs() > 0.0009
        ? item.taxableAmount
        : item.referenceRate > 0
            ? item.referenceRate * item.qty
            : item.amount;
    if (taxableAmount <= 0) return const <TaxBreakdown>[];

    final taxAmount = taxableAmount * taxPercent / 100;
    final normalizedType = item.taxType.trim().toUpperCase();
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

    final billingMode = order.billingTaxMode.trim().toUpperCase();
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
        label: 'SGST ${_formatTaxPercent(halfRate)}%',
        taxType: 'GST',
        rate: halfRate,
        taxableAmount: taxableAmount,
        taxAmount: halfAmount,
      ),
    ];
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
    if (item.taxableAmount.abs() > 0.0009) return item.taxableAmount;
    if (item.referenceRate > 0 && item.qty > 0) {
      return item.referenceRate * item.qty;
    }
    return item.amount;
  }

  static double _displayRate(SaleItem item) {
    if (item.referenceRate > 0) return item.referenceRate;
    return item.rate;
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

  static String _cleanAddressForPrint(String? rawAddress) {
    if (rawAddress == null || rawAddress.trim().isEmpty) return '';
    String address = rawAddress.trim();
    
    while (true) {
      final stateIndex = address.toLowerCase().lastIndexOf(', state:');
      if (stateIndex != -1) {
        address = address.substring(0, stateIndex).trim();
      } else {
        break;
      }
    }
    
    if (address.toLowerCase().startsWith('state:')) {
      return '';
    }
    
    return address;
  }

  static String _deriveBuyerState(SaleOrder order, PropertyInfo? property) {
    final gstStateCode = _stateCodeFromGstin(order.customerGstin);
    if (gstStateCode != null) {
      return _stateNameByCode[gstStateCode] ?? (order.billingTaxMode == 'IGST' ? '' : property?.state ?? '');
    }

    final address = order.customerAddress ?? '';
    for (final state in _stateCodes.keys) {
      if (address.toLowerCase().contains(state.toLowerCase())) {
        return state;
      }
    }

    return order.billingTaxMode == 'IGST' ? '' : property?.state ?? '';
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

  static String _amountInWords(double amount) {
    final rupees = amount.floor();
    final paise = ((amount - rupees) * 100).round();
    final rupeeWords = _numberToWords(rupees);
    final paiseWords = paise > 0 ? ' and ${_numberToWords(paise)} Paise' : '';
    return 'Indian Rupees $rupeeWords$paiseWords Only';
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

    await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
  }

  static Future<Uint8List> buildCreditNotePdf({
    required Map<String, dynamic> creditNote,
    required PropertyInfo? property,
  }) async {
    final document = pw.Document();
    final logo = await BrandingStorage.loadPdfLogo(property?.logoPath);

    final originalSale = creditNote['sale'] is Map ? creditNote['sale'] as Map<String, dynamic> : null;
    final billFormat = originalSale?['bill_format']?.toString() ?? 'A4';

    if (_isThermalFormat(billFormat)) {
      document.addPage(
        pw.MultiPage(
          pageFormat: _thermalSheetFor(billFormat),
          build: (_) => [_buildThermalCreditNoteReceipt(creditNote, property, logo)],
        ),
      );
    } else {
      final cnNo = creditNote['credit_note_no']?.toString() ?? '';
      final cnDateRaw = creditNote['credit_note_date']?.toString() ?? '';
      final cnDate = DateTime.tryParse(cnDateRaw) ?? DateTime.now();

      final originalSaleNo = creditNote['sale'] is Map
          ? (creditNote['sale']['sale_no']?.toString() ?? '')
          : '';
      final originalSaleDateRaw = creditNote['sale'] is Map
          ? (creditNote['sale']['sale_date']?.toString() ?? '')
          : '';
      final originalSaleDate = DateTime.tryParse(originalSaleDateRaw) ?? DateTime.now();

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
                        if ((property?.mobile ?? '').isNotEmpty) pw.Text('Phone: ${property!.mobile}', style: const pw.TextStyle(fontSize: 8.5)),
                        if ((property?.gstNo ?? '').isNotEmpty) pw.Text('GSTIN: ${property!.gstNo}', style: const pw.TextStyle(fontSize: 8.5)),
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
                        pw.Text('GSTIN: $customerGstin', style: const pw.TextStyle(fontSize: 8.5)),
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
      Map<String, dynamic> creditNote, PropertyInfo? property, pw.MemoryImage? logo) {
    final regular = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();
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
    final cnDate = DateTime.tryParse(cnDateRaw) ?? DateTime.now();

    final originalSaleNo = creditNote['sale'] is Map
        ? (creditNote['sale']['sale_no']?.toString() ?? '')
        : '';
    final originalSaleDateRaw = creditNote['sale'] is Map
        ? (creditNote['sale']['sale_date']?.toString() ?? '')
        : '';
    final originalSaleDate = DateTime.tryParse(originalSaleDateRaw) ?? DateTime.now();

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
                if ((property?.mobile ?? '').isNotEmpty)
                  pw.Text(
                    'Phone: ${property!.mobile}',
                    textAlign: pw.TextAlign.center,
                  ),
                if ((property?.gstNo ?? '').isNotEmpty)
                  pw.Text(
                    'GSTIN: ${property!.gstNo}',
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
                  'GST COMPLIANT',
                  style: bodyStyle.copyWith(fontSize: 7.5),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: _thermalDivider, thickness: 0.8),
          
          // CN and Sale Details
          _thermalRow('CN No:', cnNo, bold: true),
          _thermalRow('CN Date:', _date.format(cnDate)),
          _thermalRow('Orig Bill No:', originalSaleNo),
          _thermalRow('Orig Bill Date:', _date.format(originalSaleDate)),
          pw.Divider(color: _thermalDivider, thickness: 0.8),

          // Customer Details
          if (customerName.isNotEmpty) _thermalRow('Customer:', customerName),
          if (customerPhone != '--') _thermalRow('Phone:', customerPhone),
          if (customerGstin.isNotEmpty) _thermalRow('GSTIN:', customerGstin),
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
          if (sgstTotal > 0) _thermalRow('Total SGST:', sgstTotal.toStringAsFixed(2)),
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
    await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
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
    final document = pw.Document();
    final pageFormat = _thermalSheetFor('THERMAL_80');
    final formattedDate = refundedAt.isNotEmpty ? refundedAt : DateTime.now().toString().split(' ')[0];

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
                    if (property?.mobile != null && property!.mobile.isNotEmpty)
                      pw.Text('Phone: ${property.mobile}', style: const pw.TextStyle(fontSize: 7.5)),
                    if (property?.gstNo != null && property!.gstNo.isNotEmpty)
                      pw.Text('GSTIN: ${property.gstNo}', style: const pw.TextStyle(fontSize: 7.5)),
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

              _thermalReceiptRow('Original Amount Paid:', 'Rs. ${double.tryParse(order['net_amount']?.toString() ?? '0.0')?.toStringAsFixed(2) ?? '0.00'}'),
              _thermalReceiptRow('Refunded Amount:', 'Rs. ${refundAmt.toStringAsFixed(2)}', isBold: true),
              
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
  });
}

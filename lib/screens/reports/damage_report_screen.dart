import 'dart:io';

import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/inventory/damage_controller.dart';
import '../../controllers/reports/damage_report_controller.dart';
import '../../core/auth/token_storage.dart';
import '../../utils/branding_storage.dart';

//
class DamageReportSumScreen extends StatefulWidget {
  const DamageReportSumScreen({super.key});

  @override
  State<DamageReportSumScreen> createState() => _DamageReportSumScreenState();
}

class _DamageReportSumScreenState extends State<DamageReportSumScreen> {
  final ctrl = DamageReportsumController();
  final damageCtrl = DamageController();

  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  String? _role;

  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fromCtrl.text = DateFormat('dd-MMM-yyyy').format(fromDate);
    _toCtrl.text = DateFormat('dd-MMM-yyyy').format(toDate);
    _loadRole();
  }

  Future<void> _loadRole() async {
    _role = await TokenStorage.getRole();
    if (mounted) {
      setState(() {});
    }
  }

  void _generate() async {
    ctrl.fromDate = fromDate;
    ctrl.toDate = toDate;
    await ctrl.load();
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Damage Summary Report'),
        centerTitle: true,
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.file_download),
            label: const Text("Excel"),
            onPressed: exportToExcel,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text("PDF"),
            onPressed: exportToPdf,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _modernFilterCard(),
            const SizedBox(height: 20),
            Expanded(child: _reportBody()),
          ],
        ),
      ),
    );
  }

  // ================= MODERN FILTER =================
  Widget _modernFilterCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _modernDateField("From Date", _fromCtrl, _pickFrom),
          _modernDateField("To Date", _toCtrl, _pickTo),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: _generate,
              icon: const Icon(Icons.search),
              label: const Text("Generate"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernDateField(
      String label, TextEditingController controller, VoidCallback onTap) {
    return SizedBox(
      width: 220,
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ================= REPORT BODY =================
  Widget _reportBody() {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        if (ctrl.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (ctrl.data.isEmpty) {
          return const Center(
            child: Text(
              'No damage records found',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: ctrl.data.length,
          itemBuilder: (_, index) {
            final header = ctrl.data[index];

            final total = header.totalValue;

            return Container(
              margin: const EdgeInsets.only(bottom: 22),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.04),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER
                  Row(
                    children: [
                      Text(
                        "Damage #${header.damageNo}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        DateFormat('dd-MMM-yyyy').format(header.date),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 12),
                      _statusChip(header.approvalStatus),
                      const Spacer(),
                      Text(
                        "Rs ${total.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text('Document Status: ${header.status}'),
                      if (header.approvedAt != null)
                        Text(
                          'Approved: ${DateFormat('dd-MMM-yyyy HH:mm').format(header.approvedAt!)}',
                        ),
                      if (header.rejectedAt != null)
                        Text(
                          'Rejected: ${DateFormat('dd-MMM-yyyy HH:mm').format(header.rejectedAt!)}',
                        ),
                    ],
                  ),
                  if (header.rejectionReason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Reason: ${header.rejectionReason}'),
                    ),
                  ],
                  if (_role == 'ADMIN' && header.approvalStatus == 'PENDING') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () => _approveDamage(header.damageId),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Approve'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => _rejectDamage(header.damageId),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Reject'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Divider(color: Colors.grey.shade200),
                  const SizedBox(height: 14),

                  // TABLE
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty.all(Colors.grey.shade100),
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                      dataRowMinHeight: 44,
                      columns: const [
                        DataColumn(label: Text('Item')),
                        DataColumn(label: Text('Unit')),
                        DataColumn(label: Text('Qty')),
                        DataColumn(label: Text('Rate')),
                        DataColumn(label: Text('Amount')),
                        DataColumn(label: Text('Remarks')),
                      ],
                      rows: header.items.map((e) {
                        return DataRow(
                          cells: [
                            DataCell(Text('${e.itemName}${e.brand.isNotEmpty ? ' (${e.brand})' : ''}')),
                            DataCell(Text(e.unit)),
                            DataCell(Text(e.qty.toString())),
                            DataCell(Text(e.rate.toStringAsFixed(2))),
                            DataCell(Text(
                              e.amount.toStringAsFixed(2),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            )),
                            DataCell(Text(e.remarks ?? '')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Damage Total : Rs ${total.toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ================= DATE PICKERS =================
  void _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        fromDate = d;
        _fromCtrl.text = DateFormat('dd-MMM-yyyy').format(d);
      });
    }
  }

  void _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        toDate = d;
        _toCtrl.text = DateFormat('dd-MMM-yyyy').format(d);
      });
    }
  }

  Widget _statusChip(String status) {
    final normalized = status.toUpperCase();
    Color bgColor;
    Color fgColor;

    switch (normalized) {
      case 'APPROVED':
        bgColor = Colors.green.shade100;
        fgColor = Colors.green.shade800;
        break;
      case 'REJECTED':
        bgColor = Colors.red.shade100;
        fgColor = Colors.red.shade800;
        break;
      default:
        bgColor = Colors.orange.shade100;
        fgColor = Colors.orange.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized,
        style: TextStyle(fontWeight: FontWeight.w700, color: fgColor),
      ),
    );
  }

  Future<void> _approveDamage(int damageId) async {
    await damageCtrl.approveDamage(damageId);
    await ctrl.load();
  }

  Future<void> _rejectDamage(int damageId) async {
    final reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Damage'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Enter rejection reason',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reasonController.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    await damageCtrl.rejectDamage(damageId, result);
    await ctrl.load();
  }

  Future<void> exportToExcel() async {
    final excel = exc.Excel.createExcel();
    final sheet = excel['Damage Report'];

    int row = 0;
    double grandTotal = 0;

    // ===== Title =====
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = exc.TextCellValue('DAMAGE SUMMARY REPORT');

    row++;

    sheet
            .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value =
        exc.TextCellValue(
            'From: ${DateFormat('dd-MMM-yyyy').format(fromDate)}  '
            'To: ${DateFormat('dd-MMM-yyyy').format(toDate)}');

    row += 2;

    for (final header in ctrl.data) {
      final total = header.items.fold<double>(
        0,
        (sum, e) => sum + (e.amount ?? 0),
      );

      // ===== Header Row =====
      final headerCell = sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));

      headerCell.value = exc.TextCellValue('Damage: ${header.damageNo} | '
          '${DateFormat('dd-MMM-yyyy').format(header.date)}');

      headerCell.cellStyle = exc.CellStyle(
        bold: true,
        backgroundColorHex: exc.ExcelColor.fromHexString('#DCE6F1'),
      );

      row++;

      // ===== Table Header =====
      final columns = ['Item', 'Unit', 'Qty', 'Rate', 'Amount', 'Remarks'];

      for (int i = 0; i < columns.length; i++) {
        final cell = sheet.cell(
            exc.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));

        cell.value = exc.TextCellValue(columns[i]);
        cell.cellStyle = exc.CellStyle(
          bold: true,
          fontColorHex: exc.ExcelColor.fromHexString('#FFFFFF'),
          backgroundColorHex: exc.ExcelColor.fromHexString('#305496'),
        );
      }

      row++;

      // ===== Items =====
      for (int i = 0; i < header.items.length; i++) {
        final item = header.items[i];

        final bgColor = i.isEven
            ? exc.ExcelColor.fromHexString('#FFFFFF')
            : exc.ExcelColor.fromHexString('#F2F2F2');

        void setCell(int col, exc.CellValue value) {
          final cell = sheet.cell(
              exc.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          cell.value = value;
          cell.cellStyle = exc.CellStyle(backgroundColorHex: bgColor);
        }

        setCell(0, exc.TextCellValue('${item.itemName}${item.brand.isNotEmpty ? ' (${item.brand})' : ''}'));
        setCell(1, exc.TextCellValue(item.unit));
        setCell(2, exc.DoubleCellValue(item.qty));
        setCell(3, exc.DoubleCellValue(item.rate));
        setCell(4, exc.DoubleCellValue(item.amount ?? 0));
        setCell(5, exc.TextCellValue(item.remarks ?? ''));

        row++;
      }

      // ===== Damage Total =====
      sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = exc.TextCellValue('Damage Total');

      sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .value = exc.DoubleCellValue(total);

      grandTotal += total;

      row += 2;
    }

    // ===== Grand Total =====
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = exc.TextCellValue('Grand Total');

    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        .value = exc.DoubleCellValue(grandTotal);

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/DamageReport_${DateTime.now().millisecondsSinceEpoch}.xlsx');

    await file.writeAsBytes(excel.encode()!);
    await OpenFile.open(file.path);
  }

  Future<void> exportToPdf() async {
    final pdf = pw.Document();
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
    final branding = await BrandingStorage.getCurrentBrandingContext();
    final logo = await BrandingStorage.loadPdfLogo(branding?.logoPath);
    final nowStr = DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());

    double grandTotal = 0;
    for (final header in ctrl.data) {
      for (final item in header.items) {
        grandTotal += (item.amount ?? 0);
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logo != null)
                      pw.Container(
                        width: 45,
                        height: 45,
                        margin: const pw.EdgeInsets.only(right: 12),
                        child: pw.Image(logo, fit: pw.BoxFit.contain),
                      ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if ((branding?.businessName ?? '').isNotEmpty)
                          pw.Text(
                            branding!.businessName,
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#1E293B'),
                            ),
                          ),
                        pw.Text(
                          'DAMAGE SUMMARY REPORT',
                          style: pw.TextStyle(
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#2563EB'),
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'From: ${DateFormat('dd-MMM-yyyy').format(fromDate)}  To: ${DateFormat('dd-MMM-yyyy').format(toDate)}',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Generated: $nowStr',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Total Damage Entries: ${ctrl.data.length}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#475569'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColor.fromHex('#CBD5E1'), thickness: 1),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'RetailSale POS — Damage Report',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        build: (context) {
          final widgets = <pw.Widget>[];

          // KPI Summary Bar
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              margin: const pw.EdgeInsets.only(bottom: 12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfKpiBlock('Total Damage Entries', ctrl.data.length.toString(), PdfColor.fromHex('#1E40AF')),
                  _pdfKpiBlock('Grand Total Damage Value', currency.format(grandTotal), PdfColor.fromHex('#DC2626')),
                ],
              ),
            ),
          );

          for (final header in ctrl.data) {
            final total = header.items.fold<double>(
              0,
              (sum, e) => sum + (e.amount ?? 0),
            );

            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 10, bottom: 4),
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#E2E8F0'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Damage Ref: ${header.damageNo}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColor.fromHex('#1E293B')),
                    ),
                    pw.Text(
                      'Date: ${DateFormat('dd-MMM-yyyy').format(header.date)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColor.fromHex('#2563EB')),
                    ),
                  ],
                ),
              ),
            );

            final tableHeaders = ['Item', 'Unit', 'Qty', 'Rate', 'Amount', 'Remarks'];
            final tableData = header.items.map((item) {
              return [
                '${item.itemName}${item.brand.isNotEmpty ? ' (${item.brand})' : ''}',
                item.unit,
                item.qty.toString(),
                item.rate.toStringAsFixed(2),
                currency.format(item.amount ?? 0),
                item.remarks ?? '',
              ];
            }).toList();

            widgets.add(
              pw.TableHelper.fromTextArray(
                headers: tableHeaders,
                data: tableData,
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E293B')),
                headerStyle: pw.TextStyle(color: PdfColors.white, fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 7.0),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.centerLeft,
                },
                rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
                oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F8FAFC')),
                border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.5),
                  1: pw.FlexColumnWidth(0.8),
                  2: pw.FlexColumnWidth(0.8),
                  3: pw.FlexColumnWidth(1.0),
                  4: pw.FlexColumnWidth(1.2),
                  5: pw.FlexColumnWidth(2.0),
                },
              ),
            );

            widgets.add(
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4, bottom: 8),
                  child: pw.Text(
                    'Entry Total: ${currency.format(total)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColor.fromHex('#DC2626')),
                  ),
                ),
              ),
            );
          }

          widgets.add(pw.Divider(color: PdfColor.fromHex('#CBD5E1')));
          widgets.add(
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#1E293B'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  "Grand Total Damage: ${currency.format(grandTotal)}",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          );

          return widgets;
        },
      ),
    );

    await Printing.layoutPdf(name: 'Damage_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}', onLayout: (format) async => pdf.save());
  }

  pw.Widget _pdfKpiBlock(String label, String value, PdfColor valueColor) {
    return pw.Column(
      children: [
        pw.Text(
          label.toUpperCase(),
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }
}

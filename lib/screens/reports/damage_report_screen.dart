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
                            DataCell(Text(e.itemName)),
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

        setCell(0, exc.TextCellValue(item.itemName));
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
    double grandTotal = 0;
    final branding = await BrandingStorage.getCurrentBrandingContext();
    final logo = await BrandingStorage.loadPdfLogo(branding?.logoPath);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(children: [
              if (logo != null)
                pw.Container(
                  width: 42,
                  height: 42,
                  margin: const pw.EdgeInsets.only(right: 10),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if ((branding?.businessName ?? '').isNotEmpty)
                    pw.Text(
                      branding!.businessName,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  pw.Text(
                    'Damage Summary Report',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ]),
            pw.Text('From: ${DateFormat('dd-MMM-yyyy').format(fromDate)}  '
                'To: ${DateFormat('dd-MMM-yyyy').format(toDate)}'),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        build: (context) {
          final widgets = <pw.Widget>[];

          for (final header in ctrl.data) {
            final total = header.items.fold<double>(
              0,
              (sum, e) => sum + (e.amount ?? 0),
            );

            grandTotal += total;

            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
                padding: const pw.EdgeInsets.all(8),
                color: PdfColors.blueGrey100,
                child: pw.Text(
                  'Damage: ${header.damageNo} | '
                  '${DateFormat('dd-MMM-yyyy').format(header.date)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            );

            widgets.add(
              pw.Table.fromTextArray(
                headers: const [
                  'Item',
                  'Unit',
                  'Qty',
                  'Rate',
                  'Amount',
                  'Remarks'
                ],
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.blueGrey700),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                data: header.items.map((item) {
                  return [
                    item.itemName,
                    item.unit,
                    item.qty.toString(),
                    item.rate.toStringAsFixed(2),
                    (item.amount ?? 0).toStringAsFixed(2),
                    item.remarks ?? '',
                  ];
                }).toList(),
              ),
            );

            widgets.add(
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 6),
                  child: pw.Text(
                    'Damage Total : ${total.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ),
            );

            widgets.add(pw.SizedBox(height: 16));
          }

          widgets.add(pw.Divider());

          widgets.add(
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Grand Total : ${grandTotal.toStringAsFixed(2)}',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
              ),
            ),
          );

          return widgets;
        },
      ),
    );

    await Printing.layoutPdf(name: 'Damage_Report', onLayout: (format) async => pdf.save());
  }
}

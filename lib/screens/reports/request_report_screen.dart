import 'dart:io';

import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/inventory/request_controller.dart';
import '../../controllers/reports/request_report_controller.dart';
import '../../utils/branding_storage.dart';

class RequestReportScreen extends StatefulWidget {
  const RequestReportScreen({super.key});

  @override
  State<RequestReportScreen> createState() => _RequestReportScreenState();
}

class _RequestReportScreenState extends State<RequestReportScreen> {
  final ctrl = RequestReportController();
  final requestCtrl = RequestController();

  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    ctrl.init();

    _fromCtrl.text = DateFormat('dd-MMM-yyyy').format(ctrl.fromDate);
    _toCtrl.text = DateFormat('dd-MMM-yyyy').format(ctrl.toDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Request Report'),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _filterCard(),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: ctrl,
              builder: (_, __) {
                if (ctrl.loading) {
                  return const SizedBox();
                }

                return _summaryCard();
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AnimatedBuilder(
                animation: ctrl,
                builder: (_, __) {
                  if (ctrl.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (ctrl.list.isEmpty) {
                    return const Center(child: Text('No request found'));
                  }

                  return _requestList();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= FILTER =================
  Widget _filterCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        // boxShadow: [
        //   BoxShadow(
        //     color: Colors.black.withOpacity(.05),
        //     blurRadius: 16,
        //     offset: const Offset(0, 6),
        //   )
        // ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Filter Options",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 20,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 📅 From Date
              _modernDateField(
                label: 'From Date',
                controller: _fromCtrl,
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: ctrl.fromDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (p != null) {
                    ctrl.fromDate = p;
                    _fromCtrl.text = DateFormat('dd-MMM-yyyy').format(p);
                  }
                },
              ),

              // 📅 To Date
              _modernDateField(
                label: 'To Date',
                controller: _toCtrl,
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: ctrl.toDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (p != null) {
                    ctrl.toDate = p;
                    _toCtrl.text = DateFormat('dd-MMM-yyyy').format(p);
                  }
                },
              ),

              // 📊 Status
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: ctrl.status,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Status')),
                    DropdownMenuItem(value: 'OPEN', child: Text('OPEN')),
                    DropdownMenuItem(value: 'PARTIAL', child: Text('PARTIAL')),
                    DropdownMenuItem(value: 'CLOSED', child: Text('CLOSED')),
                  ],
                  onChanged: (v) => ctrl.status = v,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: ctrl.approvalStatus,
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('All Approval Status'),
                    ),
                    DropdownMenuItem(value: 'PENDING', child: Text('PENDING')),
                    DropdownMenuItem(
                        value: 'APPROVED', child: Text('APPROVED')),
                    DropdownMenuItem(
                        value: 'REJECTED', child: Text('REJECTED')),
                  ],
                  onChanged: (v) => ctrl.approvalStatus = v,
                  decoration: InputDecoration(
                    labelText: 'Approval',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // 🔍 Search
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Search Request No',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // ▶ Apply Button
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    ctrl.search = _searchCtrl.text;
                    ctrl.load();
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Apply'),
                ),
              ),

              // 🔄 Reset Button
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    ctrl.reset();
                    _searchCtrl.clear();
                    _fromCtrl.text =
                        DateFormat('dd-MMM-yyyy').format(ctrl.fromDate);
                    _toCtrl.text = DateFormat('dd-MMM-yyyy').format(ctrl.toDate);
                    ctrl.load();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modernDateField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today),
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

  // ================= SUMMARY =================
  Widget _summaryCard() {
    return _card(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip('Total Qty', ctrl.totalQty, Colors.blue),
          _chip('Total Amount', ctrl.grandTotal, Colors.green),
        ],
      ),
    );
  }

  // ================= LIST =================
  Widget _requestList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: ctrl.list.length,
      itemBuilder: (context, index) {
        final header = ctrl.list[index];

        final statusColor = _statusColor(header.status);
        final approvalColor = _approvalColor(header.approvalStatus);

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================= HEADER =================
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT SECTION
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Request #${header.requestNo}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('dd-MMM-yyyy')
                                .format(header.requestDate),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            header.department,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // RIGHT SECTION
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _statusPill(
                          'Approval: ${header.approvalStatus.toUpperCase()}',
                          approvalColor,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(.12),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            'Fulfillment: ${header.status.toUpperCase()}',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "₹ ${header.totalAmount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                if (header.rejectionReason.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Reject reason: ${header.rejectionReason}',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (header.approvalStatus == 'PENDING') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () => _approveRequest(header.id),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Approve'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => _rejectRequest(header.id),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Reject'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 14),

                // ================= ITEMS TABLE =================
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(Colors.grey.shade100),
                    headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 48,
                    columns: const [
                      DataColumn(label: Text('Item')),
                      DataColumn(label: Text('Qty')),
                      DataColumn(label: Text('Rate')),
                      DataColumn(label: Text('Amount')),
                    ],
                    rows: List.generate(header.items.length, (i) {
                      final item = header.items[i];

                      return DataRow(
                        color: WidgetStateProperty.all(
                          i.isEven ? Colors.grey.shade50 : Colors.white,
                        ),
                        cells: [
                          DataCell(Text(
                            item.itemName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          )),
                          DataCell(Text(item.qty.toString())),
                          DataCell(Text(item.rate.toStringAsFixed(2))),
                          DataCell(Text(
                            item.amount.toStringAsFixed(2),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          )),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================= COMMON =================
  Widget _card({String? title, required Widget child}) => Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const Divider(),
              ],
              child,
            ],
          ),
        ),
      );

  Widget _dateField(
      String label, TextEditingController controller, VoidCallback onTap) {
    return SizedBox(
      width: 180,
      child: TextField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _chip(String label, double val, Color color) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Chip(
          backgroundColor: color.withOpacity(.15),
          label: Text(
            '$label : ${val.toStringAsFixed(2)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
      );

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return Colors.orange;
      case 'PARTIAL':
        return Colors.blue;
      case 'CLOSED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _approvalColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _approveRequest(int requestId) async {
    try {
      await requestCtrl.approve(requestId);
      await ctrl.load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request approved successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _rejectRequest(int requestId) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Enter rejection reason',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, reasonCtrl.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) {
      return;
    }

    try {
      await requestCtrl.reject(requestId, reason);
      await ctrl.load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request rejected successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> exportToExcel() async {
    final excel = exc.Excel.createExcel();
    final sheet = excel['Request Report'];

    int row = 0;
    double grandTotal = 0;

    // ===== Title =====
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = exc.TextCellValue('REQUEST REPORT');

    row++;

    sheet
            .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value =
        exc.TextCellValue(
            'From: ${DateFormat('dd-MMM-yyyy').format(ctrl.fromDate)}  '
            'To: ${DateFormat('dd-MMM-yyyy').format(ctrl.toDate)}');

    row += 2;

    for (final header in ctrl.list) {
      // ===== Header Row =====
      final headerCell = sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));

      headerCell.value = exc.TextCellValue('Request: ${header.requestNo} | '
          '${DateFormat('dd-MMM-yyyy').format(header.requestDate)} | '
          '${header.department} | ${header.status}');

      headerCell.cellStyle = exc.CellStyle(
        bold: true,
        backgroundColorHex: exc.ExcelColor.fromHexString('#DCE6F1'),
      );

      row++;

      // ===== Table Header =====
      final columns = ['Item', 'Qty', 'Rate', 'Amount'];

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
        setCell(1, exc.DoubleCellValue(item.qty));
        setCell(2, exc.DoubleCellValue(item.rate));
        setCell(3, exc.DoubleCellValue(item.amount));

        row++;
      }

      // ===== Request Total =====
      sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = exc.TextCellValue('Request Total');

      sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = exc.DoubleCellValue(header.totalAmount);

      grandTotal += header.totalAmount;

      row += 2;
    }

    // ===== Grand Total =====
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        .value = exc.TextCellValue('Grand Total');

    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = exc.DoubleCellValue(grandTotal);

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/RequestReport_${DateTime.now().millisecondsSinceEpoch}.xlsx');

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
                    'Request Report',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ]),
            pw.Text('From: ${DateFormat('dd-MMM-yyyy').format(ctrl.fromDate)}  '
                'To: ${DateFormat('dd-MMM-yyyy').format(ctrl.toDate)}'),
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

          for (final header in ctrl.list) {
            grandTotal += header.totalAmount;

            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
                padding: const pw.EdgeInsets.all(8),
                color: PdfColors.blueGrey100,
                child: pw.Text(
                  'Request: ${header.requestNo} | '
                  '${DateFormat('dd-MMM-yyyy').format(header.requestDate)} | '
                  '${header.department} | ${header.status}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            );

            widgets.add(
              pw.Table.fromTextArray(
                headers: const ['Item', 'Qty', 'Rate', 'Amount'],
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
                    item.qty.toString(),
                    item.rate.toStringAsFixed(2),
                    item.amount.toStringAsFixed(2),
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
                    'Request Total : ${header.totalAmount.toStringAsFixed(2)}',
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

    await Printing.layoutPdf(name: 'Request_Report', onLayout: (format) async => pdf.save());
  }
}

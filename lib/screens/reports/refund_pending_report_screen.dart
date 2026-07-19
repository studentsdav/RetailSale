// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'dart:io';

import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/sales/sales_controller.dart';

class RefundPendingReportScreen extends StatefulWidget {
  const RefundPendingReportScreen({super.key});

  @override
  State<RefundPendingReportScreen> createState() =>
      _RefundPendingReportScreenState();
}

class _RefundPendingReportScreenState extends State<RefundPendingReportScreen> {
  final ctrl = SalesController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> refunds = [];
  bool loading = false;

  DateTime? fromDate;
  DateTime? toDate;
  String selectedStatus = 'ALL';
  String search = '';

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    fromDate = DateTime(today.year, today.month, 1);
    toDate = today;
    _loadReportData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReportData() async {
    setState(() {
      loading = true;
    });

    try {
      final data = await ctrl.listRefunds(
        status: selectedStatus == 'ALL' ? null : selectedStatus,
        fromDate: fromDate,
        toDate: toDate,
        search: search.trim().isEmpty ? null : search.trim(),
      );
      setState(() {
        refunds = data;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (fromDate ?? DateTime.now())
        : (toDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        fromDate = picked;
      } else {
        toDate = picked;
      }
    });
  }

  String _fmt(dynamic value) {
    final number = double.tryParse('${value ?? 0}') ?? 0;
    return number.toStringAsFixed(2);
  }

  // Calculated metrics
  double get totalRefundAmount {
    return refunds.fold(0.0, (sum, item) {
      return sum + (double.tryParse('${item['amount_pending'] ?? 0}') ?? 0.0);
    });
  }

  double get totalPaidAmount {
    return refunds.fold(0.0, (sum, item) {
      return sum + (double.tryParse('${item['amount_paid'] ?? 0}') ?? 0.0);
    });
  }

  double get totalPendingBalance {
    return refunds.fold(0.0, (sum, item) {
      final pending = double.tryParse('${item['amount_pending'] ?? 0}') ?? 0.0;
      final paid = double.tryParse('${item['amount_paid'] ?? 0}') ?? 0.0;
      return sum + (pending - paid);
    });
  }

  Future<void> exportToExcel() async {
    final excel = exc.Excel.createExcel();
    final sheet = excel['Customer Refunds'];

    final headers = [
      'Refund No',
      'Date',
      'Original Bill',
      'Customer',
      'Refund Value',
      'Paid',
      'Pending Balance',
      'Status'
    ];

    for (var column = 0; column < headers.length; column++) {
      final cell = sheet.cell(exc.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0));
      cell.value = exc.TextCellValue(headers[column]);
      cell.cellStyle = exc.CellStyle(bold: true);
    }

    for (var index = 0; index < refunds.length; index++) {
      final row = refunds[index];
      final rawDate = DateTime.tryParse('${row['refund_date'] ?? ''}')?.toLocal();
      final displayDate = rawDate == null
          ? ''
          : DateFormat('dd-MMM-yyyy').format(displayDateUtcOrLocal(row['refund_date']));

      final pending = double.tryParse('${row['amount_pending'] ?? 0}') ?? 0.0;
      final paid = double.tryParse('${row['amount_paid'] ?? 0}') ?? 0.0;
      final balance = pending - paid;

      final customerName = row['sale']?['customer_name'] ?? 'Walk-in Customer';
      final customerPhone = row['sale']?['customer_phone'] ?? '';
      final customerStr = customerPhone.isNotEmpty ? '$customerName ($customerPhone)' : customerName;

      final values = [
        '${row['refund_no'] ?? ''}',
        displayDate,
        '${row['sale']?['sale_no'] ?? ''}',
        customerStr,
        _fmt(pending),
        _fmt(paid),
        _fmt(balance),
        '${row['status'] ?? ''}',
      ];

      for (var column = 0; column < values.length; column++) {
        final cell = sheet.cell(exc.CellIndex.indexByColumnRow(
          columnIndex: column,
          rowIndex: index + 1,
        ));
        cell.value = exc.TextCellValue(values[column]);
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/PendingCustomerRefundsReport.xlsx');
    if (await file.exists()) {
      await file.delete();
    }
    await file.writeAsBytes(excel.encode()!);
    await OpenFile.open(file.path);
  }

  DateTime displayDateUtcOrLocal(dynamic dateVal) {
    if (dateVal == null) return DateTime.now();
    if (dateVal is DateTime) return dateVal.toLocal();
    final parsed = DateTime.tryParse(dateVal.toString());
    return parsed?.toLocal() ?? DateTime.now();
  }

  Future<void> exportToPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (_) => [
          pw.Text(
            'Pending Customer Refunds Report',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'From: ${fromDate == null ? '--' : DateFormat('dd-MMM-yyyy').format(fromDate!)}'
            '  To: ${toDate == null ? '--' : DateFormat('dd-MMM-yyyy').format(toDate!)}',
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: const [
              'Refund No',
              'Date',
              'Bill No',
              'Customer',
              'Refund Value',
              'Paid',
              'Balance',
              'Status',
            ],
            data: refunds.map((row) {
              final rawDate = DateTime.tryParse('${row['refund_date'] ?? ''}')?.toLocal();
              final displayDate = rawDate == null
                  ? '--'
                  : DateFormat('dd-MMM-yyyy').format(displayDateUtcOrLocal(row['refund_date']));

              final pending = double.tryParse('${row['amount_pending'] ?? 0}') ?? 0.0;
              final paid = double.tryParse('${row['amount_paid'] ?? 0}') ?? 0.0;
              final balance = pending - paid;

              final customerName = row['sale']?['customer_name'] ?? 'Walk-in Customer';
              return [
                '${row['refund_no'] ?? ''}',
                displayDate,
                '${row['sale']?['sale_no'] ?? ''}',
                customerName,
                _fmt(pending),
                _fmt(paid),
                _fmt(balance),
                '${row['status'] ?? ''}',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(name: 'Refund_Pending_Report', onLayout: (_) async => pdf.save());
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return Colors.green;
      case 'PARTIALLY_PAID':
        return Colors.orange;
      case 'PENDING':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _openRefundDialog(Map<String, dynamic> refund) async {
    final pendingVal = double.tryParse('${refund['amount_pending'] ?? 0}') ?? 0.0;
    final paidVal = double.tryParse('${refund['amount_paid'] ?? 0}') ?? 0.0;
    final remainingBalance = pendingVal - paidVal;

    final amountCtrl = TextEditingController(text: remainingBalance.toStringAsFixed(2));
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String paymentMode = 'CASH';
    String? errorText;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final enteredAmount = double.tryParse(amountCtrl.text) ?? 0.0;

            void validate() {
              final amt = double.tryParse(amountCtrl.text) ?? 0.0;
              if (amt <= 0) {
                errorText = 'Refund amount must be positive';
              } else if (amt > remainingBalance + 0.009) {
                errorText = 'Amount exceeds remaining balance (Rs. ${remainingBalance.toStringAsFixed(2)})';
              } else {
                errorText = null;
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              actionsPadding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.assignment_return_outlined, color: Colors.orange.shade800, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Issue Consumer Refund',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Refund cash or credit against bill return',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.blueGrey.shade500,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Refund record overview metrics
                      Container(
                        margin: const EdgeInsets.only(bottom: 18, top: 4),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CUSTOMER',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.blueGrey.shade500,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      refund['sale']?['customer_name'] ?? 'Walk-in Customer',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey.shade800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              VerticalDivider(
                                color: Colors.blueGrey.shade300,
                                thickness: 1,
                                width: 20,
                                indent: 4,
                                endIndent: 4,
                              ),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'REFUND NO',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.blueGrey.shade500,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${refund['refund_no']}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              VerticalDivider(
                                color: Colors.blueGrey.shade300,
                                thickness: 1,
                                width: 20,
                                indent: 4,
                                endIndent: 4,
                              ),
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PENDING BALANCE',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.blueGrey.shade500,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Rs. ${remainingBalance.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFB91C1C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Inputs
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        decoration: InputDecoration(
                          labelText: 'Refund Amount To Pay',
                          hintText: 'Enter amount to refund',
                          prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                          suffixText: 'INR',
                          errorText: errorText,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blueGrey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blueGrey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (v) {
                          setDialogState(() {
                            validate();
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: paymentMode,
                        decoration: InputDecoration(
                          labelText: 'Payment Mode',
                          prefixIcon: const Icon(Icons.wallet_outlined, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blueGrey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blueGrey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        items: ['CASH', 'CARD', 'UPI', 'BANK', 'CREDIT']
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e, style: const TextStyle(fontWeight: FontWeight.w500)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setDialogState(() {
                            paymentMode = v!;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: refCtrl,
                        decoration: InputDecoration(
                          labelText: 'Reference No',
                          hintText: 'Transaction ID or receipt details',
                          prefixIcon: const Icon(Icons.tag_outlined, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blueGrey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blueGrey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Notes',
                          hintText: 'Add remarks for this refund...',
                          prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blueGrey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blueGrey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueGrey.shade700,
                    side: BorderSide(color: Colors.blueGrey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.blueGrey.shade200,
                    disabledForegroundColor: Colors.blueGrey.shade400,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    elevation: 1,
                  ),
                  onPressed: errorText != null || enteredAmount <= 0
                      ? null
                      : () async {
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await ctrl.payRefund(
                              refundId: refund['id'],
                              amountPaid: enteredAmount,
                              paymentMode: paymentMode,
                              referenceNo: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
                              notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                            );
                            navigator.pop();
                            await _loadReportData();
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Refund paid successfully and Cash Ledger updated!')),
                            );
                          } catch (e) {
                            setDialogState(() {
                              errorText = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  child: const Text('Confirm Refund', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Customer Pending Refunds'),
        centerTitle: true,
        actions: [
          Tooltip(
            message: 'Export Excel',
            child: ElevatedButton.icon(
              onPressed: refunds.isEmpty ? null : exportToExcel,
              icon: const Icon(Icons.file_download),
              label: const Text('Excel'),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Export PDF',
            child: ElevatedButton.icon(
              onPressed: refunds.isEmpty ? null : exportToPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF'),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _filterCard(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _summaryChip('Refund Records', refunds.length.toString()),
                        const SizedBox(width: 8),
                        _summaryChip('Total Return Val', 'Rs. ${_fmt(totalRefundAmount)}'),
                        const SizedBox(width: 8),
                        _summaryChip('Total Paid', 'Rs. ${_fmt(totalPaidAmount)}'),
                        const SizedBox(width: 8),
                        _summaryChip('Total Pending', 'Rs. ${_fmt(totalPendingBalance)}', isWarning: totalPendingBalance > 0),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: refunds.isEmpty
                        ? const Center(child: Text('No pending customer refunds found.'))
                        : Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    Colors.grey.shade200,
                                  ),
                                  columns: const [
                                    DataColumn(label: Text('Refund No')),
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Original Bill')),
                                    DataColumn(label: Text('Customer')),
                                    DataColumn(label: Text('Refund Value')),
                                    DataColumn(label: Text('Paid Amount')),
                                    DataColumn(label: Text('Pending Balance')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('Action')),
                                  ],
                                  rows: refunds.map((row) {
                                    final rawDate = DateTime.tryParse('${row['refund_date'] ?? ''}')?.toLocal();
                                    final displayDate = rawDate == null
                                        ? '--'
                                        : DateFormat('dd-MMM-yyyy').format(displayDateUtcOrLocal(row['refund_date']));

                                    final pending = double.tryParse('${row['amount_pending'] ?? 0}') ?? 0.0;
                                    final paid = double.tryParse('${row['amount_paid'] ?? 0}') ?? 0.0;
                                    final balance = pending - paid;

                                    final customerName = row['sale']?['customer_name'] ?? 'Walk-in Customer';
                                    final customerPhone = row['sale']?['customer_phone'] ?? '';
                                    final customerStr = customerPhone.isNotEmpty ? '$customerName ($customerPhone)' : customerName;
                                    final statusStr = (row['status'] ?? 'PENDING').toString().toUpperCase();

                                    return DataRow(
                                      cells: [
                                        DataCell(Text('${row['refund_no'] ?? '--'}')),
                                        DataCell(Text(displayDate)),
                                        DataCell(Text('${row['sale']?['sale_no'] ?? '--'}')),
                                        DataCell(Text(customerStr)),
                                        DataCell(Text('Rs. ${_fmt(pending)}')),
                                        DataCell(Text('Rs. ${_fmt(paid)}')),
                                        DataCell(Text(
                                          'Rs. ${_fmt(balance)}',
                                          style: TextStyle(
                                            fontWeight: balance > 0 ? FontWeight.bold : FontWeight.normal,
                                            color: balance > 0 ? Colors.red.shade700 : Colors.black87,
                                          ),
                                        )),
                                        DataCell(Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _statusColor(statusStr).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            statusStr,
                                            style: TextStyle(
                                              color: _statusColor(statusStr),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        )),
                                        DataCell(
                                          statusStr != 'PAID'
                                              ? FilledButton(
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor: Colors.orange.shade700,
                                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                                  ),
                                                  onPressed: () => _openRefundDialog(row),
                                                  child: const Text('Refund'),
                                                )
                                              : const Text('Fully Paid', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
                                        ),
                                      ],
                                    );
                                  }).toList(),
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

  Widget _filterCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 190,
            child: OutlinedButton.icon(
              onPressed: () => _pickDate(isFrom: true),
              icon: const Icon(Icons.date_range),
              label: Text(
                fromDate == null
                    ? 'From'
                    : DateFormat('dd-MMM-yyyy').format(fromDate!),
              ),
            ),
          ),
          SizedBox(
            width: 190,
            child: OutlinedButton.icon(
              onPressed: () => _pickDate(isFrom: false),
              icon: const Icon(Icons.event),
              label: Text(
                toDate == null ? 'To' : DateFormat('dd-MMM-yyyy').format(toDate!),
              ),
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Refund Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                DropdownMenuItem(value: 'PENDING', child: Text('PENDING')),
                DropdownMenuItem(value: 'PARTIALLY_PAID', child: Text('PARTIALLY PAID')),
                DropdownMenuItem(value: 'PAID', child: Text('PAID')),
              ],
              onChanged: (value) {
                setState(() {
                  selectedStatus = value ?? 'ALL';
                });
              },
            ),
          ),
          SizedBox(
            width: 240,
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: 'Search Refund / Bill / Customer',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                search = value;
              },
            ),
          ),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _loadReportData,
              icon: const Icon(Icons.refresh),
              label: const Text('Generate'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value, {bool isWarning = false}) {
    return Chip(
      label: Text(
        '$label: $value',
        style: TextStyle(
          color: isWarning ? Colors.red.shade800 : Colors.black87,
          fontWeight: isWarning ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      backgroundColor: isWarning ? Colors.red.shade50 : Colors.white,
      side: isWarning ? BorderSide(color: Colors.red.shade200) : null,
    );
  }
}

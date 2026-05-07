import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/inventory/issue_controller.dart';
import '../../controllers/modify/issue_modify_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../models/common/property_info_model.dart' show PropertyInfo;
import '../../models/inventory/stock_location_model.dart';

class IssueModifyScreen extends StatefulWidget {
  const IssueModifyScreen({super.key});

  @override
  State<IssueModifyScreen> createState() => _IssueModifyScreenState();
}

class _IssueModifyScreenState extends State<IssueModifyScreen> {
  final ctrl = IssueModifyController();
  final issueCtrl = IssueController();
  final propertyCtrl = PropertyInfoController();
  DateTime selectedDate = DateTime.now();
  PropertyInfo? propertyInfo;

  int? issueId;
  StockLocationdata? selectedDepartment;

  List items = [];

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    await issueCtrl.getdepartment();
    await propertyCtrl.load();
    propertyInfo = propertyCtrl.data;
    await _loadIssues();
  }

  Future<void> _loadIssues() async {
    final date = DateFormat('yyyy-MM-dd').format(selectedDate);

    await ctrl.loadIssueByDate(date);

    setState(() {
      issueId = null;
      selectedDepartment = null;
      items = [];
    });
  }

  Future<void> _loadDetails(int id) async {
    setState(() {
      issueId = id;
      selectedDepartment = null;
      items = [];
    });

    await ctrl.loadIssueDetails(id);

    final dept = ctrl.issueDetails['department'];
    StockLocationdata? nextDepartment;

    try {
      nextDepartment = issueCtrl.departments.firstWhere(
        (d) => d.locationName == dept,
      );
    } catch (e) {
      nextDepartment = null;
    }

    setState(() {
      items = List.from(ctrl.items);
      selectedDepartment = nextDepartment;
    });
  }

  double get total {
    double t = 0;

    for (var i in items) {
      t += double.parse(i['qty'].toString()) *
          double.parse(i['rate'].toString());
    }

    return t;
  }

  Future<void> _save() async {
    try {
      if (issueId == null) {
        _msg("Select Issue");
        return;
      }

      await ctrl.modifyIssue(
        id: issueId!,
        department: selectedDepartment!.locationName,
        items: items,
      );

      _msg("Issue Updated");
    } catch (e) {
      _msg(e.toString());
    }
  }

  void _msg(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _reprint() {
    if (issueId == null) {
      _msg("Select Issue");
      return;
    }

    _printIssue();
  }

  void _closeScreen() {
    Navigator.of(context).maybePop();
  }

  Future<void> _printIssue() async {
    final pdf = pw.Document();

    final property = propertyCtrl.data;

    final issue = ctrl.issueDetails;

    final issueDate = DateTime.parse(issue['issue_date']);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          /// ================= HEADER =================
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      property?.propertyName ?? '',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(property?.address ?? ""),
                    pw.Text("GSTIN: ${property?.gstNo ?? ""}"),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Text(
                  "STOCK ISSUE SLIP",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= ISSUE INFO =================
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Issue No: ${issue['issue_no']}"),
                  pw.Text(
                    "Date: ${DateFormat('dd-MMM-yyyy').format(issueDate)}",
                  ),
                  pw.Text(
                    "Department: ${selectedDepartment?.locationName ?? issue['department']}",
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Issue Type: ${issue['issue_type'] ?? ''}"),
                  pw.Text("Request ID: ${issue['open_request_no'] ?? ''}"),
                  pw.Text("Status: ${issue['status'] ?? ''}"),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= ITEM TABLE =================
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(1),
            },
            children: [
              /// HEADER
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                children: [
                  _cell("S.No", bold: true),
                  _cell("Item"),
                  _cell("Unit"),
                  _cell("Qty"),
                  _cell("Rate"),
                  _cell("Amount"),
                ],
              ),

              /// ITEMS
              ...List.generate(items.length, (i) {
                final r = items[i];

                final qty = double.parse(r['qty'].toString());
                final rate = double.parse(r['rate'].toString());

                final amount = qty * rate;

                return pw.TableRow(
                  children: [
                    _cell("${i + 1}"),
                    _cell(r['item_master']?['item_name'] ?? r['item_code']),
                    _cell(r['item_master']?['unit'] ?? ""),
                    _cell(qty.toString()),
                    _cell(rate.toStringAsFixed(2)),
                    _cell(amount.toStringAsFixed(2)),
                  ],
                );
              })
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= TOTAL =================
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "Total Amount : ${total.toStringAsFixed(2)}",
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),

          pw.SizedBox(height: 30),

          /// ================= FOOTER =================
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(children: [
                pw.Text("Issued By (Store)"),
                pw.SizedBox(height: 30),
              ]),
              pw.Column(children: [
                pw.Text("Received By (Department)"),
                pw.SizedBox(height: 30),
              ]),
              pw.Column(children: [
                pw.Text("Approved By"),
                pw.SizedBox(height: 30),
              ]),
            ],
          ),

          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "REPRINT",
              style: pw.TextStyle(
                color: PdfColors.red,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _total(String label, double value, {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(value.toStringAsFixed(2),
            style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        title: const Text("Modify Issue"),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _reprint,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            /// FILTER CARD
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    /// DATE
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        DateFormat('dd-MMM-yyyy').format(selectedDate),
                      ),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );

                        if (d != null) {
                          selectedDate = d;
                          await _loadIssues();
                        }
                      },
                    ),

                    const SizedBox(width: 20),

                    /// ISSUE NO
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('issue-$issueId'),
                        value: issueId,
                        decoration: InputDecoration(
                          labelText: "Issue No",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: ctrl.issues.map<DropdownMenuItem<int>>((e) {
                          return DropdownMenuItem(
                            value: e['id'],
                            child: Text(e['issue_no']),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            _loadDetails(v);
                          }
                        },
                      ),
                    ),

                    const SizedBox(width: 20),

                    /// DEPARTMENT
                    Expanded(
                      child: DropdownButtonFormField<StockLocationdata>(
                        key: ValueKey(
                          'issue-department-$issueId-${selectedDepartment?.id ?? selectedDepartment?.locationName}',
                        ),
                        value: selectedDepartment,
                        decoration: InputDecoration(
                          labelText: "Department",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: issueCtrl.departments.map((d) {
                          return DropdownMenuItem(
                            value: d,
                            child: Text(d.locationName),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() {
                            selectedDepartment = v;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// ITEMS GRID
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(Colors.grey.shade100),
                    columnSpacing: 40,
                    columns: const [
                      DataColumn(label: Text("S.No")),
                      DataColumn(label: Text("Code")),
                      DataColumn(label: Text("Item")),
                      DataColumn(label: Text("Unit")),
                      DataColumn(label: Text("Qty")),
                      DataColumn(label: Text("Rate")),
                      DataColumn(label: Text("Amount")),
                    ],
                    rows: List.generate(items.length, (i) {
                      final item = items[i];

                      final amount = double.parse(item['qty'].toString()) *
                          double.parse(item['rate'].toString());

                      return DataRow(
                        color: WidgetStateProperty.resolveWith(
                          (states) =>
                              i.isEven ? const Color(0xffFAFBFD) : Colors.white,
                        ),
                        cells: [
                          DataCell(Text("${i + 1}")),

                          DataCell(Text(item['item_master']['item_code'])),
                          DataCell(Text(item['item_master']['item_name'])),

                          DataCell(Text(item['item_master']['unit'] ?? "")),

                          /// QTY
                          DataCell(
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                key: ValueKey(
                                  'issue-$issueId-${item['id'] ?? item['item_code'] ?? item['item_master']?['item_code'] ?? item['item_master']?['item_name']}-qty',
                                ),
                                initialValue: item['qty'].toString(),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  isDense: true,
                                ),
                                onChanged: (v) {
                                  item['qty'] = double.tryParse(v) ?? 0;

                                  setState(() {});
                                },
                              ),
                            ),
                          ),

                          /// RATE
                          DataCell(
                            SizedBox(
                              width: 90,
                              child: TextFormField(
                                key: ValueKey(
                                  'issue-$issueId-${item['id'] ?? item['item_code'] ?? item['item_master']?['item_code'] ?? item['item_master']?['item_name']}-rate',
                                ),
                                initialValue: item['rate'].toString(),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  isDense: true,
                                ),
                                onChanged: (v) {
                                  item['rate'] = double.tryParse(v) ?? 0;

                                  setState(() {});
                                },
                              ),
                            ),
                          ),

                          DataCell(
                            Text(
                              amount.toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// TOTAL BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    "Total Amount",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "₹ ${total.toStringAsFixed(2)}",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            SafeArea(
              top: false,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.end,
                children: [
                  Tooltip(
                    message: 'Close modify screen',
                    child: SizedBox(
                      width: 170,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _closeScreen,
                        icon: const Icon(Icons.close_outlined),
                        label: const Text('Cancel'),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Print stock out slip',
                    child: SizedBox(
                      width: 180,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _reprint,
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Print'),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Save stock out changes',
                    child: SizedBox(
                      width: 180,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

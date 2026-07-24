import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/inventory/issue_controller.dart';
import '../../controllers/modify/issue_modify_controller.dart';
import '../../models/auth/permission_service.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../models/common/property_info_model.dart' show PropertyInfo;
import '../../models/inventory/stock_location_model.dart';
import '../../utils/branding_storage.dart';
import '../../core/printing/pos_invoice_printer.dart';

class IssueModifyScreen extends StatefulWidget {
  const IssueModifyScreen({super.key});

  @override
  State<IssueModifyScreen> createState() => _IssueModifyScreenState();
}

class _IssueModifyScreenState extends State<IssueModifyScreen> {
  final ctrl = IssueModifyController();
  bool get _canReprint =>
      PermissionService.can('REPRINT_ISSUE') || PermissionService.can('MODIFY_ISSUE');
  bool get _canModify => PermissionService.can('MODIFY_ISSUE');
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
    final logo = await BrandingStorage.loadPdfLogo(property?.logoPath);

    final issue = ctrl.issueDetails;

    final issueDate = DateTime.parse(issue['issue_date']);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          /// ================= HEADER =================
          PosInvoicePrinter.buildStandardA4Header(
            property: property,
            logo: logo,
            rightWidget: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
              ),
              child: pw.Text(
                "STOCK DISPATCH SLIP",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),

          pw.SizedBox(height: 20),

          /// ================= ISSUE INFO =================
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              color: PdfColors.grey50,
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("DEPARTMENT DETAILS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.blueGrey800)),
                      pw.SizedBox(height: 4),
                      pw.Text(selectedDepartment?.locationName ?? issue['department']?.toString() ?? 'N/A', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.blueGrey900)),
                      pw.Text("Dispatch Type: ${issue['issue_type'] ?? 'N/A'}", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                    ],
                  ),
                ),
                pw.Container(width: 0.5, height: 45, color: PdfColors.grey300, margin: const pw.EdgeInsets.symmetric(horizontal: 16)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("DISPATCH DETAILS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.blueGrey800)),
                    pw.SizedBox(height: 4),
                    _metaRow("Dispatch No", issue['issue_no'].toString()),
                    _metaRow("Date", DateFormat('dd-MMM-yyyy').format(issueDate)),
                    if ((issue['open_request_no'] ?? '').toString().trim().isNotEmpty)
                      _metaRow("Request ID", issue['open_request_no'].toString().trim()),
                    _metaRow("Status", issue['status']?.toString() ?? 'CLOSED'),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          /// ================= ITEM TABLE =================
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(40),
              3: const pw.FixedColumnWidth(50),
              4: const pw.FixedColumnWidth(60),
              5: const pw.FixedColumnWidth(60),
            },
            children: [
              /// HEADER
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                children: [
                  _cell("S.No", bold: true, alignment: pw.Alignment.center),
                  _cell("Item", bold: true),
                  _cell("Unit", bold: true, alignment: pw.Alignment.center),
                  _cell("Qty", bold: true, alignment: pw.Alignment.centerRight),
                  _cell("Rate", bold: true, alignment: pw.Alignment.centerRight),
                  _cell("Amount", bold: true, alignment: pw.Alignment.centerRight),
                ],
              ),

              /// ITEMS
              ...List.generate(items.length, (i) {
                final r = items[i];

                final qty = double.parse(r['qty'].toString());
                final rate = double.parse(r['rate'].toString());

                final amount = qty * rate;
                final brand = r['item_master']?['brand']?.toString() ?? '';
                final itemName = r['item_master']?['item_name'] ?? r['item_code'];

                return pw.TableRow(
                  children: [
                    _cell("${i + 1}", alignment: pw.Alignment.center),
                    _cell(brand.isNotEmpty ? '$itemName ($brand)' : '$itemName'),
                    _cell(r['item_master']?['unit'] ?? "", alignment: pw.Alignment.center),
                    _cell(qty.toString(), alignment: pw.Alignment.centerRight),
                    _cell(rate.toStringAsFixed(2), alignment: pw.Alignment.centerRight),
                    _cell(amount.toStringAsFixed(2), alignment: pw.Alignment.centerRight),
                  ],
                );
              })
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= TOTAL =================
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                color: PdfColors.grey50,
              ),
              child: pw.Text(
                "Total Amount : ${total.toStringAsFixed(2)}",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.blueGrey900),
              ),
            ),
          ),

          pw.SizedBox(height: 30),

          /// ================= FOOTER =================
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Dispatched By (Store)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.SizedBox(height: 30),
                ]
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text("Received By (Dept)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.SizedBox(height: 30),
                ]
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text("Approved By", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.SizedBox(height: 30),
                ]
              ),
            ],
          ),

          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "REPRINT",
              style: pw.TextStyle(
                color: PdfColors.red,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(name: 'Issue_${issue['issue_no']}', onLayout: (format) async => pdf.save());
  }

  pw.Widget _cell(String text, {bool bold = false, pw.Alignment alignment = pw.Alignment.centerLeft}) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: bold ? PdfColors.blueGrey900 : PdfColors.grey900,
        ),
      ),
    );
  }

  pw.Widget _metaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: 45,
            child: pw.Text(
              "$label:",
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        title: const Text("Modify Stock Dispatch"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            /// FILTER CARD
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    /// DATE
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Date",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 38,
                          width: 160,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 14),
                            label: Text(
                              DateFormat('dd-MMM-yyyy').format(selectedDate),
                              style: const TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
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
                        ),
                      ],
                    ),

                    /// ISSUE NO
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Issue No",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 38,
                          width: 220,
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('issue-$issueId'),
                            initialValue: issueId,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: ctrl.issues.map<DropdownMenuItem<int>>((e) {
                              return DropdownMenuItem(
                                value: e['id'],
                                child: Text(e['issue_no'], style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                _loadDetails(v);
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    /// DEPARTMENT
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Department",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 38,
                          width: 260,
                          child: DropdownButtonFormField<StockLocationdata>(
                            key: ValueKey(
                              'issue-department-$issueId-${selectedDepartment?.id ?? selectedDepartment?.locationName}',
                            ),
                            initialValue: selectedDepartment,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: issueCtrl.departments.map((d) {
                              return DropdownMenuItem(
                                value: d,
                                child: Text(d.locationName, style: const TextStyle(fontSize: 13)),
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
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// ITEMS GRID
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(scheme.surfaceContainerHighest),
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
                              DataCell(Text(
                                '${item['item_master']['item_name']}${item['item_master']['brand'] != null && item['item_master']['brand'].toString().isNotEmpty ? ' (${item['item_master']['brand']})' : ''}'
                              )),

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
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
              ),
            ),

            const SizedBox(height: 16),

            /// TOTAL BAR
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 300,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "Total Amount",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        "₹ ${total.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SafeArea(
              top: false,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.end,
                children: [
                  if (_canModify)
                    Tooltip(
                      message: 'Close modify screen',
                      child: SizedBox(
                        width: 140,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _closeScreen,
                          icon: const Icon(Icons.close_outlined, size: 18),
                          label: const Text('Cancel'),
                        ),
                      ),
                    ),
                  if (_canReprint)
                    Tooltip(
                      message: 'Print stock dispatch slip',
                      child: SizedBox(
                        width: 140,
                        height: 44,
                        child: FilledButton.icon(
                          onPressed: _reprint,
                          icon: const Icon(Icons.print_outlined, size: 18),
                          label: const Text('Print'),
                        ),
                      ),
                    ),
                  if (_canModify)
                    Tooltip(
                      message: 'Save stock dispatch changes',
                      child: SizedBox(
                        width: 140,
                        height: 44,
                        child: FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save_outlined, size: 18),
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

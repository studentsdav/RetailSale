import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/inventory/issue_controller.dart';
import '../../controllers/modify/request_modify-controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/common/property_info_model.dart';
import '../../models/inventory/request_detail_model.dart';
import '../../models/inventory/stock_location_model.dart';

class RequestModifyScreen extends StatefulWidget {
  const RequestModifyScreen({super.key});

  @override
  State<RequestModifyScreen> createState() => _RequestModifyScreenState();
}

class _RequestModifyScreenState extends State<RequestModifyScreen> {
  final ctrl = RequestModifyController();
  final issueCtrl = IssueController();
  final propertyCtrl = PropertyInfoController();
  PropertyInfo? propertyInfo;
  DateTime selectedDate = DateTime.now();

  int? requestId;
  StockLocationdata? selectedDepartment;

  List items = [];

  T? _singleMatchOrNull<T>(Iterable<T?> values, T? selected) {
    if (selected == null) return null;
    final matches = values.where((value) => value == selected).length;
    return matches == 1 ? selected : null;
  }

  @override
  void initState() {
    super.initState();
    _initLoad();
    _loadPropertyInfo();
  }

  Future<void> _loadPropertyInfo() async {
    await propertyCtrl.load();
    setState(() {
      propertyInfo = propertyCtrl.data;
    });
  }

  Future<void> _initLoad() async {
    await issueCtrl.getdepartment();
    await _loadRequests();
  }

  Future<void> _loadRequests() async {
    final date = DateFormat('yyyy-MM-dd').format(selectedDate);
    await ctrl.loadRequestsByDate(date);
    setState(() {
      requestId = null;
      selectedDepartment = null;
      items = [];
    });
  }

  Future<void> _loadDetails(int id) async {
    setState(() {
      requestId = id;
      selectedDepartment = null;
      items = [];
    });

    await ctrl.loadRequestDetails(id);

    final deptId = ctrl.requestDetails['department'];
    StockLocationdata? nextDepartment;

    try {
      nextDepartment = issueCtrl.departments.firstWhere(
        (e) => e.locationName.toString() == deptId.toString(),
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
    if (requestId == null) {
      _msg("Select request");
      return;
    }

    if (items.isEmpty) {
      _msg("At least one item required");
      return;
    }

    await ctrl.modifyRequest(
      requestId: requestId!,
      department: selectedDepartment!.locationName.toString(),
      items: items,
    );

    _msg("Request Updated");
  }

  void _msg(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m)),
    );
  }

  void _reprint() {
    if (requestId == null) {
      _msg("Select request");
      return;
    }
    reprintRequest(requestId!);
  }

  Future<void> _cancelRequest() async {
    if (requestId == null) {
      _msg("Select request");
      return;
    }

    final status = ctrl.requestDetails['status'] ?? ''.toUpperCase();
    if (status == 'CLOSED' || status == 'CANCELLED') {
      _msg("Only open or partial request can be cancelled");
      return;
    }

    try {
      await ctrl.cancelRequest(requestId!);
      _msg("Request cancelled");
      await _loadRequests();
      setState(() {
        requestId = null;
        selectedDepartment = null;
        items = [];
      });
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> reprintRequest(int id) async {
    final res = await ApiClient.get('${ApiEndpoints.requests}/$id');

    final request = RequestDetail.fromJson(res['data']);

    await _printRequest(request);
  }

  Future<void> _printRequest(RequestDetail request) async {
    final pdf = pw.Document();

    final property = propertyCtrl.data;
    final totalAmount = request.items.fold<double>(
      0,
      (sum, i) => sum + (i.qty * i.rate),
    );
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          /// ================= HEADER =================
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // if (logo != null)
              //   pw.Container(
              //     width: 60,
              //     height: 60,
              //     child: pw.Image(logo),
              //   ),
              // pw.SizedBox(width: 12),
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
                    pw.Text(property?.address ?? ''),
                    pw.Text("GSTIN: ${property?.gstNo ?? ''}"),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Text(
                  "MATERIAL REQUEST",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= REQUEST INFO =================
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Request No: ${request.requestNo}"),
                  pw.Text(
                      "Date: ${DateFormat('dd-MMM-yyyy').format(request.requestDate)}"),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Department: ${request.department ?? ''}"),
                  pw.Text("Status: ${request.status}"),
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
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _cell("S.No", bold: true),
                  _cell("Item"),
                  _cell("Unit"),
                  _cell("Qty"),
                  _cell("Rate"),
                ],
              ),
              ...List.generate(request.items.length, (i) {
                final r = request.items[i];
                return pw.TableRow(
                  children: [
                    _cell("${i + 1}"),
                    _cell(r.name),
                    _cell(r.unit),
                    _cell(r.qty.toString()),
                    _cell(r.rate.toStringAsFixed(2)),
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
              "Total Amount : ${totalAmount.toStringAsFixed(2)}",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),

          pw.SizedBox(height: 30),

          /// ================= SIGNATURE SECTION =================
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(children: [
                pw.Text("Requested By"),
                pw.SizedBox(height: 30),
              ]),
              pw.Column(children: [
                pw.Text("Store Incharge"),
                pw.SizedBox(height: 30),
              ]),
              pw.Column(children: [
                pw.Text("Approved By"),
                pw.SizedBox(height: 30),
              ]),
            ],
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

  Widget _modernFieldDecoration(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedRequestValue = _singleMatchOrNull<int>(
      ctrl.requests.map((e) => int.tryParse(e['id'].toString())),
      requestId,
    );
    final selectedDepartmentValue = _singleMatchOrNull<StockLocationdata>(
      issueCtrl.departments,
      selectedDepartment,
    );

    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        title: const Text("Modify Request"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            /// FILTER SECTION
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  /// DATE
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
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
                        await _loadRequests();
                      }
                    },
                  ),

                  const SizedBox(width: 20),

                  /// REQUEST NO
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('request-$requestId'),
                      value: selectedRequestValue,
                      decoration: InputDecoration(
                        labelText: "Request No",
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: ctrl.requests
                          .map<DropdownMenuItem<int>>(
                              (e) => DropdownMenuItem<int>(
                                    value: int.parse(e['id'].toString()),
                                    child: Text(e['request_no']),
                                  ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) _loadDetails(v);
                      },
                    ),
                  ),

                  const SizedBox(width: 20),

                  /// DEPARTMENT
                  Expanded(
                    child: DropdownButtonFormField<StockLocationdata>(
                      key: ValueKey(
                        'request-department-$requestId-${selectedDepartment?.id ?? selectedDepartment?.locationName}',
                      ),
                      value: selectedDepartmentValue,
                      decoration: InputDecoration(
                        labelText: "Department",
                        filled: true,
                        fillColor: Colors.grey.shade50,
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

            const SizedBox(height: 20),

            /// ITEMS GRID
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      Colors.grey.shade100,
                    ),
                    columnSpacing: 40,
                    columns: const [
                      DataColumn(label: Text("S.No")),
                      DataColumn(label: Text("Item")),
                      DataColumn(label: Text("Unit")),
                      DataColumn(label: Text("Qty")),
                      DataColumn(label: Text("Rate")),
                      DataColumn(label: Text("Amount")),
                      DataColumn(label: Text("Action")),
                    ],
                    rows: List.generate(items.length, (i) {
                      final item = items[i];

                      final amount = double.parse(item['qty'].toString()) *
                          double.parse(item['rate'].toString());

                      return DataRow(
                        color: WidgetStateProperty.resolveWith((states) {
                          return i.isEven
                              ? const Color(0xffFAFBFD)
                              : Colors.white;
                        }),
                        cells: [
                          DataCell(Text("${i + 1}")),
                          DataCell(Text(item['item_master']['item_name'])),
                          DataCell(Text(item['item_master']['unit'])),
                          DataCell(
                            SizedBox(
                              width: 80,
                              child: _modernFieldDecoration(
                                TextFormField(
                                  key: ValueKey(
                                    'request-$requestId-${item['id'] ?? item['item_code'] ?? item['item_master']?['item_code'] ?? item['item_master']?['item_name']}-qty',
                                  ),
                                  initialValue: item['qty'].toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                  ),
                                  onChanged: (v) {
                                    item['qty'] = double.tryParse(v) ?? 0;
                                    setState(() {});
                                  },
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 90,
                              child: _modernFieldDecoration(
                                TextFormField(
                                  key: ValueKey(
                                    'request-$requestId-${item['id'] ?? item['item_code'] ?? item['item_master']?['item_code'] ?? item['item_master']?['item_name']}-rate',
                                  ),
                                  initialValue: item['rate'].toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                  ),
                                  onChanged: (v) {
                                    item['rate'] = double.tryParse(v) ?? 0;
                                    setState(() {});
                                  },
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              amount.toStringAsFixed(2),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red,
                              tooltip: "Delete Item",
                              onPressed: () {
                                if (items.length == 1) {
                                  _msg("At least one item required");
                                  return;
                                }

                                setState(() {
                                  items.removeAt(i);
                                });
                              },
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
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Text(
                    "Total Amount",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    "₹ ${total.toStringAsFixed(2)}",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
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
                    message: 'Cancel request',
                    child: SizedBox(
                      width: 180,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _cancelRequest,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel Request'),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Print request slip',
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
                    message: 'Save request changes',
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

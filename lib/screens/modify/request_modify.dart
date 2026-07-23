import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/inventory/issue_controller.dart';
import '../../controllers/modify/request_modify-controller.dart';
import '../../models/auth/permission_service.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/common/property_info_model.dart';
import '../../models/inventory/request_detail_model.dart';
import '../../models/inventory/stock_location_model.dart';
import '../../utils/branding_storage.dart';
import '../../core/printing/pos_invoice_printer.dart';

class RequestModifyScreen extends StatefulWidget {
  const RequestModifyScreen({super.key});

  @override
  State<RequestModifyScreen> createState() => _RequestModifyScreenState();
}

class _RequestModifyScreenState extends State<RequestModifyScreen> {
  final ctrl = RequestModifyController();
  bool get _canReprint =>
      PermissionService.can('REPRINT_REQUEST') || PermissionService.can('MODIFY_REQUEST');
  bool get _canModify => PermissionService.can('MODIFY_REQUEST');
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
    final logo = await BrandingStorage.loadPdfLogo(property?.logoPath);
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
          PosInvoicePrinter.buildStandardA4Header(
            property: property,
            logo: logo,
            rightWidget: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              child: pw.Text(
                "MATERIAL REQUEST",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
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
                    _cell(r.brand.isNotEmpty ? '${r.name} (${r.brand})' : r.name),
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

    await Printing.layoutPdf(name: 'Request_${request.requestNo}', onLayout: (format) async => pdf.save());
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                                await _loadRequests();
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    /// REQUEST NO
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Request No",
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
                            key: ValueKey('request-$requestId'),
                            initialValue: selectedRequestValue,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: ctrl.requests
                                .map<DropdownMenuItem<int>>(
                                    (e) => DropdownMenuItem<int>(
                                          value: int.parse(e['id'].toString()),
                                          child: Text(e['request_no'], style: const TextStyle(fontSize: 13)),
                                        ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) _loadDetails(v);
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
                              'request-department-$requestId-${selectedDepartment?.id ?? selectedDepartment?.locationName}',
                            ),
                            initialValue: selectedDepartmentValue,
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
                              DataCell(Text(
                                '${item['item_master']['item_name']}${item['item_master']['brand'] != null && item['item_master']['brand'].toString().isNotEmpty ? ' (${item['item_master']['brand']})' : ''}'
                              )),
                              DataCell(Text(item['item_master']['unit'] ?? "")),
                              DataCell(
                                SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    key: ValueKey(
                                      'request-$requestId-${item['id'] ?? item['item_code'] ?? item['item_master']?['item_code'] ?? item['item_master']?['item_name']}-qty',
                                    ),
                                    initialValue: item['qty'].toString(),
                                    keyboardType: TextInputType.number,
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
                              DataCell(
                                SizedBox(
                                  width: 90,
                                  child: TextFormField(
                                    key: ValueKey(
                                      'request-$requestId-${item['id'] ?? item['item_code'] ?? item['item_master']?['item_code'] ?? item['item_master']?['item_name']}-rate',
                                    ),
                                    initialValue: item['rate'].toString(),
                                    keyboardType: TextInputType.number,
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
                      message: 'Cancel request',
                      child: SizedBox(
                        width: 150,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _cancelRequest,
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Cancel Request'),
                        ),
                      ),
                    ),
                  if (_canReprint)
                    Tooltip(
                      message: 'Print request slip',
                      child: SizedBox(
                        width: 150,
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
                      message: 'Save request changes',
                      child: SizedBox(
                        width: 150,
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../controllers/inventory/item_controller.dart';
import '../../controllers/restaurant/restaurant_controller.dart';
import '../inventory/salescreen.dart';

class DeliveryChallanScreen extends StatefulWidget {
  const DeliveryChallanScreen({super.key});

  @override
  State<DeliveryChallanScreen> createState() => _DeliveryChallanScreenState();
}

class _DeliveryChallanScreenState extends State<DeliveryChallanScreen> {
  final ItemController _itemController = ItemController();
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedStatusFilter = 'ALL';
  bool _isInit = false;

  final NumberFormat _qtyFmt = NumberFormat.decimalPattern();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final restCtrl = Provider.of<RestaurantController>(context, listen: false);
    await Future.wait([
      restCtrl.loadChallans(),
      _itemController.load(),
    ]);
    if (mounted) {
      setState(() => _isInit = true);
    }
  }

  List<dynamic> _getFilteredChallans(List<dynamic> list) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return list.where((item) {
      final status = (item['status'] ?? '').toString().toUpperCase();
      if (_selectedStatusFilter == 'ISSUED' && status != 'ISSUED') return false;
      if (_selectedStatusFilter == 'CONVERTED' && status == 'ISSUED') return false;

      if (query.isEmpty) return true;
      final challanNo = (item['challan_no'] ?? '').toString().toLowerCase();
      final customer = (item['customer_name'] ?? '').toString().toLowerCase();
      final phone = (item['customer_phone'] ?? '').toString().toLowerCase();
      return challanNo.contains(query) || customer.contains(query) || phone.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<RestaurantController>();
    final allChallans = ctrl.challans;
    final filteredList = _getFilteredChallans(allChallans);

    final totalCount = allChallans.length;
    final pendingCount = allChallans.where((c) => c['status'] == 'Issued').length;
    final convertedCount = totalCount - pendingCount;
    final totalDispatchedQty = allChallans.fold<double>(
      0.0,
      (sum, c) => sum + (double.tryParse(c['total_qty']?.toString() ?? '0') ?? 0.0),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Delivery Challan Manager',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: () => ctrl.loadChallans(),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF008060),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _openIssueChallanDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Issue Delivery Challan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: ctrl.loading && !_isInit
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: ctrl.loadChallans,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary KPI Cards
                    Row(
                      children: [
                        _buildKpiCard(
                          title: 'Total Challans Issued',
                          value: '$totalCount',
                          subtitle: '${_qtyFmt.format(totalDispatchedQty)} Units Dispatched',
                          icon: Icons.local_shipping_outlined,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        _buildKpiCard(
                          title: 'Pending Conversion',
                          value: '$pendingCount',
                          subtitle: 'Awaiting Final Sales Invoice',
                          icon: Icons.pending_actions_outlined,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        _buildKpiCard(
                          title: 'Converted to Sale',
                          value: '$convertedCount',
                          subtitle: 'Fully Invoiced & Settled',
                          icon: Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Search & Filter Toolbar
                    Card(
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  hintText: 'Search by Challan #, Customer Name, or Phone...',
                                  prefixIcon: Icon(Icons.search, size: 20),
                                  isDense: true,
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'ALL', label: Text('All')),
                                ButtonSegment(value: 'ISSUED', label: Text('Issued (Pending)')),
                                ButtonSegment(value: 'CONVERTED', label: Text('Converted')),
                              ],
                              selected: {_selectedStatusFilter},
                              onSelectionChanged: (set) {
                                setState(() => _selectedStatusFilter = set.first);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Challan Table Container
                    Card(
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: filteredList.isEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(40),
                                color: Colors.white,
                                child: Column(
                                  children: [
                                    Icon(Icons.local_shipping_outlined, size: 54, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No Delivery Challans Found',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Click "Issue Delivery Challan" to dispatch goods to a customer.',
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                color: Colors.white,
                                width: double.infinity,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                                  dataRowMaxHeight: 64,
                                  columns: const [
                                    DataColumn(label: Text('Challan No & Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Total Dispatched Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: filteredList.map((item) {
                                    final isIssued = item['status'] == 'Issued';
                                    final dateStr = item['challan_date'] != null
                                        ? DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(item['challan_date']))
                                        : 'N/A';

                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['challan_no'] ?? 'N/A',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                                              ),
                                              Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['customer_name'] ?? 'Walk-in Customer',
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                              ),
                                              Text(
                                                item['customer_phone'] ?? 'No Phone',
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                              ),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            '${item['total_qty'] ?? 0} Units',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isIssued ? Colors.orange.shade50 : Colors.green.shade50,
                                              border: Border.all(
                                                color: isIssued ? Colors.orange.shade300 : Colors.green.shade300,
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              isIssued ? 'Issued (Pending)' : 'Converted to Sale',
                                              style: TextStyle(
                                                color: isIssued ? Colors.orange.shade900 : Colors.green.shade900,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.print_outlined, color: Colors.indigo),
                                                tooltip: 'Print Delivery Challan Bill to Printer',
                                                onPressed: () => _printChallanToPrinter(context, item['id']),
                                              ),
                                              if (isIssued) ...[
                                                const SizedBox(width: 4),
                                                OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: const Color(0xFF008060),
                                                    side: const BorderSide(color: Color(0xFF008060)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                  ),
                                                  onPressed: () => _openInBillingScreen(context, item['id']),
                                                  icon: const Icon(Icons.point_of_sale, size: 16),
                                                  label: const Text('Open in Billing', style: TextStyle(fontSize: 12)),
                                                ),
                                                const SizedBox(width: 4),
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF008060),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                  ),
                                                  onPressed: () async {
                                                    final success = await ctrl.updateChallanStatus(item['id'], 'Converted_To_Sale');
                                                    if (success && context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text('Delivery Challan converted to final Sales Invoice!'),
                                                          backgroundColor: Color(0xFF008060),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  icon: const Icon(Icons.check, size: 16),
                                                  label: const Text('Convert 1-Click', style: TextStyle(fontSize: 12)),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _openInBillingScreen(BuildContext context, int challanId) async {
    final restCtrl = Provider.of<RestaurantController>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final details = await restCtrl.getChallanDetails(challanId);
    if (context.mounted) Navigator.pop(context); // Dismiss loader

    if (details == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load delivery challan details')),
        );
      }
      return;
    }

    final List<Map<String, dynamic>> preloadedItems = (details['items'] as List? ?? []).map((it) {
      return {
        'item_id': it['item_id'],
        'item_name': it['item_name'],
        'unit': it['unit'] ?? 'PCS',
        'qty': double.tryParse(it['qty']?.toString() ?? '1') ?? 1.0,
      };
    }).toList();

    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SaleScreen(
            preloadedItems: preloadedItems,
            preloadedCustomerName: details['customer_name'],
            preloadedCustomerPhone: details['customer_phone'],
            challanNo: details['challan_no'],
            affectStock: false, // Stock NOT deducted again (already adjusted on challan issue)
          ),
        ),
      );

      // Auto-update status to Converted_To_Sale after returning from Billing
      await restCtrl.updateChallanStatus(challanId, 'Converted_To_Sale');
    }
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openIssueChallanDialog(BuildContext mainContext) {
    final customerNameCtrl = TextEditingController();
    final customerPhoneCtrl = TextEditingController();

    List<Map<String, dynamic>> lineItems = [];
    final catalogItems = _itemController.list;

    showDialog(
      context: mainContext,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Row(
                children: [
                  Icon(Icons.local_shipping, color: Color(0xFF008060)),
                  SizedBox(width: 10),
                  Text('Issue New Delivery Challan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: customerNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Customer Name *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: customerPhoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Customer Phone *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Dispatch Item Line Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          TextButton.icon(
                            onPressed: () {
                              if (catalogItems.isNotEmpty) {
                                final first = catalogItems.first;
                                setDialogState(() {
                                  lineItems.add({
                                    'item_id': first.id,
                                    'item_name': first.itemName,
                                    'unit': first.unit ?? 'PCS',
                                    'qty': 1.0,
                                  });
                                });
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text('Add Line Item'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (lineItems.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'No line items added yet. Click "+ Add Line Item" above.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: lineItems.length,
                          itemBuilder: (context, idx) {
                            final row = lineItems[idx];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<int>(
                                      value: row['item_id'],
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Item',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      items: catalogItems.map((catItem) {
                                        return DropdownMenuItem<int>(
                                          value: catItem.id,
                                          child: Text('${catItem.itemCode} - ${catItem.itemName}'),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          final found = catalogItems.firstWhere((it) => it.id == val);
                                          setDialogState(() {
                                            row['item_id'] = found.id;
                                            row['item_name'] = found.itemName;
                                            row['unit'] = found.unit ?? 'PCS';
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      initialValue: row['qty'].toString(),
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Qty (${row['unit']})',
                                        isDense: true,
                                        border: const OutlineInputBorder(),
                                      ),
                                      onChanged: (val) {
                                        row['qty'] = double.tryParse(val) ?? 1.0;
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () {
                                      setDialogState(() {
                                        lineItems.removeAt(idx);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF008060)),
                  onPressed: () async {
                    if (customerNameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(mainContext).showSnackBar(
                        const SnackBar(content: Text('Customer Name is required')),
                      );
                      return;
                    }
                    if (lineItems.isEmpty) {
                      ScaffoldMessenger.of(mainContext).showSnackBar(
                        const SnackBar(content: Text('Please add at least 1 item to dispatch')),
                      );
                      return;
                    }

                    Navigator.pop(dialogCtx);
                    final restCtrl = Provider.of<RestaurantController>(mainContext, listen: false);
                    final success = await restCtrl.saveChallan({
                      'customer_name': customerNameCtrl.text.trim(),
                      'customer_phone': customerPhoneCtrl.text.trim(),
                      'items': lineItems,
                    });

                    if (success && mainContext.mounted) {
                      ScaffoldMessenger.of(mainContext).showSnackBar(
                        const SnackBar(
                          content: Text('Delivery Challan issued successfully! Stock deducted.'),
                          backgroundColor: Color(0xFF008060),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Issue Challan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // PRINTABLE DELIVERY CHALLAN BILL ENGINE (PDF + Direct System Printer)
  // =========================================================================
  Future<void> _printChallanToPrinter(BuildContext context, int challanId) async {
    final restCtrl = Provider.of<RestaurantController>(context, listen: false);
    
    // Show quick progress loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final details = await restCtrl.getChallanDetails(challanId);
    if (context.mounted) Navigator.pop(context); // Dismiss progress

    if (details == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load full delivery challan details')),
        );
      }
      return;
    }

    final challanNo = details['challan_no'] ?? 'DC-UNKNOWN';
    final customerName = details['customer_name'] ?? 'Walk-In Customer';
    final customerPhone = details['customer_phone'] ?? 'N/A';
    final status = details['status'] ?? 'Issued';
    final rawDate = details['challan_date'];
    final dateStr = rawDate != null
        ? DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(rawDate.toString()))
        : DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());

    final List<dynamic> itemsList = details['items'] ?? [];
    final double totalQty = details['total_qty'] != null
        ? double.tryParse(details['total_qty'].toString()) ?? 0.0
        : itemsList.fold<double>(0.0, (sum, it) => sum + (double.tryParse(it['qty']?.toString() ?? '0') ?? 0.0));

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context pwContext) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Company Header & Document Banner
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DELIVERY CHALLAN',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'STOCK DISPATCH & DELIVERY NOTE',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.blueGrey800, width: 1),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Challan No: $challanNo',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                        pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('Status: $status', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey700)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey400, thickness: 1),
              pw.SizedBox(height: 12),

              // Customer / Consignee Information Block
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Consignee / Customer Details:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey800)),
                        pw.SizedBox(height: 4),
                        pw.Text('Name: $customerName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.Text('Phone: $customerPhone', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Dispatch Type: Outward Goods', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Mode of Transport: Hand / Vehicle', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Items Table
              pw.Text('Dispatched Line Items Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              pw.SizedBox(height: 6),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _pdfCell('#', bold: true, alignment: pw.Alignment.center),
                      _pdfCell('Item Code', bold: true),
                      _pdfCell('Item Description', bold: true),
                      _pdfCell('Unit', bold: true, alignment: pw.Alignment.center),
                      _pdfCell('Quantity Dispatched', bold: true, alignment: pw.Alignment.centerRight),
                    ],
                  ),
                  // Table Rows
                  ...List.generate(itemsList.length, (idx) {
                    final row = itemsList[idx];
                    final qtyVal = double.tryParse(row['qty']?.toString() ?? '0') ?? 0.0;
                    return pw.TableRow(
                      children: [
                        _pdfCell('${idx + 1}', alignment: pw.Alignment.center),
                        _pdfCell(row['item_code'] ?? 'N/A'),
                        _pdfCell(row['item_name'] ?? 'Item'),
                        _pdfCell(row['unit'] ?? 'PCS', alignment: pw.Alignment.center),
                        _pdfCell(qtyVal.toStringAsFixed(2), alignment: pw.Alignment.centerRight, bold: true),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 16),

              // Totals Box
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 220,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Dispatched Qty:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text('${totalQty.toStringAsFixed(2)} Units', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blue900)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 24),

              // Declarations & Terms
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  border: pw.Border.all(color: PdfColors.grey200),
                ),
                child: pw.Text(
                  'Declaration: Received the above mentioned goods/items in good condition and order as specified in this delivery challan.',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
              ),

              pw.Spacer(),

              // Signatures Block
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 120, height: 1, color: PdfColors.grey500),
                      pw.SizedBox(height: 4),
                      pw.Text('Dispatched By (Store)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 120, height: 1, color: PdfColors.grey500),
                      pw.SizedBox(height: 4),
                      pw.Text('Driver / Transporter', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 120, height: 1, color: PdfColors.grey500),
                      pw.SizedBox(height: 4),
                      pw.Text('Receiver Signature & Stamp', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Send PDF document layout directly to printer / print preview!
    await Printing.layoutPdf(
      name: 'Delivery_Challan_$challanNo',
      onLayout: (format) async => pdf.save(),
    );
  }

  pw.Widget _pdfCell(String text, {bool bold = false, pw.Alignment alignment = pw.Alignment.centerLeft}) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: bold ? PdfColors.grey900 : PdfColors.grey800,
        ),
      ),
    );
  }
}

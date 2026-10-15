import 'package:flutter/material.dart';

import '../core/config/date_time_service.dart';
import '../core/currency/currency_service.dart';
import '../core/printing/pos_invoice_printer.dart';
import '../core/utils/timezone_utils.dart';
import '../controllers/settings/property_info_controller.dart';
import '../controllers/settings/system_settings_controller.dart';
import '../models/common/property_info_model.dart';
import '../models/inventory/sale_order_model.dart';

Future<void> showSaleBillPreviewDialog(
  BuildContext context, {
  required Map<String, dynamic> sale,
  PropertyInfo? property,
}) async {
  final settingsCtrl = SystemSettingsController();
  if (settingsCtrl.settings == null) {
    try {
      await settingsCtrl.load();
    } catch (_) {}
  }
  final sysSettings = settingsCtrl.settings;

  // Determine active print format (80mm vs A4) based on system settings or sale format
  String activeFormat = 'THERMAL_80';
  final rawSaleFormat = (sale['bill_format'] ?? sale['billFormat'])?.toString().trim();
  final sysBillFormat = sysSettings?.billFormat?.trim() ?? '';
  final thermalWidthSetting = (sysSettings?.receiptTemplateConfig?['thermal_width'] ?? '').toString();

  if (sysBillFormat.isNotEmpty) {
    activeFormat = sysBillFormat;
  } else if (rawSaleFormat != null && rawSaleFormat.isNotEmpty && rawSaleFormat != 'A4') {
    activeFormat = rawSaleFormat;
  } else if (thermalWidthSetting.contains('80')) {
    activeFormat = 'THERMAL_80';
  } else if (rawSaleFormat != null && rawSaleFormat.isNotEmpty) {
    activeFormat = rawSaleFormat;
  }

  // Normalize to standard known formats
  if (activeFormat.toUpperCase().contains('80') || activeFormat.toUpperCase().contains('THERMAL')) {
    activeFormat = 'THERMAL_80';
  } else if (activeFormat.toUpperCase().contains('A5')) {
    activeFormat = 'A5';
  } else {
    activeFormat = 'A4';
  }

  final order = SaleOrder.fromJson({
    ...sale,
    'bill_format': activeFormat,
  });
  final itemCount = order.items.length;

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final isThermal = activeFormat.toUpperCase().contains('80') || activeFormat.toUpperCase().contains('THERMAL');
        final isA5 = activeFormat.toUpperCase().contains('A5');

        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Bill ${order.saleNo}'),
              SegmentedButton<String>(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: [
                  const ButtonSegment(
                    value: 'THERMAL_80',
                    label: Text('80mm Thermal'),
                    icon: Icon(Icons.receipt_long_outlined, size: 16),
                  ),
                  if (sysBillFormat == 'A5' || activeFormat == 'A5')
                    const ButtonSegment(
                      value: 'A5',
                      label: Text('A5 Invoice'),
                      icon: Icon(Icons.description_outlined, size: 16),
                    ),
                  const ButtonSegment(
                    value: 'A4',
                    label: Text('A4 Invoice'),
                    icon: Icon(Icons.print_outlined, size: 16),
                  ),
                ],
                selected: {activeFormat},
                onSelectionChanged: (newSelection) {
                  setDialogState(() {
                    activeFormat = newSelection.first;
                  });
                },
              ),
            ],
          ),
          content: SizedBox(
            width: 920,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Customer: ${(order.customerName ?? '').trim().isEmpty ? 'Walk-in' : order.customerName!.trim()}'),
                  Text('Date: ${TimeZoneUtils.formatInTimeZone(order.saleDate, DateTimeService.instance.currentTimeZone, pattern: 'dd-MMM-yyyy hh:mm a')}'),
                  Text('Payment: ${order.paymentMode}${order.paymentMode.toUpperCase() == 'CREDIT' && order.balanceDue <= 0.009 ? ' (FULLY REPAID)' : (order.paymentMode.toUpperCase() == 'CREDIT' && order.amountPaid > 0.009 ? ' (PARTIALLY REPAID)' : '')}'),
                  Text('Net Amount: ${CurrencyService.format(order.netAmount)}'),
                  if (order.balanceDue > 0.009)
                    Text('Balance Due: ${CurrencyService.format(order.balanceDue)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  if ((order.paymentReference ?? '').trim().isNotEmpty && !order.paymentReference!.startsWith('POSPAY:'))
                    Text('Reference: ${order.paymentReference!.trim()}'),
                  if ((order.notes ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Notes: ${order.notes!.trim()}'),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Items',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  if (itemCount == 0)
                    const Text('No items found.')
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Item')),
                          DataColumn(label: Text('Qty')),
                          DataColumn(label: Text('Rate')),
                          DataColumn(label: Text('Amount')),
                        ],
                        rows: order.items.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(Text(item.itemName)),
                              DataCell(Text(_fmtQty(item.qty))),
                              DataCell(Text(item.rate.toStringAsFixed(2))),
                              DataCell(Text(item.netAmount.toStringAsFixed(2))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Total items: $itemCount',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                PropertyInfo? prop = property;
                if (prop == null) {
                  try {
                    final propCtrl = PropertyInfoController();
                    await propCtrl.load();
                    prop = propCtrl.data;
                  } catch (_) {}
                }
                final orderToPrint = order.copyWith(billFormat: activeFormat);
                await PosInvoicePrinter.printSaleInvoice(
                  order: orderToPrint,
                  property: prop,
                  settings: sysSettings,
                );
              },
              icon: const Icon(Icons.print_outlined),
              label: Text(
                isThermal
                    ? 'Print 80mm Thermal'
                    : (isA5 ? 'Print A5 Invoice' : 'Print A4 Invoice'),
              ),
            ),
          ],
        );
      },
    ),
  );
}

String _fmtQty(double qty) {
  return qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2);
}

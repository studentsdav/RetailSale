import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/printing/pos_invoice_printer.dart';
import '../models/inventory/sale_order_model.dart';

Future<void> showSaleBillPreviewDialog(
  BuildContext context, {
  required Map<String, dynamic> sale,
}) async {
  final order = SaleOrder.fromJson(sale);
  final itemCount = order.items.length;
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: Text('Bill ${order.saleNo}'),
      content: SizedBox(
        width: 920,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Customer: ${(order.customerName ?? '').trim().isEmpty ? 'Walk-in' : order.customerName!.trim()}'),
              Text('Date: ${DateFormat('dd-MMM-yyyy').format(order.saleDate)}'),
              Text('Status: ${order.status}'),
              Text('Payment: ${order.paymentMode}'),
              Text('Net Amount: ${currency.format(order.netAmount)}'),
              if ((order.paymentReference ?? '').trim().isNotEmpty)
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
            await PosInvoicePrinter.printSaleInvoice(
              order: order,
              property: null,
            );
          },
          icon: const Icon(Icons.print_outlined),
          label: const Text('Print PDF'),
        ),
      ],
    ),
  );
}

String _fmtQty(double qty) {
  return qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2);
}

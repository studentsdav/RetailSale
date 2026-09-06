import 'package:flutter/material.dart';
import '../../controllers/inventory/stock_transfer_controller.dart';

class StockReceiveScreen extends StatefulWidget {
  const StockReceiveScreen({super.key});

  @override
  State<StockReceiveScreen> createState() => _StockReceiveScreenState();
}

class _StockReceiveScreenState extends State<StockReceiveScreen> {
  final StockTransferController _transferCtrl = StockTransferController();
  List<dynamic> _pendingTransfers = [];
  bool _isLoading = true;
  int? _receivingId;

  @override
  void initState() {
    super.initState();
    _loadPendingTransfers();
  }

  Future<void> _loadPendingTransfers() async {
    setState(() => _isLoading = true);
    final transfers = await _transferCtrl.fetchTransfers(status: 'DISPATCHED');
    if (mounted) {
      setState(() {
        _pendingTransfers = transfers;
        _isLoading = false;
      });
    }
  }

  Future<void> _receiveTransfer(dynamic rawTransferId, String transferNo) async {
    final int? transferId = rawTransferId is int ? rawTransferId : int.tryParse(rawTransferId?.toString() ?? '');
    if (transferId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid transfer record ID')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Receive Shipment $transferNo?'),
        content: const Text(
          'Confirming receipt will credit 100% of the dispatched stock directly into your outlet stock ledger.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm Receive')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _receivingId = transferId);
    final res = await _transferCtrl.receiveStock(transferId);
    if (mounted) {
      setState(() => _receivingId = null);
      if (res != null && res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Stock credited successfully!')),
        );
        _loadPendingTransfers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?['message'] ?? 'Failed to receive stock')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Receive Incoming Outlet Stock'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingTransfers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingTransfers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mark_email_read_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No pending incoming stock transfers.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendingTransfers.length,
                  itemBuilder: (context, index) {
                    final t = _pendingTransfers[index];
                    final isReceiving = _receivingId == t['id'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.move_to_inbox, color: Colors.blue),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t['transfer_no'] ?? '',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Total Qty: ${t['total_qty']} | Total Amount: ₹${t['total_amount']}'),
                                  Text('Dispatch Date: ${t['dispatch_date'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: isReceiving ? null : () => _receiveTransfer(t['id'], t['transfer_no']),
                              icon: isReceiving
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.check_circle_outline),
                              label: const Text('Receive & Credit Stock'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

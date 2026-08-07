import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/restaurant/restaurant_controller.dart';

class DeliveryChallanScreen extends StatefulWidget {
  const DeliveryChallanScreen({super.key});

  @override
  State<DeliveryChallanScreen> createState() => _DeliveryChallanScreenState();
}

class _DeliveryChallanScreenState extends State<DeliveryChallanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RestaurantController>(context, listen: false).loadChallans();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<RestaurantController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Challan Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ctrl.loadChallans(),
          )
        ],
      ),
      body: ctrl.loading
          ? const Center(child: CircularProgressIndicator())
          : ctrl.challans.isEmpty
              ? const Center(child: Text('No delivery challans issued.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ctrl.challans.length,
                  itemBuilder: (context, index) {
                    final challan = ctrl.challans[index];
                    final isIssued = challan['status'] == 'Issued';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: isIssued ? colorScheme.primaryContainer : Colors.grey.shade200,
                          child: Icon(
                            Icons.local_shipping,
                            color: isIssued ? colorScheme.primary : Colors.grey,
                          ),
                        ),
                        title: Text(
                          'Challan No: ${challan['challan_no']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Customer: ${challan['customer_name'] ?? 'N/A'} (${challan['customer_phone'] ?? 'N/A'})\nDate: ${challan['challan_date']} | Total Qty: ${challan['total_qty']}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ),
                        trailing: isIssued
                            ? ElevatedButton.icon(
                                onPressed: () async {
                                  final success = await ctrl.updateChallanStatus(challan['id'], 'Converted_To_Sale');
                                  if (success && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Challan successfully converted to final Sale Invoice!')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.receipt_long, size: 16),
                                label: const Text('Convert to Sale'),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  challan['status'],
                                  style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}

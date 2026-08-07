import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/restaurant/restaurant_controller.dart';

class RecurringExpensesScreen extends StatefulWidget {
  const RecurringExpensesScreen({super.key});

  @override
  State<RecurringExpensesScreen> createState() => _RecurringExpensesScreenState();
}

class _RecurringExpensesScreenState extends State<RecurringExpensesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RestaurantController>(context, listen: false).loadRecurringExpenses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<RestaurantController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Expenses Scheduler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, ctrl),
          )
        ],
      ),
      body: ctrl.loading
          ? const Center(child: CircularProgressIndicator())
          : ctrl.recurringExpensesList.isEmpty
              ? const Center(child: Text('No recurring expenses scheduled.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ctrl.recurringExpensesList.length,
                  itemBuilder: (context, index) {
                    final item = ctrl.recurringExpensesList[index];
                    final isActive = item['is_active'] ?? true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.secondaryContainer,
                          child: Icon(Icons.autorenew, color: colorScheme.secondary),
                        ),
                        title: Text(
                          '${item['description'] ?? 'Expense'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Amount: \$${item['amount']} | Freq: ${item['frequency']}\nNext Generation Date: ${item['next_generation_date']}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green.shade100 : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isActive ? 'Active' : 'Paused',
                                style: TextStyle(color: isActive ? Colors.green.shade800 : Colors.red.shade800, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final success = await ctrl.deleteRecurringExpense(item['id']);
                                if (success && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Recurring expense scheduler deleted successfully')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showAddDialog(BuildContext context, RestaurantController ctrl) {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String freq = 'MONTHLY';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Schedule Recurring Expense'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description (e.g. Shop Rent, Internet Bill)'),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount (\$ / Local Currency)'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: freq,
                    decoration: const InputDecoration(labelText: 'Interval Frequency'),
                    items: const [
                      DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                      DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                      DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                      DropdownMenuItem(value: 'YEARLY', child: Text('Yearly')),
                    ],
                    onChanged: (val) => setState(() => freq = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (descCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                    final success = await ctrl.saveRecurringExpense({
                      'description': descCtrl.text,
                      'amount': double.tryParse(amountCtrl.text) ?? 0.0,
                      'frequency': freq,
                      'start_date': DateTime.now().toIso8601String().split('T')[0],
                      'next_generation_date': DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0],
                    });
                    if (success && mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Recurring expense successfully scheduled!')),
                      );
                    }
                  },
                  child: const Text('Schedule'),
                )
              ],
            );
          },
        );
      },
    );
  }
}

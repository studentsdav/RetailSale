import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/currency/currency_service.dart';

class ExpenseEntryScreen extends StatefulWidget {
  const ExpenseEntryScreen({super.key});

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  bool _loading = false;
  List<dynamic> _expenseHistory = [];

  static const Color primaryColor = Color(0xFF0B5CAD);

  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _vendorCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _selectedCategory = 'Petty Cash / General';
  String _selectedPaymentMode = 'CASH';

  final List<String> _categories = [
    'Petty Cash / General',
    'Rent & Utilities',
    'Equipment Repair & Maintenance',
    'Transport & Logistics',
    'Licenses & Permits',
    'Staff Welfare & Meals',
    'Marketing & Advertising',
    'Miscellaneous Expense',
  ];

  final List<String> _paymentModes = [
    'CASH',
    'MPESA_TILL',
    'MPESA_PAYBILL',
    'CARD',
    'BANK_TRANSFER',
  ];

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  Future<void> _fetchExpenses() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get('/api/restaurant/expenses?recurrent=false');
      if (res['success'] == true && res['data'] is List) {
        setState(() {
          _expenseHistory = res['data'] as List;
        });
      }
    } catch (e) {
      debugPrint('Error loading non-recurring expenses: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitExpense() async {
    final title = _titleCtrl.text.trim();
    final amountStr = _amountCtrl.text.trim();
    final amount = double.tryParse(amountStr) ?? 0.0;

    if (title.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid description and amount.'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final payload = {
        'description': title,
        'amount': amount,
        'category': _selectedCategory,
        'payment_mode': _selectedPaymentMode,
        'vendor_name': _vendorCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        'is_recurrent': false,
        'txn_date': DateTime.now().toIso8601String(),
      };

      final res = await ApiClient.post('/api/restaurant/expenses', payload);
      if (res['success'] == true) {
        _titleCtrl.clear();
        _amountCtrl.clear();
        _vendorCtrl.clear();
        _notesCtrl.clear();
        if (mounted) {
          Navigator.pop(context);
          _fetchExpenses();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Non-recurring expense logged successfully!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating expense: $e');
    }
  }

  void _showAddExpenseDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text(
            'Log Non-Recurring Expense',
            style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Expense Description (e.g. Generator Fuel / Taxi)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount (${CurrencyService.symbol})',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPaymentMode,
                  decoration: const InputDecoration(
                    labelText: 'Payment Mode',
                    border: OutlineInputBorder(),
                  ),
                  items: _paymentModes.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => _selectedPaymentMode = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _vendorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Vendor / Payee Name (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Reference # (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              onPressed: _submitExpense,
              child: const Text('Save Expense', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Non-Recurring Expenses Entry'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchExpenses,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Record One-Off / Petty Cash Expenses',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Log one-off operational expenditures. Entries update the cash ledger automatically.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _expenseHistory.isEmpty
                        ? const Center(child: Text('No non-recurring expense records logged yet.'))
                        : ListView.separated(
                            itemCount: _expenseHistory.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final item = _expenseHistory[index];
                              final desc = item['description'] ?? 'Expense';
                              final amt = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
                              final cat = item['category'] ?? 'General';
                              final pMode = item['payment_mode'] ?? 'CASH';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange.shade100,
                                  child: const Icon(Icons.receipt_long, color: Colors.deepOrange),
                                ),
                                title: Text(desc, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('$cat • Mode: $pMode'),
                                trailing: Text(
                                  CurrencyService.format(amt),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        onPressed: _showAddExpenseDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Log One-Off Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

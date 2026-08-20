import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../controllers/restaurant/restaurant_controller.dart';

class RecurringExpensesScreen extends StatefulWidget {
  const RecurringExpensesScreen({super.key});

  @override
  State<RecurringExpensesScreen> createState() => _RecurringExpensesScreenState();
}

class _RecurringExpensesScreenState extends State<RecurringExpensesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedFreqFilter = 'ALL';

  final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RestaurantController>(context, listen: false).loadRecurringExpenses();
    });
  }

  List<dynamic> _getFilteredExpenses(List<dynamic> list) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return list.where((item) {
      final freq = (item['frequency'] ?? '').toString().toUpperCase();
      if (_selectedFreqFilter != 'ALL' && freq != _selectedFreqFilter) return false;

      if (query.isEmpty) return true;
      final desc = (item['description'] ?? '').toString().toLowerCase();
      return desc.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<RestaurantController>();
    final allList = ctrl.recurringExpensesList;
    final filteredList = _getFilteredExpenses(allList);

    final totalCount = allList.length;
    final activeCount = allList.where((e) => e['is_active'] == true || e['is_active'] == 1).length;
    
    // Calculate Monthly Commitment Equivalent
    final monthlyCommitment = allList.where((e) => e['is_active'] == true || e['is_active'] == 1).fold<double>(
      0.0,
      (sum, e) {
        final amt = double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0;
        final freq = (e['frequency'] ?? 'MONTHLY').toString().toUpperCase();
        if (freq == 'DAILY') return sum + (amt * 30);
        if (freq == 'WEEKLY') return sum + (amt * 4.33);
        if (freq == 'YEARLY') return sum + (amt / 12);
        return sum + amt; // MONTHLY
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Recurring Expenses Scheduler',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Schedulers',
            onPressed: () => ctrl.loadRecurringExpenses(),
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
              onPressed: () => _openScheduleExpenseDialog(context, ctrl),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Schedule Recurring Expense',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: ctrl.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: ctrl.loadRecurringExpenses,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary KPI Header Cards
                    Row(
                      children: [
                        _buildKpiCard(
                          title: 'Total Schedulers',
                          value: '$totalCount',
                          subtitle: '$activeCount Schedulers Active',
                          icon: Icons.autorenew_outlined,
                          color: Colors.indigo,
                        ),
                        const SizedBox(width: 12),
                        _buildKpiCard(
                          title: 'Monthly Commitment',
                          value: _inr.format(monthlyCommitment),
                          subtitle: 'Estimated Monthly Fixed Cost',
                          icon: Icons.account_balance_wallet_outlined,
                          color: const Color(0xFF008060),
                        ),
                        const SizedBox(width: 12),
                        _buildKpiCard(
                          title: 'Active Schedulers',
                          value: '$activeCount / $totalCount',
                          subtitle: 'Auto-generates Expense Entries',
                          icon: Icons.schedule_outlined,
                          color: Colors.blue,
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
                                  hintText: 'Search expense description (e.g. Rent, Internet)...',
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
                                ButtonSegment(value: 'MONTHLY', label: Text('Monthly')),
                                ButtonSegment(value: 'WEEKLY', label: Text('Weekly')),
                                ButtonSegment(value: 'DAILY', label: Text('Daily')),
                                ButtonSegment(value: 'YEARLY', label: Text('Yearly')),
                              ],
                              selected: {_selectedFreqFilter},
                              onSelectionChanged: (set) {
                                setState(() => _selectedFreqFilter = set.first);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Expenses Table / Empty View
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
                                    Icon(Icons.schedule_outlined, size: 54, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No Recurring Expenses Scheduled',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Click "Schedule Recurring Expense" above to add automated bills (Rent, Utilities, Salary, etc.).',
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
                                    DataColumn(label: Text('Expense Description', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Frequency', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Next Run Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: filteredList.map((item) {
                                    final isActive = item['is_active'] == true || item['is_active'] == 1;
                                    final amt = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
                                    final nextDate = item['next_generation_date'] != null
                                        ? item['next_generation_date'].toString()
                                        : 'N/A';

                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            item['description'] ?? 'Unnamed Expense',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            _inr.format(amt),
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                                          ),
                                        ),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              border: Border.all(color: Colors.blue.shade200),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              (item['frequency'] ?? 'MONTHLY').toString().toUpperCase(),
                                              style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 11),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(nextDate, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                                        ),
                                        DataCell(
                                          Switch(
                                            value: isActive,
                                            activeColor: const Color(0xFF008060),
                                            onChanged: (val) async {
                                              await ctrl.saveRecurringExpense({
                                                'id': item['id'],
                                                'is_active': val,
                                              });
                                            },
                                          ),
                                        ),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                                            tooltip: 'Delete Scheduler',
                                            onPressed: () => _confirmDelete(context, ctrl, item['id']),
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
                    Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900)),
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

  void _openScheduleExpenseDialog(BuildContext mainContext, RestaurantController ctrl) {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String freq = 'MONTHLY';
    DateTime selectedNextDate = DateTime.now();

    showDialog(
      context: mainContext,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Row(
                children: [
                  Icon(Icons.schedule, color: Color(0xFF008060)),
                  SizedBox(width: 10),
                  Text('Schedule New Recurring Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Expense Description *',
                        hintText: 'e.g. Shop Rent, Internet Fiber, Cleaning Service',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹) *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: freq,
                      decoration: const InputDecoration(
                        labelText: 'Frequency Interval',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly (e.g. Rent, Salary)')),
                        DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly (e.g. Maintenance)')),
                        DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                        DropdownMenuItem(value: 'YEARLY', child: Text('Yearly (e.g. License Renewal)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => freq = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      title: Text(
                        'Next Run Date: ${DateFormat('yyyy-MM-dd').format(selectedNextDate)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      trailing: const Icon(Icons.calendar_month, color: Colors.indigo),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: mainContext,
                          initialDate: selectedNextDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedNextDate = picked);
                        }
                      },
                    ),
                  ],
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
                    if (descCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(mainContext).showSnackBar(
                        const SnackBar(content: Text('Please fill all required fields')),
                      );
                      return;
                    }

                    Navigator.pop(dialogCtx);
                    final success = await ctrl.saveRecurringExpense({
                      'description': descCtrl.text.trim(),
                      'amount': double.tryParse(amountCtrl.text.trim()) ?? 0.0,
                      'frequency': freq,
                      'next_generation_date': DateFormat('yyyy-MM-dd').format(selectedNextDate),
                      'is_active': true,
                    });

                    if (success && mainContext.mounted) {
                      ScaffoldMessenger.of(mainContext).showSnackBar(
                        const SnackBar(
                          content: Text('Recurring Expense scheduler created successfully!'),
                          backgroundColor: Color(0xFF008060),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Save Scheduler'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, RestaurantController ctrl, int id) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Recurring Expense Scheduler?'),
          content: const Text('Are you sure you want to delete this scheduler? Automated entries will stop.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await ctrl.deleteRecurringExpense(id);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Scheduler deleted successfully')),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

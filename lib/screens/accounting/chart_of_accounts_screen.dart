import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class ChartOfAccountsScreen extends StatefulWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  State<ChartOfAccountsScreen> createState() => _ChartOfAccountsScreenState();
}

class _ChartOfAccountsScreenState extends State<ChartOfAccountsScreen> {
  bool _loading = false;
  List<dynamic> _accounts = [];

  final _accNameCtrl = TextEditingController();
  final _accCodeCtrl = TextEditingController();
  String _selectedNature = 'EXPENSE';
  String _selectedGroup = 'Indirect Expenses';
  final _openingDebitCtrl = TextEditingController(text: '0.00');
  final _openingCreditCtrl = TextEditingController(text: '0.00');

  final List<String> _natures = ['ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE'];
  final Map<String, List<String>> _groupsByNature = {
    'ASSET': ['Current Assets', 'Bank Accounts', 'Fixed Assets', 'Stock / Inventory', 'Loans & Advances'],
    'LIABILITY': ['Current Liabilities', 'Sundry Creditors', 'Duties & Taxes', 'Loans (Liability)'],
    'EQUITY': ['Capital Account', 'Retained Earnings', 'Reserves & Surplus'],
    'REVENUE': ['Sales Income', 'Direct Income', 'Indirect Income / Interest'],
    'EXPENSE': ['Direct Expenses', 'Indirect Expenses', 'Rent & Utilities', 'Salaries & Wages', 'Depreciation'],
  };

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get(ApiEndpoints.accountingTrialBalance);
      if (res['success'] == true && res['data'] is List) {
        setState(() {
          _accounts = res['data'] as List;
        });
      }
    } catch (e) {
      debugPrint('Error fetching Chart of Accounts: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showAddAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text(
            'Add New General Ledger Account',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B5CAD)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _accNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ledger Account Name (e.g. Office Electricity)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedNature,
                  decoration: const InputDecoration(
                    labelText: 'Account Nature',
                    border: OutlineInputBorder(),
                  ),
                  items: _natures.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDlgState(() {
                        _selectedNature = val;
                        _selectedGroup = _groupsByNature[val]?.first ?? 'General';
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedGroup,
                  decoration: const InputDecoration(
                    labelText: 'Account Group',
                    border: OutlineInputBorder(),
                  ),
                  items: (_groupsByNature[_selectedNature] ?? ['General'])
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => _selectedGroup = val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _openingDebitCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Opening Debit (₹)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _openingCreditCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Opening Credit (₹)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5CAD)),
              onPressed: () async {
                if (_accNameCtrl.text.trim().isEmpty) return;
                try {
                  await ApiClient.post(ApiEndpoints.accountingTrialBalance, {
                    'account_name': _accNameCtrl.text.trim(),
                    'group_name': _selectedGroup,
                    'nature': _selectedNature,
                    'opening_debit': double.tryParse(_openingDebitCtrl.text) ?? 0.0,
                    'opening_credit': double.tryParse(_openingCreditCtrl.text) ?? 0.0,
                  });
                  _accNameCtrl.clear();
                  if (mounted) {
                    Navigator.pop(ctx);
                    _fetchAccounts();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ledger Account Added Successfully!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  debugPrint('Error creating ledger account: $e');
                }
              },
              child: const Text('Create Account', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0B5CAD);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Chart of Accounts (COA) Hierarchy',
          style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: primaryColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: primaryColor),
            onPressed: _fetchAccounts,
            tooltip: 'Refresh Chart of Accounts',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        onPressed: _showAddAccountDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Custom Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Master Chart of Accounts (COA)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryColor),
                            ),
                            Text(
                              'Hierarchical structure of Assets, Liabilities, Equity, Revenue, and Expenses.',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_accounts.length} Active Ledgers',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListView.separated(
                        itemCount: _accounts.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final acc = _accounts[index];
                          final nature = acc['nature'] ?? 'ASSET';
                          Color natureColor = Colors.blue;
                          if (nature == 'LIABILITY') natureColor = Colors.red;
                          if (nature == 'REVENUE') natureColor = Colors.green;
                          if (nature == 'EXPENSE') natureColor = Colors.orange;

                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: natureColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: natureColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                nature,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: natureColor),
                              ),
                            ),
                            title: Text(
                              acc['account_name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            subtitle: Text('Group: ${acc['group_name'] ?? 'General'}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Dr: ₹${acc['debit'] ?? 0} | Cr: ₹${acc['credit'] ?? 0}',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

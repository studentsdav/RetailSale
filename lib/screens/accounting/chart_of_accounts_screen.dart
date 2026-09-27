import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/currency/currency_service.dart';

class ChartOfAccountsScreen extends StatefulWidget {
  final String? outletId;
  const ChartOfAccountsScreen({super.key, this.outletId});

  @override
  State<ChartOfAccountsScreen> createState() => _ChartOfAccountsScreenState();
}

class _ChartOfAccountsScreenState extends State<ChartOfAccountsScreen> with SingleTickerProviderStateMixin {
  bool _loading = false;
  List<dynamic> _accounts = [];
  String _selectedNatureFilter = 'ALL';
  String _searchQuery = '';

  final _searchCtrl = TextEditingController();
  final _accNameCtrl = TextEditingController();
  final _accCodeCtrl = TextEditingController();
  String _selectedNature = 'EXPENSE';
  String _selectedGroup = 'Indirect Expenses';
  final _openingDebitCtrl = TextEditingController(text: '0.00');
  final _openingCreditCtrl = TextEditingController(text: '0.00');

  final List<String> _natures = ['ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE'];
  final Map<String, List<String>> _groupsByNature = {
    'ASSET': ['Current Assets', 'Bank Accounts', 'Fixed Assets', 'Stock / Inventory', 'Loans & Advances', 'Duties & Taxes'],
    'LIABILITY': ['Current Liabilities', 'Sundry Creditors', 'Duties & Taxes', 'Loans (Liability)'],
    'EQUITY': ['Capital Account', 'Retained Earnings', 'Reserves & Surplus'],
    'REVENUE': ['Sales Income', 'Direct Income', 'Indirect Income / Interest'],
    'EXPENSE': ['Direct Expenses', 'Indirect Expenses', 'Rent & Utilities', 'Salaries & Wages', 'Depreciation', 'Repairs & Maintenance'],
  };

  static const primaryColor = Color(0xFF0B5CAD);

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _accNameCtrl.dispose();
    _accCodeCtrl.dispose();
    _openingDebitCtrl.dispose();
    _openingCreditCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAccounts() async {
    setState(() => _loading = true);
    try {
      final params = <String>[];
      if (widget.outletId != null && widget.outletId!.isNotEmpty) {
        params.add('outlet_id=${widget.outletId}');
      }
      if (_selectedNatureFilter != 'ALL') {
        params.add('nature=$_selectedNatureFilter');
      }
      if (_searchQuery.trim().isNotEmpty) {
        params.add('search=${Uri.encodeComponent(_searchQuery.trim())}');
      }

      final queryString = params.isNotEmpty ? '?${params.join('&')}' : '';
      final res = await ApiClient.get('${ApiEndpoints.accountingCoa}$queryString');
      if (res['success'] == true && res['data'] is List) {
        setState(() {
          _accounts = res['data'] as List;
        });
      }
    } catch (e) {
      debugPrint('Error fetching Chart of Accounts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading COA: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _seedDefaultAccounts() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.post(
        '${ApiEndpoints.accountingCoa}/seed',
        widget.outletId != null ? {'outlet_id': widget.outletId} : {},
      );
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Standard Chart of Accounts seeded successfully!'), backgroundColor: Colors.green),
          );
        }
        await _fetchAccounts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to seed accounts: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddAccountDialog({Map<String, dynamic>? editAccount}) {
    final isEditing = editAccount != null;
    if (isEditing) {
      _accNameCtrl.text = editAccount['account_name'] ?? '';
      _accCodeCtrl.text = editAccount['account_code'] ?? '';
      _selectedNature = editAccount['nature'] ?? 'EXPENSE';
      _selectedGroup = editAccount['group_name'] ?? (_groupsByNature[_selectedNature]?.first ?? 'General');
      _openingDebitCtrl.text = (editAccount['opening_debit'] ?? '0.00').toString();
      _openingCreditCtrl.text = (editAccount['opening_credit'] ?? '0.00').toString();
    } else {
      _accNameCtrl.clear();
      _accCodeCtrl.clear();
      _selectedNature = 'EXPENSE';
      _selectedGroup = 'Indirect Expenses';
      _openingDebitCtrl.text = '0.00';
      _openingCreditCtrl.text = '0.00';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(isEditing ? Icons.edit_note : Icons.add_chart, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                isEditing ? 'Edit General Ledger Account' : 'Add New Account to COA',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Directly register an account into your Chart of Accounts for vouchers, balance sheets, and tax reports.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _accNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ledger Account Name * (e.g. Office Electricity)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _accCodeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Account Code (Optional)',
                            hintText: 'e.g. 5120',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.numbers),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedNature,
                          decoration: const InputDecoration(
                            labelText: 'Account Nature *',
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: (_groupsByNature[_selectedNature]?.contains(_selectedGroup) ?? false)
                        ? _selectedGroup
                        : (_groupsByNature[_selectedNature]?.first ?? 'General'),
                    decoration: const InputDecoration(
                      labelText: 'Account Group / Sub-Category',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: (_groupsByNature[_selectedNature] ?? ['General'])
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDlgState(() => _selectedGroup = val);
                    },
                  ),
                  if (!isEditing) ...[
                    const SizedBox(height: 12),
                    const Text('Quick Template Presets:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.bolt, size: 14, color: Colors.orange),
                          label: const Text('Electricity & Power', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDlgState(() {
                              _accNameCtrl.text = 'Electricity & Power Utilities';
                              _accCodeCtrl.text = '5110';
                              _selectedNature = 'EXPENSE';
                              _selectedGroup = 'Rent & Utilities';
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.receipt_long, size: 14, color: Colors.red),
                          label: const Text('VAT Payable 16%', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDlgState(() {
                              _accNameCtrl.text = 'VAT Payable 16%';
                              _accCodeCtrl.text = '2100';
                              _selectedNature = 'LIABILITY';
                              _selectedGroup = 'Duties & Taxes';
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.phone_android, size: 14, color: Colors.green),
                          label: const Text('M-Pesa Clearing', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDlgState(() {
                              _accNameCtrl.text = 'M-Pesa Clearing Account';
                              _accCodeCtrl.text = '1010';
                              _selectedNature = 'ASSET';
                              _selectedGroup = 'Bank Accounts';
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.people_outline, size: 14, color: Colors.blue),
                          label: const Text('Staff Salaries', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDlgState(() {
                              _accNameCtrl.text = 'Staff Salaries & Wages';
                              _accCodeCtrl.text = '5200';
                              _selectedNature = 'EXPENSE';
                              _selectedGroup = 'Salaries & Wages';
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _openingDebitCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Opening Debit (${CurrencyService.symbol})',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.arrow_upward, color: Colors.green),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _openingCreditCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Opening Credit (${CurrencyService.symbol})',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.arrow_downward, color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              onPressed: () async {
                final name = _accNameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an account name'), backgroundColor: Colors.red),
                  );
                  return;
                }
                try {
                  final payload = {
                    'account_name': name,
                    'account_code': _accCodeCtrl.text.trim(),
                    'group_name': _selectedGroup,
                    'nature': _selectedNature,
                    'opening_debit': double.tryParse(_openingDebitCtrl.text) ?? 0.0,
                    'opening_credit': double.tryParse(_openingCreditCtrl.text) ?? 0.0,
                    if (widget.outletId != null) 'outlet_id': widget.outletId,
                  };

                  if (isEditing) {
                    await ApiClient.put('${ApiEndpoints.accountingCoa}/${editAccount['id']}', payload);
                  } else {
                    await ApiClient.post(ApiEndpoints.accountingCoa, payload);
                  }

                  if (mounted) {
                    Navigator.pop(ctx);
                    _fetchAccounts();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEditing ? 'Account Updated Successfully!' : 'Account Added to COA Directly!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error saving account: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save account: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: Text(isEditing ? 'Update Account' : 'Save Account', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> acc) async {
    try {
      final res = await ApiClient.post('${ApiEndpoints.accountingCoa}/${acc['id']}/toggle', {});
      if (res['success'] == true) {
        _fetchAccounts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating account status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteAccount(Map<String, dynamic> acc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Account?'),
          ],
        ),
        content: Text('Are you sure you want to delete "${acc['account_name']}" from Chart of Accounts?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await ApiClient.delete('${ApiEndpoints.accountingCoa}/${acc['id']}');
        if (res['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account deleted successfully.'), backgroundColor: Colors.green),
            );
          }
          _fetchAccounts();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete account: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Color _getNatureColor(String nature) {
    switch (nature.toUpperCase()) {
      case 'ASSET':
        return Colors.blue.shade700;
      case 'LIABILITY':
        return Colors.red.shade700;
      case 'EQUITY':
        return Colors.purple.shade700;
      case 'REVENUE':
        return Colors.green.shade700;
      case 'EXPENSE':
        return Colors.orange.shade800;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Chart of Accounts (COA) Direct Management',
          style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: primaryColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: primaryColor),
            onPressed: _fetchAccounts,
            tooltip: 'Refresh Accounts',
          ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high, color: Colors.teal),
            onPressed: _seedDefaultAccounts,
            tooltip: 'Seed / Reset Standard Master Accounts',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        onPressed: () => _showAddAccountDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Account Directly', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Top Filter & Search Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search account name, code, group...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                      _fetchAccounts();
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (val) {
                            setState(() => _searchQuery = val);
                            _fetchAccounts();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onPressed: () {
                          setState(() => _searchQuery = _searchCtrl.text);
                          _fetchAccounts();
                        },
                        icon: const Icon(Icons.search, color: Colors.white, size: 18),
                        label: const Text('Search', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Nature Category Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('ALL', 'All Ledgers (${_accounts.length})'),
                        const SizedBox(width: 6),
                        _buildFilterChip('ASSET', 'Assets'),
                        const SizedBox(width: 6),
                        _buildFilterChip('LIABILITY', 'Liabilities'),
                        const SizedBox(width: 6),
                        _buildFilterChip('EQUITY', 'Equity'),
                        const SizedBox(width: 6),
                        _buildFilterChip('REVENUE', 'Revenue'),
                        const SizedBox(width: 6),
                        _buildFilterChip('EXPENSE', 'Expenses'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Accounts List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _accounts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_wallet_outlined, size: 60, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text(
                                'No accounts found in Chart of Accounts',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'You can add accounts directly or seed standard master accounts.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                                onPressed: _seedDefaultAccounts,
                                icon: const Icon(Icons.auto_fix_high, color: Colors.white),
                                label: const Text('Seed Standard Chart of Accounts', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        )
                      : Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListView.separated(
                            itemCount: _accounts.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final acc = _accounts[index];
                              final nature = (acc['nature'] ?? 'ASSET').toString().toUpperCase();
                              final natureColor = _getNatureColor(nature);
                              final bool isSystem = acc['is_system'] == true;
                              final bool isActive = acc['is_active'] != false;
                              final double debit = double.tryParse((acc['opening_debit'] ?? 0).toString()) ?? 0.0;
                              final double credit = double.tryParse((acc['opening_credit'] ?? 0).toString()) ?? 0.0;
                              final double currentBal = double.tryParse((acc['current_balance'] ?? 0).toString()) ?? 0.0;

                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: natureColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: natureColor.withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    nature,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: natureColor),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    if (acc['account_code'] != null && acc['account_code'].toString().isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          acc['account_code'].toString(),
                                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                    Expanded(
                                      child: Text(
                                        acc['account_name'] ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isActive ? Colors.black87 : Colors.grey,
                                          decoration: isActive ? null : TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ),
                                    if (isSystem)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.teal.shade200),
                                        ),
                                        child: const Text('SYSTEM', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.teal)),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  'Group: ${acc['group_name'] ?? 'General'}  •  Opening: Dr ${CurrencyService.format(debit)} | Cr ${CurrencyService.format(credit)}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          CurrencyService.format(currentBal),
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: currentBal >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                                          ),
                                        ),
                                        Text(
                                          isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(fontSize: 10, color: isActive ? Colors.green : Colors.grey),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 18),
                                      onSelected: (action) {
                                        if (action == 'EDIT') {
                                          _showAddAccountDialog(editAccount: acc);
                                        } else if (action == 'TOGGLE') {
                                          _toggleActive(acc);
                                        } else if (action == 'DELETE') {
                                          _deleteAccount(acc);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'EDIT',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 16, color: Colors.blue),
                                              SizedBox(width: 8),
                                              Text('Edit Account'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'TOGGLE',
                                          child: Row(
                                            children: [
                                              Icon(isActive ? Icons.block : Icons.check_circle, size: 16, color: Colors.orange),
                                              SizedBox(width: 8),
                                              Text(isActive ? 'Mark Inactive' : 'Mark Active'),
                                            ],
                                          ),
                                        ),
                                        if (!isSystem)
                                          const PopupMenuItem(
                                            value: 'DELETE',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete, size: 16, color: Colors.red),
                                                SizedBox(width: 8),
                                                Text('Delete Account'),
                                              ],
                                            ),
                                          ),
                                      ],
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

  Widget _buildFilterChip(String natureKey, String label) {
    final isSelected = _selectedNatureFilter == natureKey;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: primaryColor.withValues(alpha: 0.18),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedNatureFilter = natureKey);
          _fetchAccounts();
        }
      },
    );
  }
}

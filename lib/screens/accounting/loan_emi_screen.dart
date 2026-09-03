import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';

class LoanEmiScreen extends StatefulWidget {
  const LoanEmiScreen({super.key});

  @override
  State<LoanEmiScreen> createState() => _LoanEmiScreenState();
}

class _LoanEmiScreenState extends State<LoanEmiScreen> {
  bool _loading = false;
  List<dynamic> _loans = [];
  List<dynamic> _assets = [];

  final _loanNameCtrl = TextEditingController();
  final _lenderCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _interestRateCtrl = TextEditingController();
  final _tenureCtrl = TextEditingController(text: '12');
  final _emiAmountCtrl = TextEditingController();

  final _assetNameCtrl = TextEditingController();
  final _assetCategoryCtrl = TextEditingController(text: 'FIXED_ASSET');
  final _purchaseCostCtrl = TextEditingController();

  final _payPrincipalCtrl = TextEditingController();
  final _payInterestCtrl = TextEditingController();
  final _payNarrationCtrl = TextEditingController(text: 'Monthly EMI payment');
  String _paymentMode = 'BANK_TRANSFER';

  @override
  void initState() {
    super.initState();
    _fetchLoanAssetsData();
  }

  Future<void> _fetchLoanAssetsData() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get('/api/accounting/loans-assets');
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _loans = (res['data']['loans'] as List? ?? []);
          _assets = (res['data']['assets'] as List? ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error fetching Loan & Asset data: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showAddLoanDialog() {
    _loanNameCtrl.clear();
    _lenderCtrl.clear();
    _principalCtrl.clear();
    _interestRateCtrl.text = '10.5';
    _tenureCtrl.text = '36';
    _emiAmountCtrl.clear();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final messenger = ScaffoldMessenger.of(context);
        final nav = Navigator.of(dialogCtx);
        return AlertDialog(
          title: const Text('Add Active Business Loan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B5CAD))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _loanNameCtrl,
                  decoration: const InputDecoration(labelText: 'Loan Name (e.g. HDFC Business Loan)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _lenderCtrl,
                  decoration: const InputDecoration(labelText: 'Lender / Bank Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _principalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sanctioned Principal Amount (₹)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _interestRateCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Interest Rate (% p.a.)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _tenureCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Tenure (Months)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emiAmountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Monthly EMI Amount (₹)', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => nav.pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5CAD)),
              onPressed: () async {
                final double p = double.tryParse(_principalCtrl.text) ?? 0.0;
                final double emi = double.tryParse(_emiAmountCtrl.text) ?? 0.0;
                if (_loanNameCtrl.text.isEmpty || p <= 0) return;

                try {
                  final res = await ApiClient.post('/api/accounting/loans', {
                    'loan_name': _loanNameCtrl.text,
                    'lender_name': _lenderCtrl.text,
                    'principal_amount': p,
                    'interest_rate': double.tryParse(_interestRateCtrl.text) ?? 0.0,
                    'tenure_months': int.tryParse(_tenureCtrl.text) ?? 12,
                    'monthly_emi': emi,
                    'remaining_principal': p,
                  });
                  nav.pop();
                  if (res['success'] == true) {
                    messenger.showSnackBar(const SnackBar(content: Text('Business Loan Added!'), backgroundColor: Colors.green));
                    _fetchLoanAssetsData();
                  }
                } catch (e) {
                  debugPrint('Add Loan Error: $e');
                }
              },
              child: const Text('Save Loan', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showAddAssetDialog() {
    _assetNameCtrl.clear();
    _assetCategoryCtrl.text = 'FIXED_ASSET';
    _purchaseCostCtrl.clear();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final messenger = ScaffoldMessenger.of(context);
        final nav = Navigator.of(dialogCtx);
        return AlertDialog(
          title: const Text('Add Capital Asset / Infrastructure', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B5CAD))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _assetNameCtrl,
                  decoration: const InputDecoration(labelText: 'Asset Name (e.g. POS Hardware, Furniture)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _assetCategoryCtrl.text,
                  decoration: const InputDecoration(labelText: 'Asset Category', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'FIXED_ASSET', child: Text('Fixed Asset (Infrastructure)')),
                    DropdownMenuItem(value: 'INVESTMENT_SHARES', child: Text('Investment in Other Companies / Shares')),
                    DropdownMenuItem(value: 'PROPERTY_REAL_ESTATE', child: Text('Property & Real Estate Investment')),
                    DropdownMenuItem(value: 'MACHINERY_EQUIPMENT', child: Text('Machinery & POS Equipment')),
                    DropdownMenuItem(value: 'VEHICLE', child: Text('Commercial Vehicle')),
                    DropdownMenuItem(value: 'COMPUTER_HARDWARE', child: Text('Computers & Hardware')),
                  ],
                  onChanged: (val) {
                    if (val != null) _assetCategoryCtrl.text = val;
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _purchaseCostCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Purchase Cost / Valuation (₹)', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => nav.pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5CAD)),
              onPressed: () async {
                final double cost = double.tryParse(_purchaseCostCtrl.text) ?? 0.0;
                if (_assetNameCtrl.text.isEmpty || cost <= 0) return;

                try {
                  final res = await ApiClient.post('/api/accounting/assets', {
                    'asset_name': _assetNameCtrl.text,
                    'asset_category': _assetCategoryCtrl.text,
                    'purchase_cost': cost,
                    'current_value': cost,
                  });
                  nav.pop();
                  if (res['success'] == true) {
                    messenger.showSnackBar(const SnackBar(content: Text('Capital Asset Added!'), backgroundColor: Colors.green));
                    _fetchLoanAssetsData();
                  }
                } catch (e) {
                  debugPrint('Add Asset Error: $e');
                }
              },
              child: const Text('Save Asset', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showPayEmiDialog(dynamic loan) {
    _loanNameCtrl.text = loan != null ? (loan['loan_name'] ?? 'Business Loan') : '';
    final double emiVal = loan != null ? (double.tryParse(loan['monthly_emi'].toString()) ?? 0.0) : 0.0;
    _emiAmountCtrl.text = emiVal > 0 ? emiVal.toStringAsFixed(2) : '';
    _payPrincipalCtrl.text = (emiVal * 0.75).toStringAsFixed(2);
    _payInterestCtrl.text = (emiVal * 0.25).toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final messenger = ScaffoldMessenger.of(context);
          final nav = Navigator.of(dialogCtx);
          return AlertDialog(
            title: const Text('Pay Monthly Loan EMI Installment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B5CAD))),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _loanNameCtrl,
                    decoration: const InputDecoration(labelText: 'Loan Account Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emiAmountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Total EMI Amount (₹)', border: OutlineInputBorder()),
                    onChanged: (val) {
                      final double total = double.tryParse(val) ?? 0.0;
                      setDlgState(() {
                        _payPrincipalCtrl.text = (total * 0.75).toStringAsFixed(2);
                        _payInterestCtrl.text = (total * 0.25).toStringAsFixed(2);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _payPrincipalCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Principal (₹) [Liability]', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _payInterestCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Interest (₹) [Expense]', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _paymentMode,
                    decoration: const InputDecoration(labelText: 'Payment Mode / Bank Account', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'CASH', child: Text('Main Cash Drawer')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => _paymentMode = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _payNarrationCtrl,
                    decoration: const InputDecoration(labelText: 'Remarks / Auto-Debit Note', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => nav.pop(), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5CAD)),
                onPressed: () async {
                  final double total = double.tryParse(_emiAmountCtrl.text) ?? 0.0;
                  final double prin = double.tryParse(_payPrincipalCtrl.text) ?? 0.0;
                  final double inte = double.tryParse(_payInterestCtrl.text) ?? 0.0;

                  try {
                    final res = await ApiClient.post('/api/accounting/loans/pay-emi', {
                      if (loan != null && loan['id'] != null) 'loan_id': loan['id'],
                      'loan_name': _loanNameCtrl.text,
                      'total_emi_amount': total,
                      'principal_amount': prin,
                      'interest_amount': inte,
                      'payment_mode': _paymentMode,
                      'narration': _payNarrationCtrl.text,
                    });
                    nav.pop();
                    if (res['success'] == true) {
                      messenger.showSnackBar(SnackBar(content: Text(res['message'] ?? 'EMI Payment Posted!'), backgroundColor: Colors.green));
                      _fetchLoanAssetsData();
                    }
                  } catch (e) {
                    debugPrint('EMI Post Error: $e');
                  }
                },
                child: const Text('Post EMI Voucher & Debit', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteLoan(int id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ApiClient.delete('/api/accounting/loans/$id');
      if (res['success'] == true) {
        messenger.showSnackBar(const SnackBar(content: Text('Loan Deleted'), backgroundColor: Colors.red));
        _fetchLoanAssetsData();
      }
    } catch (e) {
      debugPrint('Delete Loan Error: $e');
    }
  }

  Future<void> _deleteAsset(int id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ApiClient.delete('/api/accounting/assets/$id');
      if (res['success'] == true) {
        messenger.showSnackBar(const SnackBar(content: Text('Asset Deleted'), backgroundColor: Colors.red));
        _fetchLoanAssetsData();
      }
    } catch (e) {
      debugPrint('Delete Asset Error: $e');
    }
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
          'Capital Assets, Loans & Monthly EMI Master',
          style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: primaryColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: primaryColor),
            onPressed: _fetchLoanAssetsData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Explanation
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_outlined, color: primaryColor, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Capital Investment & Loan Liabilities',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor),
                              ),
                              Text(
                                'Property, Machinery, and Infrastructure are preserved under Capital Assets. Monthly EMIs automatically split into Principal (Liability reduction) and Interest (Operational expense).',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 1: Active Business Loans
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ACTIVE BUSINESS LOANS & EMIs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor)),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: primaryColor),
                            onPressed: _showAddLoanDialog,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Loan', style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                            onPressed: () => _showPayEmiDialog(null),
                            icon: const Icon(Icons.payment, size: 16, color: Colors.white),
                            label: const Text('Pay Loan EMI', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_loans.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.credit_card_off, size: 36, color: Colors.grey),
                              const SizedBox(height: 8),
                              const Text('No Active Business Loans Configured', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _showAddLoanDialog,
                                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                                child: const Text('+ Add Business Loan', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ..._loans.map((l) => Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      l['loan_name'] ?? 'Business Loan',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            border: Border.all(color: Colors.green),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            l['status'] ?? 'ACTIVE',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                          onPressed: () => _deleteLoan(l['id']),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Sanctioned Amount: ₹${l['principal_amount']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        Text('Monthly EMI: ₹${l['monthly_emi']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Interest Rate: ${l['interest_rate']}% p.a.', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        Text('Outstanding: ₹${l['remaining_principal']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )),

                  const SizedBox(height: 24),

                  // Section 2: Capital Assets & Infrastructure
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('CAPITAL ASSETS & INFRASTRUCTURE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor)),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: primaryColor),
                        onPressed: _showAddAssetDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Asset', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_assets.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.domain_disabled, size: 36, color: Colors.grey),
                              const SizedBox(height: 8),
                              const Text('No Capital Assets Configured', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _showAddAssetDialog,
                                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                                child: const Text('+ Add Capital Asset', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: _assets.map((a) => ListTile(
                          leading: const Icon(Icons.domain, color: primaryColor),
                          title: Text(a['asset_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('Category: ${a['asset_category']} • Purchased: ${a['purchase_date']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹${a['purchase_cost']}',
                                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                onPressed: () => _deleteAsset(a['id']),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

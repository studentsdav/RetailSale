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

  final _loanNameCtrl = TextEditingController(text: 'HDFC Business Expansion Loan');
  final _emiAmountCtrl = TextEditingController(text: '16254.00');
  final _principalCtrl = TextEditingController(text: '12500.00');
  final _interestCtrl = TextEditingController(text: '3754.00');
  final _narrationCtrl = TextEditingController(text: 'Monthly EMI payment auto-debit');
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

  void _showPayEmiDialog(dynamic loan) {
    if (loan != null) {
      _loanNameCtrl.text = loan['loan_name'] ?? 'Business Loan';
      _emiAmountCtrl.text = (loan['monthly_emi'] ?? 16254.00).toString();
      final double emiVal = double.tryParse(_emiAmountCtrl.text) ?? 16254.0;
      _principalCtrl.text = (emiVal * 0.75).toStringAsFixed(2);
      _interestCtrl.text = (emiVal * 0.25).toStringAsFixed(2);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text(
            'Pay Monthly Loan EMI Installment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B5CAD)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _loanNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Loan Account Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emiAmountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total EMI Amount (₹)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    final double total = double.tryParse(val) ?? 0.0;
                    setDlgState(() {
                      _principalCtrl.text = (total * 0.75).toStringAsFixed(2);
                      _interestCtrl.text = (total * 0.25).toStringAsFixed(2);
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _principalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Principal (₹) [Liability]',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _interestCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Interest (₹) [Expense]',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _paymentMode,
                  decoration: const InputDecoration(
                    labelText: 'Payment Mode / Bank Account',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('HDFC Bank Transfer')),
                    DropdownMenuItem(value: 'CASH', child: Text('Main Cash Drawer')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => _paymentMode = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _narrationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Remarks / Auto-Debit Note',
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5CAD)),
              onPressed: () async {
                final double total = double.tryParse(_emiAmountCtrl.text) ?? 0.0;
                final double prin = double.tryParse(_principalCtrl.text) ?? 0.0;
                final double inte = double.tryParse(_interestCtrl.text) ?? 0.0;

                try {
                  final res = await ApiClient.post('/api/accounting/loans/pay-emi', {
                    'loan_name': _loanNameCtrl.text,
                    'total_emi_amount': total,
                    'principal_amount': prin,
                    'interest_amount': inte,
                    'payment_mode': _paymentMode,
                    'narration': _narrationCtrl.text,
                  });

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? 'EMI Payment & Voucher Posted!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _fetchLoanAssetsData();
                  }
                } catch (e) {
                  debugPrint('EMI Post Error: $e');
                }
              },
              child: const Text('Post EMI Voucher & Debit', style: TextStyle(color: Colors.white)),
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
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                        onPressed: () => _showPayEmiDialog(null),
                        icon: const Icon(Icons.payment, size: 16, color: Colors.white),
                        label: const Text('Pay Loan EMI', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._loans.map((l) => Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  const Text('CAPITAL ASSETS & INFRASTRUCTURE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor)),
                  const SizedBox(height: 10),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: _assets.map((a) => ListTile(
                        leading: const Icon(Icons.domain, color: primaryColor),
                        title: Text(a['asset_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('Category: ${a['asset_category']} • Purchased: ${a['purchase_date']}'),
                        trailing: Text(
                          '₹${a['purchase_cost']}',
                          style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
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

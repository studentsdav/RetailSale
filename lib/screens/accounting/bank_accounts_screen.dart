import 'package:flutter/material.dart';
import '../../controllers/accounting/bank_account_controller.dart';

class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  final BankAccountController ctrl = BankAccountController();

  final _bankNameCtrl = TextEditingController();
  final _accNameCtrl = TextEditingController();
  final _accNoCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _openingCtrl = TextEditingController(text: '0.00');

  @override
  void initState() {
    super.initState();
    ctrl.fetchBanks();
  }

  void _showAddBankDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Company Bank Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B5CAD))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _bankNameCtrl,
                decoration: const InputDecoration(labelText: 'Bank Name (e.g. HDFC Bank)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _accNameCtrl,
                decoration: const InputDecoration(labelText: 'Account Name (e.g. Main Current A/c)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _accNoCtrl,
                decoration: const InputDecoration(labelText: 'Account Number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _ifscCtrl,
                decoration: const InputDecoration(labelText: 'IFSC / SWIFT Code', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _branchCtrl,
                decoration: const InputDecoration(labelText: 'Branch Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _openingCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Opening Balance (₹)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5CAD)),
            onPressed: () async {
              final ok = await ctrl.createBank(
                bankName: _bankNameCtrl.text,
                accountName: _accNameCtrl.text,
                accountNumber: _accNoCtrl.text,
                ifscCode: _ifscCtrl.text,
                branchName: _branchCtrl.text,
                openingBalance: double.tryParse(_openingCtrl.text) ?? 0.0,
              );
              if (mounted) {
                Navigator.pop(context);
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bank Account Added Successfully!'), backgroundColor: Colors.green),
                  );
                }
              }
            },
            child: const Text('Save Bank Account', style: TextStyle(color: Colors.white)),
          ),
        ],
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
        title: const Text('Company Bank Accounts Master', style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        onPressed: _showAddBankDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Bank Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          if (ctrl.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (ctrl.banks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_balance, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No Bank Accounts Configured Yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _showAddBankDialog,
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                    child: const Text('+ Add Bank Account', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView.builder(
              itemCount: ctrl.banks.length,
              itemBuilder: (context, index) {
                final b = ctrl.banks[index];
                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.account_balance, color: primaryColor),
                    ),
                    title: Text(b.bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Text('${b.accountName} • A/c: ${b.accountNumber} • IFSC: ${b.ifscCode ?? 'N/A'}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${b.currentBalance.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor, fontFamily: 'monospace')),
                        const Text('Live Balance', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

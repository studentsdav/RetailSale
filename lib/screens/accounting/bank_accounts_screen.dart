import 'package:flutter/material.dart';
import '../../controllers/accounting/bank_account_controller.dart';
import '../../models/accounting/bank_account_model.dart';

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

  void _clearForm() {
    _bankNameCtrl.clear();
    _accNameCtrl.clear();
    _accNoCtrl.clear();
    _ifscCtrl.clear();
    _branchCtrl.clear();
    _openingCtrl.text = '0.00';
  }

  void _showAddBankDialog() {
    _clearForm();
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final messenger = ScaffoldMessenger.of(context);
        final nav = Navigator.of(dialogCtx);
        return AlertDialog(
          title: const Text('Add Company Bank Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B5CAD))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _bankNameCtrl,
                  decoration: const InputDecoration(labelText: 'Bank Name (e.g. SBI, HDFC)', border: OutlineInputBorder()),
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
              onPressed: () => nav.pop(),
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
                nav.pop();
                if (ok) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Bank Account Added Successfully!'), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('Save Bank Account', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showEditBankDialog(BankAccountModel bank) {
    _bankNameCtrl.text = bank.bankName;
    _accNameCtrl.text = bank.accountName;
    _accNoCtrl.text = bank.accountNumber;
    _ifscCtrl.text = bank.ifscCode ?? '';
    _branchCtrl.text = bank.branchName ?? '';
    _openingCtrl.text = bank.openingBalance.toStringAsFixed(2);
    final canEditOpening = bank.currentBalance == bank.openingBalance;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final messenger = ScaffoldMessenger.of(context);
        final nav = Navigator.of(dialogCtx);
        return AlertDialog(
          title: const Text('Edit Bank Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B5CAD))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _bankNameCtrl,
                  decoration: const InputDecoration(labelText: 'Bank Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _accNameCtrl,
                  decoration: const InputDecoration(labelText: 'Account Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _accNoCtrl,
                  decoration: const InputDecoration(labelText: 'Account Number', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _ifscCtrl,
                  decoration: const InputDecoration(labelText: 'IFSC Code', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _branchCtrl,
                  decoration: const InputDecoration(labelText: 'Branch Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _openingCtrl,
                  enabled: canEditOpening,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Opening Balance (₹)',
                    border: const OutlineInputBorder(),
                    helperText: canEditOpening ? 'Editable (No transactions linked)' : 'Locked (Transactions exist for this account)',
                    helperStyle: TextStyle(color: canEditOpening ? Colors.green.shade800 : Colors.red.shade800, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => nav.pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5CAD)),
              onPressed: () async {
                final ok = await ctrl.updateBank(
                  id: bank.id,
                  bankName: _bankNameCtrl.text,
                  accountName: _accNameCtrl.text,
                  accountNumber: _accNoCtrl.text,
                  ifscCode: _ifscCtrl.text,
                  branchName: _branchCtrl.text,
                  openingBalance: canEditOpening ? (double.tryParse(_openingCtrl.text) ?? bank.openingBalance) : bank.openingBalance,
                );
                nav.pop();
                if (ok) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Bank Account Updated!'), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('Update Account', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
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
                  elevation: b.isPrimary ? 3 : 1,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: b.isPrimary ? const BorderSide(color: Colors.green, width: 1.5) : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: b.isPrimary ? Colors.green.shade50 : primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.account_balance,
                            color: b.isPrimary ? Colors.green.shade800 : primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(b.bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  if (b.isPrimary) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'PRIMARY',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                                      ),
                                    ),
                                  ],
                                  if (!b.isActive) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'INACTIVE',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('${b.accountName} • A/c: ${b.accountNumber} • IFSC: ${b.ifscCode ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${b.currentBalance.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor, fontFamily: 'monospace'),
                            ),
                            const Text('Live Balance', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                        PopupMenuButton<String>(
                          onSelected: (val) async {
                            final messenger = ScaffoldMessenger.of(context);
                            if (val == 'edit') {
                              _showEditBankDialog(b);
                            } else if (val == 'primary') {
                              final ok = await ctrl.setPrimaryBank(b.id);
                              if (ok) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('${b.bankName} set as Primary Account'), backgroundColor: Colors.green),
                                );
                              }
                            } else if (val == 'toggle') {
                              final ok = await ctrl.toggleBankActive(b.id);
                              if (ok) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('${b.bankName} status updated'), backgroundColor: Colors.blue),
                                );
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18, color: primaryColor),
                                  SizedBox(width: 8),
                                  Text('Edit Account Details'),
                                ],
                              ),
                            ),
                            if (!b.isPrimary)
                              const PopupMenuItem(
                                value: 'primary',
                                child: Row(
                                  children: [
                                    Icon(Icons.star, size: 18, color: Colors.amber),
                                    SizedBox(width: 8),
                                    Text('Set as Primary Account'),
                                  ],
                                ),
                              ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Row(
                                children: [
                                  Icon(b.isActive ? Icons.block : Icons.check_circle, size: 18, color: b.isActive ? Colors.red : Colors.green),
                                  const SizedBox(width: 8),
                                  Text(b.isActive ? 'Mark as Inactive' : 'Mark as Active'),
                                ],
                              ),
                            ),
                          ],
                        ),
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

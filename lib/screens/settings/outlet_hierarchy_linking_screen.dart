import 'package:flutter/material.dart';
import '../../controllers/inventory/stock_transfer_controller.dart';
import '../inventory/stock_dispatch_screen.dart';
import '../reports/transfer_progress_dashboard_screen.dart';

class OutletHierarchyLinkingScreen extends StatefulWidget {
  const OutletHierarchyLinkingScreen({super.key});

  @override
  State<OutletHierarchyLinkingScreen> createState() => _OutletHierarchyLinkingScreenState();
}

class _OutletHierarchyLinkingScreenState extends State<OutletHierarchyLinkingScreen> {
  final StockTransferController _transferCtrl = StockTransferController();

  bool _isLoading = true;
  Map<String, dynamic>? _currentOutlet;
  Map<String, dynamic>? _masterOutlet;
  List<dynamic> _childOutlets = [];
  bool _shareContactInfo = true;

  @override
  void initState() {
    super.initState();
    _loadHierarchy();
  }

  Future<void> _loadHierarchy() async {
    setState(() => _isLoading = true);
    final data = await _transferCtrl.fetchHierarchy();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (data != null) {
          _currentOutlet = data['current_outlet'];
          _masterOutlet = data['master_outlet'];
          _childOutlets = data['child_outlets'] ?? data['linked_child_outlets'] ?? [];
          if (data['share_contact_info'] != null) {
            _shareContactInfo = Boolean(data['share_contact_info']);
          }
        }
      });
    }
  }

  bool Boolean(dynamic val) {
    if (val is bool) return val;
    if (val is int) return val == 1;
    return val.toString().toLowerCase() == 'true';
  }

  void _showLinkExistingOutletDialog() {
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final otpCtrl = TextEditingController();

    String linkMethod = 'PIN'; // 'PIN' or 'OTP'
    bool isRequestingOtp = false;
    bool isOtpSent = false;
    String? otpHintMessage;
    bool isLinking = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.link, color: Colors.blue),
                const SizedBox(width: 10),
                Text('Link Existing Outlet (${linkMethod == 'PIN' ? 'PIN' : 'OTP'})'),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'PIN',
                            label: Text('Recovery PIN'),
                            icon: Icon(Icons.pin),
                          ),
                          ButtonSegment(
                            value: 'OTP',
                            label: Text('OTP Code'),
                            icon: Icon(Icons.sms),
                          ),
                        ],
                        selected: {linkMethod},
                        onSelectionChanged: (Set<String> newSelection) {
                          setDialogState(() {
                            linkMethod = newSelection.first;
                            otpHintMessage = null;
                            isOtpSent = false;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        linkMethod == 'PIN'
                            ? 'Enter target outlet code and its 4-digit Recovery PIN setup during registration to link under this Master Outlet.'
                            : 'Enter target outlet code to send a 6-digit verification OTP to its registered mobile/email.',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Target Outlet Code (e.g. OUTLET202604212159)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.store),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Target Outlet Code is required' : null,
                      ),
                      const SizedBox(height: 14),
                      if (linkMethod == 'PIN') ...[
                        TextFormField(
                          controller: pinCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Recovery PIN / Supervisor PIN',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'PIN is required' : null,
                        ),
                      ] else ...[
                        if (!isOtpSent) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: isRequestingOtp
                                  ? null
                                  : () async {
                                      if (codeCtrl.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please enter Target Outlet Code first')),
                                        );
                                        return;
                                      }
                                      setDialogState(() => isRequestingOtp = true);

                                      final res = await _transferCtrl.requestLinkOtp(
                                        targetOutletCode: codeCtrl.text.trim(),
                                      );

                                      if (mounted) {
                                        setDialogState(() {
                                          isRequestingOtp = false;
                                          if (res['success'] == true) {
                                            isOtpSent = true;
                                            otpHintMessage = res['message'] ?? 'OTP sent to registered phone/email. Please enter the 6-digit code received.';
                                            otpCtrl.clear();
                                          } else {
                                            otpHintMessage = res['message'] ?? 'Failed to send OTP.';
                                          }
                                        });
                                      }
                                    },
                              icon: isRequestingOtp
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.send),
                              label: const Text('Send Verification OTP'),
                            ),
                          ),
                        ],
                        if (otpHintMessage != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isOtpSent ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isOtpSent ? Colors.green.shade200 : Colors.red.shade200),
                            ),
                            child: Text(
                              otpHintMessage!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isOtpSent ? Colors.green.shade900 : Colors.red.shade900,
                              ),
                            ),
                          ),
                        ],
                        if (isOtpSent) ...[
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: otpCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '6-Digit Verification OTP',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.security),
                            ),
                            validator: (v) => (v == null || v.trim().length < 4) ? 'Enter valid OTP' : null,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton.icon(
                onPressed: isLinking
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        if (linkMethod == 'OTP' && !isOtpSent) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please request OTP first')),
                          );
                          return;
                        }

                        setDialogState(() => isLinking = true);

                        Map<String, dynamic> res;
                        if (linkMethod == 'PIN') {
                          res = await _transferCtrl.linkOutletByPin(
                            targetOutletCode: codeCtrl.text.trim(),
                            pin: pinCtrl.text.trim(),
                            masterOutletId: _currentOutlet?['id'],
                          );
                        } else {
                          res = await _transferCtrl.verifyLinkOtp(
                            targetOutletCode: codeCtrl.text.trim(),
                            otp: otpCtrl.text.trim(),
                            masterOutletId: _currentOutlet?['id'],
                          );
                        }

                        if (mounted) {
                          Navigator.pop(ctx);
                          if (res['success'] == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(res['message'] ?? 'Outlet linked successfully!')),
                            );
                            _loadHierarchy();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(res['message'] ?? 'Verification or linking failed.')),
                            );
                          }
                        }
                      },
                icon: isLinking
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.link),
                label: Text(linkMethod == 'PIN' ? 'Verify PIN & Link' : 'Verify OTP & Link'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Master & Child Outlet Linking'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHierarchy),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Action Navigation Cards
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: const Color(0xFFEFF6FF),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.swap_horiz, color: Colors.blue, size: 28),
                                  SizedBox(width: 12),
                                  Text(
                                    'Inter-Outlet Stock Dispatch & Progress Quick Actions',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const StockDispatchScreen()),
                                    ),
                                    icon: const Icon(Icons.local_shipping),
                                    label: const Text('Dispatch Stock to Child Outlet'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const TransferProgressDashboardScreen()),
                                    ),
                                    icon: const Icon(Icons.analytics),
                                    label: const Text('Transfer Progress Dashboard'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card 2: Contact Info Sharing Privacy Toggle Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: Colors.white,
                        child: SwitchListTile(
                          value: _shareContactInfo,
                          onChanged: (val) async {
                            setState(() => _shareContactInfo = val);
                            final success = await _transferCtrl.toggleContactSharing(val);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'Contact info sharing ${val ? 'enabled' : 'disabled'}!'
                                        : 'Failed to update contact sharing setting',
                                  ),
                                ),
                              );
                            }
                          },
                          secondary: CircleAvatar(
                            backgroundColor: _shareContactInfo ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                            child: Icon(
                              Icons.contacts_outlined,
                              color: _shareContactInfo ? Colors.green : Colors.grey,
                            ),
                          ),
                          title: const Text(
                            'Share Contact Info Across Linked Outlets',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: const Text(
                            'Allows linked master and branch outlets to view each other\'s contact phone, email, and store details in dashboard directory.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Linked Child Outlets Header & Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Linked Child Outlets', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              Text(
                                _currentOutlet?['parent_outlet_id'] != null
                                    ? 'Store: ${_currentOutlet?['outlet_name'] ?? 'Current Store'} (${_currentOutlet?['outlet_code'] ?? ''}) | Linked under: ${_masterOutlet?['outlet_name'] ?? 'Parent Store'}'
                                    : 'Master Store: ${_currentOutlet?['outlet_name'] ?? 'Current Store'} (${_currentOutlet?['outlet_code'] ?? ''})',
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                          FilledButton.icon(
                            onPressed: _showLinkExistingOutletDialog,
                            icon: const Icon(Icons.link),
                            label: const Text('Link Existing Outlet (PIN / OTP)'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Linked Child Outlets List Card
                      _childOutlets.isEmpty
                          ? Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const Icon(Icons.link_off, size: 48, color: Colors.grey),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No Child Outlets Currently Linked',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Click "Link Existing Outlet (PIN / OTP)" to link child outlets under ${_currentOutlet?['outlet_name'] ?? 'this store'}.',
                                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      FilledButton.icon(
                                        onPressed: _showLinkExistingOutletDialog,
                                        icon: const Icon(Icons.link),
                                        label: const Text('Link Outlet (PIN / OTP)'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _childOutlets.length,
                                separatorBuilder: (_, __) => const Divider(),
                                itemBuilder: (context, index) {
                                  final outlet = _childOutlets[index];
                                  final phone = outlet['contact_phone'] ?? '';
                                  final email = outlet['contact_email'] ?? '';

                                  return ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0xFFE0F2FE),
                                      child: Icon(Icons.store, color: Color(0xFF0284C7)),
                                    ),
                                    title: Text(
                                      '${outlet['outlet_name']} (${outlet['outlet_code']})',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Role: CHILD BRANCH OUTLET | Module: ${outlet['business_module'] ?? "ALL"}'),
                                        if (phone.toString().isNotEmpty || email.toString().isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Contact: ${phone.toString().isNotEmpty ? phone : "N/A"} | Email: ${email.toString().isNotEmpty ? email : "N/A"}',
                                            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'LINKED',
                                            style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.link_off, color: Colors.red, size: 20),
                                          tooltip: 'Unlink Outlet',
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Unlink Outlet'),
                                                content: Text('Are you sure you want to unlink ${outlet['outlet_name']} (${outlet['outlet_code']})?'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                  FilledButton(
                                                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                                    onPressed: () => Navigator.pop(ctx, true),
                                                    child: const Text('Unlink'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              final res = await _transferCtrl.unlinkOutlet(targetOutletId: outlet['id']);
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(res['message'] ?? 'Unlinked outlet')),
                                                );
                                                _loadHierarchy();
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

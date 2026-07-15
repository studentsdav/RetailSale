import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';

class LuckyDrawCampaignScreen extends StatefulWidget {
  const LuckyDrawCampaignScreen({super.key});

  @override
  State<LuckyDrawCampaignScreen> createState() => _LuckyDrawCampaignScreenState();
}

class _LuckyDrawCampaignScreenState extends State<LuckyDrawCampaignScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  dynamic _activeCampaign;
  Map<String, dynamic>? _activeStats;
  List<dynamic> _campaignHistory = [];

  // Winner selection animation states
  bool _isDrawing = false;
  String _animatingVoucherText = '';
  Timer? _drawAnimationTimer;
  Map<String, dynamic>? _winnerResult;

  final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  @override
  void initState() {
    super.initState();
    _loadCampaignData();
  }

  @override
  void dispose() {
    _drawAnimationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCampaignData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch active campaign
      final activeRes = await ApiClient.get('/api/lucky-draw/campaigns/active');
      if (activeRes['success'] == true && activeRes['data'] != null) {
        _activeCampaign = activeRes['data'];
        
        // 2. Fetch stats for active campaign
        final statsRes = await ApiClient.get('/api/lucky-draw/campaigns/${_activeCampaign['id']}/stats');
        if (statsRes['success'] == true) {
          _activeStats = statsRes['data'];
        }
      } else {
        _activeCampaign = null;
        _activeStats = null;
      }

      // 3. Fetch all campaigns for history
      final historyRes = await ApiClient.get('/api/lucky-draw/campaigns');
      if (historyRes['success'] == true && historyRes['data'] != null) {
        final List<dynamic> all = historyRes['data'];
        _campaignHistory = all.where((c) => c['status'] == 'COMPLETED').toList();
      }
    } catch (e) {
      debugPrint('[LUCKY DRAW SCREEN LOAD ERROR] $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Blinking effect for pending draw status
  Widget _buildBlinkingStatusBadge(String status) {
    final isPending = status == 'PENDING_RESULT';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPending ? Colors.amber.shade100 : Colors.green.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isPending ? Colors.amber.shade400 : Colors.green.shade400),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPending) ...[
            const _BlinkingDot(),
            const SizedBox(width: 6),
          ],
          Text(
            isPending ? 'PENDING RESULT' : 'ACTIVE',
            style: TextStyle(
              color: isPending ? Colors.amber.shade900 : Colors.green.shade900,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerWinnerDraw() async {
    if (_activeCampaign == null) return;
    setState(() {
      _isDrawing = true;
      _winnerResult = null;
    });

    // Run custom slot machine/raffle animation
    int counter = 0;
    _drawAnimationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        final randDigits = (100 + (100 * (counter % 9))).toString();
        _animatingVoucherText = 'LD-TMP${counter}-${randDigits}';
      });
      counter++;
      if (counter > 25) {
        timer.cancel();
        _finalizeWinnerDraw();
      }
    });
  }

  Future<void> _finalizeWinnerDraw() async {
    try {
      final res = await ApiClient.post('/api/lucky-draw/campaigns/${_activeCampaign['id']}/draw', {});
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _winnerResult = res['data'];
          _animatingVoucherText = _winnerResult!['voucher_code'];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to draw a winner.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error drawing winner: $e')),
      );
    } finally {
      setState(() => _isDrawing = false);
      _loadCampaignData();
    }
  }

  void _showCompleteAndResetDialog() {
    final nextNameCtrl = TextEditingController(text: 'Diwali Mega Draw Part II');
    final nextThresholdCtrl = TextEditingController(text: '2000');
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.autorenew_outlined, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Complete & Start Campaign'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'This action will complete the current campaign and automatically initialize a new campaign, resetting customer spend counters.',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nextNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Next Campaign Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nextThresholdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Ticket Purchase Threshold (INR)',
                        border: OutlineInputBorder(),
                        prefixText: '₹',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      title: const Text('Draw Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      subtitle: Text(
                        DateFormat('dd-MMM-yyyy').format(selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      trailing: const Icon(Icons.calendar_today, color: Colors.blue),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (nextNameCtrl.text.trim().isEmpty || nextThresholdCtrl.text.trim().isEmpty) {
                      return;
                    }
                    try {
                      final res = await ApiClient.post('/api/lucky-draw/campaigns/${_activeCampaign['id']}/complete', {
                        'next_campaign_name': nextNameCtrl.text.trim(),
                        'next_threshold_amount': double.tryParse(nextThresholdCtrl.text) ?? 2000.0,
                        'next_draw_date': selectedDate.toIso8601String(),
                      });
                      if (res['success'] == true) {
                        Navigator.pop(dialogContext);
                        _loadCampaignData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Campaign completed and reset successfully.')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error resetting campaign: $e')),
                      );
                    }
                  },
                  child: const Text('Complete & Start'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNewCampaignDialog() {
    final nameCtrl = TextEditingController(text: 'Diwali Mega Draw');
    final thresholdCtrl = TextEditingController(text: '2000');
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.add_circle_outline, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Start First Campaign'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Campaign Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: thresholdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Ticket Purchase Threshold (INR)',
                        border: OutlineInputBorder(),
                        prefixText: '₹',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      title: const Text('Draw Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      subtitle: Text(
                        DateFormat('dd-MMM-yyyy').format(selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      trailing: const Icon(Icons.calendar_today, color: Colors.blue),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty || thresholdCtrl.text.trim().isEmpty) {
                      return;
                    }
                    try {
                      final res = await ApiClient.post('/api/lucky-draw/campaigns', {
                        'name': nameCtrl.text.trim(),
                        'threshold_amount': double.tryParse(thresholdCtrl.text) ?? 2000.0,
                        'draw_date': selectedDate.toIso8601String(),
                      });
                      if (res['success'] == true) {
                        Navigator.pop(dialogContext);
                        _loadCampaignData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Campaign initialized successfully.')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error starting campaign: $e')),
                      );
                    }
                  },
                  child: const Text('Start Campaign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildKPI(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lucky Draw Campaigns'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadCampaignData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;
                
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // IF NO ACTIVE CAMPAIGN
                      if (_activeCampaign == null)
                        Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 500),
                            margin: const EdgeInsets.only(top: 60),
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 6)),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.confirmation_number_outlined, size: 56, color: Colors.blue.shade600),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'No Active Raffle Campaign',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Reward customer visits by setting a spending threshold. Crossing the threshold grants raffle tickets to customers directly on their printed bills.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black54, fontSize: 14, height: 1.5),
                                ),
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: FilledButton.icon(
                                    onPressed: _showNewCampaignDialog,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Start First Campaign', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        // KPI ROW
                        Flex(
                          direction: isWide ? Axis.horizontal : Axis.vertical,
                          children: [
                            Expanded(
                              flex: isWide ? 1 : 0,
                              child: _buildKPI(
                                'Total Revenue Driven',
                                _inr.format(_asDouble(_activeStats?['total_revenue'])),
                                Icons.payments_outlined,
                                const Color(0xFF10B981),
                              ),
                            ),
                            if (!isWide) const SizedBox(height: 12),
                            if (isWide) const SizedBox(width: 12),
                            Expanded(
                              flex: isWide ? 1 : 0,
                              child: _buildKPI(
                                'Tickets Generated',
                                (_activeStats?['total_tickets'] ?? 0).toString(),
                                Icons.confirmation_number_outlined,
                                const Color(0xFF3B82F6),
                              ),
                            ),
                            if (!isWide) const SizedBox(height: 12),
                            if (isWide) const SizedBox(width: 12),
                            Expanded(
                              flex: isWide ? 1 : 0,
                              child: _buildKPI(
                                'Participating Customers',
                                (_activeStats?['participating_customers'] ?? 0).toString(),
                                Icons.people_outline,
                                const Color(0xFF8B5CF6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ACTIVE CAMPAIGN DETAILS & DRAW PANEL
                        Flex(
                          direction: isWide ? Axis.horizontal : Axis.vertical,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // LEFT: Campaign Info Card
                            Expanded(
                              flex: isWide ? 4 : 0,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Campaign Configurations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                        _buildBlinkingStatusBadge(_activeCampaign['status']),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _activeCampaign['name'],
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                                    ),
                                    const SizedBox(height: 16),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    _detailRow('Raffle Threshold', 'Spend ${_inr.format(_asDouble(_activeCampaign['threshold_amount']))} per ticket'),
                                    _detailRow('Start Date', DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.parse(_activeCampaign['start_date']))),
                                    _detailRow('Draw Date / Deadline', DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.parse(_activeCampaign['draw_date']))),
                                  ],
                                ),
                              ),
                            ),
                            if (!isWide) const SizedBox(height: 16),
                            if (isWide) const SizedBox(width: 16),

                            // RIGHT: Pick Winner Panel
                            Expanded(
                              flex: isWide ? 5 : 0,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Raffle Draw Panel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    const SizedBox(height: 16),
                                    
                                    // Blinking text or animation container
                                    Container(
                                      height: 130,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Center(
                                        child: _isDrawing
                                            ? Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const SizedBox(
                                                    width: 32,
                                                    height: 32,
                                                    child: CircularProgressIndicator(strokeWidth: 3),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    _animatingVoucherText,
                                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                                  ),
                                                ],
                                              )
                                            : _activeCampaign['winner'] != null
                                                ? Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        _activeCampaign['winner']['voucher_code'],
                                                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 1),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        'Winner: ${_activeCampaign['winner']['customer_name'] ?? "Walk-in"} (${_activeCampaign['winner']['customer_phone']})',
                                                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                                                      ),
                                                    ],
                                                  )
                                                : const Text(
                                                    'No Winner Drawn Yet',
                                                    style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
                                                  ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 48,
                                            child: OutlinedButton.icon(
                                              onPressed: _isDrawing ? null : _triggerWinnerDraw,
                                              icon: const Icon(Icons.casino),
                                              label: Text(_activeCampaign['winner'] != null ? 'Re-draw Winner' : 'Pick Random Winner'),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: Colors.blue),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (_activeCampaign['status'] == 'PENDING_RESULT' || _activeCampaign['winner'] != null) ...[
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: SizedBox(
                                              height: 48,
                                              child: FilledButton.icon(
                                                onPressed: _isDrawing ? null : _showCompleteAndResetDialog,
                                                icon: const Icon(Icons.check_circle_outline),
                                                label: const Text('Complete & Start Next'),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // CAMPAIGN HISTORY
                      const SizedBox(height: 28),
                      const Text(
                        'Campaign History',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: _campaignHistory.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(
                                  child: Text(
                                    'No completed campaigns in history.',
                                    style: TextStyle(color: Colors.grey, fontSize: 14),
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                                  columns: const [
                                    DataColumn(label: Text('Campaign Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Threshold', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Duration', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Winner Code', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Winner Name & Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: _campaignHistory.map((c) {
                                    final winnerCode = c['winner']?['voucher_code'] ?? '--';
                                    final winnerDetails = c['winner'] != null
                                        ? '${c['winner']['customer_name'] ?? "Walk-in"} (${c['winner']['customer_phone']})'
                                        : '--';
                                    final duration = '${DateFormat('dd-MMM-yy').format(DateTime.parse(c['start_date']))} to ${DateFormat('dd-MMM-yy').format(DateTime.parse(c['draw_date']))}';
                                    
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(c['name'], style: const TextStyle(fontWeight: FontWeight.w600))),
                                        DataCell(Text('₹${_asDouble(c['threshold_amount']).toStringAsFixed(0)}')),
                                        DataCell(Text(duration)),
                                        DataCell(Text(winnerCode, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                                        DataCell(Text(winnerDetails)),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}

// Blinking Dot Widget for Pending Result Status
class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

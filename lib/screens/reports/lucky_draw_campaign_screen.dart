import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../core/api/api_client.dart';

class LuckyDrawCampaignScreen extends StatefulWidget {
  const LuckyDrawCampaignScreen({super.key});

  @override
  State<LuckyDrawCampaignScreen> createState() => _LuckyDrawCampaignScreenState();
}

class _LuckyDrawCampaignScreenState extends State<LuckyDrawCampaignScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  dynamic _activeCampaign;
  Map<String, dynamic>? _activeStats;
  List<dynamic> _activeParticipants = [];
  List<dynamic> _filteredParticipants = [];
  List<dynamic> _activeSalesTrend = [];
  List<dynamic> _campaignHistory = [];

  // Selected completed campaign details
  dynamic _selectedCompletedCampaign;
  Map<String, dynamic>? _completedStats;
  List<dynamic> _completedParticipants = [];
  List<dynamic> _completedFilteredParticipants = [];
  List<dynamic> _completedSalesTrend = [];

  // Search filters
  final TextEditingController _activeSearchCtrl = TextEditingController();
  final TextEditingController _completedSearchCtrl = TextEditingController();

  // Drawing Winner Animation states
  bool _isDrawing = false;
  String _animatingVoucherText = '';
  Timer? _drawAnimationTimer;
  Map<String, dynamic>? _winnerResult;

  final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadCampaignData();
    _activeSearchCtrl.addListener(_filterActiveParticipants);
    _completedSearchCtrl.addListener(_filterCompletedParticipants);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _drawAnimationTimer?.cancel();
    _activeSearchCtrl.dispose();
    _completedSearchCtrl.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.index == 1 && _campaignHistory.isNotEmpty && _selectedCompletedCampaign == null) {
      _selectCompletedCampaign(_campaignHistory.first);
    }
  }

  Future<void> _loadCampaignData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch active campaign
      final activeRes = await ApiClient.get('/api/lucky-draw/campaigns/active');
      if (activeRes['success'] == true && activeRes['data'] != null) {
        _activeCampaign = activeRes['data'];
        
        // 2. Fetch stats, participants, sales-trend for active campaign
        final id = _activeCampaign['id'];
        final statsRes = await ApiClient.get('/api/lucky-draw/campaigns/$id/stats');
        final participantsRes = await ApiClient.get('/api/lucky-draw/campaigns/$id/participants');
        final trendRes = await ApiClient.get('/api/lucky-draw/campaigns/$id/sales-trend');

        if (statsRes['success'] == true) _activeStats = statsRes['data'];
        if (participantsRes['success'] == true) {
          _activeParticipants = participantsRes['data'] ?? [];
          _filteredParticipants = List.from(_activeParticipants);
        }
        if (trendRes['success'] == true) _activeSalesTrend = trendRes['data'] ?? [];
      } else {
        _activeCampaign = null;
        _activeStats = null;
        _activeParticipants = [];
        _filteredParticipants = [];
        _activeSalesTrend = [];
      }

      // 3. Fetch completed campaigns
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

  Future<void> _selectCompletedCampaign(dynamic campaign) async {
    setState(() {
      _selectedCompletedCampaign = campaign;
      _completedStats = null;
      _completedParticipants = [];
      _completedFilteredParticipants = [];
      _completedSalesTrend = [];
    });

    try {
      final id = campaign['id'];
      final statsRes = await ApiClient.get('/api/lucky-draw/campaigns/$id/stats');
      final participantsRes = await ApiClient.get('/api/lucky-draw/campaigns/$id/participants');
      final trendRes = await ApiClient.get('/api/lucky-draw/campaigns/$id/sales-trend');

      if (statsRes['success'] == true) _completedStats = statsRes['data'];
      if (participantsRes['success'] == true) {
        _completedParticipants = participantsRes['data'] ?? [];
        _completedFilteredParticipants = List.from(_completedParticipants);
      }
      if (trendRes['success'] == true) _completedSalesTrend = trendRes['data'] ?? [];
    } catch (e) {
      debugPrint('[LUCKY DRAW COMPLETED SELECTION ERROR] $e');
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _filterActiveParticipants() {
    final query = _activeSearchCtrl.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredParticipants = List.from(_activeParticipants);
      } else {
        _filteredParticipants = _activeParticipants.where((p) {
          final name = (p['customer_name'] ?? '').toString().toLowerCase();
          final phone = (p['customer_phone'] ?? '').toString().toLowerCase();
          return name.contains(query) || phone.contains(query);
        }).toList();
      }
    });
  }

  void _filterCompletedParticipants() {
    final query = _completedSearchCtrl.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _completedFilteredParticipants = List.from(_completedParticipants);
      } else {
        _completedFilteredParticipants = _completedParticipants.where((p) {
          final name = (p['customer_name'] ?? '').toString().toLowerCase();
          final phone = (p['customer_phone'] ?? '').toString().toLowerCase();
          return name.contains(query) || phone.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _triggerWinnerDraw() async {
    if (_activeCampaign == null) return;
    setState(() {
      _isDrawing = true;
      _winnerResult = null;
    });

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

        // Show a premium winner award modal dialogue
        _showWinnerModal(_winnerResult!);
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

  void _showWinnerModal(Map<String, dynamic> winner) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.emoji_events, size: 72, color: Colors.green.shade600),
              ),
              const SizedBox(height: 24),
              const Text(
                'CONGRATULATIONS!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Winning Raffle Coupon Code:',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  winner['voucher_code'] ?? 'LD-XXXX-XXX',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 24),
              _winnerDetailRow('Winner Name', winner['customer_name'] ?? 'Walk-in'),
              _winnerDetailRow('Mobile Number', winner['customer_phone'] ?? '--'),
              _winnerDetailRow('Address', winner['customer_address'] ?? 'No address registered'),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close & View Results', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _winnerDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _showCompleteAndResetDialog() {
    final nextNameCtrl = TextEditingController(text: 'Diwali Mega Draw Part II');
    final nextThresholdCtrl = TextEditingController(text: '2000');
    final nextDescriptionCtrl = TextEditingController(text: 'Win pressure cooker, cup, mug, or more!');
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));
    bool startNextCampaign = true;
    bool nextAllowCreditors = false;

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
                  Text('Complete Campaign'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'This action will complete the current campaign and reset customer spend counters.',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: startNextCampaign,
                          onChanged: (val) {
                            setDialogState(() => startNextCampaign = val ?? false);
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Initialize next campaign immediately',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    if (startNextCampaign) ...[
                      const SizedBox(height: 12),
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
                      TextField(
                        controller: nextDescriptionCtrl,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'Next Campaign Description',
                          border: OutlineInputBorder(),
                          hintText: 'Enter prizes description...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: nextAllowCreditors,
                            onChanged: (val) {
                              setDialogState(() => nextAllowCreditors = val ?? false);
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'Applicable for Creditors (Credit > 0)',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
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
                    if (startNextCampaign && (nextNameCtrl.text.trim().isEmpty || nextThresholdCtrl.text.trim().isEmpty)) {
                      return;
                    }
                    try {
                      final body = startNextCampaign
                          ? {
                              'next_campaign_name': nextNameCtrl.text.trim(),
                              'next_threshold_amount': double.tryParse(nextThresholdCtrl.text) ?? 2000.0,
                              'next_draw_date': selectedDate.toIso8601String(),
                              'next_description': nextDescriptionCtrl.text.trim(),
                              'next_allow_creditors': nextAllowCreditors,
                            }
                          : <String, dynamic>{};

                      final res = await ApiClient.post('/api/lucky-draw/campaigns/${_activeCampaign['id']}/complete', body);
                      if (res['success'] == true) {
                        Navigator.pop(dialogContext);
                        _loadCampaignData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Campaign completed successfully.')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error completing campaign: $e')),
                      );
                    }
                  },
                  child: Text(startNextCampaign ? 'Complete & Start' : 'Complete Only'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pauseActiveCampaign() async {
    try {
      final res = await ApiClient.post('/api/lucky-draw/campaigns/${_activeCampaign['id']}/pause', {});
      if (res['success'] == true) {
        _loadCampaignData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lucky draw campaign paused successfully.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error pausing campaign: $e')),
      );
    }
  }

  Future<void> _resumeActiveCampaign() async {
    try {
      final res = await ApiClient.post('/api/lucky-draw/campaigns/${_activeCampaign['id']}/resume', {});
      if (res['success'] == true) {
        _loadCampaignData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lucky draw campaign resumed successfully.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resuming campaign: $e')),
      );
    }
  }

  void _showStopCampaignDialog() {
    final nextNameCtrl = TextEditingController(text: 'Diwali Mega Draw Part II');
    final nextThresholdCtrl = TextEditingController(text: '2000');
    final nextDescriptionCtrl = TextEditingController(text: 'Win pressure cooker, cup, mug, or more!');
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));
    bool startNextCampaign = false;
    bool nextAllowCreditors = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Stop Campaign Without Winner'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Are you sure you want to stop the current campaign without declaring a winner? Spend progress will be reset and voucher ticket issuance will be terminated.',
                      style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: startNextCampaign,
                          onChanged: (val) {
                            setDialogState(() => startNextCampaign = val ?? false);
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Initialize next campaign immediately',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    if (startNextCampaign) ...[
                      const SizedBox(height: 12),
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
                      TextField(
                        controller: nextDescriptionCtrl,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'Next Campaign Description',
                          border: OutlineInputBorder(),
                          hintText: 'Enter prizes description...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: nextAllowCreditors,
                            onChanged: (val) {
                              setDialogState(() => nextAllowCreditors = val ?? false);
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'Applicable for Creditors (Credit > 0)',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
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
                    try {
                      final body = startNextCampaign
                          ? {
                              'next_campaign_name': nextNameCtrl.text.trim(),
                              'next_threshold_amount': double.tryParse(nextThresholdCtrl.text) ?? 2000.0,
                              'next_draw_date': selectedDate.toIso8601String(),
                              'next_description': nextDescriptionCtrl.text.trim(),
                              'next_allow_creditors': nextAllowCreditors,
                            }
                          : <String, dynamic>{};

                      final res = await ApiClient.post('/api/lucky-draw/campaigns/${_activeCampaign['id']}/stop', body);
                      if (res['success'] == true) {
                        Navigator.pop(dialogContext);
                        _loadCampaignData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Campaign stopped successfully.')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error stopping campaign: $e')),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Stop Campaign'),
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
    final descriptionCtrl = TextEditingController(text: 'Win pressure cooker, cup, mug, or more!');
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));
    bool allowCreditors = false;

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
                    TextField(
                      controller: descriptionCtrl,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Campaign Description (e.g. Prizes details)',
                        border: OutlineInputBorder(),
                        hintText: 'Enter prizes description...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: allowCreditors,
                          onChanged: (val) {
                            setDialogState(() => allowCreditors = val ?? false);
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Applicable for Creditors (Credit > 0)',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
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
                        'description': descriptionCtrl.text.trim(),
                        'allow_creditors': allowCreditors,
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
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent(bool isWide) {
    if (_activeCampaign == null) {
      return Center(
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
      );
    }

    final drawDate = DateTime.parse(_activeCampaign['draw_date']);
    final isResultDayOrAfter = DateTime.now().isAfter(drawDate);
    final daysLeft = drawDate.difference(DateTime.now()).inDays;
    final daysLeftText = daysLeft <= 0 ? 'Draw Day Reached!' : '$daysLeft Days Left';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Cards Row
        Flex(
          direction: isWide ? Axis.horizontal : Axis.vertical,
          children: [
            Expanded(
              flex: isWide ? 1 : 0,
              child: _buildKPI(
                'Active Campaign Sales',
                _inr.format(_activeStats?['total_revenue'] ?? 0.0),
                Icons.payments_outlined,
                const Color(0xFF10B981),
              ),
            ),
            if (!isWide) const SizedBox(height: 12),
            if (isWide) const SizedBox(width: 12),
            Expanded(
              flex: isWide ? 1 : 0,
              child: _buildKPI(
                'Tickets Issued',
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
            if (!isWide) const SizedBox(height: 12),
            if (isWide) const SizedBox(width: 12),
            Expanded(
              flex: isWide ? 1 : 0,
              child: _buildKPI(
                'Draw Timeline',
                daysLeftText,
                Icons.hourglass_empty,
                daysLeft <= 0 ? Colors.red : Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Campaign Detail Panel & Draw Panel
        Flex(
          direction: isWide ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT: Configurations
            Expanded(
              flex: isWide ? 4 : 0,
              child: _buildCampaignDetailsCard(_activeCampaign),
            ),
            if (!isWide) const SizedBox(height: 16),
            if (isWide) const SizedBox(width: 16),

            // RIGHT: Raffle Drawer Console
            Expanded(
              flex: isWide ? 5 : 0,
              child: _buildRaffleDrawerConsole(_activeCampaign, isResultDayOrAfter),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Sales Trend Chart Card
        _buildSalesTrendChartCard(_activeSalesTrend),
        const SizedBox(height: 24),

        // Participants Table Card
        _buildParticipantsTableCard(
          participants: _filteredParticipants,
          searchController: _activeSearchCtrl,
          isCompleted: false,
        ),
      ],
    );
  }

  Widget _buildCompletedTabContent(bool isWide) {
    if (_campaignHistory.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 80.0),
          child: Column(
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No completed campaigns found in history.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Flex(
      direction: isWide ? Axis.horizontal : Axis.vertical,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar list of campaigns
        SizedBox(
          width: isWide ? 260 : double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Past Campaigns', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black54)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _campaignHistory.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final c = _campaignHistory[index];
                    final isSelected = _selectedCompletedCampaign?['id'] == c['id'];
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: Colors.blue.shade50,
                      title: Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(DateFormat('dd-MMM-yy').format(DateTime.parse(c['draw_date'])), style: const TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: () => _selectCompletedCampaign(c),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (isWide) const SizedBox(width: 20) else const SizedBox(height: 20),

        // Completed Campaign Details View
        if (_selectedCompletedCampaign != null)
          Expanded(
            flex: isWide ? 1 : 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Configurations & Winner details
                Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: isWide ? 4 : 0,
                      child: _buildCampaignDetailsCard(_selectedCompletedCampaign),
                    ),
                    if (!isWide) const SizedBox(height: 16),
                    if (isWide) const SizedBox(width: 16),
                    Expanded(
                      flex: isWide ? 5 : 0,
                      child: _buildWinnerInfoCard(_selectedCompletedCampaign),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Sales Trend Chart Card
                _buildSalesTrendChartCard(_completedSalesTrend),
                const SizedBox(height: 24),

                // Participants List
                _buildParticipantsTableCard(
                  participants: _completedFilteredParticipants,
                  searchController: _completedSearchCtrl,
                  isCompleted: true,
                ),
              ],
            ),
          )
        else
          const Expanded(child: Center(child: CircularProgressIndicator())),
      ],
    );
  }

  Widget _buildCampaignDetailsCard(dynamic campaign) {
    return Container(
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
              _buildCampaignStatusBadge(campaign['status']),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            campaign['name'],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          _detailRow('Raffle Threshold', 'Spend ${_inr.format(double.parse(campaign['threshold_amount'].toString()))} per ticket'),
          _detailRow('Start Date', DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.parse(campaign['start_date']))),
          _detailRow('Draw Date', DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.parse(campaign['draw_date']))),
          
          if (campaign['id'] == _activeCampaign?['id'] && (campaign['status'] == 'ACTIVE' || campaign['status'] == 'PAUSED')) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                if (campaign['status'] == 'ACTIVE')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pauseActiveCampaign,
                      icon: const Icon(Icons.pause, size: 16, color: Colors.orange),
                      label: const Text('Pause Draw', style: TextStyle(color: Colors.orange, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resumeActiveCampaign,
                      icon: const Icon(Icons.play_arrow, size: 16, color: Colors.green),
                      label: const Text('Resume Draw', style: TextStyle(color: Colors.green, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showStopCampaignDialog,
                    icon: const Icon(Icons.stop, size: 16, color: Colors.red),
                    label: const Text('Stop Draw', style: TextStyle(color: Colors.red, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRaffleDrawerConsole(dynamic campaign, bool isResultDayOrAfter) {
    final status = campaign['status'];
    final hasWinner = campaign['winner'] != null;
    final drawDate = DateTime.parse(campaign['draw_date']);

    return Container(
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
          
          // Slot machine container
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
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1),
                        ),
                      ],
                    )
                  : hasWinner
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              campaign['winner']['voucher_code'],
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 1),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Winner: ${campaign['winner']['customer_name'] ?? "Walk-in"} (${campaign['winner']['customer_phone']})',
                              style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600),
                            ),
                            if (campaign['winner']['customer_address'] != null && campaign['winner']['customer_address'].toString().trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  'Address: ${campaign['winner']['customer_address']}',
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ),
                          ],
                        )
                      : const Text(
                          'No Winner Drawn Yet',
                          style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500),
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
                    onPressed: (_isDrawing || !isResultDayOrAfter) ? null : _triggerWinnerDraw,
                    icon: const Icon(Icons.casino),
                    label: Text(hasWinner ? 'Re-draw Winner' : 'Pick Random Winner'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isResultDayOrAfter ? Colors.blue : Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
              if (status == 'PENDING_RESULT' || hasWinner) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _isDrawing ? null : _showCompleteAndResetDialog,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Complete & Reset'),
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
          if (!isResultDayOrAfter && !hasWinner) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Winner selection unlocks on result day: ${DateFormat('dd-MMM-yyyy').format(drawDate)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWinnerInfoCard(dynamic campaign) {
    final winner = campaign['winner'];
    return Container(
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
          const Text('Winner Announcement Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          if (winner == null)
            const SizedBox(
              height: 120,
              child: Center(child: Text('No winner declared for this campaign.', style: TextStyle(color: Colors.grey))),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.stars, color: Colors.green.shade700, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    winner['voucher_code'],
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green.shade900, letterSpacing: 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _detailRow('Winner Name', winner['customer_name'] ?? 'Walk-in'),
            _detailRow('Mobile Number', winner['customer_phone'] ?? '--'),
            _detailRow('Address', winner['customer_address'] ?? 'No address registered'),
          ],
        ],
      ),
    );
  }

  Widget _buildSalesTrendChartCard(List<dynamic> salesTrendData) {
    // Map backend response into Syncfusion-compatible data
    final List<SalesDayPoint> dataPoints = salesTrendData.map((s) {
      final date = DateTime.parse(s['date'].toString());
      final sales = double.parse(s['total_sales'].toString());
      return SalesDayPoint(date, sales);
    }).toList();

    return Container(
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
          const Text('Campaign Revenue Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          const Text('Daily sales accumulated since campaign start date', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: dataPoints.isEmpty
                ? const Center(child: Text('No sales records registered during this campaign timeline.', style: TextStyle(color: Colors.grey)))
                : SfCartesianChart(
                    primaryXAxis: DateTimeAxis(
                      dateFormat: DateFormat('dd MMM'),
                      intervalType: DateTimeIntervalType.days,
                    ),
                    primaryYAxis: const NumericAxis(
                      title: AxisTitle(text: 'Revenue'),
                    ),
                    series: <CartesianSeries>[
                      SplineAreaSeries<SalesDayPoint, DateTime>(
                        dataSource: dataPoints,
                        xValueMapper: (SalesDayPoint p, _) => p.date,
                        yValueMapper: (SalesDayPoint p, _) => p.sales,
                        gradient: LinearGradient(
                          colors: [Colors.blue.withOpacity(0.4), Colors.blue.withOpacity(0.03)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderColor: Colors.blue,
                        borderWidth: 2,
                        name: 'Sales',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsTableCard({
    required List<dynamic> participants,
    required TextEditingController searchController,
    required bool isCompleted,
  }) {
    return Container(
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
              const Text('Participants & Tickets Ledger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              SizedBox(
                width: 250,
                height: 38,
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 16),
                    hintText: 'Search Name or Phone...',
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (participants.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0),
              child: Center(child: Text('No customer participants registered.', style: TextStyle(color: Colors.grey))),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                columns: const [
                  DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Mobile', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Address', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Total Purchase', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Tickets Held', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Ticket Codes', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: participants.map((p) {
                  final List<dynamic> codes = p['voucher_codes'] ?? [];
                  return DataRow(
                    cells: [
                      DataCell(Text(p['customer_name'] ?? 'Walk-in', style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(p['customer_phone'] ?? '--')),
                      DataCell(Text(p['customer_address'] ?? 'No Address')),
                      DataCell(Text(_inr.format(p['total_purchase'] ?? 0.0))),
                      DataCell(Text(p['voucher_count'].toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(
                        Row(
                          children: codes.map<Widget>((code) {
                            return Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                code.toString(),
                                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCampaignStatusBadge(String status) {
    Color bg = Colors.green.shade100;
    Color fg = Colors.green.shade900;
    String label = 'ACTIVE';

    if (status == 'PENDING_RESULT') {
      bg = Colors.amber.shade100;
      fg = Colors.amber.shade900;
      label = 'PENDING RESULT';
    } else if (status == 'COMPLETED') {
      bg = Colors.grey.shade200;
      fg = Colors.grey.shade700;
      label = 'COMPLETED';
    } else if (status == 'PAUSED') {
      bg = Colors.blue.shade100;
      fg = Colors.blue.shade900;
      label = 'PAUSED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
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
            width: 140,
            child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lucky Draw Campaigns Console'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active Campaign'),
            Tab(text: 'Completed Campaigns'),
          ],
        ),
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;
                return TabBarView(
                  controller: _tabController,
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildActiveTabContent(isWide),
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildCompletedTabContent(isWide),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// Chart Data Point class
class SalesDayPoint {
  final DateTime date;
  final double sales;
  SalesDayPoint(this.date, this.sales);
}

// Blinking Dot Widget for PENDING RESULT
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

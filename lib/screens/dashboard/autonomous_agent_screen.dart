import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class AutonomousAgentScreen extends StatefulWidget {
  const AutonomousAgentScreen({Key? key}) : super(key: key);

  @override
  State<AutonomousAgentScreen> createState() => _AutonomousAgentScreenState();
}

class _AutonomousAgentScreenState extends State<AutonomousAgentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  List<Map<String, dynamic>> _proposals = [];
  List<Map<String, dynamic>> _auditLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAgentData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAgentData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final propRes = await ApiClient.get(ApiEndpoints.agentProposals);
      final logRes = await ApiClient.get(ApiEndpoints.agentAuditLogs);

      if (mounted) {
        setState(() {
          if (propRes != null && propRes['success'] == true && propRes['data'] is List) {
            _proposals = (propRes['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
          if (logRes != null && logRes['success'] == true && logRes['data'] is List) {
            _auditLogs = (logRes['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        });
      }
    } catch (e) {
      // Quiet fallback
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveProposal(String id) async {
    try {
      final endpoint = "${ApiEndpoints.agentProposals}/$id/approve";
      final res = await ApiClient.post(endpoint, {});

      if (res != null && res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Business proposal approved & executed by LYNX AI Agent!"), backgroundColor: Colors.green),
        );
        _loadAgentData();
      }
    } catch (e) {
      // Quiet fallback
    }
  }

  Future<void> _rejectProposal(String id) async {
    try {
      final endpoint = "${ApiEndpoints.agentProposals}/$id/reject";
      await ApiClient.post(endpoint, {});
      _loadAgentData();
    } catch (e) {
      // Quiet fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2D) : const Color(0xFFF8FAFC);
    final appBarBg = isDark ? const Color(0xFF151521) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.grey : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF2B2B40) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: isDark ? 0 : 1,
        iconTheme: IconThemeData(color: textColor),
        title: Row(
          children: [
            const Icon(Icons.psychology_rounded, color: Color(0xFFE53935)),
            const SizedBox(width: 10),
            Text("LYNX AI AGENT • Command Center", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text("AGENT ACTIVE", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: _loadAgentData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE53935),
          labelColor: textColor,
          unselectedLabelColor: subtitleColor,
          tabs: const [
            Tab(icon: Icon(Icons.mark_chat_unread_outlined), text: "Pending Approvals"),
            Tab(icon: Icon(Icons.history_edu_rounded), text: "Execution Audit Logs"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProposalsTab(isDark, cardBg, borderColor, textColor, subtitleColor),
                _buildAuditLogsTab(isDark, cardBg, borderColor, textColor, subtitleColor),
              ],
            ),
    );
  }

  Widget _buildProposalsTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subtitleColor) {
    final pending = _proposals.where((p) => p['status'] == 'PENDING').toList();

    if (pending.isEmpty) {
      return Center(
        child: Text("🎉 All caught up! No pending autonomous business proposals require approval.",
            style: TextStyle(color: subtitleColor, fontSize: 14)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      itemBuilder: (context, index) {
        final item = pending[index];
        final id = item['id'] ?? '';
        final title = item['title'] ?? 'Business Action Proposal';
        final category = item['category'] ?? 'Autonomous Agent';
        final description = item['description'] ?? '';
        final impact = item['expectedImpact'] ?? '';

        return Card(
          color: cardBg,
          elevation: isDark ? 0 : 2,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderColor)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC81E1E).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category.toString().toUpperCase(),
                        style: const TextStyle(color: Color(0xFFE53935), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.schedule, color: subtitleColor, size: 14),
                    const SizedBox(width: 4),
                    Text("Requires Approval", style: TextStyle(color: subtitleColor, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Text(description, style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF334155), fontSize: 13, height: 1.4)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF151521) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Expected Impact: $impact",
                          style: TextStyle(color: isDark ? Colors.greenAccent : const Color(0xFF047857), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: subtitleColor,
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Dismiss"),
                      onPressed: () => _rejectProposal(id),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC81E1E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text("Approve & Execute"),
                      onPressed: () => _approveProposal(id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuditLogsTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subtitleColor) {
    if (_auditLogs.isEmpty) {
      return Center(
        child: Text("No autonomous audit logs recorded yet.", style: TextStyle(color: subtitleColor, fontSize: 14)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _auditLogs.length,
      itemBuilder: (context, index) {
        final log = _auditLogs[index];
        final title = log['actionTitle'] ?? 'Executed Action';
        final by = log['executedBy'] ?? 'AI Agent';
        final impact = log['impact'] ?? '';
        final time = log['timestamp'] ?? '';

        return Card(
          color: cardBg,
          elevation: isDark ? 0 : 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor)),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.done_all_rounded, color: Colors.white),
            ),
            title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text("By: $by • Time: $time\nImpact: $impact", style: TextStyle(color: subtitleColor, fontSize: 12)),
          ),
        );
      },
    );
  }
}

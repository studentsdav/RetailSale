import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class WorkflowAutomationScreen extends StatefulWidget {
  const WorkflowAutomationScreen({Key? key}) : super(key: key);

  @override
  State<WorkflowAutomationScreen> createState() => _WorkflowAutomationScreenState();
}

class _WorkflowAutomationScreenState extends State<WorkflowAutomationScreen> {
  List<Map<String, dynamic>> _rules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiClient.get(ApiEndpoints.workflowRules);
      if (response != null && response['success'] == true && response['data'] is List) {
        final List list = response['data'];
        if (mounted) {
          setState(() {
            _rules = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          });
        }
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

  Future<void> _toggleRule(String ruleId, bool newValue) async {
    setState(() {
      final idx = _rules.indexWhere((r) => r['id'] == ruleId);
      if (idx != -1) {
        _rules[idx]['isActive'] = newValue;
      }
    });

    try {
      final endpoint = "${ApiEndpoints.workflowRules}/$ruleId/toggle";
      await ApiClient.post(endpoint, {'isActive': newValue});
    } catch (e) {
      _loadRules();
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
            const Icon(Icons.bolt_rounded, color: Color(0xFFE53935)),
            const SizedBox(width: 10),
            Text("LYNX AUTOMATE • Workflow Engine", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: _loadRules,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rules.length,
              itemBuilder: (context, index) {
                final rule = _rules[index];
                final id = rule['id'] ?? '';
                final name = rule['name'] ?? 'Workflow Rule';
                final category = rule['category'] ?? 'Automation';
                final description = rule['description'] ?? '';
                final isActive = rule['isActive'] == true;

                return Card(
                  color: cardBg,
                  elevation: isDark ? 0 : 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: borderColor)),
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
                            Switch(
                              value: isActive,
                              activeThumbColor: const Color(0xFFE53935),
                              onChanged: (val) => _toggleRule(id, val),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(color: subtitleColor, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

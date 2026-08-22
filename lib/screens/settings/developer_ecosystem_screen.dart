import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class DeveloperEcosystemScreen extends StatefulWidget {
  const DeveloperEcosystemScreen({Key? key}) : super(key: key);

  @override
  State<DeveloperEcosystemScreen> createState() => _DeveloperEcosystemScreenState();
}

class _DeveloperEcosystemScreenState extends State<DeveloperEcosystemScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  Map<String, dynamic> _info = {};
  List<Map<String, dynamic>> _webhooks = [];
  List<Map<String, dynamic>> _apiKeys = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final infoRes = await ApiClient.get(ApiEndpoints.developerInfo);
      final whRes = await ApiClient.get(ApiEndpoints.developerWebhooks);
      final keyRes = await ApiClient.get(ApiEndpoints.developerApiKeys);

      if (mounted) {
        setState(() {
          if (infoRes != null && infoRes['success'] == true) {
            _info = Map<String, dynamic>.from(infoRes['data'] as Map);
          }
          if (whRes != null && whRes['success'] == true && whRes['data'] is List) {
            _webhooks = (whRes['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
          if (keyRes != null && keyRes['success'] == true && keyRes['data'] is List) {
            _apiKeys = (keyRes['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  Future<void> _showAddWebhookDialog() async {
    final topicCtrl = TextEditingController(text: 'sale.completed');
    final urlCtrl = TextEditingController(text: 'https://api.myerp.com/webhooks/pos-sales');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Register Developer Webhook"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Event Topic", style: TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            TextField(
              controller: topicCtrl,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            const Text("Target URL Endpoint", style: TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC81E1E)),
            child: const Text("Register", style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ApiClient.post(ApiEndpoints.developerWebhooks, {
                'topic': topicCtrl.text.trim(),
                'targetUrl': urlCtrl.text.trim(),
              });
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showGenerateApiKeyDialog() async {
    final nameCtrl = TextEditingController(text: 'E-Commerce Integration Key');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Issue Open Ecosystem API Key"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("API Key Application Name", style: TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC81E1E)),
            child: const Text("Generate Key", style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ApiClient.post(ApiEndpoints.developerApiKeys, {
                'keyName': nameCtrl.text.trim(),
              });
              _loadData();
            },
          ),
        ],
      ),
    );
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
            const Icon(Icons.code_rounded, color: Color(0xFFE53935)),
            const SizedBox(width: 10),
            Text("FAMALTH LYNX • Developer & Open Ecosystem", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE53935),
          labelColor: textColor,
          unselectedLabelColor: subtitleColor,
          tabs: const [
            Tab(icon: Icon(Icons.webhook_rounded), text: "Webhooks"),
            Tab(icon: Icon(Icons.key_rounded), text: "API Keys"),
            Tab(icon: Icon(Icons.devices_other_rounded), text: "Hardware & Docs"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWebhooksTab(isDark, cardBg, borderColor, textColor, subtitleColor),
                _buildApiKeysTab(isDark, cardBg, borderColor, textColor, subtitleColor),
                _buildHardwareDocsTab(isDark, cardBg, borderColor, textColor, subtitleColor),
              ],
            ),
    );
  }

  Widget _buildWebhooksTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subtitleColor) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFC81E1E),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Register Webhook", style: TextStyle(color: Colors.white)),
        onPressed: _showAddWebhookDialog,
      ),
      body: _webhooks.isEmpty
          ? Center(child: Text("No developer webhooks registered yet.", style: TextStyle(color: subtitleColor)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _webhooks.length,
              itemBuilder: (context, index) {
                final item = _webhooks[index];
                final topic = item['topic'] ?? '';
                final url = item['targetUrl'] ?? '';
                final status = item['status'] ?? 'ACTIVE';

                return Card(
                  color: cardBg,
                  elevation: isDark ? 0 : 2,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor)),
                  child: ListTile(
                    leading: const Icon(Icons.webhook_rounded, color: Color(0xFFE53935)),
                    title: Text(topic, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    subtitle: Text(url, style: TextStyle(color: subtitleColor, fontSize: 12)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(status, style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildApiKeysTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subtitleColor) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFC81E1E),
        icon: const Icon(Icons.key, color: Colors.white),
        label: const Text("Issue API Key", style: TextStyle(color: Colors.white)),
        onPressed: _showGenerateApiKeyDialog,
      ),
      body: _apiKeys.isEmpty
          ? Center(child: Text("No ecosystem API keys issued yet.", style: TextStyle(color: subtitleColor)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _apiKeys.length,
              itemBuilder: (context, index) {
                final item = _apiKeys[index];
                final name = item['keyName'] ?? 'Developer Key';
                final key = item['apiKey'] ?? '';

                return Card(
                  color: cardBg,
                  elevation: isDark ? 0 : 2,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor)),
                  child: ListTile(
                    leading: const Icon(Icons.vpn_key_rounded, color: Colors.amber),
                    title: Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    subtitle: Text("Key: $key", style: TextStyle(color: subtitleColor, fontSize: 12)),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHardwareDocsTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subtitleColor) {
    final hardware = (_info['hardwareIntegrations'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: cardBg,
          elevation: isDark ? 0 : 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: borderColor)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("FAMALTH LYNX Ecosystem Specification", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Text("Version: ${_info['version'] ?? 'v1.0.0'}", style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("Company: ${_info['company'] ?? 'Famalth Business Solutions'}", style: TextStyle(color: subtitleColor, fontSize: 12)),
                const SizedBox(height: 12),
                Text("Documentation: ${_info['documentationUrl'] ?? 'https://docs.famalthlynx.io/api/v1'}",
                    style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12, decoration: TextDecoration.underline)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text("Hardware Peripherals & Integration Matrix", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        ...hardware.map((hw) {
          return Card(
            color: cardBg,
            elevation: isDark ? 0 : 1,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
            child: ListTile(
              leading: Icon(Icons.print_rounded, color: subtitleColor),
              title: Text(hw, style: TextStyle(color: textColor, fontSize: 13)),
              trailing: const Icon(Icons.check_circle, color: Colors.green, size: 18),
            ),
          );
        }).toList(),
      ],
    );
  }
}

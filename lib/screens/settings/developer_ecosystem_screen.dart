import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class DeveloperEcosystemScreen extends StatefulWidget {
  const DeveloperEcosystemScreen({super.key});

  @override
  State<DeveloperEcosystemScreen> createState() => _DeveloperEcosystemScreenState();
}

class _DeveloperEcosystemScreenState extends State<DeveloperEcosystemScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  Map<String, dynamic> _info = {};
  List<Map<String, dynamic>> _webhooks = [];
  List<Map<String, dynamic>> _apiKeys = [];

  // Track visibility of secret values per key (key ID -> map of visibility booleans)
  final Map<dynamic, bool> _visibleApiKey = {};
  final Map<dynamic, bool> _visibleClientId = {};
  final Map<dynamic, bool> _visibleClientSecret = {};
  final Map<dynamic, bool> _visibleWebhookSecret = {};

  // Scopes options available for selection
  final List<Map<String, String>> _availableScopes = [
    {'id': 'orders:read', 'name': 'Read Orders', 'desc': 'Query live & historical sales and receipts'},
    {'id': 'orders:write', 'name': 'Create Orders', 'desc': 'Inject orders from external channels & delivery apps'},
    {'id': 'billing:read', 'name': 'Read Billing & Invoices', 'desc': 'Access tax invoices, payment breakdowns'},
    {'id': 'reports:read', 'name': 'Read Analytics & Reports', 'desc': 'Access sales summaries and financial snapshots'},
    {'id': 'inventory:read', 'name': 'Read Inventory & Catalog', 'desc': 'Access real-time stock levels and catalog items'},
  ];

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
    } catch (_) {
      // Quiet fallback
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _maskValue(String raw) {
    if (raw.length <= 8) return '••••••••••••••••';
    return '${raw.substring(0, 8)}${'•' * 24}${raw.substring(raw.length - 4)}';
  }

  Future<void> _showAddWebhookDialog() async {
    final topicCtrl = TextEditingController(text: 'order.created');
    final urlCtrl = TextEditingController(text: 'https://');
    String selectedTopic = 'order.created';

    final topics = [
      {'val': 'order.created', 'label': 'order.created — When a new order is placed'},
      {'val': 'order.completed', 'label': 'order.completed — When a sale is billed/paid'},
      {'val': 'billing.invoice_generated', 'label': 'billing.invoice_generated — When invoice is created'},
      {'val': 'inventory.low_stock', 'label': 'inventory.low_stock — When stock reaches reorder level'},
      {'val': 'order.cancelled', 'label': 'order.cancelled — When an order or item is voided'},
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.webhook_rounded, color: Color(0xFFE53935)),
              SizedBox(width: 8),
              Text("Register Webhook Subscription", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Event Topic", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedTopic,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: topics.map((t) => DropdownMenuItem(
                    value: t['val'],
                    child: Text(t['label']!, style: const TextStyle(fontSize: 13)),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedTopic = val;
                        topicCtrl.text = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text("Target URL Endpoint (HTTPS)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: urlCtrl,
                  decoration: InputDecoration(
                    hintText: 'https://api.your-erp.com/webhooks/pos-events',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.security_rounded, size: 16, color: Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "All webhook payloads are securely signed with HMAC-SHA256 via the 'X-Lynx-Signature' header.",
                          style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC81E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Register Webhook", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () async {
                final url = urlCtrl.text.trim();
                if (url.isEmpty || !url.startsWith('http')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please provide a valid HTTPS target URL')),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                await ApiClient.post(ApiEndpoints.developerWebhooks, {
                  'topic': selectedTopic,
                  'targetUrl': url,
                });
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showGenerateApiKeyDialog() async {
    final nameCtrl = TextEditingController(text: 'E-Commerce & Accounting Integration');
    final selectedScopes = <String>{'orders:read', 'orders:write', 'billing:read', 'reports:read', 'inventory:read'};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: Color(0xFFE53935)),
              SizedBox(width: 8),
              Text("Generate Credentials (API Key & OAuth 2.0)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Application / Partner Name", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: "e.g. Shopify Connector, Tally ERP, Zomato Sync",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Allowed Granular Permissions & Scopes", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: _availableScopes.map((scope) {
                        final isChecked = selectedScopes.contains(scope['id']);
                        return CheckboxListTile(
                          dense: true,
                          title: Text(scope['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(scope['desc']!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          value: isChecked,
                          activeColor: const Color(0xFFC81E1E),
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedScopes.add(scope['id']!);
                              } else {
                                selectedScopes.remove(scope['id']!);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_user_rounded, size: 16, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Generates BOTH API Key (X-API-Key) and OAuth 2.0 Client Credentials (client_id & client_secret) with secret masking.",
                            style: TextStyle(fontSize: 11, color: Color(0xFF065F46)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC81E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Generate Credentials", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await ApiClient.post(ApiEndpoints.developerApiKeys, {
                  'keyName': nameCtrl.text.trim(),
                  'scopes': selectedScopes.toList(),
                });
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testPingWebhook(Map<String, dynamic> item) async {
    final id = item['id'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Sending test payload to ${item['targetUrl']}...")),
    );

    try {
      final res = await ApiClient.post('/api/v1/developer/webhooks/$id/test', {});
      if (!mounted) return;
      if (res != null && res['success'] == true) {
        final ping = res['data'];
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  ping['success'] == true ? Icons.check_circle_rounded : Icons.warning_rounded,
                  color: ping['success'] == true ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                const Text("Webhook Test Result"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Target URL: ${ping['targetUrl']}", style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Text("HTTP Status: ${ping['httpStatus']}", style: TextStyle(fontWeight: FontWeight.bold, color: ping['success'] == true ? Colors.green : Colors.red)),
                const SizedBox(height: 6),
                Text("Latency: ${ping['durationMs']} ms", style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Text("Signature Sent: ${ping['signature']?.toString().substring(0, 16)}...", style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                if (ping['error'] != null) ...[
                  const SizedBox(height: 8),
                  Text("Error Detail: ${ping['error']}", style: const TextStyle(color: Colors.red, fontSize: 12)),
                ]
              ],
            ),
            actions: [
              TextButton(child: const Text("Close"), onPressed: () => Navigator.of(ctx).pop()),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Test Ping failed: ${res?['message'] ?? 'Network error'}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Test error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteWebhook(dynamic id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Revoke Webhook"),
        content: const Text("Are you sure you want to delete this webhook subscription?"),
        actions: [
          TextButton(child: const Text("Cancel"), onPressed: () => Navigator.of(ctx).pop(false)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiClient.delete('/api/v1/developer/webhooks/$id');
      _loadData();
    }
  }

  Future<void> _deleteApiKey(dynamic id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Revoke API Key"),
        content: const Text("Revoking this API key will immediately deny access to all external applications using it. Proceed?"),
        actions: [
          TextButton(child: const Text("Cancel"), onPressed: () => Navigator.of(ctx).pop(false)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Revoke", style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiClient.delete('/api/v1/developer/apikeys/$id');
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final appBarBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: isDark ? 0 : 1,
        iconTheme: IconThemeData(color: textColor),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.code_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("FAMALTH LYNX • Developer & Open Ecosystem", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                Text("Production REST APIs, OAuth 2.0 & Webhook Gateway", style: TextStyle(color: subtitleColor, fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Refresh Data",
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFEF4444),
          indicatorWeight: 3,
          labelColor: const Color(0xFFEF4444),
          unselectedLabelColor: subtitleColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.key_rounded, size: 18), text: "API Keys & OAuth 2.0"),
            Tab(icon: Icon(Icons.webhook_rounded, size: 18), text: "Webhooks Engine"),
            Tab(icon: Icon(Icons.integration_instructions_rounded, size: 18), text: "API Docs & Playground"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEF4444)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildApiKeysTab(isDark, cardBg, borderColor, textColor, subtitleColor),
                _buildWebhooksTab(isDark, cardBg, borderColor, textColor, subtitleColor),
                _buildHardwareDocsTab(isDark, cardBg, borderColor, textColor, subtitleColor),
              ],
            ),
    );
  }

  Widget _buildApiKeysTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subtitleColor) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFDC2626),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("Generate Credentials", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showGenerateApiKeyDialog,
      ),
      body: _apiKeys.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.vpn_key_outlined, size: 56, color: subtitleColor.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text("No API credentials issued yet", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("Generate an API Key & OAuth 2.0 Client credentials to connect external systems.", style: TextStyle(color: subtitleColor, fontSize: 13)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text("Create First Key", style: TextStyle(color: Colors.white)),
                    onPressed: _showGenerateApiKeyDialog,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _apiKeys.length,
              itemBuilder: (context, index) {
                final item = _apiKeys[index];
                final id = item['id'];
                final name = item['keyName'] ?? 'Developer Key';
                final apiKey = item['apiKey'] ?? '';
                final clientId = item['clientId'] ?? '';
                final clientSecret = item['clientSecret'] ?? '';
                final scopes = (item['scopes'] as List?)?.map((e) => e.toString()).toList() ?? [];
                final isActive = item['isActive'] != false;

                final showKey = _visibleApiKey[id] ?? false;
                final showCid = _visibleClientId[id] ?? false;
                final showCsec = _visibleClientSecret[id] ?? false;

                return Card(
                  color: cardBg,
                  elevation: isDark ? 0 : 2,
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.key_rounded, color: Colors.amber, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text("Outlet #${item['outletId'] ?? '0'} • Dual Auth (API Key & OAuth 2.0)", style: TextStyle(color: subtitleColor, fontSize: 11)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isActive ? "ACTIVE" : "REVOKED",
                                style: TextStyle(color: isActive ? Colors.green : Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              tooltip: "Revoke Credentials",
                              onPressed: () => _deleteApiKey(id),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        // 1. API Key with Eye Toggle & Copy
                        _buildCredentialField(
                          label: "API Key",
                          value: apiKey,
                          isRevealed: showKey,
                          onToggle: () {
                            setState(() {
                              _visibleApiKey[id] = !showKey;
                            });
                          },
                          onCopy: () => _copyToClipboard(apiKey, "API Key"),
                          isDark: isDark,
                          borderColor: borderColor,
                        ),
                        const SizedBox(height: 10),
                        // 2. Client ID with Eye Toggle & Copy
                        if (clientId.isNotEmpty) ...[
                          _buildCredentialField(
                            label: "Client ID",
                            value: clientId,
                            isRevealed: showCid,
                            onToggle: () {
                              setState(() {
                                _visibleClientId[id] = !showCid;
                              });
                            },
                            onCopy: () => _copyToClipboard(clientId, "Client ID"),
                            isDark: isDark,
                            borderColor: borderColor,
                          ),
                          const SizedBox(height: 10),
                          // 3. Client Secret with Eye Toggle & Copy
                          _buildCredentialField(
                            label: "Secret",
                            value: clientSecret,
                            isRevealed: showCsec,
                            onToggle: () {
                              setState(() {
                                _visibleClientSecret[id] = !showCsec;
                              });
                            },
                            onCopy: () => _copyToClipboard(clientSecret, "Client Secret"),
                            isDark: isDark,
                            borderColor: borderColor,
                          ),
                        ],
                        const SizedBox(height: 14),
                        // Scopes chips
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: scopes.map((s) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                            ),
                            child: Text(s, style: const TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold)),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildCredentialField({
    required String label,
    required String value,
    required bool isRevealed,
    required VoidCallback onToggle,
    required VoidCallback onCopy,
    required bool isDark,
    required Color borderColor,
  }) {
    final displayText = isRevealed ? value : _maskValue(value);

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text("$label:", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              displayText,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                letterSpacing: isRevealed ? 0 : 1.2,
                color: isRevealed ? null : Colors.grey,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            isRevealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 18,
            color: isRevealed ? const Color(0xFFEF4444) : Colors.grey,
          ),
          tooltip: isRevealed ? "Hide Value" : "Reveal Value",
          onPressed: onToggle,
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 18),
          tooltip: "Copy $label",
          onPressed: onCopy,
        ),
      ],
    );
  }

  Widget _buildWebhooksTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subtitleColor) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFDC2626),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Register Webhook", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showAddWebhookDialog,
      ),
      body: _webhooks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.webhook_outlined, size: 56, color: subtitleColor.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text("No developer webhooks registered", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("Register webhook endpoints to receive instant HTTP push events.", style: TextStyle(color: subtitleColor, fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _webhooks.length,
              itemBuilder: (context, index) {
                final item = _webhooks[index];
                final id = item['id'];
                final topic = item['topic'] ?? '';
                final url = item['targetUrl'] ?? '';
                final secret = item['secret'] ?? '';
                final status = item['status'] ?? 'ACTIVE';
                final isSecretShown = _visibleWebhookSecret[id] ?? false;

                return Card(
                  color: cardBg,
                  elevation: isDark ? 0 : 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.webhook_rounded, color: Color(0xFFEF4444), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(topic, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(url, style: TextStyle(color: subtitleColor, fontSize: 12), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(status, style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              tooltip: "Revoke Webhook",
                              onPressed: () => _deleteWebhook(id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text("HMAC Secret: ", style: TextStyle(color: subtitleColor, fontSize: 11)),
                            Expanded(
                              child: Text(
                                isSecretShown ? secret : _maskValue(secret),
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isSecretShown ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                size: 16,
                                color: isSecretShown ? const Color(0xFFEF4444) : Colors.grey,
                              ),
                              tooltip: isSecretShown ? "Hide Secret" : "Reveal Secret",
                              onPressed: () {
                                setState(() {
                                  _visibleWebhookSecret[id] = !isSecretShown;
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              tooltip: "Copy Secret",
                              onPressed: () => _copyToClipboard(secret, "Webhook Secret"),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                              icon: const Icon(Icons.send_rounded, size: 14),
                              label: const Text("Test Ping", style: TextStyle(fontSize: 12)),
                              onPressed: () => _testPingWebhook(item),
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
  }

  Widget _buildHardwareDocsTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subtitleColor) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Live Specification Card
        Card(
          color: cardBg,
          elevation: isDark ? 0 : 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: borderColor)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.hub_rounded, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Text("FAMALTH LYNX Open REST API Gateway Guide", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 6),
                Text("Version: ${_info['version'] ?? 'v1.0.0'} • Complete Production Manual", style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                  "Connect external POS hardware, Shopify, Zomato, Swiggy, Tally ERP, and accounting software. Every request supports BOTH API Key and OAuth 2.0 Bearer tokens with 100% outlet tenant isolation.",
                  style: TextStyle(color: subtitleColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // SECTION 1: How to Generate OAuth 2.0 Token
        _buildSectionHeader(Icons.token_rounded, "1. How to Generate OAuth 2.0 Token (RFC 6749)", textColor),
        const SizedBox(height: 8),
        _buildApiEndpointCard(
          method: "POST",
          path: "/api/v1/developer/oauth/token",
          scope: "oauth:issue",
          title: "Exchange Client Credentials for Bearer Token",
          desc: "External servers exchange their Client ID & Client Secret for an ephemeral 24-hour JWT Bearer token without exposing static API keys.",
          headers: [
            {"name": "Content-Type", "value": "application/json", "desc": "Payload format"},
          ],
          parameters: [
            {"name": "grant_type", "type": "string", "req": "Required", "desc": "Must be exactly 'client_credentials'"},
            {"name": "client_id", "type": "string", "req": "Required", "desc": "Your Client ID from API Keys tab"},
            {"name": "client_secret", "type": "string", "req": "Required", "desc": "Your Client Secret from API Keys tab"},
          ],
          sampleCurl: 'curl -X POST https://your-pos-domain.com/api/v1/developer/oauth/token \\\n'
              '  -H "Content-Type: application/json" \\\n'
              '  -d \'{\n'
              '    "grant_type": "client_credentials",\n'
              '    "client_id": "lynx_cid_your_client_id",\n'
              '    "client_secret": "lynx_csec_your_client_secret"\n'
              '  }\'',
          sampleResponse: '{\n'
              '  "success": true,\n'
              '  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",\n'
              '  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",\n'
              '  "token_type": "Bearer",\n'
              '  "expires_in": 86400,\n'
              '  "scopes": ["orders:read", "orders:write", "billing:read", "reports:read", "inventory:read"]\n'
              '}',
          cardBg: cardBg,
          borderColor: borderColor,
          textColor: textColor,
          subtitleColor: subtitleColor,
          isDark: isDark,
        ),
        const SizedBox(height: 8),

        // Auto-Refresh Endpoint (like Gmail OAuth)
        _buildApiEndpointCard(
          method: "POST",
          path: "/api/v1/developer/oauth/token",
          scope: "oauth:refresh",
          title: "Automatic Token Refresh (Zero Manual Re-generation)",
          desc: "Never manually log in again. Just like Gmail OAuth, store the 30-day 'refresh_token' on your backend. When the 24-hour access_token expires, your code automatically exchanges the refresh_token for a brand new access_token + rolling refresh_token without touching Client Secret.",
          headers: [
            {"name": "Content-Type", "value": "application/json", "desc": "Payload format"},
          ],
          parameters: [
            {"name": "grant_type", "type": "string", "req": "Required", "desc": "Must be exactly 'refresh_token'"},
            {"name": "refresh_token", "type": "string", "req": "Required", "desc": "The 30-day refresh_token received in Step 1"},
          ],
          sampleCurl: 'curl -X POST https://your-pos-domain.com/api/v1/developer/oauth/token \\\n'
              '  -H "Content-Type: application/json" \\\n'
              '  -d \'{\n'
              '    "grant_type": "refresh_token",\n'
              '    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."\n'
              '  }\'',
          sampleResponse: '{\n'
              '  "success": true,\n'
              '  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",\n'
              '  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",\n'
              '  "token_type": "Bearer",\n'
              '  "expires_in": 86400\n'
              '}',
          cardBg: cardBg,
          borderColor: borderColor,
          textColor: textColor,
          subtitleColor: subtitleColor,
          isDark: isDark,
        ),

        const SizedBox(height: 16),
        // SECTION 2: How to Call APIs (API Key vs Bearer Token)
        _buildSectionHeader(Icons.security_rounded, "2. Authentication Methods: API Key vs Bearer Token", textColor),
        const SizedBox(height: 8),
        Card(
          color: cardBg,
          elevation: isDark ? 0 : 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Method A: Direct API Key Header", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFEF4444))),
                const SizedBox(height: 4),
                const Text("Fastest method for backend integrations, CRON scripts, and webhooks. Add header:", style: TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                _buildCodeSnippet('X-API-Key: lynx_live_sk_your_api_key_here', isDark),
                const SizedBox(height: 14),
                const Text("Method B: OAuth 2.0 Bearer Token Header", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB))),
                const SizedBox(height: 4),
                const Text("Standard enterprise token approach. Add standard HTTP Authorization header:", style: TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                _buildCodeSnippet('Authorization: Bearer <access_token_from_step_1>', isDark),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        // SECTION 3: Business REST Endpoints
        _buildSectionHeader(Icons.api_rounded, "3. Core Business REST APIs (Orders, Billing, Reports, Inventory)", textColor),
        const SizedBox(height: 8),

        // Endpoint: GET /orders
        _buildApiEndpointCard(
          method: "GET",
          path: "/api/v1/open/orders",
          scope: "orders:read",
          title: "Query Orders & Live Receipts",
          desc: "Search, filter, and page through sales, line items, customer details, and payment breakdown.",
          headers: [
            {"name": "X-API-Key", "value": "lynx_live_sk_...", "desc": "Either this or Authorization Bearer"},
            {"name": "Authorization", "value": "Bearer <jwt>", "desc": "Alternative OAuth 2.0 token"},
          ],
          parameters: [
            {"name": "limit", "type": "integer", "req": "Optional", "desc": "Max records to return (default: 50)"},
            {"name": "offset", "type": "integer", "req": "Optional", "desc": "Pagination offset (default: 0)"},
            {"name": "status", "type": "string", "req": "Optional", "desc": "Filter by status: COMPLETED, PENDING"},
            {"name": "startDate", "type": "string", "req": "Optional", "desc": "YYYY-MM-DD filter start"},
            {"name": "endDate", "type": "string", "req": "Optional", "desc": "YYYY-MM-DD filter end"},
          ],
          sampleCurl: '# Calling via API Key:\n'
              'curl -H "X-API-Key: lynx_live_sk_your_api_key" \\\n'
              '  "https://your-pos-domain.com/api/v1/open/orders?limit=10"\n\n'
              '# Calling via OAuth 2.0 Bearer Token:\n'
              'curl -H "Authorization: Bearer eyJhbGciOi..." \\\n'
              '  "https://your-pos-domain.com/api/v1/open/orders?limit=10"',
          sampleResponse: '{\n'
              '  "success": true,\n'
              '  "data": [\n'
              '    {\n'
              '      "id": 1024,\n'
              '      "order_number": "ORD-20261011-001",\n'
              '      "customer_name": "Walk-in Customer",\n'
              '      "net_amount": 450.00,\n'
              '      "payment_mode": "UPI / CARD",\n'
              '      "status": "COMPLETED",\n'
              '      "created_at": "2026-10-11T12:30:00Z",\n'
              '      "items": [\n'
              '        {"item_code": "ITM-01", "name": "Cold Brew", "qty": 2, "price": 225.00}\n'
              '      ]\n'
              '    }\n'
              '  ]\n'
              '}',
          cardBg: cardBg,
          borderColor: borderColor,
          textColor: textColor,
          subtitleColor: subtitleColor,
          isDark: isDark,
        ),

        // Endpoint: POST /orders
        _buildApiEndpointCard(
          method: "POST",
          path: "/api/v1/open/orders",
          scope: "orders:write",
          title: "Create & Inject External Order (Shopify, Swiggy, Zomato)",
          desc: "Inject sales transactions directly into the POS from third-party websites or food aggregators.",
          headers: [
            {"name": "Content-Type", "value": "application/json", "desc": "Required"},
            {"name": "X-API-Key", "value": "lynx_live_sk_...", "desc": "Either this or Authorization Bearer"},
          ],
          parameters: [
            {"name": "customer_name", "type": "string", "req": "Optional", "desc": "Customer full name"},
            {"name": "customer_phone", "type": "string", "req": "Optional", "desc": "Customer phone number"},
            {"name": "payment_mode", "type": "string", "req": "Optional", "desc": "CASH, CARD, UPI, ONLINE (default: CASH)"},
            {"name": "items", "type": "array", "req": "Required", "desc": "List of [{ item_code, qty, selling_price }]"},
          ],
          sampleCurl: 'curl -X POST https://your-pos-domain.com/api/v1/open/orders \\\n'
              '  -H "Content-Type: application/json" \\\n'
              '  -H "X-API-Key: lynx_live_sk_your_api_key" \\\n'
              '  -d \'{\n'
              '    "customer_name": "Alice Green",\n'
              '    "customer_phone": "+19876543210",\n'
              '    "payment_mode": "ONLINE",\n'
              '    "items": [\n'
              '      { "item_code": "BURGER-01", "qty": 1, "selling_price": 250 },\n'
              '      { "item_code": "FRIES-02", "qty": 2, "selling_price": 100 }\n'
              '    ]\n'
              '  }\'',
          sampleResponse: '{\n'
              '  "success": true,\n'
              '  "order_id": 1025,\n'
              '  "sale_no": "ORD-1025",\n'
              '  "net_amount": 450.00,\n'
              '  "status": "COMPLETED",\n'
              '  "message": "Order injected successfully into POS"\n'
              '}',
          cardBg: cardBg,
          borderColor: borderColor,
          textColor: textColor,
          subtitleColor: subtitleColor,
          isDark: isDark,
        ),

        // Endpoint: GET /billing/invoices
        _buildApiEndpointCard(
          method: "GET",
          path: "/api/v1/open/billing/invoices",
          scope: "billing:read",
          title: "Billing & Invoices Audit (Tally & Accounting)",
          desc: "Access finalized tax bills, tax subtotals, invoice numbers, and payment reconciliation data.",
          headers: [
            {"name": "X-API-Key", "value": "lynx_live_sk_...", "desc": "Either this or Authorization Bearer"},
          ],
          parameters: [
            {"name": "limit", "type": "integer", "req": "Optional", "desc": "Default 50"},
            {"name": "offset", "type": "integer", "req": "Optional", "desc": "Default 0"},
          ],
          sampleCurl: 'curl -H "X-API-Key: lynx_live_sk_your_api_key" \\\n'
              '  "https://your-pos-domain.com/api/v1/open/billing/invoices?limit=25"',
          sampleResponse: '{\n'
              '  "success": true,\n'
              '  "invoices": [\n'
              '    {\n'
              '      "invoice_id": 1024,\n'
              '      "invoice_no": "INV-2026-0042",\n'
              '      "taxable_amount": 400.00,\n'
              '      "tax_amount": 50.00,\n'
              '      "total_amount": 450.00,\n'
              '      "payment_mode": "CARD",\n'
              '      "date": "2026-10-11T13:00:00Z"\n'
              '    }\n'
              '  ]\n'
              '}',
          cardBg: cardBg,
          borderColor: borderColor,
          textColor: textColor,
          subtitleColor: subtitleColor,
          isDark: isDark,
        ),

        // Endpoint: GET /reports/sales-summary
        _buildApiEndpointCard(
          method: "GET",
          path: "/api/v1/open/reports/sales-summary",
          scope: "reports:read",
          title: "Real-Time Sales Summary & Financial Analytics",
          desc: "Instant metrics on gross volume, total revenue, average order value (AOV), and payment splits.",
          headers: [
            {"name": "X-API-Key", "value": "lynx_live_sk_...", "desc": "Either this or Authorization Bearer"},
          ],
          parameters: [
            {"name": "startDate", "type": "string", "req": "Optional", "desc": "YYYY-MM-DD"},
            {"name": "endDate", "type": "string", "req": "Optional", "desc": "YYYY-MM-DD"},
          ],
          sampleCurl: 'curl -H "X-API-Key: lynx_live_sk_your_api_key" \\\n'
              '  "https://your-pos-domain.com/api/v1/open/reports/sales-summary"',
          sampleResponse: '{\n'
              '  "success": true,\n'
              '  "summary": {\n'
              '    "total_revenue": 142500.00,\n'
              '    "total_orders": 312,\n'
              '    "average_order_value": 456.73,\n'
              '    "payment_distribution": {\n'
              '      "UPI": 85000.00,\n'
              '      "CARD": 42000.00,\n'
              '      "CASH": 15500.00\n'
              '    }\n'
              '  }\n'
              '}',
          cardBg: cardBg,
          borderColor: borderColor,
          textColor: textColor,
          subtitleColor: subtitleColor,
          isDark: isDark,
        ),

        // Endpoint: GET /inventory/items
        _buildApiEndpointCard(
          method: "GET",
          path: "/api/v1/open/inventory/items",
          scope: "inventory:read",
          title: "Catalog Master & Live Stock Balance",
          desc: "Query products, SKUs, barcode numbers, sales rates, and live outlet stock counts.",
          headers: [
            {"name": "X-API-Key", "value": "lynx_live_sk_...", "desc": "Either this or Authorization Bearer"},
          ],
          parameters: [
            {"name": "search", "type": "string", "req": "Optional", "desc": "Keyword or barcode lookup"},
            {"name": "limit", "type": "integer", "req": "Optional", "desc": "Default 50"},
          ],
          sampleCurl: 'curl -H "X-API-Key: lynx_live_sk_your_api_key" \\\n'
              '  "https://your-pos-domain.com/api/v1/open/inventory/items?limit=50"',
          sampleResponse: '{\n'
              '  "success": true,\n'
              '  "items": [\n'
              '    {\n'
              '      "item_code": "ITM-01",\n'
              '      "item_name": "Cold Brew 300ml",\n'
              '      "barcode": "8901234567890",\n'
              '      "rate": 225.00,\n'
              '      "current_stock": 48\n'
              '    }\n'
              '  ]\n'
              '}',
          cardBg: cardBg,
          borderColor: borderColor,
          textColor: textColor,
          subtitleColor: subtitleColor,
          isDark: isDark,
        ),

        const SizedBox(height: 16),
        // SECTION 4: Webhook Configuration & HMAC Signatures
        _buildSectionHeader(Icons.webhook_rounded, "4. Webhook Setup & HMAC-SHA256 Signature Verification", textColor),
        const SizedBox(height: 8),
        Card(
          color: cardBg,
          elevation: isDark ? 0 : 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("How to Receive & Verify Webhook Notifications:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                const Text(
                  "1. Go to the 'Webhooks Engine' tab and click '+ Register Webhook'.\n"
                  "2. Choose the event topic (e.g. 'order.created' or 'order.completed') and enter your HTTPS endpoint.\n"
                  "3. Lynx automatically generates a unique HMAC secret key for your endpoint.\n"
                  "4. For every incoming HTTP POST webhook call, Lynx attaches the following header:",
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 8),
                _buildCodeSnippet('X-Lynx-Signature: hex_hmac_sha256_of_request_body', isDark),
                const SizedBox(height: 10),
                const Text("Sample Webhook Verification Code (Node.js):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                _buildCodeSnippet(
                  'const crypto = require("crypto");\n\n'
                  'function verifyWebhook(req, secret) {\n'
                  '  const signature = req.headers["x-lynx-signature"];\n'
                  '  const expected = crypto.createHmac("sha256", secret)\n'
                  '                         .update(JSON.stringify(req.body))\n'
                  '                         .digest("hex");\n'
                  '  return signature === expected;\n'
                  '}',
                  isDark,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFEF4444)),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildCodeSnippet(String code, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Stack(
        children: [
          SelectableText(
            code,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF38BDF8)),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: IconButton(
              icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.white70),
              tooltip: "Copy Snippet",
              onPressed: () => _copyToClipboard(code, "Snippet"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiEndpointCard({
    required String method,
    required String path,
    required String scope,
    required String title,
    required String desc,
    required List<Map<String, String>> headers,
    required List<Map<String, String>> parameters,
    required String sampleCurl,
    required String sampleResponse,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtitleColor,
    required bool isDark,
  }) {
    final methodColor = method == "GET" ? Colors.green : (method == "POST" ? Colors.blue : Colors.orange);

    return Card(
      color: cardBg,
      elevation: isDark ? 0 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: methodColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(method, style: TextStyle(color: methodColor, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(path, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: subtitleColor)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text("Scope: $scope", style: TextStyle(fontSize: 10, color: subtitleColor)),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc, style: TextStyle(fontSize: 12, color: textColor)),
                const SizedBox(height: 12),

                // Headers table
                const Text("Header Parameters:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: headers.map((h) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(width: 120, child: Text(h['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace'))),
                          Expanded(child: Text(h['desc']!, style: TextStyle(fontSize: 11, color: subtitleColor))),
                          Text(h['value']!, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.blueAccent)),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Request Parameters table
                if (parameters.isNotEmpty) ...[
                  const Text("Request Parameters / Body Schema:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: parameters.map((p) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(width: 120, child: Text(p['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace'))),
                            SizedBox(width: 70, child: Text(p['type']!, style: const TextStyle(fontSize: 10, color: Colors.purple))),
                            SizedBox(
                              width: 65,
                              child: Text(
                                p['req']!,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: p['req'] == 'Required' ? Colors.red : Colors.grey),
                              ),
                            ),
                            Expanded(child: Text(p['desc']!, style: TextStyle(fontSize: 11, color: subtitleColor))),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // cURL Request Example
                const Text("Sample Request (cURL):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                const SizedBox(height: 6),
                _buildCodeSnippet(sampleCurl, isDark),
                const SizedBox(height: 12),

                // JSON Response Example
                const Text("Expected Response (JSON 200 OK):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                const SizedBox(height: 6),
                _buildCodeSnippet(sampleResponse, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

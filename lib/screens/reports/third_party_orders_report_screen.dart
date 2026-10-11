import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/token_storage.dart';
import '../settings/plugin_marketplace_screen.dart';

class ThirdPartyOrdersReportScreen extends StatefulWidget {
  const ThirdPartyOrdersReportScreen({super.key});

  @override
  State<ThirdPartyOrdersReportScreen> createState() => _ThirdPartyOrdersReportScreenState();
}

class _ThirdPartyOrdersReportScreenState extends State<ThirdPartyOrdersReportScreen> {
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _currentlySyncingPluginId;
  List<Map<String, dynamic>> _orders = [];
  List<String> _dynamicPlatforms = ['ALL'];
  List<Map<String, dynamic>> _availablePlugins = [];
  String _selectedSource = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final userMap = await TokenStorage.getUser();
      final int activeOutletId = int.tryParse((userMap?['outlet_id'] ?? userMap?['outletId'] ?? 1).toString()) ?? 1;

      String query = '${ApiEndpoints.thirdPartyOrdersReport}?sourceTag=$_selectedSource&outletId=$activeOutletId';
      if (_searchCtrl.text.trim().isNotEmpty) {
        query += '&search=${Uri.encodeComponent(_searchCtrl.text.trim())}';
      }

      final res = await ApiClient.get(query);
      if (mounted) {
        setState(() {
          if (res != null && res['success'] == true && res['data'] != null) {
            final data = res['data'];

            // 1. Orders list
            if (data is Map && data['orders'] is List) {
              _orders = (data['orders'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
            } else if (data is List) {
              _orders = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            } else {
              _orders = [];
            }

            // 2. Dynamic platforms discovered from DB and plugins
            final Set<String> platformSet = {'ALL'};
            if (data is Map && data['platforms'] is List) {
              for (final p in data['platforms']) {
                if (p != null && p.toString().trim().isNotEmpty) {
                  platformSet.add(p.toString().toUpperCase().trim());
                }
              }
            }

            // 3. Available plugins capable of onOrderFetch
            if (data is Map && data['orderFetchPlugins'] is List) {
              _availablePlugins = (data['orderFetchPlugins'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
              for (final plg in _availablePlugins) {
                final tag = plg['platformTag']?.toString().toUpperCase();
                if (tag != null && tag.isNotEmpty) platformSet.add(tag);
              }
            }

            // Also add platforms from any current loaded orders
            for (final o in _orders) {
              final tag = o['sourceTag']?.toString().toUpperCase();
              if (tag != null && tag.isNotEmpty) platformSet.add(tag);
            }

            _dynamicPlatforms = platformSet.toList();
          } else {
            _orders = [];
          }
        });
      }
    } catch (_) {
      // Quiet fallback
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ---------------- ORDER DELETION / CLEAR WORKFLOW ----------------

  void _confirmDeleteOrders() {
    final isSpecific = _selectedSource != 'ALL';
    final targetLabel = isSpecific ? "$_selectedSource orders" : "ALL third-party orders";
    final count = _orders.length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text("Delete Third-Party Orders?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Are you sure you want to permanently delete $targetLabel ($count currently shown)?",
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "This will only remove staging records from the third_party_orders table. Your in-store POS sales, invoices, and inventory balances are completely unaffected.",
                        style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: Text("Delete $targetLabel"),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteOrders(sourceTag: _selectedSource);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOrders({String? sourceTag}) async {
    setState(() => _isLoading = true);
    try {
      final userMap = await TokenStorage.getUser();
      final int activeOutletId = int.tryParse((userMap?['outlet_id'] ?? userMap?['outletId'] ?? 1).toString()) ?? 1;
      final tag = sourceTag ?? _selectedSource;
      final endpoint = '${ApiEndpoints.thirdPartyOrdersReport}?sourceTag=$tag&outletId=$activeOutletId';
      final res = await ApiClient.delete(endpoint);

      if (!mounted) return;

      if (res != null && res['success'] == true) {
        final deleted = res['data']?['deletedCount'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Deleted $deleted third-party orders successfully."),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        await _fetchOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to delete orders: ${res?['message'] ?? 'Unknown error'}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting orders: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ---------------- ORDER FETCH WORKFLOW & ERROR HANDLING ----------------

  void _openFetchOptionsDialog() {
    if (_availablePlugins.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text("No Order-Fetch Plugins Available"),
            ],
          ),
          content: const Text(
            "There are currently no active plugins that implement order fetching (like Shopify, Flipkart, or WooCommerce).\n\nPlease install and configure an order integration plugin from the Add-on Marketplace.",
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              icon: const Icon(Icons.storefront_rounded, size: 16),
              label: const Text("Go to Marketplace"),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PluginMarketplaceScreen())).then((_) => _fetchOrders());
              },
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cloud_download_rounded, color: Color(0xFF2563EB), size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Select Plugin to Fetch Orders", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text("Fetch live orders without affecting POS billing", style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Orders are fetched into your isolated staging table with automatic duplicate deduplication.",
                        style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text("Available Enabled Plugins:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              ..._availablePlugins.map((plugin) {
                final name = plugin['name'] ?? 'Plugin';
                final tag = (plugin['platformTag'] ?? 'EXTERNAL').toString().toUpperCase();
                final color = _getSourceColor(tag);
                final author = plugin['author'] ?? 'Developer';
                final isCurrentSyncing = _isSyncing && _currentlySyncingPluginId == plugin['id'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.shopping_cart_outlined, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(tag, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text("By $author • Ready to sync", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: isCurrentSyncing
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.download_rounded, size: 16),
                        label: Text(isCurrentSyncing ? "Syncing..." : "Fetch", style: const TextStyle(fontSize: 12)),
                        onPressed: _isSyncing
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _executeOrderFetch(plugin);
                              },
                      ),
                    ],
                  ),
                );
              }),
              if (_availablePlugins.length > 1) ...[
                const SizedBox(height: 10),
                Center(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                    ),
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: const Text("Fetch All Plugins Sequentially"),
                    onPressed: _isSyncing
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _fetchAllPluginsSequentially();
                          },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  Future<void> _fetchAllPluginsSequentially() async {
    if (!mounted || _isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    int totalSaved = 0;
    int totalDuplicates = 0;
    final List<String> errors = [];
    final List<String> allLogs = [];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            const SizedBox(width: 12),
            Expanded(child: Text("Fetching orders from all ${_availablePlugins.length} plugins sequentially...")),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );

    for (int i = 0; i < _availablePlugins.length; i++) {
      if (!mounted) break;
      final plugin = _availablePlugins[i];
      final pluginId = plugin['id'] ?? '';
      final pluginName = plugin['name'] ?? 'Plugin';
      final platformTag = (plugin['platformTag'] ?? 'EXTERNAL').toString().toUpperCase();

      setState(() {
        _currentlySyncingPluginId = pluginId;
      });

      try {
        final endpoint = "/api/v1/plugins/$pluginId/hook/onOrderFetch";
        final res = await ApiClient.post(endpoint, {});

        if (res != null && res['success'] == true) {
          final data = res['data'] ?? {};

          if (data['success'] == false || data['error'] != null) {
            errors.add("$pluginName [$platformTag]: ${data['error'] ?? 'Execution error'}");
          } else {
            final hookResult = data['result'] ?? {};
            if (hookResult is Map && hookResult['success'] == false) {
              errors.add("$pluginName [$platformTag]: ${hookResult['error'] ?? hookResult['message'] ?? 'Platform error'}");
            } else {
              final saved = hookResult['savedThirdPartyCount'] ?? hookResult['count'] ?? 0;
              final duplicates = hookResult['duplicateCount'] ?? 0;
              totalSaved += (saved is int ? saved : int.tryParse(saved.toString()) ?? 0);
              totalDuplicates += (duplicates is int ? duplicates : int.tryParse(duplicates.toString()) ?? 0);
            }
          }

          if (data['logs'] is List) {
            allLogs.addAll((data['logs'] as List).map((e) => e.toString()));
          }
        } else {
          errors.add("$pluginName [$platformTag]: ${res?['message'] ?? 'Request failed'}");
        }
      } catch (e) {
        String cleanMsg = e.toString();
        if (cleanMsg.startsWith('Exception: ')) cleanMsg = cleanMsg.substring('Exception: '.length);
        errors.add("$pluginName [$platformTag]: $cleanMsg");
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    setState(() {
      _isSyncing = false;
      _currentlySyncingPluginId = null;
    });

    await _fetchOrders();

    if (!mounted) return;

    if (errors.isEmpty) {
      _showSuccessDialog(
        pluginName: "All ${_availablePlugins.length} Plugins",
        platformTag: "SEQUENTIAL_SYNC",
        savedCount: totalSaved,
        duplicateCount: totalDuplicates,
        logs: allLogs.join('\n'),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                errors.length == _availablePlugins.length ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                color: errors.length == _availablePlugins.length ? Colors.red : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text("Sequential Sync Results", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      "✓ $totalSaved New Orders Saved • $totalDuplicates Duplicates Skipped",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF047857)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text("Issues / Errors Encountered:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
                  const SizedBox(height: 6),
                  ...errors.map((err) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                        ),
                        child: Text(err, style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B))),
                      )),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("View Orders"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _executeOrderFetch(Map<String, dynamic> plugin) async {
    if (!mounted || _isSyncing) return;

    final pluginId = plugin['id'] ?? '';
    final pluginName = plugin['name'] ?? 'Plugin';
    final platformTag = (plugin['platformTag'] ?? 'EXTERNAL').toString().toUpperCase();

    setState(() {
      _isSyncing = true;
      _currentlySyncingPluginId = pluginId;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            const SizedBox(width: 12),
            Expanded(child: Text("Fetching live orders from $pluginName [$platformTag]...")),
          ],
        ),
        duration: const Duration(seconds: 15),
      ),
    );

    try {
      final endpoint = "/api/v1/plugins/$pluginId/hook/onOrderFetch";
      final res = await ApiClient.post(endpoint, {});

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (res != null && res['success'] == true) {
        final data = res['data'] ?? {};

        // Check if plugin execution sandbox reported an error
        if (data['success'] == false || data['error'] != null) {
          final errorMsg = data['error'] ?? 'Plugin execution failed inside secure sandbox';
          final logs = (data['logs'] as List?)?.join('\n') ?? 'No logs generated.';
          _showErrorDialog(
            title: "Plugin Execution Error",
            pluginName: pluginName,
            platformTag: platformTag,
            errorMessage: errorMsg.toString(),
            logs: logs,
            plugin: plugin,
          );
          return;
        }

        // Check if hook result reported platform error
        final hookResult = data['result'] ?? {};
        if (hookResult is Map && hookResult['success'] == false) {
          final errorMsg = hookResult['error'] ?? hookResult['message'] ?? 'Platform returned an error';
          final logs = (data['logs'] as List?)?.join('\n') ?? '';
          _showErrorDialog(
            title: "Platform Fetch Error",
            pluginName: pluginName,
            platformTag: platformTag,
            errorMessage: errorMsg.toString(),
            logs: logs,
            plugin: plugin,
          );
          return;
        }

        // Success!
        final saved = hookResult['savedThirdPartyCount'] ?? hookResult['count'] ?? 0;
        final duplicates = hookResult['duplicateCount'] ?? 0;
        final logs = (data['logs'] as List?)?.join('\n') ?? 'Sync completed successfully.';

        _showSuccessDialog(
          pluginName: pluginName,
          platformTag: platformTag,
          savedCount: saved,
          duplicateCount: duplicates,
          logs: logs,
        );

        // Refresh orders list
        await _fetchOrders();
      } else {
        final errorMsg = res?['message'] ?? res?['error'] ?? 'Server returned unsuccessful response';
        _showErrorDialog(
          title: "Order Fetch Request Failed",
          pluginName: pluginName,
          platformTag: platformTag,
          errorMessage: errorMsg.toString(),
          logs: null,
          plugin: plugin,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      String cleanMsg = e.toString();
      if (cleanMsg.startsWith('Exception: ')) {
        cleanMsg = cleanMsg.substring('Exception: '.length);
      }

      _showErrorDialog(
        title: "Order Fetch Error",
        pluginName: pluginName,
        platformTag: platformTag,
        errorMessage: cleanMsg,
        logs: null,
        plugin: plugin,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _currentlySyncingPluginId = null;
        });
      }
    }
  }

  void _showErrorDialog({
    required String title,
    required String pluginName,
    required String platformTag,
    required String errorMessage,
    String? logs,
    required Map<String, dynamic> plugin,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                  Text("$pluginName [$platformTag]", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error response message box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Error Details from Response:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
                            const SizedBox(height: 4),
                            SelectableText(
                              errorMessage,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Troubleshooting Tips:\n• Verify store credentials or API keys configured in Add-on Marketplace.\n• Check network connectivity and store domain URL.\n• Review the execution logs below for detailed error stack.",
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (logs != null && logs.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Execution Logs:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      TextButton.icon(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                        icon: const Icon(Icons.copy_rounded, size: 13),
                        label: const Text("Copy Logs", style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: logs));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Logs copied to clipboard"), duration: Duration(seconds: 2)),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 180),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        logs,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFF87171)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Dismiss"),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.settings_suggest_rounded, size: 15),
            label: const Text("Marketplace Config"),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PluginMarketplaceScreen())).then((_) => _fetchOrders());
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            icon: const Icon(Icons.refresh_rounded, size: 15),
            label: const Text("Retry Fetch"),
            onPressed: () {
              Navigator.pop(ctx);
              _executeOrderFetch(plugin);
            },
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog({
    required String pluginName,
    required String platformTag,
    required int savedCount,
    required int duplicateCount,
    required String logs,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cloud_done_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text("Orders Fetched Successfully", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "$savedCount New Orders Saved ($duplicateCount Duplicates Skipped)",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF047857)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Source: $pluginName [$platformTag]. Stored in isolated third-party orders table.",
                              style: const TextStyle(fontSize: 11, color: Color(0xFF065F46)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text("Execution Logs:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 160),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      logs,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF38BDF8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("View Orders in Report"),
          ),
        ],
      ),
    );
  }

  // ---------------- UI HELPERS ----------------

  Color _getSourceColor(String source) {
    switch (source.toUpperCase()) {
      case 'SHOPIFY':
        return const Color(0xFF10B981);
      case 'FLIPKART':
        return const Color(0xFF2563EB);
      case 'AMAZON':
        return const Color(0xFFFF9900);
      case 'WOOCOMMERCE':
        return const Color(0xFF96588A);
      case 'SWIGGY':
        return const Color(0xFFFC8019);
      case 'ZOMATO':
        return const Color(0xFFE23744);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final orderNum = order['orderNumber'] ?? order['externalOrderId'] ?? 'Order';
    final customer = order['customerName'] ?? 'Customer';
    final phone = order['customerPhone'] ?? '-';
    final email = order['customerEmail'] ?? '-';
    final total = order['totalAmount'] ?? 0;
    final currency = order['currency'] ?? 'INR';
    final source = (order['sourceTag'] ?? 'EXTERNAL').toString().toUpperCase();
    final items = (order['lineItems'] as List?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getSourceColor(source).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(source, style: TextStyle(color: _getSourceColor(source), fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text("Order #$orderNum", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow("Platform Source:", source, isBold: true),
                      if (customer.isNotEmpty && customer != 'Guest' && !customer.contains('Famalth Online Customer')) ...[
                        const SizedBox(height: 4),
                        _buildDetailRow("Customer:", customer),
                      ],
                      if (phone.isNotEmpty && phone != '+91 9876543210') ...[
                        const SizedBox(height: 4),
                        _buildDetailRow("Phone:", phone),
                      ],
                      if (email.isNotEmpty && !email.contains('online-order@famalth.com')) ...[
                        const SizedBox(height: 4),
                        _buildDetailRow("Email:", email),
                      ],
                      const Divider(height: 16),
                      if (order['financialStatus'] != null &&
                          !order['financialStatus'].toString().toUpperCase().contains('N/A') &&
                          order['financialStatus'].toString().trim().isNotEmpty) ...[
                        _buildDetailRow("Financial Status:", order['financialStatus'].toString(), isBold: true),
                        const SizedBox(height: 4),
                      ],
                      if (order['fulfillmentStatus'] != null &&
                          !order['fulfillmentStatus'].toString().toUpperCase().contains('N/A') &&
                          order['fulfillmentStatus'].toString().trim().isNotEmpty) ...[
                        _buildDetailRow("Fulfillment:", order['fulfillmentStatus'].toString()),
                        const SizedBox(height: 4),
                      ],
                      _buildDetailRow("Total Amount:", "$currency $total", isBold: true, highlight: true),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text("Order Line Items", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const Text("No line item details provided.", style: TextStyle(color: Colors.grey, fontSize: 12))
                else
                  ...items.map((itm) {
                    final title = itm['title'] ?? itm['name'] ?? itm['item_name'] ?? 'Item';
                    final qty = itm['quantity'] ?? itm['qty'] ?? 1;
                    final price = itm['rate'] ?? itm['price'] ?? itm['unitPrice'] ?? itm['selling_price'] ?? 0;
                    final mrp = itm['mrp'] ?? itm['compare_at_price'];
                    final sku = itm['sku']?.toString() ?? '';
                    final stock = itm['stock_status'] ?? itm['stock'] ?? '';
                    final weight = itm['weight']?.toString() ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.05),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                              Row(
                                children: [
                                  if (mrp != null && mrp > price) ...[
                                    Text(
                                      "$currency $mrp",
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    "$currency $price",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (sku.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text("SKU: $sku", style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey)),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (weight.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text("Weight: $weight", style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB))),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (stock.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(stock.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                ),
                              ],
                              const Spacer(),
                              Text("Qty: $qty", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: highlight ? const Color(0xFF10B981) : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF2563EB), size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Third-Party Orders Report", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                Text("Dynamic Marketplace Orders • Isolated from In-Store POS Billing", style: TextStyle(color: subtitleColor, fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          // 1. Prominent "Fetch Orders" Action in AppBar
          if (_availablePlugins.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isSyncing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.cloud_download_rounded, size: 16),
                label: Text(
                  _isSyncing
                      ? "Fetching..."
                      : (_availablePlugins.length == 1 ? "Fetch Orders" : "Fetch Orders (${_availablePlugins.length})"),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: _isSyncing ? null : _openFetchOptionsDialog,
              ),
            ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFF2563EB)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: const Icon(Icons.storefront_rounded, size: 16),
            label: const Text("Plugin Marketplace", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const PluginMarketplaceScreen()));
              _fetchOrders();
            },
          ),
          const SizedBox(width: 8),
          if (_orders.isNotEmpty)
            IconButton(
              tooltip: _selectedSource == 'ALL' ? "Delete All Orders" : "Delete $_selectedSource Orders",
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: _isSyncing || _isLoading ? null : _confirmDeleteOrders,
            ),
          IconButton(
            tooltip: "Refresh Orders",
            icon: Icon(Icons.refresh_rounded, color: textColor),
            onPressed: _isLoading ? null : _fetchOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Available Order-Fetch Plugins Banner with 1-Click Fetch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 11, color: textColor),
                      children: [
                        const TextSpan(
                          text: "Active Order-Fetch Plugins: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (_availablePlugins.isEmpty)
                          TextSpan(
                            text: "None installed yet. Install Shopify, Flipkart or custom plugins from the Marketplace.",
                            style: TextStyle(color: subtitleColor),
                          )
                        else
                          TextSpan(
                            text: _availablePlugins.map((p) => "${p['name']} [${p['platformTag']}]").join(", "),
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_availablePlugins.isNotEmpty) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: _isSyncing
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5))
                        : const Icon(Icons.bolt_rounded, size: 14),
                    label: Text(_isSyncing ? "Syncing..." : "Fetch Orders", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: _isSyncing ? null : _openFetchOptionsDialog,
                  ),
                  const SizedBox(width: 12),
                ],
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text("Manage Plugins ➜", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const PluginMarketplaceScreen()));
                    _fetchOrders();
                  },
                ),
              ],
            ),
          ),

          // 2. Dynamic Platform Filter & Search Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                // Dynamic Platform Filter Chips
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _dynamicPlatforms.map((src) {
                        final isSelected = _selectedSource == src;
                        final color = src == 'ALL' ? const Color(0xFF2563EB) : _getSourceColor(src);

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(
                              src,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: color,
                            backgroundColor: cardBg,
                            side: BorderSide(color: isSelected ? color : borderColor),
                            labelStyle: TextStyle(color: isSelected ? Colors.white : textColor),
                            onSelected: (val) {
                              if (val) {
                                setState(() => _selectedSource = src);
                                _fetchOrders();
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Search Field
                SizedBox(
                  width: 240,
                  height: 38,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: "Search order # or customer...",
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onSubmitted: (_) => _fetchOrders(),
                  ),
                ),
                if (_orders.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                    label: Text(
                      _selectedSource == 'ALL' ? "Clear All" : "Clear $_selectedSource",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isSyncing || _isLoading ? null : _confirmDeleteOrders,
                  ),
                ],
              ],
            ),
          ),

          // 3. Orders List or Helpful Empty State with 1-Click Fetch
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shopping_bag_outlined, size: 56, color: subtitleColor.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text("No third-party orders found", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(
                              _selectedSource == 'ALL'
                                  ? (_availablePlugins.isNotEmpty
                                      ? "Active order-fetch plugin available! Click 'Fetch Orders' below to retrieve orders."
                                      : "Install and enable an order-fetching plugin to retrieve remote marketplace orders.")
                                  : "No orders found under platform '$_selectedSource'. Try switching to 'ALL'.",
                              style: TextStyle(color: subtitleColor, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            if (_availablePlugins.isNotEmpty) ...[
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: _isSyncing
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.cloud_download_rounded, size: 18),
                                label: Text(
                                  _availablePlugins.length == 1
                                      ? "Fetch Orders from ${_availablePlugins.first['platformTag']}"
                                      : "Select Plugin & Fetch Orders Now",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                onPressed: _isSyncing ? null : _openFetchOptionsDialog,
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: subtitleColor,
                                  side: BorderSide(color: borderColor),
                                ),
                                icon: const Icon(Icons.storefront_rounded, size: 15),
                                label: const Text("Open Plugin Marketplace"),
                                onPressed: () async {
                                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const PluginMarketplaceScreen()));
                                  _fetchOrders();
                                },
                              ),
                            ] else ...[
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.storefront_rounded, size: 16),
                                label: const Text("Go to Marketplace & Enable Plugin"),
                                onPressed: () async {
                                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const PluginMarketplaceScreen()));
                                  _fetchOrders();
                                },
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final o = _orders[index];
                          final source = (o['sourceTag'] ?? 'EXTERNAL').toString().toUpperCase();
                          final color = _getSourceColor(source);
                          final orderNum = o['orderNumber'] ?? o['externalOrderId'] ?? 'N/A';
                          final customer = o['customerName'] ?? 'Guest';
                          final amount = o['totalAmount'] ?? 0;
                          final currency = o['currency'] ?? 'INR';
                          final date = o['createdAt']?.toString().split('T').first ?? '';

                          final lineItems = (o['lineItems'] is List) ? (o['lineItems'] as List) : [];
                          final firstItem = lineItems.isNotEmpty && lineItems.first is Map ? lineItems.first as Map : null;
                          final imgUrl = firstItem?['image_url'] ?? firstItem?['imageUrl'] ?? '';
                          final itemName = firstItem?['name'] ?? firstItem?['title'] ?? '';
                          final sku = firstItem?['sku'] ?? '';
                          final stock = firstItem?['stock_status'] ?? firstItem?['stock'] ?? '';
                          final isOutOfStock = stock.toString().toLowerCase().contains('out');
                          final mrp = firstItem?['mrp'] != null ? num.tryParse(firstItem!['mrp'].toString()) : null;
                          final rate = firstItem?['rate'] ?? firstItem?['price'] ?? amount;

                          return Card(
                            color: cardBg,
                            elevation: isDark ? 0 : 1,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _showOrderDetails(o),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Product Thumbnail / Image
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        width: 58,
                                        height: 58,
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                        child: (imgUrl != null && imgUrl.toString().trim().isNotEmpty)
                                            ? Image.network(
                                                imgUrl.toString(),
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Icon(Icons.inventory_2_outlined, color: color, size: 24),
                                              )
                                            : Icon(Icons.inventory_2_outlined, color: color, size: 24),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Product Details & Customer
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: color.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(source, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  "Order #$orderNum",
                                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (itemName.toString().trim().isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              itemName.toString(),
                                              style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              if (sku.toString().trim().isNotEmpty) ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    "SKU: $sku",
                                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              if (stock.toString().trim().isNotEmpty) ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: isOutOfStock
                                                        ? Colors.red.withValues(alpha: 0.12)
                                                        : const Color(0xFF10B981).withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        isOutOfStock ? Icons.cancel_outlined : Icons.check_circle_outline_rounded,
                                                        size: 11,
                                                        color: isOutOfStock ? Colors.red : const Color(0xFF10B981),
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        stock.toString(),
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: isOutOfStock ? Colors.red : const Color(0xFF10B981),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                              const Spacer(),
                                              Icon(Icons.calendar_today_outlined, size: 11, color: subtitleColor),
                                              const SizedBox(width: 3),
                                              Text(date, style: TextStyle(color: subtitleColor, fontSize: 11)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Price & MRP
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (mrp != null && mrp > num.parse(rate.toString())) ...[
                                          Text(
                                            "$currency $mrp",
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                        ],
                                        Text(
                                          "$currency $rate",
                                          style: const TextStyle(
                                            color: Color(0xFF10B981),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (customer.isNotEmpty && customer != 'Guest' && !customer.contains('Famalth Online Customer')) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            customer,
                                            style: TextStyle(color: subtitleColor, fontSize: 11),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

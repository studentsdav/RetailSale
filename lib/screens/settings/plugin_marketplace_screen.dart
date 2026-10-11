import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import 'plugin_dev_studio_screen.dart';

class PluginMarketplaceScreen extends StatefulWidget {
  const PluginMarketplaceScreen({super.key});

  @override
  State<PluginMarketplaceScreen> createState() => _PluginMarketplaceScreenState();
}

class _PluginMarketplaceScreenState extends State<PluginMarketplaceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  List<Map<String, dynamic>> _marketplaceCatalog = [];
  List<Map<String, dynamic>> _installedPlugins = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPluginsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPluginsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final catalogRes = await ApiClient.get(ApiEndpoints.pluginsMarketplace);
      final installedRes = await ApiClient.get(ApiEndpoints.pluginsInstalled);

      if (mounted) {
        setState(() {
          if (catalogRes != null && catalogRes['success'] == true && catalogRes['data'] is List) {
            _marketplaceCatalog = (catalogRes['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
          if (installedRes != null && installedRes['success'] == true && installedRes['data'] is List) {
            _installedPlugins = (installedRes['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  Future<void> _installPlugin(String pluginId) async {
    try {
      final res = await ApiClient.post(ApiEndpoints.pluginInstall, {'pluginId': pluginId});
      if (res != null && res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Add-on Plugin successfully installed & activated!"), backgroundColor: Colors.green),
        );
        _loadPluginsData();
      }
    } catch (_) {
      // Quiet fallback
    }
  }

  Future<void> _uninstallPlugin(String pluginId, String pluginName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Uninstall Plugin?'),
          ],
        ),
        content: Text('Are you sure you want to uninstall "$pluginName"? Its credentials and automation hooks will be removed from this outlet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await ApiClient.post(ApiEndpoints.pluginUninstall, {'pluginId': pluginId});
      if (res != null && res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🗑️ $pluginName has been uninstalled!"), backgroundColor: Colors.black87),
        );
        _loadPluginsData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Uninstall error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _syncAndFetchOrders(Map<String, dynamic> plugin) async {
    final pluginId = plugin['id'] ?? '';
    final pluginName = plugin['name'] ?? 'Plugin';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            const SizedBox(width: 12),
            Text("Syncing & fetching live orders from $pluginName..."),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    try {
      final endpoint = "/api/v1/plugins/$pluginId/hook/onOrderFetch";
      final res = await ApiClient.post(endpoint, {});

      if (!mounted) return;

      if (res != null && res['success'] == true) {
        final data = res['data'] ?? {};
        final hookResult = data['result'] ?? {};
        final saved = hookResult['savedThirdPartyCount'] ?? hookResult['ordersCount'] ?? hookResult['count'] ?? 0;
        final duplicates = hookResult['duplicateCount'] ?? 0;
        final logs = (data['logs'] as List?)?.join('\n') ?? 'Sync completed.';

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.cloud_done_rounded, color: Colors.green),
                SizedBox(width: 8),
                Text('Third-Party Orders Synced'),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "$saved New Orders Saved ($duplicates Duplicates Skipped)",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "Saved in the Third-Party Orders table. Isolated from POS billing. Viewable under Reports ➜ Third-Party Orders.",
                                style: TextStyle(fontSize: 11, color: Color(0xFF065F46)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text("Plugin Execution Logs:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      logs,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF38BDF8)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Order fetch failed: ${res?['message'] ?? 'Unknown error'}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sync error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _togglePlugin(String pluginId, bool newValue) async {
    try {
      final endpoint = "/api/v1/plugins/$pluginId/toggle";
      await ApiClient.post(endpoint, {'isActive': newValue});
      _loadPluginsData();
    } catch (_) {
      // Quiet fallback
    }
  }

  void _showAddKeyDialog(BuildContext parentContext, Function(String) onAdd) {
    final keyCtrl = TextEditingController();
    showDialog(
      context: parentContext,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Add Custom Setting Key', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: keyCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. shopDomain, secretKey, webhookSecret',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () {
                final text = keyCtrl.text.trim();
                Navigator.pop(ctx);
                if (text.isNotEmpty) onAdd(text);
              },
              child: const Text('Add Field'),
            ),
          ],
        );
      },
    );
  }

  void _showConfigureDialog(Map<String, dynamic> plugin) {
    final pluginId = plugin['id'] ?? '';
    final pluginName = plugin['name'] ?? 'Plugin';
    final rawFields = (plugin['configFields'] as List?) ?? [];
    final currentConfig = (plugin['config'] as Map?) ?? {};

    // Build mutable list of fields
    final List<Map<String, dynamic>> fields = [];
    for (final f in rawFields) {
      if (f is Map) fields.add(Map<String, dynamic>.from(f));
    }

    // Also include any keys already stored in currentConfig that might not be in configFields
    for (final k in currentConfig.keys) {
      final keyStr = k.toString();
      if (!fields.any((f) => f['key'] == keyStr)) {
        final isSecret = keyStr.toLowerCase().contains('token') ||
            keyStr.toLowerCase().contains('secret') ||
            keyStr.toLowerCase().contains('password') ||
            keyStr.toLowerCase().contains('key');
        fields.add({
          'key': keyStr,
          'label': keyStr,
          'type': isSecret ? 'password' : 'text',
        });
      }
    }

    // Intelligent defaults if empty
    if (fields.isEmpty) {
      final isShopify = pluginId.toLowerCase().contains('shopify') || pluginName.toLowerCase().contains('shopify');
      if (isShopify) {
        fields.add({'key': 'shopDomain', 'label': 'Shopify Store Domain (e.g. mystore.myshopify.com)', 'type': 'text'});
        fields.add({'key': 'accessToken', 'label': 'Admin API Access Token (shpat_...)', 'type': 'password'});
      } else {
        fields.add({'key': 'apiKey', 'label': 'API Key / Secret', 'type': 'password'});
      }
    }

    final Map<String, TextEditingController> controllers = {};
    for (final field in fields) {
      final key = field['key'] as String;
      final val = currentConfig[key]?.toString() ?? field['default']?.toString() ?? '';
      controllers[key] = TextEditingController(text: val);
    }

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.settings_suggest_rounded, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Configure $pluginName',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF2563EB), size: 22),
                    tooltip: 'Add Custom Key',
                    onPressed: () {
                      _showAddKeyDialog(context, (newKey) {
                        setDialogState(() {
                          final isSecret = newKey.toLowerCase().contains('token') ||
                              newKey.toLowerCase().contains('secret') ||
                              newKey.toLowerCase().contains('password') ||
                              newKey.toLowerCase().contains('key');
                          fields.add({
                            'key': newKey,
                            'label': newKey,
                            'type': isSecret ? 'password' : 'text',
                          });
                          controllers[newKey] = TextEditingController();
                        });
                      });
                    },
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
                      const Text(
                        'Set outlet API keys, credentials, and webhooks for this plugin:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ...fields.map((f) {
                        final key = f['key'] as String;
                        final label = (f['label'] ?? key) as String;
                        final type = f['type'] ?? 'text';
                        final isPassword = type == 'password';
                        final options = f['options'] as List?;
                        final ctrl = controllers[key]!;

                        if (type == 'select' && options != null && options.isNotEmpty) {
                          final validVal = options.contains(ctrl.text) ? ctrl.text : options.first.toString();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: DropdownButtonFormField<String>(
                              initialValue: validVal,
                              decoration: InputDecoration(
                                labelText: label,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: options.map((opt) => DropdownMenuItem<String>(
                                value: opt.toString(),
                                child: Text(opt.toString()),
                              )).toList(),
                              onChanged: (val) {
                                if (val != null) ctrl.text = val;
                              },
                            ),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: TextField(
                            controller: ctrl,
                            obscureText: isPassword,
                            decoration: InputDecoration(
                              labelText: label,
                              hintText: isPassword ? 'Enter secret key / token' : 'Enter value',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              suffixIcon: isPassword
                                  ? const Icon(Icons.lock_outline, size: 18, color: Colors.grey)
                                  : null,
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (!controllers.containsKey('shopDomain'))
                            ActionChip(
                              label: const Text('+ shopDomain', style: TextStyle(fontSize: 10)),
                              onPressed: () {
                                setDialogState(() {
                                  fields.add({'key': 'shopDomain', 'label': 'Shopify Store Domain (e.g. mystore.myshopify.com)', 'type': 'text'});
                                  controllers['shopDomain'] = TextEditingController();
                                });
                              },
                            ),
                          if (!controllers.containsKey('accessToken'))
                            ActionChip(
                              label: const Text('+ accessToken', style: TextStyle(fontSize: 10)),
                              onPressed: () {
                                setDialogState(() {
                                  fields.add({'key': 'accessToken', 'label': 'Shopify Access Token (shpat_...)', 'type': 'password'});
                                  controllers['accessToken'] = TextEditingController();
                                });
                              },
                            ),
                          if (!controllers.containsKey('apiKey'))
                            ActionChip(
                              label: const Text('+ apiKey', style: TextStyle(fontSize: 10)),
                              onPressed: () {
                                setDialogState(() {
                                  fields.add({'key': 'apiKey', 'label': 'API Key', 'type': 'password'});
                                  controllers['apiKey'] = TextEditingController();
                                });
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  icon: isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Save Settings'),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          final Map<String, dynamic> toSave = {};
                          controllers.forEach((k, ctrl) {
                            toSave[k] = ctrl.text.trim();
                          });

                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(ctx);
                          try {
                            final endpoint = "/api/v1/plugins/$pluginId/config";
                            final res = await ApiClient.post(endpoint, {'config': toSave});
                            if (mounted && res != null && res['success'] == true) {
                              navigator.pop();
                              messenger.showSnackBar(
                                const SnackBar(content: Text("✅ Plugin credentials saved successfully!"), backgroundColor: Colors.green),
                              );
                              _loadPluginsData();
                            }
                          } catch (err) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(content: Text("Error: $err"), backgroundColor: Colors.red),
                              );
                            }
                          } finally {
                            setDialogState(() => isSaving = false);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
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
            const Icon(Icons.extension_rounded, color: Color(0xFFE53935)),
            const SizedBox(width: 10),
            Text("Add-on Plugin Marketplace", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
            icon: const Icon(Icons.code_rounded, size: 18),
            label: const Text("Plugin Studio", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const PluginDevStudioScreen()));
              _loadPluginsData(); // Instant update when returning from Developer Studio!
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: _loadPluginsData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE53935),
          labelColor: textColor,
          unselectedLabelColor: subtitleColor,
          tabs: const [
            Tab(icon: Icon(Icons.storefront_rounded), text: "Add-on Marketplace"),
            Tab(icon: Icon(Icons.download_done_rounded), text: "Installed Add-ons"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMarketplaceTab(isDark, cardBg, borderColor, textColor, subtitleColor),
                _buildInstalledTab(isDark, cardBg, borderColor, textColor, subtitleColor),
              ],
            ),
    );
  }

  Widget _buildMarketplaceTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subtitleColor) {
    if (_marketplaceCatalog.isEmpty) {
      return Center(
        child: Text("No plugins available in the Marketplace.", style: TextStyle(color: subtitleColor, fontSize: 14)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _marketplaceCatalog.length,
      itemBuilder: (context, index) {
        final plugin = _marketplaceCatalog[index];
        final id = plugin['id'] ?? '';
        final name = plugin['name'] ?? 'Add-on Plugin';
        final author = plugin['author'] ?? 'Verified Developer';
        final version = plugin['version'] ?? 'v1.0.0';
        final category = plugin['category'] ?? 'Integration';
        final description = plugin['description'] ?? '';
        final isInstalled = plugin['isInstalled'] == true;
        final language = plugin['language'] ?? 'typescript';
        final isPublic = plugin['isPublic'] == true || plugin['outletId'] == 0 || plugin['outletId'] == null;

        return Card(
          color: cardBg,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: borderColor)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.extension_rounded, color: Color(0xFF2563EB), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(language.toUpperCase(), style: const TextStyle(color: Color(0xFF2563EB), fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isPublic ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isPublic ? "GLOBAL" : "PRIVATE",
                                  style: TextStyle(
                                    color: isPublic ? const Color(0xFF10B981) : Colors.orange,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.store_rounded, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text("Developed by $author", style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(" • $version • $category", style: TextStyle(color: subtitleColor, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(description, style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF334155), fontSize: 13, height: 1.4)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isInstalled) ...[
                      // 1. Fetch Orders Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                          side: const BorderSide(color: Color(0xFF10B981)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.cloud_download_rounded, size: 16),
                        label: const Text("Fetch Orders"),
                        onPressed: () => _syncAndFetchOrders(plugin),
                      ),
                      const SizedBox(width: 8),

                      // 2. Configure Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text("Configure"),
                        onPressed: () => _showConfigureDialog(plugin),
                      ),
                      const SizedBox(width: 8),

                      // 3. Uninstall Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text("Uninstall"),
                        onPressed: () => _uninstallPlugin(id, name),
                      ),
                      const SizedBox(width: 8),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 15),
                            SizedBox(width: 4),
                            Text("Active", style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ] else
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text("Install Add-on", style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _installPlugin(id),
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

  Widget _buildInstalledTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subtitleColor) {
    if (_installedPlugins.isEmpty) {
      return Center(
        child: Text("No plugins installed yet. Browse the Add-on Marketplace to get started!",
            style: TextStyle(color: subtitleColor, fontSize: 14)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _installedPlugins.length,
      itemBuilder: (context, index) {
        final plugin = _installedPlugins[index];
        final id = plugin['id'] ?? '';
        final name = plugin['name'] ?? 'Installed Add-on';
        final category = plugin['category'] ?? 'Plugin';
        final isActive = plugin['isActive'] == true;

        return Card(
          color: cardBg,
          elevation: isDark ? 0 : 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: borderColor)),
          child: ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            subtitle: Text("Category: $category", style: TextStyle(color: subtitleColor, fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.cloud_download_rounded, size: 14),
                  label: const Text("Fetch Orders", style: TextStyle(fontSize: 12)),
                  onPressed: () => _syncAndFetchOrders(plugin),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Configure Credentials',
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  onPressed: () => _showConfigureDialog(plugin),
                ),
                IconButton(
                  tooltip: 'Uninstall Plugin',
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  onPressed: () => _uninstallPlugin(id, name),
                ),
                Switch(
                  value: isActive,
                  activeThumbColor: const Color(0xFFE53935),
                  onChanged: (val) => _togglePlugin(id, val),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class PluginMarketplaceScreen extends StatefulWidget {
  const PluginMarketplaceScreen({Key? key}) : super(key: key);

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

  Future<void> _installPlugin(String pluginId) async {
    try {
      final res = await ApiClient.post(ApiEndpoints.pluginInstall, {'pluginId': pluginId});
      if (res != null && res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Add-on Plugin successfully installed & activated!"), backgroundColor: Colors.green),
        );
        _loadPluginsData();
      }
    } catch (e) {
      // Quiet fallback
    }
  }

  Future<void> _togglePlugin(String pluginId, bool newValue) async {
    try {
      final endpoint = "${ApiEndpoints.pluginsMarketplace}/$pluginId/toggle";
      await ApiClient.post(endpoint, {'isActive': newValue});
      _loadPluginsData();
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
            const Icon(Icons.extension_rounded, color: Color(0xFFE53935)),
            const SizedBox(width: 10),
            Text("FAMALTH LYNX • Add-on Marketplace", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _marketplaceCatalog.length,
      itemBuilder: (context, index) {
        final plugin = _marketplaceCatalog[index];
        final id = plugin['id'] ?? '';
        final name = plugin['name'] ?? 'Add-on Plugin';
        final author = plugin['author'] ?? 'Developer';
        final version = plugin['version'] ?? 'v1.0.0';
        final category = plugin['category'] ?? 'Integration';
        final installs = plugin['installs'] ?? '0';
        final rating = plugin['rating'] ?? 5.0;
        final description = plugin['description'] ?? '';
        final isInstalled = plugin['isInstalled'] == true;

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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC81E1E).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.extension_rounded, color: Color(0xFFE53935), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 2),
                          Text("By $author • $version • $category", style: TextStyle(color: subtitleColor, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text("$rating ($installs)", style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
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
                    if (isInstalled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            SizedBox(width: 6),
                            Text("Installed & Active", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC81E1E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text("Get Add-on Plugin"),
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
            trailing: Switch(
              value: isActive,
              activeThumbColor: const Color(0xFFE53935),
              onChanged: (val) => _togglePlugin(id, val),
            ),
          ),
        );
      },
    );
  }
}

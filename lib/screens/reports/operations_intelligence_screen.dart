import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../inventory/purchase_order_screen.dart';

class OperationsIntelligenceScreen extends StatefulWidget {
  const OperationsIntelligenceScreen({Key? key}) : super(key: key);

  @override
  State<OperationsIntelligenceScreen> createState() => _OperationsIntelligenceScreenState();
}

class _OperationsIntelligenceScreenState extends State<OperationsIntelligenceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  Map<String, dynamic> _healthSnapshot = {};
  List<Map<String, dynamic>> _reorderAlerts = [];
  List<Map<String, dynamic>> _expiryAlerts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOperationsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOperationsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final healthRes = await ApiClient.get(ApiEndpoints.operationsHealth);
      final reorderRes = await ApiClient.get(ApiEndpoints.operationsReorderAlerts);
      final expiryRes = await ApiClient.get(ApiEndpoints.operationsExpiryAlerts);

      if (mounted) {
        setState(() {
          if (healthRes != null && healthRes['success'] == true) {
            _healthSnapshot = Map<String, dynamic>.from(healthRes['data'] as Map);
          }
          if (reorderRes != null && reorderRes['success'] == true && reorderRes['data'] is List) {
            _reorderAlerts = (reorderRes['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
          if (expiryRes != null && expiryRes['success'] == true && expiryRes['data'] is List) {
            _expiryAlerts = (expiryRes['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2D) : const Color(0xFFF8FAFC);
    final appBarBg = isDark ? const Color(0xFF151521) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.grey : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF2B2B40) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final totalProducts = _healthSnapshot['totalActiveProducts'] ?? 0;
    final lowStockCount = _healthSnapshot['lowStockCount'] ?? 0;
    final expiryCount = _healthSnapshot['expiringItemCount'] ?? 0;
    final supplierAmount = _healthSnapshot['pendingSupplierAmount'] ?? 0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: isDark ? 0 : 1,
        iconTheme: IconThemeData(color: textColor),
        title: Row(
          children: [
            const Icon(Icons.speed_rounded, color: Color(0xFFE53935)),
            const SizedBox(width: 10),
            Text("LYNX OPERATE • Operations Excellence", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text("LIVE OPS", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: _loadOperationsData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE53935),
          labelColor: textColor,
          unselectedLabelColor: subtitleColor,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: "Reorder & Velocity Watcher"),
            Tab(icon: Icon(Icons.hourglass_bottom_rounded), text: "Near Expiry Batches"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : RefreshIndicator(
              onRefresh: _loadOperationsData,
              child: Column(
                children: [
                  // KPI Header Cards
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        _buildKpiCard("Active Catalog", "$totalProducts Items", Icons.storage, Colors.blue, isDark, cardBg, borderColor, textColor, subtitleColor),
                        const SizedBox(width: 10),
                        _buildKpiCard("Stockout Alerts", "$lowStockCount Low Stock", Icons.warning_amber_rounded, Colors.orange, isDark, cardBg, borderColor, textColor, subtitleColor),
                        const SizedBox(width: 10),
                        _buildKpiCard("Expiry Warnings", "$expiryCount Near Expiry", Icons.alarm, Colors.red, isDark, cardBg, borderColor, textColor, subtitleColor),
                        const SizedBox(width: 10),
                        _buildKpiCard("Pending Supplier", "₹${supplierAmount.toString()}", Icons.account_balance_wallet, Colors.amber, isDark, cardBg, borderColor, textColor, subtitleColor),
                      ],
                    ),
                  ),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildReorderTab(isDark, cardBg, borderColor, textColor, subtitleColor),
                        _buildExpiryTab(isDark, cardBg, borderColor, textColor, subtitleColor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color, bool isDark, Color cardBg, Color borderColor, Color textColor, Color subtitleColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? color.withOpacity(0.3) : borderColor),
          boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: subtitleColor, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildReorderTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subtitleColor) {
    if (_reorderAlerts.isEmpty) {
      return Center(
        child: Text("✅ Healthy Inventory: All products are sufficiently stocked above reorder thresholds.",
            style: TextStyle(color: subtitleColor, fontSize: 14)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _reorderAlerts.length,
      itemBuilder: (context, index) {
        final item = _reorderAlerts[index];
        final name = item['itemName'] ?? 'Item';
        final code = item['itemCode'] ?? '';
        final stock = item['currentStock'] ?? 0;
        final velocity = item['dailyVelocity'] ?? 0;
        final suggested = item['suggestedReorderQty'] ?? 10;

        return Card(
          color: cardBg,
          elevation: isDark ? 0 : 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFC81E1E).withOpacity(0.15),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFE53935)),
            ),
            title: Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            subtitle: Text(
              "Code: $code • Current Stock: $stock • Sales Velocity: $velocity units/day",
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            trailing: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC81E1E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add_shopping_cart, size: 14),
              label: Text("Reorder +$suggested"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PurchaseOrderScreen()),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpiryTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subtitleColor) {
    if (_expiryAlerts.isEmpty) {
      return Center(
        child: Text("✅ Batch Freshness Healthy: No product batches expiring in the next 60 days.",
            style: TextStyle(color: subtitleColor, fontSize: 14)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _expiryAlerts.length,
      itemBuilder: (context, index) {
        final item = _expiryAlerts[index];
        final name = item['itemName'] ?? 'Item';
        final qty = item['qty'] ?? 0;
        final expiry = item['expiryDate'] ?? '';
        final days = item['daysUntilExpiry'] ?? 0;
        final supplier = item['supplierName'] ?? 'N/A';

        return Card(
          color: cardBg,
          elevation: isDark ? 0 : 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.redAccent.withOpacity(0.15),
              child: const Icon(Icons.alarm, color: Colors.redAccent),
            ),
            title: Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            subtitle: Text(
              "Quantity: $qty • Supplier: $supplier • Expiry: $expiry",
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (days <= 15 ? Colors.red : Colors.orange).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "$days Days Left",
                style: TextStyle(
                  color: days <= 15 ? Colors.redAccent : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

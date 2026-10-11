import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/community/community_controller.dart';
import '../../controllers/inventory/marketplace_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../core/currency/currency_service.dart';
import '../../models/inventory/marketplace_vendor_model.dart';
import '../community/chat_conversation_screen.dart';
import '../dashboard/customer_app_screen.dart';

class B2BMarketplaceScreen extends StatefulWidget {
  const B2BMarketplaceScreen({super.key});

  @override
  State<B2BMarketplaceScreen> createState() => _B2BMarketplaceScreenState();
}

class _B2BMarketplaceScreenState extends State<B2BMarketplaceScreen> {
  final MarketplaceController _marketplaceCtrl = MarketplaceController();
  final PropertyInfoController _propertyCtrl = PropertyInfoController();

  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Wholesale Supply',
    'Commodities',
    'Groceries',
    'Dairy',
    'Packaging',
    'Spices',
  ];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _propertyCtrl.load();
    final userCity = _propertyCtrl.data?.city.trim();
    if (userCity != null && userCity.isNotEmpty) {
      _marketplaceCtrl.setCity(userCity);
    }
    await _marketplaceCtrl.fetchVendors(
      city: _marketplaceCtrl.selectedCity,
      category: _selectedCategory,
    );
    if (mounted) setState(() {});
  }

  void _openVendorStorefront(MarketplaceVendor vendor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerAppScreen(
          initialOutletId: vendor.vendorCode,
          initialVendorName: vendor.businessName,
          isB2BMode: true,
          buyerPropertyInfo: _propertyCtrl.data,
        ),
      ),
    );
  }

  void _showCitySelectorDialog() {
    String searchFilter = '';
    final defaultBuyerCity = _propertyCtrl.data?.city.trim() ?? '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final allCities = _marketplaceCtrl.availableCities;
            final query = searchFilter.trim().toLowerCase();
            final filtered = allCities.where((c) => c.toLowerCase().contains(query)).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.public_rounded, color: Colors.blueAccent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Select Marketplace Region', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text('Global & regional wholesale coverage', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    // Global Location Search Field
                    TextField(
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: 'Search city, state, or country globally...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: searchFilter.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setDialogState(() => searchFilter = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        setDialogState(() => searchFilter = val);
                      },
                    ),
                    const SizedBox(height: 10),

                    // Quick Location Chips Bar
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.public, size: 16, color: Colors.blueAccent),
                            label: const Text('All Global Locations', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            backgroundColor: Colors.blue.shade50,
                            side: BorderSide(color: Colors.blue.shade200),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _updateLocationRealtime('All Locations (Global)');
                            },
                          ),
                          if (defaultBuyerCity.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            ActionChip(
                              avatar: const Icon(Icons.my_location, size: 16, color: Colors.green),
                              label: Text('My Store ($defaultBuyerCity)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              backgroundColor: Colors.green.shade50,
                              side: BorderSide(color: Colors.green.shade200),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _updateLocationRealtime(defaultBuyerCity);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Divider(height: 18),

                    // Locations List
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          // Custom location option if user typed something not in list
                          if (searchFilter.trim().isNotEmpty &&
                              !filtered.any((c) => c.toLowerCase() == searchFilter.trim().toLowerCase()))
                            ListTile(
                              leading: const Icon(Icons.add_location_alt_rounded, color: Colors.blueAccent),
                              title: Text('Use "${searchFilter.trim()}" globally',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                              subtitle: const Text('Search distributors delivering to this location'),
                              onTap: () {
                                final customLoc = searchFilter.trim();
                                Navigator.pop(ctx);
                                _updateLocationRealtime(customLoc);
                              },
                            ),
                          ...filtered.map((city) {
                            final isCurrent = city.toLowerCase() ==
                                (_marketplaceCtrl.selectedCity ?? '').toLowerCase();
                            final isGlobal = city.toLowerCase().contains('global');
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                isGlobal
                                    ? Icons.public
                                    : (isCurrent ? Icons.radio_button_checked : Icons.location_on_outlined),
                                color: isCurrent ? Colors.blueAccent : (isGlobal ? Colors.indigo : Colors.grey),
                                size: 20,
                              ),
                              title: Text(
                                city,
                                style: TextStyle(
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  color: isCurrent ? Colors.blue.shade900 : Colors.black87,
                                ),
                              ),
                              trailing: isCurrent
                                  ? const Icon(Icons.check_circle, color: Colors.blueAccent, size: 18)
                                  : null,
                              onTap: () {
                                Navigator.pop(ctx);
                                _updateLocationRealtime(city);
                              },
                            );
                          }),
                          if (filtered.isEmpty && searchFilter.trim().isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('No locations found', style: TextStyle(color: Colors.grey)),
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
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _updateLocationRealtime(String newLocation) {
    _marketplaceCtrl.setCity(newLocation);
    _marketplaceCtrl.fetchVendors(
      city: newLocation,
      category: _selectedCategory,
      search: _searchQuery,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _marketplaceCtrl,
      builder: (context, _) {
        final currentCity = _marketplaceCtrl.selectedCity ?? 'All Locations (Global)';

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              children: [
                Icon(Icons.storefront_outlined),
                SizedBox(width: 8),
                Text('B2B Wholesale Marketplace'),
              ],
            ),
            actions: [
              // Real-time Global Location Picker Button
              InkWell(
                onTap: _showCitySelectorDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.public_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          currentCity,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _buildMarketplaceExploreView(),
        );
      },
    );
  }

  Widget _buildMarketplaceExploreView() {
    final buyer = _propertyCtrl.data;

    return Column(
      children: [
        // Top Buyer Auto-Info Bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              const Icon(Icons.business, color: Colors.blueAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  buyer != null
                      ? 'Ordering as: ${buyer.propertyName.isNotEmpty ? buyer.propertyName : buyer.legalName} (${buyer.gstNo.isNotEmpty ? buyer.gstNo : "URP"}) - B2B Rates Active'
                      : 'B2B Trade Mode Active',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Search & Filter Bar with Global Location Pill
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search verified distributors, products, brands...',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (val) {
                    _searchQuery = val;
                    _marketplaceCtrl.fetchVendors(
                      city: _marketplaceCtrl.selectedCity,
                      category: _selectedCategory,
                      search: _searchQuery,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _showCitySelectorDialog,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.public, size: 16, color: Colors.blueAccent),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          _marketplaceCtrl.selectedCity ?? 'Global',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueAccent),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 16, color: Colors.blueAccent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Category Chips
        SizedBox(
          height: 38,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = _categories[i];
              final isSelected = cat == _selectedCategory;
              return ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                selectedColor: Colors.blueAccent,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (val) {
                  setState(() => _selectedCategory = cat);
                  _marketplaceCtrl.fetchVendors(
                    city: _marketplaceCtrl.selectedCity,
                    category: _selectedCategory,
                    search: _searchQuery,
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Vendors List / Grid
        Expanded(
          child: _marketplaceCtrl.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _marketplaceCtrl.vendors.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.store_mall_directory_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No registered distributors found in "${_marketplaceCtrl.selectedCity ?? "this location"}".',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.public),
                            label: const Text('View All Global Registered Distributors'),
                            onPressed: () {
                              _updateLocationRealtime('All Locations (Global)');
                            },
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.search),
                            label: const Text('Search Another City / Country'),
                            onPressed: _showCitySelectorDialog,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      itemCount: _marketplaceCtrl.vendors.length,
                      itemBuilder: (context, index) {
                        final vendor = _marketplaceCtrl.vendors[index];
                        return _buildVendorCard(vendor);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildVendorCard(MarketplaceVendor vendor) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openVendorStorefront(vendor),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vendor Avatar
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        vendor.businessName.isNotEmpty
                            ? vendor.businessName.substring(0, 1).toUpperCase()
                            : 'V',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Business Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                vendor.businessName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (vendor.isVerified)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.green.shade300),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.verified,
                                        size: 12, color: Colors.green),
                                    SizedBox(width: 2),
                                    Text('GST Verified',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (vendor.tradeName.isNotEmpty && vendor.tradeName != vendor.businessName)
                          Text(
                            vendor.tradeName,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (vendor.gstin.isNotEmpty) ...[
                              Icon(Icons.badge_outlined, size: 13, color: Colors.blue.shade700),
                              const SizedBox(width: 3),
                              Text('GST: ${vendor.gstin}',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade900)),
                              const SizedBox(width: 8),
                            ],
                            if (vendor.phone.isNotEmpty) ...[
                              Icon(Icons.phone_outlined, size: 13, color: Colors.grey.shade700),
                              const SizedBox(width: 3),
                              Text(vendor.phone,
                                  style: TextStyle(
                                      fontSize: 11.5, color: Colors.grey.shade700)),
                              const SizedBox(width: 8),
                            ],
                            const Icon(Icons.location_on, size: 13, color: Colors.grey),
                            Text(
                              vendor.city,
                              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                vendor.address,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Badges & CTA
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Min Order: ${CurrencyService.symbol}${vendor.minOrderAmount.toInt()}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          vendor.deliveryEstimate,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade900),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: Colors.blue.shade300),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.blueAccent),
                        label: const Text('Chat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                        onPressed: () {
                          final communityCtrl = context.read<CommunityController>();
                          final directChat = communityCtrl.getOrCreateDirectChat(
                            recipientId: vendor.id,
                            recipientName: vendor.businessName,
                            recipientGstin: vendor.gstin,
                            recipientPhone: vendor.phone,
                            recipientCity: vendor.city,
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatConversationScreen(conversation: directChat),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.shopping_bag_outlined, size: 15),
                        label: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Open in Customer App', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios, size: 11),
                          ],
                        ),
                        onPressed: () => _openVendorStorefront(vendor),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../controllers/inventory/marketplace_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../core/currency/currency_service.dart';
import '../../models/inventory/marketplace_vendor_model.dart';
import '../dashboard/customer_app_screen.dart';
import '../settings/vendor_marketplace_settings_screen.dart';

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
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_on, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('Select Marketplace City'),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _marketplaceCtrl.availableCities.length,
              itemBuilder: (context, i) {
                final city = _marketplaceCtrl.availableCities[i];
                final isCurrent = city.toLowerCase() ==
                    (_marketplaceCtrl.selectedCity ?? '').toLowerCase();
                return ListTile(
                  leading: Icon(
                    isCurrent ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isCurrent ? Colors.blueAccent : Colors.grey,
                  ),
                  title: Text(city,
                      style: TextStyle(
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _marketplaceCtrl.setCity(city);
                    _marketplaceCtrl.fetchVendors(
                      city: city,
                      category: _selectedCategory,
                      search: _searchQuery,
                    );
                  },
                );
              },
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
  }

  @override
  Widget build(BuildContext context) {
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
          // City Picker Button
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
                children: [
                  const Icon(Icons.location_pin, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    _marketplaceCtrl.selectedCity ?? 'Dehradun',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: _marketplaceCtrl,
        builder: (context, _) => _buildMarketplaceExploreView(),
      ),
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

        // Search & Filter Bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search verified suppliers, commodities, brands...',
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
                            'No public vendors have published their inventory in ${_marketplaceCtrl.selectedCity ?? "this region"} yet.',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.storefront_rounded),
                            label: const Text('Setup & Publish Your Store as Vendor'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const VendorMarketplaceSettingsScreen()),
                              ).then((_) => _initData());
                            },
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _showCitySelectorDialog,
                            child: const Text('Switch City / Location'),
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
        ),
      ),
    );
  }
}

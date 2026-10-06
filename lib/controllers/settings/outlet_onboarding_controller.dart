import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/token_storage.dart';
import '../../core/settings/local_preferences.dart';

class OnboardingStepStatus {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isConfigured;
  final List<String> allowedModules;
  final String actionText;

  OnboardingStepStatus({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isConfigured,
    required this.allowedModules,
    required this.actionText,
  });
}

class OutletOnboardingController extends ChangeNotifier {
  bool isLoading = false;
  String businessModule = 'ALL';

  bool propertyConfigured = false;
  bool settingsConfigured = false;
  bool taxGroupConfigured = false;
  bool sequenceConfigured = false;
  bool locationConfigured = false;
  bool itemMasterConfigured = false;
  bool supplierConfigured = false;
  bool restaurantConfigured = false;
  bool usersConfigured = false;

  int get completedStepsCount => steps.where((s) => s.isConfigured).length;
  int get totalStepsCount => steps.length;
  double get completionPercentage =>
      totalStepsCount > 0 ? (completedStepsCount / totalStepsCount) : 0.0;
  bool get is100PercentComplete =>
      totalStepsCount > 0 && completedStepsCount == totalStepsCount;

  List<OnboardingStepStatus> get steps {
    final allSteps = [
      OnboardingStepStatus(
        key: 'PROPERTY',
        title: 'Property & Branding Setup',
        subtitle: 'Configure store name, address, phone number, GSTIN, and receipt logo',
        icon: Icons.storefront_rounded,
        isConfigured: propertyConfigured,
        allowedModules: const ['RETAIL', 'RESTAURANT', 'HOTEL', 'INVENTORY', 'ALL'],
        actionText: 'Configure Property',
      ),
      OnboardingStepStatus(
        key: 'SETTINGS',
        title: 'Regional, Country & Currency Settings',
        subtitle: 'Set billing country, base currency symbol, ISO code, timezone, and billing rules',
        icon: Icons.public_rounded,
        isConfigured: settingsConfigured,
        allowedModules: const ['RETAIL', 'RESTAURANT', 'HOTEL', 'INVENTORY', 'ALL'],
        actionText: 'Setup Currency',
      ),
      OnboardingStepStatus(
        key: 'TAX_GROUP',
        title: 'Tax Groups & Multi-Tax Structure',
        subtitle: 'Create regional tax groups (State Tax, City Tax, GST, VAT) for items and billing',
        icon: Icons.account_balance_wallet_outlined,
        isConfigured: taxGroupConfigured,
        allowedModules: const ['RETAIL', 'RESTAURANT', 'HOTEL', 'INVENTORY', 'ALL'],
        actionText: 'Manage Taxes',
      ),
      OnboardingStepStatus(
        key: 'SEQUENCE',
        title: 'Document Sequence Settings',
        subtitle: 'Set auto-numbering prefixes for sales bills, KOTs, GRNs, and POs',
        icon: Icons.pin_outlined,
        isConfigured: sequenceConfigured,
        allowedModules: const ['RETAIL', 'RESTAURANT', 'HOTEL', 'INVENTORY', 'ALL'],
        actionText: 'Set Sequences',
      ),
      OnboardingStepStatus(
        key: 'LOCATION',
        title: 'Inventory Location / Warehouse',
        subtitle: 'Add store locations, stock rooms, or warehouses for inventory control',
        icon: Icons.location_on_outlined,
        isConfigured: locationConfigured,
        allowedModules: const ['RETAIL', 'RESTAURANT', 'HOTEL', 'INVENTORY', 'ALL'],
        actionText: 'Setup Locations',
      ),
      OnboardingStepStatus(
        key: 'ITEM_MASTER',
        title: 'Item Master & Inventory Catalog',
        subtitle: 'Add products, categories, rates, and opening stock items',
        icon: Icons.inventory_2_outlined,
        isConfigured: itemMasterConfigured,
        allowedModules: const ['RETAIL', 'RESTAURANT', 'HOTEL', 'INVENTORY', 'ALL'],
        actionText: 'Add Items',
      ),
      OnboardingStepStatus(
        key: 'SUPPLIER',
        title: 'Suppliers & Vendor Master',
        subtitle: 'Register vendors and suppliers for purchase orders and receiving',
        icon: Icons.local_shipping_outlined,
        isConfigured: supplierConfigured,
        allowedModules: const ['RETAIL', 'RESTAURANT', 'HOTEL', 'INVENTORY', 'ALL'],
        actionText: 'Manage Vendors',
      ),
      OnboardingStepStatus(
        key: 'RESTAURANT',
        title: 'Restaurant Areas, Floors & Tables',
        subtitle: 'Create dining areas, section floors, and seating table layouts',
        icon: Icons.table_restaurant_outlined,
        isConfigured: restaurantConfigured,
        allowedModules: const ['RESTAURANT', 'HOTEL'],
        actionText: 'Setup Tables',
      ),
      OnboardingStepStatus(
        key: 'USERS',
        title: 'Staff Users & Cashier Roles',
        subtitle: 'Create cashier and manager accounts with custom security permissions',
        icon: Icons.people_alt_outlined,
        isConfigured: usersConfigured,
        allowedModules: const ['RETAIL', 'RESTAURANT', 'HOTEL', 'INVENTORY', 'ALL'],
        actionText: 'Manage Staff',
      ),
    ];

    final currentMod = businessModule.trim().toUpperCase();
    return allSteps.where((s) {
      if ((currentMod == 'RETAIL' || currentMod == 'INVENTORY') && s.key == 'RESTAURANT') {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> refreshStatus() async {
    isLoading = true;
    notifyListeners();

    try {
      // 1. Try fast single dedicated endpoint first
      try {
        final fastRes = await ApiClient.get('/api/inventory/onboarding-status').catchError((_) => null);
        if (fastRes != null && fastRes['success'] == true && fastRes['data'] is Map<String, dynamic>) {
          final data = fastRes['data'] as Map<String, dynamic>;
          businessModule = (data['business_module'] ?? 'ALL').toString().toUpperCase();
          propertyConfigured = data['property_configured'] == true;
          settingsConfigured = data['settings_configured'] == true;
          taxGroupConfigured = data['tax_group_configured'] == true;
          sequenceConfigured = data['sequence_configured'] == true;
          locationConfigured = data['location_configured'] == true;
          itemMasterConfigured = data['item_master_configured'] == true;
          supplierConfigured = data['supplier_configured'] == true;
          restaurantConfigured = data['restaurant_configured'] == true;
          usersConfigured = data['users_configured'] == true;
          isLoading = false;
          notifyListeners();

          final userMap = await TokenStorage.getUser();
          final outletCode = (userMap?['outlet_code'] ?? userMap?['outletCode'] ?? '').toString().trim();
          final outletIdentifier = outletCode.isNotEmpty ? outletCode : (userMap?['outlet_id'] ?? userMap?['outletId'] ?? 1).toString();
          
          if (is100PercentComplete) {
            await LocalPreferences.setOnboardingCompleted(outletIdentifier, true);
          } else {
            await LocalPreferences.setOnboardingCompleted(outletIdentifier, false);
          }
          return;
        }
      } catch (_) {}

      final userMap = await TokenStorage.getUser();

      // Parallelize onboarding API checks concurrently as fallback
      final results = await Future.wait([
        ApiClient.get(ApiEndpoints.propertyInfo).catchError((_) => null),
        ApiClient.get(ApiEndpoints.documentSequence).catchError((_) => null),
        ApiClient.get(ApiEndpoints.stockLocations).catchError((_) => null),
        ApiClient.get(ApiEndpoints.items).catchError((_) => null),
        ApiClient.get(ApiEndpoints.suppliers).catchError((_) => null),
        ApiClient.get('/api/restaurant/tables').catchError((_) => null),
        ApiClient.get(ApiEndpoints.users).catchError((_) => null),
        ApiClient.get(ApiEndpoints.settings).catchError((_) => null),
        ApiClient.get(ApiEndpoints.taxGroups).catchError((_) => null),
      ]);

      // 1. Determine Business Module (Inventory Only / Retail / Restaurant / Hotel)
      final propRes = results[0];
      String rawModule = '';
      if (propRes != null && propRes['success'] == true && propRes['data'] != null) {
        final pData = propRes['data'];
        rawModule = (pData['business_type'] ?? pData['business_module'] ?? pData['property_type'] ?? pData['businessType'] ?? '').toString();
      }
      if (rawModule.isEmpty || rawModule == 'null') {
        rawModule = (userMap?['business_type'] ?? userMap?['business_module'] ?? userMap?['outlet_module'] ?? userMap?['outlet_type'] ?? 'ALL').toString();
      }

      final upper = rawModule.trim().toUpperCase();
      if (upper.contains('INVENTORY') || upper.contains('WAREHOUSE') || upper.contains('STOCK')) {
        businessModule = 'INVENTORY';
      } else if (upper.contains('RETAIL') || upper.contains('STORE') || upper.contains('MART') || upper.contains('GROCERY') || upper.contains('SUPERMARKET') || upper.contains('SHOP')) {
        businessModule = 'RETAIL';
      } else if (upper.contains('RESTAURANT') || upper.contains('CAFE') || upper.contains('DINER') || upper.contains('FOOD')) {
        businessModule = 'RESTAURANT';
      } else if (upper.contains('HOTEL') || upper.contains('LODGE') || upper.contains('RESORT')) {
        businessModule = 'HOTEL';
      } else {
        businessModule = upper.isNotEmpty ? upper : 'ALL';
      }

      // 2. Property Setup Status
      if (propRes != null && propRes['success'] == true && propRes['data'] != null) {
        final data = propRes['data'];
        final String name = (data['property_name'] ?? data['propertyName'] ?? data['outlet_name'] ?? data['name'] ?? '').toString().trim();
        propertyConfigured = name.isNotEmpty;
      } else {
        final String fallbackName = (userMap?['outlet_name'] ?? userMap?['property_name'] ?? userMap?['name'] ?? '').toString().trim();
        propertyConfigured = fallbackName.isNotEmpty;
      }

      // 3. Settings Status (Country, Currency & Timezone)
      final settingsRes = results[7];
      if (settingsRes != null && settingsRes['success'] == true && settingsRes['data'] != null) {
        final data = settingsRes['data'];
        final String sym = (data['base_currency_symbol'] ?? data['baseCurrencySymbol'] ?? '').toString().trim();
        final String country = (data['billing_country'] ?? data['billingCountry'] ?? '').toString().trim();
        settingsConfigured = sym.isNotEmpty && country.isNotEmpty;
      } else {
        settingsConfigured = false;
      }

      // 4. Tax Groups Status
      final taxGroupsRes = results[8];
      if (taxGroupsRes != null && taxGroupsRes['success'] == true && taxGroupsRes['data'] is List) {
        final list = taxGroupsRes['data'] as List;
        taxGroupConfigured = list.isNotEmpty;
      } else {
        taxGroupConfigured = false;
      }

      // 5. Document Sequence Status
      final seqRes = results[1];
      if (seqRes != null && seqRes['success'] == true && seqRes['data'] is List) {
        final list = seqRes['data'] as List;
        sequenceConfigured = list.isNotEmpty;
      } else {
        sequenceConfigured = false;
      }

      // 6. Location Setup Status
      final locRes = results[2];
      if (locRes != null && locRes['success'] == true && locRes['data'] is List) {
        final list = locRes['data'] as List;
        locationConfigured = list.isNotEmpty;
      } else {
        locationConfigured = false;
      }

      // 7. Item Master Status
      final itemRes = results[3];
      if (itemRes != null && itemRes['success'] == true && itemRes['data'] is List) {
        final list = itemRes['data'] as List;
        itemMasterConfigured = list.isNotEmpty;
      } else {
        itemMasterConfigured = false;
      }

      // 8. Supplier Status
      final supRes = results[4];
      if (supRes != null && supRes['success'] == true && supRes['data'] is List) {
        final list = supRes['data'] as List;
        supplierConfigured = list.isNotEmpty;
      } else {
        supplierConfigured = false;
      }

      // 9. Restaurant Setup Status
      final restRes = results[5];
      if (restRes != null && restRes['success'] == true && restRes['data'] is List) {
        final list = restRes['data'] as List;
        restaurantConfigured = list.isNotEmpty;
      } else {
        restaurantConfigured = false;
      }

      // 10. Users Status
      final usersRes = results[6];
      if (usersRes != null && usersRes['success'] == true && usersRes['data'] is List) {
        final list = usersRes['data'] as List;
        usersConfigured = list.length > 1;
      } else {
        usersConfigured = false;
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

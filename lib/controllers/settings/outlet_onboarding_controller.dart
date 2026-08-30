import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/token_storage.dart';

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
        allowedModules: const ['RETAIL', 'RESTAURANT', 'HOTEL', 'ALL'],
        actionText: 'Configure Property',
      ),
      OnboardingStepStatus(
        key: 'SEQUENCE',
        title: 'Document Sequence Settings',
        subtitle: 'Set auto-numbering prefixes for sales bills, KOTs, GRNs, and POs',
        icon: Icons.pin_outlined,
        isConfigured: sequenceConfigured,
        allowedModules: const ['RETAIL', 'RESTAURANT', 'HOTEL', 'ALL'],
        actionText: 'Set Sequences',
      ),
      OnboardingStepStatus(
        key: 'LOCATION',
        title: 'Inventory Location / Warehouse',
        subtitle: 'Add store locations, stock rooms, or warehouses for inventory control',
        icon: Icons.location_on_outlined,
        isConfigured: locationConfigured,
        allowedModules: const ['RETAIL', 'HOTEL', 'ALL'],
        actionText: 'Setup Locations',
      ),
      OnboardingStepStatus(
        key: 'ITEM_MASTER',
        title: 'Item Master & Inventory Catalog',
        subtitle: 'Add products, categories, rates, and opening stock items',
        icon: Icons.inventory_2_outlined,
        isConfigured: itemMasterConfigured,
        allowedModules: const ['RETAIL', 'RESTAURANT', 'HOTEL', 'ALL'],
        actionText: 'Add Items',
      ),
      OnboardingStepStatus(
        key: 'SUPPLIER',
        title: 'Suppliers & Vendor Master',
        subtitle: 'Register vendors and suppliers for purchase orders and receiving',
        icon: Icons.local_shipping_outlined,
        isConfigured: supplierConfigured,
        allowedModules: const ['RETAIL', 'RESTAURANT', 'HOTEL', 'ALL'],
        actionText: 'Manage Vendors',
      ),
      OnboardingStepStatus(
        key: 'RESTAURANT',
        title: 'Restaurant Areas, Floors & Tables',
        subtitle: 'Create dining areas, section floors, and seating table layouts',
        icon: Icons.table_restaurant_outlined,
        isConfigured: restaurantConfigured,
        allowedModules: const ['RESTAURANT', 'HOTEL', 'ALL'],
        actionText: 'Setup Tables',
      ),
      OnboardingStepStatus(
        key: 'USERS',
        title: 'Staff Users & Cashier Roles',
        subtitle: 'Create cashier and manager accounts with custom security permissions',
        icon: Icons.people_alt_outlined,
        isConfigured: usersConfigured,
        allowedModules: const ['RETAIL', 'RESTAURANT', 'HOTEL', 'ALL'],
        actionText: 'Manage Staff',
      ),
    ];

    final currentMod = businessModule.trim().toUpperCase();
    return allSteps.where((s) {
      if (currentMod == 'ALL') return true;
      return s.allowedModules.contains(currentMod) || s.allowedModules.contains('ALL');
    }).toList();
  }

  Future<void> refreshStatus() async {
    isLoading = true;
    notifyListeners();

    try {
      final userMap = await TokenStorage.getUser();
      businessModule = userMap?['business_module'] ?? userMap?['outlet_module'] ?? 'ALL';

      // 1. Property Setup Status
      try {
        final propRes = await ApiClient.get(ApiEndpoints.propertyInfo);
        if (propRes != null && propRes['success'] == true && propRes['data'] != null) {
          final data = propRes['data'];
          final String name = (data['property_name'] ?? data['propertyName'] ?? data['name'] ?? '').toString().trim();
          propertyConfigured = name.isNotEmpty;
        } else {
          propertyConfigured = false;
        }
      } catch (_) {
        propertyConfigured = false;
      }

      // 2. Document Sequence Status
      try {
        final seqRes = await ApiClient.get(ApiEndpoints.documentSequence);
        if (seqRes != null && seqRes['success'] == true && seqRes['data'] is List) {
          final list = seqRes['data'] as List;
          sequenceConfigured = list.isNotEmpty;
        } else {
          sequenceConfigured = false;
        }
      } catch (_) {
        sequenceConfigured = false;
      }

      // 3. Location Setup Status
      try {
        final locRes = await ApiClient.get(ApiEndpoints.stockLocations);
        if (locRes != null && locRes['success'] == true && locRes['data'] is List) {
          final list = locRes['data'] as List;
          locationConfigured = list.isNotEmpty;
        } else {
          locationConfigured = false;
        }
      } catch (_) {
        locationConfigured = false;
      }

      // 4. Item Master Status
      try {
        final itemRes = await ApiClient.get(ApiEndpoints.items);
        if (itemRes != null && itemRes['success'] == true && itemRes['data'] is List) {
          final list = itemRes['data'] as List;
          itemMasterConfigured = list.isNotEmpty;
        } else {
          itemMasterConfigured = false;
        }
      } catch (_) {
        itemMasterConfigured = false;
      }

      // 5. Supplier Status
      try {
        final supRes = await ApiClient.get(ApiEndpoints.suppliers);
        if (supRes != null && supRes['success'] == true && supRes['data'] is List) {
          final list = supRes['data'] as List;
          supplierConfigured = list.isNotEmpty;
        } else {
          supplierConfigured = false;
        }
      } catch (_) {
        supplierConfigured = false;
      }

      // 6. Restaurant Setup Status
      try {
        final restRes = await ApiClient.get('/api/restaurant/tables');
        if (restRes != null && restRes['success'] == true && restRes['data'] is List) {
          final list = restRes['data'] as List;
          restaurantConfigured = list.isNotEmpty;
        } else {
          restaurantConfigured = false;
        }
      } catch (_) {
        restaurantConfigured = false;
      }

      // 7. Users Status
      try {
        final usersRes = await ApiClient.get(ApiEndpoints.users);
        if (usersRes != null && usersRes['success'] == true && usersRes['data'] is List) {
          final list = usersRes['data'] as List;
          usersConfigured = list.length > 1; // More than 1 user means staff configured
        } else {
          usersConfigured = false;
        }
      } catch (_) {
        usersConfigured = false;
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

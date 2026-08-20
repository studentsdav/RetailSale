class ModuleCapability {
  ModuleCapability._();

  static const String inventory = 'INVENTORY';
  static const String retail = 'RETAIL';
  static const String restaurant = 'RESTAURANT';
  static const String all = 'ALL';

  /// Normalizes module input string
  static String normalize(String? rawModule) {
    if (rawModule == null || rawModule.trim().isEmpty) return all;
    final upper = rawModule.trim().toUpperCase();
    if (upper == inventory ||
        upper == retail ||
        upper == restaurant ||
        upper == all) {
      return upper;
    }
    return all;
  }

  /// Checks if Inventory feature is supported
  static bool hasInventory(String? module) => true;

  /// Checks if Retail feature is supported
  static bool hasRetail(String? module) {
    final mod = normalize(module);
    return mod == retail || mod == all;
  }

  /// Checks if Restaurant feature is supported
  static bool hasRestaurant(String? module) {
    final mod = normalize(module);
    return mod == restaurant || mod == all;
  }

  /// Stock Transfer: Retailers & ALL only. Hidden in Inventory only or Restaurant only.
  static bool isStockTransferAllowed(String? module) {
    final mod = normalize(module);
    return mod == retail || mod == all;
  }

  /// Product Assembly / Recipe: Hide in Inventory only module.
  static bool isAssemblyAllowed(String? module) {
    final mod = normalize(module);
    return mod != inventory;
  }

  /// Gets display label for Product Assembly / Recipe
  static String? getAssemblyLabel(String? module) {
    final mod = normalize(module);
    if (mod == restaurant) return 'Recipe Management';
    if (mod == inventory) return null;
    return 'Product Assembly';
  }

  /// Lucky Draw Campaign: Retailer, Restaurant & ALL. Hide in Inventory only.
  static bool isLuckyDrawAllowed(String? module) {
    final mod = normalize(module);
    return mod != inventory;
  }

  /// Reprint / Modify Sales Bill: Retailer, Restaurant & ALL. Hide in Inventory only.
  static bool isReprintSalesAllowed(String? module) {
    final mod = normalize(module);
    return mod != inventory;
  }

  /// Document sequence module filtering
  static bool isSequenceAllowed(String sequenceModule, String? module) {
    final mod = normalize(module);
    final seqUpper = sequenceModule.toUpperCase();
    if (mod == all) return true;

    if (mod == inventory) {
      if (seqUpper == 'SALES' || seqUpper == 'KOT') return false;
    }

    if (mod == retail) {
      if (seqUpper == 'KOT') return false;
    }

    return true;
  }

  /// Reports & Analytics visibility check
  static bool isReportAllowed(String reportKey, String? module) {
    final mod = normalize(module);
    final keyUpper = reportKey.toUpperCase();
    if (mod == all) return true;

    if (mod == inventory) {
      const inventoryHiddenReports = {
        'STOCK_TRANSFER',
        'SCHEME',
        'LOYALTY',
        'STORE_ANALYSIS',
        'BRAND_ANALYSIS',
        'SALE_SOURCE',
        'COMMISSION',
        'PAYMENT_METHOD',
        'FINANCE_HUB',
        'RETAIL_SALES',
        'DAILY_CLOSING',
      };
      if (inventoryHiddenReports.contains(keyUpper)) return false;
    }

    if (mod == restaurant) {
      const restaurantHiddenReports = {
        'STOCK_TRANSFER',
        'STORE_ANALYSIS',
        'BRAND_ANALYSIS',
      };
      if (restaurantHiddenReports.contains(keyUpper)) return false;
    }

    return true;
  }

  /// Checks if a permission key is allowed under the current business module
  static bool isPermissionAllowed(String? permissionKey, String? module) {
    if (permissionKey == null || permissionKey.isEmpty) return true;
    final key = permissionKey.toUpperCase();
    final mod = normalize(module);

    if (mod == all) return true;

    // Rules for Stock Transfer
    if (key.contains('STOCK_TRANSFER') || key.contains('TRANSFER')) {
      if (!isStockTransferAllowed(mod)) return false;
    }

    // Rules for Assembly / Recipe
    if (key.contains('ASSEMBLY') || key.contains('RECIPE')) {
      if (!isAssemblyAllowed(mod)) return false;
    }

    // Rules for Lucky Draw
    if (key.contains('LUCKY_DRAW')) {
      if (!isLuckyDrawAllowed(mod)) return false;
    }

    // Rules for Sales Reprint / Modify
    if (key.contains('REPRINT_SALES') || key.contains('MODIFY_SALES')) {
      if (!isReprintSalesAllowed(mod)) return false;
    }

    // Retail specific permissions
    const retailPermissions = {
      'RETAIL_SALES',
      'CUSTOMER_APP',
      'RETAILER_CONSOLE',
      'RIDER_PORTAL',
      'RETAIL_SALES_REPORT',
      'STORE_ANALYSIS',
      'BRAND_ANALYSIS',
    };

    // Restaurant specific permissions
    const restaurantPermissions = {
      'RESTAURANT_CONSOLE',
      'RESTAURANT_FLOOR_DESIGN',
      'RESTAURANT_KDS',
      'RESTAURANT_SETUP',
      'DELIVERY_CHALLANS',
      'RECURRING_EXPENSES',
    };

    if (retailPermissions.contains(key) && !hasRetail(mod)) {
      return false;
    }

    if (restaurantPermissions.contains(key) && !hasRestaurant(mod)) {
      return false;
    }

    return true;
  }

  /// Dynamically adapts labels for Restaurant/Inventory modules
  static String adaptLabel(String label, String? module) {
    final mod = normalize(module);
    if (mod == restaurant) {
      if (label.toUpperCase().contains('ASSEMBLY')) {
        return getAssemblyLabel(mod) ?? label;
      }
      if (label.contains('Supplier / Retailer Console')) {
        return 'Supplier & Kitchen Console';
      }
      if (label.contains('Retailer Console')) {
        return 'Restaurant Console';
      }
      if (label.contains('Retail Sales')) {
        return 'Dining & Restaurant Sales';
      }
      if (label.contains('Retail POS')) {
        return 'Restaurant POS';
      }
      if (label.contains('Retailer')) {
        return label.replaceAll('Retailer', 'Restaurant');
      }
    }
    if (mod == inventory) {
      if (label.contains('Retailer')) {
        return label.replaceAll('Retailer', 'Inventory');
      }
    }
    return label;
  }

  /// Filters drawer menu items dynamically based on module access
  static List<Map<String, dynamic>> filterDrawerItems(
      List<Map<String, dynamic>> items, String? module) {
    final mod = normalize(module);
    if (mod == all) return items;

    return items.where((item) {
      final String? perm = item['permission']?.toString();
      final String? category = item['category']?.toString();
      final String? label = item['label']?.toString();

      if (perm != null && perm.isNotEmpty) {
        if (!isPermissionAllowed(perm, mod)) return false;
      }

      if (category != null) {
        final catUpper = category.toUpperCase();
        if (catUpper.contains('RESTAURANT') && !hasRestaurant(mod)) return false;
      }

      if (label != null) {
        final labelUpper = label.toUpperCase();

        // Stock Transfer check
        if (labelUpper.contains('STOCK TRANSFER') && !isStockTransferAllowed(mod)) {
          return false;
        }

        // Product Assembly check
        if ((labelUpper.contains('ASSEMBLY') || labelUpper.contains('RECIPE')) &&
            !isAssemblyAllowed(mod)) {
          return false;
        }

        // Lucky Draw check
        if (labelUpper.contains('LUCKY DRAW') && !isLuckyDrawAllowed(mod)) {
          return false;
        }

        // Sales Bill Reprint / Modify check
        if ((labelUpper.contains('REPRINT') ||
                labelUpper.contains('SALES BILL') ||
                labelUpper.contains('MODIFY SALES')) &&
            !isReprintSalesAllowed(mod)) {
          return false;
        }

        // Restaurant checks
        if ((labelUpper.contains('KDS') ||
                labelUpper.contains('RESTAURANT') ||
                labelUpper.contains('CAPTAIN') ||
                labelUpper.contains('FLOOR PLAN') ||
                labelUpper.contains('KOT') ||
                labelUpper.contains('TABLE RESERVATION')) &&
            !hasRestaurant(mod)) {
          return false;
        }

        // Retail checks
        if ((labelUpper.contains('RETAIL SALES') ||
                labelUpper.contains('CUSTOMER APP') ||
                labelUpper.contains('RETAILER CONSOLE') ||
                labelUpper.contains('RIDER DELIVERY') ||
                labelUpper.contains('STORE ANALYSIS') ||
                labelUpper.contains('BRAND ANALYSIS')) &&
            !hasRetail(mod)) {
          return false;
        }

        // Reports check for Inventory module
        if (mod == inventory) {
          if (labelUpper.contains('LOYALTY') ||
              labelUpper.contains('SCHEME') ||
              labelUpper.contains('COMMISSION') ||
              labelUpper.contains('PAYMENT METHOD ANALYSIS') ||
              labelUpper.contains('SALE SOURCE') ||
              labelUpper.contains('FINANCE HUB')) {
            return false;
          }
        }
      }

      return true;
    }).map((item) {
      final label = item['label']?.toString();
      if (label != null) {
        final adapted = adaptLabel(label, mod);
        if (adapted != label) {
          final copy = Map<String, dynamic>.from(item);
          copy['label'] = adapted;
          return copy;
        }
      }
      return item;
    }).toList();
  }
}

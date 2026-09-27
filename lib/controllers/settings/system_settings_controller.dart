import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/config/date_time_service.dart';
import '../../core/currency/currency_service.dart';
import '../../core/settings/local_preferences.dart';
import '../../models/inventory/settings/system_settings_model.dart';

class SystemSettingsController extends ChangeNotifier {
  bool loading = false;
  SystemSettings? settings;

  SystemSettingsController() {
    _initFromCache();
  }

  Future<void> _initFromCache() async {
    final cachedMappings = await LocalPreferences.getDevicePrinterMappings();
    final cachedCountry = await LocalPreferences.getBillingCountry();
    final cachedSymbol = await LocalPreferences.getBaseCurrencySymbol();
    final cachedCode = await LocalPreferences.getBaseCurrencyCode();
    final cachedPosition = await LocalPreferences.getCurrencySymbolPosition();
    final cachedDecimals = await LocalPreferences.getCurrencyDecimals();
    final cachedTaxMode = await LocalPreferences.getBillingTaxMode();
    final cachedTimeZone = await LocalPreferences.getTimeZone();
    final cachedRestaurantSettlementMode = await LocalPreferences.getRestaurantSettlementMode();

    if (settings == null) {
      settings = SystemSettings.fromJson({});
    }
    if (cachedRestaurantSettlementMode.isNotEmpty) {
      settings!.restaurantSettlementMode = cachedRestaurantSettlementMode;
    }
    if (cachedMappings.isNotEmpty) {
      settings!.devicePrinterMappings = Map<String, dynamic>.from(cachedMappings);
    }
    if (cachedCountry != null && cachedCountry.isNotEmpty) {
      settings!.billingCountry = cachedCountry;
    }
    if (cachedSymbol != null && cachedSymbol.isNotEmpty) {
      settings!.baseCurrencySymbol = cachedSymbol;
    }
    if (cachedCode != null && cachedCode.isNotEmpty) {
      settings!.baseCurrencyCode = cachedCode;
    }
    if (cachedPosition != null && cachedPosition.isNotEmpty) {
      settings!.currencySymbolPosition = cachedPosition;
    }
    if (cachedDecimals != null) {
      settings!.currencyDecimals = cachedDecimals;
    }
    if (cachedTaxMode != null && cachedTaxMode.isNotEmpty) {
      settings!.billingTaxMode = cachedTaxMode;
    }
    if (cachedTimeZone.isNotEmpty) {
      settings!.timeZone = cachedTimeZone;
    }
    DateTimeService.instance.updateTimeZone(settings!.timeZone);
    CurrencyService.updateFromSettings(settings!);
  }

  SystemSettings get currentSettings {
    if (settings == null) {
      settings = SystemSettings.fromJson({});
      _initFromCache();
    }
    return settings!;
  }

  /// LOAD SETTINGS
  Future<void> load() async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.get(ApiEndpoints.settings);
      if (res['data'] != null && res['data'] is Map) {
        settings = SystemSettings.fromJson(res['data']);
        if (res['data']['outlet_max_discount_percent'] != null) {
          final val = res['data']['outlet_max_discount_percent'];
          final dbMaxDisc = val is num
              ? val.toDouble()
              : (double.tryParse(val.toString()) ?? 100.0);
          await LocalPreferences.setMaxDiscountPercent(dbMaxDisc);
        }
      }
    } catch (_) {}

    settings ??= SystemSettings.fromJson({});

    // Read cached local device printer mappings as fallback / merge
    final cachedMappings = await LocalPreferences.getDevicePrinterMappings();
    if (settings!.devicePrinterMappings.isEmpty && cachedMappings.isNotEmpty) {
      settings!.devicePrinterMappings = Map<String, dynamic>.from(cachedMappings);
    } else if (settings!.devicePrinterMappings.isNotEmpty) {
      final merged = Map<String, dynamic>.from(cachedMappings);
      merged.addAll(settings!.devicePrinterMappings);
      settings!.devicePrinterMappings = merged;
      await LocalPreferences.setDevicePrinterMappings(merged);
    } else if (cachedMappings.isNotEmpty) {
      settings!.devicePrinterMappings = Map<String, dynamic>.from(cachedMappings);
    }

    final localCopies = await LocalPreferences.getBillCopiesCount();
    if (localCopies != null && localCopies > 0 && settings != null) {
      settings!.billCopiesCount = localCopies;
    }

    final localTokenSys = await LocalPreferences.getEnableTokenSystem();
    if (localTokenSys != null && settings != null) {
      settings!.enableTokenSystem = localTokenSys;
    }

    final localTokenCopies = await LocalPreferences.getTokenCopiesCount();
    if (localTokenCopies != null && localTokenCopies > 0 && settings != null) {
      settings!.tokenCopiesCount = localTokenCopies;
    }

    final localEnableKotPrint = await LocalPreferences.getEnableKotPrint();
    if (localEnableKotPrint != null && settings != null) {
      settings!.enableKotPrint = localEnableKotPrint;
    }

    final localKotPrintMode = await LocalPreferences.getKotPrintMode();
    if (localKotPrintMode != null && localKotPrintMode.isNotEmpty && settings != null) {
      settings!.kotPrintMode = localKotPrintMode;
    }

    // Merge cached regional & currency preferences if server returned defaults
    final localCountry = await LocalPreferences.getBillingCountry();
    if (localCountry != null && localCountry.isNotEmpty && settings != null) {
      if (settings!.billingCountry.isEmpty || settings!.billingCountry == 'India') {
        settings!.billingCountry = localCountry;
      }
    }
    final localSymbol = await LocalPreferences.getBaseCurrencySymbol();
    if (localSymbol != null && localSymbol.isNotEmpty && settings != null) {
      if (settings!.baseCurrencySymbol.isEmpty || (settings!.baseCurrencySymbol == 'KSh' && localSymbol != 'KSh')) {
        settings!.baseCurrencySymbol = localSymbol;
      }
    }
    final localCode = await LocalPreferences.getBaseCurrencyCode();
    if (localCode != null && localCode.isNotEmpty && settings != null) {
      if (settings!.baseCurrencyCode.isEmpty || (settings!.baseCurrencyCode == 'KES' && localCode != 'KES')) {
        settings!.baseCurrencyCode = localCode;
      }
    }
    final localPos = await LocalPreferences.getCurrencySymbolPosition();
    if (localPos != null && localPos.isNotEmpty && settings != null) {
      settings!.currencySymbolPosition = localPos;
    }
    final localDec = await LocalPreferences.getCurrencyDecimals();
    if (localDec != null && settings != null) {
      settings!.currencyDecimals = localDec;
    }
    final localTaxMode = await LocalPreferences.getBillingTaxMode();
    if (localTaxMode != null && localTaxMode.isNotEmpty && settings != null) {
      if (settings!.billingTaxMode.isEmpty || settings!.billingTaxMode == 'CGST_SGST') {
        settings!.billingTaxMode = localTaxMode;
      }
    }

    if (settings != null) {
      await LocalPreferences.setTimeZone(settings!.timeZone);
      DateTimeService.instance.updateTimeZone(settings!.timeZone);
      CurrencyService.updateFromSettings(settings!);
    }

    loading = false;
    notifyListeners();
  }

  /// SAVE SETTINGS
  Future<void> save(SystemSettings payload) async {
    settings = payload;
    loading = true;
    notifyListeners();

    await LocalPreferences.setBillCopiesCount(payload.billCopiesCount);
    await LocalPreferences.setEnableTokenSystem(payload.enableTokenSystem);
    await LocalPreferences.setTokenCopiesCount(payload.tokenCopiesCount);
    await LocalPreferences.setDevicePrinterMappings(payload.devicePrinterMappings);
    await LocalPreferences.setEnableKotPrint(payload.enableKotPrint);
    await LocalPreferences.setKotPrintMode(payload.kotPrintMode);
    await LocalPreferences.setTimeZone(payload.timeZone);
    await LocalPreferences.setBillingCountry(payload.billingCountry);
    await LocalPreferences.setBaseCurrencySymbol(payload.baseCurrencySymbol);
    await LocalPreferences.setBaseCurrencyCode(payload.baseCurrencyCode);
    await LocalPreferences.setCurrencySymbolPosition(payload.currencySymbolPosition);
    await LocalPreferences.setCurrencyDecimals(payload.currencyDecimals);
    await LocalPreferences.setBillingTaxMode(payload.billingTaxMode);
    await LocalPreferences.setRestaurantSettlementMode(payload.restaurantSettlementMode);

    DateTimeService.instance.updateTimeZone(payload.timeZone);
    CurrencyService.updateFromSettings(payload);

    try {
      final res = await ApiClient.post(
        ApiEndpoints.settings,
        payload.toJson(),
      );
      if (res['data'] != null && res['data'] is Map) {
        final serverSettings = SystemSettings.fromJson(res['data']);
        if (serverSettings.devicePrinterMappings.isNotEmpty) {
          final merged = Map<String, dynamic>.from(payload.devicePrinterMappings);
          merged.addAll(serverSettings.devicePrinterMappings);
          settings!.devicePrinterMappings = merged;
          await LocalPreferences.setDevicePrinterMappings(merged);
        }
      }
    } catch (_) {}

    // Ensure user-selected KOT print preferences and currency remain intact after save
    settings!.enableKotPrint = payload.enableKotPrint;
    settings!.kotPrintMode = payload.kotPrintMode;
    settings!.billingCountry = payload.billingCountry;
    settings!.baseCurrencySymbol = payload.baseCurrencySymbol;
    settings!.baseCurrencyCode = payload.baseCurrencyCode;
    settings!.currencySymbolPosition = payload.currencySymbolPosition;
    settings!.currencyDecimals = payload.currencyDecimals;
    settings!.billingTaxMode = payload.billingTaxMode;

    loading = false;
    notifyListeners();
  }

  Future<bool> updateSettings(SystemSettings payload) async {
    await save(payload);
    return true;
  }
}

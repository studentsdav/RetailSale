import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/config/date_time_service.dart';
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
    if (settings == null) {
      settings = SystemSettings.fromJson({});
      if (cachedMappings.isNotEmpty) {
        settings!.devicePrinterMappings = Map<String, dynamic>.from(cachedMappings);
      }
    } else if (settings!.devicePrinterMappings.isEmpty && cachedMappings.isNotEmpty) {
      settings!.devicePrinterMappings = Map<String, dynamic>.from(cachedMappings);
    }
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

    if (settings != null) {
      await LocalPreferences.setTimeZone(settings!.timeZone);
      DateTimeService.instance.updateTimeZone(settings!.timeZone);
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
    DateTimeService.instance.updateTimeZone(payload.timeZone);

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

    // Ensure user-selected KOT print preferences remain intact after save
    settings!.enableKotPrint = payload.enableKotPrint;
    settings!.kotPrintMode = payload.kotPrintMode;

    loading = false;
    notifyListeners();
  }
}

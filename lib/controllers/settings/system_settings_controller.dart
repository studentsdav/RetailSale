import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/settings/local_preferences.dart';
import '../../models/inventory/settings/system_settings_model.dart';

class SystemSettingsController extends ChangeNotifier {
  bool loading = false;
  SystemSettings? settings;

  /// LOAD SETTINGS
  Future<void> load() async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.get(ApiEndpoints.settings);
      settings = SystemSettings.fromJson(res['data']);
    } catch (_) {
      settings ??= SystemSettings(
        autoReorder: true,
        allowNegativeStock: false,
        damageApprovalRequired: true,
        enableAuditLog: true,
        autoPrintOnSave: false,
        enableItemImagesInSales: false,
        printMode: 'PRINT_DIALOG',
        defaultPrinterName: '',
        defaultPrinterUrl: '',
        billingCountry: 'India',
        billingTaxMode: 'CGST_SGST',
        billFormat: 'A4',
        defaultCharges: const [],
        isCloudEnabled: false,
        enableAppSubscription: false,
        enablePaymentGateway: false,
        paymentGatewayProvider: 'SANDBOX',
        paymentGatewayApiKey: '',
        paymentGatewaySecretKey: '',
        merchantUpiId: '',
        subDeliveryChargeEnabled: false,
        subDeliveryChargeName: '',
        subDeliveryChargeAmount: 0,
        subDeliveryChargeType: 'FLAT',
        subDeliveryChargeGstPercent: 0,
        subDeliveryFreeAbove: 0,
        enableSalespersonTagging: false,
        billCopiesCount: 1,
        showBrandName: true,
      );
    }

    final localCopies = await LocalPreferences.getBillCopiesCount();
    if (localCopies != null && localCopies > 0 && settings != null) {
      settings!.billCopiesCount = localCopies;
    }

    loading = false;
    notifyListeners();
  }

  /// SAVE SETTINGS
  Future<void> save(SystemSettings payload) async {
    loading = true;
    notifyListeners();

    await LocalPreferences.setBillCopiesCount(payload.billCopiesCount);

    try {
      await ApiClient.post(
        ApiEndpoints.settings,
        payload.toJson(),
      );
    } catch (_) {}

    settings = payload;
    loading = false;
    notifyListeners();
  }
}

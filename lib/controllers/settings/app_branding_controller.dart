import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/config/app_brand.dart';
import '../../core/settings/local_preferences.dart';
import '../../models/settings/app_branding_model.dart';

class AppBrandingController extends ChangeNotifier {
  AppBrandingModel _branding = AppBrandingModel.defaults();
  bool loading = false;

  AppBrandingModel get branding => _branding;

  Future<void> loadLocal() async {
    _branding = await LocalPreferences.getAppBranding();
    AppBrand.apply(_branding);
    notifyListeners();
  }

  Future<void> loadFromServer() async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.get(ApiEndpoints.appBranding);
      _branding = AppBrandingModel.fromJson(
        Map<String, dynamic>.from(res['data']),
      );
      await LocalPreferences.setAppBranding(_branding);
      AppBrand.apply(_branding);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> save(AppBrandingModel payload) async {
    loading = true;
    notifyListeners();

    try {
      final normalized = _normalize(payload);
      final res = await ApiClient.post(
        ApiEndpoints.appBranding,
        normalized.toJson(),
      );
      _branding = AppBrandingModel.fromJson(
        Map<String, dynamic>.from(res['data'] ?? normalized.toJson()),
      );
      await LocalPreferences.setAppBranding(_branding);
      AppBrand.apply(_branding);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void updateLocal(AppBrandingModel value) {
    _branding = _normalize(value);
    AppBrand.apply(_branding);
    notifyListeners();
  }

  AppBrandingModel _normalize(AppBrandingModel value) {
    final defaults = AppBrandingModel.defaults();
    final companyName =
        value.companyName.trim().isEmpty ? defaults.companyName : value.companyName.trim();

    return value.copyWith(
      companyName: companyName,
      productName:
          value.productName.trim().isEmpty ? defaults.productName : value.productName.trim(),
      supportEmail:
          value.supportEmail.trim().isEmpty ? defaults.supportEmail : value.supportEmail.trim(),
      supportWebsite: value.supportWebsite.trim().isEmpty
          ? defaults.supportWebsite
          : value.supportWebsite.trim(),
      supportPhone:
          value.supportPhone.trim().isEmpty ? defaults.supportPhone : value.supportPhone.trim(),
      openSourceNotice: value.openSourceNotice.trim().isEmpty
          ? defaults.openSourceNotice
          : value.openSourceNotice.trim(),
      poweredByLabel: value.poweredByLabel.trim().isEmpty
          ? 'Powered by $companyName'
          : value.poweredByLabel.trim(),
      themeKey: value.themeKey.trim().isEmpty ? defaults.themeKey : value.themeKey.trim(),
    );
  }
}

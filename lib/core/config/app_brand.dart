import '../../models/settings/app_branding_model.dart';

class AppBrand {
  AppBrand._();

  // Permanent, immutable core brand identity (Cannot be altered or overridden by outlet customization)
  static const String coreOwner = 'Famalth Business Solutions';
  static const String coreBrand = 'FAMALTH LYNX';
  static const String permanentWatermark = 'Powered by Famalth • FAMALTH LYNX Ecosystem';
  static const String permanentCopyright = '© Famalth Business Solutions. All rights reserved.';

  static AppBrandingModel _current = AppBrandingModel.defaults();

  static String get companyName => _current.companyName;
  static String get productName => _current.productName;
  static String get supportEmail => _current.supportEmail;
  static String get supportWebsite => _current.supportWebsite;
  static String get supportPhone => _current.supportPhone;
  static String get openSourceNotice => _current.openSourceNotice;
  static String get poweredByLabel => permanentWatermark; // Permanent Famalth watermark
  static String get themeKey => _current.themeKey;
  static AppBrandingModel get current => _current;

  static void apply(AppBrandingModel value) {
    _current = value;
  }
}

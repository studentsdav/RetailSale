import '../../models/settings/app_branding_model.dart';

class AppBrand {
  AppBrand._();

  static AppBrandingModel _current = AppBrandingModel.defaults();

  static String get companyName => _current.companyName;
  static String get productName => _current.productName;
  static String get supportEmail => _current.supportEmail;
  static String get supportWebsite => _current.supportWebsite;
  static String get supportPhone => _current.supportPhone;
  static String get openSourceNotice => _current.openSourceNotice;
  static String get poweredByLabel => _current.poweredByLabel;
  static String get themeKey => _current.themeKey;
  static AppBrandingModel get current => _current;

  static void apply(AppBrandingModel value) {
    _current = value;
  }
}

class AppBrandingModel {
  final String companyName;
  final String productName;
  final String supportEmail;
  final String supportWebsite;
  final String supportPhone;
  final String openSourceNotice;
  final String poweredByLabel;
  final String themeKey;
  final String homeBgImagePath;
  final String homeBgImageSize;
  final String homeThemeStyle;

  const AppBrandingModel({
    required this.companyName,
    required this.productName,
    required this.supportEmail,
    required this.supportWebsite,
    required this.supportPhone,
    required this.openSourceNotice,
    required this.poweredByLabel,
    required this.themeKey,
    required this.homeBgImagePath,
    required this.homeBgImageSize,
    required this.homeThemeStyle,
  });

  factory AppBrandingModel.defaults() {
    return const AppBrandingModel(
      companyName: 'Famalth Business Solutions',
      productName: 'FAMALTH LYNX',
      supportEmail: 'help@famalth.com',
      supportWebsite: 'www.famalth.com',
      supportPhone: '+91-00000-00000',
      openSourceNotice:
          'Famalth Business Solutions branding is applied across the product. Third-party packages remain available under their respective open-source licenses.',
      poweredByLabel: 'Powered by FAMALTH LYNX Ecosystem',
      themeKey: 'famalth_classic',
      homeBgImagePath: '',
      homeBgImageSize: 'Cover',
      homeThemeStyle: 'Default',
    );
  }

  factory AppBrandingModel.fromJson(Map<String, dynamic> json) {
    final defaults = AppBrandingModel.defaults();
    final companyName =
        (json['company_name'] ?? defaults.companyName).toString().trim();

    return AppBrandingModel(
      companyName: companyName.isEmpty ? defaults.companyName : companyName,
      productName: _valueOrDefault(json['product_name'], defaults.productName),
      supportEmail: _valueOrDefault(
        json['support_email'],
        defaults.supportEmail,
      ),
      supportWebsite: _valueOrDefault(
        json['support_website'],
        defaults.supportWebsite,
      ),
      supportPhone: _valueOrDefault(
        json['support_phone'],
        defaults.supportPhone,
      ),
      openSourceNotice: _valueOrDefault(
        json['open_source_notice'],
        defaults.openSourceNotice,
      ),
      poweredByLabel: 'Powered by Famalth • FAMALTH LYNX Ecosystem',
      themeKey: _valueOrDefault(json['theme_key'], defaults.themeKey),
      homeBgImagePath: _valueOrDefault(json['home_bg_image_path'], defaults.homeBgImagePath),
      homeBgImageSize: _valueOrDefault(json['home_bg_image_size'], defaults.homeBgImageSize),
      homeThemeStyle: _valueOrDefault(json['home_theme_style'], defaults.homeThemeStyle),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_name': companyName,
      'product_name': productName,
      'support_email': supportEmail,
      'support_website': supportWebsite,
      'support_phone': supportPhone,
      'open_source_notice': openSourceNotice,
      'powered_by_label': poweredByLabel,
      'theme_key': themeKey,
      'home_bg_image_path': homeBgImagePath,
      'home_bg_image_size': homeBgImageSize,
      'home_theme_style': homeThemeStyle,
    };
  }

  AppBrandingModel copyWith({
    String? companyName,
    String? productName,
    String? supportEmail,
    String? supportWebsite,
    String? supportPhone,
    String? openSourceNotice,
    String? poweredByLabel,
    String? themeKey,
    String? homeBgImagePath,
    String? homeBgImageSize,
    String? homeThemeStyle,
  }) {
    return AppBrandingModel(
      companyName: companyName ?? this.companyName,
      productName: productName ?? this.productName,
      supportEmail: supportEmail ?? this.supportEmail,
      supportWebsite: supportWebsite ?? this.supportWebsite,
      supportPhone: supportPhone ?? this.supportPhone,
      openSourceNotice: openSourceNotice ?? this.openSourceNotice,
      poweredByLabel: poweredByLabel ?? this.poweredByLabel,
      themeKey: themeKey ?? this.themeKey,
      homeBgImagePath: homeBgImagePath ?? this.homeBgImagePath,
      homeBgImageSize: homeBgImageSize ?? this.homeBgImageSize,
      homeThemeStyle: homeThemeStyle ?? this.homeThemeStyle,
    );
  }

  static String _valueOrDefault(dynamic value, String fallback) {
    final text = (value ?? fallback).toString().trim();
    return text.isEmpty ? fallback : text;
  }
}

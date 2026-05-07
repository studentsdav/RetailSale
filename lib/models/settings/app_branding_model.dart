class AppBrandingModel {
  final String companyName;
  final String productName;
  final String supportEmail;
  final String supportWebsite;
  final String supportPhone;
  final String openSourceNotice;
  final String poweredByLabel;
  final String themeKey;

  const AppBrandingModel({
    required this.companyName,
    required this.productName,
    required this.supportEmail,
    required this.supportWebsite,
    required this.supportPhone,
    required this.openSourceNotice,
    required this.poweredByLabel,
    required this.themeKey,
  });

  factory AppBrandingModel.defaults() {
    return const AppBrandingModel(
      companyName: 'Famalth Technologies',
      productName: 'Famalth Inventory',
      supportEmail: 'support@famalth.com',
      supportWebsite: 'www.famalth.com',
      supportPhone: '+91-00000-00000',
      openSourceNotice:
          'Famalth Technologies branding is applied across the product. Third-party packages remain available under their respective open-source licenses.',
      poweredByLabel: 'Powered by Famalth Technologies',
      themeKey: 'famalth_classic',
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
      poweredByLabel: _valueOrDefault(
        json['powered_by_label'],
        'Powered by ${companyName.isEmpty ? defaults.companyName : companyName}',
      ),
      themeKey: _valueOrDefault(json['theme_key'], defaults.themeKey),
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
    );
  }

  static String _valueOrDefault(dynamic value, String fallback) {
    final text = (value ?? fallback).toString().trim();
    return text.isEmpty ? fallback : text;
  }
}

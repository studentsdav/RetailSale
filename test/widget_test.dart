import 'package:flutter_test/flutter_test.dart';
import 'package:retailpos/models/settings/app_branding_model.dart';

void main() {
  group('AppBrandingModel Unit Tests', () {
    test('AppBrandingModel.defaults provides correct default branding values', () {
      final defaults = AppBrandingModel.defaults();

      expect(defaults.companyName, 'Famalth Business Solutions');
      expect(defaults.productName, 'FAMALTH LYNX');
      expect(defaults.supportEmail, 'help@famalth.com');
      expect(defaults.poweredByLabel, 'Powered by FAMALTH LYNX Ecosystem');
    });

    test('AppBrandingModel.fromJson correctly parses JSON overrides', () {
      final json = {
        'company_name': 'Custom Enterprise POS',
        'support_email': 'support@custompos.com',
      };

      final model = AppBrandingModel.fromJson(json);

      expect(model.companyName, 'Custom Enterprise POS');
      expect(model.supportEmail, 'support@custompos.com');
      expect(model.productName, 'FAMALTH LYNX'); // Falls back to default
    });
  });
}

import 'dart:convert';
import '../billing_charge_model.dart';

class SystemSettings {
  bool autoReorder;
  bool allowNegativeStock;
  bool damageApprovalRequired;
  bool enableAuditLog;
  bool autoPrintOnSave;
  bool enableItemImagesInSales;
  String printMode;
  String defaultPrinterName;
  String defaultPrinterUrl;
  String billingCountry;
  String timeZone;
  String billingTaxMode;
  String billFormat;
  List<BillingCharge> defaultCharges;
  bool isCloudEnabled;
  /// When true, daily subscription home-delivery orders are auto-accepted
  /// and appear directly in the retailer console. When false, they are
  /// created as DRAFT bills in the sale screen for manual confirmation.
  bool enableAppSubscription;
  bool enablePaymentGateway;
  String paymentGatewayProvider;
  String paymentGatewayApiKey;
  String paymentGatewaySecretKey;
  String merchantUpiId;
  bool subDeliveryChargeEnabled;
  String subDeliveryChargeName;
  double subDeliveryChargeAmount;
  String subDeliveryChargeType;
  double subDeliveryChargeGstPercent;
  double subDeliveryFreeAbove;
  bool enableSalespersonTagging;
  int billCopiesCount;
  bool showBrandName;
  bool enableTokenSystem;
  int tokenCopiesCount;
  String kotPrintMode; // 'DIRECT', 'DIALOG', 'NONE' (KDS Only)
  bool enableKotPrint;
  Map<String, dynamic> devicePrinterMappings;
  String baseCurrencyCode;
  String baseCurrencySymbol;
  String currencySymbolPosition; // 'BEFORE', 'AFTER'
  int currencyDecimals;
  List<Map<String, dynamic>> paymentModes;
  Map<String, dynamic> receiptTemplateConfig;
  Map<String, dynamic> a4TemplateConfig;
  Map<String, dynamic> a5TemplateConfig;
  Map<String, dynamic> kotTemplateConfig;
  Map<String, dynamic> tokenTemplateConfig;
  String restaurantSettlementMode; // 'DIRECT' or 'AFTER_BILL_PRINT'

  SystemSettings({
    required this.autoReorder,
    required this.allowNegativeStock,
    required this.damageApprovalRequired,
    required this.enableAuditLog,
    required this.autoPrintOnSave,
    required this.enableItemImagesInSales,
    required this.printMode,
    required this.defaultPrinterName,
    required this.defaultPrinterUrl,
    required this.billingCountry,
    this.timeZone = 'Asia/Kolkata',
    required this.billingTaxMode,
    required this.billFormat,
    required this.defaultCharges,
    required this.isCloudEnabled,
    required this.enableAppSubscription,
    required this.enablePaymentGateway,
    required this.paymentGatewayProvider,
    required this.paymentGatewayApiKey,
    required this.paymentGatewaySecretKey,
    required this.merchantUpiId,
    required this.subDeliveryChargeEnabled,
    required this.subDeliveryChargeName,
    required this.subDeliveryChargeAmount,
    required this.subDeliveryChargeType,
    required this.subDeliveryChargeGstPercent,
    required this.subDeliveryFreeAbove,
    required this.enableSalespersonTagging,
    this.billCopiesCount = 1,
    required this.showBrandName,
    this.enableTokenSystem = false,
    this.tokenCopiesCount = 1,
    this.kotPrintMode = 'DIRECT',
    this.enableKotPrint = true,
    Map<String, dynamic>? devicePrinterMappings,
    this.baseCurrencyCode = 'KES',
    this.baseCurrencySymbol = 'KSh',
    this.currencySymbolPosition = 'BEFORE',
    this.currencyDecimals = 2,
    List<Map<String, dynamic>>? paymentModes,
    Map<String, dynamic>? receiptTemplateConfig,
    Map<String, dynamic>? a4TemplateConfig,
    Map<String, dynamic>? a5TemplateConfig,
    Map<String, dynamic>? kotTemplateConfig,
    Map<String, dynamic>? tokenTemplateConfig,
    this.restaurantSettlementMode = 'DIRECT',
  })  : devicePrinterMappings = devicePrinterMappings ?? {},
        paymentModes = paymentModes ??
            [
              {'id': 'CASH', 'name': 'Cash', 'enabled': true},
              {'id': 'CARD', 'name': 'Card', 'enabled': true},
              {'id': 'MPESA_TILL', 'name': 'M-Pesa Till', 'enabled': true},
              {'id': 'MPESA_PAYBILL', 'name': 'M-Pesa Paybill', 'enabled': true},
              {'id': 'BANK_TRANSFER', 'name': 'Bank Transfer', 'enabled': true},
            ],
        receiptTemplateConfig = receiptTemplateConfig ?? {},
        a4TemplateConfig = a4TemplateConfig ?? {},
        a5TemplateConfig = a5TemplateConfig ?? {},
        kotTemplateConfig = kotTemplateConfig ?? {},
        tokenTemplateConfig = tokenTemplateConfig ?? {};

  static bool _parseBool(dynamic val, [bool fallback = false]) {
    if (val == null) return fallback;
    if (val is bool) return val;
    if (val is num) return val != 0;
    final s = val.toString().trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return fallback;
  }

  factory SystemSettings.fromJson(Map<String, dynamic> json) {
    final rawCharges = json['default_charges'] ?? json['defaultCharges'];
    final rawDevicePrinters = json['device_printer_mappings'] ?? json['devicePrinterMappings'];
    return SystemSettings(
      autoReorder: _parseBool(json['auto_reorder'] ?? json['autoReorder'], true),
      allowNegativeStock: _parseBool(json['allow_negative_stock'] ?? json['allowNegativeStock'], false),
      damageApprovalRequired: _parseBool(json['damage_approval_required'] ?? json['damageApprovalRequired'], true),
      enableAuditLog: _parseBool(json['enable_audit_log'] ?? json['enableAuditLog'], true),
      autoPrintOnSave: _parseBool(json['auto_print_on_save'] ?? json['autoPrintOnSave'], false),
      enableItemImagesInSales: _parseBool(json['enable_item_images_in_sales'] ?? json['enableItemImagesInSales'], false),
      printMode: (json['print_mode'] ?? json['printMode'] ?? 'PRINT_DIALOG').toString(),
      defaultPrinterName: (json['default_printer_name'] ?? json['defaultPrinterName'] ?? '').toString(),
      defaultPrinterUrl: (json['default_printer_url'] ?? json['defaultPrinterUrl'] ?? '').toString(),
      billingCountry: (json['billing_country'] ?? json['billingCountry'] ?? 'India').toString(),
      timeZone: (json['time_zone'] ?? json['timeZone'] ?? 'Asia/Kolkata').toString(),
      billingTaxMode: (json['billing_tax_mode'] ?? json['billingTaxMode'] ?? 'CGST_SGST').toString(),
      billFormat: (json['bill_format'] ?? json['billFormat'] ?? 'A4').toString(),
      billCopiesCount: int.tryParse(json['bill_copies_count']?.toString() ?? json['billCopiesCount']?.toString() ?? '1') ?? 1,
      showBrandName: _parseBool(json['show_brand_name'] ?? json['showBrandName'], true),
      enableTokenSystem: _parseBool(json['enable_token_system'] ?? json['enableTokenSystem'], false),
      tokenCopiesCount: int.tryParse(json['token_copies_count']?.toString() ?? json['tokenCopiesCount']?.toString() ?? '1') ?? 1,
      kotPrintMode: (json['kot_print_mode'] ?? json['kotPrintMode'] ?? 'DIRECT').toString(),
      enableKotPrint: _parseBool(json['enable_kot_print'] ?? json['enableKotPrint'], true),
      devicePrinterMappings: () {
        if (rawDevicePrinters is Map) {
          return Map<String, dynamic>.from(rawDevicePrinters);
        } else if (rawDevicePrinters is String && rawDevicePrinters.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(rawDevicePrinters);
            if (decoded is Map) {
              return Map<String, dynamic>.from(decoded);
            }
          } catch (_) {}
        }
        return <String, dynamic>{};
      }(),
      isCloudEnabled: _parseBool(json['is_cloud_enabled'] ?? json['isCloudEnabled'], false),
      enableAppSubscription: _parseBool(json['enable_app_subscription'] ?? json['enableAppSubscription'], false),
      enablePaymentGateway: _parseBool(json['enable_payment_gateway'] ?? json['enablePaymentGateway'], false),
      paymentGatewayProvider: (json['payment_gateway_provider'] ?? json['paymentGatewayProvider'] ?? 'SANDBOX').toString(),
      paymentGatewayApiKey: (json['payment_gateway_api_key'] ?? json['paymentGatewayApiKey'] ?? '').toString(),
      paymentGatewaySecretKey: (json['payment_gateway_secret_key'] ?? json['paymentGatewaySecretKey'] ?? '').toString(),
      merchantUpiId: (json['merchant_upi_id'] ?? json['merchantUpiId'] ?? '').toString(),
      subDeliveryChargeEnabled: _parseBool(json['sub_delivery_charge_enabled'] ?? json['subDeliveryChargeEnabled'], false),
      subDeliveryChargeName: (json['sub_delivery_charge_name'] ?? json['subDeliveryChargeName'] ?? 'Subscription Delivery').toString(),
      subDeliveryChargeAmount: double.tryParse(json['sub_delivery_charge_amount']?.toString() ?? json['subDeliveryChargeAmount']?.toString() ?? '0.0') ?? 0.0,
      subDeliveryChargeType: (json['sub_delivery_charge_type'] ?? json['subDeliveryChargeType'] ?? 'FLAT').toString(),
      subDeliveryChargeGstPercent: double.tryParse(json['sub_delivery_charge_gst_percent']?.toString() ?? json['subDeliveryChargeGstPercent']?.toString() ?? '0.0') ?? 0.0,
      subDeliveryFreeAbove: double.tryParse(json['sub_delivery_free_above']?.toString() ?? json['subDeliveryFreeAbove']?.toString() ?? '0.0') ?? 0.0,
      enableSalespersonTagging: _parseBool(json['enable_salesperson_tagging'] ?? json['enableSalespersonTagging'], false),
      baseCurrencyCode: (json['base_currency_code'] ?? json['baseCurrencyCode'] ?? 'KES').toString(),
      baseCurrencySymbol: (json['base_currency_symbol'] ?? json['baseCurrencySymbol'] ?? 'KSh').toString(),
      currencySymbolPosition: (json['currency_symbol_position'] ?? json['currencySymbolPosition'] ?? 'BEFORE').toString(),
      currencyDecimals: int.tryParse(json['currency_decimals']?.toString() ?? json['currencyDecimals']?.toString() ?? '2') ?? 2,
      paymentModes: () {
        final rawPM = json['payment_modes'] ?? json['paymentModes'];
        if (rawPM is List) {
          return rawPM.map((e) => Map<String, dynamic>.from(e)).toList();
        } else if (rawPM is String && rawPM.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(rawPM);
            if (decoded is List) {
              return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
            }
          } catch (_) {}
        }
        return [
          {'id': 'CASH', 'name': 'Cash', 'enabled': true},
          {'id': 'CARD', 'name': 'Card', 'enabled': true},
          {'id': 'MPESA_TILL', 'name': 'M-Pesa Till', 'enabled': true},
          {'id': 'MPESA_PAYBILL', 'name': 'M-Pesa Paybill', 'enabled': true},
          {'id': 'BANK_TRANSFER', 'name': 'Bank Transfer', 'enabled': true},
        ];
      }(),
      receiptTemplateConfig: () {
        final rawRC = json['receipt_template_config'] ?? json['receiptTemplateConfig'];
        if (rawRC is Map) return Map<String, dynamic>.from(rawRC);
        if (rawRC is String && rawRC.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(rawRC);
            if (decoded is Map) return Map<String, dynamic>.from(decoded);
          } catch (_) {}
        }
        return <String, dynamic>{};
      }(),
      a4TemplateConfig: () {
        final rawA4 = json['a4_template_config'] ?? json['a4TemplateConfig'];
        if (rawA4 is Map) return Map<String, dynamic>.from(rawA4);
        if (rawA4 is String && rawA4.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(rawA4);
            if (decoded is Map) return Map<String, dynamic>.from(decoded);
          } catch (_) {}
        }
        return <String, dynamic>{};
      }(),
      a5TemplateConfig: () {
        final rawA5 = json['a5_template_config'] ?? json['a5TemplateConfig'];
        if (rawA5 is Map) return Map<String, dynamic>.from(rawA5);
        if (rawA5 is String && rawA5.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(rawA5);
            if (decoded is Map) return Map<String, dynamic>.from(decoded);
          } catch (_) {}
        }
        return <String, dynamic>{};
      }(),
      kotTemplateConfig: () {
        final rawKC = json['kot_template_config'] ?? json['kotTemplateConfig'];
        if (rawKC is Map) return Map<String, dynamic>.from(rawKC);
        if (rawKC is String && rawKC.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(rawKC);
            if (decoded is Map) return Map<String, dynamic>.from(decoded);
          } catch (_) {}
        }
        return <String, dynamic>{};
      }(),
      tokenTemplateConfig: () {
        final rawTC = json['token_template_config'] ?? json['tokenTemplateConfig'];
        if (rawTC is Map) return Map<String, dynamic>.from(rawTC);
        if (rawTC is String && rawTC.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(rawTC);
            if (decoded is Map) return Map<String, dynamic>.from(decoded);
          } catch (_) {}
        }
        return <String, dynamic>{};
      }(),
      restaurantSettlementMode: (json['restaurant_settlement_mode'] ?? json['restaurantSettlementMode'] ?? 'DIRECT').toString(),
      defaultCharges: rawCharges is List
          ? rawCharges
              .map((e) => BillingCharge.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [
              BillingCharge(
                name: 'Packing',
                code: 'PACKING',
                amount: 0,
                calculationValue: 0,
                taxable: false,
                autoApply: false,
                isEnabled: false,
                taxType: 'GST',
                taxPercent: 0,
              ),
              BillingCharge(
                name: 'Delivery',
                code: 'DELIVERY',
                amount: 0,
                calculationValue: 0,
                taxable: false,
                autoApply: false,
                isEnabled: false,
                taxType: 'GST',
                taxPercent: 0,
              ),
              BillingCharge(
                name: 'Service',
                code: 'SERVICE',
                amount: 0,
                calculationValue: 0,
                taxable: false,
                autoApply: false,
                isEnabled: false,
                taxType: 'GST',
                taxPercent: 0,
              ),
            ],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'auto_reorder': autoReorder,
      'allow_negative_stock': allowNegativeStock,
      'damage_approval_required': damageApprovalRequired,
      'enable_audit_log': enableAuditLog,
      'auto_print_on_save': autoPrintOnSave,
      'enable_item_images_in_sales': enableItemImagesInSales,
      'print_mode': printMode,
      'default_printer_name': defaultPrinterName,
      'default_printer_url': defaultPrinterUrl,
      'billing_country': billingCountry,
      'time_zone': timeZone,
      'billing_tax_mode': billingTaxMode,
      'bill_format': billFormat,
      'base_currency_code': baseCurrencyCode,
      'base_currency_symbol': baseCurrencySymbol,
      'currency_symbol_position': currencySymbolPosition,
      'currency_decimals': currencyDecimals,
      'payment_modes': paymentModes,
      'receipt_template_config': receiptTemplateConfig,
      'a4_template_config': a4TemplateConfig,
      'a5_template_config': a5TemplateConfig,
      'kot_template_config': kotTemplateConfig,
      'token_template_config': tokenTemplateConfig,
      'default_charges':
          defaultCharges.map((charge) => charge.toJson()).toList(),
      'is_cloud_enabled': isCloudEnabled,
      'enable_app_subscription': enableAppSubscription,
      'enable_payment_gateway': enablePaymentGateway,
      'payment_gateway_provider': paymentGatewayProvider,
      'payment_gateway_api_key': paymentGatewayApiKey,
      'payment_gateway_secret_key': paymentGatewaySecretKey,
      'merchant_upi_id': merchantUpiId,
      'sub_delivery_charge_enabled': subDeliveryChargeEnabled,
      'sub_delivery_charge_name': subDeliveryChargeName,
      'sub_delivery_charge_amount': subDeliveryChargeAmount,
      'sub_delivery_charge_type': subDeliveryChargeType,
      'sub_delivery_charge_gst_percent': subDeliveryChargeGstPercent,
      'sub_delivery_free_above': subDeliveryFreeAbove,
      'enable_salesperson_tagging': enableSalespersonTagging,
      'bill_copies_count': billCopiesCount,
      'show_brand_name': showBrandName,
      'enable_token_system': enableTokenSystem,
      'token_copies_count': tokenCopiesCount,
      'kot_print_mode': kotPrintMode,
      'enable_kot_print': enableKotPrint,
      'device_printer_mappings': devicePrinterMappings,
      'restaurant_settlement_mode': restaurantSettlementMode,
    };
  }
}

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
  });

  factory SystemSettings.fromJson(Map<String, dynamic> json) {
    final rawCharges = json['default_charges'];
    return SystemSettings(
      autoReorder: json['auto_reorder'] ?? true,
      allowNegativeStock: json['allow_negative_stock'] ?? false,
      damageApprovalRequired: json['damage_approval_required'] ?? true,
      enableAuditLog: json['enable_audit_log'] ?? true,
      autoPrintOnSave: json['auto_print_on_save'] ?? false,
      enableItemImagesInSales: json['enable_item_images_in_sales'] ?? false,
      printMode: json['print_mode'] ?? 'PRINT_DIALOG',
      defaultPrinterName: json['default_printer_name'] ?? '',
      defaultPrinterUrl: json['default_printer_url'] ?? '',
      billingCountry: json['billing_country'] ?? 'India',
      billingTaxMode: json['billing_tax_mode'] ?? 'CGST_SGST',
      billFormat: json['bill_format'] ?? 'A4',
      isCloudEnabled: json['is_cloud_enabled'] ?? false,
      enableAppSubscription: json['enable_app_subscription'] ?? false,
      enablePaymentGateway: json['enable_payment_gateway'] ?? false,
      paymentGatewayProvider: json['payment_gateway_provider'] ?? 'SANDBOX',
      paymentGatewayApiKey: json['payment_gateway_api_key'] ?? '',
      paymentGatewaySecretKey: json['payment_gateway_secret_key'] ?? '',
      merchantUpiId: json['merchant_upi_id'] ?? '',
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
      'billing_tax_mode': billingTaxMode,
      'bill_format': billFormat,
      'default_charges':
          defaultCharges.map((charge) => charge.toJson()).toList(),
      'is_cloud_enabled': isCloudEnabled,
      'enable_app_subscription': enableAppSubscription,
      'enable_payment_gateway': enablePaymentGateway,
      'payment_gateway_provider': paymentGatewayProvider,
      'payment_gateway_api_key': paymentGatewayApiKey,
      'payment_gateway_secret_key': paymentGatewaySecretKey,
      'merchant_upi_id': merchantUpiId,
    };
  }
}

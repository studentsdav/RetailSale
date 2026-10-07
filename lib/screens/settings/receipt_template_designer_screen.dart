import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/settings/system_settings_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../core/currency/currency_service.dart';
import '../../core/config/app_brand.dart';

class ReceiptTemplateDesignerScreen extends StatefulWidget {
  const ReceiptTemplateDesignerScreen({super.key});

  @override
  State<ReceiptTemplateDesignerScreen> createState() => _ReceiptTemplateDesignerScreenState();
}

class _ReceiptTemplateDesignerScreenState extends State<ReceiptTemplateDesignerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const Color primaryColor = Color(0xFF0B5CAD);

  // =========================================================================
  // 1. 80mm / Thermal Bill Template Controllers & Toggles
  // =========================================================================
  final _billHeaderTitleCtrl = TextEditingController();
  final _billHeaderSubtextCtrl = TextEditingController();
  final _billFooterNoteCtrl = TextEditingController();
  final _billTaxRegNoCtrl = TextEditingController();
  final _billTermsCtrl = TextEditingController();
  final _billResellerFooterCtrl = TextEditingController();

  bool _billShowLogo = true;
  bool _billShowAddress = true;
  bool _billShowPhone = true;
  bool _billShowEmail = true;
  bool _billShowCustomer = true;
  bool _billShowCashier = true;
  bool _billShowToken = true;
  bool _billShowBrand = true;
  bool _billShowDiscounts = true;
  bool _billShowTaxBreakup = true;
  bool _billShowBankDetails = true;
  bool _billShowUpiQr = true;
  bool _billShowResellerFooter = true;
  bool _billShowCurrency = true;
  String _billFontSize = 'MEDIUM'; // SMALL, MEDIUM, LARGE
  String _billThermalWidth = '80mm'; // 80mm, 76mm, 58mm

  // =========================================================================
  // 2. A4 Full Invoice Template Controllers & Toggles
  // =========================================================================
  final _a4HeaderTitleCtrl = TextEditingController();
  final _a4HeaderSubtextCtrl = TextEditingController();
  final _a4TaxRegNoCtrl = TextEditingController();
  final _a4PanNoCtrl = TextEditingController();
  final _a4FooterNoteCtrl = TextEditingController();
  final _a4TermsCtrl = TextEditingController();
  final _a4BankNameCtrl = TextEditingController();
  final _a4BankAccountNoCtrl = TextEditingController();
  final _a4BankIfscCtrl = TextEditingController();
  final _a4MpesaPaybillCtrl = TextEditingController();
  final _a4SignatoryLabelCtrl = TextEditingController();

  bool _a4ShowLogo = true;
  bool _a4ShowCompanyAddress = true;
  bool _a4ShowCompanyContact = true;
  bool _a4ShowTaxReg = true;
  bool _a4ShowBuyerDetails = true;
  bool _a4ShowShippingDetails = true;
  bool _a4ShowHsnCode = true;
  bool _a4ShowBrand = true;
  bool _a4ShowItemDiscount = true;
  bool _a4ShowTaxBreakup = true;
  bool _a4ShowAmountInWords = true;
  bool _a4ShowBankDetails = true;
  bool _a4ShowQrCode = true;
  bool _a4ShowTermsAndConditions = true;
  bool _a4ShowSignatureBox = true;
  bool _a4ShowCurrency = true;
  String _a4ThemeColor = 'BLUE'; // BLUE, SLATE, EMERALD, CRIMSON
  String _a4FontSize = 'MEDIUM'; // SMALL, MEDIUM, LARGE

  // =========================================================================
  // 3. A5 Half-Sheet Invoice Template Controllers & Toggles
  // =========================================================================
  final _a5HeaderTitleCtrl = TextEditingController();
  final _a5HeaderSubtextCtrl = TextEditingController();
  final _a5TaxRegNoCtrl = TextEditingController();
  final _a5PanNoCtrl = TextEditingController();
  final _a5FooterNoteCtrl = TextEditingController();
  final _a5TermsCtrl = TextEditingController();
  final _a5BankNameCtrl = TextEditingController();
  final _a5BankAccountNoCtrl = TextEditingController();
  final _a5BankIfscCtrl = TextEditingController();
  final _a5MpesaPaybillCtrl = TextEditingController();
  final _a5SignatoryLabelCtrl = TextEditingController();

  bool _a5ShowLogo = true;
  bool _a5ShowCompanyAddress = true;
  bool _a5ShowCompanyContact = true;
  bool _a5ShowTaxReg = true;
  bool _a5ShowBuyerDetails = true;
  bool _a5ShowShippingDetails = true;
  bool _a5ShowHsnCode = true;
  bool _a5ShowBrand = true;
  bool _a5ShowItemDiscount = true;
  bool _a5ShowTaxBreakup = true;
  bool _a5ShowAmountInWords = true;
  bool _a5ShowBankDetails = true;
  bool _a5ShowQrCode = true;
  bool _a5ShowTermsAndConditions = true;
  bool _a5ShowSignatureBox = true;
  bool _a5ShowCurrency = true;
  String _a5ThemeColor = 'BLUE'; // BLUE, SLATE, EMERALD, CRIMSON
  String _a5FontSize = 'MEDIUM'; // SMALL, MEDIUM, LARGE

  // =========================================================================
  // 4. KOT Kitchen Ticket Template Controllers & Toggles
  // =========================================================================
  final _kotHeaderTitleCtrl = TextEditingController(text: 'KITCHEN ORDER TICKET');
  final _kotFooterNoteCtrl = TextEditingController();

  bool _kotShowStation = true;
  bool _kotShowTable = true;
  bool _kotShowGuests = true;
  bool _kotShowWaiter = true;
  bool _kotShowTimestamp = true;
  bool _kotShowNotes = true;
  bool _kotShowBrand = true;
  bool _kotShowCutLine = true;
  String _kotFontSize = 'MEDIUM'; // SMALL, MEDIUM, LARGE

  // =========================================================================
  // 4. Token Ticket Template Controllers & Toggles (Tab 4)
  // =========================================================================
  final _tokenHeaderTitleCtrl = TextEditingController(text: 'ORDER TOKEN / QUEUE SLIP');
  final _tokenHeaderSubtextCtrl = TextEditingController();
  final _tokenFooterNoteCtrl = TextEditingController(text: 'Please wait for your token number to be called.');
  final _tokenCounterLabelCtrl = TextEditingController(text: 'COUNTER #1 - PICKUP BAY');

  bool _tokenShowStoreName = true;
  bool _tokenShowBigNumber = true;
  bool _tokenShowOrderNo = true;
  bool _tokenShowTimestamp = true;
  bool _tokenShowCounter = true;
  bool _tokenShowCustomer = true;
  bool _tokenShowItemsSummary = true;
  bool _tokenShowItemCount = true;
  bool _tokenShowBarcode = true;
  bool _tokenShowCutLine = true;
  String _tokenBadgeStyle = 'INVERTED_BOX'; // INVERTED_BOX, BORDER_BOX, CIRCLE, MINIMAL
  String _tokenFontSize = 'MEDIUM'; // SMALL, MEDIUM, LARGE
  String _tokenThermalWidth = '80mm'; // 80mm, 58mm

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    Future.microtask(() => _loadSettings());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _billHeaderTitleCtrl.dispose();
    _billHeaderSubtextCtrl.dispose();
    _billFooterNoteCtrl.dispose();
    _billTaxRegNoCtrl.dispose();
    _billTermsCtrl.dispose();
    _billResellerFooterCtrl.dispose();

    _a4HeaderTitleCtrl.dispose();
    _a4HeaderSubtextCtrl.dispose();
    _a4TaxRegNoCtrl.dispose();
    _a4PanNoCtrl.dispose();
    _a4FooterNoteCtrl.dispose();
    _a4TermsCtrl.dispose();
    _a4BankNameCtrl.dispose();
    _a4BankAccountNoCtrl.dispose();
    _a4BankIfscCtrl.dispose();
    _a4MpesaPaybillCtrl.dispose();
    _a4SignatoryLabelCtrl.dispose();

        _a5HeaderTitleCtrl.dispose();
    _a5HeaderSubtextCtrl.dispose();
    _a5TaxRegNoCtrl.dispose();
    _a5PanNoCtrl.dispose();
    _a5FooterNoteCtrl.dispose();
    _a5TermsCtrl.dispose();
    _a5BankNameCtrl.dispose();
    _a5BankAccountNoCtrl.dispose();
    _a5BankIfscCtrl.dispose();
    _a5MpesaPaybillCtrl.dispose();
    _a5SignatoryLabelCtrl.dispose();
    _kotHeaderTitleCtrl.dispose();
    _kotFooterNoteCtrl.dispose();

    _tokenHeaderTitleCtrl.dispose();
    _tokenHeaderSubtextCtrl.dispose();
    _tokenFooterNoteCtrl.dispose();
    _tokenCounterLabelCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    SystemSettingsController settingsCtrl;
    try {
      settingsCtrl = context.read<SystemSettingsController>();
    } catch (_) {
      settingsCtrl = SystemSettingsController();
    }
    final propCtrl = PropertyInfoController();
    await settingsCtrl.load();
    await propCtrl.load();

    final billConfig = settingsCtrl.settings?.receiptTemplateConfig ?? {};
    final a4Config = settingsCtrl.settings?.a4TemplateConfig ?? {};
        final a5Config = settingsCtrl.settings?.a5TemplateConfig ?? {};
    final kotConfig = settingsCtrl.settings?.kotTemplateConfig ?? {};
    final tokenConfig = settingsCtrl.settings?.tokenTemplateConfig ?? {};
    final prop = propCtrl.data;

    // 1. Bill 80mm Config
    _billHeaderTitleCtrl.text = billConfig['header_title'] ?? (prop?.propertyName.isNotEmpty == true ? prop!.propertyName : 'RETAIL POS STORE');
    _billHeaderSubtextCtrl.text = billConfig['header_subtext'] ?? (prop?.address.isNotEmpty == true ? '${prop!.address}, ${prop.city}' : 'Nairobi, Kenya • Tel: +254 700 000000');
    _billFooterNoteCtrl.text = billConfig['footer_note'] ?? (prop?.thermalFooterNote.isNotEmpty == true ? prop!.thermalFooterNote : 'Asante Sana! Thank you for your business.');
    _billTaxRegNoCtrl.text = billConfig['tax_reg_no'] ?? (prop?.gstNo.isNotEmpty == true ? 'KRA PIN / VAT: ${prop!.gstNo}' : 'KRA PIN: P051234567Z');
    _billTermsCtrl.text = billConfig['terms_and_conditions'] ?? (prop?.termsAndConditions.isNotEmpty == true ? prop!.termsAndConditions : 'Goods once sold will not be taken back or exchanged.');
    _billResellerFooterCtrl.text = billConfig['reseller_footer_text'] ?? AppBrand.poweredByLabel;

    _billShowLogo = billConfig['show_logo'] ?? true;
    _billShowAddress = billConfig['show_address'] ?? true;
    _billShowPhone = billConfig['show_phone'] ?? (prop?.printMobile ?? true);
    _billShowEmail = billConfig['show_email'] ?? (prop?.printEmail ?? true);
    _billShowCustomer = billConfig['show_customer'] ?? true;
    _billShowCashier = billConfig['show_cashier'] ?? true;
    _billShowToken = billConfig['show_token'] ?? (settingsCtrl.settings?.enableTokenSystem ?? false);
    _billShowBrand = billConfig['show_brand'] ?? (settingsCtrl.settings?.showBrandName ?? true);
    _billShowDiscounts = billConfig['show_item_discounts'] ?? true;
    _billShowTaxBreakup = billConfig['show_tax_breakup'] ?? true;
    _billShowBankDetails = billConfig['show_bank_details'] ?? (prop?.printBankDetails ?? false);
    _billShowUpiQr = billConfig['show_upi_qr'] ?? (prop?.printUpiQr ?? false);
    _billShowResellerFooter = billConfig['show_reseller_footer'] ?? true;
    _billShowCurrency = billConfig['show_currency_symbol'] ?? billConfig['show_currency'] ?? true;
    _billFontSize = billConfig['font_size'] ?? 'MEDIUM';
    _billThermalWidth = billConfig['thermal_width'] ?? '80mm';

    // 2. A4 Invoice Config
    _a4HeaderTitleCtrl.text = a4Config['header_title'] ?? (prop?.propertyName.isNotEmpty == true ? prop!.propertyName : 'RETAIL ENTERPRISES LIMITED');
    _a4HeaderSubtextCtrl.text = a4Config['header_subtext'] ?? (prop?.address.isNotEmpty == true ? '${prop!.address}, ${prop.city}, ${prop.state}' : 'Industrial Area, Commercial Street, Nairobi, Kenya');
    _a4TaxRegNoCtrl.text = a4Config['tax_reg_no'] ?? (prop?.gstNo.isNotEmpty == true ? 'KRA PIN / GSTIN: ${prop!.gstNo}' : 'KRA PIN / GSTIN: P051987654X');
    _a4PanNoCtrl.text = a4Config['pan_no'] ?? (prop?.panNo.isNotEmpty == true ? 'REG / PAN: ${prop!.panNo}' : 'COMPANY REG: CPR/2023/88990');
    _a4FooterNoteCtrl.text = a4Config['footer_note'] ?? 'This is a computer generated invoice and does not require a physical signature.';
    _a4TermsCtrl.text = a4Config['terms_and_conditions'] ?? (prop?.termsAndConditions.isNotEmpty == true ? prop!.termsAndConditions : '1. Goods once sold will not be accepted back without prior inspection.\n2. Interest @ 18% p.a. will be charged on overdue payments after 30 days.\n3. Subject to local judicial arbitration.');
    _a4BankNameCtrl.text = a4Config['bank_name'] ?? (prop?.bankName.isNotEmpty == true ? prop!.bankName : 'Standard Chartered / Equity Bank');
    _a4BankAccountNoCtrl.text = a4Config['bank_account_no'] ?? (prop?.bankAccNo.isNotEmpty == true ? prop!.bankAccNo : 'A/C: 0102030405060');
    _a4BankIfscCtrl.text = a4Config['bank_ifsc'] ?? (prop?.bankIfsc.isNotEmpty == true ? prop!.bankIfsc : 'SWIFT: SCBLKENX / Branch: 010');
    _a4MpesaPaybillCtrl.text = a4Config['mpesa_paybill'] ?? 'M-Pesa Paybill: 247247 | A/C: 0712345678';
    _a4SignatoryLabelCtrl.text = a4Config['signatory_label'] ?? 'For ${prop?.propertyName.isNotEmpty == true ? prop!.propertyName : "RETAIL ENTERPRISES LTD"}\nAuthorized Signatory';

    _a4ShowLogo = a4Config['show_logo'] ?? true;
    _a4ShowCompanyAddress = a4Config['show_address'] ?? true;
    _a4ShowCompanyContact = a4Config['show_contact'] ?? true;
    _a4ShowTaxReg = a4Config['show_tax_reg'] ?? true;
    _a4ShowBuyerDetails = a4Config['show_buyer_details'] ?? true;
    _a4ShowShippingDetails = a4Config['show_shipping_details'] ?? true;
    _a4ShowHsnCode = a4Config['show_hsn_code'] ?? true;
    _a4ShowBrand = a4Config['show_brand'] ?? true;
    _a4ShowItemDiscount = a4Config['show_item_discount'] ?? true;
    _a4ShowTaxBreakup = a4Config['show_tax_breakup'] ?? true;
    _a4ShowAmountInWords = a4Config['show_amount_in_words'] ?? true;
    _a4ShowBankDetails = a4Config['show_bank_details'] ?? true;
    _a4ShowQrCode = a4Config['show_qr_code'] ?? true;
    _a4ShowTermsAndConditions = a4Config['show_terms'] ?? true;
    _a4ShowSignatureBox = a4Config['show_signature_box'] ?? true;
    _a4ShowCurrency = a4Config['show_currency_symbol'] ?? a4Config['show_currency'] ?? true;
    _a4ThemeColor = a4Config['theme_color'] ?? 'BLUE';
    _a4FontSize = a4Config['font_size'] ?? 'MEDIUM';

    // 3. A5 Invoice Config
    _a5HeaderTitleCtrl.text = a5Config['header_title'] ?? (a4Config['header_title'] ?? (prop?.propertyName.isNotEmpty == true ? prop!.propertyName : 'RETAIL ENTERPRISES LIMITED'));
    _a5HeaderSubtextCtrl.text = a5Config['header_subtext'] ?? (a4Config['header_subtext'] ?? (prop?.address.isNotEmpty == true ? '${prop!.address}, ${prop.city}, ${prop.state}' : 'Industrial Area, Commercial Street, Nairobi, Kenya'));
    _a5TaxRegNoCtrl.text = a5Config['tax_reg_no'] ?? (a4Config['tax_reg_no'] ?? (prop?.gstNo.isNotEmpty == true ? 'KRA PIN / GSTIN: ${prop!.gstNo}' : 'KRA PIN / GSTIN: P051987654X'));
    _a5PanNoCtrl.text = a5Config['pan_no'] ?? (a4Config['pan_no'] ?? (prop?.panNo.isNotEmpty == true ? 'REG / PAN: ${prop!.panNo}' : 'COMPANY REG: CPR/2023/88990'));
    _a5FooterNoteCtrl.text = a5Config['footer_note'] ?? (a4Config['footer_note'] ?? 'This is a computer generated invoice and does not require a physical signature.');
    _a5TermsCtrl.text = a5Config['terms_and_conditions'] ?? (a4Config['terms_and_conditions'] ?? (prop?.termsAndConditions.isNotEmpty == true ? prop!.termsAndConditions : '1. Goods once sold will not be accepted back without prior inspection.\n2. Interest @ 18% p.a. will be charged on overdue payments after 30 days.\n3. Subject to local judicial arbitration.'));
    _a5BankNameCtrl.text = a5Config['bank_name'] ?? (a4Config['bank_name'] ?? (prop?.bankName.isNotEmpty == true ? prop!.bankName : 'Standard Chartered / Equity Bank'));
    _a5BankAccountNoCtrl.text = a5Config['bank_account_no'] ?? (a4Config['bank_account_no'] ?? (prop?.bankAccNo.isNotEmpty == true ? prop!.bankAccNo : 'A/C: 0102030405060'));
    _a5BankIfscCtrl.text = a5Config['bank_ifsc'] ?? (a4Config['bank_ifsc'] ?? (prop?.bankIfsc.isNotEmpty == true ? prop!.bankIfsc : 'SWIFT: SCBLKENX / Branch: 010'));
    _a5MpesaPaybillCtrl.text = a5Config['mpesa_paybill'] ?? (a4Config['mpesa_paybill'] ?? 'M-Pesa Paybill: 247247 | A/C: 0712345678');
    _a5SignatoryLabelCtrl.text = a5Config['signatory_label'] ?? (a4Config['signatory_label'] ?? 'For ${prop?.propertyName.isNotEmpty == true ? prop!.propertyName : "RETAIL ENTERPRISES LTD"}\nAuthorized Signatory');

    _a5ShowLogo = a5Config['show_logo'] ?? (a4Config['show_logo'] ?? true);
    _a5ShowCompanyAddress = a5Config['show_address'] ?? (a4Config['show_address'] ?? true);
    _a5ShowCompanyContact = a5Config['show_contact'] ?? (a4Config['show_contact'] ?? true);
    _a5ShowTaxReg = a5Config['show_tax_reg'] ?? (a4Config['show_tax_reg'] ?? true);
    _a5ShowBuyerDetails = a5Config['show_buyer_details'] ?? (a4Config['show_buyer_details'] ?? true);
    _a5ShowShippingDetails = a5Config['show_shipping_details'] ?? (a4Config['show_shipping_details'] ?? true);
    _a5ShowHsnCode = a5Config['show_hsn_code'] ?? (a4Config['show_hsn_code'] ?? true);
    _a5ShowBrand = a5Config['show_brand'] ?? (a4Config['show_brand'] ?? true);
    _a5ShowItemDiscount = a5Config['show_item_discount'] ?? (a4Config['show_item_discount'] ?? true);
    _a5ShowTaxBreakup = a5Config['show_tax_breakup'] ?? (a4Config['show_tax_breakup'] ?? true);
    _a5ShowAmountInWords = a5Config['show_amount_in_words'] ?? (a4Config['show_amount_in_words'] ?? true);
    _a5ShowBankDetails = a5Config['show_bank_details'] ?? (a4Config['show_bank_details'] ?? true);
    _a5ShowQrCode = a5Config['show_qr_code'] ?? (a4Config['show_qr_code'] ?? true);
    _a5ShowTermsAndConditions = a5Config['show_terms'] ?? (a4Config['show_terms'] ?? true);
    _a5ShowSignatureBox = a5Config['show_signature_box'] ?? (a4Config['show_signature_box'] ?? true);
    _a5ShowCurrency = a5Config['show_currency_symbol'] ?? a5Config['show_currency'] ?? (a4Config['show_currency_symbol'] ?? true);
    _a5ThemeColor = a5Config['theme_color'] ?? (a4Config['theme_color'] ?? 'BLUE');
    _a5FontSize = a5Config['font_size'] ?? (a4Config['font_size'] ?? 'MEDIUM');

    // 4. KOT Config
    _kotHeaderTitleCtrl.text = kotConfig['header_title'] ?? 'KITCHEN ORDER TICKET';
    _kotFooterNoteCtrl.text = kotConfig['footer_note'] ?? 'Order ready for cooking & serving';
    _kotShowStation = kotConfig['show_station'] ?? true;
    _kotShowTable = kotConfig['show_table'] ?? true;
    _kotShowGuests = kotConfig['show_guests'] ?? true;
    _kotShowWaiter = kotConfig['show_waiter'] ?? true;
    _kotShowTimestamp = kotConfig['show_timestamp'] ?? true;
    _kotShowNotes = kotConfig['show_notes'] ?? true;
    _kotShowBrand = kotConfig['show_brand'] ?? true;
    _kotShowCutLine = kotConfig['show_cut_line'] ?? true;
    _kotFontSize = kotConfig['font_size'] ?? 'MEDIUM';

    // 4. Token Config
    _tokenHeaderTitleCtrl.text = tokenConfig['header_title'] ?? (prop?.propertyName.isNotEmpty == true ? prop!.propertyName : 'ORDER TOKEN / QUEUE SLIP');
    _tokenHeaderSubtextCtrl.text = tokenConfig['header_subtext'] ?? (prop?.address.isNotEmpty == true ? prop!.address : 'Please retain this slip for order collection');
    _tokenFooterNoteCtrl.text = tokenConfig['footer_note'] ?? 'Please watch the pickup display or wait for announcement.';
    _tokenCounterLabelCtrl.text = tokenConfig['counter_label'] ?? 'COUNTER #1 - PICKUP BAY';
    _tokenShowStoreName = tokenConfig['show_store_name'] ?? true;
    _tokenShowBigNumber = tokenConfig['show_big_number'] ?? true;
    _tokenShowOrderNo = tokenConfig['show_order_no'] ?? true;
    _tokenShowTimestamp = tokenConfig['show_timestamp'] ?? true;
    _tokenShowCounter = tokenConfig['show_counter'] ?? true;
    _tokenShowCustomer = tokenConfig['show_customer'] ?? true;
    _tokenShowItemsSummary = tokenConfig['show_items_summary'] ?? true;
    _tokenShowItemCount = tokenConfig['show_item_count'] ?? true;
    _tokenShowBarcode = tokenConfig['show_barcode'] ?? true;
    _tokenShowCutLine = tokenConfig['show_cut_line'] ?? true;
    _tokenBadgeStyle = tokenConfig['badge_style'] ?? 'INVERTED_BOX';
    _tokenFontSize = tokenConfig['font_size'] ?? 'MEDIUM';
    _tokenThermalWidth = tokenConfig['thermal_width'] ?? '80mm';

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveTemplateConfig() async {
    SystemSettingsController settingsCtrl;
    try {
      settingsCtrl = context.read<SystemSettingsController>();
    } catch (_) {
      settingsCtrl = SystemSettingsController();
    }
    var currentSettings = settingsCtrl.settings;
    if (currentSettings == null) {
      await settingsCtrl.load();
      currentSettings = settingsCtrl.settings;
      if (currentSettings == null) return;
    }

    final billConfig = {
      'header_title': _billHeaderTitleCtrl.text.trim(),
      'header_subtext': _billHeaderSubtextCtrl.text.trim(),
      'footer_note': _billFooterNoteCtrl.text.trim(),
      'tax_reg_no': _billTaxRegNoCtrl.text.trim(),
      'terms_and_conditions': _billTermsCtrl.text.trim(),
      'show_logo': _billShowLogo,
      'show_address': _billShowAddress,
      'show_phone': _billShowPhone,
      'show_email': _billShowEmail,
      'show_customer': _billShowCustomer,
      'show_cashier': _billShowCashier,
      'show_token': _billShowToken,
      'show_brand': _billShowBrand,
      'show_item_discounts': _billShowDiscounts,
      'show_tax_breakup': _billShowTaxBreakup,
      'show_bank_details': _billShowBankDetails,
      'show_upi_qr': _billShowUpiQr,
      'show_reseller_footer': _billShowResellerFooter,
      'show_currency_symbol': _billShowCurrency,
      'reseller_footer_text': _billResellerFooterCtrl.text.trim(),
      'font_size': _billFontSize,
      'thermal_width': _billThermalWidth,
    };

    final a4Config = {
      'header_title': _a4HeaderTitleCtrl.text.trim(),
      'header_subtext': _a4HeaderSubtextCtrl.text.trim(),
      'tax_reg_no': _a4TaxRegNoCtrl.text.trim(),
      'pan_no': _a4PanNoCtrl.text.trim(),
      'footer_note': _a4FooterNoteCtrl.text.trim(),
      'terms_and_conditions': _a4TermsCtrl.text.trim(),
      'bank_name': _a4BankNameCtrl.text.trim(),
      'bank_account_no': _a4BankAccountNoCtrl.text.trim(),
      'bank_ifsc': _a4BankIfscCtrl.text.trim(),
      'mpesa_paybill': _a4MpesaPaybillCtrl.text.trim(),
      'signatory_label': _a4SignatoryLabelCtrl.text.trim(),
      'show_logo': _a4ShowLogo,
      'show_address': _a4ShowCompanyAddress,
      'show_contact': _a4ShowCompanyContact,
      'show_tax_reg': _a4ShowTaxReg,
      'show_buyer_details': _a4ShowBuyerDetails,
      'show_shipping_details': _a4ShowShippingDetails,
      'show_hsn_code': _a4ShowHsnCode,
      'show_brand': _a4ShowBrand,
      'show_item_discount': _a4ShowItemDiscount,
      'show_tax_breakup': _a4ShowTaxBreakup,
      'show_amount_in_words': _a4ShowAmountInWords,
      'show_bank_details': _a4ShowBankDetails,
      'show_qr_code': _a4ShowQrCode,
      'show_terms': _a4ShowTermsAndConditions,
      'show_signature_box': _a4ShowSignatureBox,
      'show_currency_symbol': _a4ShowCurrency,
      'theme_color': _a4ThemeColor,
      'font_size': _a4FontSize,
    };

    final a5Config = {
      'header_title': _a5HeaderTitleCtrl.text.trim(),
      'header_subtext': _a5HeaderSubtextCtrl.text.trim(),
      'tax_reg_no': _a5TaxRegNoCtrl.text.trim(),
      'pan_no': _a5PanNoCtrl.text.trim(),
      'footer_note': _a5FooterNoteCtrl.text.trim(),
      'terms_and_conditions': _a5TermsCtrl.text.trim(),
      'bank_name': _a5BankNameCtrl.text.trim(),
      'bank_account_no': _a5BankAccountNoCtrl.text.trim(),
      'bank_ifsc': _a5BankIfscCtrl.text.trim(),
      'mpesa_paybill': _a5MpesaPaybillCtrl.text.trim(),
      'signatory_label': _a5SignatoryLabelCtrl.text.trim(),
      'show_logo': _a5ShowLogo,
      'show_address': _a5ShowCompanyAddress,
      'show_contact': _a5ShowCompanyContact,
      'show_tax_reg': _a5ShowTaxReg,
      'show_buyer_details': _a5ShowBuyerDetails,
      'show_shipping_details': _a5ShowShippingDetails,
      'show_hsn_code': _a5ShowHsnCode,
      'show_brand': _a5ShowBrand,
      'show_item_discount': _a5ShowItemDiscount,
      'show_tax_breakup': _a5ShowTaxBreakup,
      'show_amount_in_words': _a5ShowAmountInWords,
      'show_bank_details': _a5ShowBankDetails,
      'show_qr_code': _a5ShowQrCode,
      'show_terms': _a5ShowTermsAndConditions,
      'show_signature_box': _a5ShowSignatureBox,
      'show_currency_symbol': _a5ShowCurrency,
      'theme_color': _a5ThemeColor,
      'font_size': _a5FontSize,
    };

    final kotConfig = {
      'header_title': _kotHeaderTitleCtrl.text.trim(),
      'footer_note': _kotFooterNoteCtrl.text.trim(),
      'show_station': _kotShowStation,
      'show_table': _kotShowTable,
      'show_guests': _kotShowGuests,
      'show_waiter': _kotShowWaiter,
      'show_timestamp': _kotShowTimestamp,
      'show_notes': _kotShowNotes,
      'show_brand': _kotShowBrand,
      'show_cut_line': _kotShowCutLine,
      'font_size': _kotFontSize,
    };

    final tokenConfig = {
      'header_title': _tokenHeaderTitleCtrl.text.trim(),
      'header_subtext': _tokenHeaderSubtextCtrl.text.trim(),
      'footer_note': _tokenFooterNoteCtrl.text.trim(),
      'counter_label': _tokenCounterLabelCtrl.text.trim(),
      'show_store_name': _tokenShowStoreName,
      'show_big_number': _tokenShowBigNumber,
      'show_order_no': _tokenShowOrderNo,
      'show_timestamp': _tokenShowTimestamp,
      'show_counter': _tokenShowCounter,
      'show_customer': _tokenShowCustomer,
      'show_items_summary': _tokenShowItemsSummary,
      'show_item_count': _tokenShowItemCount,
      'show_barcode': _tokenShowBarcode,
      'show_cut_line': _tokenShowCutLine,
      'badge_style': _tokenBadgeStyle,
      'font_size': _tokenFontSize,
      'thermal_width': _tokenThermalWidth,
    };

    currentSettings.receiptTemplateConfig = billConfig;
    currentSettings.a4TemplateConfig = a4Config;
    currentSettings.a5TemplateConfig = a5Config;
    currentSettings.kotTemplateConfig = kotConfig;
    currentSettings.tokenTemplateConfig = tokenConfig;

    setState(() => _loading = true);
    await settingsCtrl.save(currentSettings);
    setState(() => _loading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Bill, A4, A5 Invoice, KOT & Token templates saved successfully!'),
          backgroundColor: Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _getA5PrimaryColor() {
    switch (_a5ThemeColor) {
      case 'SLATE':
        return const Color(0xFF1E293B);
      case 'EMERALD':
        return const Color(0xFF047857);
      case 'CRIMSON':
        return const Color(0xFF991B1B);
      case 'BLUE':
      default:
        return const Color(0xFF0B5CAD);
    }
  }

  Color _getA4PrimaryColor() {
    switch (_a4ThemeColor) {
      case 'SLATE':
        return const Color(0xFF1E293B);
      case 'EMERALD':
        return const Color(0xFF047857);
      case 'CRIMSON':
        return const Color(0xFF991B1B);
      case 'BLUE':
      default:
        return const Color(0xFF0B5CAD);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Receipt, KOT & Token Template Designer',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save, size: 18),
              label: const Text('Save Templates', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _loading ? null : _saveTemplateConfig,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorWeight: 3,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long, size: 18), text: '80mm Thermal Bill'),
            Tab(icon: Icon(Icons.description_outlined, size: 18), text: 'A4 Tax Invoice'),
            Tab(icon: Icon(Icons.receipt_outlined, size: 18), text: 'A5 Tax Invoice'),
            Tab(icon: Icon(Icons.soup_kitchen_outlined, size: 18), text: 'Kitchen KOT'),
            Tab(icon: Icon(Icons.confirmation_number_outlined, size: 18), text: 'Token Slip'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : TabBarView(
              controller: _tabController,
              children: [
                _build80mmBillDesignerTab(),
                _buildA4InvoiceDesignerTab(),
                _buildA5InvoiceDesignerTab(),
                _buildKotDesignerTab(),
                _buildTokenDesignerTab(),
              ],
            ),
    );
  }

  // =========================================================================
  // TAB 1: 80mm Thermal Bill Template Designer
  // =========================================================================
  Widget _build80mmBillDesignerTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader('80mm Thermal Receipt Content', 'Customize title, tax IDs, and policy notes', Icons.edit_note),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildTextField('Store / Business Header Title', _billHeaderTitleCtrl, 'e.g. ABC SUPERMARKET'),
                      const SizedBox(height: 12),
                      _buildTextField('Header Subtext (Address & Tel)', _billHeaderSubtextCtrl, 'e.g. Kimathi St, Nairobi • Tel: 0700000000', maxLines: 2),
                      const SizedBox(height: 12),
                      _buildTextField('Tax Registration ID / KRA PIN / VAT', _billTaxRegNoCtrl, 'e.g. KRA PIN: P051234567Z'),
                      const SizedBox(height: 12),
                      _buildTextField('Thermal Footer Note', _billFooterNoteCtrl, 'e.g. Asante Sana! Thank you for shopping with us.', maxLines: 2),
                      const SizedBox(height: 12),
                      _buildTextField('Terms & Return Policy', _billTermsCtrl, 'e.g. Goods once sold will not be taken back.', maxLines: 2),
                      const SizedBox(height: 12),
                      _buildTextField('Powered By / Reseller Tagline', _billResellerFooterCtrl, 'e.g. ${AppBrand.poweredByLabel}'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('Thermal Section Visibility', 'Toggle components printed on thermal slips', Icons.toggle_on),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildSwitch('Print Store Logo at Top', _billShowLogo, (v) => setState(() => _billShowLogo = v)),
                      _buildSwitch('Print Store Address Line', _billShowAddress, (v) => setState(() => _billShowAddress = v)),
                      _buildSwitch('Print Phone Number', _billShowPhone, (v) => setState(() => _billShowPhone = v)),
                      _buildSwitch('Print Email Address', _billShowEmail, (v) => setState(() => _billShowEmail = v)),
                      _buildSwitch('Print Customer Name & Phone', _billShowCustomer, (v) => setState(() => _billShowCustomer = v)),
                      _buildSwitch('Print Cashier / Server Name', _billShowCashier, (v) => setState(() => _billShowCashier = v)),
                      _buildSwitch('Print Token Number (e.g. TK-101)', _billShowToken, (v) => setState(() => _billShowToken = v)),
                      _buildSwitch('Print Product Brand Prefix', _billShowBrand, (v) => setState(() => _billShowBrand = v)),
                      _buildSwitch('Print Discount & Scheme Breakdown', _billShowDiscounts, (v) => setState(() => _billShowDiscounts = v)),
                      _buildSwitch('Print Tax Analysis Table (VAT/CTL)', _billShowTaxBreakup, (v) => setState(() => _billShowTaxBreakup = v)),
                      _buildSwitch('Print Bank Account / M-Pesa Till', _billShowBankDetails, (v) => setState(() => _billShowBankDetails = v)),
                      _buildSwitch('Print Payment / e-Invoice QR Code', _billShowUpiQr, (v) => setState(() => _billShowUpiQr = v)),
                      _buildSwitch('Print Powered by Reseller Tag', _billShowResellerFooter, (v) => setState(() => _billShowResellerFooter = v)),
                      _buildSwitch('Print Currency Symbol (${CurrencyService.symbol})', _billShowCurrency, (v) => setState(() => _billShowCurrency = v)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('Thermal Paper & Typography Scale', 'Paper roll width and dynamic font density', Icons.font_download),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Paper Roll Width', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _billThermalWidth,
                              decoration: _inputDecoration(),
                              items: const [
                                DropdownMenuItem(value: '80mm', child: Text('80mm (Standard 3-inch Roll)')),
                                DropdownMenuItem(value: '76mm', child: Text('76mm (Dot Matrix / POS)')),
                                DropdownMenuItem(value: '58mm', child: Text('58mm (Compact 2-inch Roll)')),
                              ],
                              onChanged: (v) => setState(() => _billThermalWidth = v ?? '80mm'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Font Density / Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _billFontSize,
                              decoration: _inputDecoration(),
                              items: const [
                                DropdownMenuItem(value: 'SMALL', child: Text('Compact (Dense, Save Paper)')),
                                DropdownMenuItem(value: 'MEDIUM', child: Text('Medium Standard')),
                                DropdownMenuItem(value: 'LARGE', child: Text('Large Bold (High Legibility)')),
                              ],
                              onChanged: (v) => setState(() => _billFontSize = v ?? 'MEDIUM'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(width: 1, color: const Color(0xFFE2E8F0)),
        Expanded(
          flex: 4,
          child: Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Live 80mm Thermal Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFE0E7FF), borderRadius: BorderRadius.circular(6)),
                      child: Text('$_billThermalWidth • Font: $_billFontSize', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: primaryColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: _buildLive80mmPreviewPaper(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 2: A4 Full Tax Invoice Template Designer
  // =========================================================================
  Widget _buildA4InvoiceDesignerTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader('A4 Company & Header Details', 'Business identity on standard A4 tax invoice', Icons.business),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildTextField('Company / Firm Legal Name', _a4HeaderTitleCtrl, 'e.g. RETAIL ENTERPRISES LIMITED'),
                      const SizedBox(height: 12),
                      _buildTextField('Registered Office & Postal Address', _a4HeaderSubtextCtrl, 'e.g. Commercial Street, Nairobi, Kenya', maxLines: 2),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('KRA PIN / GSTIN / Tax ID', _a4TaxRegNoCtrl, 'e.g. P051987654X')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Company Reg / PAN', _a4PanNoCtrl, 'e.g. CPR/2023/88990')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('Bank Settlement & Signatory Details', 'Payment coordinates & authorization seal', Icons.account_balance),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Bank Name', _a4BankNameCtrl, 'e.g. Standard Chartered / Equity')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Bank Account / IBAN', _a4BankAccountNoCtrl, 'e.g. 0102030405060')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('SWIFT / IFSC / Branch', _a4BankIfscCtrl, 'e.g. SCBLKENX / 010')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('M-Pesa Paybill / Till', _a4MpesaPaybillCtrl, 'e.g. Paybill: 247247 | Acc: 0712345678')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField('Signatory Designation Label', _a4SignatoryLabelCtrl, 'e.g. For RETAIL ENTERPRISES LTD\nAuthorized Signatory', maxLines: 2),
                      const SizedBox(height: 12),
                      _buildTextField('Invoice Terms & Conditions (Legal)', _a4TermsCtrl, 'e.g. 1. Goods once sold will not be accepted back...', maxLines: 3),
                      const SizedBox(height: 12),
                      _buildTextField('Computer Generated Footer Tagline', _a4FooterNoteCtrl, 'e.g. This is a computer generated invoice...', maxLines: 2),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('A4 Invoicing Sections & Tables', 'Toggle tables and visual blocks on A4 page', Icons.view_quilt),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildSwitch('Print Company Logo & Header Brand Box', _a4ShowLogo, (v) => setState(() => _a4ShowLogo = v)),
                      _buildSwitch('Print Registered Office Address Line', _a4ShowCompanyAddress, (v) => setState(() => _a4ShowCompanyAddress = v)),
                      _buildSwitch('Print Company Telephone & Email Contacts', _a4ShowCompanyContact, (v) => setState(() => _a4ShowCompanyContact = v)),
                      _buildSwitch('Print Tax PIN / GSTIN Block', _a4ShowTaxReg, (v) => setState(() => _a4ShowTaxReg = v)),
                      _buildSwitch('Print "Billed To" Customer Card (Name, PIN, Address)', _a4ShowBuyerDetails, (v) => setState(() => _a4ShowBuyerDetails = v)),
                      _buildSwitch('Print "Shipped To" Delivery Address Card', _a4ShowShippingDetails, (v) => setState(() => _a4ShowShippingDetails = v)),
                      _buildSwitch('Print HSN / SAC Code Column in Items Grid', _a4ShowHsnCode, (v) => setState(() => _a4ShowHsnCode = v)),
                      _buildSwitch('Print Item Brand Prefix in Description', _a4ShowBrand, (v) => setState(() => _a4ShowBrand = v)),
                      _buildSwitch('Print Item Discount % Column', _a4ShowItemDiscount, (v) => setState(() => _a4ShowItemDiscount = v)),
                      _buildSwitch('Print Comprehensive Tax Breakup Box (CGST/SGST/VAT/CTL)', _a4ShowTaxBreakup, (v) => setState(() => _a4ShowTaxBreakup = v)),
                      _buildSwitch('Print Total Net Payable in Words', _a4ShowAmountInWords, (v) => setState(() => _a4ShowAmountInWords = v)),
                      _buildSwitch('Print Bank Account & M-Pesa Settlement Block', _a4ShowBankDetails, (v) => setState(() => _a4ShowBankDetails = v)),
                      _buildSwitch('Print e-Invoice / UPI Payment Verification QR', _a4ShowQrCode, (v) => setState(() => _a4ShowQrCode = v)),
                      _buildSwitch('Print Terms & Conditions Box', _a4ShowTermsAndConditions, (v) => setState(() => _a4ShowTermsAndConditions = v)),
                      _buildSwitch('Print Signature & Company Seal Box', _a4ShowSignatureBox, (v) => setState(() => _a4ShowSignatureBox = v)),
                      _buildSwitch('Print Currency Symbol (${CurrencyService.symbol})', _a4ShowCurrency, (v) => setState(() => _a4ShowCurrency = v)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('A4 Accent Color Theme & Typography', 'Color scheme and font density scale', Icons.palette),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Theme Accent Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildColorOption('BLUE', 'Corporate Navy', const Color(0xFF0B5CAD), selectedKey: _a4ThemeColor, onSelect: (c) => setState(() => _a4ThemeColor = c)),
                          const SizedBox(width: 8),
                          _buildColorOption('SLATE', 'Modern Charcoal', const Color(0xFF1E293B), selectedKey: _a4ThemeColor, onSelect: (c) => setState(() => _a4ThemeColor = c)),
                          const SizedBox(width: 8),
                          _buildColorOption('EMERALD', 'Forest Emerald', const Color(0xFF047857), selectedKey: _a4ThemeColor, onSelect: (c) => setState(() => _a4ThemeColor = c)),
                          const SizedBox(width: 8),
                          _buildColorOption('CRIMSON', 'Executive Wine', const Color(0xFF991B1B), selectedKey: _a4ThemeColor, onSelect: (c) => setState(() => _a4ThemeColor = c)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('A4 Font Density / Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _a4FontSize,
                        decoration: _inputDecoration(),
                        items: const [
                          DropdownMenuItem(value: 'SMALL', child: Text('Compact (Dense Invoicing, Fit More Line Items)')),
                          DropdownMenuItem(value: 'MEDIUM', child: Text('Medium Standard (Balanced Invoicing)')),
                          DropdownMenuItem(value: 'LARGE', child: Text('Large Spacious (Executive Presentation)')),
                        ],
                        onChanged: (v) => setState(() => _a4FontSize = v ?? 'MEDIUM'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(width: 1, color: const Color(0xFFE2E8F0)),
        Expanded(
          flex: 5,
          child: Container(
            color: const Color(0xFFE2E8F0),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Live A4 Sheet Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFCBD5E1))),
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: _getA4PrimaryColor(), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('A4 210 x 297 mm • Font: $_a4FontSize • $_a4ThemeColor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: _buildLiveA4PreviewSheet(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 3: Kitchen KOT Template Designer
  // =========================================================================

  // =========================================================================
  // TAB 3: A5 Half-Sheet Tax Invoice Template Designer
  // =========================================================================
  Widget _buildA5InvoiceDesignerTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader('A5 Company & Header Details', 'Business identity on compact A5 (148 x 210 mm) tax invoice', Icons.business),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildTextField('Company / Firm Legal Name', _a5HeaderTitleCtrl, 'e.g. RETAIL ENTERPRISES LIMITED'),
                      const SizedBox(height: 12),
                      _buildTextField('Registered Office & Postal Address', _a5HeaderSubtextCtrl, 'e.g. Commercial Street, Nairobi, Kenya', maxLines: 2),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('KRA PIN / GSTIN / Tax ID', _a5TaxRegNoCtrl, 'e.g. P051987654X')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Company Reg / PAN', _a5PanNoCtrl, 'e.g. CPR/2023/88990')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('Bank Settlement & Signatory Details', 'Payment coordinates & authorization seal', Icons.account_balance),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Bank Name', _a5BankNameCtrl, 'e.g. Standard Chartered / Equity')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Bank Account / IBAN', _a5BankAccountNoCtrl, 'e.g. 0102030405060')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('SWIFT / IFSC / Branch', _a5BankIfscCtrl, 'e.g. SCBLKENX / 010')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('M-Pesa Paybill / Till', _a5MpesaPaybillCtrl, 'e.g. Paybill: 247247 | Acc: 0712345678')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField('Signatory Designation Label', _a5SignatoryLabelCtrl, 'e.g. For RETAIL ENTERPRISES LTD\nAuthorized Signatory', maxLines: 2),
                      const SizedBox(height: 12),
                      _buildTextField('Invoice Terms & Conditions (Legal)', _a5TermsCtrl, 'e.g. 1. Goods once sold will not be accepted back...', maxLines: 3),
                      const SizedBox(height: 12),
                      _buildTextField('Computer Generated Footer Tagline', _a5FooterNoteCtrl, 'e.g. This is a computer generated invoice...', maxLines: 2),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('A5 Invoicing Sections & Tables', 'Toggle tables and visual blocks on A5 page', Icons.view_quilt),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildSwitch('Print Company Logo & Header Brand Box', _a5ShowLogo, (v) => setState(() => _a5ShowLogo = v)),
                      _buildSwitch('Print Registered Office Address Line', _a5ShowCompanyAddress, (v) => setState(() => _a5ShowCompanyAddress = v)),
                      _buildSwitch('Print Company Telephone & Email Contacts', _a5ShowCompanyContact, (v) => setState(() => _a5ShowCompanyContact = v)),
                      _buildSwitch('Print Tax PIN / GSTIN Block', _a5ShowTaxReg, (v) => setState(() => _a5ShowTaxReg = v)),
                      _buildSwitch('Print "Billed To" Customer Card (Name, PIN, Address)', _a5ShowBuyerDetails, (v) => setState(() => _a5ShowBuyerDetails = v)),
                      _buildSwitch('Print "Shipped To" Delivery Address Card', _a5ShowShippingDetails, (v) => setState(() => _a5ShowShippingDetails = v)),
                      _buildSwitch('Print HSN / SAC Code Column in Items Grid', _a5ShowHsnCode, (v) => setState(() => _a5ShowHsnCode = v)),
                      _buildSwitch('Print Item Brand Prefix in Description', _a5ShowBrand, (v) => setState(() => _a5ShowBrand = v)),
                      _buildSwitch('Print Item Discount % Column', _a5ShowItemDiscount, (v) => setState(() => _a5ShowItemDiscount = v)),
                      _buildSwitch('Print Comprehensive Tax Breakup Box (CGST/SGST/VAT/CTL)', _a5ShowTaxBreakup, (v) => setState(() => _a5ShowTaxBreakup = v)),
                      _buildSwitch('Print Total Net Payable in Words', _a5ShowAmountInWords, (v) => setState(() => _a5ShowAmountInWords = v)),
                      _buildSwitch('Print Bank Account & M-Pesa Settlement Block', _a5ShowBankDetails, (v) => setState(() => _a5ShowBankDetails = v)),
                      _buildSwitch('Print e-Invoice / UPI Payment Verification QR', _a5ShowQrCode, (v) => setState(() => _a5ShowQrCode = v)),
                      _buildSwitch('Print Terms & Conditions Box', _a5ShowTermsAndConditions, (v) => setState(() => _a5ShowTermsAndConditions = v)),
                      _buildSwitch('Print Signature & Company Seal Box', _a5ShowSignatureBox, (v) => setState(() => _a5ShowSignatureBox = v)),
                      _buildSwitch('Print Currency Symbol (${CurrencyService.symbol})', _a5ShowCurrency, (v) => setState(() => _a5ShowCurrency = v)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('A5 Accent Color Theme & Typography', 'Color scheme and font density scale', Icons.palette),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Theme Accent Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildColorOption('BLUE', 'Corporate Navy', const Color(0xFF0B5CAD), selectedKey: _a5ThemeColor, onSelect: (c) => setState(() => _a5ThemeColor = c)),
                          const SizedBox(width: 8),
                          _buildColorOption('SLATE', 'Modern Charcoal', const Color(0xFF1E293B), selectedKey: _a5ThemeColor, onSelect: (c) => setState(() => _a5ThemeColor = c)),
                          const SizedBox(width: 8),
                          _buildColorOption('EMERALD', 'Forest Emerald', const Color(0xFF047857), selectedKey: _a5ThemeColor, onSelect: (c) => setState(() => _a5ThemeColor = c)),
                          const SizedBox(width: 8),
                          _buildColorOption('CRIMSON', 'Executive Wine', const Color(0xFF991B1B), selectedKey: _a5ThemeColor, onSelect: (c) => setState(() => _a5ThemeColor = c)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('A5 Font Density / Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _a5FontSize,
                        decoration: _inputDecoration(),
                        items: const [
                          DropdownMenuItem(value: 'SMALL', child: Text('Compact (Dense Invoicing, Fit More Line Items)')),
                          DropdownMenuItem(value: 'MEDIUM', child: Text('Medium Standard (Balanced Invoicing)')),
                          DropdownMenuItem(value: 'LARGE', child: Text('Large Spacious (Executive Presentation)')),
                        ],
                        onChanged: (v) => setState(() => _a5FontSize = v ?? 'MEDIUM'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(width: 1, color: const Color(0xFFE2E8F0)),
        Expanded(
          flex: 5,
          child: Container(
            color: const Color(0xFFE2E8F0),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Live A5 Sheet Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFCBD5E1))),
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: _getA5PrimaryColor(), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('A5 148 x 210 mm • Font: $_a5FontSize • $_a5ThemeColor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: _buildLiveA5PreviewSheet(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // LIVE A5 INVOICE SHEET PREVIEW WIDGET (DYNAMIC FONT DENSITY)
  // =========================================================================
  Widget _buildLiveA5PreviewSheet() {
    String fmt(num val) => _a5ShowCurrency ? CurrencyService.format(val) : val.toStringAsFixed(2);
    final themeColor = _getA5PrimaryColor();

    // Dynamic scaling based on _a5FontSize
    double scale = 1.0;
    if (_a5FontSize == 'SMALL') scale = 0.85;
    if (_a5FontSize == 'LARGE') scale = 1.18;

    final double titleSize = 14.0 * scale;
    final double subtextSize = 8.5 * scale;
    final double metaLabelSize = 7.5 * scale;
    final double metaValueSize = 8.0 * scale;
    final double tableHeaderSize = 8.0 * scale;
    final double tableItemSize = 7.8 * scale;
    final double summaryLabelSize = 7.8 * scale;
    final double netTotalSize = 11.0 * scale;

    return Container(
      width: 450,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      padding: EdgeInsets.all(18 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A5 Top Banner / Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_a5ShowLogo) ...[
                Container(
                  width: 40 * scale,
                  height: 40 * scale,
                  decoration: BoxDecoration(color: themeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Icon(Icons.corporate_fare, color: themeColor, size: 24 * scale),
                ),
                SizedBox(width: 10 * scale),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _a5HeaderTitleCtrl.text.isEmpty ? 'RETAIL ENTERPRISES LIMITED' : _a5HeaderTitleCtrl.text,
                      style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold, color: themeColor),
                    ),
                    if (_a5ShowCompanyAddress && _a5HeaderSubtextCtrl.text.isNotEmpty) ...[
                      SizedBox(height: 2 * scale),
                      Text(_a5HeaderSubtextCtrl.text, style: TextStyle(fontSize: subtextSize, color: const Color(0xFF475569))),
                    ],
                    if (_a5ShowCompanyContact) ...[
                      SizedBox(height: 2 * scale),
                      Text('Phone: +254 700 000000 | Email: sales@retailpos.com', style: TextStyle(fontSize: 7.8 * scale, color: const Color(0xFF64748B))),
                    ],
                    if (_a5ShowTaxReg) ...[
                      SizedBox(height: 2 * scale),
                      Text('${_a5TaxRegNoCtrl.text} | ${_a5PanNoCtrl.text}', style: TextStyle(fontSize: 8 * scale, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                    ],
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
                decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(4)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('TAX INVOICE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11 * scale, letterSpacing: 0.8)),
                    Text('A5 COMPACT', style: TextStyle(color: Colors.white70, fontSize: 7 * scale)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10 * scale),
          Divider(color: themeColor, thickness: 1.2),
          SizedBox(height: 4 * scale),

          // Metadata + Billed To Cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(7 * scale),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(4)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('INVOICE DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8.5 * scale, color: themeColor)),
                      SizedBox(height: 3 * scale),
                      _a4MetaRow('Invoice No:', 'INV-2026-00892', metaLabelSize, metaValueSize),
                      _a4MetaRow('Date & Time:', '27-Sep-2026 14:00 PM', metaLabelSize, metaValueSize),
                      _a4MetaRow('Payment Mode:', 'BANK / M-PESA', metaLabelSize, metaValueSize),
                      _a4MetaRow('Place of Supply:', 'Nairobi, Kenya (01)', metaLabelSize, metaValueSize),
                    ],
                  ),
                ),
              ),
              if (_a5ShowBuyerDetails) ...[
                SizedBox(width: 8 * scale),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(7 * scale),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(4)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BILLED TO (BUYER)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8.5 * scale, color: themeColor)),
                        SizedBox(height: 3 * scale),
                        Text('Apex Commercial Supplies Ltd', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8.5 * scale)),
                        Text('Plot 45, Uhuru Highway, Nairobi', style: TextStyle(fontSize: 7.8 * scale, color: const Color(0xFF475569))),
                        Text('KRA PIN: P059988776Z', style: TextStyle(fontSize: 7.8 * scale, color: const Color(0xFF475569))),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 8 * scale),

          // Tabular Items Table
          Container(
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1))),
            child: Column(
              children: [
                Container(
                  color: themeColor.withValues(alpha: 0.08),
                  padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 4 * scale),
                  child: Row(
                    children: [
                      SizedBox(width: 18 * scale, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize))),
                      Expanded(flex: 4, child: Text('ITEM DESCRIPTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize))),
                      if (_a5ShowHsnCode) Expanded(flex: 2, child: Text('HSN/SAC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize))),
                      Expanded(flex: 1, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize))),
                      Expanded(flex: 2, child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize))),
                      if (_a5ShowItemDiscount) Expanded(flex: 2, child: Text('DISC', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize))),
                      if (_a5ShowTaxBreakup) Expanded(flex: 2, child: Text('TAX', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize))),
                      Expanded(flex: 2, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize))),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFCBD5E1)),
                _a4ItemTableRow('1', '${_a5ShowBrand ? "Brookside - " : ""}Fresh Whole Milk 500ml', '0401.20', '10.0', fmt(80.00), fmt(0.00), '16% (${fmt(128.00)})', fmt(800.00), tableItemSize, scale),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _a4ItemTableRow('2', '${_a5ShowBrand ? "Farmers - " : ""}Sandwich Bread 400g', '1905.90', '5.0', fmt(65.00), '5% (${fmt(16.25)})', '16% (${fmt(49.40)})', fmt(308.75), tableItemSize, scale),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _a4ItemTableRow('3', 'Mineral Drinking Water 1L Bottle', '2201.10', '24.0', fmt(50.00), fmt(0.00), '16% (${fmt(192.00)})', fmt(1200.00), tableItemSize, scale),
              ],
            ),
          ),
          SizedBox(height: 8 * scale),

          // Financial Breakup & Bank Details Box
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_a5ShowAmountInWords) ...[
                      Container(
                        padding: EdgeInsets.all(5 * scale),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          'Amount in Words: Kenya Shillings Two Thousand Three Hundred Eight and 75/100 Only.',
                          style: TextStyle(fontSize: 7.8 * scale, fontStyle: FontStyle.italic, color: Colors.grey.shade800),
                        ),
                      ),
                      SizedBox(height: 5 * scale),
                    ],
                    if (_a5ShowBankDetails) ...[
                      Container(
                        padding: EdgeInsets.all(5 * scale),
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(4)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BANK & PAYMENT SETTLEMENT DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 7.8 * scale, color: themeColor)),
                            SizedBox(height: 2 * scale),
                            Text('Bank: ${_a5BankNameCtrl.text}', style: TextStyle(fontSize: 7.5 * scale)),
                            Text('${_a5BankAccountNoCtrl.text} | ${_a5BankIfscCtrl.text}', style: TextStyle(fontSize: 7.5 * scale)),
                            Text(_a5MpesaPaybillCtrl.text, style: TextStyle(fontSize: 7.5 * scale, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                flex: 4,
                child: Container(
                  padding: EdgeInsets.all(7 * scale),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(4)),
                  child: Column(
                    children: [
                      _a4SummaryRow('Taxable Amount:', fmt(1989.35), summaryLabelSize),
                      if (_a5ShowTaxBreakup) ...[
                        _a4SummaryRow('CGST / VAT (16%):', fmt(318.30), summaryLabelSize),
                        _a4SummaryRow('Tourism CTL (2%):', fmt(39.79), summaryLabelSize),
                      ],
                      _a4SummaryRow('Round Off:', fmt(-0.69), summaryLabelSize),
                      const Divider(height: 6, color: Color(0xFF94A3B8)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('NET TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5 * scale, color: themeColor)),
                          Text(fmt(2346.75), style: TextStyle(fontWeight: FontWeight.bold, fontSize: netTotalSize, color: themeColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * scale),

          // Terms and Signatory Box
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_a5ShowTermsAndConditions && _a5TermsCtrl.text.isNotEmpty) ...[
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Terms & Conditions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 7.8 * scale)),
                      SizedBox(height: 2 * scale),
                      Text(_a5TermsCtrl.text, style: TextStyle(fontSize: 7.0 * scale, color: const Color(0xFF475569))),
                    ],
                  ),
                ),
                SizedBox(width: 8 * scale),
              ],
              if (_a5ShowQrCode) ...[
                Column(
                  children: [
                    Icon(Icons.qr_code_2, size: 36 * scale),
                    Text('e-Invoice QR', style: TextStyle(fontSize: 6.5 * scale, color: Colors.grey)),
                  ],
                ),
                SizedBox(width: 8 * scale),
              ],
              if (_a5ShowSignatureBox) ...[
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: EdgeInsets.all(5 * scale),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(4)),
                    child: Column(
                      children: [
                        Text(
                          _a5SignatoryLabelCtrl.text.isEmpty ? 'Authorized Signatory' : _a5SignatoryLabelCtrl.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 7.5 * scale, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 16 * scale),
                        const Divider(height: 1, color: Colors.grey),
                        SizedBox(height: 2 * scale),
                        Text('Signature & Stamp', style: TextStyle(fontSize: 6.5 * scale, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_a5FooterNoteCtrl.text.isNotEmpty) ...[
            SizedBox(height: 6 * scale),
            Center(
              child: Text(_a5FooterNoteCtrl.text, style: TextStyle(fontSize: 7.0 * scale, color: Colors.grey)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKotDesignerTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader('Kitchen Ticket Headers', 'Headers and special instructions for chefs', Icons.restaurant_menu),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildTextField('Ticket Header Title', _kotHeaderTitleCtrl, 'e.g. KITCHEN ORDER TICKET (KOT)'),
                      const SizedBox(height: 12),
                      _buildTextField('Kitchen Instructions / Note', _kotFooterNoteCtrl, 'e.g. Please serve piping hot! Order ready.'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('KOT Ticket Elements', 'Toggle restaurant info on preparation slip', Icons.checklist_rtl),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildSwitch('Print Kitchen Station Name (e.g. HOT LINE)', _kotShowStation, (v) => setState(() => _kotShowStation = v)),
                      _buildSwitch('Print Table Number in Bold (e.g. Table #04)', _kotShowTable, (v) => setState(() => _kotShowTable = v)),
                      _buildSwitch('Print Guest / Pax Count', _kotShowGuests, (v) => setState(() => _kotShowGuests = v)),
                      _buildSwitch('Print Captain / Waiter Name', _kotShowWaiter, (v) => setState(() => _kotShowWaiter = v)),
                      _buildSwitch('Print Exact Time Stamp', _kotShowTimestamp, (v) => setState(() => _kotShowTimestamp = v)),
                      _buildSwitch('Print Special Notes / Cooking Modifiers', _kotShowNotes, (v) => setState(() => _kotShowNotes = v)),
                      _buildSwitch('Print Product Brand Prefix', _kotShowBrand, (v) => setState(() => _kotShowBrand = v)),
                      _buildSwitch('Print Tear-off Cut Separator Line', _kotShowCutLine, (v) => setState(() => _kotShowCutLine = v)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('Kitchen Font Typography', 'Chef reading legibility and size scale', Icons.format_size),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('KOT Font Density / Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _kotFontSize,
                        decoration: _inputDecoration(),
                        items: const [
                          DropdownMenuItem(value: 'SMALL', child: Text('Compact Size (Dense Slip)')),
                          DropdownMenuItem(value: 'MEDIUM', child: Text('Medium Standard')),
                          DropdownMenuItem(value: 'LARGE', child: Text('Extra Large (Chef High Visibility Bold)')),
                        ],
                        onChanged: (v) => setState(() => _kotFontSize = v ?? 'MEDIUM'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(width: 1, color: const Color(0xFFE2E8F0)),
        Expanded(
          flex: 4,
          child: Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Live Kitchen KOT Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                      child: Text('KDS / 80mm Roll • Font: $_kotFontSize', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFB45309))),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: _buildLiveKotPreviewPaper(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 4: Token Slip / Ticket Template Designer
  // =========================================================================
  Widget _buildTokenDesignerTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader('Token Ticket Header & Messages', 'Store identity, pickup counters, and instructions', Icons.confirmation_number),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildTextField('Store Header / Title', _tokenHeaderTitleCtrl, 'e.g. ORDER TOKEN / QUEUE SLIP'),
                      const SizedBox(height: 12),
                      _buildTextField('Subtext / Subtitle', _tokenHeaderSubtextCtrl, 'e.g. Please retain this slip for order collection', maxLines: 2),
                      const SizedBox(height: 12),
                      _buildTextField('Pickup Counter / Station Label', _tokenCounterLabelCtrl, 'e.g. COUNTER #1 - PICKUP BAY'),
                      const SizedBox(height: 12),
                      _buildTextField('Footer Guidance Note', _tokenFooterNoteCtrl, 'e.g. Please watch the pickup screen or wait for your number.', maxLines: 2),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('Token Badge & Visual Style', 'Format of the prominent token number', Icons.style),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Token Number Badge Style', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _tokenBadgeStyle,
                        decoration: _inputDecoration(),
                        items: const [
                          DropdownMenuItem(value: 'INVERTED_BOX', child: Text('Solid Inverted Box (High Contrast Black Block)')),
                          DropdownMenuItem(value: 'BORDER_BOX', child: Text('Bordered Box (Crisp Double/Thick Border)')),
                          DropdownMenuItem(value: 'CIRCLE', child: Text('Circle Badge (Rounded Emblem)')),
                          DropdownMenuItem(value: 'MINIMAL', child: Text('Minimal Clean (Large Bold Text with Underline)')),
                        ],
                        onChanged: (v) => setState(() => _tokenBadgeStyle = v ?? 'INVERTED_BOX'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Paper Roll Width', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: _tokenThermalWidth,
                                  decoration: _inputDecoration(),
                                  items: const [
                                    DropdownMenuItem(value: '80mm', child: Text('80mm Standard Roll')),
                                    DropdownMenuItem(value: '58mm', child: Text('58mm Compact Roll')),
                                  ],
                                  onChanged: (v) => setState(() => _tokenThermalWidth = v ?? '80mm'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Font Density / Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: _tokenFontSize,
                                  decoration: _inputDecoration(),
                                  items: const [
                                    DropdownMenuItem(value: 'SMALL', child: Text('Compact Size')),
                                    DropdownMenuItem(value: 'MEDIUM', child: Text('Medium Standard')),
                                    DropdownMenuItem(value: 'LARGE', child: Text('Extra Large (Maximum Visibility)')),
                                  ],
                                  onChanged: (v) => setState(() => _tokenFontSize = v ?? 'MEDIUM'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('Token Section Elements', 'Toggle components printed on token slips', Icons.checklist_rtl),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildSwitch('Print Store / Brand Header Name', _tokenShowStoreName, (v) => setState(() => _tokenShowStoreName = v)),
                      _buildSwitch('Print Big Token Badge', _tokenShowBigNumber, (v) => setState(() => _tokenShowBigNumber = v)),
                      _buildSwitch('Print Order / Invoice # Reference', _tokenShowOrderNo, (v) => setState(() => _tokenShowOrderNo = v)),
                      _buildSwitch('Print Exact Order Timestamp', _tokenShowTimestamp, (v) => setState(() => _tokenShowTimestamp = v)),
                      _buildSwitch('Print Pickup Counter / Bay Instruction', _tokenShowCounter, (v) => setState(() => _tokenShowCounter = v)),
                      _buildSwitch('Print Customer Name & Phone', _tokenShowCustomer, (v) => setState(() => _tokenShowCustomer = v)),
                      _buildSwitch('Print Items Summary List', _tokenShowItemsSummary, (v) => setState(() => _tokenShowItemsSummary = v)),
                      _buildSwitch('Print Total Item & Quantity Count', _tokenShowItemCount, (v) => setState(() => _tokenShowItemCount = v)),
                      _buildSwitch('Print Barcode / QR for Scanner Recall', _tokenShowBarcode, (v) => setState(() => _tokenShowBarcode = v)),
                      _buildSwitch('Print Tear-off Cut Separator Line', _tokenShowCutLine, (v) => setState(() => _tokenShowCutLine = v)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(width: 1, color: const Color(0xFFE2E8F0)),
        Expanded(
          flex: 4,
          child: Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Live Token Slip Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                      child: Text('$_tokenThermalWidth • Style: $_tokenBadgeStyle • Font: $_tokenFontSize', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF15803D))),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: _buildLiveTokenPreviewPaper(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // LIVE 80mm THERMAL PREVIEW WIDGET (DYNAMIC FONT DENSITY)
  // =========================================================================
  // =========================================================================
  // LIVE 80mm THERMAL PREVIEW WIDGET (1:1 REPLICA OF REAL PRINTED BILL)
  // =========================================================================
  Widget _buildLive80mmPreviewPaper() {
    final width = _billThermalWidth == '58mm' ? 260.0 : (_billThermalWidth == '76mm' ? 310.0 : 350.0);

    // Dynamic typography scaling based on _billFontSize
    double scale = 1.0;
    if (_billFontSize == 'SMALL') scale = 0.85;
    if (_billFontSize == 'LARGE') scale = 1.25;

    final double titleSize = 13.5 * scale;
    final double subtextSize = 9.0 * scale;
    final double taxIdSize = 9.5 * scale;
    final double metaSize = 9.0 * scale;
    final double itemHeaderSize = 9.5 * scale;
    final double totalHeaderSize = 13.0 * scale;
    final double totalAmountSize = 14.0 * scale;
    final double noteSize = 9.0 * scale;

    String fmt(num val) {
      if (_billShowCurrency) {
        return CurrencyService.format(val);
      }
      return val.toDouble().toStringAsFixed(2);
    }

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Logo (if enabled)
          if (_billShowLogo) ...[
            Center(
              child: Container(
                width: 32 * scale,
                height: 32 * scale,
                margin: EdgeInsets.only(bottom: 4 * scale),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
                ),
                child: Center(
                  child: Icon(Icons.blur_circular, size: 20 * scale, color: const Color(0xFF0284C7)),
                ),
              ),
            ),
          ],

          // 2. Business / Header Title
          Center(
            child: Text(
              _billHeaderTitleCtrl.text.isEmpty ? 'Famalth technologies' : _billHeaderTitleCtrl.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: titleSize, color: Colors.black),
            ),
          ),

          // 3. Address Subtext
          if (_billShowAddress && _billHeaderSubtextCtrl.text.isNotEmpty) ...[
            SizedBox(height: 2 * scale),
            Text(
              _billHeaderSubtextCtrl.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontSize: subtextSize, color: const Color(0xFF475569)),
            ),
          ],

          // 4. Tax ID / GSTIN / PIN
          if (_billTaxRegNoCtrl.text.isNotEmpty) ...[
            SizedBox(height: 2 * scale),
            Text(
              _billTaxRegNoCtrl.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: taxIdSize, color: Colors.black),
            ),
          ],

          // 5. TAX INVOICE Header Badge
          SizedBox(height: 3 * scale),
          Center(
            child: Text(
              'TAX INVOICE',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 10.5 * scale, color: Colors.black, letterSpacing: 0.5),
            ),
          ),

          // 6. Token Number (if enabled)
          if (_billShowToken) ...[
            SizedBox(height: 4 * scale),
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 2 * scale, horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text('TOKEN NO: TK-101', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13 * scale, color: Colors.black)),
              ),
            ),
          ],

          SizedBox(height: 4 * scale),
          _dashedDivider(scale),
          SizedBox(height: 3 * scale),

          // 7. Metadata Rows (Bill No, Date, Cashier, Time, Customer)
          _build80mmMetaRow('Bill No:', 'FAM-21-26', 'Date:', '27-Sep-2026', metaSize),
          if (_billShowCashier)
            _build80mmMetaRow('Cashier:', 'famalth1', 'Time:', '02:49 PM', metaSize),
          if (_billShowCustomer)
            _build80mmMetaRow('Customer:', 'Walk-in', 'Phone:', '--', metaSize),

          SizedBox(height: 3 * scale),
          _dashedDivider(scale),
          SizedBox(height: 3 * scale),

          // 8. Item Details Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ITEM DETAILS', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: itemHeaderSize, color: Colors.black)),
              Text('NET TOTAL', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: itemHeaderSize, color: Colors.black)),
            ],
          ),
          SizedBox(height: 3 * scale),

          // 9. Items Rows (matching real PosInvoicePrinter item format)
          _build80mmItemRow(
            '${_billShowBrand ? "JK Paper - " : ""}A4 Paper Rim',
            fmt(855.86),
            'HSN 4802 | 2 Nos x ${fmt(399.00)} | Sales Tax 7.25% = ${fmt(57.85)}',
            scale,
          ),

          SizedBox(height: 3 * scale),
          _dashedDivider(scale),
          SizedBox(height: 3 * scale),

          // 10. Summary (Total Items, Total Qty, Subtotal)
          _build80mmSummaryRow('Total Items', '1.00', scale),
          _build80mmSummaryRow('Total Qty', '2.00', scale),
          _build80mmSummaryRow('Subtotal', fmt(798.00), scale),
          if (_billShowDiscounts)
            _build80mmSummaryRow('Savings / Discount', '- ${fmt(0.00)}', scale, isGreen: true),

          SizedBox(height: 3 * scale),
          _dashedDivider(scale),
          SizedBox(height: 3 * scale),

          // 11. Tax Breakup (Taxable Value, Tax Breakup - Items, Round Off)
          _build80mmSummaryRow('Taxable Value', fmt(798.00), scale),
          if (_billShowTaxBreakup) ...[
            SizedBox(height: 3 * scale),
            Text('Tax Breakup - Items', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9.5 * scale, color: Colors.black)),
            SizedBox(height: 2 * scale),
            _build80mmTaxBreakupRow('STATE SALES TAX (6.25%)', fmt(798.00), fmt(49.88), scale),
            _build80mmTaxBreakupRow('CITY TAX (1%)', fmt(798.00), fmt(7.98), scale),
            _build80mmSummaryRow('Round Off', fmt(0.14), scale),
          ],

          SizedBox(height: 3 * scale),
          _dashedDivider(scale),
          SizedBox(height: 4 * scale),

          // 12. NET PAYABLE (Large Bold)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NET PAYABLE', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: totalHeaderSize, color: Colors.black)),
              Text(fmt(856.00), style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: totalAmountSize, color: Colors.black)),
            ],
          ),
          SizedBox(height: 4 * scale),

          // 13. Payment Breakdown (Split Bill Modes)
          _build80mmMetaRow('Payment Mode:', 'SPLIT', 'Refund:', fmt(0.00), metaSize),
          Text('PAYMENT (2 Modes)', style: TextStyle(fontFamily: 'monospace', fontSize: 8.5 * scale, color: Colors.black87)),
          SizedBox(height: 3 * scale),
          Center(
            child: Text(
              '— PAYMENT BREAKDOWN (SPLIT BILL) —',
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 8.5 * scale, color: Colors.black),
            ),
          ),
          SizedBox(height: 2 * scale),
          _build80mmMetaRow('CASH:', fmt(856.00), '', '', metaSize),
          _build80mmMetaRow('RETAIL:', fmt(0.14), '', '', metaSize),
          _build80mmMetaRow('Total Received:', fmt(856.00), '', '', metaSize),

          // 14. Realistic Barcode Graphic
          SizedBox(height: 6 * scale),
          Center(
            child: _buildRealisticBarcode('FAM-21-26', scale),
          ),

          // 15. Notes & Footers
          SizedBox(height: 4 * scale),
          Text(
            'Note: Payment: Cash ${fmt(856.00)} | Retail round off: +${fmt(0.14)}',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'monospace', fontSize: 8.0 * scale, color: Colors.black87),
          ),

          if (_billTermsCtrl.text.isNotEmpty) ...[
            SizedBox(height: 4 * scale),
            Text(
              _billTermsCtrl.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontSize: 8.0 * scale, color: Colors.grey.shade800),
            ),
          ],

          if (_billFooterNoteCtrl.text.isNotEmpty) ...[
            SizedBox(height: 4 * scale),
            Text(
              _billFooterNoteCtrl.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: noteSize, color: Colors.black),
            ),
          ],

          // 16. Optional UPI QR / Bank Details / Reseller Footer
          if (_billShowUpiQr) ...[
            SizedBox(height: 6 * scale),
            Center(child: Icon(Icons.qr_code_2, size: 46 * scale, color: Colors.black)),
            Center(child: Text('Scan to Pay via UPI', style: TextStyle(fontFamily: 'monospace', fontSize: 8.0 * scale, color: Colors.grey.shade700))),
          ],
          if (_billShowBankDetails) ...[
            SizedBox(height: 6 * scale),
            Container(
              padding: EdgeInsets.all(4 * scale),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
              child: Column(
                children: [
                  Text('--- Bank Details ---', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 8.5 * scale)),
                  Text('Bank: State Bank | A/c: 1234567890 | IFSC: SBIN0001234', style: TextStyle(fontFamily: 'monospace', fontSize: 7.5 * scale)),
                ],
              ),
            ),
          ],
          if (_billShowResellerFooter) ...[
            SizedBox(height: 6 * scale),
            Center(
              child: Text(
                '--- ${_billResellerFooterCtrl.text.trim().isNotEmpty ? _billResellerFooterCtrl.text.trim() : AppBrand.poweredByLabel} ---',
                style: TextStyle(fontFamily: 'monospace', fontSize: 7.5 * scale, color: Colors.grey),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRealisticBarcode(String text, double scale) {
    return Column(
      children: [
        Container(
          height: 28 * scale,
          width: 140 * scale,
          padding: EdgeInsets.symmetric(horizontal: 4 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < 34; i++)
                Container(
                  width: (i % 6 == 0 ? 3.0 : (i % 3 == 0 ? 2.0 : 1.2)) * scale,
                  color: (i % 5 == 1 || i % 8 == 4) ? Colors.transparent : Colors.black,
                ),
            ],
          ),
        ),
        SizedBox(height: 2 * scale),
        Text(
          text,
          style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9.5 * scale, color: Colors.black, letterSpacing: 1.2),
        ),
      ],
    );
  }

  Widget _build80mmItemRow(String name, String total, String details, double scale) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9.5 * scale, color: Colors.black),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                total,
                style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9.5 * scale, color: Colors.black),
              ),
            ],
          ),
          SizedBox(height: 1 * scale),
          Text(
            details,
            style: TextStyle(fontFamily: 'monospace', fontSize: 8.0 * scale, color: const Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  Widget _build80mmMetaRow(String label1, String val1, String label2, String val2, double fontSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label1 $val1', style: TextStyle(fontFamily: 'monospace', fontSize: fontSize, color: Colors.black87)),
          if (label2.isNotEmpty || val2.isNotEmpty)
            Text('$label2 $val2', style: TextStyle(fontFamily: 'monospace', fontSize: fontSize, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _build80mmTaxBreakupRow(String label, String taxable, String taxAmt, double scale) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 5,
            child: Text(label, style: TextStyle(fontFamily: 'monospace', fontSize: 8.5 * scale, color: Colors.black87)),
          ),
          Expanded(
            flex: 3,
            child: Text(taxable, textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontSize: 8.5 * scale, color: Colors.black87)),
          ),
          Expanded(
            flex: 2,
            child: Text(taxAmt, textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 8.5 * scale, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _build80mmSummaryRow(String label, String value, double scale, {bool isGreen = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.0 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontFamily: 'monospace', fontSize: 9.0 * scale, color: isGreen ? const Color(0xFF15803D) : Colors.black87)),
          Text(value, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 9.0 * scale, color: isGreen ? const Color(0xFF15803D) : Colors.black87)),
        ],
      ),
    );
  }

  // =========================================================================
  // LIVE A4 INVOICE SHEET PREVIEW WIDGET (DYNAMIC FONT DENSITY)
  // =========================================================================
  Widget _buildLiveA4PreviewSheet() {
    String fmt(num val) => _a4ShowCurrency ? CurrencyService.format(val) : val.toStringAsFixed(2);
    final themeColor = _getA4PrimaryColor();

    // Dynamic scaling based on _a4FontSize
    double scale = 1.0;
    if (_a4FontSize == 'SMALL') scale = 0.85;
    if (_a4FontSize == 'LARGE') scale = 1.18;

    final double titleSize = 16.0 * scale;
    final double subtextSize = 9.5 * scale;
    final double metaLabelSize = 8.0 * scale;
    final double metaValueSize = 8.5 * scale;
    final double tableHeaderSize = 9.0 * scale;
    final double tableItemSize = 8.5 * scale;
    final double summaryLabelSize = 8.5 * scale;
    final double netTotalSize = 12.0 * scale;

    return Container(
      width: 580,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      padding: EdgeInsets.all(26 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A4 Top Banner / Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_a4ShowLogo) ...[
                Container(
                  width: 48 * scale,
                  height: 48 * scale,
                  decoration: BoxDecoration(color: themeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.corporate_fare, color: themeColor, size: 28 * scale),
                ),
                SizedBox(width: 12 * scale),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _a4HeaderTitleCtrl.text.isEmpty ? 'RETAIL ENTERPRISES LIMITED' : _a4HeaderTitleCtrl.text,
                      style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold, color: themeColor),
                    ),
                    if (_a4ShowCompanyAddress && _a4HeaderSubtextCtrl.text.isNotEmpty) ...[
                      SizedBox(height: 2 * scale),
                      Text(_a4HeaderSubtextCtrl.text, style: TextStyle(fontSize: subtextSize, color: const Color(0xFF475569))),
                    ],
                    if (_a4ShowCompanyContact) ...[
                      SizedBox(height: 2 * scale),
                      Text('Phone: +254 700 000000 | Email: sales@retailpos.com | Web: www.retailpos.com', style: TextStyle(fontSize: 8.5 * scale, color: const Color(0xFF64748B))),
                    ],
                    if (_a4ShowTaxReg) ...[
                      SizedBox(height: 2 * scale),
                      Text('${_a4TaxRegNoCtrl.text}  |  ${_a4PanNoCtrl.text}', style: TextStyle(fontSize: 9 * scale, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                    ],
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
                decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(4)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('TAX INVOICE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13 * scale, letterSpacing: 1)),
                    Text('ORIGINAL FOR RECIPIENT', style: TextStyle(color: Colors.white70, fontSize: 7.5 * scale)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14 * scale),
          Divider(color: themeColor, thickness: 1.5),
          SizedBox(height: 6 * scale),

          // Metadata + Billed To Cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(9 * scale),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(4)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('INVOICE DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5 * scale, color: themeColor)),
                      SizedBox(height: 4 * scale),
                      _a4MetaRow('Invoice No:', 'INV-2026-00892', metaLabelSize, metaValueSize),
                      _a4MetaRow('Date & Time:', '27-Sep-2026 14:00 PM', metaLabelSize, metaValueSize),
                      _a4MetaRow('Payment Mode:', 'BANK TRANSFER / M-PESA', metaLabelSize, metaValueSize),
                      _a4MetaRow('Place of Supply:', 'Nairobi, Kenya (01)', metaLabelSize, metaValueSize),
                    ],
                  ),
                ),
              ),
              if (_a4ShowBuyerDetails) ...[
                SizedBox(width: 10 * scale),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(9 * scale),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(4)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BILLED TO (BUYER)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5 * scale, color: themeColor)),
                        SizedBox(height: 4 * scale),
                        Text('Apex Commercial Supplies Ltd', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5 * scale)),
                        Text('Plot 45, Uhuru Highway, Nairobi', style: TextStyle(fontSize: 8.5 * scale, color: const Color(0xFF475569))),
                        Text('KRA PIN: P059988776Z | Tel: +254 711 223344', style: TextStyle(fontSize: 8.5 * scale, color: const Color(0xFF475569))),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 12 * scale),

          // Tabular Items Table
          Container(
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1))),
            child: Column(
              children: [
                Container(
                  color: themeColor.withValues(alpha: 0.08),
                  padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 5 * scale),
                  child: Row(
                    children: [
                      SizedBox(width: 22 * scale, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize))),
                      Expanded(flex: 4, child: Text('ITEM DESCRIPTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize))),
                      if (_a4ShowHsnCode) Expanded(flex: 2, child: Text('HSN/SAC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize))),
                      Expanded(flex: 1, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize))),
                      Expanded(flex: 2, child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize))),
                      if (_a4ShowItemDiscount) Expanded(flex: 2, child: Text('DISC', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize))),
                      if (_a4ShowTaxBreakup) Expanded(flex: 2, child: Text('TAX', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize))),
                      Expanded(flex: 2, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize))),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFCBD5E1)),
                _a4ItemTableRow('1', '${_a4ShowBrand ? "Brookside - " : ""}Fresh Whole Milk 500ml', '0401.20', '10.0', fmt(80.00), fmt(0.00), '16% (${fmt(128.00)})', fmt(800.00), tableItemSize, scale),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _a4ItemTableRow('2', '${_a4ShowBrand ? "Farmers - " : ""}Sandwich Bread 400g', '1905.90', '5.0', fmt(65.00), '5% (${fmt(16.25)})', '16% (${fmt(49.40)})', fmt(308.75), tableItemSize, scale),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _a4ItemTableRow('3', 'Mineral Drinking Water 1L Bottle', '2201.10', '24.0', fmt(50.00), fmt(0.00), '16% (${fmt(192.00)})', fmt(1200.00), tableItemSize, scale),
              ],
            ),
          ),
          SizedBox(height: 10 * scale),

          // Financial Breakup & Bank Details Box
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_a4ShowAmountInWords) ...[
                      Container(
                        padding: EdgeInsets.all(6 * scale),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          'Amount in Words: Kenya Shillings Two Thousand Three Hundred Eight and 75/100 Only.',
                          style: TextStyle(fontSize: 8.5 * scale, fontStyle: FontStyle.italic, color: Colors.grey.shade800),
                        ),
                      ),
                      SizedBox(height: 6 * scale),
                    ],
                    if (_a4ShowBankDetails) ...[
                      Container(
                        padding: EdgeInsets.all(7 * scale),
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(4)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BANK & PAYMENT SETTLEMENT DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8.5 * scale, color: themeColor)),
                            SizedBox(height: 3 * scale),
                            Text('Bank: ${_a4BankNameCtrl.text}', style: TextStyle(fontSize: 8 * scale)),
                            Text('${_a4BankAccountNoCtrl.text}  |  ${_a4BankIfscCtrl.text}', style: TextStyle(fontSize: 8 * scale)),
                            Text(_a4MpesaPaybillCtrl.text, style: TextStyle(fontSize: 8 * scale, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 12 * scale),
              Expanded(
                flex: 4,
                child: Container(
                  padding: EdgeInsets.all(9 * scale),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(4)),
                  child: Column(
                    children: [
                      _a4SummaryRow('Taxable Amount:', fmt(1989.35), summaryLabelSize),
                      if (_a4ShowTaxBreakup) ...[
                        _a4SummaryRow('CGST / VAT (16%):', fmt(318.30), summaryLabelSize),
                        _a4SummaryRow('Tourism CTL (2%):', fmt(39.79), summaryLabelSize),
                      ],
                      _a4SummaryRow('Round Off:', fmt(-0.69), summaryLabelSize),
                      const Divider(height: 8, color: Color(0xFF94A3B8)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('NET TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11 * scale, color: themeColor)),
                          Text(fmt(2346.75), style: TextStyle(fontWeight: FontWeight.bold, fontSize: netTotalSize, color: themeColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * scale),

          // Terms and Signatory Box
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_a4ShowTermsAndConditions && _a4TermsCtrl.text.isNotEmpty) ...[
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Terms & Conditions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8.5 * scale)),
                      SizedBox(height: 2 * scale),
                      Text(_a4TermsCtrl.text, style: TextStyle(fontSize: 7.5 * scale, color: const Color(0xFF475569))),
                    ],
                  ),
                ),
                SizedBox(width: 10 * scale),
              ],
              if (_a4ShowQrCode) ...[
                Column(
                  children: [
                    Icon(Icons.qr_code_2, size: 44 * scale),
                    Text('e-Invoice QR', style: TextStyle(fontSize: 7 * scale, color: Colors.grey)),
                  ],
                ),
                SizedBox(width: 10 * scale),
              ],
              if (_a4ShowSignatureBox) ...[
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: EdgeInsets.all(7 * scale),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(4)),
                    child: Column(
                      children: [
                        Text(
                          _a4SignatoryLabelCtrl.text.isEmpty ? 'Authorized Signatory' : _a4SignatoryLabelCtrl.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 8 * scale, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 20 * scale),
                        const Divider(height: 1, color: Colors.grey),
                        SizedBox(height: 2 * scale),
                        Text('Signature & Stamp', style: TextStyle(fontSize: 7 * scale, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_a4FooterNoteCtrl.text.isNotEmpty) ...[
            SizedBox(height: 8 * scale),
            Center(
              child: Text(_a4FooterNoteCtrl.text, style: TextStyle(fontSize: 7.5 * scale, color: Colors.grey)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _a4MetaRow(String label, String value, double labelSize, double valueSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(width: 85, child: Text(label, style: TextStyle(fontSize: labelSize, color: const Color(0xFF64748B)))),
          Expanded(child: Text(value, style: TextStyle(fontSize: valueSize, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _a4ItemTableRow(String no, String name, String hsn, String qty, String rate, String disc, String tax, String total, double fontSize, double scale) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 3.5 * scale),
      child: Row(
        children: [
          SizedBox(width: 22 * scale, child: Text(no, style: TextStyle(fontSize: fontSize))),
          Expanded(flex: 4, child: Text(name, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600))),
          if (_a4ShowHsnCode) Expanded(flex: 2, child: Text(hsn, style: TextStyle(fontSize: fontSize * 0.95, color: const Color(0xFF64748B)))),
          Expanded(flex: 1, child: Text(qty, textAlign: TextAlign.center, style: TextStyle(fontSize: fontSize))),
          Expanded(flex: 2, child: Text(rate, textAlign: TextAlign.right, style: TextStyle(fontSize: fontSize))),
          if (_a4ShowItemDiscount) Expanded(flex: 2, child: Text(disc, textAlign: TextAlign.right, style: TextStyle(fontSize: fontSize, color: const Color(0xFF15803D)))),
          if (_a4ShowTaxBreakup) Expanded(flex: 2, child: Text(tax, textAlign: TextAlign.right, style: TextStyle(fontSize: fontSize * 0.95))),
          Expanded(flex: 2, child: Text(total, textAlign: TextAlign.right, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _a4SummaryRow(String label, String value, double fontSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, color: const Color(0xFF475569))),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // =========================================================================
  // LIVE KOT PREVIEW TICKET WIDGET (DYNAMIC FONT DENSITY)
  // =========================================================================
  Widget _buildLiveKotPreviewPaper() {
    // Dynamic typography scaling based on _kotFontSize
    double scale = 1.0;
    if (_kotFontSize == 'SMALL') scale = 0.85;
    if (_kotFontSize == 'LARGE') scale = 1.30;

    final double titleSize = 14.0 * scale;
    final double stationSize = 10.0 * scale;
    final double tableSize = 13.0 * scale;
    final double paxSize = 11.0 * scale;
    final double metaSize = 9.5 * scale;
    final double headerSize = 10.5 * scale;
    final double noteSize = 9.5 * scale;

    return Container(
      width: 330,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              _kotHeaderTitleCtrl.text.isEmpty ? 'KITCHEN ORDER TICKET' : _kotHeaderTitleCtrl.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: titleSize, color: Colors.black),
            ),
          ),
          if (_kotShowStation) ...[
            SizedBox(height: 2 * scale),
            Center(
              child: Text('[ KITCHEN STATION: HOT LINE / GRILL ]', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: stationSize, color: const Color(0xFFB45309))),
            ),
          ],
          SizedBox(height: 5 * scale),
          _dashedDivider(scale),
          SizedBox(height: 5 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_kotShowTable) Text('TABLE: T-04 (Dine-In)', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: tableSize)),
              if (_kotShowGuests) Text('PAX: 3', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: paxSize)),
            ],
          ),
          SizedBox(height: 3 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('KOT #: KOT-088', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: metaSize)),
              if (_kotShowTimestamp) Text('27-Sep-2026 14:02', style: TextStyle(fontFamily: 'monospace', fontSize: metaSize, color: Colors.grey.shade700)),
            ],
          ),
          if (_kotShowWaiter) ...[
            SizedBox(height: 2 * scale),
            Text('Captain/Server: Alex K.', style: TextStyle(fontFamily: 'monospace', fontSize: metaSize)),
          ],
          SizedBox(height: 5 * scale),
          _dashedDivider(scale),
          SizedBox(height: 5 * scale),
          Row(
            children: [
              Expanded(flex: 7, child: Text('ORDERED ITEM', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: headerSize))),
              Expanded(flex: 3, child: Text('QTY', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: headerSize))),
            ],
          ),
          SizedBox(height: 4 * scale),
          _buildKotItemRow('${_kotShowBrand ? "Chef Special - " : ""}Grilled Chicken Breast', '2.0', scale, modifier: _kotShowNotes ? '* Medium Spicy, Extra Sauce' : null),
          _buildKotItemRow('Garlic Naan Butter', '4.0', scale),
          _buildKotItemRow('Fresh Passion Juice Pitcher', '1.0', scale, modifier: _kotShowNotes ? '* No Sugar Added' : null),
          SizedBox(height: 6 * scale),
          _dashedDivider(scale),
          if (_kotFooterNoteCtrl.text.isNotEmpty) ...[
            SizedBox(height: 6 * scale),
            Text(
              _kotFooterNoteCtrl.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontStyle: FontStyle.italic, fontSize: noteSize, color: Colors.black),
            ),
          ],
          if (_kotShowCutLine) ...[
            SizedBox(height: 10 * scale),
            Center(
              child: Text('✂ - - - - - - - - TEAR HERE - - - - - - - - ✂', style: TextStyle(fontFamily: 'monospace', fontSize: 9 * scale, color: Colors.grey)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKotItemRow(String name, String qty, double scale, {String? modifier}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(flex: 7, child: Text(name, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11 * scale))),
              Expanded(flex: 3, child: Text(qty, textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 13.5 * scale))),
            ],
          ),
          if (modifier != null) ...[
            SizedBox(height: 1 * scale),
            Text(modifier, style: TextStyle(fontFamily: 'monospace', fontStyle: FontStyle.italic, fontSize: 9 * scale, color: const Color(0xFFDC2626))),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // LIVE TOKEN SLIP PREVIEW WIDGET (TAB 4)
  // =========================================================================
  Widget _buildLiveTokenPreviewPaper() {
    final width = _tokenThermalWidth == '58mm' ? 260.0 : 340.0;

    // Dynamic typography scaling based on _tokenFontSize
    double scale = 1.0;
    if (_tokenFontSize == 'SMALL') scale = 0.85;
    if (_tokenFontSize == 'LARGE') scale = 1.25;

    final double titleSize = 14.0 * scale;
    final double subtextSize = 9.5 * scale;
    final double counterSize = 11.0 * scale;
    final double metaSize = 9.5 * scale;
    final double noteSize = 9.0 * scale;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_tokenShowStoreName) ...[
            Center(
              child: Text(
                _tokenHeaderTitleCtrl.text.isEmpty ? 'ORDER TOKEN SLIP' : _tokenHeaderTitleCtrl.text,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: titleSize, color: Colors.black),
              ),
            ),
            if (_tokenHeaderSubtextCtrl.text.isNotEmpty) ...[
              SizedBox(height: 2 * scale),
              Text(
                _tokenHeaderSubtextCtrl.text,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'monospace', fontSize: subtextSize, color: const Color(0xFF64748B)),
              ),
            ],
            SizedBox(height: 6 * scale),
            _dashedDivider(scale),
            SizedBox(height: 6 * scale),
          ],

          if (_tokenShowBigNumber) ...[
            _buildTokenBadge(scale),
            SizedBox(height: 8 * scale),
          ],

          if (_tokenShowCounter && _tokenCounterLabelCtrl.text.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.symmetric(vertical: 4 * scale, horizontal: 8),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
              child: Center(
                child: Text(
                  _tokenCounterLabelCtrl.text,
                  style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: counterSize, color: const Color(0xFF0F172A)),
                ),
              ),
            ),
            SizedBox(height: 6 * scale),
          ],

          if (_tokenShowOrderNo || _tokenShowTimestamp) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_tokenShowOrderNo) Text('Order: #ORD-0842', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: metaSize)),
                if (_tokenShowTimestamp) Text('27-Sep-2026 14:05', style: TextStyle(fontFamily: 'monospace', fontSize: metaSize * 0.95, color: Colors.grey.shade700)),
              ],
            ),
          ],

          if (_tokenShowCustomer) ...[
            SizedBox(height: 3 * scale),
            Text('Customer: Jane Kamau (+254 712 ***)', style: TextStyle(fontFamily: 'monospace', fontSize: metaSize)),
          ],

          if (_tokenShowItemsSummary) ...[
            SizedBox(height: 6 * scale),
            _dashedDivider(scale),
            SizedBox(height: 4 * scale),
            Row(
              children: [
                Expanded(flex: 7, child: Text('ITEM ORDER SUMMARY', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9.5 * scale))),
                Expanded(flex: 3, child: Text('QTY', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9.5 * scale))),
              ],
            ),
            SizedBox(height: 3 * scale),
            _buildTokenItemSummaryRow('Beef Burger Double Combo', '1', scale),
            _buildTokenItemSummaryRow('French Fries Large', '2', scale),
            _buildTokenItemSummaryRow('Vanilla Shake 400ml', '1', scale),
          ],

          if (_tokenShowItemCount) ...[
            SizedBox(height: 4 * scale),
            _dashedDivider(scale),
            SizedBox(height: 4 * scale),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL ITEMS / UNITS:', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9.5 * scale)),
                Text('3 Items (Qty: 4)', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 10 * scale)),
              ],
            ),
          ],

          if (_tokenShowBarcode) ...[
            SizedBox(height: 8 * scale),
            Center(
              child: Column(
                children: [
                  Icon(Icons.view_column, size: 36 * scale, color: Colors.black87),
                  Text('*TK-104-0842*', style: TextStyle(fontFamily: 'monospace', fontSize: 8.5 * scale, letterSpacing: 2)),
                ],
              ),
            ),
          ],

          if (_tokenFooterNoteCtrl.text.isNotEmpty) ...[
            SizedBox(height: 8 * scale),
            Text(
              _tokenFooterNoteCtrl.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontSize: noteSize, color: Colors.grey.shade700),
            ),
          ],

          if (_tokenShowCutLine) ...[
            SizedBox(height: 10 * scale),
            Center(
              child: Text('✂ - - - - - - - - TEAR HERE - - - - - - - - ✂', style: TextStyle(fontFamily: 'monospace', fontSize: 9 * scale, color: Colors.grey)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTokenBadge(double scale) {
    switch (_tokenBadgeStyle) {
      case 'BORDER_BOX':
        return Container(
          padding: EdgeInsets.symmetric(vertical: 10 * scale, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text('YOUR TOKEN NUMBER', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 10 * scale, letterSpacing: 1.5)),
              SizedBox(height: 2 * scale),
              Text('104', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 38 * scale, color: Colors.black, letterSpacing: 3)),
            ],
          ),
        );
      case 'CIRCLE':
        return Center(
          child: Container(
            width: 100 * scale,
            height: 100 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('TOKEN', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9 * scale, color: Colors.white70, letterSpacing: 1.5)),
                Text('104', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 34 * scale, color: Colors.white)),
              ],
            ),
          ),
        );
      case 'MINIMAL':
        return Container(
          padding: EdgeInsets.symmetric(vertical: 6 * scale),
          child: Column(
            children: [
              Text('TOKEN NUMBER', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 10 * scale, color: Colors.grey.shade700, letterSpacing: 1.5)),
              Text('TK-104', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 36 * scale, color: Colors.black, letterSpacing: 2)),
              Container(height: 2, width: 120 * scale, color: Colors.black),
            ],
          ),
        );
      case 'INVERTED_BOX':
      default:
        return Container(
          padding: EdgeInsets.symmetric(vertical: 12 * scale, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              Text('TOKEN NUMBER', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 10 * scale, color: Colors.white70, letterSpacing: 1.5)),
              SizedBox(height: 2 * scale),
              Text('104', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 40 * scale, color: Colors.white, letterSpacing: 3)),
            ],
          ),
        );
    }
  }

  Widget _buildTokenItemSummaryRow(String name, String qty, double scale) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.5 * scale),
      child: Row(
        children: [
          Expanded(flex: 7, child: Text('• $name', style: TextStyle(fontFamily: 'monospace', fontSize: 9 * scale))),
          Expanded(flex: 3, child: Text(qty, textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9.5 * scale))),
        ],
      ),
    );
  }

  // =========================================================================
  // HELPER REUSABLE WIDGETS
  // =========================================================================
  Widget _buildCardHeader(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, color: primaryColor, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
      ],
    );
  }

  Widget _buildCardWrapper({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: _inputDecoration(hint: hint),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildSwitch(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile.adaptive(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildColorOption(String key, String label, Color color, {required String selectedKey, required ValueChanged<String> onSelect}) {
    final isSelected = selectedKey == key;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
            border: Border.all(color: isSelected ? color : const Color(0xFFE2E8F0), width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Flexible(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? color : Colors.black87), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11.5, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
    );
  }

  Widget _dashedDivider([double scale = 1.0]) {
    return Text(
      '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: TextStyle(fontFamily: 'monospace', color: Colors.grey, fontSize: 10 * scale),
    );
  }
}

import 'billing_charge_model.dart';
import 'sale_item_model.dart';
import 'sale_scheme_model.dart';
import 'tax_breakdown_model.dart';
import 'dart:convert';
import 'dart:math' as math;

class SaleOrder {
  final String saleNo;
  final DateTime saleDate;
  final String status;
  final String orderType;
  final String billingCountry;
  final String billingTaxMode;
  final String billFormat;
  final String? saleSource;
  final String? customerName;
  final String? customerPhone;
  final String? doctorName;
  final String? patientName;
  final double amountPaid;
  final double changeAmount;
  final double balanceDue;
  final String? customerAddress;
  final String? customerGstin;
  final String paymentMode;
  final String? paymentReference;
  final double subTotal;
  final double totalQty;
  final double taxPercent;
  final int? schemeId;
  final String? schemeName;
  final String? schemeUsageMode;
  final double schemeDiscount;
  final String? manualDiscountType;
  final double manualDiscountValue;
  final double manualDiscountAmount;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalTax;
  final List<TaxBreakdown> taxBreakup;
  final List<BillingCharge> charges;
  final double chargeTotal;
  final double chargeTaxTotal;
  final double totalDiscount;
  final double couponDiscountAmount;
  final Map<String, dynamic>? paymentGatewayDetails;
  final double roundOffAmount;
  final double netAmount;
  final String? voucherCode;
  final String? voucherLabel;
  final String? voucherFooterMessage;
  final int loyaltyPointsEarned;
  final int loyaltyPointsRedeemed;
  final double loyaltyDiscountAmount;
  final String? notes;
  final String? modificationNote;
  final String? returnStatus;
  final String? returnType;
  final String? refundStatus;
  final double refundAmount;
  final DateTime? refundPaidAt;
  final String? refundPaymentMode;
  final List<dynamic>? returnedItems;
  final String? exchangeAgainstBillNo;
  final bool hasBillNo;
  final bool affectStock;
  final List<SaleScheme> selectedSchemes;
  final List<SaleItem> items;
  final bool itemsPreSplit;
  final int? orderId;
  final List<dynamic>? luckyDrawVouchers;

  SaleOrder({
    required this.saleNo,
    required this.saleDate,
    required this.status,
    this.modificationNote,
    required this.orderType,
    required this.billingCountry,
    required this.billingTaxMode,
    required this.billFormat,
    this.saleSource,
    this.customerName,
    this.customerPhone,
    this.doctorName,
    this.patientName,
    required this.amountPaid,
    required this.changeAmount,
    required this.balanceDue,
    this.customerAddress,
    this.customerGstin,
    required this.paymentMode,
    this.paymentReference,
    required this.subTotal,
    required this.totalQty,
    required this.taxPercent,
    this.schemeId,
    this.schemeName,
    this.schemeUsageMode,
    required this.schemeDiscount,
    this.manualDiscountType,
    required this.manualDiscountValue,
    required this.manualDiscountAmount,
    required this.taxableAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.totalTax,
    required this.taxBreakup,
    required this.charges,
    required this.chargeTotal,
    required this.chargeTaxTotal,
    required this.totalDiscount,
    this.couponDiscountAmount = 0,
    this.paymentGatewayDetails,
    required this.roundOffAmount,
    required this.netAmount,
    this.voucherCode,
    this.voucherLabel,
    this.voucherFooterMessage,
    this.loyaltyPointsEarned = 0,
    this.loyaltyPointsRedeemed = 0,
    this.loyaltyDiscountAmount = 0,
    this.notes,
    this.returnStatus,
    this.returnType,
    this.refundStatus,
    this.refundAmount = 0.0,
    this.refundPaidAt,
    this.refundPaymentMode,
    this.returnedItems,
    this.exchangeAgainstBillNo,
    this.hasBillNo = false,
    this.orderId,
    required this.items,
    this.selectedSchemes = const [],
    this.affectStock = true,
    this.itemsPreSplit = false,
    this.luckyDrawVouchers,
  });

  Map<String, dynamic> toJson() {
    return {
      'header': {
        'sale_no': saleNo,
        'sale_date': saleDate.toIso8601String(),
        'status': status,
        'order_type': orderType,
        'billing_country': billingCountry,
        'billing_tax_mode': billingTaxMode,
        'bill_format': billFormat,
        'sale_source': saleSource,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'doctor_name': doctorName,
        'patient_name': patientName,
        'customer_address': customerAddress,
        'customer_gstin': customerGstin,
        'payment_mode': paymentMode,
        'payment_reference': paymentReference,
        'sub_total': subTotal,
        'total_qty': totalQty,
        'tax_percent': taxPercent,
        'scheme_id': schemeId,
        'amount_paid': amountPaid,
        'change_amount': changeAmount,
        'balance_due': balanceDue,
        'scheme_name': schemeName,
        'scheme_usage_mode': schemeUsageMode,
        'scheme_discount': schemeDiscount,
        'manual_discount_type': manualDiscountType,
        'manual_discount_value': manualDiscountValue,
        'manual_discount_amount': manualDiscountAmount,
        'taxable_amount': taxableAmount,
        'cgst_amount': cgstAmount,
        'sgst_amount': sgstAmount,
        'igst_amount': igstAmount,
        'total_tax': totalTax,
        'tax_breakup': taxBreakup.map((entry) => entry.toJson()).toList(),
        'charges': charges.map((entry) => entry.toJson()).toList(),
        'charge_total': chargeTotal,
        'charge_tax_total': chargeTaxTotal,
        'total_discount': totalDiscount,
        'coupon_discount_amount': couponDiscountAmount,
        'payment_gateway_details': paymentGatewayDetails,
        'round_off_amount': roundOffAmount,
        'net_amount': netAmount,
        'voucher_code': voucherCode,
        'voucher_label': voucherLabel,
        'loyalty_points_earned': loyaltyPointsEarned,
        'loyalty_points_redeemed': loyaltyPointsRedeemed,
        'loyalty_discount_amount': loyaltyDiscountAmount,
        'notes': notes,
        'modification_note': modificationNote,
        'refund_amount': refundAmount,
        'refund_paid_at': refundPaidAt?.toIso8601String(),
        'refund_payment_mode': refundPaymentMode,
        'refund_status': refundStatus,
        'exchange_against_bill_no': exchangeAgainstBillNo,
        'has_bill_no': hasBillNo,
        'order_id': orderId,
        'affect_stock': affectStock,
        'selected_schemes': selectedSchemes.map((scheme) => scheme.toJson()).toList(),
        'items_pre_split': itemsPreSplit,
        'lucky_draw_vouchers': luckyDrawVouchers,
      },
      'items': items.map((e) => e.toJson()).toList(),
    };
  }

  factory SaleOrder.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic value) =>
        double.tryParse(value?.toString() ?? '') ?? 0;

    double refundAmt = parseNum(json['refund_amount'] ?? json['refundAmount']);
    final refund = json['refund_details'];
    if (refundAmt == 0.0 && refund != null) {
      final paid = double.tryParse(refund['amount_paid']?.toString() ?? '0.0') ?? 0.0;
      final pending = double.tryParse(refund['amount_pending']?.toString() ?? '0.0') ?? 0.0;
      refundAmt = paid > 0 ? paid : pending;
    }
    final gatewayDetails = json['payment_gateway_details'];
    if (gatewayDetails != null) {
      try {
        final dynamic details = gatewayDetails is String ? jsonDecode(gatewayDetails) : gatewayDetails;
        if (details != null && details['refund_amount'] != null) {
          refundAmt = double.tryParse(details['refund_amount'].toString()) ?? refundAmt;
        }
      } catch (_) {}
    }
    Map<String, dynamic>? parsedGatewayDetails;
    double couponDiscountAmount = parseNum(json['coupon_discount_amount']);
    final rawCharges = json['charges'];
    if (couponDiscountAmount <= 0.0009 && rawCharges is List) {
      for (final entry in rawCharges) {
        if (entry is! Map) continue;
        final code = entry['code']?.toString().trim().toUpperCase() ?? '';
        final name = entry['name']?.toString().trim().toUpperCase() ?? '';
        if (code == 'COUPON_DISCOUNT' || name.contains('COUPON DISCOUNT')) {
          couponDiscountAmount = math.max(
            couponDiscountAmount,
            (double.tryParse(entry['amount']?.toString() ?? '0') ?? 0).abs(),
          );
        }
      }
    }
    if (gatewayDetails != null) {
      try {
        final dynamic details = gatewayDetails is String ? jsonDecode(gatewayDetails) : gatewayDetails;
        if (details is Map) {
          parsedGatewayDetails = Map<String, dynamic>.from(details);
          couponDiscountAmount = math.max(
            couponDiscountAmount,
            double.tryParse(parsedGatewayDetails['coupon_discount_amount']?.toString() ?? '0') ?? 0,
          );
        }
      } catch (_) {}
    }

    final refundPaidAtVal = json['refund_paid_at']?.toString() ?? (refund != null ? refund['refund_date']?.toString() : null);
    final refundPaymentModeVal = json['refund_payment_mode']?.toString() ?? (refund != null ? refund['payment_mode']?.toString() : null);

    return SaleOrder(
      saleNo: json['sale_no']?.toString() ?? '',
      saleDate: (DateTime.tryParse(json['sale_date']?.toString() ?? '') ??
              DateTime.now())
          .toLocal(),
      status: json['status']?.toString() ?? 'COMPLETED',
      orderType: json['order_type']?.toString() ?? 'B2C',
      billingCountry: json['billing_country']?.toString() ?? 'India',
      billingTaxMode: json['billing_tax_mode']?.toString() ?? 'CGST_SGST',
      billFormat: json['bill_format']?.toString() ?? 'A4',
      saleSource: json['sale_source']?.toString(),
      customerName: json['customer_name']?.toString(),
      customerPhone: json['customer_phone']?.toString(),
      doctorName: json['doctor_name']?.toString(),
      patientName: json['patient_name']?.toString(),
      customerAddress: json['customer_address']?.toString(),
      customerGstin: json['customer_gstin']?.toString(),
      paymentMode: json['payment_mode']?.toString() ?? 'CASH',
      paymentReference: json['payment_reference']?.toString(),
      amountPaid: parseNum(json['amount_paid']),
      changeAmount: parseNum(json['change_amount']),
      balanceDue: parseNum(json['balance_due']),
      subTotal: parseNum(json['sub_total']),
      totalQty: parseNum(json['total_qty']),
      taxPercent: parseNum(json['tax_percent']),
      schemeId: json['scheme_id'],
      schemeName: json['scheme_name']?.toString(),
      schemeUsageMode: json['scheme_usage_mode']?.toString(),
      schemeDiscount: parseNum(json['scheme_discount']),
      manualDiscountType: json['manual_discount_type']?.toString(),
      manualDiscountValue: parseNum(json['manual_discount_value']),
      manualDiscountAmount: parseNum(json['manual_discount_amount']),
      taxableAmount: parseNum(json['taxable_amount']),
      cgstAmount: parseNum(json['cgst_amount']),
      sgstAmount: parseNum(json['sgst_amount']),
      igstAmount: parseNum(json['igst_amount']),
      totalTax: parseNum(json['total_tax']),
      taxBreakup: (json['tax_breakup'] as List? ?? const [])
          .map((entry) =>
              TaxBreakdown.fromJson(Map<String, dynamic>.from(entry)))
          .toList(),
      charges: (json['charges'] as List? ?? const [])
          .map((entry) =>
              BillingCharge.fromJson(Map<String, dynamic>.from(entry)))
          .toList(),
      chargeTotal: parseNum(json['charge_total']),
      chargeTaxTotal: parseNum(json['charge_tax_total']),
      totalDiscount: parseNum(json['total_discount']),
      couponDiscountAmount: couponDiscountAmount,
      paymentGatewayDetails: parsedGatewayDetails,
      roundOffAmount: parseNum(json['round_off_amount']),
      netAmount: parseNum(json['net_amount']),
      voucherCode: json['voucher_code']?.toString(),
      voucherLabel: json['voucher_label']?.toString(),
      voucherFooterMessage: null,
      loyaltyPointsEarned:
          int.tryParse((json['loyalty_points_earned'] ?? 0).toString()) ?? 0,
      loyaltyPointsRedeemed:
          int.tryParse((json['loyalty_points_redeemed'] ?? 0).toString()) ?? 0,
      loyaltyDiscountAmount: parseNum(json['loyalty_discount_amount']),
      notes: json['notes']?.toString(),
      modificationNote: json['modification_note']?.toString(),
      refundStatus: json['refund_status']?.toString(),
      refundAmount: refundAmt,
      refundPaidAt: DateTime.tryParse(refundPaidAtVal ?? ''),
      refundPaymentMode: refundPaymentModeVal,
      exchangeAgainstBillNo: json['exchange_against_bill_no']?.toString(),
      hasBillNo: json['has_bill_no'] != null
          ? (json['has_bill_no'] == true || json['has_bill_no'].toString() == '1')
          : (json['sale_no']?.toString() ?? '').trim().isNotEmpty,
      orderId: json['order_id'] != null
          ? int.tryParse(json['order_id'].toString())
          : (() {
              final notesStr = json['notes']?.toString() ?? '';
              final match = RegExp(r'delivery order #(\d+)').firstMatch(notesStr);
              return match != null ? int.tryParse(match.group(1) ?? '') : null;
            })(),
      affectStock: json['affect_stock'] ?? true,
      selectedSchemes: (json['selected_schemes'] as List? ?? const [])
          .map((entry) => SaleScheme.fromJson(Map<String, dynamic>.from(entry)))
          .toList(),
      itemsPreSplit: json['items_pre_split'] == true,
      luckyDrawVouchers: json['lucky_draw_vouchers'] as List?,
      items: (json['items'] as List? ?? const [])
          .map((entry) => SaleItem.fromJson(Map<String, dynamic>.from(entry)))
          .toList(),
    );
  }
}

double _toDouble(dynamic value) => double.tryParse(value.toString()) ?? 0;

class SalesReportCharge {
  final String name;
  final String code;
  final double amount;
  final double taxPercent;
  final double taxAmount;
  final bool taxable;

  const SalesReportCharge({
    required this.name,
    required this.code,
    required this.amount,
    required this.taxPercent,
    required this.taxAmount,
    required this.taxable,
  });

  factory SalesReportCharge.fromJson(Map<String, dynamic> json) {
    return SalesReportCharge(
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      amount: _toDouble(json['amount']),
      taxPercent: _toDouble(json['tax_percent'] ?? json['taxPercent']),
      taxAmount: _toDouble(json['tax_amount'] ?? json['taxAmount']),
      taxable: json['taxable'] ?? false,
    );
  }
}

class SalesTaxSummary {
  final String label;
  final double amount;

  const SalesTaxSummary({
    required this.label,
    required this.amount,
  });

  factory SalesTaxSummary.fromJson(Map<String, dynamic> json) {
    return SalesTaxSummary(
      label: json['label'] ?? '',
      amount: _toDouble(json['amount']),
    );
  }
}

class SalesReportItem {
  final String itemCode;
  final String itemName;
  final String itemGroup;
  final String subCategory;
  final String brand;
  final String hsnSacCode;
  final String unit;
  final double qty;
  final double rate;
  final double amount;
  final double lineDiscount;
  final double taxableAmount;
  final double taxAmount;
  final double netAmount;
  final double estimatedCost;
  final double estimatedProfit;
  final List<SalesTaxBreakupEntry> taxBreakup;

  const SalesReportItem({
    required this.itemCode,
    required this.itemName,
    required this.itemGroup,
    required this.subCategory,
    required this.brand,
    required this.hsnSacCode,
    required this.unit,
    required this.qty,
    required this.rate,
    required this.amount,
    required this.lineDiscount,
    required this.taxableAmount,
    required this.taxAmount,
    required this.netAmount,
    required this.estimatedCost,
    required this.estimatedProfit,
    required this.taxBreakup,
  });

  factory SalesReportItem.fromJson(Map<String, dynamic> json) {
    return SalesReportItem(
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'] ?? '',
      itemGroup: json['item_group'] ?? '',
      subCategory: json['sub_category'] ?? '',
      brand: json['brand'] ?? '',
      hsnSacCode:
          json['hsn_sac_code'] ?? json['hsn_code'] ?? json['hsn'] ?? '',
      unit: json['unit'] ?? '',
      qty: _toDouble(json['qty']),
      rate: _toDouble(json['rate']),
      amount: _toDouble(json['amount']),
      lineDiscount: _toDouble(json['line_discount'] ?? json['lineDiscount']),
      taxableAmount: _toDouble(json['taxable_amount']),
      taxAmount: _toDouble(json['tax_amount']),
      netAmount: _toDouble(json['net_amount']),
      estimatedCost: _toDouble(json['estimated_cost']),
      estimatedProfit: _toDouble(json['estimated_profit']),
      taxBreakup: (json['tax_breakup'] as List? ?? [])
          .map((e) => SalesTaxBreakupEntry.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(),
    );
  }
}

class SalesTaxBreakupEntry {
  final String code;
  final String label;
  final double rate;
  final double taxableAmount;
  final double taxAmount;

  const SalesTaxBreakupEntry({
    required this.code,
    required this.label,
    required this.rate,
    required this.taxableAmount,
    required this.taxAmount,
  });

  factory SalesTaxBreakupEntry.fromJson(Map<String, dynamic> json) {
    return SalesTaxBreakupEntry(
      code: json['code'] ?? '',
      label: json['label'] ?? '',
      rate: _toDouble(json['rate']),
      taxableAmount: _toDouble(json['taxable_amount']),
      taxAmount: _toDouble(json['tax_amount']),
    );
  }
}

class SalesReport {
  final int id;
  final String saleNo;
  final DateTime saleDate;
  final String saleZone;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String customerGstin;
  final String paymentMode;
  final String paymentReference;
  final String orderType;
  final String billingTaxMode;
  final String schemeName;
  final double totalQty;
  final double subTotal;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalTax;
  final double chargeTotal;
  final double totalDiscount;
  final double netAmount;
  final double estimatedCost;
  final double estimatedProfit;
  final List<SalesReportCharge> charges;
  final List<SalesReportItem> items;

  const SalesReport({
    required this.id,
    required this.saleNo,
    required this.saleDate,
    required this.saleZone,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.customerGstin,
    required this.paymentMode,
    required this.paymentReference,
    required this.orderType,
    required this.billingTaxMode,
    required this.schemeName,
    required this.totalQty,
    required this.subTotal,
    required this.taxableAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.totalTax,
    required this.chargeTotal,
    required this.totalDiscount,
    required this.netAmount,
    required this.estimatedCost,
    required this.estimatedProfit,
    required this.charges,
    required this.items,
  });

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    return SalesReport(
      id: json['id'] ?? 0,
      saleNo: json['sale_no'] ?? '',
      saleDate: DateTime.parse(json['sale_date']).toLocal(),
      saleZone: json['sale_zone'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      customerAddress: json['customer_address'] ?? '',
      customerGstin: json['customer_gstin'] ?? '',
      paymentMode: json['payment_mode'] ?? '',
      paymentReference: json['payment_reference'] ?? '',
      orderType: json['order_type'] ?? '',
      billingTaxMode: json['billing_tax_mode'] ?? '',
      schemeName: json['scheme_name'] ?? '',
      totalQty: _toDouble(json['total_qty']),
      subTotal: _toDouble(json['sub_total']),
      taxableAmount: _toDouble(json['taxable_amount']),
      cgstAmount: _toDouble(json['cgst_amount']),
      sgstAmount: _toDouble(json['sgst_amount']),
      igstAmount: _toDouble(json['igst_amount']),
      totalTax: _toDouble(json['total_tax']),
      chargeTotal: _toDouble(json['charge_total']),
      totalDiscount: _toDouble(json['total_discount']),
      netAmount: _toDouble(json['net_amount']),
      estimatedCost: _toDouble(json['estimated_cost']),
      estimatedProfit: _toDouble(json['estimated_profit']),
      charges: (json['charges'] as List? ?? [])
          .map((e) => SalesReportCharge.fromJson(e))
          .toList(),
      items: (json['items'] as List? ?? [])
          .map((e) => SalesReportItem.fromJson(e))
          .toList(),
    );
  }
}

class SalesSummary {
  final double totalQty;
  final double grossSales;
  final double taxableAmount;
  final double totalDiscount;
  final double totalCharges;
  final double packingChargesCollected;
  final double otherChargesCollected;
  final double gstCollected;
  final double vatCollected;
  final double otherTaxesCollected;
  final double totalTaxesCollected;
  final double totalRevenue;
  final double subscriptionRealized;
  final double estimatedCost;
  final double estimatedProfit;
  final double estimatedLoss;
  final int totalBills;

  const SalesSummary({
    required this.totalQty,
    required this.grossSales,
    required this.taxableAmount,
    required this.totalDiscount,
    required this.totalCharges,
    required this.packingChargesCollected,
    required this.otherChargesCollected,
    required this.gstCollected,
    required this.vatCollected,
    required this.otherTaxesCollected,
    required this.totalTaxesCollected,
    required this.totalRevenue,
    required this.subscriptionRealized,
    required this.estimatedCost,
    required this.estimatedProfit,
    required this.estimatedLoss,
    required this.totalBills,
  });

  factory SalesSummary.fromJson(Map<String, dynamic> json) {
    return SalesSummary(
      totalQty: _toDouble(json['total_qty']),
      grossSales: _toDouble(json['gross_sales']),
      taxableAmount: _toDouble(json['taxable_amount']),
      totalDiscount: _toDouble(json['total_discount']),
      totalCharges: _toDouble(json['total_charges']),
      packingChargesCollected: _toDouble(json['packing_charges_collected']),
      otherChargesCollected: _toDouble(json['other_charges_collected']),
      gstCollected: _toDouble(json['gst_collected']),
      vatCollected: _toDouble(json['vat_collected']),
      otherTaxesCollected: _toDouble(json['other_taxes_collected']),
      totalTaxesCollected: _toDouble(json['total_taxes_collected']),
      totalRevenue: _toDouble(json['total_revenue']),
      subscriptionRealized: _toDouble(json['subscription_realized']),
      estimatedCost: _toDouble(json['estimated_cost']),
      estimatedProfit: _toDouble(json['estimated_profit']),
      estimatedLoss: _toDouble(json['estimated_loss']),
      totalBills: json['total_bills'] ?? 0,
    );
  }

  static const empty = SalesSummary(
    totalQty: 0,
    grossSales: 0,
    taxableAmount: 0,
    totalDiscount: 0,
    totalCharges: 0,
    packingChargesCollected: 0,
    otherChargesCollected: 0,
    gstCollected: 0,
    vatCollected: 0,
    otherTaxesCollected: 0,
    totalTaxesCollected: 0,
    totalRevenue: 0,
    subscriptionRealized: 0,
    estimatedCost: 0,
    estimatedProfit: 0,
    estimatedLoss: 0,
    totalBills: 0,
  );
}

class SalesBreakdownEntry {
  final String key;
  final String label;
  final double amount;
  final double profit;
  final int count;

  const SalesBreakdownEntry({
    required this.key,
    required this.label,
    required this.amount,
    required this.profit,
    this.count = 0,
  });

  factory SalesBreakdownEntry.fromJson(
    Map<String, dynamic> json, {
    String keyField = 'payment_mode',
    String labelField = 'label',
    String amountField = 'amount',
    String profitField = 'profit',
    String countField = 'sales_count',
  }) {
    final key = (json[keyField] ?? json['zone'] ?? '').toString();
    return SalesBreakdownEntry(
      key: key,
      label: (json[labelField] ?? key).toString(),
      amount: _toDouble(json[amountField] ?? json['total_sales']),
      profit: _toDouble(json[profitField]),
      count: int.tryParse((json[countField] ?? 0).toString()) ?? 0,
    );
  }
}

class SalesHeatmapRow {
  final String itemName;
  final String itemCode;
  final double totalQty;
  final double totalSales;
  final Map<String, double> zones;

  const SalesHeatmapRow({
    required this.itemName,
    required this.itemCode,
    required this.totalQty,
    required this.totalSales,
    required this.zones,
  });

  factory SalesHeatmapRow.fromJson(Map<String, dynamic> json) {
    final rawZones = (json['zones'] as Map?) ?? {};
    return SalesHeatmapRow(
      itemName: json['item_name'] ?? '',
      itemCode: json['item_code'] ?? '',
      totalQty: _toDouble(json['total_qty']),
      totalSales: _toDouble(json['total_sales']),
      zones: rawZones.map(
        (key, value) => MapEntry(key.toString(), _toDouble(value)),
      ),
    );
  }
}

class SalesComparisonPoint {
  final String period;
  final double sales;
  final double profit;
  final double loss;
  final double profitChange;
  final double lossChange;

  const SalesComparisonPoint({
    required this.period,
    required this.sales,
    required this.profit,
    required this.loss,
    required this.profitChange,
    required this.lossChange,
  });

  factory SalesComparisonPoint.fromJson(Map<String, dynamic> json) {
    return SalesComparisonPoint(
      period: json['period'] ?? '',
      sales: _toDouble(json['sales']),
      profit: _toDouble(json['profit']),
      loss: _toDouble(json['loss']),
      profitChange: _toDouble(json['profit_change']),
      lossChange: _toDouble(json['loss_change']),
    );
  }
}

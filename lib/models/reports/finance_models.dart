DateTime _parseApiDate(dynamic raw) {
  final text = (raw ?? '').toString().trim();
  if (text.isEmpty) return DateTime.now();

  final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (dateOnly != null) {
    return DateTime(
      int.parse(dateOnly.group(1)!),
      int.parse(dateOnly.group(2)!),
      int.parse(dateOnly.group(3)!),
    );
  }

  final parsed = DateTime.tryParse(text);
  if (parsed == null) return DateTime.now();
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

class CashLedgerEntry {
  final int id;
  final DateTime txnDate;
  final String transactionType;
  final String referenceType;
  final String? referenceId;
  final String referenceNo;
  final String partyName;
  final String paymentMethod;
  final double amountIn;
  final double amountOut;
  final double adjustmentAmount;
  final double balance;
  final String notes;

  const CashLedgerEntry({
    required this.id,
    required this.txnDate,
    required this.transactionType,
    required this.referenceType,
    this.referenceId,
    required this.referenceNo,
    required this.partyName,
    required this.paymentMethod,
    required this.amountIn,
    required this.amountOut,
    required this.adjustmentAmount,
    required this.balance,
    required this.notes,
  });

  factory CashLedgerEntry.fromJson(Map<String, dynamic> json) {
    double numVal(dynamic value) =>
        double.tryParse((value ?? 0).toString()) ?? 0;

    return CashLedgerEntry(
      id: int.tryParse((json['id'] ?? 0).toString()) ?? 0,
      txnDate: _parseApiDate(json['txn_date']),
      transactionType: (json['transaction_type'] ?? '').toString(),
      referenceType: (json['reference_type'] ?? '').toString(),
      referenceId: json['reference_id']?.toString(),
      referenceNo: (json['reference_no'] ?? '').toString(),
      partyName: (json['party_name'] ?? '').toString(),
      paymentMethod: (json['payment_method'] ?? '').toString(),
      amountIn: numVal(json['amount_in']),
      amountOut: numVal(json['amount_out']),
      adjustmentAmount: numVal(json['adjustment_amount']),
      balance: numVal(json['balance']),
      notes: (json['notes'] ?? '').toString(),
    );
  }
}

class LedgerDayGroup {
  final DateTime date;
  final double openingBalance;
  final double closingBalance;
  final List<CashLedgerEntry> entries;

  const LedgerDayGroup({
    required this.date,
    required this.openingBalance,
    required this.closingBalance,
    required this.entries,
  });

  factory LedgerDayGroup.fromJson(Map<String, dynamic> json) {
    double numVal(dynamic value) =>
        double.tryParse((value ?? 0).toString()) ?? 0;

    return LedgerDayGroup(
      date: _parseApiDate(json['date']),
      openingBalance: numVal(json['opening_balance']),
      closingBalance: numVal(json['closing_balance']),
      entries: (json['entries'] as List? ?? const [])
          .map((e) => CashLedgerEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class RepaymentEntry {
  final int id;
  final DateTime paymentDate;
  final double amount;
  final String paymentMode;
  final String referenceNo;
  final String note;

  const RepaymentEntry({
    required this.id,
    required this.paymentDate,
    required this.amount,
    required this.paymentMode,
    required this.referenceNo,
    required this.note,
  });

  factory RepaymentEntry.fromJson(Map<String, dynamic> json) {
    final rawDate = json['payment_date'] ?? json['transaction_date'] ?? json['txn_date'];
    return RepaymentEntry(
      id: int.tryParse((json['id'] ?? 0).toString()) ?? 0,
      paymentDate: _parseApiDate(rawDate),
      amount: double.tryParse((json['amount'] ?? 0).toString()) ?? 0,
      paymentMode: (json['payment_mode'] ?? '').toString(),
      referenceNo: (json['reference_no'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
    );
  }
}

class CreditBill {
  final int saleId;
  final String billNo;
  final DateTime billDate;
  final double amount;
  final double initialPaid;
  final double repaymentTotal;
  final double totalPaid;
  final double outstanding;
  final String paymentStatus;
  final List<RepaymentEntry> payments;

  const CreditBill({
    required this.saleId,
    required this.billNo,
    required this.billDate,
    required this.amount,
    required this.initialPaid,
    required this.repaymentTotal,
    required this.totalPaid,
    required this.outstanding,
    required this.paymentStatus,
    required this.payments,
  });

  factory CreditBill.fromJson(Map<String, dynamic> json) {
    double numVal(dynamic value) =>
        double.tryParse((value ?? 0).toString()) ?? 0;

    return CreditBill(
      saleId: int.tryParse((json['sale_id'] ?? 0).toString()) ?? 0,
      billNo: (json['bill_no'] ?? '').toString(),
      billDate: _parseApiDate(json['bill_date']),
      amount: numVal(json['amount']),
      initialPaid: numVal(json['initial_paid']),
      repaymentTotal: numVal(json['repayment_total']),
      totalPaid: numVal(json['total_paid']),
      outstanding: numVal(json['outstanding']),
      paymentStatus: (json['payment_status'] ?? '').toString(),
      payments: (json['payments'] as List? ?? const [])
          .map((e) => RepaymentEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class AdvanceEntry {
  final int id;
  final DateTime advanceDate;
  final int? sourceSaleId;
  final double originalAmount;
  final double availableAmount;
  final String paymentMode;
  final String referenceNo;
  final String note;

  const AdvanceEntry({
    required this.id,
    required this.advanceDate,
    required this.sourceSaleId,
    required this.originalAmount,
    required this.availableAmount,
    required this.paymentMode,
    required this.referenceNo,
    required this.note,
  });

  factory AdvanceEntry.fromJson(Map<String, dynamic> json) {
    double numVal(dynamic value) =>
        double.tryParse((value ?? 0).toString()) ?? 0;

    return AdvanceEntry(
      id: int.tryParse((json['id'] ?? 0).toString()) ?? 0,
      advanceDate: _parseApiDate(json['advance_date']),
      sourceSaleId:
          int.tryParse((json['source_sale_id'] ?? '').toString()),
      originalAmount: numVal(json['original_amount']),
      availableAmount: numVal(json['available_amount']),
      paymentMode: (json['payment_mode'] ?? '').toString(),
      referenceNo: (json['reference_no'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
    );
  }
}

class CreditCustomerReport {
  final String customerName;
  final String customerPhone;
  final String customerGstin;
  final String customerAddress;
  final double totalOutstanding;
  final double totalAdvance;
  final List<CreditBill> bills;
  final List<AdvanceEntry> advances;

  const CreditCustomerReport({
    required this.customerName,
    required this.customerPhone,
    required this.customerGstin,
    required this.customerAddress,
    required this.totalOutstanding,
    required this.totalAdvance,
    required this.bills,
    required this.advances,
  });

  factory CreditCustomerReport.fromJson(Map<String, dynamic> json) {
    return CreditCustomerReport(
      customerName: (json['customer_name'] ?? '').toString(),
      customerPhone: (json['customer_phone'] ?? '').toString(),
      customerGstin: (json['customer_gstin'] ?? '').toString(),
      customerAddress: (json['customer_address'] ?? '').toString(),
      totalOutstanding:
          double.tryParse((json['total_outstanding'] ?? 0).toString()) ?? 0,
      totalAdvance:
          double.tryParse((json['total_advance'] ?? 0).toString()) ?? 0,
      bills: (json['bills'] as List? ?? const [])
          .map((e) => CreditBill.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      advances: (json['advances'] as List? ?? const [])
          .map((e) => AdvanceEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class ExpenseTaxLine {
  final String taxName;
  final double taxPercentage;
  final double taxAmount;

  const ExpenseTaxLine({
    required this.taxName,
    required this.taxPercentage,
    required this.taxAmount,
  });

  factory ExpenseTaxLine.fromJson(Map<String, dynamic> json) {
    double numVal(dynamic val) => double.tryParse((val ?? 0).toString()) ?? 0.0;
    return ExpenseTaxLine(
      taxName: (json['tax_name'] ?? '').toString(),
      taxPercentage: numVal(json['tax_percentage']),
      taxAmount: numVal(json['tax_amount']),
    );
  }

  Map<String, dynamic> toJson() => {
    'tax_name': taxName,
    'tax_percentage': taxPercentage,
    'tax_amount': taxAmount,
  };
}

class ExpenseDeductionLine {
  final String deductionType;
  final double deductionPercentage;
  final double deductionAmount;

  const ExpenseDeductionLine({
    required this.deductionType,
    required this.deductionPercentage,
    required this.deductionAmount,
  });

  factory ExpenseDeductionLine.fromJson(Map<String, dynamic> json) {
    double numVal(dynamic val) => double.tryParse((val ?? 0).toString()) ?? 0.0;
    return ExpenseDeductionLine(
      deductionType: (json['deduction_type'] ?? '').toString(),
      deductionPercentage: numVal(json['deduction_percentage']),
      deductionAmount: numVal(json['deduction_amount']),
    );
  }

  Map<String, dynamic> toJson() => {
    'deduction_type': deductionType,
    'deduction_percentage': deductionPercentage,
    'deduction_amount': deductionAmount,
  };
}

class ExpenseEntryReport {
  final String id;
  final DateTime expenseDate;
  final String category;
  final double amount;
  final String note;
  final int? vendorId;
  final String? categoryId;
  final String invoiceRefNo;
  final String paymentMethod;
  final bool isTaxInclusive;
  final double baseAmount;
  final double totalTaxAmount;
  final double totalDeductionAmount;
  final double netPayableAmount;
  final String status;
  final String vendorName;
  final List<ExpenseTaxLine> taxes;
  final List<ExpenseDeductionLine> deductions;

  const ExpenseEntryReport({
    required this.id,
    required this.expenseDate,
    required this.category,
    required this.amount,
    required this.note,
    this.vendorId,
    this.categoryId,
    required this.invoiceRefNo,
    required this.paymentMethod,
    required this.isTaxInclusive,
    required this.baseAmount,
    required this.totalTaxAmount,
    required this.totalDeductionAmount,
    required this.netPayableAmount,
    required this.status,
    required this.vendorName,
    required this.taxes,
    required this.deductions,
  });

  factory ExpenseEntryReport.fromJson(Map<String, dynamic> json) {
    double numVal(dynamic val) => double.tryParse((val ?? 0).toString()) ?? 0.0;
    
    // Parse category name from either nested object or direct field
    String parsedCat = '';
    if (json['category'] != null) {
      if (json['category'] is Map) {
        parsedCat = (json['category']['category_name'] ?? '').toString();
      } else {
        parsedCat = json['category'].toString();
      }
    }

    // Parse vendor name and note
    String rawNote = (json['expense_note'] ?? json['note'] ?? '').toString();
    String parsedVendor = 'Direct Cash';
    String parsedNote = rawNote;

    if (json['vendor'] != null && json['vendor'] is Map) {
      parsedVendor = (json['vendor']['supplier_name'] ?? '').toString();
    } else {
      if (rawNote.startsWith('Paid To: ')) {
        final parts = rawNote.split(' | ');
        parsedVendor = parts.first.substring(9);
        parsedNote = parts.length > 1 ? parts.sublist(1).join(' | ') : '';
      } else if (rawNote.startsWith('Paid To Staff: ')) {
        final parts = rawNote.split(' | ');
        parsedVendor = parts.first.substring(15);
        parsedNote = parts.length > 1 ? parts.sublist(1).join(' | ') : '';
      }
    }

    // Parse list of taxes and deductions
    final rawTaxes = json['taxes'] as List? ?? const [];
    final parsedTaxes = rawTaxes
        .map((e) => ExpenseTaxLine.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final rawDeductions = json['deductions'] as List? ?? const [];
    final parsedDeductions = rawDeductions
        .map((e) => ExpenseDeductionLine.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    // Map base/net amounts
    final double netAmount = numVal(json['net_payable_amount'] ?? json['amount']);

    return ExpenseEntryReport(
      id: (json['id'] ?? '').toString(),
      expenseDate: _parseApiDate(json['payment_date'] ?? json['expense_date']),
      category: parsedCat.isNotEmpty ? parsedCat : 'General',
      amount: netAmount, // amount displays final paid amount in list
      note: parsedNote,
      vendorId: int.tryParse((json['vendor_id'] ?? '').toString()),
      categoryId: (json['category_id'] ?? '').toString(),
      invoiceRefNo: (json['invoice_ref_no'] ?? '').toString(),
      paymentMethod: (json['payment_method'] ?? json['payment_mode'] ?? 'CASH').toString(),
      isTaxInclusive: json['is_tax_inclusive'] == true || json['is_tax_inclusive'] == 1,
      baseAmount: numVal(json['base_amount'] ?? json['amount']),
      totalTaxAmount: numVal(json['total_tax_amount']),
      totalDeductionAmount: numVal(json['total_deduction_amount']),
      netPayableAmount: netAmount,
      status: (json['status'] ?? 'Paid').toString(),
      vendorName: parsedVendor,
      taxes: parsedTaxes,
      deductions: parsedDeductions,
    );
  }
}

class IncomeEntryReport {
  final int id;
  final DateTime incomeDate;
  final String source;
  final String partyName;
  final String paymentMethod;
  final String referenceNo;
  final double amount;
  final String note;

  const IncomeEntryReport({
    required this.id,
    required this.incomeDate,
    required this.source,
    required this.partyName,
    required this.paymentMethod,
    required this.referenceNo,
    required this.amount,
    required this.note,
  });

  factory IncomeEntryReport.fromJson(Map<String, dynamic> json) {
    final rawNote = (json['notes'] ?? json['note'] ?? '').toString();
    final party = (json['party_name'] ?? '').toString();
    String source = '';
    String note = '';
    if (rawNote.startsWith('SOURCE:')) {
      for (final line in rawNote.split('\n')) {
        if (line.startsWith('SOURCE:')) {
          source = line.substring(7).trim();
        } else if (line.startsWith('NOTE:')) {
          note = line.substring(5).trim();
        }
      }
    } else {
      source = rawNote;
      note = rawNote;
    }
    return IncomeEntryReport(
      id: int.tryParse((json['id'] ?? 0).toString()) ?? 0,
      incomeDate: _parseApiDate(json['txn_date']),
      source: source.isNotEmpty ? source : party,
      partyName: party,
      paymentMethod: (json['payment_method'] ?? '').toString(),
      referenceNo: (json['reference_no'] ?? '').toString(),
      amount: double.tryParse((json['amount_in'] ?? 0).toString()) ?? 0,
      note: note,
    );
  }
}

class WithdrawalEntryReport {
  final int id;
  final DateTime withdrawalDate;
  final String purpose;
  final String paymentMethod;
  final String referenceNo;
  final double amount;
  final String note;

  const WithdrawalEntryReport({
    required this.id,
    required this.withdrawalDate,
    required this.purpose,
    required this.paymentMethod,
    required this.referenceNo,
    required this.amount,
    required this.note,
  });

  factory WithdrawalEntryReport.fromJson(Map<String, dynamic> json) {
    return WithdrawalEntryReport(
      id: int.tryParse((json['id'] ?? 0).toString()) ?? 0,
      withdrawalDate: _parseApiDate(json['txn_date']),
      purpose: (json['party_name'] ?? json['purpose'] ?? '').toString(),
      paymentMethod: (json['payment_method'] ?? '').toString(),
      referenceNo: (json['reference_no'] ?? '').toString(),
      amount: double.tryParse((json['amount_out'] ?? 0).toString()) ?? 0,
      note: (json['notes'] ?? json['note'] ?? '').toString(),
    );
  }
}

class OpeningBalanceEntry {
  final DateTime balanceDate;
  final double openingBalance;
  final String note;

  const OpeningBalanceEntry({
    required this.balanceDate,
    required this.openingBalance,
    required this.note,
  });

  factory OpeningBalanceEntry.fromJson(Map<String, dynamic> json) {
    return OpeningBalanceEntry(
      balanceDate: _parseApiDate(json['balance_date']),
      openingBalance:
          double.tryParse((json['opening_balance'] ?? 0).toString()) ?? 0,
      note: (json['note'] ?? '').toString(),
    );
  }
}

class DeliveryReportEntry {
  final int saleId;
  final DateTime date;
  final String billNo;
  final String customerName;
  final String customerPhone;
  final double amount;
  final double paidAmount;
  final double outstanding;
  final String paymentMode;
  final String paymentStatus;

  const DeliveryReportEntry({
    required this.saleId,
    required this.date,
    required this.billNo,
    required this.customerName,
    required this.customerPhone,
    required this.amount,
    required this.paidAmount,
    required this.outstanding,
    required this.paymentMode,
    required this.paymentStatus,
  });

  factory DeliveryReportEntry.fromJson(Map<String, dynamic> json) {
    double numVal(dynamic value) =>
        double.tryParse((value ?? 0).toString()) ?? 0;

    return DeliveryReportEntry(
      saleId: int.tryParse((json['sale_id'] ?? 0).toString()) ?? 0,
      date: _parseApiDate(json['date']),
      billNo: (json['bill_no'] ?? '').toString(),
      customerName: (json['customer_name'] ?? '').toString(),
      customerPhone: (json['customer_phone'] ?? '').toString(),
      amount: numVal(json['amount']),
      paidAmount: numVal(json['paid_amount']),
      outstanding: numVal(json['outstanding']),
      paymentMode: (json['payment_mode'] ?? '').toString(),
      paymentStatus: (json['payment_status'] ?? '').toString(),
    );
  }
}

class LedgerPaymentMethodSummary {
  final String paymentMethod;
  final double amountIn;
  final double amountOut;
  final int count;

  const LedgerPaymentMethodSummary({
    required this.paymentMethod,
    required this.amountIn,
    required this.amountOut,
    required this.count,
  });

  factory LedgerPaymentMethodSummary.fromJson(Map<String, dynamic> json) {
    double numVal(dynamic value) =>
        double.tryParse((value ?? 0).toString()) ?? 0;

    return LedgerPaymentMethodSummary(
      paymentMethod: (json['payment_method'] ?? '').toString(),
      amountIn: numVal(json['amount_in']),
      amountOut: numVal(json['amount_out']),
      count: int.tryParse((json['count'] ?? 0).toString()) ?? 0,
    );
  }
}

class ExpiryReportEntry {
  final int id;
  final String itemCode;
  final String itemName;
  final double qty;
  final String unit;
  final DateTime expiryDate;
  final int daysLeft;
  final String status;
  final String grnNo;
  final DateTime? receiptDate;

  const ExpiryReportEntry({
    required this.id,
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.unit,
    required this.expiryDate,
    required this.daysLeft,
    required this.status,
    required this.grnNo,
    required this.receiptDate,
  });

  factory ExpiryReportEntry.fromJson(Map<String, dynamic> json) {
    return ExpiryReportEntry(
      id: int.tryParse((json['id'] ?? 0).toString()) ?? 0,
      itemCode: (json['item_code'] ?? '').toString(),
      itemName: (json['item_name'] ?? '').toString(),
      qty: double.tryParse((json['qty'] ?? 0).toString()) ?? 0,
      unit: (json['unit'] ?? '').toString(),
      expiryDate: DateTime.tryParse(json['expiry_date']?.toString() ?? '') ??
          DateTime.now(),
      daysLeft: int.tryParse((json['days_left'] ?? 0).toString()) ?? 0,
      status: (json['status'] ?? '').toString(),
      grnNo: (json['grn_no'] ?? '').toString(),
      receiptDate: DateTime.tryParse(json['receipt_date']?.toString() ?? ''),
    );
  }
}

class ExpenseCategoryModel {
  final String id;
  final String categoryName;
  final bool isActive;

  const ExpenseCategoryModel({
    required this.id,
    required this.categoryName,
    required this.isActive,
  });

  factory ExpenseCategoryModel.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryModel(
      id: (json['id'] ?? '').toString(),
      categoryName: (json['category_name'] ?? '').toString(),
      isActive: json['is_active'] == true || json['is_active'] == 1,
    );
  }
}

class TaxesMasterModel {
  final String id;
  final String taxName;
  final double defaultRate;
  final bool isEditable;

  const TaxesMasterModel({
    required this.id,
    required this.taxName,
    required this.defaultRate,
    required this.isEditable,
  });

  factory TaxesMasterModel.fromJson(Map<String, dynamic> json) {
    return TaxesMasterModel(
      id: (json['id'] ?? '').toString(),
      taxName: (json['tax_name'] ?? '').toString(),
      defaultRate: double.tryParse((json['default_rate'] ?? 0).toString()) ?? 0.0,
      isEditable: json['is_editable'] != false,
    );
  }
}

class ExpenseAnalyticsModel {
  final double totalInputTaxPaid;
  final double totalTdsDeducted;
  final double totalTcsCollected;
  final double totalSpend;
  final List<Map<String, dynamic>> taxBreakdown;
  final List<Map<String, dynamic>> categoryBreakdown;
  final List<Map<String, dynamic>> vendorSpend;
  final List<ExpenseEntryReport> expenses;

  const ExpenseAnalyticsModel({
    required this.totalInputTaxPaid,
    required this.totalTdsDeducted,
    required this.totalTcsCollected,
    required this.totalSpend,
    required this.taxBreakdown,
    required this.categoryBreakdown,
    required this.vendorSpend,
    required this.expenses,
  });

  factory ExpenseAnalyticsModel.fromJson(Map<String, dynamic> json) {
    double numVal(dynamic val) => double.tryParse((val ?? 0).toString()) ?? 0.0;
    
    final summary = json['summary'] ?? {};
    
    return ExpenseAnalyticsModel(
      totalInputTaxPaid: numVal(summary['totalInputTaxPaid']),
      totalTdsDeducted: numVal(summary['totalTdsDeducted']),
      totalTcsCollected: numVal(summary['totalTcsCollected']),
      totalSpend: numVal(summary['totalSpend']),
      taxBreakdown: List<Map<String, dynamic>>.from(json['taxBreakdown'] ?? const []),
      categoryBreakdown: List<Map<String, dynamic>>.from(json['categoryBreakdown'] ?? const []),
      vendorSpend: List<Map<String, dynamic>>.from(json['vendorSpend'] ?? const []),
      expenses: (json['expenses'] as List? ?? const [])
          .map((e) => ExpenseEntryReport.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

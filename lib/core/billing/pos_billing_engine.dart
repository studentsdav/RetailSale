import '../../models/inventory/billing_charge_model.dart';
import '../../models/inventory/sale_item_model.dart';
import '../../models/inventory/tax_breakdown_model.dart';

class PosBillingEngine {
  const PosBillingEngine._();

  static InvoiceComputation compute({
    required List<SaleItem> items,
    required String taxMode,
    required double schemeDiscountAmount,
    required double manualDiscountAmount,
    required List<BillingCharge> charges,
    int? schemeItemId,
  }) {
    final subTotal = items.fold<double>(0, (sum, item) => sum + item.amount);
    final totalQty = items.fold<double>(0, (sum, item) => sum + item.qty);

    final schemeEligibleTotal = schemeItemId != null
        ? items
            .where((item) => item.itemId == schemeItemId && item.schemeApplicable)
            .fold<double>(0, (sum, item) => sum + item.amount)
        : items
            .where((item) => item.schemeApplicable)
            .fold<double>(0, (sum, item) => sum + item.amount);
    final discountEligibleTotal = items
        .where((item) => item.discountApplicable)
        .fold<double>(0, (sum, item) => sum + item.amount);

    final computedItems = <SaleItem>[];
    final taxSummary = <String, TaxBreakdown>{};

    for (final item in items) {
      final gross = item.amount;
      final schemeShare = schemeEligibleTotal > 0 &&
              item.schemeApplicable &&
              (schemeItemId == null || item.itemId == schemeItemId)
          ? (gross / schemeEligibleTotal) * schemeDiscountAmount
          : 0.0;
      final manualShare = discountEligibleTotal > 0 && item.discountApplicable
          ? (gross / discountEligibleTotal) * manualDiscountAmount
          : 0.0;
      double lineDiscount = (schemeShare + manualShare).clamp(0, gross);
      double taxableAmount = (gross - lineDiscount).clamp(0, double.infinity);
      final lineTaxes = _resolveTaxes(
        taxMode: taxMode,
        taxType: item.taxType,
        taxPercent: item.taxPercent,
        taxableAmount: taxableAmount,
      );
      final taxAmount =
          lineTaxes.fold<double>(0, (sum, entry) => sum + entry.taxAmount);
      final lineTotal = taxableAmount + taxAmount;

      final enriched = item.copyWith(
        lineDiscount: lineDiscount,
        taxableAmount: taxableAmount,
        taxAmount: taxAmount,
        lineTotal: lineTotal,
        taxBreakup: lineTaxes,
      );
      computedItems.add(enriched);

      for (final tax in lineTaxes) {
        final key = '${tax.code}_${tax.rate}';
        final existing = taxSummary[key];
        if (existing == null) {
          taxSummary[key] = tax;
        } else {
          taxSummary[key] = TaxBreakdown(
            code: existing.code,
            label: existing.label,
            taxType: existing.taxType,
            rate: existing.rate,
            taxableAmount: existing.taxableAmount + tax.taxableAmount,
            taxAmount: existing.taxAmount + tax.taxAmount,
          );
        }
      }
    }

    final activeCharges = charges
        .where(
          (charge) =>
              charge.isEnabled &&
              (charge.amount > 0 || charge.calculationValue > 0),
        )
        .toList(growable: false);

    final computedCharges = <ComputedCharge>[];
    for (final charge in activeCharges) {
      final effectiveAmount = charge.effectiveAmount(subTotal);
      if (effectiveAmount <= 0) continue;
      final resolvedCharge = charge.copyWith(amount: effectiveAmount);
      final chargeTaxes = resolvedCharge.taxable
          ? _resolveTaxes(
              taxMode: taxMode,
              taxType: resolvedCharge.taxType,
              taxPercent: resolvedCharge.taxPercent,
              taxableAmount: effectiveAmount,
            )
          : const <TaxBreakdown>[];
      final chargeTax = chargeTaxes.fold<double>(
        0,
        (sum, entry) => sum + entry.taxAmount,
      );
      computedCharges.add(
        ComputedCharge(
          charge: resolvedCharge,
          taxAmount: chargeTax,
          totalAmount: effectiveAmount + chargeTax,
          taxBreakup: chargeTaxes,
        ),
      );
      for (final tax in chargeTaxes) {
        final key = '${tax.code}_${tax.rate}';
        final existing = taxSummary[key];
        if (existing == null) {
          taxSummary[key] = tax;
        } else {
          taxSummary[key] = TaxBreakdown(
            code: existing.code,
            label: existing.label,
            taxType: existing.taxType,
            rate: existing.rate,
            taxableAmount: existing.taxableAmount + tax.taxableAmount,
            taxAmount: existing.taxAmount + tax.taxAmount,
          );
        }
      }
    }

    final taxableAmount = computedItems.fold<double>(
          0,
          (sum, item) => sum + item.taxableAmount,
        ) +
        computedCharges
            .where((charge) => charge.charge.taxable)
            .fold<double>(0, (sum, charge) => sum + charge.charge.amount);
    final totalTax = computedItems.fold<double>(
          0,
          (sum, item) => sum + item.taxAmount,
        ) +
        computedCharges.fold<double>(
            0, (sum, charge) => sum + charge.taxAmount);
    final chargeTotal = computedCharges.fold<double>(
        0, (sum, charge) => sum + charge.charge.amount);
    final chargeTaxTotal = computedCharges.fold<double>(
        0, (sum, charge) => sum + charge.taxAmount);

    double totalDiscount =
        (schemeDiscountAmount + manualDiscountAmount).clamp(0, subTotal);

    return InvoiceComputation(
      items: computedItems,
      charges: computedCharges,
      taxSummary: taxSummary.values.toList()
        ..sort((a, b) => a.label.compareTo(b.label)),
      subTotal: subTotal,
      totalQty: totalQty,
      schemeDiscountAmount: schemeDiscountAmount.clamp(0, subTotal),
      manualDiscountAmount: manualDiscountAmount.clamp(0, subTotal),
      totalDiscount: totalDiscount,
      taxableAmount: taxableAmount,
      totalTax: totalTax,
      chargeTotal: chargeTotal,
      chargeTaxTotal: chargeTaxTotal,
      netAmount: (subTotal - totalDiscount) + chargeTotal + totalTax,
    );
  }

  static List<TaxBreakdown> _resolveTaxes({
    required String taxMode,
    required String taxType,
    required double taxPercent,
    required double taxableAmount,
  }) {
    if (taxMode == 'NONE' || taxPercent <= 0 || taxableAmount <= 0) {
      return const <TaxBreakdown>[];
    }

    final normalizedType = taxType.toUpperCase();
    final taxAmount = taxableAmount * taxPercent / 100;

    switch (normalizedType) {
      case 'VAT':
        return [
          TaxBreakdown(
            code: 'VAT',
            label: 'VAT ${_fmt(taxPercent)}%',
            taxType: 'VAT',
            rate: taxPercent,
            taxableAmount: taxableAmount,
            taxAmount: taxAmount,
          ),
        ];
      case 'CESS':
        return [
          TaxBreakdown(
            code: 'CESS',
            label: 'CESS ${_fmt(taxPercent)}%',
            taxType: 'CESS',
            rate: taxPercent,
            taxableAmount: taxableAmount,
            taxAmount: taxAmount,
          ),
        ];
      case 'OTHER':
      case 'CUSTOM':
        return [
          TaxBreakdown(
            code: 'CUSTOM',
            label: 'Custom Tax ${_fmt(taxPercent)}%',
            taxType: 'CUSTOM',
            rate: taxPercent,
            taxableAmount: taxableAmount,
            taxAmount: taxAmount,
          ),
        ];
      case 'GST':
      default:
        if (taxMode == 'IGST') {
          return [
            TaxBreakdown(
              code: 'IGST',
              label: 'IGST ${_fmt(taxPercent)}%',
              taxType: 'GST',
              rate: taxPercent,
              taxableAmount: taxableAmount,
              taxAmount: taxAmount,
            ),
          ];
        }
        if (taxMode == 'VAT') {
          return [
            TaxBreakdown(
              code: 'VAT',
              label: 'VAT ${_fmt(taxPercent)}%',
              taxType: 'VAT',
              rate: taxPercent,
              taxableAmount: taxableAmount,
              taxAmount: taxAmount,
            ),
          ];
        }
        final halfRate = taxPercent / 2;
        final halfAmount = taxAmount / 2;
        return [
          TaxBreakdown(
            code: 'CGST',
            label: 'CGST ${_fmt(halfRate)}%',
            taxType: 'GST',
            rate: halfRate,
            taxableAmount: taxableAmount,
            taxAmount: halfAmount,
          ),
          TaxBreakdown(
            code: 'SGST',
            label: 'SGST ${_fmt(halfRate)}%',
            taxType: 'GST',
            rate: halfRate,
            taxableAmount: taxableAmount,
            taxAmount: halfAmount,
          ),
        ];
    }
  }

  static String _fmt(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }
}

class ComputedCharge {
  final BillingCharge charge;
  final double taxAmount;
  final double totalAmount;
  final List<TaxBreakdown> taxBreakup;

  const ComputedCharge({
    required this.charge,
    required this.taxAmount,
    required this.totalAmount,
    required this.taxBreakup,
  });
}

class InvoiceComputation {
  final List<SaleItem> items;
  final List<ComputedCharge> charges;
  final List<TaxBreakdown> taxSummary;
  final double subTotal;
  final double totalQty;
  final double schemeDiscountAmount;
  final double manualDiscountAmount;
  final double totalDiscount;
  final double taxableAmount;
  final double totalTax;
  final double chargeTotal;
  final double chargeTaxTotal;
  final double netAmount;

  const InvoiceComputation({
    required this.items,
    required this.charges,
    required this.taxSummary,
    required this.subTotal,
    required this.totalQty,
    required this.schemeDiscountAmount,
    required this.manualDiscountAmount,
    required this.totalDiscount,
    required this.taxableAmount,
    required this.totalTax,
    required this.chargeTotal,
    required this.chargeTaxTotal,
    required this.netAmount,
  });

  double amountForCode(String code) {
    return taxSummary
        .where((entry) => entry.code == code)
        .fold<double>(0, (sum, entry) => sum + entry.taxAmount);
  }
}

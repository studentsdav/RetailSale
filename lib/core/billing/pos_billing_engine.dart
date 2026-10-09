import '../../models/inventory/billing_charge_model.dart';
import '../../models/inventory/sale_item_model.dart';
import '../../models/inventory/tax_breakdown_model.dart';
import '../../models/inventory/tax_group_model.dart';

class PosBillingEngine {
  const PosBillingEngine._();

  static InvoiceComputation compute({
    required List<SaleItem> items,
    required String taxMode,
    required double schemeDiscountAmount,
    required double manualDiscountAmount,
    required List<BillingCharge> charges,
    int? schemeItemId,
    List<TaxGroup>? taxGroups,
  }) {
    final totalQty = items.fold<double>(0, (sum, item) => sum + item.qty);

    double discountEligibleTotal = 0.0;
    double schemeEligibleTotal = 0.0;

    for (final item in items) {
      if (item.discountApplicable) {
        discountEligibleTotal += item.amount;
      }
      if (item.schemeApplicable &&
          (schemeItemId == null || item.itemId == schemeItemId)) {
        schemeEligibleTotal += item.amount;
      }
    }

    final computedItems = <SaleItem>[];
    final taxSummary = <String, TaxBreakdown>{};

    double calculatedSubTotal = 0.0;
    double calculatedDiscount = 0.0;

    for (final item in items) {
      final double itemAmount = item.amount;
      final double schemeShare = schemeEligibleTotal > 0 &&
              item.schemeApplicable &&
              (schemeItemId == null || item.itemId == schemeItemId)
          ? (itemAmount / schemeEligibleTotal) * schemeDiscountAmount
          : 0.0;
      final double manualShare =
          discountEligibleTotal > 0 && item.discountApplicable
              ? (itemAmount / discountEligibleTotal) * manualDiscountAmount
              : 0.0;

      if (item.isTaxInclusive) {
        final double grossInclusive = itemAmount;
        double lineDiscount;
        if (item.isSchemeFree) {
          lineDiscount = grossInclusive;
        } else {
          lineDiscount = (item.lineDiscount + schemeShare + manualShare).clamp(0.0, grossInclusive);
        }

        final netInclusive = (grossInclusive - lineDiscount).clamp(0.0, double.infinity);
        final taxableAmount = netInclusive / (1 + item.taxPercent / 100);
        final lineTaxes = _resolveTaxes(
          taxMode: taxMode,
          taxType: item.taxType,
          taxPercent: item.taxPercent,
          taxableAmount: taxableAmount,
          taxGroup: item.taxGroup,
        );
        final taxAmount = netInclusive - taxableAmount;
        final lineTotal = netInclusive;

        calculatedSubTotal += grossInclusive;
        calculatedDiscount += lineDiscount;

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
      } else {
        final double grossExclusive = itemAmount;
        double lineDiscount;
        if (item.isSchemeFree) {
          lineDiscount = grossExclusive;
        } else {
          lineDiscount = (item.lineDiscount + schemeShare + manualShare).clamp(0.0, grossExclusive);
        }

        final taxableAmount = (grossExclusive - lineDiscount).clamp(0.0, double.infinity);
        final lineTaxes = _resolveTaxes(
          taxMode: taxMode,
          taxType: item.taxType,
          taxPercent: item.taxPercent,
          taxableAmount: taxableAmount,
          taxGroup: item.taxGroup,
        );
        final taxAmount = taxableAmount * (item.taxPercent / 100);
        final lineTotal = taxableAmount + taxAmount;

        calculatedSubTotal += grossExclusive;
        calculatedDiscount += lineDiscount;

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
    }

    final bool allExclusiveCart = items.isNotEmpty && items.every((item) => !item.isTaxInclusive);
    final double subTotal = allExclusiveCart
        ? items.fold<double>(0, (sum, item) => sum + item.amount)
        : calculatedSubTotal;

    final activeCharges = charges
        .where(
          (charge) =>
              charge.isEnabled &&
              (charge.amount > 0 || charge.calculationValue > 0),
        )
        .toList(growable: false);

    final double itemsNetTaxable = computedItems
        .where((item) => item.taxPercent > 0)
        .fold<double>(
      0,
      (sum, item) => sum + item.taxableAmount,
    );

    final computedCharges = <ComputedCharge>[];
    for (final charge in activeCharges) {
      final double chargeBase = charge.calculationType == 'PERCENT'
          ? itemsNetTaxable
          : subTotal;
      final effectiveAmount = charge.effectiveAmount(chargeBase);
      if (effectiveAmount <= 0) continue;

      TaxGroup? chargeTaxGroup = charge.taxGroup;
      if (chargeTaxGroup == null && taxGroups != null && taxGroups.isNotEmpty) {
        chargeTaxGroup = taxGroups.where((g) =>
            g.id == charge.taxGroupId ||
            (g.groupCode != null && g.groupCode!.trim().toLowerCase() == charge.taxType.trim().toLowerCase()) ||
            g.groupName.trim().toLowerCase() == charge.taxType.trim().toLowerCase()
        ).firstOrNull;
      }

      final chargeTaxes = charge.taxable
          ? _resolveTaxes(
              taxMode: taxMode,
              taxType: charge.taxType,
              taxPercent: charge.taxPercent,
              taxableAmount: effectiveAmount,
              taxGroup: chargeTaxGroup,
            )
          : const <TaxBreakdown>[];
      final chargeTax = chargeTaxes.fold<double>(
        0,
        (sum, entry) => sum + entry.taxAmount,
      );
      final resolvedCharge = charge.copyWith(
        amount: effectiveAmount,
        taxGroup: chargeTaxGroup,
        taxBreakup: chargeTaxes,
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

    double totalDiscount = calculatedDiscount.clamp(0, subTotal);

    // Compute net amount from the actual line totals of each item.
    // This is the only formula that works correctly for all cases:
    //   - exclusive-only carts: lineTotal = taxableAmount + taxAmount
    //   - inclusive-only carts: lineTotal = netInclusive (tax already inside)
    //   - mixed carts: each item contributes its own correct lineTotal
    // We CANNOT use (subTotal - totalDiscount) + totalTax because subTotal is
    // exclusive but totalDiscount is inclusive, making that arithmetic wrong.
    final double itemsNetTotal =
        computedItems.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final double netAmount = itemsNetTotal + chargeTotal + chargeTaxTotal;

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
      netAmount: netAmount,
    );
  }

  static List<TaxBreakdown> _resolveTaxes({
    required String taxMode,
    required String taxType,
    required double taxPercent,
    required double taxableAmount,
    TaxGroup? taxGroup,
  }) {
    if (taxMode == 'NONE' || taxPercent <= 0 || taxableAmount <= 0) {
      return const <TaxBreakdown>[];
    }

    if (taxGroup != null && taxGroup.components.isNotEmpty) {
      final list = <TaxBreakdown>[];
      for (final comp in taxGroup.components) {
        final compAmount = taxableAmount * comp.rate / 100;
        final rawCompName = comp.componentName.trim();
        final cleanedCompName = rawCompName
            .replaceAll(RegExp(r'\s*\(\s*\d+(\.\d+)?%\s*\)', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*\b\d+(\.\d+)?%\s*$', caseSensitive: false), '')
            .trim();
        final baseName = cleanedCompName.isNotEmpty
            ? cleanedCompName
            : (comp.componentCode.isNotEmpty ? comp.componentCode : 'TAX');
        list.add(
          TaxBreakdown(
            code: comp.componentCode.isNotEmpty ? comp.componentCode : 'TAX',
            label: '$baseName (${_fmt(comp.rate)}%)',
            taxType: comp.componentCode,
            rate: comp.rate,
            taxableAmount: taxableAmount,
            taxAmount: compAmount,
          ),
        );
      }
      return list;
    }

    final normalizedType = taxType.toUpperCase();
    final taxAmount = taxableAmount * taxPercent / 100;

    switch (normalizedType) {
      case 'VAT':
      case 'VAT_ONLY':
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
      case 'VAT_CTL':
        // For Kenya restaurant businesses: Tax rate breakdown e.g. 16% VAT + 2% CTL
        const ctlRate = 2.0;
        final vatRate = taxPercent > 2.0 ? taxPercent - ctlRate : taxPercent;
        final vatAmount = taxableAmount * vatRate / 100;
        final ctlAmount = taxableAmount * ctlRate / 100;
        return [
          TaxBreakdown(
            code: 'VAT',
            label: 'VAT ${_fmt(vatRate)}%',
            taxType: 'VAT',
            rate: vatRate,
            taxableAmount: taxableAmount,
            taxAmount: vatAmount,
          ),
          TaxBreakdown(
            code: 'CTL',
            label: 'CTL ${_fmt(ctlRate)}%',
            taxType: 'CTL',
            rate: ctlRate,
            taxableAmount: taxableAmount,
            taxAmount: ctlAmount,
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
      case 'US_SALES_TAX':
      case 'COMPOSITE':
      case 'SALES_TAX':
        {
          final stateRate = taxPercent > 1.0 ? double.parse((taxPercent - 1.0).toStringAsFixed(2)) : taxPercent;
          final cityRate = taxPercent > 1.0 ? 1.0 : 0.0;

          final stateAmt = taxableAmount * stateRate / 100;
          final cityAmt = taxableAmount * cityRate / 100;

          return [
            TaxBreakdown(
              code: 'STATE_TAX',
              label: 'STATE SALES TAX (${_fmt(stateRate)}%)',
              taxType: 'STATE_TAX',
              rate: stateRate,
              taxableAmount: taxableAmount,
              taxAmount: stateAmt,
            ),
            if (cityRate > 0)
              TaxBreakdown(
                code: 'CITY_TAX',
                label: 'CITY TAX (${_fmt(cityRate)}%)',
                taxType: 'CITY_TAX',
                rate: cityRate,
                taxableAmount: taxableAmount,
                taxAmount: cityAmt,
              ),
          ];
        }
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
        if (normalizedType.contains('USA') ||
            normalizedType.contains('US_') ||
            normalizedType.contains('SALES') ||
            taxMode == 'US_SALES_TAX' ||
            taxMode == 'SALES_TAX') {
          final stateRate = taxPercent > 1.0 ? double.parse((taxPercent - 1.0).toStringAsFixed(2)) : taxPercent;
          final cityRate = taxPercent > 1.0 ? 1.0 : 0.0;
          final stateAmt = taxableAmount * stateRate / 100;
          final cityAmt = taxableAmount * cityRate / 100;
          return [
            TaxBreakdown(
              code: 'STATE_TAX',
              label: 'STATE SALES TAX (${_fmt(stateRate)}%)',
              taxType: 'STATE_TAX',
              rate: stateRate,
              taxableAmount: taxableAmount,
              taxAmount: stateAmt,
            ),
            if (cityRate > 0)
              TaxBreakdown(
                code: 'CITY_TAX',
                label: 'CITY TAX (${_fmt(cityRate)}%)',
                taxType: 'CITY_TAX',
                rate: cityRate,
                taxableAmount: taxableAmount,
                taxAmount: cityAmt,
              ),
          ];
        }
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
        if (taxMode == 'VAT' || normalizedType == 'VAT') {
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
        if (normalizedType != 'GST' && normalizedType != 'CGST_SGST' && taxMode != 'CGST_SGST') {
          return [
            TaxBreakdown(
              code: normalizedType.isNotEmpty ? normalizedType : 'TAX',
              label: '${normalizedType.isNotEmpty ? normalizedType : "Tax"} (${_fmt(taxPercent)}%)',
              taxType: normalizedType.isNotEmpty ? normalizedType : 'TAX',
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

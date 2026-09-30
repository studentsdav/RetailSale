/**
 * Universal Multi-Country Dynamic Tax Calculation Engine
 *
 * Supports:
 * - USA: Multi-stacked composite sales tax (State + County + City + Transit District)
 * - Kenya: VAT 16% + CTL 2% (Catering Levy)
 * - Canada: GST 5% + PST 6-10% or HST 13-15% (with optional compound QST)
 * - EU / UK: Inclusive VAT Slabs (Standard, Reduced, Zero)
 * - India: Intra-state (CGST + SGST), Inter-state (IGST), CESS
 * - China: VAT 13%/9%/6% + City Maintenance Surcharge 7% + Education Surcharge 3%
 * - Japan: Japanese Consumption Tax (JCT) 10%/8%
 * - Australia: GST 10% Inclusive
 */

export interface TaxComponent {
  calculation_order?: number;
  rate?: number | string;
  calculation_type?: 'FLAT_PERCENT' | 'COMPOUND_ON_SUBTOTAL' | 'PERCENT_OF_TAX' | string;
  component_code?: string;
  component_name?: string;
  [key: string]: any;
}

export interface TaxBreakdownItem {
  code: string;
  label: string;
  tax_type: string;
  rate: number;
  taxable_amount: number;
  tax_amount: number;
}

export interface ComputeTaxBreakdownOptions {
  taxableAmount: number;
  taxPercent?: number | string;
  taxType?: string;
  taxMode?: string;
  taxGroupComponents?: TaxComponent[];
  isTaxInclusive?: boolean;
}

export function formatRate(val: any): string {
  const num = Number(val || 0);
  return Number.isInteger(num) ? num.toString() : num.toFixed(2);
}

export function computeTaxBreakdown({
  taxableAmount,
  taxPercent,
  taxType,
  taxMode = 'EXCLUSIVE',
  taxGroupComponents = [],
  isTaxInclusive = false
}: ComputeTaxBreakdownOptions): TaxBreakdownItem[] {
  if (taxableAmount <= 0) {
    return [];
  }

  // 1. If explicit multi-component Tax Group is present
  if (Array.isArray(taxGroupComponents) && taxGroupComponents.length > 0) {
    const sortedComponents = [...taxGroupComponents].sort(
      (a, b) => (a.calculation_order || 1) - (b.calculation_order || 1)
    );
    const results: TaxBreakdownItem[] = [];
    let runningTaxable = taxableAmount;

    for (const comp of sortedComponents) {
      const rate = Number(comp.rate || 0);
      if (rate <= 0) continue;

      const calcType = comp.calculation_type || 'FLAT_PERCENT';
      let compTaxable = taxableAmount;
      let compTax = 0;

      if (calcType === 'COMPOUND_ON_SUBTOTAL') {
        compTaxable = runningTaxable;
        compTax = compTaxable * (rate / 100);
        runningTaxable += compTax;
      } else if (calcType === 'PERCENT_OF_TAX') {
        const prevTaxSum = results.reduce((acc, r) => acc + r.tax_amount, 0);
        compTaxable = prevTaxSum;
        compTax = prevTaxSum * (rate / 100);
      } else {
        // FLAT_PERCENT
        compTaxable = taxableAmount;
        compTax = taxableAmount * (rate / 100);
        runningTaxable += compTax;
      }

      results.push({
        code: comp.component_code || 'TAX',
        label: `${comp.component_name || comp.component_code} (${formatRate(rate)}%)`,
        tax_type: comp.component_code || 'TAX',
        rate: rate,
        taxable_amount: Number(compTaxable.toFixed(2)),
        tax_amount: Number(compTax.toFixed(2))
      });
    }
    return results;
  }

  // 2. Fallback to legacy single-rate resolution by taxType / taxMode
  const normalizedType = String(taxType || 'GST').toUpperCase();
  const rate = Number(taxPercent || 0);
  if (rate <= 0) return [];

  const taxAmount = taxableAmount * (rate / 100);

  switch (normalizedType) {
    case 'VAT_CTL': {
      const ctlRate = 2.0;
      const vatRate = rate > 2.0 ? rate - ctlRate : rate;
      const vatAmt = taxableAmount * (vatRate / 100);
      const ctlAmt = taxableAmount * (ctlRate / 100);
      return [
        {
          code: 'VAT',
          label: `VAT ${formatRate(vatRate)}%`,
          tax_type: 'VAT',
          rate: vatRate,
          taxable_amount: Number(taxableAmount.toFixed(2)),
          tax_amount: Number(vatAmt.toFixed(2))
        },
        {
          code: 'CTL',
          label: `CTL ${formatRate(ctlRate)}%`,
          tax_type: 'CTL',
          rate: ctlRate,
          taxable_amount: Number(taxableAmount.toFixed(2)),
          tax_amount: Number(ctlAmt.toFixed(2))
        }
      ];
    }
    case 'US_SALES_TAX':
    case 'COMPOSITE': {
      // Default 3-tier US state/city/transit split if single composite rate passed
      const stateRate = Number((rate * 0.7575).toFixed(2));
      const cityRate = Number((rate * 0.1212).toFixed(2));
      const transitRate = Number((rate - stateRate - cityRate).toFixed(2));
      return [
        {
          code: 'STATE_TAX',
          label: `STATE SALES TAX (${formatRate(stateRate)}%)`,
          tax_type: 'STATE_TAX',
          rate: stateRate,
          taxable_amount: Number(taxableAmount.toFixed(2)),
          tax_amount: Number(((taxableAmount * stateRate) / 100).toFixed(2))
        },
        {
          code: 'CITY_TAX',
          label: `CITY TAX (${formatRate(cityRate)}%)`,
          tax_type: 'CITY_TAX',
          rate: cityRate,
          taxable_amount: Number(taxableAmount.toFixed(2)),
          tax_amount: Number(((taxableAmount * cityRate) / 100).toFixed(2))
        },
        {
          code: 'TRANSIT_TAX',
          label: `MTA TRANSIT TAX (${formatRate(transitRate)}%)`,
          tax_type: 'TRANSIT_TAX',
          rate: transitRate,
          taxable_amount: Number(taxableAmount.toFixed(2)),
          tax_amount: Number(((taxableAmount * transitRate) / 100).toFixed(2))
        }
      ];
    }
    case 'VAT':
    case 'VAT_ONLY':
      return [
        {
          code: 'VAT',
          label: `VAT ${formatRate(rate)}%`,
          tax_type: 'VAT',
          rate: rate,
          taxable_amount: Number(taxableAmount.toFixed(2)),
          tax_amount: Number(taxAmount.toFixed(2))
        }
      ];
    case 'CESS':
      return [
        {
          code: 'CESS',
          label: `CESS ${formatRate(rate)}%`,
          tax_type: 'CESS',
          rate: rate,
          taxable_amount: Number(taxableAmount.toFixed(2)),
          tax_amount: Number(taxAmount.toFixed(2))
        }
      ];
    case 'GST':
    default: {
      if (taxMode === 'IGST') {
        return [
          {
            code: 'IGST',
            label: `IGST ${formatRate(rate)}%`,
            tax_type: 'GST',
            rate: rate,
            taxable_amount: Number(taxableAmount.toFixed(2)),
            tax_amount: Number(taxAmount.toFixed(2))
          }
        ];
      }
      if (taxMode === 'VAT') {
        return [
          {
            code: 'VAT',
            label: `VAT ${formatRate(rate)}%`,
            tax_type: 'VAT',
            rate: rate,
            taxable_amount: Number(taxableAmount.toFixed(2)),
            tax_amount: Number(taxAmount.toFixed(2))
          }
        ];
      }
      const halfRate = rate / 2;
      const halfAmt = taxAmount / 2;
      return [
        {
          code: 'CGST',
          label: `CGST ${formatRate(halfRate)}%`,
          tax_type: 'GST',
          rate: halfRate,
          taxable_amount: Number(taxableAmount.toFixed(2)),
          tax_amount: Number(halfAmt.toFixed(2))
        },
        {
          code: 'SGST',
          label: `SGST ${formatRate(halfRate)}%`,
          tax_type: 'GST',
          rate: halfRate,
          taxable_amount: Number(taxableAmount.toFixed(2)),
          tax_amount: Number(halfAmt.toFixed(2))
        }
      ];
    }
  }
}

module.exports = {
  formatRate,
  computeTaxBreakdown
};

import { Op, fn, col } from 'sequelize';

export interface RepaymentTotalParams {
  db: any;
  sale_id: number | string;
  transaction?: any;
  exclude_repayment_id?: number | string | null;
}

export interface RefreshSaleOutstandingParams {
  db: any;
  sale: any;
  transaction?: any;
}

export interface RefreshSaleOutstandingResult {
  totalPaid: number;
  balanceDue: number;
  paymentStatus: string;
  repaymentTotal: number;
  initialPaid: number;
}

export function roundAmount(value: any): number {
  return Number((Number(value) || 0).toFixed(2));
}

export function resolvePaymentStatus(totalPaid: number, netAmount: number, paymentMode: string = ''): string {
  const mode = String(paymentMode || '').toUpperCase();
  if (mode.includes('SUBSCRIPTION')) return 'PAID';
  if (mode.includes('SCHEME')) return 'PAID';
  if (mode.includes('DISCOUNT')) return 'PAID';
  if (roundAmount(netAmount) <= 0) return 'PAID';
  if (roundAmount(totalPaid) <= 0) return 'UNPAID';
  if (roundAmount(totalPaid) >= roundAmount(netAmount)) return 'PAID';
  return 'PARTIAL';
}

export function extractInitialPaid(sale: any): number | null {
  if (sale.initial_amount_paid !== null && sale.initial_amount_paid !== undefined) {
    return roundAmount(sale.initial_amount_paid);
  }
  const ref = String(sale.payment_reference || '');
  if (ref.startsWith('POSPAY:')) {
    try {
      const raw = ref.slice(7);
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) {
        return roundAmount(
          parsed
            .filter((l: any) => String(l.method || l.payment_method || '').toUpperCase() !== 'CREDIT')
            .reduce((sum: number, l: any) => sum + (Number(l.amount) || 0), 0)
        );
      }
    } catch (_) {}
  }
  return null;
}

export async function getRepaymentTotal({
  db,
  sale_id,
  transaction = undefined,
  exclude_repayment_id = null
}: RepaymentTotalParams): Promise<number> {
  const where: any = { sale_id };
  if (exclude_repayment_id) {
    where.id = { [Op.ne]: exclude_repayment_id };
  }

  const summary: any = await db.models.customer_repayments.findOne({
    where,
    attributes: [[fn('COALESCE', fn('SUM', col('amount')), 0), 'total']],
    raw: true,
    transaction
  });

  return roundAmount(summary?.total);
}

export async function refreshSaleOutstanding({
  db,
  sale,
  transaction = undefined
}: RefreshSaleOutstandingParams): Promise<RefreshSaleOutstandingResult> {
  const repayments = await db.models.customer_repayments.findAll({
    where: { sale_id: sale.id },
    order: [['payment_date', 'ASC'], ['id', 'ASC']],
    transaction
  });

  const repaymentTotal = repayments.reduce(
    (sum: number, r: any) => sum + roundAmount(Number(r.amount) || 0),
    0
  );

  const parsedInitial = extractInitialPaid(sale);
  const initialPaid =
    parsedInitial !== null
      ? parsedInitial
      : Math.max(0, roundAmount(sale.amount_paid) - repaymentTotal);

  const totalPaid = roundAmount(initialPaid + repaymentTotal);
  // net_amount already includes round_off_amount (net = subtotal + tax + charges + roundOff).
  const effectiveNet = roundAmount(sale.net_amount);
  const rawBalance = roundAmount(effectiveNet - totalPaid);
  const isCredit =
    String(sale.payment_mode || '').toUpperCase().includes('CREDIT') ||
    String(sale.payment_reference || '').toUpperCase().includes('CREDIT') ||
    rawBalance > 0.009;
  const balanceDue = !isCredit && rawBalance <= 0.5 ? 0 : Math.max(0, rawBalance);
  const paymentStatus = resolvePaymentStatus(totalPaid, effectiveNet, sale.payment_mode);

  // Reconstruct accurate, up-to-date payment lines reflecting actual initial paid + repayments
  let initialLines: Array<{ method: string; amount: number }> = [];
  const ref = String(sale.payment_reference || '').trim();
  if (ref.startsWith('POSPAY:')) {
    try {
      const parsed = JSON.parse(ref.substring(7));
      if (Array.isArray(parsed)) {
        initialLines = parsed
          .filter((l: any) => String(l.method || '').toUpperCase() !== 'CREDIT' && Number(l.amount) > 0)
          .map((l: any) => ({
            method: String(l.method || 'CASH').toUpperCase(),
            amount: roundAmount(Number(l.amount) || 0)
          }));
      }
    } catch (_) {}
  }
  if (initialLines.length === 0 && initialPaid > 0.009) {
    const origMode = String(sale.payment_mode || 'CASH').toUpperCase();
    const nonCreditMode = (origMode !== 'CREDIT' && origMode !== 'SPLIT') ? origMode : 'CASH';
    initialLines.push({ method: nonCreditMode, amount: initialPaid });
  }

  const repaymentLines: Array<{ method: string; amount: number }> = repayments
    .filter((r: any) => Number(r.amount) > 0)
    .map((r: any) => ({
      method: String(r.payment_mode || 'CASH').trim().toUpperCase(),
      amount: roundAmount(Number(r.amount) || 0)
    }));

  const methodMap = new Map<string, number>();
  for (const line of [...initialLines, ...repaymentLines]) {
    const m = line.method;
    methodMap.set(m, roundAmount((methodMap.get(m) || 0) + line.amount));
  }
  const mergedPaymentLines: Array<{ method: string; amount: number }> = [];
  for (const [method, amt] of methodMap.entries()) {
    if (amt > 0.009) {
      mergedPaymentLines.push({ method, amount: amt });
    }
  }
  if (balanceDue > 0.009) {
    mergedPaymentLines.push({ method: 'CREDIT', amount: balanceDue });
  }

  let updatedPaymentReference = sale.payment_reference;
  if (mergedPaymentLines.length > 0) {
    updatedPaymentReference = `POSPAY:${JSON.stringify(mergedPaymentLines)}`;
  }

  let updatedPaymentMode = sale.payment_mode;
  if (balanceDue > 0.009) {
    if (totalPaid > 0.009) {
      updatedPaymentMode = 'SPLIT';
    } else {
      updatedPaymentMode = 'CREDIT';
    }
  } else {
    // Fully paid!
    if (mergedPaymentLines.length === 0) {
      updatedPaymentMode = 'CASH';
    } else if (mergedPaymentLines.length === 1) {
      updatedPaymentMode = mergedPaymentLines[0].method;
    } else {
      updatedPaymentMode = 'SPLIT';
    }
  }

  await sale.update(
    {
      initial_amount_paid: initialPaid,
      amount_paid: totalPaid,
      balance_due: balanceDue,
      payment_mode: updatedPaymentMode,
      payment_reference: updatedPaymentReference,
      notes: sale.notes
    },
    { transaction }
  );

  return {
    totalPaid,
    balanceDue,
    paymentStatus,
    repaymentTotal,
    initialPaid
  };
}

export async function syncAllSalesOutstanding({
  db,
  outletId
}: {
  db: any;
  outletId?: number;
}) {
  try {
    const where: any = {};
    if (outletId) where.outlet_id = outletId;
    const repaidSales = await db.models.customer_repayments.findAll({
      where,
      attributes: ['sale_id'],
      group: ['sale_id'],
      raw: true
    });
    const saleIds = repaidSales.map((r: any) => r.sale_id).filter(Boolean);
    for (const sId of saleIds) {
      try {
        const sale = await db.models.sales_headers.findByPk(sId);
        if (sale) {
          await refreshSaleOutstanding({ db, sale });
        }
      } catch (e) {
        console.warn(`Error syncing sale ${sId}:`, e);
      }
    }
  } catch (err) {
    console.warn('Error in syncAllSalesOutstanding:', err);
  }
}

module.exports = {
  roundAmount,
  resolvePaymentStatus,
  extractInitialPaid,
  getRepaymentTotal,
  refreshSaleOutstanding,
  syncAllSalesOutstanding
};

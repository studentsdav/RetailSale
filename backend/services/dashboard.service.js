const { QueryTypes } = require('sequelize');

const SALES_ZONES = [
  { key: 'MORNING', label: 'Morning', startHour: 5, endHour: 11 },
  { key: 'AFTERNOON', label: 'Afternoon', startHour: 12, endHour: 16 },
  { key: 'EVENING', label: 'Evening', startHour: 17, endHour: 20 },
  { key: 'NIGHT', label: 'Night', startHour: 21, endHour: 4 }
];

function toNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function roundAmount(value) {
  return Number(toNumber(value).toFixed(2));
}

function formatDateLocalYmd(value) {
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function normalizeDate(value) {
  if (value instanceof Date) return value;
  if (typeof value === 'string') {
    const clean = value.trim();
    if (/^\d{4}-\d{2}-\d{2}$/.test(clean)) {
      const [year, month, day] = clean.split('-').map(Number);
      return new Date(year, month - 1, day);
    }
    if (/^\d{4}-\d{2}-\d{2}[\sT]\d{2}:\d{2}:\d{2}(?:\.\d+)?$/.test(clean)) {
      const parts = clean.split(/[\sT]/);
      const [year, month, day] = parts[0].split('-').map(Number);
      const timeParts = parts[1].split('.')[0].split(':').map(Number);
      return new Date(year, month - 1, day, timeParts[0], timeParts[1], timeParts[2]);
    }
  }
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? new Date() : date;
}

function resolveSaleZone(dateValue) {
  const hour = normalizeDate(dateValue).getHours();
  if (hour >= 5 && hour <= 11) return SALES_ZONES[0];
  if (hour >= 12 && hour <= 16) return SALES_ZONES[1];
  if (hour >= 17 && hour <= 20) return SALES_ZONES[2];
  return SALES_ZONES[3];
}

function startOfDay(dateValue) {
  const date = normalizeDate(dateValue);
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function startOfWeek(dateValue) {
  const date = startOfDay(dateValue);
  const day = date.getDay();
  const diff = (day + 6) % 7;
  date.setDate(date.getDate() - diff);
  return date;
}

function startOfMonth(dateValue) {
  const date = normalizeDate(dateValue);
  return new Date(date.getFullYear(), date.getMonth(), 1);
}

function startOfYear(dateValue) {
  const date = normalizeDate(dateValue);
  return new Date(date.getFullYear(), 0, 1);
}

function periodBetween(currentStart, previousStart, currentEnd, previousEnd) {
  return {
    currentStart,
    previousStart,
    currentEnd,
    previousEnd,
    current: { sales: 0, profit: 0, loss: 0 },
    previous: { sales: 0, profit: 0, loss: 0 }
  };
}

function growthPercent(current, previous) {
  if (!previous) return current > 0 ? 100 : 0;
  return roundAmount(((current - previous) / previous) * 100);
}

exports.getInventoryDashboard = async (outletId, db) => {
  const todayStr = formatDateLocalYmd(new Date());

  const [
    kpis,
    lowStockItems,
    issueReceive,
    departmentIssue,
    damageTrend,
    categoryStock,
    stockValueResult,
    supplierPayments,
    unpaidSuppliers,
    customerOutstandingResult,
    supplierOutstandingResult,
    salesRows,
    cashLedgerRows,
    subscriptionConsumptionResult
  ] = await Promise.all([

    // KPI
    db.query(`
          SELECT
            COALESCE(SUM(qty_in),0) AS today_in,
            COALESCE(SUM(qty_out),0) AS today_out
          FROM stock_ledger
          WHERE outlet_id = :outletId
          AND txn_date = :today::DATE
        `, { replacements: { outletId, today: todayStr }, type: QueryTypes.SELECT }),

    // Low stock items (calculated from stock_ledger)
    db.query(`
SELECT
  im.item_name,
  im.brand
FROM item_master im
LEFT JOIN stock_ledger sl
  ON sl.item_code = im.item_code
  AND sl.outlet_id = :outletId
WHERE im.outlet_id = :outletId
  AND im.is_active = TRUE
GROUP BY im.id, im.item_name, im.brand, im.min_level, im.opening_balance
HAVING
  (
    COALESCE(im.opening_balance, 0)
    +
    COALESCE(SUM(sl.qty_in - sl.qty_out), 0)
  ) <= im.min_level
`, {
      replacements: { outletId },
      type: QueryTypes.SELECT
    }),


    // Issue vs Receive (7 days)
    db.query(`
          SELECT
            TO_CHAR(txn_date, 'Dy') AS day,
            SUM(qty_in) AS received,
            SUM(qty_out) AS issued
          FROM stock_ledger
          WHERE outlet_id = :outletId
          AND txn_date >= :today::DATE - INTERVAL '6 days'
          GROUP BY txn_date
          ORDER BY txn_date
        `, { replacements: { outletId, today: todayStr }, type: QueryTypes.SELECT }),

    // Department wise issue
    db.query(`
          SELECT
            h.department AS dept,
            SUM(i.qty) AS qty
          FROM issue_headers h
          JOIN issue_items i ON i.issue_id = h.id
          WHERE h.outlet_id = :outletId
          GROUP BY h.department
        `, { replacements: { outletId }, type: QueryTypes.SELECT }),

    // Damage trend
    db.query(`
          SELECT
            TO_CHAR(damage_date, 'Dy') AS day,
            SUM(i.qty) AS qty
          FROM damage_headers h
          JOIN damage_items i ON i.damage_id = h.id
          WHERE h.outlet_id = :outletId
          AND damage_date >= :today::DATE - INTERVAL '6 days'
          GROUP BY damage_date
          ORDER BY damage_date
        `, { replacements: { outletId, today: todayStr }, type: QueryTypes.SELECT }),

    // Category stock % (ledger-based, no nested aggregates)
    db.query(`
WITH item_stock AS (
  SELECT
    im.id,
    im.item_group,
    im.rate,
    (
      COALESCE(im.opening_balance, 0)
      +
      COALESCE(SUM(sl.qty_in - sl.qty_out), 0)
    ) AS current_stock
  FROM item_master im
  LEFT JOIN stock_ledger sl
    ON sl.item_code = im.item_code
    AND sl.outlet_id = :outletId
  WHERE im.outlet_id = :outletId
  GROUP BY im.id, im.item_group, im.rate, im.opening_balance
),
category_value AS (
  SELECT
    item_group AS category,
    SUM(current_stock * rate) AS category_value
  FROM item_stock
  GROUP BY item_group
)
SELECT
  category,
  ROUND(
    CASE
      WHEN SUM(category_value) OVER () = 0 THEN 0
      ELSE category_value * 100.0 /
           NULLIF(SUM(category_value) OVER (), 0)
    END,
    0
  ) AS percent
FROM category_value;
`, {
      replacements: { outletId },
      type: QueryTypes.SELECT
    }),


    // Total stock value (actual amount)
    db.query(`
WITH item_stock AS (
  SELECT
    im.id,
    im.rate,
    (
      COALESCE(im.opening_balance, 0)
      +
      COALESCE(SUM(sl.qty_in - sl.qty_out), 0)
    ) AS current_stock
  FROM item_master im
  LEFT JOIN stock_ledger sl
    ON sl.item_code = im.item_code
    AND sl.outlet_id = :outletId
  WHERE im.outlet_id = :outletId
  GROUP BY im.id, im.rate, im.opening_balance
)
SELECT
  COALESCE(SUM(current_stock * rate), 0) AS total_stock_value
FROM item_stock;
`, {
      replacements: { outletId },
      type: QueryTypes.SELECT
    }),

    // Supplier paid vs unpaid
    db.query(`
          SELECT
            s.supplier_name AS supplier,
            SUM(b.paid_amount) AS paid,
            SUM(b.bill_amount - b.paid_amount) AS unpaid
          FROM supplier_bills b
          JOIN supplier_master s ON s.id = b.supplier_id
          WHERE b.outlet_id = :outletId
          GROUP BY s.supplier_name
        `, { replacements: { outletId }, type: QueryTypes.SELECT }),

    // Unpaid supplier list
    db.query(`
          SELECT
            s.supplier_name AS supplier,
            SUM(b.bill_amount - b.paid_amount) AS amount
          FROM supplier_bills b
          JOIN supplier_master s ON s.id = b.supplier_id
          WHERE b.outlet_id = :outletId
          AND b.bill_amount > b.paid_amount
          GROUP BY s.supplier_name
          ORDER BY amount DESC
        `, { replacements: { outletId }, type: QueryTypes.SELECT })
    ,
    db.query(`
      SELECT
        COALESCE(SUM(GREATEST(COALESCE(balance_due, 0), 0)), 0) AS total_outstanding
      FROM sales_headers
      WHERE outlet_id = :outletId
        AND status = 'COMPLETED'
        AND is_latest = TRUE
        AND is_deleted = FALSE
        AND NOT (order_type = 'DELIVERY' AND COALESCE(payment_mode, '') != 'CREDIT')
    `, { replacements: { outletId }, type: QueryTypes.SELECT }),
    db.query(`
      SELECT
        COALESCE(SUM(GREATEST(COALESCE(bill_amount, 0) - COALESCE(paid_amount, 0), 0)), 0) AS total_outstanding
      FROM supplier_bills
      WHERE outlet_id = :outletId
    `, { replacements: { outletId }, type: QueryTypes.SELECT }),
    db.query(`
      SELECT
        sh.id,
        sh.sale_no,
        sh.sale_date,
        sh.net_amount,
        sh.taxable_amount,
        sh.total_discount,
        sh.total_tax
      FROM sales_headers sh
      WHERE sh.outlet_id = :outletId
      ORDER BY sh.sale_date DESC, sh.id DESC
    `, { replacements: { outletId }, type: QueryTypes.SELECT })
    ,
    db.query(`
      SELECT
        txn_date,
        transaction_type,
        amount_in,
        amount_out,
        adjustment_amount,
        reference_type
      FROM cash_ledger
      WHERE outlet_id = :outletId
      ORDER BY txn_date ASC, id ASC
    `, { replacements: { outletId }, type: QueryTypes.SELECT }),
    db.query(`
      SELECT
        txn_date,
        covered_qty,
        covered_amount
      FROM milk_subscription_consumptions
      WHERE outlet_id = :outletId
        AND status != 'CANCELLED'
    `, { replacements: { outletId }, type: QueryTypes.SELECT })
  ]);

  const sales = await db.models.sales_headers.findAll({
    where: { outlet_id: outletId },
    include: [{
      model: db.models.sales_items,
      as: 'items',
      include: [{
        model: db.models.item_master,
        as: 'item',
        attributes: ['rate', 'item_group', 'sub_category', 'brand']
      }]
    }],
    order: [['sale_date', 'DESC'], ['id', 'DESC']]
  });

  const topItemMap = new Map();
  const periodAccumulator = {
    day: { current: { sales: 0, profit: 0, loss: 0 }, previous: { sales: 0, profit: 0, loss: 0 } },
    week: { current: { sales: 0, profit: 0, loss: 0 }, previous: { sales: 0, profit: 0, loss: 0 } },
    month: { current: { sales: 0, profit: 0, loss: 0 }, previous: { sales: 0, profit: 0, loss: 0 } },
    year: { current: { sales: 0, profit: 0, loss: 0 }, previous: { sales: 0, profit: 0, loss: 0 } }
  };

  const now = new Date();
  const currentDayStart = startOfDay(now);
  const previousDayStart = new Date(currentDayStart);
  previousDayStart.setDate(previousDayStart.getDate() - 1);
  const currentWeekStart = startOfWeek(now);
  const previousWeekStart = new Date(currentWeekStart);
  previousWeekStart.setDate(previousWeekStart.getDate() - 7);
  const currentMonthStart = startOfMonth(now);
  const previousMonthStart = new Date(currentMonthStart);
  previousMonthStart.setMonth(previousMonthStart.getMonth() - 1);
  const currentYearStart = startOfYear(now);
  const previousYearStart = new Date(currentYearStart);
  previousYearStart.setFullYear(previousYearStart.getFullYear() - 1);

  const currentDayEnd = new Date(currentDayStart);
  currentDayEnd.setDate(currentDayEnd.getDate() + 1);
  const currentWeekEnd = new Date(currentWeekStart);
  currentWeekEnd.setDate(currentWeekEnd.getDate() + 7);
  const currentMonthEnd = new Date(currentMonthStart);
  currentMonthEnd.setMonth(currentMonthEnd.getMonth() + 1);
  const currentYearEnd = new Date(currentYearStart);
  currentYearEnd.setFullYear(currentYearEnd.getFullYear() + 1);

  function fitsRange(date, start, end) {
    return date >= start && date < end;
  }

  function addPeriod(rangeKey, date, salesValue, profitValue, lossValue) {
    const bucket = periodAccumulator[rangeKey];
    if (!bucket) return;
    if (fitsRange(date, bucket.currentStart, bucket.currentEnd)) {
      bucket.current.sales = roundAmount(bucket.current.sales + salesValue);
      bucket.current.profit = roundAmount(bucket.current.profit + profitValue);
      bucket.current.loss = roundAmount(bucket.current.loss + lossValue);
    } else if (fitsRange(date, bucket.previousStart, bucket.previousEnd)) {
      bucket.previous.sales = roundAmount(bucket.previous.sales + salesValue);
      bucket.previous.profit = roundAmount(bucket.previous.profit + profitValue);
      bucket.previous.loss = roundAmount(bucket.previous.loss + lossValue);
    }
  }

  periodAccumulator.day = periodBetween(currentDayStart, previousDayStart, currentDayEnd, currentDayStart);
  periodAccumulator.week = periodBetween(currentWeekStart, previousWeekStart, currentWeekEnd, currentWeekStart);
  periodAccumulator.month = periodBetween(currentMonthStart, previousMonthStart, currentMonthEnd, previousMonthStart);
  periodAccumulator.year = periodBetween(currentYearStart, previousYearStart, currentYearEnd, previousYearStart);

  let grandProfit = 0;
  let grandLoss = 0;
  let grandRevenue = 0;
  let grandTaxableRevenue = 0;
  let cogsTotal = 0;
  let todayDiscount = 0;
  let todayRevenue = 0;
  let todayTaxableRevenue = 0;
  let todayCollection = 0;
  let todayCogs = 0;
  let todayGst = 0;

  for (const sale of sales) {
    const saleDate = normalizeDate(sale.sale_date);
    let saleProfit = 0;
    let saleLoss = 0;
    const saleRevenue = toNumber(sale.net_amount);

    for (const item of sale.items || []) {
      const qty = toNumber(item.qty);
      const lineNet = toNumber(item.net_amount);
      const lineTaxable = toNumber(item.taxable_amount);
      const itemCost = toNumber(item.item?.rate) * qty;
      cogsTotal = roundAmount(cogsTotal + itemCost);
      if (fitsRange(saleDate, currentDayStart, currentDayEnd)) {
        todayCogs = roundAmount(todayCogs + itemCost);
      }
      const lineProfit = lineTaxable - itemCost;
      saleProfit += Math.max(lineProfit, 0);
      saleLoss += lineProfit < 0 ? Math.abs(lineProfit) : 0;

      if (fitsRange(saleDate, currentDayStart, currentDayEnd)) {
        const zone = resolveSaleZone(saleDate).key;
        const itemKey = `${item.item_name}||${item.item_code || ''}`;
        if (!topItemMap.has(itemKey)) {
          topItemMap.set(itemKey, {
            item_name: item.item_name,
            item_code: item.item_code || '',
            item_group: item.item?.item_group || '',
            sub_category: item.item?.sub_category || '',
            brand: item.item?.brand || '',
            total_qty: 0,
            total_sales: 0,
            zones: Object.fromEntries(SALES_ZONES.map((entry) => [entry.key, { qty: 0, sales: 0 }]))
          });
        }
        const itemEntry = topItemMap.get(itemKey);
        itemEntry.total_qty = roundAmount(itemEntry.total_qty + qty);
        itemEntry.total_sales = roundAmount(itemEntry.total_sales + lineNet);
        itemEntry.zones[zone].qty = roundAmount(itemEntry.zones[zone].qty + qty);
        itemEntry.zones[zone].sales = roundAmount(itemEntry.zones[zone].sales + lineNet);
      }
    }

    grandRevenue = roundAmount(grandRevenue + saleRevenue);
    grandTaxableRevenue = roundAmount(grandTaxableRevenue + toNumber(sale.taxable_amount));
    grandProfit = roundAmount(grandProfit + saleProfit);
    grandLoss = roundAmount(grandLoss + saleLoss);
    if (fitsRange(saleDate, currentDayStart, currentDayEnd)) {
      todayDiscount = roundAmount(todayDiscount + toNumber(sale.total_discount));
      todayRevenue = roundAmount(todayRevenue + saleRevenue);
      todayTaxableRevenue = roundAmount(todayTaxableRevenue + toNumber(sale.taxable_amount));
      todayGst = roundAmount(todayGst + toNumber(sale.total_tax));
    }

    addPeriod('day', saleDate, toNumber(sale.taxable_amount), saleProfit, saleLoss);
    addPeriod('week', saleDate, toNumber(sale.taxable_amount), saleProfit, saleLoss);
    addPeriod('month', saleDate, toNumber(sale.taxable_amount), saleProfit, saleLoss);
    addPeriod('year', saleDate, toNumber(sale.taxable_amount), saleProfit, saleLoss);
  }

  let todaySubscriptionQty = 0;
  let todaySubscriptionAmount = 0;

  for (const c of subscriptionConsumptionResult || []) {
    const cDate = normalizeDate(c.txn_date);
    const cAmount = toNumber(c.covered_amount);
    const cQty = toNumber(c.covered_qty);

    if (fitsRange(cDate, currentDayStart, currentDayEnd)) {
      todaySubscriptionAmount = roundAmount(todaySubscriptionAmount + cAmount);
      todaySubscriptionQty = roundAmount(todaySubscriptionQty + cQty);
      todayRevenue = roundAmount(todayRevenue + cAmount);
      todayTaxableRevenue = roundAmount(todayTaxableRevenue + cAmount);
    }

    grandRevenue = roundAmount(grandRevenue + cAmount);
    grandTaxableRevenue = roundAmount(grandTaxableRevenue + cAmount);

    addPeriod('day', cDate, cAmount, 0, 0);
    addPeriod('week', cDate, cAmount, 0, 0);
    addPeriod('month', cDate, cAmount, 0, 0);
    addPeriod('year', cDate, cAmount, 0, 0);
  }

  let cashInTotal = 0;
  let cashOutTotal = 0;
  let cashNetTotal = 0;
  let expenseTotal = 0;
  let withdrawalTotal = 0;
  let supplierPaymentTotal = 0;
  let customerAdvanceTotal = 0;
  let repaymentTotal = 0;
  let openingDepositTotal = 0;
  const monthlyTransactionTypeMap = new Map();
  const cashPeriodMap = {
    day: { current: 0, previous: 0 },
    week: { current: 0, previous: 0 },
    month: { current: 0, previous: 0 },
    year: { current: 0, previous: 0 }
  };

  function addCashPeriod(rangeKey, date, netAmount) {
    const bucket = cashPeriodMap[rangeKey];
    if (!bucket) return;
    if (fitsRange(date, periodAccumulator[rangeKey].currentStart, periodAccumulator[rangeKey].currentEnd)) {
      bucket.current = roundAmount(bucket.current + netAmount);
    } else if (fitsRange(date, periodAccumulator[rangeKey].previousStart, periodAccumulator[rangeKey].previousEnd)) {
      bucket.previous = roundAmount(bucket.previous + netAmount);
    }
  }

  for (const entry of cashLedgerRows || []) {
    const type = String(entry.transaction_type || '').toUpperCase();
    const entryDate = normalizeDate(entry.txn_date);
    const inAmount = toNumber(entry.amount_in);
    const outAmount = toNumber(entry.amount_out);
    const netAmount = roundAmount(inAmount - outAmount);

    if (fitsRange(entryDate, currentDayStart, currentDayEnd)) {
      if (type !== 'OPENING_DEPOSIT' && inAmount > 0) {
        todayCollection = roundAmount(todayCollection + inAmount);
      }
    }

    if (type === 'OPENING_DEPOSIT') {
      openingDepositTotal = roundAmount(openingDepositTotal + inAmount - outAmount);
      continue;
    }

    cashInTotal = roundAmount(cashInTotal + inAmount);
    cashOutTotal = roundAmount(cashOutTotal + outAmount);
    cashNetTotal = roundAmount(cashNetTotal + netAmount);

    if (type === 'EXPENSE') {
      expenseTotal = roundAmount(expenseTotal + outAmount);
    } else if (type === 'WITHDRAWAL') {
      withdrawalTotal = roundAmount(withdrawalTotal + outAmount);
    } else if (type === 'SUPPLIER_PAYMENT') {
      supplierPaymentTotal = roundAmount(supplierPaymentTotal + outAmount);
    } else if (type === 'CUSTOMER_ADVANCE') {
      customerAdvanceTotal = roundAmount(customerAdvanceTotal + inAmount);
    } else if (type === 'REPAYMENT') {
      repaymentTotal = roundAmount(repaymentTotal + inAmount);
    }

    if (entryDate >= currentMonthStart && entryDate < currentMonthEnd) {
      const summaryKey = type || 'UNKNOWN';
      if (!monthlyTransactionTypeMap.has(summaryKey)) {
        monthlyTransactionTypeMap.set(summaryKey, {
          transaction_type: summaryKey,
          transaction_label: summaryKey.replace(/_/g, ' '),
          credited: 0,
          debited: 0,
          net: 0,
          count: 0
        });
      }
      const summaryRow = monthlyTransactionTypeMap.get(summaryKey);
      summaryRow.credited = roundAmount(summaryRow.credited + inAmount);
      summaryRow.debited = roundAmount(summaryRow.debited + outAmount);
      summaryRow.net = roundAmount(summaryRow.net + netAmount);
      summaryRow.count += 1;
    }

    addCashPeriod('day', entryDate, netAmount);
    addCashPeriod('week', entryDate, netAmount);
    addCashPeriod('month', entryDate, netAmount);
    addCashPeriod('year', entryDate, netAmount);
  }

  const grossProfitValue = roundAmount(grandTaxableRevenue - cogsTotal);
  const grossProfit = grossProfitValue > 0 ? grossProfitValue : 0;
  const grossLoss = grossProfitValue < 0 ? Math.abs(grossProfitValue) : 0;
  const todayGrossProfitValue = roundAmount(todayTaxableRevenue - todayCogs);
  const todayGrossProfit = todayGrossProfitValue > 0 ? todayGrossProfitValue : 0;
  const todayGrossLoss = todayGrossProfitValue < 0 ? Math.abs(todayGrossProfitValue) : 0;
  const grossMarginPercent = grandTaxableRevenue > 0 ? roundAmount((grossProfitValue / grandTaxableRevenue) * 100) : 0;
  const customerOutstanding = roundAmount(customerOutstandingResult?.[0]?.total_outstanding || 0);
  const supplierOutstanding = roundAmount(supplierOutstandingResult?.[0]?.total_outstanding || 0);
  const monthlyTransactionTypes = [...monthlyTransactionTypeMap.values()]
    .sort((a, b) => Math.abs(b.net) - Math.abs(a.net));

  const top5ItemHeatmap = [...topItemMap.values()]
    .sort((a, b) => b.total_sales - a.total_sales)
    .slice(0, 5);

  const comparisons = {
    day_to_yesterday: {
      current: periodAccumulator.day.current,
      previous: periodAccumulator.day.previous,
      growth_percent: growthPercent(periodAccumulator.day.current.sales, periodAccumulator.day.previous.sales)
    },
    week_to_previous_week: {
      current: periodAccumulator.week.current,
      previous: periodAccumulator.week.previous,
      growth_percent: growthPercent(periodAccumulator.week.current.sales, periodAccumulator.week.previous.sales)
    },
    month_to_previous_month: {
      current: periodAccumulator.month.current,
      previous: periodAccumulator.month.previous,
      growth_percent: growthPercent(periodAccumulator.month.current.sales, periodAccumulator.month.previous.sales)
    },
    year_to_previous_year: {
      current: periodAccumulator.year.current,
      previous: periodAccumulator.year.previous,
      growth_percent: growthPercent(periodAccumulator.year.current.sales, periodAccumulator.year.previous.sales)
    }
  };

  let netSubscription = 0;
  for (const entry of cashLedgerRows || []) {
    const inAmount = toNumber(entry.amount_in);
    const refType = String(entry.reference_type || '').toUpperCase();
    if (refType === 'SUBSCRIPTION') {
      netSubscription = roundAmount(netSubscription + inAmount);
    }
  }

  return {
            kpis: {
      todayIn: Number(kpis?.[0]?.today_in || 0),
      todayOut: Number(kpis?.[0]?.today_out || 0),
      lowStock: lowStockItems?.length || 0,
      stockValue: Number(stockValueResult?.[0]?.total_stock_value || 0),
      totalRevenue: grandRevenue,
      cogsTotal,
      grossProfit,
      grossLoss,
      grossMarginPercent,
      expenseTotal,
      withdrawalTotal,
      customerOutstanding,
      supplierOutstanding,
      totalOutstanding: roundAmount(customerOutstanding + supplierOutstanding),
      cashInTotal,
      cashOutTotal,
      cashNetTotal,
      openingDepositTotal,
      netOperatingProfit: roundAmount(grossProfit - expenseTotal),
      todaySubscriptionQty: todaySubscriptionQty,
      todaySubscriptionAmount: todaySubscriptionAmount,
      todayDiscount: todayDiscount,
      todayRevenue: todayRevenue,
      todayCollection: todayCollection,
      todayCogs: todayCogs,
      todayGrossProfit: todayGrossProfit,
      todayGrossLoss: todayGrossLoss,
      todayGst: todayGst,
      netSubscription,
      netDebit: cashOutTotal
    },

    lowStockItems: lowStockItems.map(i => {
      const brand = i.brand ? i.brand.trim() : '';
      return brand ? `${brand} - ${i.item_name}` : i.item_name;
    }),
    issueReceive7Days: issueReceive,
    departmentIssue,
    damageTrend7Days: damageTrend,
    categoryStock,
    supplierPayments,
    unpaidSuppliers,
    heatmapTopItems: top5ItemHeatmap,
    monthlyTransactionTypes,
    comparisons
  };
};

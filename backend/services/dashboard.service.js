const { QueryTypes, Op } = require('sequelize');
const { getOutletTimeZone, getNowInTimeZone, toOutletDateYmd } = require('../utils/timezoneHelper');

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

function safeArray(value) {
  return Array.isArray(value) ? value : [];
}

function formatDateLocalYmd(value, timeZone = 'Asia/Kolkata') {
  if (!value) return null;
  if (typeof value === 'string') {
    const clean = value.trim();
    if (/^\d{4}-\d{2}-\d{2}$/.test(clean)) return clean;
    const parsed = new Date(clean);
    if (!Number.isNaN(parsed.getTime())) {
      return toOutletDateYmd(parsed, timeZone);
    }
  }
  const dt = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(dt.getTime())) return null;
  return toOutletDateYmd(dt, timeZone);
}

function normalizeDate(value) {
  if (value instanceof Date) return value;
  if (typeof value === 'string') {
    const clean = value.trim();
    if (/^\d{4}-\d{2}-\d{2}$/.test(clean)) {
      const [year, month, day] = clean.split('-').map(Number);
      return new Date(year, month - 1, day);
    }
  }
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? new Date() : date;
}

function resolveSaleZone(dateValue, timeZone = 'Asia/Kolkata') {
  let hour = 0;
  try {
    const dt = dateValue instanceof Date ? dateValue : new Date(dateValue);
    const hourStr = dt.toLocaleTimeString('en-US', { timeZone, hour12: false, hour: '2-digit' });
    hour = parseInt(hourStr, 10);
  } catch (_) {
    hour = normalizeDate(dateValue).getHours();
  }

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

function getNowInLocalTime(timeZone = 'Asia/Kolkata') {
  return getNowInTimeZone(timeZone);
}

function growthPercent(current, previous) {
  if (!previous) return current > 0 ? 100 : 0;
  return roundAmount(((current - previous) / previous) * 100);
}

exports.getInventoryDashboard = async (outletId, db) => {
  const timeZone = await getOutletTimeZone(outletId, db);
  const now = new Date();
  const todayStr = toOutletDateYmd(now, timeZone);

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
        c.txn_date,
        c.covered_qty,
        c.covered_amount
      FROM milk_subscription_consumptions c
      LEFT JOIN sales_headers sh ON c.sale_id = sh.id
      WHERE c.outlet_id = :outletId
        AND c.status != 'CANCELLED'
        AND NOT (c.status = 'PENDING' AND c.excess_qty > 0 AND sh.payment_mode != 'SUBSCRIPTION')
    `, { replacements: { outletId }, type: QueryTypes.SELECT })
  ]);

  const sales = await db.models.sales_headers.findAll({
    where: {
      outlet_id: outletId,
      status: { [Op.in]: ['COMPLETED', 'RETURNED'] },
      is_deleted: false,
      is_latest: true
    },
    include: [
      {
        model: db.models.sales_items,
        as: 'items',
        include: [{
          model: db.models.item_master,
          as: 'item',
          attributes: ['rate', 'retail_sale_price', 'item_group', 'sub_category', 'brand', 'is_tax_inclusive']
        }]
      },
      {
        model: db.models.milk_subscription_consumptions,
        as: 'consumptions',
        required: false
      },
      {
        model: db.models.customer_repayments,
        as: 'repayments',
        required: false
      }
    ],
    order: [['sale_date', 'DESC'], ['id', 'DESC']]
  });

  const topItemMap = new Map();
  const periodAccumulator = {
    day: { current: { sales: 0, profit: 0, loss: 0 }, previous: { sales: 0, profit: 0, loss: 0 } },
    week: { current: { sales: 0, profit: 0, loss: 0 }, previous: { sales: 0, profit: 0, loss: 0 } },
    month: { current: { sales: 0, profit: 0, loss: 0 }, previous: { sales: 0, profit: 0, loss: 0 } },
    year: { current: { sales: 0, profit: 0, loss: 0 }, previous: { sales: 0, profit: 0, loss: 0 } }
  };

  const yesterdayDt = new Date(now.getTime() - 86400000);
  const yesterdayStr = toOutletDateYmd(yesterdayDt, timeZone);

  const getWeekStartStr = (dateYmd) => {
    if (!dateYmd) return '';
    const [y, m, d] = dateYmd.split('-').map(Number);
    const dt = new Date(y, m - 1, d);
    const day = dt.getDay();
    const diff = (day + 6) % 7;
    dt.setDate(dt.getDate() - diff);
    const wy = dt.getFullYear();
    const wm = String(dt.getMonth() + 1).padStart(2, '0');
    const wd = String(dt.getDate()).padStart(2, '0');
    return `${wy}-${wm}-${wd}`;
  };

  const getPreviousWeekStartStr = (currentWeekStartStr) => {
    if (!currentWeekStartStr) return '';
    const [y, m, d] = currentWeekStartStr.split('-').map(Number);
    const dt = new Date(y, m - 1, d - 7);
    const wy = dt.getFullYear();
    const wm = String(dt.getMonth() + 1).padStart(2, '0');
    const wd = String(dt.getDate()).padStart(2, '0');
    return `${wy}-${wm}-${wd}`;
  };

  const currentWeekStartStr = getWeekStartStr(todayStr);
  const previousWeekStartStr = getPreviousWeekStartStr(currentWeekStartStr);

  const currentMonthStr = todayStr.slice(0, 7);
  const [cy, cm] = todayStr.split('-').map(Number);
  const prevMonthDt = new Date(cy, cm - 2, 1);
  const previousMonthStr = `${prevMonthDt.getFullYear()}-${String(prevMonthDt.getMonth() + 1).padStart(2, '0')}`;

  const currentYearStr = todayStr.slice(0, 4);
  const previousYearStr = String(Number(currentYearStr) - 1);

  function isSameDay(date1, date2) {
    const d1 = formatDateLocalYmd(date1, timeZone);
    const d2 = formatDateLocalYmd(date2, timeZone);
    return Boolean(d1 && d2 && d1 === d2);
  }

  function addPeriodForDate(dateYmd, salesValue, profitValue, lossValue) {
    if (!dateYmd) return;
    if (dateYmd === todayStr) {
      periodAccumulator.day.current.sales = roundAmount(periodAccumulator.day.current.sales + salesValue);
      periodAccumulator.day.current.profit = roundAmount(periodAccumulator.day.current.profit + profitValue);
      periodAccumulator.day.current.loss = roundAmount(periodAccumulator.day.current.loss + lossValue);
    } else if (dateYmd === yesterdayStr) {
      periodAccumulator.day.previous.sales = roundAmount(periodAccumulator.day.previous.sales + salesValue);
      periodAccumulator.day.previous.profit = roundAmount(periodAccumulator.day.previous.profit + profitValue);
      periodAccumulator.day.previous.loss = roundAmount(periodAccumulator.day.previous.loss + lossValue);
    }

    if (dateYmd >= currentWeekStartStr && dateYmd <= todayStr) {
      periodAccumulator.week.current.sales = roundAmount(periodAccumulator.week.current.sales + salesValue);
      periodAccumulator.week.current.profit = roundAmount(periodAccumulator.week.current.profit + profitValue);
      periodAccumulator.week.current.loss = roundAmount(periodAccumulator.week.current.loss + lossValue);
    } else if (dateYmd >= previousWeekStartStr && dateYmd < currentWeekStartStr) {
      periodAccumulator.week.previous.sales = roundAmount(periodAccumulator.week.previous.sales + salesValue);
      periodAccumulator.week.previous.profit = roundAmount(periodAccumulator.week.previous.profit + profitValue);
      periodAccumulator.week.previous.loss = roundAmount(periodAccumulator.week.previous.loss + lossValue);
    }

    if (dateYmd.startsWith(currentMonthStr)) {
      periodAccumulator.month.current.sales = roundAmount(periodAccumulator.month.current.sales + salesValue);
      periodAccumulator.month.current.profit = roundAmount(periodAccumulator.month.current.profit + profitValue);
      periodAccumulator.month.current.loss = roundAmount(periodAccumulator.month.current.loss + lossValue);
    } else if (dateYmd.startsWith(previousMonthStr)) {
      periodAccumulator.month.previous.sales = roundAmount(periodAccumulator.month.previous.sales + salesValue);
      periodAccumulator.month.previous.profit = roundAmount(periodAccumulator.month.previous.profit + profitValue);
      periodAccumulator.month.previous.loss = roundAmount(periodAccumulator.month.previous.loss + lossValue);
    }

    if (dateYmd.startsWith(currentYearStr)) {
      periodAccumulator.year.current.sales = roundAmount(periodAccumulator.year.current.sales + salesValue);
      periodAccumulator.year.current.profit = roundAmount(periodAccumulator.year.current.profit + profitValue);
      periodAccumulator.year.current.loss = roundAmount(periodAccumulator.year.current.loss + lossValue);
    } else if (dateYmd.startsWith(previousYearStr)) {
      periodAccumulator.year.previous.sales = roundAmount(periodAccumulator.year.previous.sales + salesValue);
      periodAccumulator.year.previous.profit = roundAmount(periodAccumulator.year.previous.profit + profitValue);
      periodAccumulator.year.previous.loss = roundAmount(periodAccumulator.year.previous.loss + lossValue);
    }
  }

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
  let todaySubscriptionAmount = 0;

  for (const sale of sales) {
    const subItems = safeArray(sale.items).filter(i => i.is_advance_free);
    const subscriptionSubtotal = subItems.reduce((sum, i) => sum + toNumber(i.amount), 0);
    const subscriptionTax = subItems.reduce((sum, i) => sum + toNumber(i.tax_amount), 0);
    const subscriptionTaxable = subItems.reduce((sum, i) => sum + toNumber(i.taxable_amount), 0);
    const subscriptionNet = subItems.reduce((sum, i) => {
      const dbNet = toNumber(i.net_amount);
      if (dbNet > 0) return sum + dbNet;
      const dbLineTotal = toNumber(i.line_total);
      if (dbLineTotal > 0) return sum + dbLineTotal;
      const isInclusive = i.tax_type === 'GST_INCLUSIVE' || i.is_tax_inclusive === true || i.isTaxInclusive === true;
      if (isInclusive) {
        const amt = toNumber(i.amount);
        if (amt > 0) return sum + amt;
        const taxable = toNumber(i.taxable_amount);
        const taxAmt = toNumber(i.tax_amount);
        if (taxable > 0 && taxAmt > 0) return sum + taxable + taxAmt;
        return sum + taxable;
      } else {
        const taxPct = toNumber(i.tax_percent || i.taxPercent);
        const taxAmt = toNumber(i.tax_amount) > 0 ? toNumber(i.tax_amount) : (toNumber(i.taxable_amount) * (taxPct / 100));
        const calcNet = toNumber(i.taxable_amount) + taxAmt;
        return sum + (calcNet > 0 ? calcNet : (toNumber(i.amount) * (1 + taxPct / 100)));
      }
    }, 0);

    const isFullSubscriptionSale = sale.payment_mode === 'SUBSCRIPTION';
    const saleTotalDiscount = isFullSubscriptionSale ? 0 : Math.max(toNumber(sale.total_discount) - subscriptionSubtotal, 0);
    const saleNetRevenue = toNumber(sale.net_amount) + subscriptionNet;

    // Calculate tax split matching sales report
    const saleBreakup = safeArray(sale.tax_breakup);
    let saleGst = 0;
    for (const tax of saleBreakup) {
      const code = String(tax.code || tax.label || '').toUpperCase();
      const amount = toNumber(tax.tax_amount);
      if (code.includes('CGST') || code.includes('SGST') || code.includes('IGST') || code.includes('GST')) {
        saleGst += amount;
      }
    }
    if (saleGst === 0 && toNumber(sale.total_tax) > 0) {
      saleGst = toNumber(sale.total_tax);
    }
    if (saleGst === 0 && subscriptionTax > 0) {
      saleGst = subscriptionTax;
    }

    const saleDateYmd = formatDateLocalYmd(sale.sale_date, timeZone);
    const isTodaySale = Boolean(saleDateYmd && saleDateYmd === todayStr);

    let saleProfit = 0;
    let saleLoss = 0;
    let saleCogs = 0;
    let itemTaxableSum = 0;

    for (const item of safeArray(sale.items)) {
      const qty = toNumber(item.qty);
      const dbLineNet = toNumber(item.net_amount);
      const lineTaxableRaw = toNumber(item.taxable_amount);
      const lineTax = toNumber(item.tax_amount);
      let lineNet = dbLineNet;
      if (item.is_advance_free) {
        const calculatedItemNet = lineTaxableRaw + lineTax;
        lineNet = dbLineNet > 0 ? dbLineNet : (calculatedItemNet > 0 ? calculatedItemNet : toNumber(item.amount));
      }
      let lineTaxable = lineTaxableRaw;
      if (lineTaxable <= 0) {
        lineTaxable = lineNet > 0 ? Math.max(0, lineNet - lineTax) : toNumber(item.amount);
      }
      itemTaxableSum += lineTaxable;

      const itemCost = toNumber(item.item?.rate) * qty;
      saleCogs += itemCost;
      cogsTotal = roundAmount(cogsTotal + itemCost);

      if (isTodaySale) {
        const zone = resolveSaleZone(sale.sale_date, timeZone).key;
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

    const itemLineDiscountSum = safeArray(sale.items).reduce((sum, i) => sum + toNumber(i.line_discount), 0);

    const headerTaxable = toNumber(sale.taxable_amount);
    let saleTaxableAmount = 0;
    if (headerTaxable > 0) {
      saleTaxableAmount = headerTaxable;
    } else if (saleNetRevenue > 0) {
      saleTaxableAmount = Math.max(0, roundAmount(saleNetRevenue - saleGst));
    } else {
      const baseSaleTaxable = itemTaxableSum > 0 ? itemTaxableSum : 0;
      const rawTaxable = baseSaleTaxable > 0 ? roundAmount(baseSaleTaxable) : roundAmount(subscriptionTaxable);
      saleTaxableAmount = Math.max(0, roundAmount(rawTaxable - saleTotalDiscount));
    }

    const netSaleMargin = roundAmount(saleTaxableAmount - saleCogs);
    saleProfit = netSaleMargin > 0 ? netSaleMargin : 0;
    saleLoss = netSaleMargin < 0 ? Math.abs(netSaleMargin) : 0;

    grandRevenue = roundAmount(grandRevenue + saleNetRevenue);
    grandTaxableRevenue = roundAmount(grandTaxableRevenue + saleTaxableAmount);
    grandProfit = roundAmount(grandProfit + saleProfit);
    grandLoss = roundAmount(grandLoss + saleLoss);

    if (isTodaySale) {
      let subscriptionAmount = (sale.consumptions || [])
        .filter(c => !(c.status === 'PENDING' && toNumber(c.excess_qty) > 0 && sale.payment_mode !== 'SUBSCRIPTION'))
        .reduce((sum, c) => sum + toNumber(c.covered_amount), 0);
      if (subscriptionAmount === 0 && subscriptionNet > 0) {
        subscriptionAmount = subscriptionNet;
      }
      subscriptionAmount = Math.min(subscriptionAmount, saleNetRevenue);

      todayDiscount = roundAmount(todayDiscount + saleTotalDiscount);
      todaySubscriptionAmount = roundAmount(todaySubscriptionAmount + subscriptionAmount);
      todayRevenue = roundAmount(todayRevenue + saleNetRevenue);
      todayTaxableRevenue = roundAmount(todayTaxableRevenue + saleTaxableAmount);
      todayGst = roundAmount(todayGst + saleGst);
      todayCogs = roundAmount(todayCogs + saleCogs);
    }

    addPeriodForDate(saleDateYmd, saleTaxableAmount, saleProfit, saleLoss);
  }

  let todaySubscriptionQty = 0;

  for (const c of subscriptionConsumptionResult || []) {
    const cDateYmd = formatDateLocalYmd(c.txn_date, timeZone);
    const cQty = toNumber(c.covered_qty);

    if (cDateYmd === todayStr) {
      todaySubscriptionQty = roundAmount(todaySubscriptionQty + cQty);
    }
  }

  let cashInTotal = 0;
  let cashOutTotal = 0;
  let cashNetTotal = 0;
  let expenseTotal = 0;
  let todayExpenses = 0;
  let withdrawalTotal = 0;
  let supplierPaymentTotal = 0;
  let customerAdvanceTotal = 0;
  let repaymentTotal = 0;
  let openingDepositTotal = 0;
  const monthlyTransactionTypeMap = new Map();

  for (const entry of cashLedgerRows || []) {
    const type = String(entry.transaction_type || '').toUpperCase();
    const entryDateYmd = formatDateLocalYmd(entry.txn_date, timeZone);
    const inAmount = toNumber(entry.amount_in);
    const outAmount = toNumber(entry.amount_out);
    const netAmount = roundAmount(inAmount - outAmount);

    if (entryDateYmd === todayStr) {
      if (type !== 'OPENING_DEPOSIT' && inAmount > 0) {
        todayCollection = roundAmount(todayCollection + inAmount);
      }
      if (type === 'EXPENSE') {
        todayExpenses = roundAmount(todayExpenses + outAmount);
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

    if (entryDateYmd && entryDateYmd.startsWith(currentMonthStr)) {
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
  }

  const grossProfitValue = roundAmount(grandTaxableRevenue - cogsTotal);
  const grossProfit = grossProfitValue > 0 ? grossProfitValue : 0;
  const grossLoss = grossProfitValue < 0 ? Math.abs(grossProfitValue) : 0;
  const todayGrossProfitValue = roundAmount(todayTaxableRevenue - todayCogs);
  const todayGrossProfit = todayGrossProfitValue > 0 ? todayGrossProfitValue : 0;
  const todayGrossLoss = todayGrossProfitValue < 0 ? Math.abs(todayGrossProfitValue) : 0;
  const todayNetProfitValue = roundAmount(todayTaxableRevenue - todayCogs - todayExpenses);
  const todayNetProfit = todayNetProfitValue > 0 ? todayNetProfitValue : 0;
  const todayNetLoss = todayNetProfitValue < 0 ? Math.abs(todayNetProfitValue) : 0;
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
      todayExpenses,
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
      todayTaxableRevenue: todayTaxableRevenue,
      todayCollection: todayCollection,
      todayCogs: todayCogs,
      todayGrossProfit: todayGrossProfit,
      todayGrossLoss: todayGrossLoss,
      todayNetProfit: todayNetProfit,
      todayNetLoss: todayNetLoss,
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

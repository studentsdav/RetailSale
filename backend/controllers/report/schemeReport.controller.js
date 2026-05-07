const { Op } = require('sequelize');

function dateOnly(value) {
  if (!value) return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

function formatDateLocalYmd(value) {
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function addDays(date, days) {
  const d = new Date(date);
  d.setDate(d.getDate() + Number(days || 0));
  return d;
}

function normalizeCustomerIdentity(row = {}) {
  return {
    customer_phone: String(row.customer_phone || '').replace(/\D/g, '').trim(),
    customer_gstin: String(row.customer_gstin || '').trim().toUpperCase(),
    customer_name: String(row.customer_name || '').trim(),
  };
}

function buildCustomerScope(identity = {}) {
  if (identity.customer_phone) return { customer_phone: identity.customer_phone };
  if (identity.customer_gstin) return { customer_gstin: identity.customer_gstin };
  if (identity.customer_name) return { customer_name: identity.customer_name };
  return null;
}

function customerKey(row = {}) {
  return String(row.customer_phone || row.customer_gstin || row.customer_name || '')
    .trim()
    .toLowerCase();
}

function dedupeByCustomer(rows = []) {
  const unique = new Map();
  for (const row of rows) {
    const key = customerKey(row);
    if (!key) continue;
    if (!unique.has(key)) {
      unique.set(key, row);
    }
  }
  return Array.from(unique.values());
}

async function findSchemeEnrollment(req, schemeId, identity) {
  const scope = buildCustomerScope(identity);
  if (!scope) return null;
  const enrollment = await req.propertyDb.models.sales_scheme_customers.findOne({
    where: {
      outlet_id: req.user.outlet_id,
      scheme_id: schemeId,
      ...scope,
    },
    order: [['id', 'DESC']],
  });

  if (enrollment) return enrollment;

  const fallback = await req.propertyDb.models.sales_headers.findOne({
    where: {
      outlet_id: req.user.outlet_id,
      scheme_id: schemeId,
      status: 'COMPLETED',
      is_latest: true,
      is_deleted: false,
      ...scope,
    },
    order: [['sale_date', 'ASC'], ['id', 'ASC']],
  });

  if (!fallback) return null;

  return {
    customer_name: fallback.customer_name,
    customer_phone: fallback.customer_phone,
    customer_gstin: fallback.customer_gstin,
    start_date: fallback.sale_date,
    is_active: true,
    scheme_id: schemeId,
  };
}

async function computeCycleProgress({ req, scheme, enrollment, asOfDate }) {
  const startDate = enrollment?.start_date ? new Date(enrollment.start_date) : null;
  const today = dateOnly(asOfDate) || dateOnly(new Date());
  const cycleDays = Math.max(1, Number(scheme.cycle_days) || 30);
  const itemId = Number(scheme.item_id);

  if (!startDate || !today || !Number.isFinite(itemId)) return null;

  const start = dateOnly(startDate);
  const diffMs = today.getTime() - start.getTime();
  const diffDays = Math.floor(diffMs / (24 * 60 * 60 * 1000));
  const cycleIndex = diffDays >= 0 ? Math.floor(diffDays / cycleDays) : 0;
  const cycleStart = addDays(start, cycleIndex * cycleDays);
  const cycleEnd = addDays(cycleStart, cycleDays - 1);
  const dateToCheck = today < cycleEnd ? today : cycleEnd;
  const cycleElapsedDays = Math.floor((today.getTime() - cycleStart.getTime()) / (24 * 60 * 60 * 1000));

  const identity = normalizeCustomerIdentity(enrollment);
  const scope = buildCustomerScope(identity);
  if (!scope) return null;

  const [rows] = await req.propertyDb.query(
    `
SELECT DATE(sh.sale_date) AS sale_day,
       COALESCE(SUM(si.qty), 0) AS qty
FROM sales_headers sh
JOIN sales_items si ON si.sale_id = sh.id
WHERE sh.outlet_id = :outlet_id
  AND sh.status = 'COMPLETED'
  AND sh.is_latest = TRUE
  AND sh.is_deleted = FALSE
  AND si.item_id = :item_id
  AND COALESCE(si.is_scheme_free, FALSE) = FALSE
  AND DATE(sh.sale_date) BETWEEN :from_day AND :to_day
  AND (
    (:customer_phone <> '' AND sh.customer_phone = :customer_phone)
    OR (:customer_gstin <> '' AND sh.customer_gstin = :customer_gstin)
    OR (:customer_name <> '' AND sh.customer_name = :customer_name)
  )
GROUP BY DATE(sh.sale_date)
ORDER BY sale_day ASC
    `,
    {
      replacements: {
        outlet_id: req.user.outlet_id,
        item_id: itemId,
        from_day: formatDateLocalYmd(cycleStart),
        to_day: formatDateLocalYmd(dateToCheck),
        customer_phone: identity.customer_phone || '',
        customer_gstin: identity.customer_gstin || '',
        customer_name: identity.customer_name || '',
      },
    }
  );

  const daily = new Map();
  for (const row of rows || []) {
    const d = row.sale_day instanceof Date ? row.sale_day : new Date(row.sale_day);
    const key = formatDateLocalYmd(dateOnly(d));
    daily.set(key, Number(row.qty) || 0);
  }

  const requiredDailyQty = Math.max(
    0,
    Number(scheme.required_daily_qty) || Number(scheme.free_qty) || 0
  );
  let qualifiedDays = 0;
  let billedQty = 0;
  for (const qty of daily.values()) {
    if (requiredDailyQty > 0) {
      if (qty >= requiredDailyQty) qualifiedDays += 1;
    } else if (qty > 0) {
      qualifiedDays += 1;
    }
    billedQty += qty;
  }

  const missingDays = [];
  for (let d = new Date(cycleStart); d <= dateToCheck; d = addDays(d, 1)) {
    const key = formatDateLocalYmd(dateOnly(d));
    const qty = Number(daily.get(key) || 0);
    if (requiredDailyQty > 0 ? qty < requiredDailyQty : qty <= 0) {
      missingDays.push(key);
    }
  }

  const minQty = Number(scheme.min_qty) || 0;
  const daysElapsed = Math.max(0, cycleElapsedDays);
  const daysLeft = Math.max(0, Math.floor((cycleEnd.getTime() - today.getTime()) / (24 * 60 * 60 * 1000)));
  const totalRequiredQty = requiredDailyQty > 0
    ? requiredDailyQty * Math.max(1, cycleDays)
    : minQty;

  return {
    cycle_start: formatDateLocalYmd(cycleStart),
    cycle_end: formatDateLocalYmd(cycleEnd),
    cycle_days: cycleDays,
    days_elapsed: daysElapsed,
    days_left: daysLeft,
    item_id: itemId,
    min_qty: minQty,
    free_qty: requiredDailyQty,
    required_daily_qty: requiredDailyQty,
    required_total_qty: totalRequiredQty,
    total_qty: billedQty,
    consumed_qty: billedQty,
    qualified_days: qualifiedDays,
    remaining_qty: Math.max(totalRequiredQty - billedQty, 0),
    missing_days: missingDays,
    require_no_gaps: !!scheme.require_no_gaps,
    is_cycle_end_day: today.getTime() === cycleEnd.getTime(),
  };
}

async function computeItemAdvanceSummary({ req, identity, itemId, asOfDate }) {
  const toDate = dateOnly(asOfDate) || dateOnly(new Date());
  const toDay = formatDateLocalYmd(toDate);
  const [advRows] = await req.propertyDb.query(
    `
 SELECT COALESCE(SUM(original_qty), 0) AS original_qty
 FROM customer_item_advances
 WHERE outlet_id = :outlet_id
   AND item_id = :item_id
   AND DATE(advance_date) <= :to_day
   AND (
     (:customer_phone <> '' AND customer_phone = :customer_phone)
     OR (:customer_gstin <> '' AND customer_gstin = :customer_gstin)
     OR (:customer_name <> '' AND customer_name = :customer_name)
   )
     `,
    {
      replacements: {
        outlet_id: req.user.outlet_id,
        item_id: itemId,
        to_day: toDay,
        customer_phone: identity.customer_phone || '',
        customer_gstin: identity.customer_gstin || '',
        customer_name: identity.customer_name || '',
      },
    }
  );

  const [consumeRows] = await req.propertyDb.query(
    `
SELECT COALESCE(SUM(original_qty - available_qty), 0) AS consumed_qty
FROM customer_item_advances
WHERE outlet_id = :outlet_id
  AND item_id = :item_id
  AND DATE(advance_date) <= :to_day
  AND (
    (:customer_phone <> '' AND customer_phone = :customer_phone)
    OR (:customer_gstin <> '' AND customer_gstin = :customer_gstin)
    OR (:customer_name <> '' AND customer_name = :customer_name)
  )
     `,
    {
      replacements: {
        outlet_id: req.user.outlet_id,
        item_id: itemId,
        to_day: toDay,
        customer_phone: identity.customer_phone || '',
        customer_gstin: identity.customer_gstin || '',
        customer_name: identity.customer_name || '',
      },
    }
  );

  const originalQty = Number(advRows?.[0]?.original_qty) || 0;
  const consumedQty = Number(consumeRows?.[0]?.consumed_qty) || 0;
  return {
    original_qty: originalQty,
    consumed_qty: consumedQty,
    remaining_qty: Math.max(originalQty - consumedQty, 0),
    as_of_date: toDay,
  };
}

async function loadCycleWindowDetails({ req, scheme, enrollment, identity, progress, asOfDate }) {
  const cycleStart = dateOnly(progress?.cycle_start) || dateOnly(enrollment?.start_date) || dateOnly(asOfDate);
  const cycleEnd = dateOnly(progress?.cycle_end) || dateOnly(asOfDate);
  const itemId = Number(scheme.item_id);
  if (!cycleStart || !cycleEnd || !Number.isFinite(itemId)) return [];

  const replacements = {
    outlet_id: req.user.outlet_id,
    item_id: itemId,
    from_day: formatDateLocalYmd(cycleStart),
    to_day: formatDateLocalYmd(cycleEnd),
    customer_phone: identity.customer_phone || '',
    customer_gstin: identity.customer_gstin || '',
    customer_name: identity.customer_name || '',
  };

  let customerWhere = '';
  if (identity.customer_phone) {
    customerWhere = "AND sh.customer_phone = :customer_phone";
  } else if (identity.customer_gstin) {
    customerWhere = "AND sh.customer_gstin = :customer_gstin";
  } else if (identity.customer_name) {
    customerWhere = "AND sh.customer_name = :customer_name";
  }

  const [billRows] = await req.propertyDb.query(
    `
  SELECT DATE(sh.sale_date) AS sale_day,
         sh.id AS sale_id,
         sh.sale_no,
         COALESCE(SUM(si.qty), 0) AS qty,
         COALESCE(SUM(si.net_amount), 0) AS amount
  FROM sales_headers sh
JOIN sales_items si ON si.sale_id = sh.id
  WHERE sh.outlet_id = :outlet_id
    AND sh.status = 'COMPLETED'
    AND sh.is_latest = TRUE
    AND sh.is_deleted = FALSE
    AND si.item_id = :item_id
    AND COALESCE(si.is_scheme_free, FALSE) = FALSE
    AND DATE(sh.sale_date) BETWEEN :from_day AND :to_day
    ${customerWhere}
  GROUP BY DATE(sh.sale_date), sh.id, sh.sale_no
  ORDER BY sale_day ASC, sh.id ASC
      `,
    { replacements }
  );

  const billsByDay = new Map();
  for (const row of billRows || []) {
    const key = formatDateLocalYmd(dateOnly(row.sale_day));
    if (!billsByDay.has(key)) billsByDay.set(key, []);
    billsByDay.get(key).push({
      sale_id: Number(row.sale_id) || 0,
      sale_no: row.sale_no,
      qty: Number(row.qty) || 0,
      amount: Number(row.amount) || 0,
    });
  }

  const days = [];
  const requiredDailyQty = Math.max(
    0,
    Number(scheme.required_daily_qty) || Number(scheme.free_qty) || 0
  );
  for (let day = new Date(cycleStart); day <= cycleEnd; day = addDays(day, 1)) {
    const key = formatDateLocalYmd(dateOnly(day));
    const bills = billsByDay.get(key) || [];
    const billedQty = bills.reduce((sum, bill) => sum + (Number(bill.qty) || 0), 0);
    days.push({
      date: key,
      required_qty: requiredDailyQty,
      consumed_qty: billedQty,
      met: requiredDailyQty > 0 ? billedQty >= requiredDailyQty : billedQty > 0,
      billed_qty: billedQty,
      missed: bills.length === 0,
      bills,
    });
  }

  return days;
}

exports.getSchemeReport = async (req, res) => {
  try {
    const outlet_id = req.user.outlet_id;
    const schemeId = Number(req.query.scheme_id || req.query.schemeId);
    const asOfDate = req.query.date || req.query.as_of_date || new Date();
    const reportFilter = String(req.query.report_filter || req.query.filter || 'RUNNING')
      .trim()
      .toUpperCase();

    if (!Number.isFinite(schemeId) || schemeId <= 0) {
      return res.status(400).json({ success: false, message: 'scheme_id is required' });
    }

    const scheme = await req.propertyDb.models.sales_schemes.findOne({
      where: { id: schemeId, outlet_id },
    });
    if (!scheme) {
      return res.status(404).json({ success: false, message: 'Scheme not found' });
    }

    const whereEnroll = {
      outlet_id,
      scheme_id: schemeId,
    };
    const activeOnlyParam = req.query.active_only;
    const shouldApplyLegacyActiveOnly =
      activeOnlyParam !== undefined || reportFilter === 'RUNNING';
    if (
      shouldApplyLegacyActiveOnly &&
      String(activeOnlyParam ?? 'true').toLowerCase() !== 'false'
    ) {
      whereEnroll.is_active = true;
    }

    let enrollments = await req.propertyDb.models.sales_scheme_customers.findAll({
      where: whereEnroll,
      order: [['id', 'DESC']],
    });
    enrollments = dedupeByCustomer(enrollments);

    if (enrollments.length === 0) {
      const fallbackRows = await req.propertyDb.models.sales_headers.findAll({
        where: {
          outlet_id,
          scheme_id: schemeId,
          status: 'COMPLETED',
          is_latest: true,
          is_deleted: false,
        },
        attributes: ['customer_name', 'customer_phone', 'customer_gstin', 'sale_date'],
        order: [['sale_date', 'ASC'], ['id', 'ASC']],
      });

      const unique = new Map();
      for (const row of fallbackRows) {
        const key = customerKey(row);
        if (!key || unique.has(key)) continue;
        unique.set(key, {
          customer_name: row.customer_name,
          customer_phone: row.customer_phone,
          customer_gstin: row.customer_gstin,
          start_date: row.sale_date,
          is_active: true,
          scheme_id: schemeId,
          id: `fallback-${key}`,
        });
      }
      enrollments = dedupeByCustomer(Array.from(unique.values()));
    }

    const out = [];
    for (const enrollment of enrollments) {
      const identity = normalizeCustomerIdentity(enrollment);
      const progress = await computeCycleProgress({
        req,
        scheme,
        enrollment,
        asOfDate,
      });

      const remainingQty = Number(progress?.remaining_qty) || 0;
      const daysLeft = Number(progress?.days_left) || 0;
      const isActive = enrollment?.is_active !== false;
      const isConsumed = !isActive || remainingQty <= 0 || daysLeft <= 0;
      const isRunning = isActive && !isConsumed;

      if (reportFilter === 'CONSUMED' && !isConsumed) continue;
      if (reportFilter === 'RUNNING' && !isRunning) continue;

      out.push({
        enrollment,
        progress,
      });
    }

    res.json({
      success: true,
      data: {
        scheme,
        as_of_date: formatDateLocalYmd(dateOnly(asOfDate)) || null,
        rows: out,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};

exports.getSchemeCycleDetail = async (req, res) => {
  try {
    const outlet_id = req.user.outlet_id;
    const schemeId = Number(req.query.scheme_id || req.query.schemeId);
    const asOfDate = req.query.date || req.query.as_of_date || new Date();

    if (!Number.isFinite(schemeId) || schemeId <= 0) {
      return res.status(400).json({ success: false, message: 'scheme_id is required' });
    }

    const scheme = await req.propertyDb.models.sales_schemes.findOne({
      where: { id: schemeId, outlet_id },
    });
    if (!scheme) {
      return res.status(404).json({ success: false, message: 'Scheme not found' });
    }

    let enrollment = null;
    const enrollmentId = Number(req.query.enrollment_id || req.query.enrollmentId);
    if (Number.isFinite(enrollmentId) && enrollmentId > 0) {
      enrollment = await req.propertyDb.models.sales_scheme_customers.findOne({
        where: {
          id: enrollmentId,
          outlet_id,
          scheme_id: schemeId,
        },
      });
    }

    if (!enrollment) {
      const lookupIdentity = normalizeCustomerIdentity(req.query);
      enrollment = await findSchemeEnrollment(req, schemeId, lookupIdentity);
    }

    if (!enrollment) {
      return res.status(404).json({ success: false, message: 'Customer not enrolled in this scheme' });
    }
    const identity = normalizeCustomerIdentity(enrollment);

    const progress = await computeCycleProgress({
      req,
      scheme,
      enrollment,
      asOfDate,
    });
    if (!progress) {
      return res.status(400).json({ success: false, message: 'Unable to compute cycle window' });
    }

    const days = await loadCycleWindowDetails({
      req,
      scheme,
      enrollment,
      identity,
      progress,
      asOfDate,
    });

    res.json({
      success: true,
      data: {
        scheme,
        enrollment,
        progress,
        days,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};

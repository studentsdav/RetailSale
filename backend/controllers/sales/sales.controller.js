const audit = require('../../services/audit.service');
const { insertLedger } = require('../../services/stockLedger.service');
const { createLedgerEntry, recalculateLedgerBalances } = require('../../services/cashLedger.service');
const { applyLoyaltyOnCompletedSale } = require('../../services/loyalty.service');
const { Op, fn, col, where: sqlWhere } = require('sequelize');
const numberingHelper = require('../inventory/numberingSettingsV2.controller');
const { normalizeDateKey } = require('../../utils/dateQuery');

const resolveOutletId = async (req) => {
    const rawId = req.body?.outlet_id || req.body?.outletCode || req.body?.outlet_code || 
                  req.query?.outlet_id || req.query?.outletCode || req.query?.outlet_code ||
                  req.user?.outlet_code || req.user?.outlet_id;
    if (!rawId) return null;

    let resolvedId = null;
    if (typeof rawId === 'string' && isNaN(Number(rawId))) {
        const outlet = await req.propertyDb.models.outlets.findOne({
            where: { outlet_code: rawId }
        });
        if (outlet) resolvedId = outlet.id;
    } else {
        const num = Number(rawId);
        if (Number.isInteger(num)) resolvedId = num;
    }

    if (resolvedId) {
        if (!req.user) req.user = {};
        req.user.outlet_id = resolvedId;
        const { contextStorage } = require('../../utils/context');
        const store = contextStorage.getStore();
        if (store) {
            store.set('outlet_id', resolvedId);
        }
    }
    return resolvedId;
};

function normalizeCustomerIdentity(header = {}) {
    let phone = String(header.customer_phone || '').replace(/\D/g, '').trim();
    if (phone.length > 10) {
        phone = phone.slice(-10);
    }
    return {
        // Keep digits-only for stable matching across UI formats like "+91 98..." / "098..." / "98-...".
        customer_phone: phone,
        customer_gstin: String(header.customer_gstin || '').trim().toUpperCase(),
        customer_name: String(header.customer_name || '').trim()
    };
}

function buildCustomerScope(identity = {}) {
    if (identity.customer_phone) {
        const phone = String(identity.customer_phone).replace(/\D/g, '').trim();
        const last10 = phone.length > 10 ? phone.slice(-10) : phone;
        return {
            customer_phone: {
                [Op.in]: [last10, `91${last10}`, `+91${last10}`, `0${last10}`]
            }
        };
    }
    if (identity.customer_gstin) {
        return { customer_gstin: identity.customer_gstin };
    }
    if (identity.customer_name) {
        return { customer_name: identity.customer_name };
    }
    return null;
}

function dateOnly(value) {
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) return null;
    return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

function formatDateLocalYmd(value) {
    const d = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(d.getTime())) return null;
    const offsetMs = 5.5 * 60 * 60 * 1000;
    const ist = new Date(d.getTime() + offsetMs);
    const y = ist.getUTCFullYear();
    const m = String(ist.getUTCMonth() + 1).padStart(2, '0');
    const day = String(ist.getUTCDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
}

function dateOnlyString(value) {
    return formatDateLocalYmd(dateOnly(value));
}

function addDays(date, days) {
    const d = new Date(date);
    d.setDate(d.getDate() + Number(days || 0));
    return d;
}

function sameDate(a, b) {
    const da = dateOnly(a);
    const db = dateOnly(b);
    if (!da || !db) return false;
    return da.getTime() === db.getTime();
}

function toRoundedAmount(value) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? Number(parsed.toFixed(2)) : 0;
}

function isFreeBillRow(row = {}) {
    return row.is_scheme_free === true ||
        row.is_advance_free === true ||
        row._subscription_free === true;
}

function incrementSaleNo(saleNo) {
    const raw = String(saleNo || '').trim();
    if (!raw) return raw;

    const match = raw.match(/^(.*?)(\d+)([^0-9]*)$/);
    if (!match) {
        return `${raw}-2`;
    }

    const prefix = match[1] || '';
    const numeric = match[2] || '0';
    const postfix = match[3] || '';
    const width = numeric.length;
    const nextValue = String(Number(numeric) + 1).padStart(width, '0');
    return `${prefix}${nextValue}${postfix}`;
}

function buildDraftSaleNo() {
    return `DRAFT-${Date.now()}`;
}

function encodePaymentReferenceFromLines(lines = []) {
    const normalized = (Array.isArray(lines) ? lines : [])
        .map((row) => ({
            method: String(row.method || '').trim().toUpperCase(),
            amount: toAmount(row.amount)
        }))
        .filter((row) => row.method && row.amount > 0);
    return `POSPAY:${JSON.stringify(normalized)}`;
}

function decodePaymentReferenceLines(rawReference) {
    const raw = String(rawReference || '').trim();
    if (!raw.startsWith('POSPAY:')) return [];
    try {
        const parsed = JSON.parse(raw.substring(7));
        if (!Array.isArray(parsed)) return [];
        return parsed
            .map((row) => ({
                method: String(row?.method || '').trim().toUpperCase(),
                amount: toAmount(row?.amount)
            }))
            .filter((row) => row.method && row.amount > 0);
    } catch (_) {
        return [];
    }
}

function calculateTaxesForAmount({
    taxMode,
    taxType,
    taxPercent,
    taxableAmount
}) {
    if (taxMode === 'NONE' || taxPercent <= 0 || taxableAmount <= 0) {
        return [];
    }

    const normalizedType = String(taxType || 'GST').trim().toUpperCase();
    const taxAmount = taxableAmount * taxPercent / 100;

    switch (normalizedType) {
        case 'VAT':
            return [
                {
                    code: 'VAT',
                    label: `VAT ${taxPercent % 1 === 0 ? taxPercent.toFixed(0) : taxPercent.toFixed(2)}%`,
                    taxType: 'VAT',
                    tax_type: 'VAT',
                    rate: taxPercent,
                    taxableAmount,
                    taxAmount,
                    tax_amount: taxAmount,
                    taxable_amount: taxableAmount
                }
            ];
        case 'CESS':
            return [
                {
                    code: 'CESS',
                    label: `CESS ${taxPercent % 1 === 0 ? taxPercent.toFixed(0) : taxPercent.toFixed(2)}%`,
                    taxType: 'CESS',
                    tax_type: 'CESS',
                    rate: taxPercent,
                    taxableAmount,
                    taxAmount,
                    tax_amount: taxAmount,
                    taxable_amount: taxableAmount
                }
            ];
        case 'OTHER':
        case 'CUSTOM':
            return [
                {
                    code: 'CUSTOM',
                    label: `Custom Tax ${taxPercent % 1 === 0 ? taxPercent.toFixed(0) : taxPercent.toFixed(2)}%`,
                    taxType: 'CUSTOM',
                    tax_type: 'CUSTOM',
                    rate: taxPercent,
                    taxableAmount,
                    taxAmount,
                    tax_amount: taxAmount,
                    taxable_amount: taxableAmount
                }
            ];
        case 'GST':
        default:
            if (taxMode === 'IGST') {
                return [
                    {
                        code: 'IGST',
                        label: `IGST ${taxPercent % 1 === 0 ? taxPercent.toFixed(0) : taxPercent.toFixed(2)}%`,
                        taxType: 'GST',
                        tax_type: 'GST',
                        rate: taxPercent,
                        taxableAmount,
                        taxAmount,
                        tax_amount: taxAmount,
                        taxable_amount: taxableAmount
                    }
                ];
            }
            if (taxMode === 'VAT') {
                return [
                    {
                        code: 'VAT',
                        label: `VAT ${taxPercent % 1 === 0 ? taxPercent.toFixed(0) : taxPercent.toFixed(2)}%`,
                        taxType: 'VAT',
                        tax_type: 'VAT',
                        rate: taxPercent,
                        taxableAmount,
                        taxAmount,
                        tax_amount: taxAmount,
                        taxable_amount: taxableAmount
                    }
                ];
            }

            const halfRate = taxPercent / 2;
            const halfAmount = taxAmount / 2;
            return [
                {
                    code: 'CGST',
                    label: `CGST ${halfRate % 1 === 0 ? halfRate.toFixed(0) : halfRate.toFixed(2)}%`,
                    taxType: 'GST',
                    tax_type: 'GST',
                    rate: halfRate,
                    taxableAmount,
                    taxAmount: halfAmount,
                    tax_amount: halfAmount,
                    taxable_amount: taxableAmount
                },
                {
                    code: 'SGST',
                    label: `SGST ${halfRate % 1 === 0 ? halfRate.toFixed(0) : halfRate.toFixed(2)}%`,
                    taxType: 'GST',
                    tax_type: 'GST',
                    rate: halfRate,
                    taxableAmount,
                    taxAmount: halfAmount,
                    tax_amount: halfAmount,
                    taxable_amount: taxableAmount
                }
            ];
    }
}

function normalizeTaxBreakupEntry(entry = {}) {
    const code = String(entry.code || entry.tax_code || entry.label || '').trim().toUpperCase();
    const label = String(entry.label || code || '').trim();
    const taxType = String(entry.taxType || entry.tax_type || 'GST').trim().toUpperCase() || 'GST';
    const rate = toAmount(entry.rate);
    const taxableAmount = toAmount(
        entry.taxableAmount ?? entry.taxable_amount ?? entry.taxable ?? 0
    );
    const taxAmount = toAmount(
        entry.taxAmount ?? entry.tax_amount ?? entry.amount ?? entry.tax ?? 0
    );

    return {
        code: code || 'GST',
        label: label || code || 'GST',
        taxType,
        tax_type: taxType,
        rate,
        taxableAmount,
        taxable_amount: taxableAmount,
        taxAmount,
        tax_amount: taxAmount
    };
}

function buildTaxCompliantFreeRow(row, itemMeta, taxMode) {
    const qty = toAmount(row.qty);
    const resolvedRate = toAmount(
        row.scheme_free_reference_rate ??
        row.reference_rate ??
        row.original_rate ??
        row._scheme_source_rate ??
        row.item_rate ??
        itemMeta?.retail_sale_price ??
        itemMeta?.rate ??
        row.rate
    );
    const taxType = String(
        row.original_tax_type ??
        row.tax_type ??
        itemMeta?.tax_type ??
        'GST'
    ).trim().toUpperCase() || 'GST';
    const taxPercent = toAmount(
        row.original_tax_percent ??
        row.tax_percent ??
        itemMeta?.tax_percent ??
        0
    );
    const grossAmount = qty * resolvedRate;
    const taxBreakup = calculateTaxesForAmount({
        taxMode,
        taxType,
        taxPercent,
        taxableAmount: grossAmount
    });
    const taxAmount = taxBreakup.reduce((sum, entry) => sum + toAmount(entry.taxAmount), 0);
    const lineTotal = grossAmount + taxAmount;

    return {
        ...row,
        rate: resolvedRate,
        tax_type: taxType,
        tax_percent: taxPercent,
        discount_applicable: false,
        scheme_applicable: false,
        line_discount: 0,
        amount: grossAmount,
        taxable_amount: grossAmount,
        tax_amount: taxAmount,
        line_total: lineTotal,
        tax_breakup: taxBreakup,
        net_amount: lineTotal,
        is_scheme_free: row.is_scheme_free === true,
        is_advance_free: row.is_advance_free === true,
        _subscription_free: row._subscription_free === true || row.is_advance_free === true,
        applied_scheme_id: null
    };
}

function normalizeSchemeMode(value, fallback, allowed) {
    const normalized = String(value || '').trim().toUpperCase();
    return allowed.includes(normalized) ? normalized : fallback;
}

function normalizeUsageType(value, fallback = 'reusable') {
    const normalized = String(value || '').trim().toLowerCase();
    return normalized === 'single_use' ? 'single_use' : fallback;
}

function normalizeSelectedSchemes(selectedSchemes) {
    if (!Array.isArray(selectedSchemes)) return [];
    return selectedSchemes
        .map((scheme) => {
            if (!scheme) return null;
            if (typeof scheme === 'string') {
                const label = scheme.trim();
                if (!label) return null;
                return {
                    id: null,
                    scheme_type: 'CUSTOM',
                    scheme_name: label,
                    scheme_value: 0,
                    bonus_qty: 0,
                    discount_amount: 0,
                    notes: null,
                    usage_type: 'reusable'
                };
            }

            const schemeType = String(
                scheme.scheme_type || scheme.type || scheme.schemeType || 'CUSTOM'
            ).trim().toUpperCase();
            const schemeName = String(
                scheme.scheme_name || scheme.label || scheme.name || schemeType
            ).trim();
            const schemeId = Number(scheme.id ?? scheme.scheme_id ?? scheme.schemeId);

            return {
                id: Number.isFinite(schemeId) && schemeId > 0 ? schemeId : null,
                scheme_type: schemeType || 'CUSTOM',
                scheme_name: schemeName || schemeType || 'CUSTOM',
                scheme_value: toRoundedAmount(scheme.scheme_value ?? scheme.value ?? 0),
                bonus_qty: toRoundedAmount(scheme.bonus_qty ?? scheme.bonusQty ?? 0),
                discount_amount: toRoundedAmount(
                    scheme.discount_amount ?? scheme.discountAmount ?? 0
                ),
                notes: scheme.notes ?? null,
                usage_type: normalizeUsageType(scheme.usage_type ?? scheme.usageType)
            };
        })
        .filter(Boolean);
}

function selectedSchemeIdentity(header = {}) {
    return normalizeCustomerIdentity(header);
}

function buildSchemeCustomerScope(identity = {}) {
    return buildCustomerScope(identity);
}

async function getConsumedSingleUseSchemeIds(req, identity) {
    const scope = buildSchemeCustomerScope(identity);
    if (!scope) return new Set();

    const rows = await req.propertyDb.models.sales_scheme_customers.findAll({
        where: {
            outlet_id: req.user.outlet_id,
            is_consumed: true,
            usage_type: 'single_use',
            ...scope
        },
        attributes: ['scheme_id']
    });

    return new Set(
        rows
            .map((row) => Number(row.scheme_id))
            .filter((value) => Number.isFinite(value) && value > 0)
    );
}

async function markSingleUseSchemesAsConsumed({
    req,
    header,
    selectedSchemes,
    appliedSchemeIds = [],
    transaction
}) {
    const identity = selectedSchemeIdentity(header);
    const scope = buildSchemeCustomerScope(identity);
    if (!scope) return;

    const selectedSchemeIds = [
        ...new Set(
            (Array.isArray(selectedSchemes) ? selectedSchemes : [])
                .map((scheme) => Number(scheme?.id ?? scheme?.scheme_id ?? scheme?.schemeId))
                .filter((value) => Number.isFinite(value) && value > 0)
        )
    ];
    const appliedIds = [
        ...new Set(
            (Array.isArray(appliedSchemeIds) ? appliedSchemeIds : [])
                .map((value) => Number(value))
                .filter((value) => Number.isFinite(value) && value > 0)
        )
    ];
    if (!selectedSchemeIds.length || !appliedIds.length) return;
    const toConsumeIds = selectedSchemeIds.filter((id) => appliedIds.includes(id));
    if (!toConsumeIds.length) return;

    const schemeRows = await req.propertyDb.models.sales_schemes.findAll({
        where: {
            outlet_id: req.user.outlet_id,
            id: { [Op.in]: toConsumeIds }
        },
        attributes: ['id', 'repeat_mode']
    });
    const oneTimeByConfig = new Set(
        schemeRows
            .filter(
                (row) => String(row.repeat_mode || '').toUpperCase() === 'ONCE'
            )
            .map((row) => Number(row.id))
            .filter((value) => Number.isFinite(value) && value > 0)
    );

    const rows = await req.propertyDb.models.sales_scheme_customers.findAll({
        where: {
            outlet_id: req.user.outlet_id,
            scheme_id: { [Op.in]: toConsumeIds },
            is_active: true,
            ...scope
        },
        attributes: ['id', 'scheme_id', 'usage_type', 'is_consumed']
    });

    const singleUseSchemeIds = [
        ...new Set(
            rows
                .filter(
                    (row) =>
                        (normalizeUsageType(row.usage_type, 'reusable') === 'single_use' ||
                            oneTimeByConfig.has(Number(row.scheme_id))) &&
                        row.is_consumed !== true
                )
                .map((row) => Number(row.scheme_id))
                .filter((value) => Number.isFinite(value) && value > 0)
        )
    ];
    if (!singleUseSchemeIds.length) return;

    await req.propertyDb.models.sales_scheme_customers.update(
        {
            is_consumed: true,
            is_active: false
        },
        {
            where: {
                outlet_id: req.user.outlet_id,
                scheme_id: { [Op.in]: singleUseSchemeIds },
                is_active: true,
                ...scope
            },
            transaction
        }
    );
}

function collectAppliedSchemeIds(header = {}, items = []) {
    const ids = new Set();
    for (const row of Array.isArray(items) ? items : []) {
        const schemeId = Number(row?.applied_scheme_id);
        if (Number.isFinite(schemeId) && schemeId > 0) {
            ids.add(schemeId);
        }
    }

    const headerSchemeId = Number(header.scheme_id);
    const headerSchemeDiscount = toAmount(header.scheme_discount);
    const headerSchemeUsageMode = String(
        header.scheme_usage_mode || 'APPLY_NOW'
    ).toUpperCase();
    if (
        Number.isFinite(headerSchemeId) &&
        headerSchemeId > 0 &&
        headerSchemeDiscount > 0 &&
        headerSchemeUsageMode === 'APPLY_NOW'
    ) {
        ids.add(headerSchemeId);
    }

    return Array.from(ids);
}

function buildCustomerOrConditions(identity = {}) {
    const conditions = [];
    if (identity.customer_phone) {
        const phone = String(identity.customer_phone).replace(/\D/g, '').trim();
        const last10 = phone.length > 10 ? phone.slice(-10) : phone;
        conditions.push({
            customer_phone: {
                [Op.in]: [last10, `91${last10}`, `+91${last10}`, `0${last10}`]
            }
        });
    }
    if (identity.customer_gstin) {
        conditions.push({
            customer_gstin: {
                [Op.iLike]: String(identity.customer_gstin).trim()
            }
        });
    }
    if (identity.customer_name) {
        conditions.push({
            customer_name: {
                [Op.iLike]: String(identity.customer_name).trim()
            }
        });
    }
    return conditions;
}

function customerDisplayName(identity = {}) {
    return identity.customer_name || identity.customer_phone || identity.customer_gstin || 'Walk-in Customer';
}

async function getActiveMilkSubscriptions(req, identity, itemId = null, asOfDate = new Date()) {
    const asOfDay = formatDateLocalYmd(asOfDate);
    const where = {
        outlet_id: req.user.outlet_id,
        status: 'ACTIVE',
        active_subscription: true,
        start_date: { [Op.lte]: asOfDay },
        end_date: { [Op.gte]: asOfDay }
    };

    const customerFilters = buildCustomerOrConditions(identity);
    if (customerFilters.length) {
        where[Op.or] = customerFilters;
    } else {
        return [];
    }

    if (itemId !== null && Number.isFinite(Number(itemId))) {
        where.item_id = Number(itemId);
    }

    return req.propertyDb.models.milk_subscriptions.findAll({
        where,
        include: [
            { model: req.propertyDb.models.item_master, as: 'item', required: false },
            { model: req.propertyDb.models.milk_subscription_schemes, as: 'schemes', required: false }
        ],
        order: [['start_date', 'DESC'], ['end_date', 'DESC'], ['id', 'DESC']]
    });
}

async function getSubscriptionConsumedQtyForDay(
    req,
    subscriptionId,
    txnDate,
    transaction = undefined,
    itemId = null
) {
    const [rows] = await req.propertyDb.query(
        `
SELECT COALESCE(SUM(covered_qty), 0) AS covered_qty
FROM milk_subscription_consumptions
WHERE subscription_id = :subscription_id
  AND txn_date = :txn_date
  ${Number.isFinite(Number(itemId)) && Number(itemId) > 0 ? 'AND item_id = :item_id' : ''}
  AND status <> 'CANCELLED'
        `,
        {
            replacements: {
                subscription_id: subscriptionId,
                txn_date: formatDateLocalYmd(txnDate),
                item_id: Number.isFinite(Number(itemId)) && Number(itemId) > 0
                    ? Number(itemId)
                    : undefined
            },
            transaction
        }
    );
    const consumedQty = toRoundedAmount(rows?.[0]?.covered_qty);
    if (consumedQty > 0) {
        return consumedQty;
    }

    const [fallbackRows] = await req.propertyDb.query(
        `
SELECT COALESCE(SUM(si.qty), 0) AS covered_qty
FROM sales_headers sh
INNER JOIN sales_items si
    ON si.sale_id = sh.id
WHERE sh.notes ILIKE :subscription_note
  AND sh.sale_date::date = :txn_date
  AND COALESCE(sh.is_deleted, FALSE) = FALSE
  ${Number.isFinite(Number(itemId)) && Number(itemId) > 0 ? 'AND si.item_id = :item_id' : ''}
        `,
        {
            replacements: {
                subscription_note: `%[SUBSCRIPTION_AUTO] subscription_id=${subscriptionId}%`,
                txn_date: formatDateLocalYmd(txnDate),
                item_id: Number.isFinite(Number(itemId)) && Number(itemId) > 0
                    ? Number(itemId)
                    : undefined
            },
            transaction
        }
    );

    return toRoundedAmount(fallbackRows?.[0]?.covered_qty);
}

async function getPendingCustomerItemReservedQtyForDay(
    req,
    identity,
    itemId,
    txnDate,
    transaction = undefined,
    options = {}
) {
    const normalizedItemId = Number(itemId) || 0;
    if (normalizedItemId <= 0) return 0;

    const normalizedIdentity = normalizeCustomerIdentity(identity || {});
    const whereCustomer = buildCustomerScope(normalizedIdentity);
    if (!whereCustomer) return 0;

    const pendingOrders = await req.propertyDb.models.customer_orders.findAll({
        where: {
            outlet_id: req.user.outlet_id,
            status: 'PENDING',
            ...whereCustomer
        },
        attributes: ['id', 'created_at', 'items'],
        order: [['created_at', 'ASC'], ['id', 'ASC']],
        transaction
    });

    if (!pendingOrders.length) return 0;

    const cutoffOrderId = Number(options?.excludeOrderId) || 0;
    const cutoffCreatedAt = options?.beforeCreatedAt ? new Date(options.beforeCreatedAt) : null;
    let reservedQty = 0;

    for (const order of pendingOrders) {
        const orderId = Number(order.id) || 0;
        if (cutoffOrderId > 0 && orderId === cutoffOrderId) {
            continue;
        }

        if (cutoffCreatedAt) {
            const createdAt = order.created_at ? new Date(order.created_at) : null;
            if (!createdAt) continue;
            if (createdAt > cutoffCreatedAt) continue;
            if (createdAt.getTime() === cutoffCreatedAt.getTime() && cutoffOrderId > 0 && orderId >= cutoffOrderId) {
                continue;
            }
        }

        for (const row of Array.isArray(order.items) ? order.items : []) {
            if (Number(row?.item_id) !== normalizedItemId) continue;
            reservedQty += toRoundedAmount(row?.qty);
        }
    }

    return toRoundedAmount(reservedQty);
}

async function getCustomerItemConsumedQtyForDay(
    req,
    identity,
    itemId,
    txnDate,
    transaction = undefined,
    options = {}
) {
    const normalizedItemId = Number(itemId) || 0;
    if (normalizedItemId <= 0) return 0;

    const normalizedIdentity = normalizeCustomerIdentity(identity || {});
    const whereCustomer = buildCustomerScope(normalizedIdentity);
    if (!whereCustomer) return 0;

    const params = {
        outlet_id: req.user.outlet_id,
        item_id: normalizedItemId,
        txn_date: formatDateLocalYmd(txnDate)
    };

    let customerWhere = '';
    if (normalizedIdentity.customer_phone) {
        customerWhere = 'AND ms.customer_phone IN (:phone_last10, :phone_91, :phone_plus91, :phone_0)';
        params.phone_last10 = normalizedIdentity.customer_phone;
        params.phone_91 = `91${normalizedIdentity.customer_phone}`;
        params.phone_plus91 = `+91${normalizedIdentity.customer_phone}`;
        params.phone_0 = `0${normalizedIdentity.customer_phone}`;
    } else if (normalizedIdentity.customer_gstin) {
        customerWhere = 'AND ms.customer_gstin = :customer_gstin';
        params.customer_gstin = normalizedIdentity.customer_gstin;
    } else if (normalizedIdentity.customer_name) {
        customerWhere = 'AND ms.customer_name = :customer_name';
        params.customer_name = normalizedIdentity.customer_name;
    }

    const [rows] = await req.propertyDb.query(
        `
SELECT COALESCE(SUM(c.covered_qty), 0) AS covered_qty
FROM milk_subscription_consumptions c
JOIN milk_subscriptions ms
  ON ms.id = c.subscription_id
 AND ms.outlet_id = c.outlet_id
WHERE c.outlet_id = :outlet_id
  AND c.item_id = :item_id
  AND c.txn_date = :txn_date
  AND c.status <> 'CANCELLED'
  ${customerWhere}
        `,
        { replacements: params, transaction }
    );
    const consumedQty = toRoundedAmount(rows?.[0]?.covered_qty);
    const pendingReservedQty = await getPendingCustomerItemReservedQtyForDay(
        req,
        normalizedIdentity,
        normalizedItemId,
        txnDate,
        transaction,
        options
    );
    if (consumedQty > 0 || pendingReservedQty > 0) {
        return consumedQty + pendingReservedQty;
    }

    let customerWhereFallback = '';
    const fallbackParams = {
        outlet_id: req.user.outlet_id,
        item_id: normalizedItemId,
        txn_date: formatDateLocalYmd(txnDate),
        subscription_note: '%[SUBSCRIPTION_AUTO]%'
    };
    if (normalizedIdentity.customer_phone) {
        customerWhereFallback = 'AND sh.customer_phone IN (:phone_last10, :phone_91, :phone_plus91, :phone_0)';
        fallbackParams.phone_last10 = normalizedIdentity.customer_phone;
        fallbackParams.phone_91 = `91${normalizedIdentity.customer_phone}`;
        fallbackParams.phone_plus91 = `+91${normalizedIdentity.customer_phone}`;
        fallbackParams.phone_0 = `0${normalizedIdentity.customer_phone}`;
    } else if (normalizedIdentity.customer_gstin) {
        customerWhereFallback = 'AND sh.customer_gstin = :customer_gstin';
        fallbackParams.customer_gstin = normalizedIdentity.customer_gstin;
    } else if (normalizedIdentity.customer_name) {
        customerWhereFallback = 'AND sh.customer_name = :customer_name';
        fallbackParams.customer_name = normalizedIdentity.customer_name;
    }

    const [fallbackRows] = await req.propertyDb.query(
        `
SELECT COALESCE(SUM(si.qty), 0) AS covered_qty
FROM sales_headers sh
INNER JOIN sales_items si
    ON si.sale_id = sh.id
WHERE sh.outlet_id = :outlet_id
  AND sh.sale_date::date = :txn_date
  AND COALESCE(sh.is_deleted, FALSE) = FALSE
  AND sh.notes ILIKE :subscription_note
  AND si.item_id = :item_id
  ${customerWhereFallback}
        `,
        {
            replacements: fallbackParams,
            transaction
        }
    );

    return toRoundedAmount(fallbackRows?.[0]?.covered_qty) + pendingReservedQty;
}

async function loadSubscriptionConsumptionRows(req, subscription, transaction = undefined) {
    const consumedRows = await req.propertyDb.models.milk_subscription_consumptions.findAll({
        where: {
            subscription_id: subscription.id,
            status: { [Op.ne]: 'CANCELLED' }
        },
        order: [['txn_date', 'ASC'], ['id', 'ASC']],
        transaction
    });

    if (consumedRows.length > 0) {
        return consumedRows;
    }

    const autoSales = await req.propertyDb.models.sales_headers.findAll({
        where: {
            outlet_id: req.user.outlet_id,
            is_deleted: false,
            notes: {
                [Op.iLike]: `%[SUBSCRIPTION_AUTO] subscription_id=${subscription.id}%`
            }
        },
        include: [
            {
                model: req.propertyDb.models.sales_items,
                as: 'items',
                required: false
            }
        ],
        order: [['sale_date', 'ASC'], ['id', 'ASC']],
        transaction
    });

    const fallbackRows = [];
    for (const sale of autoSales) {
        const saleJson = sale.toJSON();
        const saleDate = saleJson.sale_date ? formatDateLocalYmd(saleJson.sale_date) : formatDateLocalYmd(new Date());
        for (const item of Array.isArray(saleJson.items) ? saleJson.items : []) {
            const coveredQty = toAmount(item.qty);
            if (coveredQty <= 0) continue;
            const rate = toAmount(item.rate);
            const netAmount = toAmount(item.net_amount || item.line_total);
            fallbackRows.push(
                req.propertyDb.models.milk_subscription_consumptions.build(
                    {
                        outlet_id: req.user.outlet_id,
                        subscription_id: subscription.id,
                        sale_id: saleJson.id,
                        sale_no: saleJson.sale_no,
                        txn_date: saleDate,
                        item_id: item.item_id,
                        item_name: item.item_name || subscription.item_name || '',
                        cart_qty: coveredQty,
                        covered_qty: coveredQty,
                        excess_qty: 0,
                        daily_allowed_qty: toAmount(subscription.daily_allowed_qty),
                        rate,
                        covered_amount: netAmount || (coveredQty * rate),
                        excess_amount: 0,
                        settlement_id: null,
                        status: 'CONSUMED',
                        created_by: saleJson.created_by || subscription.created_by || req.user.id
                    },
                    { isNewRecord: false }
                )
            );
        }
    }

    return fallbackRows;
}

async function allocateMilkSubscriptionCoverage({ req, header, items, transaction, pendingOrderContext = null }) {
    const identity = normalizeCustomerIdentity(header);
    const saleDate = header.sale_date || new Date();
    const saleDateKey = formatDateLocalYmd(saleDate);
    const updatedItems = [];
    const consumptionRows = [];
    let totalCoveredAmount = 0;
    let totalCoveredQty = 0;
    let subscriptionId = 0;
    let subscriptionItemId = 0;
    const inFlightConsumedByKey = new Map();
    const subscriptionCoveragesByKey = new Map();

    const addSubscriptionCoverage = (subscription, itemId, coveredQty, coveredAmount) => {
        const key = `${subscription.id}_${itemId}`;
        const existing = subscriptionCoveragesByKey.get(key) || {
            subscriptionId: subscription.id,
            subscriptionItemId: subscription.item_id,
            itemId,
            totalCoveredQty: 0,
            totalCoveredAmount: 0
        };
        existing.totalCoveredQty += coveredQty;
        existing.totalCoveredAmount += coveredAmount;
        subscriptionCoveragesByKey.set(key, existing);
        return existing;
    };

    for (const sourceRow of Array.isArray(items) ? items : []) {
        const itemId = Number(sourceRow.item_id) || 0;
        const qty = toAmount(sourceRow.qty);
        const alreadyFree =
            sourceRow.is_advance_free === true ||
            sourceRow.is_scheme_free === true ||
            toAmount(sourceRow.rate) <= 0;
        if (alreadyFree) {
            updatedItems.push(sourceRow);
            continue;
        }
        if (itemId <= 0 || qty <= 0) {
            updatedItems.push(sourceRow);
            continue;
        }

        const subscriptions = await getActiveMilkSubscriptions(req, identity, itemId, saleDate);
        if (!subscriptions.length) {
            updatedItems.push(sourceRow);
            continue;
        }

        const rate = toAmount(sourceRow.rate);
        let remainingQty = qty;
        let sourceCoveredQty = 0;
        let sourceCoveredAmount = 0;
        let sourceSubscriptionId = 0;
        let sourceSubscriptionItemId = 0;
        let sourceItemName = sourceRow.item_name || '';

        for (const subscription of subscriptions) {
            if (remainingQty <= 0) break;

            const subscriptionAdvance = await findSubscriptionItemAdvance(
                req,
                subscription.id,
                itemId,
                transaction
            );
            const dailyLimit = toAmount(subscription.daily_allowed_qty);
            const usageKey = `${subscription.id}_${itemId}_${saleDateKey}`;
            const consumedTodayFromDb = await getSubscriptionConsumedQtyForDay(
                req,
                subscription.id,
                saleDate,
                transaction,
                itemId
            );
            const inFlightConsumed = toAmount(inFlightConsumedByKey.get(usageKey) || 0);
            const consumedToday = consumedTodayFromDb + inFlightConsumed;
            const remainingCoverage = Math.max(dailyLimit - consumedToday, 0);
            const coveredQty = Math.min(remainingQty, remainingCoverage);
            if (coveredQty <= 0) {
                continue;
            }

            const agreedRate = rate > 0 ? rate : toAmount(subscriptionAdvance?.rate || 0);
            const preTaxAmount = coveredQty * agreedRate;
            const taxPercent = toAmount(sourceRow.tax_percent || 0);
            const taxAmount = preTaxAmount * taxPercent / 100.0;
            const coveredAmount = preTaxAmount + taxAmount;
            remainingQty -= coveredQty;
            sourceCoveredQty += coveredQty;
            sourceCoveredAmount += coveredAmount;
            sourceSubscriptionId = sourceSubscriptionId || subscription.id;
            sourceSubscriptionItemId = sourceSubscriptionItemId || subscription.item_id;
            sourceItemName = sourceItemName || subscription.item_name || '';
            subscriptionId = subscriptionId || subscription.id;
            subscriptionItemId = subscriptionItemId || subscription.item_id;
            totalCoveredAmount += coveredAmount;
            totalCoveredQty += coveredQty;
            addSubscriptionCoverage(subscription, itemId, coveredQty, coveredAmount);
            inFlightConsumedByKey.set(usageKey, inFlightConsumed + coveredQty);

            updatedItems.push({
                ...sourceRow,
                qty: coveredQty,
                reference_rate: agreedRate || rate,
                rate: 0,
                tax_percent: parseFloat(sourceRow.tax_percent || 0.0),
                discount_applicable: false,
                scheme_applicable: false,
                line_discount: 0,
                amount: 0,
                taxable_amount: 0,
                tax_amount: 0,
                line_total: 0,
                tax_breakup: [],
                net_amount: 0,
                is_scheme_free: true,
                _subscription_free: true,
                applied_scheme_id: null
            });
            consumptionRows.push({
                outlet_id: req.user.outlet_id,
                subscription_id: subscription.id,
                txn_date: saleDateKey,
                item_id: itemId,
                item_name: sourceItemName,
                cart_qty: coveredQty,
                covered_qty: coveredQty,
                excess_qty: 0,
                daily_allowed_qty: dailyLimit,
                rate: agreedRate,
                covered_amount: coveredAmount,
                excess_amount: 0,
                status: 'CONSUMED',
                created_by: req.user.id
            });
        }

        if (remainingQty > 0) {
            updatedItems.push({
                ...sourceRow,
                qty: remainingQty
            });
            consumptionRows.push({
                outlet_id: req.user.outlet_id,
                subscription_id: sourceSubscriptionId || subscriptions[0].id,
                txn_date: saleDateKey,
                item_id: itemId,
                item_name: sourceItemName,
                cart_qty: qty,
                covered_qty: sourceCoveredQty,
                excess_qty: remainingQty,
                daily_allowed_qty: toAmount((subscriptions[0] || {}).daily_allowed_qty),
                rate,
                covered_amount: sourceCoveredAmount,
                excess_amount: remainingQty * rate,
                status: 'PENDING',
                created_by: req.user.id
            });
        }
    }

    return {
        items: updatedItems,
        consumptions: consumptionRows,
        totalCoveredAmount,
        totalCoveredQty,
        subscriptionId,
        subscriptionItemId,
        subscriptionCoverages: Array.from(subscriptionCoveragesByKey.values())
    };
}

async function collectPreSplitSubscriptionAllocation({ req, header, items, transaction }) {
    const identity = normalizeCustomerIdentity(header);
    const saleDate = header.sale_date || new Date();
    const saleDateKey = formatDateLocalYmd(saleDate);
    const sourceItems = Array.isArray(items) ? items : [];
    const byItem = new Map();
    const coveredSubscriptionItemIds = new Set();
    const consumptionRows = [];
    let totalCoveredAmount = 0;
    let totalCoveredQty = 0;
    let subscriptionId = 0;
    let subscriptionItemId = 0;
    const inFlightConsumedByKey = new Map();
    const subscriptionCoveragesByKey = new Map();
    const addSubscriptionCoverage = (subscription, itemId, coveredQty, coveredAmount) => {
        const key = `${subscription.id}_${itemId}`;
        const existing = subscriptionCoveragesByKey.get(key) || {
            subscriptionId: subscription.id,
            subscriptionItemId: subscription.item_id,
            itemId,
            totalCoveredQty: 0,
            totalCoveredAmount: 0
        };
        existing.totalCoveredQty += coveredQty;
        existing.totalCoveredAmount += coveredAmount;
        subscriptionCoveragesByKey.set(key, existing);
        return existing;
    };

    for (const row of sourceItems) {
        const itemId = Number(row.item_id) || 0;
        if (itemId <= 0) continue;
        const qty = toAmount(row.qty);
        if (qty <= 0) continue;
        const bucket = byItem.get(itemId) || {
            itemId,
            itemName: row.item_name || '',
            cartQty: 0,
            freeQty: 0,
            rate: 0,
            taxPercent: toAmount(row.tax_percent || 0)
        };
        bucket.cartQty += qty;
        if (row.is_advance_free === true) {
            bucket.freeQty += qty;
        } else if (toAmount(row.rate) > 0) {
            bucket.rate = toAmount(row.rate);
        }
        byItem.set(itemId, bucket);
    }

    for (const bucket of byItem.values()) {
        if (bucket.freeQty <= 0) continue;
        const subscriptions = await getActiveMilkSubscriptions(
            req,
            identity,
            bucket.itemId,
            saleDate
        );
        if (!subscriptions.length) {
            const globalSubscriptions = await req.propertyDb.models.milk_subscriptions.findAll({
                where: {
                    status: 'ACTIVE',
                    active_subscription: true,
                    item_id: bucket.itemId,
                    start_date: { [Op.lte]: saleDateKey },
                    end_date: { [Op.gte]: saleDateKey }
                }
            });
            const matchingGlobal = globalSubscriptions.filter((row) => {
                const rowIdentity = normalizeCustomerIdentity(row.toJSON());
                const samePhone = identity.customer_phone && rowIdentity.customer_phone
                    ? identity.customer_phone === rowIdentity.customer_phone
                    : false;
                const sameGstin = identity.customer_gstin && rowIdentity.customer_gstin
                    ? identity.customer_gstin === rowIdentity.customer_gstin
                    : false;
                const sameName = identity.customer_name && rowIdentity.customer_name
                    ? identity.customer_name.toLowerCase() === rowIdentity.customer_name.toLowerCase()
                    : false;
                return samePhone || sameGstin || sameName;
            });

            if (matchingGlobal.length > 0) {
                const targetOutlet = await req.propertyDb.models.outlets.findByPk(matchingGlobal[0].outlet_id);
                const currentOutlet = await req.propertyDb.models.outlets.findByPk(req.user.outlet_id);
                const err = new Error(
                    `No active subscription found for free item "${bucket.itemName || 'Subscription item'}" at current outlet: ${currentOutlet?.outlet_name || req.user.outlet_id}. However, an active subscription was found at outlet: ${targetOutlet?.outlet_name || matchingGlobal[0].outlet_id}. Subscriptions are only valid at the outlet where they are subscribed.`
                );
                err.status = 400;
                throw err;
            } else {
                const err = new Error(
                    `No active subscription found for free item "${bucket.itemName || 'Subscription item'}" for this customer.`
                );
                err.status = 400;
                throw err;
            }
        }

        let chosenSubscription = null;
        let coveredQty = 0;
        let dailyLimit = 0;
        let agreedRate = 0;
        let subscriptionAdvance = null;
        let usageKey = '';

        for (const subscription of subscriptions) {
            subscriptionAdvance = await findSubscriptionItemAdvance(
                req,
                subscription.id,
                bucket.itemId,
                transaction
            );
            dailyLimit = toAmount(subscription.daily_allowed_qty);
            usageKey = `${subscription.id}_${bucket.itemId}_${saleDateKey}`;
            const consumedTodayFromDb = await getSubscriptionConsumedQtyForDay(
                req,
                subscription.id,
                saleDate,
                transaction,
                bucket.itemId
            );
            const inFlightConsumed = toAmount(inFlightConsumedByKey.get(usageKey) || 0);
            const consumedToday = consumedTodayFromDb + inFlightConsumed;
            const remainingCoverage = Math.max(dailyLimit - consumedToday, 0);
            if (remainingCoverage <= 0) continue;

            chosenSubscription = subscription;
            agreedRate = toAmount(bucket.rate) > 0
                ? toAmount(bucket.rate)
                : toAmount(subscriptionAdvance?.rate || 0);
            coveredQty = Math.min(bucket.freeQty, remainingCoverage);
            break;
        }

        if (!chosenSubscription || coveredQty <= 0) {
            const left = '0.00';
            const err = new Error(
                `${bucket.itemName || 'Subscription item'} daily free limit already used. Remaining free qty today: ${left}`
            );
            err.status = 400;
            throw err;
        }

        const excessQty = Math.max(bucket.cartQty - coveredQty, 0);
        const taxPercent = bucket.taxPercent || 0;
        const preTaxAmount = coveredQty * agreedRate;
        const taxAmount = preTaxAmount * taxPercent / 100.0;
        const coveredAmount = preTaxAmount + taxAmount;
        if (coveredQty > 0) {
            inFlightConsumedByKey.set(usageKey, toAmount(inFlightConsumedByKey.get(usageKey) || 0) + coveredQty);
            addSubscriptionCoverage(chosenSubscription, bucket.itemId, coveredQty, coveredAmount);
        }

        totalCoveredAmount += coveredAmount;
        totalCoveredQty += coveredQty;
        subscriptionId = subscriptionId || chosenSubscription.id;
        subscriptionItemId = subscriptionItemId || chosenSubscription.item_id;
        coveredSubscriptionItemIds.add(Number(bucket.itemId));

        consumptionRows.push({
            outlet_id: req.user.outlet_id,
            subscription_id: chosenSubscription.id,
            txn_date: saleDateKey,
            item_id: bucket.itemId,
            item_name: bucket.itemName || chosenSubscription.item_name || '',
            cart_qty: bucket.cartQty,
            covered_qty: coveredQty,
            excess_qty: excessQty,
            daily_allowed_qty: dailyLimit,
            rate: agreedRate,
            covered_amount: coveredAmount,
            excess_amount: excessQty * toAmount(bucket.rate || agreedRate),
            status: 'PENDING',
            created_by: req.user.id
        });
    }

    const normalizedItems = sourceItems.map((row) => {
        const itemId = Number(row?.item_id) || 0;
        if (row?.is_advance_free === true && coveredSubscriptionItemIds.has(itemId)) {
            return {
                ...row,
                is_advance_free: true,
                is_scheme_free: true,
                _subscription_free: true
            };
        }
        return row;
    });

    return {
        items: normalizedItems,
        consumptions: consumptionRows,
        totalCoveredAmount,
        totalCoveredQty,
        subscriptionId,
        subscriptionItemId,
        subscriptionCoverages: Array.from(subscriptionCoveragesByKey.values())
    };
}

function sumNumeric(rows, field) {
    return (rows || []).reduce((sum, row) => sum + toAmount(row[field]), 0);
}

function diffDaysInclusive(startDate, endDate) {
    const start = dateOnly(startDate);
    const end = dateOnly(endDate);
    if (!start || !end || end < start) return 0;
    return Math.floor((end.getTime() - start.getTime()) / (24 * 60 * 60 * 1000)) + 1;
}

function buildSubscriptionMetrics(subscription, consumptions = []) {
    const cleanedRows = (Array.isArray(consumptions) ? consumptions : [])
        .filter((row) => String(row.status || '').toUpperCase() !== 'CANCELLED');
    const totalDays = diffDaysInclusive(subscription?.start_date, subscription?.end_date);
    const today = dateOnly(new Date());
    const endDay = dateOnly(subscription?.end_date);
    const activeDays = new Set();
    let consumedQty = 0;
    let consumedValue = 0;
    let lastPositiveRate = 0;

    for (const row of cleanedRows) {
        const txnDate = row.txn_date ? formatDateLocalYmd(row.txn_date) : null;
        const coveredQty = toAmount(row.covered_qty);
        const rate = toAmount(row.rate);
        if (txnDate && coveredQty > 0) {
            activeDays.add(txnDate);
        }
        consumedQty += coveredQty;
        const rowCoveredAmount = toAmount(row.covered_amount);
        consumedValue += rowCoveredAmount > 0 ? rowCoveredAmount : (coveredQty * rate);
        const effectiveRate = (rowCoveredAmount > 0 && coveredQty > 0) ? (rowCoveredAmount / coveredQty) : rate;
        if (effectiveRate > 0) {
            lastPositiveRate = effectiveRate;
        }
    }

    const bonusQty = toAmount(subscription?.bonus_qty);
    const discountAmount = sumNumeric(subscription?.schemes, 'discount_amount');
    const bonusValue = bonusQty * lastPositiveRate;
    const isDiscountEligible =
        (endDay && today && today.getTime() >= endDay.getTime()) ||
        subscription?.status !== 'ACTIVE' ||
        subscription?.active_subscription !== true;
    const appliedDiscountAmount = isDiscountEligible ? discountAmount : 0;
    const pendingDiscountAmount = Math.max(discountAmount - appliedDiscountAmount, 0);
    // `covered_qty` rows already represent what was consumed from subscription entitlement.
    // Do not subtract bonus value again here, otherwise outstanding can incorrectly become zero.
    const actualValue = Math.max(consumedValue - appliedDiscountAmount, 0);
    const prepaidValue = toAmount(subscription?.total_payment_amount);
    const balanceDelta = Number((actualValue - prepaidValue).toFixed(2));
    const creditedAmount = balanceDelta < 0 ? Math.abs(balanceDelta) : 0;
    const outstandingAmount = balanceDelta > 0 ? balanceDelta : 0;

    return {
        total_days: totalDays,
        consumed_days: activeDays.size,
        missed_days: Math.max(totalDays - activeDays.size, 0),
        days_left: today && endDay && endDay >= today ? diffDaysInclusive(today, endDay) : 0,
        consumed_qty: Number(consumedQty.toFixed(2)),
        actual_value: Number(actualValue.toFixed(2)),
        gross_covered_value: Number(consumedValue.toFixed(2)),
        prepaid_value: Number(prepaidValue.toFixed(2)),
        balance_delta: balanceDelta,
        credited_amount: creditedAmount,
        outstanding_amount: outstandingAmount,
        bonus_value: Number(bonusValue.toFixed(2)),
        discount_amount: Number(appliedDiscountAmount.toFixed(2)),
        discount_pending_amount: Number(pendingDiscountAmount.toFixed(2)),
        daily_breakdown: cleanedRows.map((row) => {
            const rowCoveredQty = toAmount(row.covered_qty);
            const rowCoveredAmount = toAmount(row.covered_amount);
            const displayRate = (rowCoveredAmount > 0 && rowCoveredQty > 0)
                ? parseFloat((rowCoveredAmount / rowCoveredQty).toFixed(2))
                : toAmount(row.rate);
            return {
                id: row.id,
                txn_date: row.txn_date,
                sale_id: row.sale_id,
                sale_no: row.sale_no,
                item_id: row.item_id,
                item_name: row.item_name,
                cart_qty: toAmount(row.cart_qty),
                covered_qty: rowCoveredQty,
                excess_qty: toAmount(row.excess_qty),
                rate: displayRate,
                covered_amount: rowCoveredAmount > 0 ? rowCoveredAmount : (rowCoveredQty * toAmount(row.rate)),
                status: row.status
            };
        })
    };
}

function getSubscriptionReferenceNo(subscriptionId) {
    return `SUBSCRIPTION-${subscriptionId}`;
}

function buildManualAdvanceExclusionClause(alias = '') {
    const prefix = alias ? `${alias}.` : '';
    return `AND COALESCE(${prefix}note, '') NOT ILIKE 'Subscription #% prepaid qty%'`;
}

async function findSubscriptionItemAdvance(req, subscriptionId, itemId, transaction = undefined) {
    return req.propertyDb.models.customer_item_advances.findOne({
        where: {
            outlet_id: req.user.outlet_id,
            item_id: itemId,
            [Op.or]: [
                { source_sale_id: subscriptionId },
                { note: { [Op.iLike]: `%Subscription #${subscriptionId}%` } }
            ]
        },
        transaction
    });
}

async function consumeSubscriptionItemAdvance(req, subscriptionId, itemId, qty, transaction = undefined) {
    const delta = toAmount(qty);
    if (delta <= 0) return null;

    const advance = await findSubscriptionItemAdvance(req, subscriptionId, itemId, transaction);
    if (!advance) return null;

    const currentAvailable = toAmount(advance.available_qty);
    const nextAvailable = Math.max(currentAvailable - delta, 0);

    await advance.update(
        {
            available_qty: nextAvailable,
            updated_by: req.user.id
        },
        { transaction }
    );

    return advance;
}

async function getSubscriptionItemAdvanceSummary(req, subscription, transaction = undefined) {
    const itemId = Number(subscription?.item_id) || 0;
    if (itemId <= 0) {
        return {
            original_qty: 0,
            consumed_qty: 0,
            available_qty: 0,
            rate: 0,
            original_amount: 0,
            consumed_amount: 0,
            available_amount: 0
        };
    }

    const advance = await findSubscriptionItemAdvance(
        req,
        subscription.id,
        itemId,
        transaction
    );

    if (!advance) {
        return {
            original_qty: 0,
            consumed_qty: 0,
            available_qty: 0,
            rate: 0,
            original_amount: 0,
            consumed_amount: 0,
            available_amount: 0
        };
    }

    const originalQty = toAmount(advance.original_qty);
    const availableQty = toAmount(advance.available_qty);
    const consumedQty = Math.max(originalQty - availableQty, 0);
    const rate = toAmount(advance.rate);

    return {
        original_qty: Number(originalQty.toFixed(2)),
        consumed_qty: Number(consumedQty.toFixed(2)),
        available_qty: Number(availableQty.toFixed(2)),
        rate: Number(rate.toFixed(2)),
        original_amount: Number((originalQty * rate).toFixed(2)),
        consumed_amount: Number((consumedQty * rate).toFixed(2)),
        available_amount: Number((availableQty * rate).toFixed(2))
    };
}

async function findSubscriptionCustomerAdvance(req, subscriptionId, transaction = undefined) {
    return req.propertyDb.models.customer_advances.findOne({
        where: {
            outlet_id: req.user.outlet_id,
            [Op.or]: [
                { source_sale_id: subscriptionId },
                { reference_no: getSubscriptionReferenceNo(subscriptionId) }
            ]
        },
        transaction
    });
}

async function consumeSubscriptionCustomerAdvance(
    req,
    subscriptionId,
    amount,
    transaction = undefined
) {
    const delta = toAmount(amount);
    if (delta <= 0) return null;

    const advance = await findSubscriptionCustomerAdvance(req, subscriptionId, transaction);
    if (!advance) return null;

    const currentAvailable = toAmount(advance.available_amount);
    const nextAvailable = Math.max(currentAvailable - delta, 0);

    await advance.update(
        {
            available_amount: nextAvailable,
            updated_by: req.user.id
        },
        { transaction }
    );

    return advance;
}

async function addSubscriptionCustomerAdvance(
    req,
    subscription,
    amount,
    paymentMode,
    note,
    settlementDate,
    transaction = undefined
) {
    const delta = toAmount(amount);
    if (delta <= 0) return null;

    const advance = await findSubscriptionCustomerAdvance(req, subscription.id, transaction);
    if (advance) {
        await advance.update(
            {
                original_amount: toAmount(advance.original_amount) + delta,
                available_amount: toAmount(advance.available_amount) + delta,
                payment_mode: paymentMode || advance.payment_mode,
                note: note || advance.note,
                updated_by: req.user.id
            },
            { transaction }
        );
        return advance;
    }

    return req.propertyDb.models.customer_advances.create(
        {
            outlet_id: req.user.outlet_id,
            source_sale_id: null,
            customer_name: subscription.customer_name || null,
            customer_phone: subscription.customer_phone || null,
            customer_gstin: subscription.customer_gstin || null,
            advance_date: settlementDate || new Date(),
            original_amount: delta,
            available_amount: delta,
            payment_mode: paymentMode || 'CASH',
            reference_no: getSubscriptionReferenceNo(subscription.id),
            note: note || `Additional customer advance for subscription ${subscription.id}`,
            created_by: req.user.id,
            updated_by: req.user.id
        },
        { transaction }
    );
}

async function getSubscriptionCustomerAdvanceSummary(req, subscription, transaction = undefined) {
    const advance = await findSubscriptionCustomerAdvance(req, subscription.id, transaction);
    if (!advance) {
        return {
            original_amount: 0,
            consumed_amount: 0,
            available_amount: 0
        };
    }

    const originalAmount = toAmount(advance.original_amount);
    const availableAmount = toAmount(advance.available_amount);
    const consumedAmount = Math.max(originalAmount - availableAmount, 0);

    return {
        original_amount: Number(originalAmount.toFixed(2)),
        consumed_amount: Number(consumedAmount.toFixed(2)),
        available_amount: Number(availableAmount.toFixed(2))
    };
}

async function buildSubscriptionFinancialSummary(req, subscription, consumptions, transaction = undefined) {
    const metrics = buildSubscriptionMetrics(subscription, consumptions);
    const cashAdvanceSummary = await getSubscriptionCustomerAdvanceSummary(req, subscription, transaction);
    const grossOutstanding = Math.max(toAmount(metrics.outstanding_amount), 0);
    const availableAdvance = Math.max(toAmount(cashAdvanceSummary.available_amount), 0);
    const customerAdvanceUsed = Math.min(grossOutstanding, availableAdvance);
    const netOutstanding = Math.max(grossOutstanding - customerAdvanceUsed, 0);

    return {
        ...metrics,
        gross_outstanding_amount: Number(grossOutstanding.toFixed(2)),
        customer_advance_used: Number(customerAdvanceUsed.toFixed(2)),
        outstanding_amount: Number(netOutstanding.toFixed(2))
    };
}

async function buildSubscriptionLedgerResponse(req, subscriptionId) {
    const subscription = await req.propertyDb.models.milk_subscriptions.findOne({
        where: {
            id: subscriptionId,
            outlet_id: req.user.outlet_id
        },
        include: [
            { model: req.propertyDb.models.item_master, as: 'item', required: false },
            { model: req.propertyDb.models.milk_subscription_schemes, as: 'schemes', required: false }
        ]
    });

    if (!subscription) return null;

    const consumptions = await loadSubscriptionConsumptionRows(req, subscription);

    const settlements = await req.propertyDb.models.milk_subscription_settlements.findAll({
        where: {
            outlet_id: req.user.outlet_id,
            subscription_id: subscription.id
        },
        order: [['settlement_date', 'ASC'], ['id', 'ASC']]
    });

    return {
        subscription,
        consumptions,
        settlements
    };
}

async function getSubscriptionSchemeTotals(subscription) {
    const schemeRows = Array.isArray(subscription?.schemes) ? subscription.schemes : [];
    const bonusQty = schemeRows.reduce((sum, row) => sum + toAmount(row.bonus_qty), 0);
    const discountAmount = schemeRows.reduce((sum, row) => sum + toAmount(row.discount_amount), 0);
    return { bonusQty, discountAmount };
}

async function persistMilkSubscriptionConsumptions({ req, transaction, sale, consumptions }) {
    if (!Array.isArray(consumptions) || consumptions.length === 0) {
        return;
    }

    for (const row of consumptions) {
        await req.propertyDb.models.milk_subscription_consumptions.create(
            {
                ...row,
                sale_id: sale.id,
                sale_no: sale.sale_no
            },
            { transaction }
        );
    }
}

async function getActiveItemCycleSchemes(req) {
    return req.propertyDb.models.sales_schemes.findAll({
        where: {
            outlet_id: req.user.outlet_id,
            is_active: true,
            scheme_scope: 'ITEM',
            scheme_type: 'CYCLE_ITEM_FREE'
        }
    });
}

async function findSchemeEnrollment(req, schemeId, identity) {
    const scope = buildCustomerScope(identity);
    if (!scope) return null;
    return req.propertyDb.models.sales_scheme_customers.findOne({
        where: {
            outlet_id: req.user.outlet_id,
            scheme_id: schemeId,
            is_active: true,
            ...scope
        }
    });
}

async function ensureCustomerSchemeEnrollments({
    req,
    transaction,
    header,
    selectedSchemes = []
}) {
    const identity = normalizeCustomerIdentity(header);
    const scope = buildCustomerScope(identity);
    if (!scope) return;

    const candidateIds = [
        ...new Set(
            [
                Number(header?.scheme_id),
                ...(Array.isArray(selectedSchemes)
                    ? selectedSchemes.map((scheme) =>
                        Number(scheme?.id ?? scheme?.scheme_id ?? scheme?.schemeId)
                    )
                    : [])
            ].filter((value) => Number.isFinite(value) && value > 0)
        )
    ];
    if (!candidateIds.length) return;

    const schemes = await req.propertyDb.models.sales_schemes.findAll({
        where: {
            id: { [Op.in]: candidateIds },
            outlet_id: req.user.outlet_id,
            is_active: true
        },
        transaction
    });

    for (const scheme of schemes) {
        const existingEnrollment = await findSchemeEnrollment(req, scheme.id, identity);
        if (existingEnrollment) continue;
        await req.propertyDb.models.sales_scheme_customers.create(
            {
                outlet_id: req.user.outlet_id,
                scheme_id: scheme.id,
                customer_name: identity.customer_name || null,
                customer_phone: identity.customer_phone || null,
                customer_gstin: identity.customer_gstin || null,
                start_date: header.sale_date || new Date(),
                usage_type:
                    String(scheme.repeat_mode || '').toUpperCase() === 'ONCE'
                        ? 'single_use'
                        : 'reusable',
                is_consumed: false,
                is_active: true,
                created_by: req.user.id
            },
            { transaction }
        );
    }
}

async function computeItemCycleProgress({
    req,
    scheme,
    enrollment,
    identity,
    billDate,
    currentBillItems = []
}) {
    const startDate = enrollment?.start_date ? new Date(enrollment.start_date) : null;
    const today = dateOnly(billDate) || dateOnly(new Date());
    const cycleDays = Math.max(1, Number(scheme.cycle_days) || 30);
    const itemId = Number(scheme.item_id);

    if (!startDate || !today || !Number.isFinite(itemId)) {
        return null;
    }

    const start = dateOnly(startDate);
    const diffMs = today.getTime() - start.getTime();
    const diffDays = Math.floor(diffMs / (24 * 60 * 60 * 1000));
    const cycleIndex = diffDays >= 0 ? Math.floor(diffDays / cycleDays) : 0;
    const cycleStart = addDays(start, cycleIndex * cycleDays);
    const cycleEnd = addDays(cycleStart, cycleDays - 1);

    const dateToCheck = today < cycleEnd ? today : cycleEnd;

    const whereCustomer = buildCustomerScope(identity);
    const params = {
        outlet_id: req.user.outlet_id,
        item_id: itemId,
        // Use local date strings; toISOString() shifts day in IST/timezones.
        from_day: formatDateLocalYmd(cycleStart),
        to_day: formatDateLocalYmd(dateToCheck)
    };

    let customerWhere = "";
    if (whereCustomer?.customer_phone) {
        customerWhere = "AND sh.customer_phone = :customer_phone";
        params.customer_phone = whereCustomer.customer_phone;
    } else if (whereCustomer?.customer_gstin) {
        customerWhere = "AND sh.customer_gstin = :customer_gstin";
        params.customer_gstin = whereCustomer.customer_gstin;
    } else if (whereCustomer?.customer_name) {
        customerWhere = "AND sh.customer_name = :customer_name";
        params.customer_name = whereCustomer.customer_name;
    }

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
  ${customerWhere}
GROUP BY DATE(sh.sale_date)
ORDER BY sale_day ASC
        `,
        { replacements: params }
    );

    const daily = new Map();
    for (const row of rows || []) {
        const d = row.sale_day instanceof Date ? row.sale_day : new Date(row.sale_day);
        const key = formatDateLocalYmd(dateOnly(d));
        daily.set(key, Number(row.qty) || 0);
    }

    // Include current bill items for today (before saving this bill).
    const currentQty = currentBillItems
        .filter((it) => Number(it.item_id) === itemId)
        .reduce((sum, it) => sum + (Number(it.qty) || 0), 0);
    if (currentQty > 0) {
        const key = formatDateLocalYmd(today);
        daily.set(key, (daily.get(key) || 0) + currentQty);
    }

    let consumedDays = 0;
    let billedQty = 0;
    for (const qty of daily.values()) {
        if (qty > 0) consumedDays += 1;
        billedQty += qty;
    }

    const minQty = Number(scheme.min_qty) || 0;
    const freeQty = Number(scheme.free_qty) || 0;
    const requiredDailyQty = Number(scheme.required_daily_qty) || freeQty;
    const missingDays = [];
    for (let d = new Date(cycleStart); d <= dateToCheck; d = addDays(d, 1)) {
        const key = formatDateLocalYmd(dateOnly(d));
        const dayQty = daily.get(key) || 0;
        if (requiredDailyQty > 0) {
            if (dayQty < requiredDailyQty) {
                missingDays.push(key);
            }
        } else if (dayQty <= 0) {
            missingDays.push(key);
        }
    }

    const totalRequiredQty = requiredDailyQty > 0 ? requiredDailyQty * cycleDays : minQty;
    let qualifiedDays = 0;
    for (const qty of daily.values()) {
        if (requiredDailyQty > 0) {
            if (qty >= requiredDailyQty) qualifiedDays += 1;
        } else if (qty > 0) {
            qualifiedDays += 1;
        }
    }

    return {
        cycle_start: formatDateLocalYmd(cycleStart),
        cycle_end: formatDateLocalYmd(cycleEnd),
        cycle_days: cycleDays,
        is_cycle_end_day: sameDate(today, cycleEnd),
        item_id: itemId,
        min_qty: minQty,
        free_qty: freeQty,
        required_daily_qty: requiredDailyQty,
        required_total_qty: totalRequiredQty,
        total_qty: billedQty,
        consumed_qty: billedQty,
        qualified_days: qualifiedDays,
        remaining_qty: Math.max(totalRequiredQty - billedQty, 0),
        missing_days: missingDays,
        require_no_gaps: !!scheme.require_no_gaps
    };
}

async function hasSchemeGrantedToday({
    req,
    schemeId,
    itemId,
    identity,
    billDate
}) {
    const day = formatDateLocalYmd(dateOnly(billDate || new Date()));
    if (!day) return false;
    const [rows] = await req.propertyDb.query(
        `
SELECT 1
FROM sales_headers sh
JOIN sales_items si ON si.sale_id = sh.id
WHERE sh.outlet_id = :outlet_id
  AND sh.status = 'COMPLETED'
  AND sh.is_latest = TRUE
  AND sh.is_deleted = FALSE
  AND DATE(sh.sale_date) = :sale_day
  AND si.item_id = :item_id
  AND si.is_scheme_free = TRUE
  AND si.applied_scheme_id = :scheme_id
  AND (
    (:customer_phone <> '' AND sh.customer_phone = :customer_phone)
    OR (:customer_gstin <> '' AND sh.customer_gstin = :customer_gstin)
    OR (:customer_name <> '' AND sh.customer_name = :customer_name)
  )
LIMIT 1
        `,
        {
            replacements: {
                outlet_id: req.user.outlet_id,
                sale_day: day,
                item_id: itemId,
                scheme_id: schemeId,
                customer_phone: identity.customer_phone || '',
                customer_gstin: identity.customer_gstin || '',
                customer_name: identity.customer_name || ''
            }
        }
    );
    return (rows || []).length > 0;
}

async function applyItemCycleSchemesToSale({ req, header, items, transaction }) {
    const recomputeRowTotals = (row, nextQty) => {
        const qty = toAmount(nextQty);
        const rate = toAmount(row.rate);
        const prevQty = toAmount(row.qty);
        const prevLineDiscount = toAmount(row.line_discount);
        const unitDiscount = prevQty > 0 ? prevLineDiscount / prevQty : 0;
        const amount = qty * rate;
        const lineDiscount = Math.min(amount, unitDiscount * qty);
        const taxPercent = toAmount(row.tax_percent);
        const taxableAmount = Math.max(amount - lineDiscount, 0);
        const taxAmount = taxableAmount * taxPercent / 100;
        const lineTotal = taxableAmount + taxAmount;
        return {
            ...row,
            qty,
            line_discount: lineDiscount,
            amount,
            taxable_amount: taxableAmount,
            tax_amount: taxAmount,
            line_total: lineTotal,
            net_amount: lineTotal
        };
    };

    const identity = normalizeCustomerIdentity(header);
    const allSchemes = await getActiveItemCycleSchemes(req);
    const selectedSchemeId = Number(header.scheme_id);
    const selectedSchemeIdsFromHeader = normalizeSelectedSchemes(
        header.selected_schemes || header.selectedSchemes
    )
        .map((scheme) => Number(scheme?.id))
        .filter((value) => Number.isFinite(value) && value > 0);
    const targetSchemeIds = [
        ...new Set(
            [
                ...(Number.isFinite(selectedSchemeId) && selectedSchemeId > 0
                    ? [selectedSchemeId]
                    : []),
                ...selectedSchemeIdsFromHeader
            ]
        )
    ];
    const schemes = targetSchemeIds.length
        ? allSchemes.filter((s) => targetSchemeIds.includes(Number(s.id)))
        : [];
    if (!schemes.length) return items;

    const billDate = header.sale_date || new Date();
    const today = dateOnly(billDate);
    if (!today) return items;

    const updated = Array.isArray(items) ? [...items] : [];

    for (const scheme of schemes) {
        const itemId = Number(scheme.item_id);
        const freeQty = Number(scheme.free_qty) || 0;
        const requiredDailyQty = Number(scheme.required_daily_qty) || freeQty;
        const minQty = Number(scheme.min_qty) || 0;
        const applyTiming = String(scheme.apply_timing || 'CURRENT_BILL').toUpperCase();
        const usageMode = String(header.scheme_usage_mode || 'APPLY_NOW').toUpperCase();
        const repeatMode = String(scheme.repeat_mode || 'REPEAT').toUpperCase();
        if (!Number.isFinite(itemId) || freeQty <= 0) continue;

        // Must have the scheme item on the bill to apply free qty.
        const hasSchemeItemOnBill = updated.some(
            (row) => Number(row.item_id) === itemId && (Number(row.qty) || 0) > 0
        );
        if (!hasSchemeItemOnBill) continue;
        const alreadyHasAdvanceFreeForItem = updated.some(
            (row) => Number(row.item_id) === itemId && row.is_advance_free === true
        );
        if (alreadyHasAdvanceFreeForItem) continue;

        let enrollment = await findSchemeEnrollment(req, scheme.id, identity);
        // If user explicitly selected this ITEM scheme on the bill, auto-enroll (start = bill day)
        // so the scheme starts working without extra steps.
        if (!enrollment && Number.isFinite(selectedSchemeId) && selectedSchemeId > 0) {
            const scope = buildCustomerScope(identity);
            if (scope) {
                enrollment = await req.propertyDb.models.sales_scheme_customers.create({
                    outlet_id: req.user.outlet_id,
                    scheme_id: scheme.id,
                    customer_name: identity.customer_name || null,
                    customer_phone: identity.customer_phone || null,
                    customer_gstin: identity.customer_gstin || null,
                    start_date: today,
                    usage_type: repeatMode === 'ONCE' ? 'single_use' : 'reusable',
                    is_consumed: false,
                    is_active: true,
                    created_by: req.user.id
                });
            }
        }
        if (!enrollment) continue;

        const progress = await computeItemCycleProgress({
            req,
            scheme,
            enrollment,
            identity,
            billDate,
            currentBillItems: updated
        });
        if (!progress) continue;

        const alreadyGrantedThisCycle =
            String(enrollment.last_applied_cycle_start || '') ===
            String(progress.cycle_start || '') &&
            String(enrollment.last_applied_cycle_end || '') ===
            String(progress.cycle_end || '');
        if (alreadyGrantedThisCycle) continue;

        // NEXT_PURCHASE mode should reserve on current purchase and apply on a future bill.
        if (applyTiming === 'NEXT_PURCHASE' && usageMode !== 'APPLY_NOW') continue;

        if (scheme.require_no_gaps && progress.missing_days.length > 0) continue;
        const effectiveMinQty =
            minQty > 0 ? minQty : (requiredDailyQty > 0 ? requiredDailyQty : freeQty);
        if (effectiveMinQty > 0 && progress.total_qty < effectiveMinQty) {
            continue;
        }

        const alreadyGrantedToday = await hasSchemeGrantedToday({
            req,
            schemeId: scheme.id,
            itemId,
            identity,
            billDate
        });
        if (alreadyGrantedToday) continue;

        let appliedFreeQty = 0;
        const alreadyHasFreeLine = updated.some(
            (row) =>
                Number(row.item_id) === itemId &&
                (row.is_scheme_free === true || String(row.line_note || '').includes('SCHEME_FREE'))
        );
        if (alreadyHasFreeLine) continue;

        // Apply free qty as a rate=0 line based on bill quantity and threshold.
        const billItemQty = updated
            .filter((row) =>
                Number(row.item_id) === itemId &&
                (Number(row.qty) || 0) > 0 &&
                row.is_scheme_free !== true &&
                row.is_advance_free !== true
            )
            .reduce((sum, row) => sum + (Number(row.qty) || 0), 0);
        const eligibleFreeQty = Math.min(freeQty, billItemQty);
        if (eligibleFreeQty <= 0) continue;

        let remainingFree = eligibleFreeQty;
        for (let i = 0; i < updated.length && remainingFree > 0; i++) {
            const row = updated[i];
            if (Number(row.item_id) !== itemId) continue;
            if (row.is_scheme_free === true) continue;
            if (row.is_advance_free === true) continue;

            const rowQty = Number(row.qty) || 0;
            if (rowQty <= 0) continue;

            const take = Math.min(remainingFree, rowQty);
            if (take <= 0) continue;

            const freeRow = {
                ...row,
                qty: take,
                _scheme_source_rate: toAmount(row.rate),
                rate: 0,
                tax_percent: 0,
                discount_applicable: false,
                scheme_applicable: false,
                line_discount: 0,
                amount: 0,
                taxable_amount: 0,
                tax_amount: 0,
                line_total: 0,
                tax_breakup: [],
                net_amount: 0,
                is_scheme_free: true,
                applied_scheme_id: scheme.id
            };

            if (take >= rowQty - 1e-9) {
                updated[i] = freeRow;
            } else {
                updated[i] = recomputeRowTotals(row, rowQty - take);
                updated.splice(i + 1, 0, freeRow);
                i++; // skip the inserted free line
            }
            appliedFreeQty += take;

            remainingFree -= take;
        }

        if (appliedFreeQty > 0) {
            await enrollment.update(
                {
                    last_applied_cycle_start: dateOnlyString(progress.cycle_start),
                    last_applied_cycle_end: dateOnlyString(progress.cycle_end)
                },
                { transaction }
            );
        }
    }

    return updated;
}

async function allocateItemAdvanceConsumption({ req, header, items, transaction }) {
    const identity = normalizeCustomerIdentity(header);
    const scope = buildCustomerScope(identity);
    if (!scope) {
        return { items, advanceAppliedAmount: 0 };
    }

    const updatedItems = Array.isArray(items)
        ? items.map((row) => ({
            ...row,
            item_advance_qty: 0,
            item_advance_amount: 0
        }))
        : [];
    const itemIds = [...new Set(updatedItems.map((row) => Number(row.item_id)).filter((value) => Number.isFinite(value) && value > 0))];
    if (!itemIds.length) {
        return { items: updatedItems, advanceAppliedAmount: 0 };
    }

    const advanceRows = await req.propertyDb.models.customer_item_advances.findAll({
        where: {
            outlet_id: req.user.outlet_id,
            item_id: { [Op.in]: itemIds },
            available_qty: { [Op.gt]: 0 },
            ...scope
        },
        order: [['item_id', 'ASC'], ['advance_date', 'ASC'], ['id', 'ASC']],
        transaction
    });

    const advancePools = new Map();
    for (const row of advanceRows) {
        const itemId = Number(row.item_id) || 0;
        if (!advancePools.has(itemId)) advancePools.set(itemId, []);
        advancePools.get(itemId).push(row);
    }

    let advanceAppliedAmount = 0;
    for (const item of updatedItems) {
        if (item.is_scheme_free === true || item.is_advance_free === true) continue;
        const itemId = Number(item.item_id) || 0;
        const billQty = toAmount(item.qty);
        if (billQty <= 0) continue;

        const pools = advancePools.get(itemId) || [];
        let remainingQty = billQty;
        let itemAdvanceQty = 0;
        let itemAdvanceAmount = 0;

        for (const advanceRow of pools) {
            if (remainingQty <= 0) break;
            const availableQty = toAmount(advanceRow.available_qty);
            if (availableQty <= 0) continue;

            const takeQty = Math.min(remainingQty, availableQty);
            if (takeQty <= 0) continue;

            const unitRate = toAmount(advanceRow.rate);
            const consumeAmount = takeQty * unitRate;

            itemAdvanceQty += takeQty;
            itemAdvanceAmount += consumeAmount;
            advanceAppliedAmount += consumeAmount;
            remainingQty -= takeQty;
            advanceRow.available_qty = Math.max(availableQty - takeQty, 0);
        }

        item.item_advance_qty = itemAdvanceQty;
        item.item_advance_amount = itemAdvanceAmount;
    }

    for (const advanceRow of advanceRows) {
        await advanceRow.update(
            { available_qty: advanceRow.available_qty },
            { transaction }
        );
    }

    return { items: updatedItems, advanceAppliedAmount };
}

function parseDateOnly(value) {
    if (!value) return null;
    const normalized = normalizeDateKey(value);
    if (normalized) {
        const date = new Date(`${normalized}T00:00:00`);
        if (!Number.isNaN(date.getTime())) {
            return date;
        }
    }
    let date;
    if (typeof value === 'string') {
        const trimmed = value.trim();
        const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(trimmed);
        if (match) {
            date = new Date(
                Number(match[1]),
                Number(match[2]) - 1,
                Number(match[3])
            );
        } else {
            date = new Date(trimmed);
        }
    } else {
        date = new Date(value);
    }
    if (Number.isNaN(date.getTime())) return null;
    date.setHours(0, 0, 0, 0);
    return date;
}

function toWholeNumber(value, fallback = 1) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) return fallback;
    return Math.max(1, Math.round(parsed));
}

function toAmount(value, fallback = 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
}

function extractNumericPart(saleNo, setting) {
    if (!saleNo) return null;
    const prefix = setting?.prefix || '';
    const postfix = setting?.postfix || '';
    let value = String(saleNo);

    if (prefix && value.startsWith(prefix)) {
        value = value.slice(prefix.length);
    }
    if (postfix && value.endsWith(postfix)) {
        value = value.slice(0, value.length - postfix.length);
    }

    const numeric = parseInt(value, 10);
    return Number.isNaN(numeric) ? null : numeric;
}

async function getVoucherRules(req) {
    const settings = await req.propertyDb.models.system_settings.findOne({
        where: { outlet_id: req.user.outlet_id }
    });

    return Array.isArray(settings?.voucher_rules) ? settings.voucher_rules : [];
}

async function validateVoucherUsage(req, { code, orderAmount = 0, header = {}, ignoreSaleIds = [] }) {
    const rules = await getVoucherRules(req);
    const voucher = rules.find((entry) => String(entry.code || '').trim().toUpperCase() === code);

    if (!voucher) {
        return { valid: false, reason: 'INVALID', message: 'Voucher code is invalid.' };
    }

    const now = new Date();
    const validFrom = parseDateOnly(voucher.valid_from || voucher.validFrom);
    const validTo = parseDateOnly(voucher.valid_to || voucher.validTo);

    if (validFrom && now < validFrom) {
        return { valid: false, reason: 'NOT_STARTED', message: 'Voucher is not active yet.' };
    }

    if (validTo) {
        validTo.setHours(23, 59, 59, 999);
        if (now > validTo) {
            return { valid: false, reason: 'EXPIRED', message: 'Voucher has expired.' };
        }
    }

    const minimumPurchaseAmount = Number(voucher.minimum_purchase_amount ?? voucher.minimumPurchaseAmount) || 0;
    if (Number(orderAmount) < minimumPurchaseAmount) {
        return {
            valid: false,
            reason: 'MIN_PURCHASE',
            message: `Minimum purchase ${minimumPurchaseAmount.toFixed(2)} required.`
        };
    }

    const identity = normalizeCustomerIdentity(header);
    const lookupClauses = [];
    if (identity.customer_phone) lookupClauses.push({ customer_phone: identity.customer_phone });
    if (identity.customer_gstin) lookupClauses.push({ customer_gstin: identity.customer_gstin });
    if (identity.customer_name) lookupClauses.push({ customer_name: identity.customer_name });

    if (lookupClauses.length > 0) {
        const where = {
            outlet_id: req.user.outlet_id,
            voucher_code: code,
            status: 'COMPLETED',
            [Op.or]: lookupClauses
        };

        const idsToIgnore = ignoreSaleIds
            .map((value) => Number(value))
            .filter((value) => Number.isFinite(value) && value > 0);

        if (idsToIgnore.length > 0) {
            where.id = { [Op.notIn]: idsToIgnore };
        }

        const existing = await req.propertyDb.models.sales_headers.findOne({ where });
        if (existing) {
            return {
                valid: false,
                reason: 'ALREADY_USED',
                message: 'Voucher already used by this customer.'
            };
        }
    }

    return {
        valid: true,
        voucher: {
            code,
            label: voucher.label || code,
            discount_type: voucher.discount_type || voucher.discountType || 'AMOUNT',
            discount_value: Number(voucher.discount_value ?? voucher.discountValue) || 0,
            valid_from: voucher.valid_from || voucher.validFrom,
            valid_to: voucher.valid_to || voucher.validTo,
            minimum_purchase_amount: minimumPurchaseAmount
        }
    };
}

async function recordSalePayment({
    req,
    transaction,
    sale,
    header,
    paymentMode,
    amountPaid,
    netAmount,
    balanceDue,
    created_by
}) {
    if (sale.status !== 'COMPLETED') return;
    if (netAmount <= 0 && amountPaid <= 0 && balanceDue <= 0) return;
    const splitLines = decodePaymentReferenceLines(header.payment_reference);
    const nonCreditSplit = splitLines.filter((row) => row.method !== 'CREDIT');
    const hasUsableSplit = nonCreditSplit.length > 0;
    const paymentLines = hasUsableSplit
        ? nonCreditSplit
        : [{ method: paymentMode, amount: Math.min(amountPaid, netAmount) }];

    const changeAmount = toAmount(header.change_amount || sale?.change_amount || 0);
    let remainingChange = changeAmount;

    for (const line of paymentLines) {
        let lineAmount = line.amount;
        if (line.method === 'CASH' && remainingChange > 0) {
            const deduct = Math.min(lineAmount, remainingChange);
            lineAmount = toAmount(lineAmount - deduct);
            remainingChange = toAmount(remainingChange - deduct);
        }
        if (lineAmount <= 0) continue;

        await createLedgerEntry({
            db: req.propertyDb,
            outlet_id: req.user.outlet_id,
            txn_date: header.sale_date,
            transaction_type: paymentMode === 'CREDIT' || balanceDue > 0
                ? 'SALE_CREDIT'
                : 'SALE_CASH',
            reference_type: 'SALE',
            reference_id: sale.id,
            reference_no: sale.sale_no,
            party_name: header.customer_name || header.customer_phone || 'Walk-in Customer',
            payment_method: line.method,
            amount_in: lineAmount,
            notes: balanceDue > 0
                ? `Sale ${sale.sale_no} created with outstanding ${balanceDue.toFixed(2)}`
                : `Payment received for sale ${sale.sale_no}`,
            created_by,
            transaction
        });
    }

    if (!hasUsableSplit && balanceDue > 0) {
        await createLedgerEntry({
            db: req.propertyDb,
            outlet_id: req.user.outlet_id,
            txn_date: header.sale_date,
            transaction_type: 'SALE_CREDIT',
            reference_type: 'SALE',
            reference_id: sale.id,
            reference_no: sale.sale_no,
            party_name: header.customer_name || header.customer_phone || 'Walk-in Customer',
            payment_method: 'CREDIT',
            amount_in: 0,
            notes: `Sale ${sale.sale_no} created with outstanding ${balanceDue.toFixed(2)}`,
            created_by,
            transaction
        });
    }
}

async function recordSaleBenefitExpenseEntries({
    req,
    transaction,
    sale,
    header,
    paymentMode,
    created_by,
    discountAmount,
    schemeFreeQtyAmount,
    subscriptionAdjustmentAmount
}) {
    if (sale.status !== 'COMPLETED') return;

    const partyName =
        header.customer_name || header.customer_phone || 'Walk-in Customer';
    const normalizedDiscount = toAmount(discountAmount);
    const normalizedSchemeFree = toAmount(schemeFreeQtyAmount);
    const normalizedSubscriptionAdjustment = toAmount(subscriptionAdjustmentAmount);

    if (normalizedDiscount > 0) {
        await createLedgerEntry({
            db: req.propertyDb,
            outlet_id: req.user.outlet_id,
            txn_date: header.sale_date,
            transaction_type: 'SALE_DISCOUNT_EXPENSE',
            reference_type: 'SALE',
            reference_id: sale.id,
            reference_no: sale.sale_no,
            party_name: partyName,
            payment_method: paymentMode,
            amount_out: normalizedDiscount,
            notes: `Discount expense booked for sale ${sale.sale_no}`,
            created_by,
            transaction
        });
    }

    if (normalizedSchemeFree > 0) {
        await createLedgerEntry({
            db: req.propertyDb,
            outlet_id: req.user.outlet_id,
            txn_date: header.sale_date,
            transaction_type: 'SALE_SCHEME_FREE_EXPENSE',
            reference_type: 'SALE',
            reference_id: sale.id,
            reference_no: sale.sale_no,
            party_name: partyName,
            payment_method: paymentMode,
            amount_out: normalizedSchemeFree,
            notes: `Scheme free quantity expense booked for sale ${sale.sale_no}`,
            created_by,
            transaction
        });
    }

    // Avoid double-posting: subscription adjustments are booked via ADVANCE_APPLY
    // in the subscription allocation flow. Posting here again creates duplicate
    // debit lines for the same bill.

}

async function createSaleVersion({
    req,
    transaction,
    header,
    items,
    overrides = {},
    createPayment = true,
    stockTxnType = 'SALE',
    affectStock = true,
    invoiceDiscountAmount = 0
}) {
    const saleItems = Array.isArray(items) ? items : [];
    const status = header.status || 'COMPLETED';
    const voucherCode = String(header.voucher_code || '').trim().toUpperCase();
    const paymentMode = String(header.payment_mode || 'CASH').trim().toUpperCase();
    const roundOffAmount = toAmount(header.round_off_amount || 0);
    const netAmount = toAmount(header.net_amount);
    const invoiceDiscount = Math.max(0, toAmount(invoiceDiscountAmount));
    const amountPaid = toAmount(
        header.amount_paid ?? (paymentMode === 'CREDIT' ? 0 : netAmount)
    );
    const changeAmount = header.change_amount != null
        ? Math.max(toAmount(header.change_amount), 0)
        : (paymentMode === 'CASH' ? Math.max(amountPaid - netAmount, 0) : 0);
    const balanceDue = Math.max(netAmount - Math.min(amountPaid, netAmount), 0);
    const outlet_id = req.user.outlet_id;
    const created_by = req.user.id;
    const normalizedIdentity = normalizeCustomerIdentity(header);

    const itemIds = saleItems.map(row => Number(row?.item_id)).filter(id => Number.isFinite(id) && id > 0);
    const itemMasters = itemIds.length > 0 ? await req.propertyDb.models.item_master.findAll({
        where: {
            outlet_id,
            id: { [Op.in]: itemIds }
        },
        transaction
    }) : [];
    const itemMasterMap = new Map(itemMasters.map(item => [item.id, item]));

    let totalQty = 0;
    let subTotal = 0;
    let itemsTaxableTotal = 0;
    let itemsTaxTotal = 0;
    let itemsLineTotal = 0;
    const taxSummary = new Map();
    let schemeFreeQtyAmount = 0;
    let subscriptionAdjustmentAmount = 0;
    let advanceSubscriptionDiscount = 0;
    let subscriptionTaxCgst = 0;
    let subscriptionTaxSgst = 0;
    let subscriptionTaxIgst = 0;
    let subscriptionTaxableAmount = 0;

    const itemRateFallbackMap = new Map();
    for (const row of saleItems) {
        const itemId = Number(row?.item_id);
        const rowRate = toAmount(row?.rate);
        if (!Number.isFinite(itemId) || itemId <= 0) continue;
        if (row?.is_scheme_free === true || row?.is_advance_free === true) continue;
        if (rowRate <= 0) continue;
        if (!itemRateFallbackMap.has(itemId)) {
            itemRateFallbackMap.set(itemId, rowRate);
        }
    }

    const { calculateCommissionFields } = require('../../utils/commissionHelper');
    const baseAmount = toAmount(header.taxable_amount ?? header.sub_total ?? netAmount);
    const commFields = await calculateCommissionFields(
        req.propertyDb,
        header.sale_source || 'Store',
        baseAmount,
        netAmount,
        saleItems,
        transaction
    );

    const sale = await req.propertyDb.models.sales_headers.create({
        outlet_id,
        sale_no: header.sale_no,
        sale_date: header.sale_date,
        customer_name: normalizedIdentity.customer_name || null,
        customer_phone: normalizedIdentity.customer_phone || null,
        customer_address: header.customer_address || null,
        customer_gstin: normalizedIdentity.customer_gstin || null,
        payment_mode: paymentMode,
        payment_reference: header.payment_reference || null,
        initial_amount_paid: amountPaid,
        amount_paid: amountPaid,
        change_amount: changeAmount,
        balance_due: balanceDue,
        order_type: header.order_type || 'B2C',
        billing_country: header.billing_country || 'India',
        billing_tax_mode: header.billing_tax_mode || 'CGST_SGST',
        bill_format: header.bill_format || 'A4',
        sale_source: header.sale_source || 'Store',
        tax_percent: header.tax_percent || 0,
        scheme_id: header.scheme_id || null,
        scheme_name: header.scheme_name || null,
        scheme_discount: header.scheme_discount || 0,
        manual_discount_type: header.manual_discount_type || null,
        manual_discount_value: header.manual_discount_value || 0,
        manual_discount_amount: header.manual_discount_amount || 0,
        total_qty: 0,
        sub_total: 0,
        taxable_amount: header.taxable_amount || 0,
        cgst_amount: header.cgst_amount || 0,
        sgst_amount: header.sgst_amount || 0,
        igst_amount: header.igst_amount || 0,
        total_tax: header.total_tax || 0,
        tax_breakup: Array.isArray(header.tax_breakup) ? header.tax_breakup : [],
        charges: Array.isArray(header.charges) ? header.charges : [],
        charge_total: header.charge_total || 0,
        charge_tax_total: header.charge_tax_total || 0,
        total_discount: header.total_discount || 0,
        round_off_amount: roundOffAmount,
        net_amount: netAmount,
        voucher_code: voucherCode || null,
        voucher_label: header.voucher_label || null,
        loyalty_points_earned: Math.max(0, Math.floor(toAmount(header.loyalty_points_earned, 0))),
        loyalty_points_redeemed: Math.max(0, Math.floor(toAmount(header.loyalty_points_redeemed, 0))),
        loyalty_discount_amount: toAmount(header.loyalty_discount_amount || 0),
        notes: header.notes || null,
        status,
        created_by,
        original_sale_id: null,
        previous_sale_id: null,
        replaced_by_sale_id: null,
        version_no: 1,
        is_latest: true,
        is_deleted: false,
        modified_by: overrides.modified_by ?? null,
        modified_at: overrides.modified_at ?? null,
        modification_note: header.modification_note || overrides.modification_note || null,
        ...commFields,
        ...overrides
    }, { transaction });

    for (const row of saleItems) {
        const qty = toAmount(row.qty);
        let rate = toAmount(row.rate);
        let taxPercent = toAmount(row.tax_percent);
        let taxType = row.tax_type || 'GST';

        const isAdvanceOrSubFree = row.is_advance_free === true || row._subscription_free === true;
        if (isAdvanceOrSubFree && rate <= 0) {
            const itemMaster = itemMasterMap.get(Number(row.item_id));
            const referenceRate = toAmount(
                row.reference_rate ??
                row.original_rate ??
                itemMaster?.retail_sale_price ??
                itemMaster?.rate ??
                0
            );
            if (referenceRate > 0) {
                rate = referenceRate;
            }
            if (itemMaster) {
                taxPercent = toAmount(itemMaster.tax_percent);
                taxType = itemMaster.tax_type || 'GST';
            }
        }

        const amount = qty * rate;
        let lineDiscount = toAmount(row.line_discount);

        let taxableAmount, taxAmount, lineTotal, itemNetAmount, rowTaxes;

        if (isAdvanceOrSubFree) {
            lineDiscount = 0;
            taxableAmount = amount;
            const billingTaxMode = header.billing_tax_mode || 'CGST_SGST';
            rowTaxes = calculateTaxesForAmount({
                taxMode: billingTaxMode,
                taxType,
                taxPercent,
                taxableAmount
            });
            taxAmount = rowTaxes.reduce((sum, tax) => sum + toAmount(tax.taxAmount), 0);
            lineTotal = taxableAmount + taxAmount;
            itemNetAmount = lineTotal;
            advanceSubscriptionDiscount += lineTotal;
            subscriptionTaxableAmount += taxableAmount;
            for (const tax of rowTaxes) {
                if (tax.code === 'CGST') subscriptionTaxCgst += toAmount(tax.taxAmount);
                else if (tax.code === 'SGST') subscriptionTaxSgst += toAmount(tax.taxAmount);
                else if (tax.code === 'IGST') subscriptionTaxIgst += toAmount(tax.taxAmount);
            }
        } else {
            taxableAmount = toAmount(row.taxable_amount, amount - lineDiscount);
            taxAmount = toAmount(row.tax_amount);
            lineTotal = toAmount(row.line_total, taxableAmount + taxAmount);
            itemNetAmount = toAmount(row.net_amount, lineTotal);
            rowTaxes = Array.isArray(row.tax_breakup)
                ? row.tax_breakup.map((tax) => normalizeTaxBreakupEntry(tax))
                : [];
        }

        if (row.is_scheme_free === true) {
            const referenceRate = toAmount(
                row.scheme_free_reference_rate ??
                row.reference_rate ??
                row.original_rate ??
                row._scheme_source_rate ??
                itemRateFallbackMap.get(Number(row.item_id)) ??
                0
            );
            if (referenceRate > 0) {
                if (row._subscription_free === true) {
                    subscriptionAdjustmentAmount += qty * referenceRate;
                } else {
                    schemeFreeQtyAmount += qty * referenceRate;
                }
            }
        }

        totalQty += qty;
        subTotal += amount;
        itemsTaxableTotal += taxableAmount;
        itemsTaxTotal += taxAmount;
        itemsLineTotal += lineTotal;

        for (const tax of rowTaxes) {
            const taxCode = String(tax?.code || '').trim().toUpperCase();
            const taxLabel = String(tax?.label || taxCode || '').trim();
            const taxRate = toAmount(tax?.rate);
            const taxableValue = toAmount(tax?.taxableAmount ?? taxableAmount);
            const taxValue = toAmount(tax?.taxAmount ?? tax?.tax_amount);
            const key = `${taxCode}|${taxLabel}|${taxRate}`;
            const existing = taxSummary.get(key);
            if (!existing) {
                taxSummary.set(key, {
                    code: taxCode || 'GST',
                    label: taxLabel || taxCode || 'GST',
                    taxType: String(tax?.taxType || row?.tax_type || 'GST').toUpperCase(),
                    tax_type: String(tax?.taxType || row?.tax_type || 'GST').toUpperCase(),
                    rate: taxRate,
                    taxableAmount: taxableValue,
                    taxable_amount: taxableValue,
                    taxAmount: taxValue,
                    tax_amount: taxValue
                });
            } else {
                existing.taxableAmount += taxableValue;
                existing.taxable_amount += taxableValue;
                existing.taxAmount += taxValue;
                existing.tax_amount += taxValue;
            }
        }

        await req.propertyDb.models.sales_items.create({
            sale_id: sale.id,
            item_id: row.item_id,
            item_code: row.item_code,
            item_name: row.item_name,
            hsn_sac_code: row.hsn_sac_code || null,
            barcode: row.barcode || null,
            unit: row.unit || null,
            qty,
            rate,
            tax_type: row.tax_type || 'GST',
            tax_percent: toAmount(row.tax_percent),
            discount_applicable: row.discount_applicable ?? true,
            scheme_applicable: row.scheme_applicable ?? true,
            line_discount: lineDiscount,
            amount,
            taxable_amount: taxableAmount,
            tax_amount: taxAmount,
            line_total: lineTotal,
            tax_breakup: Array.isArray(row.tax_breakup) ? row.tax_breakup : [],
            net_amount: itemNetAmount,
            is_scheme_free: row.is_scheme_free === true,
            applied_scheme_id: row.applied_scheme_id || null,
            is_advance_free: row.is_advance_free === true,
        }, { transaction });

        if (status === 'COMPLETED' && affectStock) {
            // Always deduct the parent item itself
            await insertLedger({
                db: req.propertyDb,
                outlet_id,
                item_code: row.item_code,
                txn_date: header.sale_date,
                txn_type: stockTxnType,
                ref_no: header.sale_no,
                qty_out: qty,
                transaction
            });

            // If it is a composite item, also deduct components
            const bomComponents = await req.propertyDb.models.item_boms.findAll({
                where: { outlet_id, parent_item_id: row.item_id },
                include: [
                    {
                        model: req.propertyDb.models.item_master,
                        as: 'component_item',
                        where: { is_active: true }
                    }
                ],
                transaction
            });

            if (bomComponents && bomComponents.length > 0) {
                for (const bomComp of bomComponents) {
                    const compItem = bomComp.component_item;
                    if (!compItem) continue;
                    const qtyRequiredPerUnit = Number(bomComp.quantity);
                    const totalQtyNeeded = qtyRequiredPerUnit * qty;

                    await insertLedger({
                        db: req.propertyDb,
                        outlet_id,
                        item_code: compItem.item_code,
                        txn_date: header.sale_date,
                        txn_type: stockTxnType,
                        ref_no: header.sale_no,
                        qty_out: totalQtyNeeded,
                        transaction
                    });
                }
            }
        }
    }

    const headerChargeTotal = toAmount(header.charge_total);
    const headerChargeTaxTotal = toAmount(header.charge_tax_total);
    const derivedTaxBreakup = Array.from(taxSummary.values())
        .sort((a, b) => a.label.localeCompare(b.label));
    const derivedCgstAmount = Math.max(0, toAmount(
        derivedTaxBreakup
            .filter((tax) => tax.code === 'CGST')
            .reduce((sum, tax) => sum + toAmount(tax.taxAmount), 0) - subscriptionTaxCgst
    ));
    const derivedSgstAmount = Math.max(0, toAmount(
        derivedTaxBreakup
            .filter((tax) => tax.code === 'SGST')
            .reduce((sum, tax) => sum + toAmount(tax.taxAmount), 0) - subscriptionTaxSgst
    ));
    const derivedIgstAmount = Math.max(0, toAmount(
        derivedTaxBreakup
            .filter((tax) => tax.code === 'IGST')
            .reduce((sum, tax) => sum + toAmount(tax.taxAmount), 0) - subscriptionTaxIgst
    ));
    const derivedTotalDiscount = Math.max(0, toAmount(header.total_discount || 0));
    const derivedTaxableAmount = itemsTaxableTotal + headerChargeTotal;
    const derivedTotalTax = Math.max(0, toAmount(itemsTaxTotal + headerChargeTaxTotal - (subscriptionTaxCgst + subscriptionTaxSgst + subscriptionTaxIgst)));

    const adjustedTaxBreakup = derivedTaxBreakup.map(tax => {
        const copy = { ...tax };
        if (copy.code === 'CGST') {
            copy.taxAmount = Math.max(0, toAmount(copy.taxAmount - subscriptionTaxCgst));
            copy.tax_amount = copy.taxAmount;
            copy.taxableAmount = Math.max(0, toAmount(copy.taxableAmount - subscriptionTaxableAmount));
            copy.taxable_amount = copy.taxableAmount;
        } else if (copy.code === 'SGST') {
            copy.taxAmount = Math.max(0, toAmount(copy.taxAmount - subscriptionTaxSgst));
            copy.tax_amount = copy.taxAmount;
            copy.taxableAmount = Math.max(0, toAmount(copy.taxableAmount - subscriptionTaxableAmount));
            copy.taxable_amount = copy.taxableAmount;
        } else if (copy.code === 'IGST') {
            copy.taxAmount = Math.max(0, toAmount(copy.taxAmount - subscriptionTaxIgst));
            copy.tax_amount = copy.taxAmount;
            copy.taxableAmount = Math.max(0, toAmount(copy.taxableAmount - subscriptionTaxableAmount));
            copy.taxable_amount = copy.taxableAmount;
        }
        return copy;
    });

    const derivedNetAmount =
        Math.max(
            0,
            itemsLineTotal +
                headerChargeTotal +
                headerChargeTaxTotal +
                roundOffAmount -
                invoiceDiscount -
                advanceSubscriptionDiscount
        );
    const effectiveChangeAmount = header.change_amount != null
        ? Math.max(toAmount(header.change_amount), 0)
        : (paymentMode === 'CASH' ? Math.max(amountPaid - derivedNetAmount, 0) : 0);
    const effectiveBalanceDue = Math.max(
        derivedNetAmount - Math.min(amountPaid, derivedNetAmount),
        0
    );

    await sale.update({
        total_qty: totalQty,
        sub_total: subTotal,
        taxable_amount: derivedTaxableAmount,
        cgst_amount: derivedCgstAmount,
        sgst_amount: derivedSgstAmount,
        igst_amount: derivedIgstAmount,
        total_tax: derivedTotalTax,
        tax_breakup: adjustedTaxBreakup,
        charges: Array.isArray(header.charges) ? header.charges : [],
        charge_total: headerChargeTotal,
        charge_tax_total: headerChargeTaxTotal,
        total_discount: derivedTotalDiscount,
        round_off_amount: roundOffAmount,
        net_amount: derivedNetAmount,
        change_amount: effectiveChangeAmount,
        balance_due: effectiveBalanceDue
    }, { transaction });

    if (createPayment) {
        const ledgerDiscountAmount = toAmount(
            header.ledger_discount_amount ?? header.total_discount ?? 0
        );
        await recordSalePayment({
            req,
            transaction,
            sale,
            header,
            paymentMode,
            amountPaid,
            netAmount: derivedNetAmount,
            balanceDue: effectiveBalanceDue,
            created_by
        });
        await recordSaleBenefitExpenseEntries({
            req,
            transaction,
            sale,
            header,
            paymentMode,
            created_by,
            discountAmount: ledgerDiscountAmount,
            schemeFreeQtyAmount,
            subscriptionAdjustmentAmount
        });
    }

    return sale;
}

async function reverseSaleStock({ req, transaction, sale, items }) {
    if (sale.status !== 'COMPLETED') return;

    for (const row of items) {
        // Always revert the parent item itself
        await insertLedger({
            db: req.propertyDb,
            outlet_id: req.user.outlet_id,
            item_code: row.item_code,
            txn_date: new Date(),
            txn_type: 'SALE_MODIFY_REVERSE',
            ref_no: sale.sale_no,
            qty_in: toAmount(row.qty),
            transaction
        });

        // If it is a composite item, also revert components
        const bomComponents = await req.propertyDb.models.item_boms.findAll({
            where: { outlet_id: req.user.outlet_id, parent_item_id: row.item_id },
            include: [
                {
                    model: req.propertyDb.models.item_master,
                    as: 'component_item',
                    where: { is_active: true }
                }
            ],
            transaction
        });

        if (bomComponents && bomComponents.length > 0) {
            for (const bomComp of bomComponents) {
                const compItem = bomComp.component_item;
                if (!compItem) continue;
                const qtyRequiredPerUnit = Number(bomComp.quantity);
                const totalQtyToRevert = qtyRequiredPerUnit * toAmount(row.qty);

                await insertLedger({
                    db: req.propertyDb,
                    outlet_id: req.user.outlet_id,
                    item_code: compItem.item_code,
                    txn_date: new Date(),
                    txn_type: 'SALE_MODIFY_REVERSE',
                    ref_no: sale.sale_no,
                    qty_in: totalQtyToRevert,
                    transaction
                });
            }
        }
    }
}

function aggregateItemQty(items) {
    const totals = new Map();
    for (const row of Array.isArray(items) ? items : []) {
        const itemCode = String(row.item_code || '').trim();
        if (!itemCode) continue;
        const qty = toAmount(row.qty);
        if (qty <= 0) continue;
        totals.set(itemCode, (totals.get(itemCode) || 0) + qty);
    }
    return totals;
}

async function applySaleModificationStockDelta({
    req,
    transaction,
    previousItems,
    nextItems,
    refNo
}) {
    const previousTotals = aggregateItemQty(previousItems);
    const nextTotals = aggregateItemQty(nextItems);
    const itemCodes = new Set([...previousTotals.keys(), ...nextTotals.keys()]);

    for (const itemCode of itemCodes) {
        const previousQty = previousTotals.get(itemCode) || 0;
        const nextQty = nextTotals.get(itemCode) || 0;
        const diff = nextQty - previousQty;

        if (Math.abs(diff) <= 0.000001) continue;

        // Always apply stock delta adjustment to the parent item itself
        await insertLedger({
            db: req.propertyDb,
            outlet_id: req.user.outlet_id,
            item_code: itemCode,
            txn_date: new Date(),
            txn_type: 'SALE_MOD_ADJ',
            ref_no: refNo,
            qty_in: diff < 0 ? Math.abs(diff) : 0,
            qty_out: diff > 0 ? diff : 0,
            transaction
        });

        const item = await req.propertyDb.models.item_master.findOne({
            where: { outlet_id: req.user.outlet_id, item_code: itemCode },
            transaction
        });

        const bomComponents = item
            ? await req.propertyDb.models.item_boms.findAll({
                where: { outlet_id: req.user.outlet_id, parent_item_id: item.id },
                include: [
                    {
                        model: req.propertyDb.models.item_master,
                        as: 'component_item',
                        where: { is_active: true }
                    }
                ],
                transaction
            })
            : [];

        if (bomComponents && bomComponents.length > 0) {
            for (const bomComp of bomComponents) {
                const compItem = bomComp.component_item;
                if (!compItem) continue;
                const qtyRequiredPerUnit = Number(bomComp.quantity);
                const totalDiff = qtyRequiredPerUnit * diff;

                await insertLedger({
                    db: req.propertyDb,
                    outlet_id: req.user.outlet_id,
                    item_code: compItem.item_code,
                    txn_date: new Date(),
                    txn_type: 'SALE_MOD_ADJ',
                    ref_no: refNo,
                    qty_in: totalDiff < 0 ? Math.abs(totalDiff) : 0,
                    qty_out: totalDiff > 0 ? totalDiff : 0,
                    transaction
                });
            }
        }
    }
}

async function getSaleChainIds(req, sale, transaction) {
    const rootId = sale.original_sale_id || sale.id;
    const versions = await req.propertyDb.models.sales_headers.findAll({
        where: {
            outlet_id: req.user.outlet_id,
            [Op.or]: [{ id: rootId }, { original_sale_id: rootId }]
        },
        attributes: ['id'],
        transaction
    });

    return versions
        .map((row) => Number(row.id))
        .filter((value) => Number.isFinite(value) && value > 0);
}

async function recordSaleModificationPayment({
    req,
    transaction,
    previousSale,
    nextSale
}) {
    const previousCollected = previousSale.status === 'COMPLETED'
        ? Math.min(toAmount(previousSale.amount_paid), toAmount(previousSale.net_amount))
        : 0;
    const nextCollected = nextSale.status === 'COMPLETED'
        ? Math.min(toAmount(nextSale.amount_paid), toAmount(nextSale.net_amount))
        : 0;
    const diff = Number((nextCollected - previousCollected).toFixed(2));

    if (diff === 0) return;

    await createLedgerEntry({
        db: req.propertyDb,
        outlet_id: req.user.outlet_id,
        txn_date: new Date(),
        transaction_type: 'SALE_MODIFY_ADJUSTMENT',
        reference_type: 'SALE',
        reference_id: nextSale.id,
        reference_no: nextSale.sale_no,
        party_name: nextSale.customer_name || nextSale.customer_phone || 'Walk-in Customer',
        payment_method: nextSale.payment_mode,
        amount_in: diff > 0 ? diff : 0,
        amount_out: diff < 0 ? Math.abs(diff) : 0,
        notes: `Payment adjusted after modifying sale ${nextSale.sale_no}`,
        created_by: req.user.id,
        transaction
    });
}

exports.getNextSaleNo = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const normalizedDate = normalizeDateKey(req.query.date);
        const resolved = await numberingHelper.getEffectiveSetting({
            db: req.propertyDb,
            outlet_id,
            module: 'SALES',
            date: normalizedDate || req.query.date || new Date().toISOString()
        });

        if (!resolved) {
            return res.status(400).json({
                success: false,
                message: 'Sales numbering not configured'
            });
        }

        const { effective, nextSetting } = resolved;

        const existingSales = await req.propertyDb.models.sales_headers.findAll({
            where: {
                outlet_id,
                is_latest: true,
                is_deleted: false,
                sale_date: nextSetting?.start_date
                    ? {
                        [Op.gte]: effective.start_date,
                        [Op.lt]: nextSetting.start_date
                    }
                    : { [Op.gte]: effective.start_date }
            },
            attributes: ['sale_no']
        });

        let nextNum = toWholeNumber(effective.start_no);

        for (const sale of existingSales) {
            const numeric = numberingHelper.extractNumericPart(sale.sale_no, effective);
            if (numeric !== null) {
                nextNum = Math.max(nextNum, numeric + 1);
            }
        }

        res.json({
            success: true,
            data: {
                number: `${effective.prefix || ''}${nextNum}${effective.postfix || ''}`
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.createSale = async (req, res) => {
    const t = await req.propertyDb.transaction();
    let luckyDrawVouchers = [];

    try {
        const { header, items } = req.body;
        const saleItemsRaw = Array.isArray(items) ? items : [];
        const itemsPreSplit = header?.items_pre_split === true;
        const selectedSchemes = normalizeSelectedSchemes(header.selected_schemes || header.selectedSchemes);
        const status = header.status || 'COMPLETED';
        const headerForCreate = { ...header };
        if (status === 'DRAFT') {
            // Drafts must never reserve official billing sequence.
            headerForCreate.sale_no = buildDraftSaleNo();
        }
        const voucherCode = String(header.voucher_code || '').trim().toUpperCase();
        const affectStock = header.affect_stock !== false;


        const netAmount = toAmount(headerForCreate.net_amount);
        const isZeroAmountSchemeBill = status === 'COMPLETED' &&
            saleItemsRaw.length === 0 &&
            netAmount === 0 &&
            (Number(header.scheme_id) > 0 || String(header.scheme_name || '').trim().length > 0);

        if (status !== 'DRAFT' && saleItemsRaw.length === 0 && !isZeroAmountSchemeBill) {
            return res.status(400).json({
                success: false,
                message: 'At least one sale item is required'
            });
        }


        if (voucherCode && status === 'COMPLETED') {
            const voucherCheck = await validateVoucherUsage(req, {
                code: voucherCode,
                orderAmount: headerForCreate.sub_total || 0,
                header: headerForCreate
            });
            if (!voucherCheck.valid) {
                await t.rollback();
                return res.status(400).json({
                    success: false,
                    code: voucherCheck.reason,
                    message: voucherCheck.message
                });
            }
        }

        if (status === 'COMPLETED') {
            await ensureCustomerSchemeEnrollments({
                req,
                transaction: t,
                header: headerForCreate,
                selectedSchemes
            });
        }

        let saleItems = saleItemsRaw;
        let subscriptionAllocation = {
            items: saleItemsRaw,
            consumptions: [],
            totalCoveredAmount: 0,
            subscriptionId: 0
        };
        if (status === 'COMPLETED') {
            if (itemsPreSplit) {
                subscriptionAllocation = await collectPreSplitSubscriptionAllocation({
                    req,
                    header: headerForCreate,
                    items: saleItemsRaw,
                    transaction: t
                });
                saleItems = subscriptionAllocation.items;
            } else {
                subscriptionAllocation = await allocateMilkSubscriptionCoverage({
                    req,
                    header: headerForCreate,
                    items: saleItemsRaw,
                    transaction: t
                });
                saleItems = await applyItemCycleSchemesToSale({
                    req,
                    header: headerForCreate,
                    items: subscriptionAllocation.items,
                    transaction: t
                });
                saleItems = await allocateItemAdvanceConsumption({ req, header: headerForCreate, items: saleItems, transaction: t })
                    .then((result) => result.items);
            }
        }

        const itemIds = [
            ...new Set(
                saleItems
                    .map((row) => Number(row?.item_id))
                    .filter((value) => Number.isFinite(value) && value > 0)
            )
        ];
        const itemRows = itemIds.length > 0
            ? await req.propertyDb.models.item_master.findAll({
                where: {
                    outlet_id: req.user.outlet_id,
                    id: { [Op.in]: itemIds }
                },
                transaction: t
            })
            : [];
        const itemMetaMap = new Map(
            itemRows.map((row) => [Number(row.id), row.toJSON()])
        );
        const taxMode = String(header.billing_tax_mode || 'CGST_SGST').trim().toUpperCase();
        const splitItems = saleItems.reduce(
            (acc, row) => {
                if (toAmount(row?.qty) <= 0) {
                    return acc;
                }
                if (isFreeBillRow(row)) {
                    acc.free.push(row);
                } else {
                    acc.paid.push(row);
                }
                return acc;
            },
            { paid: [], free: [] }
        );
        const freeBillItems = splitItems.free.map((row) =>
            buildTaxCompliantFreeRow(row, itemMetaMap.get(Number(row.item_id)), taxMode)
        );
        const freeBillDiscount = toRoundedAmount(
            freeBillItems.reduce((sum, row) => sum + toAmount(row.line_total), 0)
        );
        const hasSubscriptionFreeRows = splitItems.free.some((row) => row._subscription_free === true || row.is_advance_free === true);
        const hasSchemeFreeRows = splitItems.free.some((row) => row.is_scheme_free === true && !(row._subscription_free === true || row.is_advance_free === true));
        const paidSaleNo = String(headerForCreate.sale_no || '').trim();
        const freeSaleNo = incrementSaleNo(paidSaleNo);
        const buildBillHeader = (saleNo, extra = {}) => ({
            ...headerForCreate,
            sale_no: saleNo,
            ...extra
        });

        const createdSales = [];
        let primarySale = null;
        let freeSale = null;

        if (splitItems.paid.length > 0) {
            primarySale = await createSaleVersion({
                req,
                transaction: t,
                header: buildBillHeader(paidSaleNo, {
                    invoice_discount_amount: 0,
                    force_invoice_discount: false
                }),
                items: splitItems.paid,
                overrides: {
                    original_sale_id: null
                },
                affectStock
            });
            await primarySale.update({
                original_sale_id: primarySale.id
            }, { transaction: t });
            createdSales.push(primarySale);
        }

        if (freeBillItems.length > 0) {
            freeSale = await createSaleVersion({
                req,
                transaction: t,
                header: buildBillHeader(freeSaleNo, {
                    payment_mode: hasSubscriptionFreeRows
                        ? 'SUBSCRIPTION'
                        : (hasSchemeFreeRows ? 'SCHEME' : 'DISCOUNT'),
                    payment_reference: null,
                    amount_paid: 0,
                    initial_amount_paid: 0,
                    change_amount: 0,
                    balance_due: 0,
                    net_amount: 0,
                    total_discount: freeBillDiscount,
                    invoice_discount_amount: freeBillDiscount,
                    scheme_id: null,
                    scheme_name: null,
                    scheme_discount: 0,
                    ledger_discount_amount: 0,
                    manual_discount_type: null,
                    manual_discount_value: 0,
                    manual_discount_amount: 0,
                    loyalty_points_earned: 0,
                    loyalty_points_redeemed: 0,
                    loyalty_discount_amount: 0,
                    voucher_code: null,
                    voucher_label: null,
                    notes: [
                        header.notes,
                        hasSubscriptionFreeRows && hasSchemeFreeRows
                            ? 'Auto-generated free bill for subscription and scheme coverage'
                            : hasSubscriptionFreeRows
                                ? 'Auto-generated free bill for subscription coverage'
                                : 'Auto-generated free bill for scheme coverage'
                    ].filter(Boolean).join(' | '),
                    force_invoice_discount: true
                }),
                items: freeBillItems,
                overrides: {
                    original_sale_id: null
                },
                affectStock,
                invoiceDiscountAmount: freeBillDiscount
            });
            await freeSale.update({
                original_sale_id: freeSale.id
            }, { transaction: t });
            createdSales.push(freeSale);
        }

        if (createdSales.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'At least one sale item is required'
            });
        }

        const referenceSale = freeSale || primarySale || createdSales[0];

        if (status === 'COMPLETED') {
            await persistMilkSubscriptionConsumptions({
                req,
                transaction: t,
                sale: referenceSale,
                consumptions: subscriptionAllocation.consumptions
            });
            if (subscriptionAllocation.totalCoveredAmount > 0) {
                const coverages = Array.isArray(subscriptionAllocation.subscriptionCoverages)
                    ? subscriptionAllocation.subscriptionCoverages
                    : [{
                        subscriptionId: subscriptionAllocation.subscriptionId,
                        subscriptionItemId: subscriptionAllocation.subscriptionItemId,
                        itemId: null,
                        totalCoveredQty: subscriptionAllocation.totalCoveredQty,
                        totalCoveredAmount: subscriptionAllocation.totalCoveredAmount
                    }];

                for (const coverage of coverages) {
                    const coverageAdvance = await findSubscriptionItemAdvance(
                        req,
                        coverage.subscriptionId,
                        coverage.itemId || subscriptionAllocation.subscriptionItemId,
                        t
                    );
                    if (coverageAdvance) {
                        await consumeSubscriptionItemAdvance(
                            req,
                            coverage.subscriptionId,
                            coverage.itemId || subscriptionAllocation.subscriptionItemId,
                            coverage.totalCoveredQty,
                            t
                        );
                    }

                    const subscriptionCashAdvance = await findSubscriptionCustomerAdvance(
                        req,
                        coverage.subscriptionId,
                        t
                    );
                    let appliedCashAdvanceAmount = 0;
                    if (subscriptionCashAdvance) {
                        appliedCashAdvanceAmount = Math.min(
                            toAmount(subscriptionCashAdvance.available_amount),
                            toAmount(coverage.totalCoveredAmount)
                        );
                        await consumeSubscriptionCustomerAdvance(
                            req,
                            coverage.subscriptionId,
                            appliedCashAdvanceAmount,
                            t
                        );
                    }
                    if (appliedCashAdvanceAmount > 0) {
                        await createLedgerEntry({
                            db: req.propertyDb,
                            outlet_id: req.user.outlet_id,
                            txn_date: header.sale_date || referenceSale.sale_date || new Date(),
                            transaction_type: 'ADVANCE_APPLY',
                            reference_type: 'SUBSCRIPTION',
                            reference_id: coverage.subscriptionId,
                            reference_no: referenceSale.sale_no,
                            party_name: header.customer_name || header.customer_phone || 'Subscription Customer',
                            payment_method: 'SUBSCRIPTION',
                            amount_out: appliedCashAdvanceAmount,
                            notes: `Advance adjusted for subscription item consumption in ${referenceSale.sale_no}`,
                            created_by: req.user.id,
                            transaction: t
                        });
                    }
                }
            }
            await markSingleUseSchemesAsConsumed({
                req,
                header,
                selectedSchemes,
                appliedSchemeIds: collectAppliedSchemeIds(header, saleItems),
                transaction: t
            });

            const loyaltyResult = await applyLoyaltyOnCompletedSale({
                db: req.propertyDb,
                outlet_id: req.user.outlet_id,
                user_id: req.user.id,
                sale: referenceSale,
                header,
                transaction: t
            });
            await referenceSale.update({
                loyalty_points_earned: loyaltyResult.earned_points,
                loyalty_points_redeemed: loyaltyResult.redeemed_points,
                loyalty_discount_amount: loyaltyResult.redemption_discount_amount
            }, { transaction: t });
        }

        await audit.log({
            req,
            module: 'SALES',
            action: 'CREATE',
            table: 'sales_headers',
            recordId: referenceSale.id,
            new_data: {
                header,
                items: saleItems,
                split_bills: createdSales.map((sale) => ({
                    sale_id: sale.id,
                    sale_no: sale.sale_no,
                    net_amount: sale.net_amount,
                    payment_mode: sale.payment_mode
                })),
                subscription_consumptions: subscriptionAllocation.consumptions
            },
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });

        // --- LUCKY DRAW INTERCEPTION HOOK ---
        if (status === 'COMPLETED' && referenceSale.customer_phone) {
            try {
                const activeCampaign = await req.propertyDb.models.lucky_draw_campaigns.findOne({
                    where: { status: 'ACTIVE' }
                });
                const pendingCampaign = await req.propertyDb.models.lucky_draw_campaigns.findOne({
                    where: { status: 'PENDING_RESULT' }
                });

                // Voucher generation is paused if there is a pending campaign or if no active campaign exists
                if (activeCampaign && !pendingCampaign) {
                    const customerPhone = referenceSale.customer_phone.trim();
                    if (customerPhone.length > 0) {
                        const customerName = referenceSale.customer_name ? referenceSale.customer_name.trim() : null;
                        const netAmount = Number(referenceSale.net_amount || 0);

                        // Check credit eligibility
                        let isEligible = true;
                        if (activeCampaign.allow_creditors === false) {
                            const outstanding = await req.propertyDb.models.sales_headers.sum('balance_due', {
                                where: {
                                    customer_phone: customerPhone,
                                    outlet_id: req.user.outlet_id,
                                    status: 'COMPLETED'
                                },
                                transaction: t
                            }) || 0;
                            if (Number(outstanding) > 0.009) {
                                isEligible = false;
                            }
                        }

                        if (isEligible) {
                            let [progress, created] = await req.propertyDb.models.customer_draw_progress.findOrCreate({
                                where: {
                                    campaign_id: activeCampaign.id,
                                    customer_phone: customerPhone
                                },
                                defaults: {
                                    outlet_id: req.user.outlet_id,
                                    customer_name: customerName,
                                    accumulated_spend: 0.00
                                },
                                transaction: t
                            });

                            // Check if a voucher already exists for this sale
                            const existingVoucher = await req.propertyDb.models.draw_vouchers.findOne({
                                where: {
                                    campaign_id: activeCampaign.id,
                                    sale_id: referenceSale.id
                                },
                                transaction: t
                            });

                            if (!existingVoucher) {
                                let code = '';
                                let attempts = 0;
                                while (attempts < 10) {
                                    const randPart1 = Math.random().toString(36).substring(2, 6).toUpperCase();
                                    const randPart2 = Math.random().toString(36).substring(2, 5).toUpperCase();
                                    code = `LD-${randPart1}-${randPart2}`;

                                    const exists = await req.propertyDb.models.draw_vouchers.findOne({
                                        where: { voucher_code: code },
                                        transaction: t,
                                        bypassOutletFilter: true
                                    });
                                    if (!exists) break;
                                    attempts++;
                                }

                                const voucher = await req.propertyDb.models.draw_vouchers.create({
                                    outlet_id: req.user.outlet_id,
                                    campaign_id: activeCampaign.id,
                                    customer_phone: customerPhone,
                                    customer_name: customerName,
                                    sale_id: referenceSale.id,
                                    voucher_code: code,
                                    is_winner: false
                                }, { transaction: t });

                                luckyDrawVouchers = [{
                                    code: voucher.voucher_code,
                                    campaign_name: activeCampaign.name,
                                    campaign_description: activeCampaign.description,
                                    customer_phone: customerPhone,
                                    customer_name: customerName
                                }];
                            }

                            // Always accumulate the spend progress total
                            await progress.update({
                                customer_name: customerName || progress.customer_name,
                                accumulated_spend: Number(progress.accumulated_spend || 0) + netAmount
                            }, { transaction: t });
                        }
                    }
                }
            } catch (ldErr) {
                console.error('[LUCKY DRAW CHECKOUT HOOK FAIL]', ldErr.message);
            }
        }

        await t.commit();

        // Trigger WhatsApp Checkout Billing alert asynchronously
        if (status === 'COMPLETED' && referenceSale.customer_phone) {
            try {
                const { queueUtilityInvoiceAlert } = require('../../services/whatsappQueue.service');
                queueUtilityInvoiceAlert(req.propertyDb, referenceSale.id, req.user.outlet_id, referenceSale.customer_phone, {
                    customer_name: referenceSale.customer_name || 'Customer',
                    sale_no: referenceSale.sale_no,
                    net_amount: referenceSale.net_amount
                }).catch(qErr => console.error('[WHATSAPP QUEUE ALERT TRIGGER FAIL]', qErr.message));
            } catch (err) {
                console.error('[WHATSAPP QUEUE SERVICE REQUIRE FAIL]', err.message);
            }
        }

        res.json({
            success: true,
            sale_id: referenceSale.id,
            sale_ids: createdSales.map((sale) => sale.id),
            sale_nos: createdSales.map((sale) => sale.sale_no),
            data: {
                primary_sale_id: primarySale?.id || null,
                primary_sale_no: primarySale?.sale_no || null,
                free_sale_id: freeSale?.id || null,
                free_sale_no: freeSale?.sale_no || null,
                sale_ids: createdSales.map((sale) => sale.id),
                sale_nos: createdSales.map((sale) => sale.sale_no),
                lucky_draw_vouchers: luckyDrawVouchers
            }
        });
    } catch (error) {
        await t.rollback();
        res.status(error.status || 500).json({
            success: false,
            error: error.message
        });
    }
};


exports.modifySale = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const saleId = Number(req.params.id);
        const { header, items } = req.body;
        const headerForModify = { ...(header || {}) };
        const saleItemsRaw = Array.isArray(items) ? items : [];
        const itemsPreSplit = headerForModify?.items_pre_split === true;
        const selectedSchemes = normalizeSelectedSchemes(headerForModify.selected_schemes || headerForModify.selectedSchemes);
        const status = headerForModify.status || 'COMPLETED';
        const voucherCode = String(headerForModify.voucher_code || '').trim().toUpperCase();
        const affectStock = headerForModify.affect_stock !== false;

        if (!Number.isFinite(saleId) || saleId <= 0) {
            return res.status(400).json({ success: false, message: 'Invalid sale id' });
        }

        const netAmount = toAmount(headerForModify.net_amount);
        const isZeroAmountSchemeBill = status === 'COMPLETED' &&
            saleItemsRaw.length === 0 &&
            netAmount === 0 &&
            (Number(headerForModify.scheme_id) > 0 || String(headerForModify.scheme_name || '').trim().length > 0);

        if (saleItemsRaw.length === 0 && !isZeroAmountSchemeBill) {
            return res.status(400).json({
                success: false,
                message: 'At least one sale item is required to modify a bill'
            });
        }

        require('fs').appendFileSync(
            require('path').join(__dirname, '../../debug.log'),
            `[${new Date().toISOString()}] DEBUG modifySale: saleId=${saleId}, userOutlet=${req.user?.outlet_id}, storeOutlet=${require('../../utils/context').contextStorage.getStore()?.get('outlet_id')}\n`
        );

        const currentSale = await req.propertyDb.models.sales_headers.findOne({
            where: {
                id: saleId,
                outlet_id: req.user.outlet_id,
                is_deleted: false
            },
            include: [
                {
                    model: req.propertyDb.models.sales_items,
                    as: 'items'
                }
            ],
            transaction: t
        });

        if (!currentSale) {
            return res.status(404).json({ success: false, message: 'Sale not found' });
        }

        if (currentSale.is_latest === false) {
            return res.status(400).json({
                success: false,
                message: 'This bill has already been modified. Open the latest version to edit again.'
            });
        }

        if ((currentSale.status || '').toUpperCase() === 'DRAFT' &&
            status === 'COMPLETED') {
            const resolved = await numberingHelper.resolveNextNumber({
                req,
                module: 'SALES',
                date: headerForModify.sale_date || new Date(),
                outlet_id: req.user.outlet_id
            });
            if (!resolved || !resolved.number) {
                return res.status(400).json({
                    success: false,
                    message: 'Sales numbering not configured'
                });
            }
            headerForModify.sale_no = resolved.number;
        }

        const ignoreSaleIds = await getSaleChainIds(req, currentSale, t);
        if (voucherCode && status === 'COMPLETED') {
            const voucherCheck = await validateVoucherUsage(req, {
                code: voucherCode,
                orderAmount: headerForModify.sub_total || 0,
                header: headerForModify,
                ignoreSaleIds
            });
            if (!voucherCheck.valid) {
                await t.rollback();
                return res.status(400).json({
                    success: false,
                    code: voucherCheck.reason,
                    message: voucherCheck.message
                });
            }
        }

        if (currentSale.notes && currentSale.notes.includes('Auto-generated from delivery order #')) {
            headerForModify.notes = currentSale.notes;
        }

        const saleItems = status === 'COMPLETED' && !itemsPreSplit
            ? await applyItemCycleSchemesToSale({ req, header: headerForModify, items: saleItemsRaw, transaction: t })
            : saleItemsRaw;
        const advanceAllocation = status === 'COMPLETED' && !itemsPreSplit
            ? await allocateItemAdvanceConsumption({ req, header: headerForModify, items: saleItems, transaction: t })
            : { items: saleItems, advanceAppliedAmount: 0 };

        const newSale = await createSaleVersion({
            req,
            transaction: t,
            header: headerForModify,
            items: advanceAllocation.items,
            overrides: {
                original_sale_id: currentSale.original_sale_id || currentSale.id,
                previous_sale_id: currentSale.id,
                version_no: toWholeNumber(currentSale.version_no, 1) + 1,
                modified_by: req.user.id,
                modified_at: new Date(),
                modification_note: headerForModify.modification_note || 'Bill modified from reprint section'
            },
            createPayment: false,
            stockTxnType: 'SALE_MODIFY',
            affectStock: false
        });

        await currentSale.update({
            is_latest: false,
            is_deleted: true,
            replaced_by_sale_id: newSale.id,
            modified_by: req.user.id,
            modified_at: new Date(),
            modification_note: headerForModify.modification_note || 'Superseded by modified bill version'
        }, { transaction: t });

        if (status === 'COMPLETED' && affectStock) {
            await applySaleModificationStockDelta({
                req,
                transaction: t,
                previousItems: currentSale.items || [],
                nextItems: advanceAllocation.items,
                refNo: newSale.sale_no
            });
        }

        if (status === 'COMPLETED') {
            await markSingleUseSchemesAsConsumed({
                req,
                header: headerForModify,
                selectedSchemes,
                appliedSchemeIds: collectAppliedSchemeIds(headerForModify, saleItems),
                transaction: t
            });

            const loyaltyResult = await applyLoyaltyOnCompletedSale({
                db: req.propertyDb,
                outlet_id: req.user.outlet_id,
                user_id: req.user.id,
                sale: newSale,
                header: headerForModify,
                transaction: t
            });
            await newSale.update({
                loyalty_points_earned: loyaltyResult.earned_points,
                loyalty_points_redeemed: loyaltyResult.redeemed_points,
                loyalty_discount_amount: loyaltyResult.redemption_discount_amount
            }, { transaction: t });
        }

        await recordSaleModificationPayment({
            req,
            transaction: t,
            previousSale: currentSale,
            nextSale: newSale
        });

        await audit.log({
            req,
            module: 'SALES',
            action: 'MODIFY',
            table: 'sales_headers',
            recordId: newSale.id,
            old_data: {
                header: currentSale.toJSON(),
                items: (currentSale.items || []).map((row) => row.toJSON())
            },
            new_data: {
                header: headerForModify,
                items: advanceAllocation.items
            },
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });

        await req.propertyDb.models.system_notifications.create({
            outlet_id: req.user.outlet_id,
            module: 'SALES',
            title: 'Sales Bill Modified',
            message: `Bill ${currentSale.sale_no} was revised to version ${newSale.version_no}`,
            type: 'WARNING',
            entity_id: newSale.id
        }, { transaction: t });

        // Sync with customer order if this sale is generated from a delivery order
        const orderIdMatch = String(currentSale.notes || '').match(/Auto-generated from delivery order #(\d+)/);
        if (orderIdMatch) {
            const orderId = Number(orderIdMatch[1]);
            const customerOrder = await req.propertyDb.models.customer_orders.findOne({
                where: { id: orderId, outlet_id: req.user.outlet_id },
                transaction: t
            });
            if (customerOrder) {
                // Initialize original_net_amount if not set
                if (customerOrder.original_net_amount === null || customerOrder.original_net_amount === undefined) {
                    customerOrder.original_net_amount = customerOrder.net_amount;
                }

                // Map items into customer order format
                const mappedReceivedItems = advanceAllocation.items.map(item => ({
                    item_id: item.item_id,
                    item_code: item.item_code,
                    item_name: item.item_name,
                    qty: item.qty,
                    rate: item.rate,
                    amount: item.amount || (toAmount(item.qty) * toAmount(item.rate))
                }));

                customerOrder.received_items = mappedReceivedItems;
                customerOrder.modification_reason = headerForModify.modification_note || 'Order modified by supplier';
                
                // Update totals
                customerOrder.sub_total = newSale.sub_total;
                customerOrder.tax_amount = newSale.total_tax;
                customerOrder.net_amount = newSale.net_amount;

                // Handle payment status adjustments
                const origAmt = toAmount(customerOrder.original_net_amount);
                const newAmt = toAmount(newSale.net_amount);
                if (customerOrder.payment_status === 'PAID') {
                    if (newAmt < origAmt) {
                        customerOrder.refund_status = 'PENDING';
                    }
                }

                await customerOrder.save({ transaction: t });
            }
        }

        await t.commit();

        res.json({
            success: true,
            sale_id: newSale.id,
            message: 'Sales bill modified successfully'
        });
    } catch (error) {
        await t.rollback();
        res.status(error.status || 500).json({
            success: false,
            error: error.message
        });
    }
};

exports.updateSalePaymentMode = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const saleId = Number(req.params.id);
        const paymentModeInput = String(req.body.payment_mode || req.body.paymentMode || '')
            .trim()
            .toUpperCase();
        const paymentLinesRaw = Array.isArray(req.body.payment_lines || req.body.paymentLines)
            ? (req.body.payment_lines || req.body.paymentLines)
            : [];

        if (!Number.isFinite(saleId) || saleId <= 0) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Invalid sale id' });
        }

        const dbMethods = await req.propertyDb.models.payment_methods.findAll({
            where: { is_active: true },
            transaction: t
        });
        const allowedModes = new Set([
            'CASH', 'CARD', 'UPI', 'BANK', 'CREDIT',
            ...dbMethods.map(m => String(m.name).trim().toUpperCase())
        ]);
        if (!allowedModes.has(paymentModeInput) && paymentLinesRaw.length === 0) {
            await t.rollback();
            return res.status(400).json({
                success: false,
                message: `Invalid payment mode. Allowed: ${[...allowedModes].join(', ')}`
            });
        }

        const sale = await req.propertyDb.models.sales_headers.findOne({
            where: {
                id: saleId,
                outlet_id: req.user.outlet_id,
                is_deleted: false,
                is_latest: true
            },
            transaction: t
        });

        if (!sale) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Sale not found' });
        }

        const previousMode = String(sale.payment_mode || '').trim().toUpperCase();
        const netAmount = toAmount(sale.net_amount);
        const previousPaymentReference = String(sale.payment_reference || '').trim();

        const paymentLines = paymentLinesRaw
            .map((row) => ({
                method: String(row.method || '').trim().toUpperCase(),
                amount: toAmount(row.amount)
            }))
            .filter((row) => allowedModes.has(row.method) && row.amount > 0);

        if (paymentLines.length === 0) {
            const fallbackAmountPaid = Math.min(toAmount(sale.amount_paid), netAmount);
            const fallbackDue = Math.max(netAmount - fallbackAmountPaid, 0);
            if (fallbackAmountPaid > 0) {
                paymentLines.push({
                    method: allowedModes.has(paymentModeInput) ? paymentModeInput : (previousMode || 'CASH'),
                    amount: fallbackAmountPaid
                });
            }
            if (fallbackDue > 0) {
                paymentLines.push({ method: 'CREDIT', amount: fallbackDue });
            }
        }

        const nonCreditLines = paymentLines.filter((row) => row.method !== 'CREDIT');
        const creditLines = paymentLines.filter((row) => row.method === 'CREDIT');
        const nonCreditCollected = toAmount(nonCreditLines.reduce((sum, row) => sum + toAmount(row.amount), 0));
        const explicitCredit = toAmount(creditLines.reduce((sum, row) => sum + toAmount(row.amount), 0));
        const paymentTotal = toAmount(paymentLines.reduce((sum, row) => sum + toAmount(row.amount), 0));
        if (Math.abs(paymentTotal - netAmount) > 0.01) {
            await t.rollback();
            return res.status(400).json({
                success: false,
                message: `Payment total must match bill amount (${netAmount.toFixed(2)}).`
            });
        }
        const remainingDue = Math.max(netAmount - nonCreditCollected, 0);
        const creditDue = Math.max(explicitCredit, remainingDue);
        const amountPaid = Math.min(nonCreditCollected, netAmount);
        const balanceDue = Math.max(netAmount - amountPaid, 0);

        let resolvedMode = paymentModeInput;
        if (!allowedModes.has(resolvedMode)) {
            if (nonCreditLines.length > 0) {
                const primary = [...nonCreditLines].sort((a, b) => b.amount - a.amount)[0];
                resolvedMode = primary?.method || 'CASH';
            } else {
                resolvedMode = 'CREDIT';
            }
        }
        if (resolvedMode !== 'CREDIT' && amountPaid <= 0 && balanceDue > 0) {
            resolvedMode = 'CREDIT';
        }

        const mergedLines = [...nonCreditLines];
        if (creditDue > 0) {
            mergedLines.push({ method: 'CREDIT', amount: creditDue });
        }

        const nextPaymentReference = encodePaymentReferenceFromLines(mergedLines);
        const nextChangeAmount = resolvedMode === 'CASH'
            ? Math.max(nonCreditCollected - netAmount, 0)
            : 0;

        const noChange = previousMode === resolvedMode &&
            toAmount(sale.amount_paid) === amountPaid &&
            toAmount(sale.balance_due) === balanceDue &&
            previousPaymentReference === nextPaymentReference;
        if (noChange) {
            await t.commit();
            return res.json({
                success: true,
                message: 'Payment details already up to date',
                data: { sale_id: sale.id, sale_no: sale.sale_no, payment_mode: resolvedMode }
            });
        }

        await sale.update({
            payment_mode: resolvedMode,
            amount_paid: amountPaid,
            balance_due: balanceDue,
            change_amount: nextChangeAmount,
            payment_reference: nextPaymentReference
        }, { transaction: t });

        await req.propertyDb.models.cash_ledger.update(
            { payment_method: resolvedMode },
            {
                where: {
                    outlet_id: req.user.outlet_id,
                    reference_type: 'SALE',
                    reference_id: sale.id
                },
                transaction: t
            }
        );

        await req.propertyDb.models.cash_ledger.destroy({
            where: {
                outlet_id: req.user.outlet_id,
                reference_type: 'SALE',
                reference_id: sale.id,
                transaction_type: { [Op.in]: ['SALE_CASH', 'SALE_CREDIT'] }
            },
            transaction: t
        });

        const entryType = balanceDue > 0 ? 'SALE_CREDIT' : 'SALE_CASH';
        for (const row of nonCreditLines) {
            if (row.amount <= 0) continue;
            await createLedgerEntry({
                db: req.propertyDb,
                outlet_id: req.user.outlet_id,
                txn_date: sale.sale_date || new Date(),
                transaction_type: entryType,
                reference_type: 'SALE',
                reference_id: sale.id,
                reference_no: sale.sale_no,
                party_name: sale.customer_name || sale.customer_phone || 'Walk-in Customer',
                payment_method: row.method,
                amount_in: row.amount,
                notes: balanceDue > 0
                    ? `Sale ${sale.sale_no} payment updated with outstanding ${balanceDue.toFixed(2)}`
                    : `Payment updated for sale ${sale.sale_no}`,
                created_by: req.user.id,
                transaction: t
            });
        }

        const hasNonCredit = nonCreditLines.some(row => row.amount > 0);
        if (!hasNonCredit && balanceDue > 0) {
            await createLedgerEntry({
                db: req.propertyDb,
                outlet_id: req.user.outlet_id,
                txn_date: sale.sale_date || new Date(),
                transaction_type: 'SALE_CREDIT',
                reference_type: 'SALE',
                reference_id: sale.id,
                reference_no: sale.sale_no,
                party_name: sale.customer_name || sale.customer_phone || 'Walk-in Customer',
                payment_method: 'CREDIT',
                amount_in: 0,
                notes: `Sale ${sale.sale_no} payment updated with outstanding ${balanceDue.toFixed(2)}`,
                created_by: req.user.id,
                transaction: t
            });
        }

        await recalculateLedgerBalances({
            db: req.propertyDb,
            outlet_id: req.user.outlet_id,
            fromDate: sale.sale_date || new Date(),
            transaction: t
        });

        await audit.log({
            req,
            module: 'SALES',
            action: 'UPDATE_PAYMENT_MODE',
            table: 'sales_headers',
            recordId: sale.id,
            old_data: { payment_mode: previousMode, payment_reference: previousPaymentReference },
            new_data: { payment_mode: resolvedMode, payment_reference: nextPaymentReference },
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });

        await t.commit();
        return res.json({
            success: true,
            message: 'Payment mode updated and ledger synced',
            data: {
                sale_id: sale.id,
                sale_no: sale.sale_no,
                payment_mode: resolvedMode,
                previous_payment_mode: previousMode
            }
        });
    } catch (error) {
        await t.rollback();
        return res.status(error.status || 500).json({
            success: false,
            error: error.message
        });
    }
};
exports.listSales = async (req, res) => {
    try {
        const status = String(req.query.status || '').trim().toUpperCase();
        const search = String(req.query.search || '').trim();
        const latestOnly = String(req.query.latest_only || 'true').trim().toLowerCase() !== 'false';
        const fromDate = parseDateOnly(req.query.from_date);
        const toDate = parseDateOnly(req.query.to_date);
        const where = { outlet_id: req.user.outlet_id };
        if (status) {
            if (status === 'COMPLETED') {
                where.status = { [Op.in]: ['COMPLETED', 'RETURNED'] };
            } else {
                where.status = status;
            }
        }
        if (latestOnly) {
            where.is_latest = true;
            where.is_deleted = false;
        }

        if (fromDate || toDate) {
            where.sale_date = {};
            if (fromDate) {
                fromDate.setHours(0, 0, 0, 0);
                where.sale_date[Op.gte] = fromDate;
            }
            if (toDate) {
                toDate.setHours(23, 59, 59, 999);
                where.sale_date[Op.lte] = toDate;
            }
        }

        if (search) {
            where[Op.or] = [
                { sale_no: { [Op.iLike]: `%${search}%` } },
                { customer_name: { [Op.iLike]: `%${search}%` } },
                { customer_phone: { [Op.iLike]: `%${search}%` } }
            ];
        }
        const sales = await req.propertyDb.models.sales_headers.findAll({
            where,
            order: [['sale_date', 'DESC'], ['id', 'DESC']]
        });

        const saleIds = sales.map(s => s.id);
        const refunds = saleIds.length > 0 ? await req.propertyDb.models.sales_refunds.findAll({
            where: {
                outlet_id: req.user.outlet_id,
                sale_id: saleIds
            }
        }) : [];

        const refundsMap = {};
        for (const refund of refunds) {
            if (!refundsMap[refund.sale_id]) {
                refundsMap[refund.sale_id] = [];
            }
            refundsMap[refund.sale_id].push(refund);
        }

        const enrichedSales = sales.map(sale => {
            const saleJson = sale.toJSON();
            const saleRefunds = refundsMap[sale.id] || [];
            let totalRefundPaid = 0;
            let hasPending = false;
            let hasPaid = false;
            saleRefunds.forEach(r => {
                totalRefundPaid += Number(r.amount_paid || 0);
                if (r.status === 'PAID') hasPaid = true;
                if (r.status === 'PENDING') hasPending = true;
            });

            if (saleRefunds.length > 0) {
                saleJson.refund_amount = totalRefundPaid;
                if (hasPaid && hasPending) {
                    saleJson.refund_status = 'PARTIALLY_REFUNDED';
                } else if (hasPaid) {
                    saleJson.refund_status = 'REFUNDED';
                } else if (hasPending) {
                    saleJson.refund_status = 'PENDING';
                }
                const paidRefunds = saleRefunds.filter(r => r.status === 'PAID');
                if (paidRefunds.length > 0) {
                    paidRefunds.sort((a, b) => new Date(b.updated_at || b.refund_date) - new Date(a.updated_at || a.refund_date));
                    saleJson.refund_payment_mode = paidRefunds[0].payment_mode;
                    saleJson.refund_paid_at = paidRefunds[0].updated_at || paidRefunds[0].refund_date;
                }
            }
            return saleJson;
        });

        res.json({ success: true, data: enrichedSales });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.listCustomers = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const search = String(req.query.search || '').trim();

        const rows = await req.propertyDb.models.sales_headers.findAll({
            where: {
                outlet_id,
                status: { [Op.in]: ['COMPLETED', 'CUSTOMER'] },
                is_latest: true,
                is_deleted: false,
                [Op.or]: [
                    { customer_phone: { [Op.ne]: null } },
                    { customer_name: { [Op.ne]: null } },
                    { customer_gstin: { [Op.ne]: null } }
                ]
            },
            attributes: [
                'id',
                'customer_name',
                'customer_phone',
                'customer_address',
                'customer_gstin',
                'scheme_id',
                'scheme_name'
            ],
            order: [['id', 'DESC']]
        });

        const unique = new Map();
        const searchLower = search.toLowerCase();
        for (const row of rows) {
            const customerName = String(row.customer_name || '').trim();
            const customerPhone = String(row.customer_phone || '').trim();
            const customerAddress = String(row.customer_address || '').trim();
            const customerGstin = String(row.customer_gstin || '').trim().toUpperCase();

            if (!customerName && !customerPhone && !customerGstin) continue;

            if (searchLower) {
                const haystack = [
                    customerName.toLowerCase(),
                    customerPhone.toLowerCase(),
                    customerAddress.toLowerCase(),
                    customerGstin.toLowerCase()
                ];
                if (!haystack.some((value) => value.includes(searchLower))) {
                    continue;
                }
            }

            const key = customerPhone || customerGstin || customerName.toLowerCase();
            if (!unique.has(key)) {
                unique.set(key, row);
            }
        }

        res.json({ success: true, data: Array.from(unique.values()) });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.createCustomer = async (req, res) => {
    try {
        const identity = normalizeCustomerIdentity(req.body);
        const payload = {
            customer_name: identity.customer_name || null,
            customer_phone: identity.customer_phone || null,
            customer_address: String(req.body.customer_address || '').trim() || null,
            customer_gstin: identity.customer_gstin || null
        };
        const scope = buildCustomerScope(identity);
        if (!scope) {
            return res.status(400).json({ success: false, message: 'Customer name or phone is required' });
        }

        const existing = await req.propertyDb.models.sales_headers.findOne({
            where: {
                outlet_id: req.user.outlet_id,
                status: { [Op.in]: ['COMPLETED', 'CUSTOMER'] },
                is_latest: true,
                is_deleted: false,
                ...scope
            }
        });

        if (existing) {
            await existing.update({
                ...payload,
                status: existing.status || 'CUSTOMER'
            });
            return res.json({ success: true, data: existing });
        }

        const created = await req.propertyDb.models.sales_headers.create({
            outlet_id: req.user.outlet_id,
            sale_no: `CUST-${Date.now()}`,
            sale_date: new Date(),
            payment_mode: 'CASH',
            initial_amount_paid: 0,
            amount_paid: 0,
            change_amount: 0,
            balance_due: 0,
            billing_country: 'India',
            billing_tax_mode: 'CGST_SGST',
            bill_format: 'A4',
            tax_percent: 0,
            total_qty: 0,
            sub_total: 0,
            taxable_amount: 0,
            cgst_amount: 0,
            sgst_amount: 0,
            igst_amount: 0,
            total_tax: 0,
            tax_breakup: [],
            charges: [],
            charge_total: 0,
            charge_tax_total: 0,
            total_discount: 0,
            net_amount: 0,
            status: 'CUSTOMER',
            created_by: req.user.id,
            version_no: 1,
            is_latest: true,
            is_deleted: false,
            ...payload
        });

        res.json({ success: true, data: created });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.updateCustomer = async (req, res) => {
    try {
        const source = await req.propertyDb.models.sales_headers.findOne({
            where: {
                id: req.params.id,
                outlet_id: req.user.outlet_id
            }
        });

        if (!source) {
            return res.status(404).json({ success: false, message: 'Customer not found' });
        }

        const scope = buildCustomerScope(normalizeCustomerIdentity(source));
        const nextIdentity = normalizeCustomerIdentity(req.body);
        const payload = {
            customer_name: nextIdentity.customer_name || null,
            customer_phone: nextIdentity.customer_phone || null,
            customer_address: String(req.body.customer_address || '').trim() || null,
            customer_gstin: nextIdentity.customer_gstin || null
        };
        const advancePayload = {
            customer_name: payload.customer_name,
            customer_phone: payload.customer_phone,
            customer_gstin: payload.customer_gstin
        };

        await req.propertyDb.models.sales_headers.update(
            payload,
            {
                where: {
                    outlet_id: req.user.outlet_id,
                    ...(scope ?? { id: source.id })
                }
            }
        );
        await req.propertyDb.models.customer_advances.update(
            advancePayload,
            {
                where: {
                    outlet_id: req.user.outlet_id,
                    ...(scope ?? { id: -1 })
                }
            }
        );

        res.json({ success: true, data: payload });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.deleteCustomer = async (req, res) => {
    try {
        const source = await req.propertyDb.models.sales_headers.findOne({
            where: {
                id: req.params.id,
                outlet_id: req.user.outlet_id
            }
        });

        if (!source) {
            return res.status(404).json({ success: false, message: 'Customer not found' });
        }

        const identity = normalizeCustomerIdentity(source);
        const scope = buildCustomerScope(identity);
        if (!scope) {
            return res.status(400).json({
                success: false,
                message: 'Unable to resolve customer identity for delete'
            });
        }

        const outlet_id = req.user.outlet_id;
        const [
            linkedSalesCount,
            linkedAdvancesCount,
            linkedItemAdvancesCount,
            linkedSchemeCustomerCount,
            linkedSubscriptionsCount,
            linkedLoyaltyCount
        ] = await Promise.all([
            req.propertyDb.models.sales_headers.count({
                where: {
                    outlet_id,
                    status: 'COMPLETED',
                    is_latest: true,
                    is_deleted: false,
                    ...scope
                }
            }),
            req.propertyDb.models.customer_advances.count({
                where: { outlet_id, ...scope }
            }),
            req.propertyDb.models.customer_item_advances.count({
                where: { outlet_id, ...scope }
            }),
            req.propertyDb.models.sales_scheme_customers.count({
                where: { outlet_id, ...scope }
            }),
            req.propertyDb.models.milk_subscriptions.count({
                where: { outlet_id, ...scope }
            }),
            req.propertyDb.models.customer_loyalty_ledger.count({
                where: { outlet_id, ...scope }
            })
        ]);

        const totalLinked =
            linkedSalesCount +
            linkedAdvancesCount +
            linkedItemAdvancesCount +
            linkedSchemeCustomerCount +
            linkedSubscriptionsCount +
            linkedLoyaltyCount;

        if (totalLinked > 0) {
            return res.status(400).json({
                success: false,
                message:
                    'Customer cannot be deleted because linked transactions exist. Please keep customer history.',
                data: {
                    linked_sales: linkedSalesCount,
                    linked_advances: linkedAdvancesCount,
                    linked_item_advances: linkedItemAdvancesCount,
                    linked_scheme_customers: linkedSchemeCustomerCount,
                    linked_subscriptions: linkedSubscriptionsCount,
                    linked_loyalty: linkedLoyaltyCount
                }
            });
        }

        // Delete only customer master row(s). Never wipe customer data from historical bills.
        const deleted = await req.propertyDb.models.sales_headers.update(
            {
                is_deleted: true,
                is_latest: false,
                modified_by: req.user.id,
                modified_at: new Date(),
                modification_note: 'Customer deleted from customer list'
            },
            {
                where: {
                    outlet_id,
                    status: 'CUSTOMER',
                    ...scope
                }
            }
        );

        if (!deleted || deleted[0] === 0) {
            return res.status(404).json({
                success: false,
                message: 'Customer master record not found for deletion'
            });
        }

        res.json({ success: true, message: 'Customer deleted successfully' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getSaleDetails = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        let sale = await req.propertyDb.models.sales_headers.findOne({
            where: {
                [Op.or]: [
                    { id: isNaN(Number(req.params.id)) ? -1 : Number(req.params.id) },
                    { sale_no: req.params.id }
                ],
                outlet_id
            },
            include: [
                {
                    model: req.propertyDb.models.sales_items,
                    as: 'items',
                    include: [
                        {
                            model: req.propertyDb.models.item_master,
                            as: 'item',
                            attributes: ['id', 'rate', 'retail_sale_price', 'tax_type', 'tax_percent', 'brand']
                        }
                    ]
                },
                {
                    model: req.propertyDb.models.customer_repayments,
                    as: 'repayments',
                    required: false
                }
            ]
        });

        if (!sale) {
            sale = await req.propertyDb.models.sales_headers.findOne({
                where: {
                    [Op.or]: [
                        { id: isNaN(Number(req.params.id)) ? -1 : Number(req.params.id) },
                        { sale_no: req.params.id }
                    ]
                },
                include: [
                    {
                        model: req.propertyDb.models.sales_items,
                        as: 'items',
                        include: [
                            {
                                model: req.propertyDb.models.item_master,
                                as: 'item',
                                attributes: ['id', 'rate', 'retail_sale_price', 'tax_type', 'tax_percent', 'brand']
                            }
                        ]
                    },
                    {
                        model: req.propertyDb.models.customer_repayments,
                        as: 'repayments',
                        required: false
                    }
                ]
            });
        }

        if (!sale) {
            return res.status(404).json({ success: false, message: 'Sale not found' });
        }

        // Load all credit notes for this sale to compute returned quantities
        const creditNotes = await req.propertyDb.models.sales_credit_notes.findAll({
            where: { sale_id: sale.id, outlet_id }
        });

        const alreadyReturned = {};
        creditNotes.forEach(cn => {
            if (Array.isArray(cn.items)) {
                cn.items.forEach(it => {
                    alreadyReturned[it.item_id] = (alreadyReturned[it.item_id] || 0) + Number(it.qty);
                });
            }
        });

        const saleJson = sale.toJSON();
        saleJson.items = saleJson.items.map(item => {
            return {
                ...item,
                returned_qty: alreadyReturned[item.item_id] || 0
            };
        });
        saleJson.credit_notes = creditNotes;

        // Load all refunds for this sale
        const refunds = await req.propertyDb.models.sales_refunds.findAll({
            where: { sale_id: sale.id, outlet_id }
        });

        saleJson.refunds = refunds;
        let totalRefundPaid = 0;
        let hasPending = false;
        let hasPaid = false;
        refunds.forEach(r => {
            totalRefundPaid += Number(r.amount_paid || 0);
            if (r.status === 'PAID') hasPaid = true;
            if (r.status === 'PENDING') hasPending = true;
        });

        if (refunds.length > 0) {
            saleJson.refund_amount = totalRefundPaid;
            if (hasPaid && hasPending) {
                saleJson.refund_status = 'PARTIALLY_REFUNDED';
            } else if (hasPaid) {
                saleJson.refund_status = 'REFUNDED';
            } else if (hasPending) {
                saleJson.refund_status = 'PENDING';
            }
            const paidRefunds = refunds.filter(r => r.status === 'PAID');
            if (paidRefunds.length > 0) {
                paidRefunds.sort((a, b) => new Date(b.updated_at || b.refund_date) - new Date(a.updated_at || a.refund_date));
                saleJson.refund_payment_mode = paidRefunds[0].payment_mode;
                saleJson.refund_paid_at = paidRefunds[0].updated_at || paidRefunds[0].refund_date;
            }
        }

        // Load all lucky draw vouchers for this sale
        try {
            const vouchers = await req.propertyDb.models.draw_vouchers.findAll({
                where: { sale_id: sale.id, outlet_id },
                include: [{
                    model: req.propertyDb.models.lucky_draw_campaigns,
                    as: 'campaign',
                    attributes: ['name', 'description']
                }]
            });
            saleJson.lucky_draw_vouchers = vouchers.map(v => ({
                code: v.voucher_code,
                campaign_name: v.campaign?.name || 'Lucky Draw',
                campaign_description: v.campaign?.description,
                customer_phone: v.customer_phone,
                customer_name: v.customer_name
            }));
        } catch (ldErr) {
            console.error('[LUCKY DRAW DETAILS FETCH FAIL]', ldErr.message);
            saleJson.lucky_draw_vouchers = [];
        }

        res.json({ success: true, data: saleJson });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.deleteDraft = async (req, res) => {
    try {
        const draft = await req.propertyDb.models.sales_headers.findOne({
            where: {
                id: req.params.id,
                outlet_id: req.user.outlet_id,
                status: 'DRAFT'
            }
        });

        if (!draft) {
            return res.status(404).json({ success: false, message: 'Draft not found' });
        }

        await req.propertyDb.models.sales_items.destroy({
            where: { sale_id: draft.id }
        });
        await draft.destroy();

        res.json({ success: true, message: 'Draft cleared successfully' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.createScheme = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const created_by = req.user.id;

        const scheme = await req.propertyDb.models.sales_schemes.create({
            outlet_id,
            scheme_name: req.body.scheme_name,
            scheme_type: req.body.scheme_type,
            scheme_scope: req.body.scheme_scope || 'ORDER',
            discount_type: req.body.discount_type,
            discount_value: req.body.discount_value || 0,
            start_time: req.body.start_time || null,
            end_time: req.body.end_time || null,
            min_qty: req.body.min_qty || 0,
            min_amount: req.body.min_amount || 0,
            item_id: req.body.item_id || null,
            required_daily_qty: req.body.required_daily_qty || 0,
            free_qty: req.body.free_qty || 0,
            cycle_days: req.body.cycle_days || 30,
            require_no_gaps: req.body.require_no_gaps ?? false,
            repeat_mode: normalizeSchemeMode(
                req.body.repeat_mode,
                'REPEAT',
                ['REPEAT', 'ONCE']
            ),
            apply_timing: normalizeSchemeMode(
                req.body.apply_timing,
                'CURRENT_BILL',
                ['CURRENT_BILL', 'NEXT_PURCHASE']
            ),
            auto_select_on_customer: req.body.auto_select_on_customer ?? true,
            next_purchase_valid_days: Number(req.body.next_purchase_valid_days) || 7,
            is_active: req.body.is_active ?? true,
            created_by
        });

        res.json({ success: true, data: scheme });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.updateScheme = async (req, res) => {
    try {
        const scheme = await req.propertyDb.models.sales_schemes.findOne({
            where: {
                id: req.params.id,
                outlet_id: req.user.outlet_id
            }
        });

        if (!scheme) {
            return res.status(404).json({ success: false, message: 'Scheme not found' });
        }

        await scheme.update({
            scheme_name: req.body.scheme_name ?? scheme.scheme_name,
            scheme_type: req.body.scheme_type ?? scheme.scheme_type,
            scheme_scope: req.body.scheme_scope ?? scheme.scheme_scope ?? 'ORDER',
            discount_type: req.body.discount_type ?? scheme.discount_type,
            discount_value: req.body.discount_value ?? scheme.discount_value,
            start_time: req.body.start_time ?? null,
            end_time: req.body.end_time ?? null,
            min_qty: req.body.min_qty ?? 0,
            min_amount: req.body.min_amount ?? 0,
            item_id: req.body.item_id ?? scheme.item_id,
            required_daily_qty: req.body.required_daily_qty ?? scheme.required_daily_qty,
            free_qty: req.body.free_qty ?? scheme.free_qty,
            cycle_days: req.body.cycle_days ?? scheme.cycle_days,
            require_no_gaps: req.body.require_no_gaps ?? scheme.require_no_gaps,
            repeat_mode: normalizeSchemeMode(
                req.body.repeat_mode ?? scheme.repeat_mode,
                scheme.repeat_mode || 'REPEAT',
                ['REPEAT', 'ONCE']
            ),
            apply_timing: normalizeSchemeMode(
                req.body.apply_timing ?? scheme.apply_timing,
                scheme.apply_timing || 'CURRENT_BILL',
                ['CURRENT_BILL', 'NEXT_PURCHASE']
            ),
            auto_select_on_customer:
                req.body.auto_select_on_customer ?? scheme.auto_select_on_customer,
            next_purchase_valid_days:
                req.body.next_purchase_valid_days ?? scheme.next_purchase_valid_days,
            is_active: req.body.is_active ?? scheme.is_active
        });

        res.json({ success: true, data: scheme });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.deleteScheme = async (req, res) => {
    try {
        const scheme = await req.propertyDb.models.sales_schemes.findOne({
            where: {
                id: req.params.id,
                outlet_id: req.user.outlet_id
            }
        });

        if (!scheme) {
            return res.status(404).json({ success: false, message: 'Scheme not found' });
        }

        await scheme.destroy();
        res.json({ success: true, message: 'Scheme deleted successfully' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.listSchemes = async (req, res) => {
    try {
        const identity = normalizeCustomerIdentity(req.query);
        const scope = buildSchemeCustomerScope(identity);
        const consumedIds = await getConsumedSingleUseSchemeIds(req, identity);
        const schemes = await req.propertyDb.models.sales_schemes.findAll({
            where: {
                outlet_id: req.user.outlet_id,
                is_active: true,
                ...(consumedIds.size
                    ? { id: { [Op.notIn]: Array.from(consumedIds) } }
                    : {})
            },
            order: [['scheme_name', 'ASC']]
        });

        let customerLinks = [];
        if (scope) {
            customerLinks = await req.propertyDb.models.sales_scheme_customers.findAll({
                where: {
                    outlet_id: req.user.outlet_id,
                    is_active: true,
                    ...scope
                },
                attributes: [
                    'scheme_id',
                    'usage_type',
                    'is_consumed',
                    'start_date'
                ]
            });
        }
        const today = dateOnly(new Date());
        const linkBySchemeId = new Map();
        for (const row of customerLinks) {
            const schemeId = Number(row.scheme_id);
            if (!Number.isFinite(schemeId) || schemeId <= 0) continue;
            const startDate = row.start_date ? dateOnly(row.start_date) : null;
            const hasStarted = !startDate || !today || startDate.getTime() <= today.getTime();
            const usageType = normalizeUsageType(row.usage_type, 'reusable');
            const isConsumed = row.is_consumed === true;
            const usable = hasStarted && !(usageType === 'single_use' && isConsumed);
            if (!linkBySchemeId.has(schemeId)) {
                linkBySchemeId.set(schemeId, usable);
            } else if (usable) {
                linkBySchemeId.set(schemeId, true);
            }
        }

        const data = schemes.map((scheme) => ({
            ...scheme.toJSON(),
            customer_linked: linkBySchemeId.get(Number(scheme.id)) === true
        }));

        res.json({ success: true, data });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.listSchemeCustomers = async (req, res) => {
    try {
        const schemeId = Number(req.params.id);
        if (!Number.isFinite(schemeId) || schemeId <= 0) {
            return res.status(400).json({ success: false, message: 'Invalid scheme id' });
        }

        const customers = await req.propertyDb.models.sales_scheme_customers.findAll({
            where: {
                outlet_id: req.user.outlet_id,
                scheme_id: schemeId
            },
            order: [['id', 'DESC']]
        });

        res.json({ success: true, data: customers });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.createSchemeCustomer = async (req, res) => {
    try {
        const schemeId = Number(req.params.id);
        if (!Number.isFinite(schemeId) || schemeId <= 0) {
            return res.status(400).json({ success: false, message: 'Invalid scheme id' });
        }

        const scheme = await req.propertyDb.models.sales_schemes.findOne({
            where: {
                id: schemeId,
                outlet_id: req.user.outlet_id
            }
        });
        if (!scheme) {
            return res.status(404).json({ success: false, message: 'Scheme not found' });
        }

        const identity = normalizeCustomerIdentity(req.body);
        const scope = buildCustomerScope(identity);
        if (!scope) {
            return res.status(400).json({
                success: false,
                message: 'Customer phone or GSTIN or name is required'
            });
        }

        const startDate = req.body.start_date || req.body.startDate;
        const parsedStart = parseDateOnly(startDate);
        if (!parsedStart) {
            return res.status(400).json({ success: false, message: 'Valid start_date is required' });
        }
        const usageType = normalizeUsageType(
            req.body.usage_type ?? req.body.usageType,
            String(scheme.repeat_mode || '').trim().toUpperCase() === 'ONCE'
                ? 'single_use'
                : 'reusable'
        );

        const created = await req.propertyDb.models.sales_scheme_customers.create({
            outlet_id: req.user.outlet_id,
            scheme_id: schemeId,
            customer_name: identity.customer_name || null,
            customer_phone: identity.customer_phone || null,
            customer_gstin: identity.customer_gstin || null,
            start_date: parsedStart,
            usage_type: usageType,
            is_consumed: req.body.is_consumed === true,
            last_applied_cycle_start: null,
            last_applied_cycle_end: null,
            is_active: req.body.is_active !== false,
            created_by: req.user.id
        });

        res.json({ success: true, data: created });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.updateSchemeCustomer = async (req, res) => {
    try {
        const schemeId = Number(req.params.id);
        const customerId = Number(req.params.customerId);
        if (!Number.isFinite(schemeId) || schemeId <= 0) {
            return res.status(400).json({ success: false, message: 'Invalid scheme id' });
        }
        if (!Number.isFinite(customerId) || customerId <= 0) {
            return res.status(400).json({ success: false, message: 'Invalid customer id' });
        }

        const row = await req.propertyDb.models.sales_scheme_customers.findOne({
            where: {
                id: customerId,
                outlet_id: req.user.outlet_id,
                scheme_id: schemeId
            }
        });
        if (!row) {
            return res.status(404).json({ success: false, message: 'Enrollment not found' });
        }

        const updates = {};
        if (req.body.start_date || req.body.startDate) {
            const parsedStart = parseDateOnly(req.body.start_date || req.body.startDate);
            if (!parsedStart) {
                return res.status(400).json({ success: false, message: 'Invalid start_date' });
            }
            updates.start_date = parsedStart;
        }
        if (typeof req.body.is_active === 'boolean') {
            updates.is_active = req.body.is_active;
        }
        if (req.body.usage_type || req.body.usageType) {
            updates.usage_type = normalizeUsageType(req.body.usage_type ?? req.body.usageType);
        }
        if (typeof req.body.is_consumed === 'boolean') {
            updates.is_consumed = req.body.is_consumed;
        }

        await row.update(updates);
        res.json({ success: true, data: row });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getSchemeProgress = async (req, res) => {
    try {
        const schemeId = Number(req.params.id);
        if (!Number.isFinite(schemeId) || schemeId <= 0) {
            return res.status(400).json({ success: false, message: 'Invalid scheme id' });
        }

        const scheme = await req.propertyDb.models.sales_schemes.findOne({
            where: {
                id: schemeId,
                outlet_id: req.user.outlet_id,
                is_active: true
            }
        });
        if (!scheme) {
            return res.status(404).json({ success: false, message: 'Scheme not found' });
        }

        const identity = normalizeCustomerIdentity(req.query);
        const enrollment = await findSchemeEnrollment(req, schemeId, identity);
        if (!enrollment) {
            return res.json({
                success: true,
                data: {
                    enrolled: false
                }
            });
        }

        const billDate = req.query.date || new Date();
        const progress = await computeItemCycleProgress({
            req,
            scheme,
            enrollment,
            identity,
            billDate,
            currentBillItems: []
        });
        const alreadyGrantedThisCycle =
            String(enrollment.last_applied_cycle_start || '') === String(progress?.cycle_start || '') &&
            String(enrollment.last_applied_cycle_end || '') === String(progress?.cycle_end || '');
        const alreadyGrantedToday = await hasSchemeGrantedToday({
            req,
            schemeId,
            itemId: Number(scheme.item_id),
            identity,
            billDate
        });

        res.json({
            success: true,
            data: {
                enrolled: true,
                enrollment,
                progress: {
                    ...progress,
                    already_granted_this_cycle: alreadyGrantedThisCycle,
                    already_granted_today: alreadyGrantedToday
                }
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.listSubscriptions = async (req, res) => {
    try {
        const search = String(req.query.search || '').trim().toLowerCase();
        const status = String(req.query.status || '').trim().toUpperCase();

        console.log("[DEBUG listSubscriptions] Received request. Query:", req.query);
        console.log("[DEBUG listSubscriptions] User resolved:", req.user);

        const where = { outlet_id: req.user.outlet_id };
        if (status === 'ACTIVE' || status === 'EXPIRED' || status === 'SETTLED' || status === 'CANCELLED') {
            where.status = status;
        }

        console.log("[DEBUG listSubscriptions] Where clause:", where);

        const subscriptions = await req.propertyDb.models.milk_subscriptions.findAll({
            where,
            include: [
                { model: req.propertyDb.models.item_master, as: 'item', required: false },
                { model: req.propertyDb.models.milk_subscription_schemes, as: 'schemes', required: false },
                { model: req.propertyDb.models.milk_subscription_consumptions, as: 'consumptions', required: false }
            ],
            order: [['created_at', 'DESC'], ['id', 'DESC']]
        });

        console.log("[DEBUG listSubscriptions] Found subscriptions count:", subscriptions.length);

        const data = [];
        for (const subscription of subscriptions) {
            const itemName = subscription.item?.item_name || subscription.item_name || '';
            const customerName = subscription.customer_name || '';
            const customerPhone = subscription.customer_phone || '';
            const haystack = [
                itemName,
                customerName,
                customerPhone,
                subscription.customer_gstin || ''
            ].join(' ').toLowerCase();

            let consumptions = Array.isArray(subscription.consumptions) ? subscription.consumptions : [];
            if (consumptions.length === 0) {
                consumptions = await loadSubscriptionConsumptionRows(req, subscription);
            }
            const advanceSummary = await getSubscriptionItemAdvanceSummary(req, subscription);
            const cashAdvanceSummary = await getSubscriptionCustomerAdvanceSummary(req, subscription);
            data.push({
                ...subscription.toJSON(),
                active_subscription: subscription.active_subscription === true && subscription.status === 'ACTIVE',
                scheme_totals: {
                    bonus_qty: sumNumeric(subscription.schemes, 'bonus_qty'),
                    discount_amount: sumNumeric(subscription.schemes, 'discount_amount')
                },
                advance_summary: advanceSummary,
                advance_original_qty: advanceSummary.original_qty,
                advance_consumed_qty: advanceSummary.consumed_qty,
                advance_remaining_qty: advanceSummary.available_qty,
                advance_rate: advanceSummary.rate,
                advance_original_amount: cashAdvanceSummary.original_amount || advanceSummary.original_amount,
                advance_consumed_amount: cashAdvanceSummary.consumed_amount || advanceSummary.consumed_amount,
                advance_remaining_amount: cashAdvanceSummary.available_amount || advanceSummary.available_amount,
                ...buildSubscriptionMetrics(subscription, consumptions),
                search_index: haystack
            });
        }

        const filtered = data.filter((entry) => !search || entry.search_index.includes(search));

        res.json({ success: true, data: filtered });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.listCustomerSubscriptions = async (req, res) => {
    try {
        await resolveOutletId(req);
        const identity = normalizeCustomerIdentity(req.query);
        const scope = buildCustomerScope(identity);
        if (!scope) {
            return res.status(400).json({ success: false, message: 'Customer name or phone is required' });
        }

        const today = req.query.date || new Date();
        const asOfDay = formatDateLocalYmd(today);
        const subscriptions = await req.propertyDb.models.milk_subscriptions.findAll({
            where: {
                outlet_id: req.user.outlet_id,
                ...scope
            },
            include: [
                { model: req.propertyDb.models.item_master, as: 'item', required: false },
                { model: req.propertyDb.models.milk_subscription_schemes, as: 'schemes', required: false }
            ],
            order: [['start_date', 'DESC'], ['id', 'DESC']]
        });

        const rows = [];
        const remainingAssignedByItem = new Set();
        for (const subscription of subscriptions) {
            const coveredRows = await loadSubscriptionConsumptionRows(req, subscription);
            const advanceSummary = await getSubscriptionItemAdvanceSummary(req, subscription);
            const cashAdvanceSummary = await getSubscriptionCustomerAdvanceSummary(req, subscription);
            const itemId = Number(subscription.item_id) || 0;
            const todayConsumedQty = await getCustomerItemConsumedQtyForDay(
                req,
                identity,
                itemId,
                today
            );
            const dailyLimit = toAmount(subscription.daily_allowed_qty);
            const todayRemainingForItem = Math.max(dailyLimit - todayConsumedQty, 0);
            const assignKey = `${itemId}`;
            const alreadyAssignedForItem = remainingAssignedByItem.has(assignKey);
            const todayRemainingQty = alreadyAssignedForItem ? 0 : todayRemainingForItem;
            if (!alreadyAssignedForItem) {
                remainingAssignedByItem.add(assignKey);
            }
            rows.push({
                ...subscription.toJSON(),
                scheme_totals: {
                    bonus_qty: sumNumeric(subscription.schemes, 'bonus_qty'),
                    discount_amount: sumNumeric(subscription.schemes, 'discount_amount')
                },
                advance_summary: advanceSummary,
                advance_original_qty: advanceSummary.original_qty,
                advance_consumed_qty: advanceSummary.consumed_qty,
                advance_remaining_qty: advanceSummary.available_qty,
                advance_rate: advanceSummary.rate,
                advance_original_amount: cashAdvanceSummary.original_amount || advanceSummary.original_amount,
                advance_consumed_amount: cashAdvanceSummary.consumed_amount || advanceSummary.consumed_amount,
                advance_remaining_amount: cashAdvanceSummary.available_amount || advanceSummary.available_amount,
                today_consumed_qty: todayConsumedQty,
                today_remaining_qty: todayRemainingQty,
                daily_allowed_qty: dailyLimit,
                consumption: coveredRows.map((row) => row.toJSON()),
                active_subscription: subscription.active_subscription === true && subscription.status === 'ACTIVE',
                ...buildSubscriptionMetrics(subscription, coveredRows)
            });
        }

        res.json({ success: true, data: rows });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getSubscriptionDetails = async (req, res) => {
    try {
        await resolveOutletId(req);
        const subscriptionId = Number(req.params.id);
        if (!Number.isFinite(subscriptionId) || subscriptionId <= 0) {
            return res.status(400).json({ success: false, message: 'Invalid subscription id' });
        }

        const ledger = await buildSubscriptionLedgerResponse(req, subscriptionId);
        if (!ledger) {
            return res.status(404).json({ success: false, message: 'Subscription not found' });
        }

        res.json({
            success: true,
            data: {
                ...ledger.subscription.toJSON(),
                scheme_totals: await getSubscriptionSchemeTotals(ledger.subscription),
                financial_summary: await buildSubscriptionFinancialSummary(
                    req,
                    ledger.subscription,
                    ledger.consumptions.map((row) => row.toJSON())
                ),
                advance_summary: await getSubscriptionItemAdvanceSummary(req, ledger.subscription),
                cash_advance_summary: await getSubscriptionCustomerAdvanceSummary(req, ledger.subscription),
                consumptions: ledger.consumptions.map((row) => row.toJSON()),
                settlements: ledger.settlements.map((row) => row.toJSON())
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.createSubscription = async (req, res) => {
    const outlet_id = await resolveOutletId(req);
    if (!outlet_id) {
        return res.status(400).json({ success: false, message: 'Valid outlet_id is required' });
    }
    const t = await req.propertyDb.transaction();
    try {
        const identity = normalizeCustomerIdentity(req.body);
        const scope = buildCustomerScope(identity);
        if (!scope) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Customer name or phone is required' });
        }

        const itemId = Number(req.body.item_id);
        if (!Number.isFinite(itemId) || itemId <= 0) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Valid item_id is required' });
        }

        const item = await req.propertyDb.models.item_master.findOne({
            where: {
                id: itemId,
                outlet_id: req.user.outlet_id
            },
            transaction: t
        });
        if (!item) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Item not found' });
        }

        const startDate = parseDateOnly(req.body.start_date || req.body.startDate);
        const endDate = parseDateOnly(req.body.end_date || req.body.endDate);
        if (!startDate || !endDate) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Valid start_date and end_date are required' });
        }

        const existingSubscriptions = await req.propertyDb.models.milk_subscriptions.findAll({
            where: {
                outlet_id: req.user.outlet_id,
                status: { [Op.ne]: 'CANCELLED' }
            },
            include: [
                {
                    model: req.propertyDb.models.item_master,
                    as: 'item',
                    required: false
                }
            ],
            order: [['start_date', 'DESC'], ['id', 'DESC']],
            transaction: t
        });
        const duplicateMatch = existingSubscriptions.find((row) => {
            // Must be the exact same item variant (item_code is unique per variant)
            const rowItemCode = row.item ? row.item.item_code : '';
            if (rowItemCode !== item.item_code) return false;

            const rowIdentity = normalizeCustomerIdentity(row.toJSON());
            const samePhone = identity.customer_phone && rowIdentity.customer_phone
                ? identity.customer_phone === rowIdentity.customer_phone
                : false;
            const sameGstin = identity.customer_gstin && rowIdentity.customer_gstin
                ? identity.customer_gstin === rowIdentity.customer_gstin
                : false;
            const sameName = identity.customer_name && rowIdentity.customer_name
                ? identity.customer_name.toLowerCase() === rowIdentity.customer_name.toLowerCase()
                : false;
            const sameCustomer = samePhone || sameGstin || sameName;
            if (!sameCustomer) return false;
            return String(row.start_date || '') === String(req.body.start_date || req.body.startDate || '') &&
                String(row.end_date || '') === String(req.body.end_date || req.body.endDate || '') &&
                String(row.delivery_type || '').toUpperCase() === String(req.body.delivery_type || 'HOME').trim().toUpperCase();
        });
        if (duplicateMatch) {
            await t.rollback();
            return res.status(409).json({
                success: false,
                message: 'An identical subscription already exists for this customer and period.',
                data: duplicateMatch.toJSON()
            });
        }

        const overlappingMatch = existingSubscriptions.find((row) => {
            // Must be the exact same item variant (item_code is unique per variant)
            const rowItemCode = row.item ? row.item.item_code : '';
            if (rowItemCode !== item.item_code) return false;

            const rowIdentity = normalizeCustomerIdentity(row.toJSON());
            const samePhone = identity.customer_phone && rowIdentity.customer_phone
                ? identity.customer_phone === rowIdentity.customer_phone
                : false;
            const sameGstin = identity.customer_gstin && rowIdentity.customer_gstin
                ? identity.customer_gstin === rowIdentity.customer_gstin
                : false;
            const sameName = identity.customer_name && rowIdentity.customer_name
                ? identity.customer_name.toLowerCase() === rowIdentity.customer_name.toLowerCase()
                : false;
            const sameCustomer = samePhone || sameGstin || sameName;
            if (!sameCustomer) return false;
            const rowStart = parseDateOnly(row.start_date);
            const rowEnd = parseDateOnly(row.end_date);
            if (!rowStart || !rowEnd) return false;
            return rowStart <= endDate && rowEnd >= startDate;
        });
        if (overlappingMatch) {
            await t.rollback();
            return res.status(409).json({
                success: false,
                message: 'An overlapping active subscription already exists for this customer and item.',
                data: overlappingMatch.toJSON()
            });
        }

        const selectedSchemes = normalizeSelectedSchemes(req.body.selected_schemes || req.body.selectedSchemes);
        const schemeTotals = selectedSchemes.reduce((acc, scheme) => {
            acc.scheme_discount_amount += toRoundedAmount(scheme.discount_amount);
            acc.bonus_qty += toRoundedAmount(scheme.bonus_qty);
            return acc;
        }, { scheme_discount_amount: 0, bonus_qty: 0 });
        const bonusQty = toRoundedAmount(req.body.bonus_qty ?? req.body.bonusQty ?? 0);
        const itemRate = toRoundedAmount(
            req.body.item_rate ?? req.body.itemRate ?? item.retail_sale_price ?? item.rate
        );
        const baseTaxableFromBody = toRoundedAmount(
            req.body.taxable_amount ?? req.body.taxableAmount ?? req.body.base_amount ?? req.body.baseAmount
        );
        const taxPercent = toRoundedAmount(req.body.tax_percent ?? req.body.taxPercent ?? item.tax_percent);
        const taxAmountFromBody = toRoundedAmount(req.body.tax_amount ?? req.body.taxAmount);
        const derivedTaxAmount = taxAmountFromBody > 0
            ? taxAmountFromBody
            : toRoundedAmount((baseTaxableFromBody * taxPercent) / 100);
        const totalPaymentAmount = toRoundedAmount(
            req.body.total_payment_amount ??
            req.body.totalPaymentAmount ??
            (baseTaxableFromBody + derivedTaxAmount)
        );

        const subscription = await req.propertyDb.models.milk_subscriptions.create({
            outlet_id: req.user.outlet_id,
            customer_name: identity.customer_name || null,
            customer_phone: identity.customer_phone || null,
            customer_gstin: identity.customer_gstin || null,
            customer_address: String(req.body.customer_address || '').trim() || null,
            item_id: itemId,
            item_name: item.item_name,
            start_date: startDate,
            end_date: endDate,
            daily_allowed_qty: toRoundedAmount(req.body.daily_allowed_qty ?? req.body.dailyAllowedQty),
            total_payment_amount: totalPaymentAmount,
            scheme_discount_amount: schemeTotals.scheme_discount_amount,
            bonus_qty: schemeTotals.bonus_qty + bonusQty,
            selected_schemes: selectedSchemes,
            // App self-subscriptions need to flow through the home-delivery job.
            // Retailer-created records still override this explicitly from the UI.
            delivery_type: String(req.body.delivery_type || 'HOME').trim().toUpperCase(),
            status: 'ACTIVE',
            active_subscription: true,
            created_by: req.user.id,
            updated_by: req.user.id
        }, { transaction: t });

        const prepaidAmount = totalPaymentAmount;
        const paymentMode = String(req.body.payment_mode || req.body.paymentMode || 'SUBSCRIPTION').trim().toUpperCase();
        const prepaidTaxableAmount = baseTaxableFromBody > 0 ? baseTaxableFromBody : prepaidAmount;
        const prepaidQty = itemRate > 0 ? toRoundedAmount(prepaidTaxableAmount / itemRate) : 0;
          if (prepaidAmount > 0 && prepaidQty > 0) {
              await req.propertyDb.models.customer_advances.create({
                  outlet_id: req.user.outlet_id,
                  source_sale_id: null,
                  customer_name: identity.customer_name || null,
                  customer_phone: identity.customer_phone || null,
                  customer_gstin: identity.customer_gstin || null,
                advance_date: startDate,
                original_amount: prepaidAmount,
                available_amount: prepaidAmount,
                payment_mode: paymentMode,
                reference_no: getSubscriptionReferenceNo(subscription.id),
                note: `Subscription prepaid amount for ${item.item_name}`,
                created_by: req.user.id,
                updated_by: req.user.id
            }, { transaction: t });

              await req.propertyDb.models.customer_item_advances.create({
                  outlet_id: req.user.outlet_id,
                  source_sale_id: null,
                  customer_name: identity.customer_name || null,
                  customer_phone: identity.customer_phone || null,
                  customer_gstin: identity.customer_gstin || null,
                item_id: item.id,
                advance_date: startDate,
                  original_qty: prepaidQty,
                  available_qty: prepaidQty,
                  rate: itemRate,
                  note: `Subscription #${subscription.id} prepaid qty for ${item.item_name}`,
                  created_by: req.user.id,
                  updated_by: req.user.id
              }, { transaction: t });

            await createLedgerEntry({
                db: req.propertyDb,
                outlet_id: req.user.outlet_id,
                txn_date: startDate,
                transaction_type: 'CUSTOMER_ADVANCE',
                reference_type: 'SUBSCRIPTION',
                reference_id: subscription.id,
                reference_no: getSubscriptionReferenceNo(subscription.id),
                party_name: identity.customer_name || identity.customer_phone || 'Subscription Customer',
                payment_method: paymentMode,
                amount_in: prepaidAmount,
                notes: `Prepaid subscription amount for ${item.item_name}`,
                created_by: req.user.id,
                transaction: t
            });
        }

        for (const scheme of selectedSchemes) {
            await req.propertyDb.models.milk_subscription_schemes.create({
                outlet_id: req.user.outlet_id,
                subscription_id: subscription.id,
                scheme_type: scheme.scheme_type,
                scheme_name: scheme.scheme_name,
                scheme_value: toRoundedAmount(scheme.scheme_value),
                bonus_qty: toRoundedAmount(scheme.bonus_qty),
                discount_amount: toRoundedAmount(scheme.discount_amount),
                notes: scheme.notes,
                created_by: req.user.id
            }, { transaction: t });
        }

        await audit.log({
            req,
            module: 'SALES',
            action: 'CREATE',
            table: 'milk_subscriptions',
            recordId: subscription.id,
            new_data: subscription.toJSON(),
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });

        await t.commit();
        res.json({
            success: true,
            data: {
                ...subscription.toJSON(),
                item_name: item.item_name,
                selected_schemes: selectedSchemes,
                taxable_amount: prepaidTaxableAmount,
                tax_percent: taxPercent,
                tax_amount: derivedTaxAmount,
                total_payment_amount: totalPaymentAmount,
                item_rate: itemRate
            }
        });
    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getSubscriptionLedger = async (req, res) => {
    try {
        await resolveOutletId(req);
        const subscriptionId = Number(req.params.id);
        if (!Number.isFinite(subscriptionId) || subscriptionId <= 0) {
            return res.status(400).json({ success: false, message: 'Invalid subscription id' });
        }

        const ledger = await buildSubscriptionLedgerResponse(req, subscriptionId);
        if (!ledger) {
            return res.status(404).json({ success: false, message: 'Subscription not found' });
        }

        res.json({
            success: true,
            data: {
                subscription: ledger.subscription.toJSON(),
                financial_summary: await buildSubscriptionFinancialSummary(
                    req,
                    ledger.subscription,
                    ledger.consumptions.map((row) => row.toJSON())
                ),
                advance_summary: await getSubscriptionItemAdvanceSummary(req, ledger.subscription),
                cash_advance_summary: await getSubscriptionCustomerAdvanceSummary(req, ledger.subscription),
                consumptions: ledger.consumptions.map((row) => row.toJSON()),
                settlements: ledger.settlements.map((row) => row.toJSON())
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.generateFinalSettlement = async (req, res) => {
    await resolveOutletId(req);
    const t = await req.propertyDb.transaction();
    try {
        const subscriptionId = Number(req.params.id);
        if (!Number.isFinite(subscriptionId) || subscriptionId <= 0) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Invalid subscription id' });
        }

        const subscription = await req.propertyDb.models.milk_subscriptions.findOne({
            where: {
                id: subscriptionId,
                outlet_id: req.user.outlet_id
            },
            include: [
                { model: req.propertyDb.models.milk_subscription_schemes, as: 'schemes', required: false }
            ],
            transaction: t
        });

        if (!subscription) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Subscription not found' });
        }

        let consumptionRows = await loadSubscriptionConsumptionRows(req, subscription, t);
        if (consumptionRows.length > 0 && consumptionRows.some((row) => !row.id)) {
            const createdRows = [];
            for (const row of consumptionRows) {
                const payload = typeof row.toJSON === 'function' ? row.toJSON() : { ...row };
                delete payload.id;
                createdRows.push(
                    await req.propertyDb.models.milk_subscription_consumptions.create(
                        {
                            ...payload,
                            status: payload.status || 'CONSUMED'
                        },
                        { transaction: t }
                    )
                );
            }
            consumptionRows = createdRows;
        }

        const metrics = buildSubscriptionMetrics(
            subscription,
            consumptionRows.map((row) => row.toJSON())
        );
        const schemeTotals = await getSubscriptionSchemeTotals(subscription);
        const referenceRateRow = [...consumptionRows].reverse().find((row) => toAmount(row.rate) > 0);
        const referenceRate = toAmount(referenceRateRow?.rate);
        const bonusAmount = metrics.bonus_value;
        const grossDue = Math.max(metrics.outstanding_amount, 0);
        const creditAmount = Math.max(metrics.credited_amount, 0);
        const cashAdvanceSummary = await getSubscriptionCustomerAdvanceSummary(req, subscription, t);
        const availableCustomerAdvance = Math.max(toAmount(cashAdvanceSummary.available_amount), 0);
        const customerAdvanceUsed = Math.min(grossDue, availableCustomerAdvance);
        const totalDue = Math.max(grossDue - customerAdvanceUsed, 0);
        const paymentMode = String(req.body.payment_mode || req.body.paymentMode || 'CASH').trim().toUpperCase();
        const requestedAmount = Math.max(
            0,
            toAmount(req.body.amount_paid ?? req.body.amountPaid ?? totalDue)
        );
        const availableCustomerAdvanceAfterDue = Math.max(
            availableCustomerAdvance - customerAdvanceUsed,
            0
        );
        const refundAvailable = availableCustomerAdvanceAfterDue + creditAmount;
        const isRefundFlow = totalDue <= 0 && refundAvailable > 0;

        if (totalDue > 0 && paymentMode === 'CREDIT') {
            throw new Error(`Please clear the remaining due of ${totalDue.toFixed(2)} before settling the subscription.`);
        }
        if (totalDue > 0 && requestedAmount + 0.009 < totalDue) {
            throw new Error(`Please pay the remaining due of ${totalDue.toFixed(2)} before settling the subscription.`);
        }
        if (isRefundFlow && requestedAmount <= 0) {
            throw new Error(`Please enter refund amount before settling the subscription. Available advance is ${refundAvailable.toFixed(2)}.`);
        }
        if (isRefundFlow && requestedAmount > refundAvailable + 0.009) {
            throw new Error(`Refund amount cannot exceed available advance of ${refundAvailable.toFixed(2)}.`);
        }

        const isCreditCarryForward = paymentMode === 'CREDIT' && totalDue > 0;
        const amountReceived = totalDue > 0 ? Math.min(requestedAmount, totalDue) : 0;
        const refundFromAdvance = isRefundFlow
            ? Math.min(requestedAmount, availableCustomerAdvanceAfterDue)
            : 0;
        const refundFromCredit = isRefundFlow
            ? Math.max(requestedAmount - refundFromAdvance, 0)
            : 0;
        const refundPaid = Number((refundFromCredit + refundFromAdvance).toFixed(2));
        const advanceTopup = totalDue > 0 ? Math.max(requestedAmount - totalDue, 0) : 0;
        const balanceDue = Math.max(totalDue - amountReceived, 0);
        const remainingCredit = Math.max(creditAmount - refundFromCredit, 0);
        const remainingCustomerAdvance = Math.max(
            availableCustomerAdvanceAfterDue - refundFromAdvance,
            0
        );
        const advanceAmount = Number((remainingCredit + remainingCustomerAdvance + advanceTopup).toFixed(2));
        const amountPaid = Number((amountReceived + refundPaid).toFixed(2));

        const settlementNo = `SUBSET-${Date.now()}`;
        const settlement = await req.propertyDb.models.milk_subscription_settlements.create({
            outlet_id: req.user.outlet_id,
            subscription_id: subscription.id,
            settlement_no: settlementNo,
            settlement_date: req.body.settlement_date || new Date(),
            period_start: subscription.start_date,
            period_end: subscription.end_date,
                gross_excess_amount: metrics.actual_value,
                scheme_discount_amount: schemeTotals.discountAmount,
                bonus_amount: bonusAmount,
                total_due: grossDue,
                payment_mode: paymentMode,
                amount_paid: amountPaid,
                balance_due: balanceDue,
                advance_amount: advanceAmount,
                notes: req.body.notes || null,
                created_by: req.user.id
            }, { transaction: t });

        await req.propertyDb.models.milk_subscription_consumptions.update(
            {
                settlement_id: settlement.id,
                status: 'SETTLED'
            },
            {
                where: {
                    id: { [Op.in]: consumptionRows.map((row) => row.id) }
                },
                transaction: t
            }
        );

        const closeSubscriptionNow = isCreditCarryForward || balanceDue <= 0;
        await subscription.update({
            status: closeSubscriptionNow ? 'SETTLED' : 'ACTIVE',
            active_subscription: !closeSubscriptionNow,
            settled_at: closeSubscriptionNow ? new Date() : null,
            updated_by: req.user.id
        }, { transaction: t });

        if (isCreditCarryForward && balanceDue > 0) {
            const creditSaleNo = `SUBCRED-${Date.now()}`;
            await req.propertyDb.models.sales_headers.create({
                outlet_id: req.user.outlet_id,
                sale_no: creditSaleNo,
                sale_date: settlement.settlement_date || new Date(),
                customer_name: subscription.customer_name || null,
                customer_phone: subscription.customer_phone || null,
                customer_address: subscription.customer_address || null,
                customer_gstin: subscription.customer_gstin || null,
                payment_mode: 'CREDIT',
                payment_reference: `SUBSCRIPTION:${subscription.id}`,
                initial_amount_paid: 0,
                amount_paid: 0,
                change_amount: 0,
                balance_due: balanceDue,
                order_type: 'B2C',
                billing_country: 'India',
                billing_tax_mode: 'CGST_SGST',
                bill_format: 'A4',
                tax_percent: 0,
                scheme_id: null,
                scheme_name: null,
                scheme_discount: 0,
                manual_discount_type: null,
                manual_discount_value: 0,
                manual_discount_amount: 0,
                total_qty: 0,
                sub_total: balanceDue,
                taxable_amount: 0,
                cgst_amount: 0,
                sgst_amount: 0,
                igst_amount: 0,
                total_tax: 0,
                tax_breakup: [],
                charges: [],
                charge_total: 0,
                charge_tax_total: 0,
                total_discount: 0,
                round_off_amount: 0,
                net_amount: balanceDue,
                voucher_code: null,
                voucher_label: null,
                notes: `Subscription ${settlement.settlement_no} moved to customer credit outstanding`,
                status: 'COMPLETED',
                created_by: req.user.id,
                original_sale_id: null,
                previous_sale_id: null,
                replaced_by_sale_id: null,
                version_no: 1,
                is_latest: true,
                is_deleted: false
            }, { transaction: t });

            await createLedgerEntry({
                db: req.propertyDb,
                outlet_id: req.user.outlet_id,
                txn_date: settlement.settlement_date,
                transaction_type: 'SUBSCRIPTION_SETTLEMENT_CREDIT',
                reference_type: 'SUBSCRIPTION',
                reference_id: subscription.id,
                reference_no: settlement.settlement_no,
                party_name: subscription.customer_name || subscription.customer_phone || 'Subscription Customer',
                payment_method: paymentMode,
                amount_in: 0,
                amount_out: 0,
                notes: `Subscription settlement moved to credit with outstanding ${balanceDue.toFixed(2)}`,
                created_by: req.user.id,
                transaction: t
            });
        }

        if (customerAdvanceUsed > 0) {
            await consumeSubscriptionCustomerAdvance(
                req,
                subscription.id,
                customerAdvanceUsed,
                t
            );
        }

        if (advanceTopup > 0) {
            await addSubscriptionCustomerAdvance(
                req,
                subscription,
                advanceTopup,
                paymentMode,
                `Advance created from settlement ${settlement.settlement_no}`,
                settlement.settlement_date,
                t
            );
        }

        if (refundFromAdvance > 0) {
            await consumeSubscriptionCustomerAdvance(
                req,
                subscription.id,
                refundFromAdvance,
                t
            );
        }

        if (!isCreditCarryForward && (amountReceived > 0 || advanceTopup > 0 || refundPaid > 0)) {
            const advanceNoteSuffix = customerAdvanceUsed > 0
                ? ` after applying customer advance ${customerAdvanceUsed.toFixed(2)}`
                : '';
            await createLedgerEntry({
                db: req.propertyDb,
                outlet_id: req.user.outlet_id,
                txn_date: settlement.settlement_date,
                transaction_type: refundPaid > 0
                    ? 'SUBSCRIPTION_SETTLEMENT_REFUND'
                    : (balanceDue > 0 ? 'SUBSCRIPTION_SETTLEMENT_PARTIAL' : 'SUBSCRIPTION_SETTLEMENT'),
                reference_type: 'SUBSCRIPTION',
                reference_id: subscription.id,
                reference_no: settlement.settlement_no,
                party_name: subscription.customer_name || subscription.customer_phone || 'Subscription Customer',
                payment_method: paymentMode,
                amount_in: amountReceived + advanceTopup,
                amount_out: refundPaid,
                notes: refundPaid > 0
                    ? `Refund settled for ${subscription.item_name} (${Math.max(remainingCredit, 0).toFixed(2)} credit left)`
                    : (balanceDue > 0
                        ? `Partial settlement for ${subscription.item_name} with outstanding ${balanceDue.toFixed(2)}${advanceNoteSuffix}`
                        : `Final settlement for ${subscription.item_name}${advanceNoteSuffix}`),
                created_by: req.user.id,
                transaction: t
            });
        }

        await audit.log({
            req,
            module: 'SALES',
            action: 'CREATE',
            table: 'milk_subscription_settlements',
            recordId: settlement.id,
            new_data: settlement.toJSON(),
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });

        await t.commit();

        res.json({
            success: true,
            data: {
                settlement: settlement.toJSON(),
                pending_rows: consumptionRows.map((row) => row.toJSON()),
                daily_breakdown: metrics.daily_breakdown,
                financial_summary: {
                    prepaid_amount: metrics.prepaid_value,
                    actual_amount: metrics.actual_value,
                    credited_amount: creditAmount,
                    gross_outstanding_amount: grossDue,
                    customer_advance_used: Number(customerAdvanceUsed.toFixed(2)),
                    outstanding_amount: totalDue,
                    bonus_amount: bonusAmount,
                    payment_mode: paymentMode,
                    amount_paid: amountPaid,
                    amount_received: Number(amountReceived.toFixed(2)),
                    amount_refunded: Number(refundPaid.toFixed(2)),
                    advance_added: Number(advanceTopup.toFixed(2)),
                    advance_remaining: advanceAmount,
                    moved_to_credit_outstanding: isCreditCarryForward,
                    balance_due: balanceDue
                },
                subscription: subscription.toJSON(),
                reference_rate: referenceRate
            }
        });
    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.listItemAdvances = async (req, res) => {
    try {
        const identity = normalizeCustomerIdentity(req.query);
        const itemId = Number(req.query.item_id);
        const filterItemId = Number.isFinite(itemId) && itemId > 0 ? itemId : null;

        const replacements = {
            outlet_id: req.user.outlet_id,
            customer_phone: identity.customer_phone || '',
            customer_gstin: identity.customer_gstin || '',
            customer_name: identity.customer_name || '',
            item_id: filterItemId,
        };

        const [advanceRows] = await req.propertyDb.query(
            `
SELECT
  cia.id,
  cia.item_id,
  cia.advance_date,
  cia.original_qty,
  cia.available_qty,
  cia.rate,
  cia.note,
  im.item_name,
  im.item_code
FROM customer_item_advances cia
LEFT JOIN item_master im ON im.id = cia.item_id
WHERE cia.outlet_id = :outlet_id
  ${buildManualAdvanceExclusionClause('cia')}
  AND (
    (:customer_phone <> '' AND cia.customer_phone = :customer_phone)
    OR (:customer_gstin <> '' AND cia.customer_gstin = :customer_gstin)
    OR (:customer_name <> '' AND cia.customer_name = :customer_name)
  )
  ${filterItemId ? 'AND cia.item_id = :item_id' : ''}
ORDER BY cia.item_id ASC, cia.advance_date ASC, cia.id ASC
            `,
            { replacements }
        );

        const [consumedRows] = await req.propertyDb.query(
            `
SELECT
  si.item_id,
  COALESCE(SUM(si.qty), 0) AS consumed_qty
FROM sales_headers sh
JOIN sales_items si ON si.sale_id = sh.id
WHERE sh.outlet_id = :outlet_id
  AND sh.status = 'COMPLETED'
  AND sh.is_latest = TRUE
  AND sh.is_deleted = FALSE
  AND (
    (:customer_phone <> '' AND sh.customer_phone = :customer_phone)
    OR (:customer_gstin <> '' AND sh.customer_gstin = :customer_gstin)
    OR (:customer_name <> '' AND sh.customer_name = :customer_name)
  )
GROUP BY si.item_id
            `,
            { replacements }
        );

        const consumedByItem = new Map();
        for (const row of consumedRows || []) {
            const itemId = Number(row.item_id) || 0;
            if (itemId > 0) {
                consumedByItem.set(itemId, Number(row.consumed_qty) || 0);
            }
        }

        const totalsByItem = new Map();
        for (const row of advanceRows || []) {
            const itemId = Number(row.item_id) || 0;
            if (!itemId) continue;
            totalsByItem.set(itemId, (totalsByItem.get(itemId) || 0) + (Number(row.original_qty) || 0));
        }

        const data = [];
        for (const row of advanceRows || []) {
            const originalQty = Number(row.original_qty) || 0;
            const availableQty = Number(row.available_qty);
            const itemId = Number(row.item_id) || 0;
            const totalOriginalQty = totalsByItem.get(itemId) || originalQty;
            const consumedQty = consumedByItem.get(itemId) || 0;
            const derivedRemainingQty = Math.max(totalOriginalQty - consumedQty, 0);
            data.push({
                ...row,
                original_qty: originalQty,
                available_qty: Number.isFinite(availableQty) ? availableQty : originalQty,
                remaining_qty: Number.isFinite(availableQty) ? availableQty : originalQty,
                remaining_qty_total: derivedRemainingQty,
                consumed_qty_total: consumedQty
            });
        }

        res.json({ success: true, data });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.createItemAdvance = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const created_by = req.user.id;
        const identity = normalizeCustomerIdentity(req.body);
        const scope = buildCustomerScope(identity);

        if (!scope) {
            return res.status(400).json({
                success: false,
                message: 'Customer phone or GSTIN or name is required'
            });
        }

        const itemId = Number(req.body.item_id || req.body.itemId);
        if (!Number.isFinite(itemId) || itemId <= 0) {
            return res.status(400).json({ success: false, message: 'Valid item_id is required' });
        }

        const qty = toAmount(req.body.original_qty ?? req.body.qty);
        if (!Number.isFinite(qty) || qty <= 0) {
            return res.status(400).json({ success: false, message: 'Valid qty/original_qty is required' });
        }

        const advanceDate = parseDateOnly(req.body.advance_date || req.body.advanceDate) || new Date();
        const rate = toAmount(req.body.rate);

        const created = await req.propertyDb.models.customer_item_advances.create({
            outlet_id,
            source_sale_id: req.body.source_sale_id || null,
            customer_name: identity.customer_name || null,
            customer_phone: identity.customer_phone || null,
            customer_gstin: identity.customer_gstin || null,
            item_id: itemId,
            advance_date: advanceDate,
            original_qty: qty,
            available_qty: qty,
            rate,
            note: req.body.note || null,
            created_by
        });

        res.json({ success: true, data: created });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.updateItemAdvance = async (req, res) => {
    try {
        const row = await req.propertyDb.models.customer_item_advances.findOne({
            where: {
                id: req.params.id,
                outlet_id: req.user.outlet_id
            }
        });
        if (!row) {
            return res.status(404).json({ success: false, message: 'Item advance not found' });
        }

        const updates = {};
        if (req.body.item_id != null) {
            const itemId = Number(req.body.item_id);
            if (!Number.isFinite(itemId) || itemId <= 0) {
                return res.status(400).json({ success: false, message: 'Valid item_id is required' });
            }
            updates.item_id = itemId;
        }
        if (req.body.advance_date || req.body.advanceDate) {
            const advanceDate = parseDateOnly(req.body.advance_date || req.body.advanceDate);
            if (!advanceDate) {
                return res.status(400).json({ success: false, message: 'Valid advance date is required' });
            }
            updates.advance_date = advanceDate;
        }
        if (req.body.original_qty != null || req.body.qty != null) {
            const qty = toAmount(req.body.original_qty ?? req.body.qty);
            if (!Number.isFinite(qty) || qty <= 0) {
                return res.status(400).json({ success: false, message: 'Valid qty is required' });
            }
            updates.original_qty = qty;
            updates.available_qty = Math.min(toAmount(row.available_qty), qty);
        }
        if (req.body.rate != null) {
            updates.rate = toAmount(req.body.rate);
        }
        if (req.body.note !== undefined) {
            updates.note = req.body.note || null;
        }

        await row.update(updates);
        res.json({ success: true, data: row });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.deleteItemAdvance = async (req, res) => {
    try {
        const row = await req.propertyDb.models.customer_item_advances.findOne({
            where: {
                id: req.params.id,
                outlet_id: req.user.outlet_id
            }
        });
        if (!row) {
            return res.status(404).json({ success: false, message: 'Item advance not found' });
        }

        await row.update({
            original_qty: 0,
            available_qty: 0,
            note: row.note ? `Cancelled: ${row.note}` : 'Cancelled'
        });
        res.json({ success: true, message: 'Item advance cancelled', data: row });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getItemAdvanceSummary = async (req, res) => {
    try {
        const identity = normalizeCustomerIdentity(req.query);
        const scope = buildCustomerScope(identity);
        if (!scope) {
            return res.status(400).json({
                success: false,
                message: 'Customer phone or GSTIN or name is required'
            });
        }

        const itemId = Number(req.query.item_id);
        if (!Number.isFinite(itemId) || itemId <= 0) {
            return res.status(400).json({ success: false, message: 'Valid item_id is required' });
        }

        const asOfDate = parseDateOnly(req.query.date || req.query.as_of_date || req.query.asOfDate) || new Date();
        const asOfDay = formatDateLocalYmd(asOfDate);

        const [advRows] = await req.propertyDb.query(
            `
SELECT
  COALESCE(SUM(original_qty), 0) AS original_qty,
  COALESCE(SUM(available_qty), 0) AS available_qty
FROM customer_item_advances
WHERE outlet_id = :outlet_id
  AND item_id = :item_id
  AND DATE(advance_date) <= :as_of_day
  ${buildManualAdvanceExclusionClause()}
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
                    as_of_day: asOfDay,
                    customer_phone: identity.customer_phone || '',
                    customer_gstin: identity.customer_gstin || '',
                    customer_name: identity.customer_name || ''
                }
            }
        );

        const [consumeRows] = await req.propertyDb.query(
            `
SELECT
  COALESCE(SUM(original_qty - available_qty), 0) AS consumed_qty
FROM customer_item_advances
WHERE outlet_id = :outlet_id
  AND item_id = :item_id
  AND DATE(advance_date) <= :as_of_day
  ${buildManualAdvanceExclusionClause()}
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
                    as_of_day: asOfDay,
                    customer_phone: identity.customer_phone || '',
                    customer_gstin: identity.customer_gstin || '',
                    customer_name: identity.customer_name || ''
                }
            }
        );

        const originalQty = Number(advRows?.[0]?.original_qty) || 0;
        const availableQty = Number(advRows?.[0]?.available_qty) || 0;
        const consumedQty = Number(consumeRows?.[0]?.consumed_qty) || 0;

        res.json({
            success: true,
            data: {
                item_id: itemId,
                original_qty: originalQty,
                consumed_qty: consumedQty,
                remaining_qty: Math.max(availableQty, 0),
                as_of_date: asOfDay
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getItemAdvanceLedger = async (req, res) => {
    try {
        const identity = normalizeCustomerIdentity(req.query);
        const scope = buildCustomerScope(identity);
        if (!scope) {
            return res.status(400).json({
                success: false,
                message: 'Customer phone or GSTIN or name is required'
            });
        }

        const itemId = Number(req.query.item_id);
        if (!Number.isFinite(itemId) || itemId <= 0) {
            return res.status(400).json({ success: false, message: 'Valid item_id is required' });
        }

        const toDate = parseDateOnly(req.query.to_date || req.query.toDate || req.query.date) || new Date();
        const fromDate = parseDateOnly(req.query.from_date || req.query.fromDate) || addDays(toDate, -30);
        const fromDay = formatDateLocalYmd(fromDate);
        const toDay = formatDateLocalYmd(toDate);

        const replacements = {
            outlet_id: req.user.outlet_id,
            item_id: itemId,
            from_day: fromDay,
            to_day: toDay,
            customer_phone: identity.customer_phone || '',
            customer_gstin: identity.customer_gstin || '',
            customer_name: identity.customer_name || ''
        };

        const [advances] = await req.propertyDb.query(
            `
SELECT id, advance_date, original_qty, available_qty, rate, note
FROM customer_item_advances
WHERE outlet_id = :outlet_id
  AND item_id = :item_id
  AND DATE(advance_date) BETWEEN :from_day AND :to_day
  ${buildManualAdvanceExclusionClause()}
  AND (
    (:customer_phone <> '' AND customer_phone = :customer_phone)
    OR (:customer_gstin <> '' AND customer_gstin = :customer_gstin)
    OR (:customer_name <> '' AND customer_name = :customer_name)
  )
ORDER BY advance_date ASC, id ASC
            `,
            { replacements }
        );

        const [consumptions] = await req.propertyDb.query(
            `
SELECT DATE(sh.sale_date) AS sale_day,
       sh.sale_no,
       COALESCE(SUM(si.qty), 0) AS qty,
       COALESCE(SUM(si.qty * COALESCE(NULLIF(si.rate, 0), 0)), 0) AS amount
FROM sales_headers sh
JOIN sales_items si ON si.sale_id = sh.id
WHERE sh.outlet_id = :outlet_id
  AND sh.status = 'COMPLETED'
  AND sh.is_latest = TRUE
  AND sh.is_deleted = FALSE
  AND si.item_id = :item_id
  AND DATE(sh.sale_date) BETWEEN :from_day AND :to_day
  AND (
    (:customer_phone <> '' AND sh.customer_phone = :customer_phone)
    OR (:customer_gstin <> '' AND sh.customer_gstin = :customer_gstin)
    OR (:customer_name <> '' AND sh.customer_name = :customer_name)
  )
GROUP BY DATE(sh.sale_date), sh.sale_no
ORDER BY sale_day ASC
            `,
            { replacements }
        );

        res.json({
            success: true,
            data: {
                item_id: itemId,
                from_day: fromDay,
                to_day: toDay,
                advances: advances || [],
                consumptions: consumptions || []
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.listVouchers = async (req, res) => {
    try {
        const rules = await getVoucherRules(req);
        res.json({ success: true, data: rules });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.createVoucher = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const code = String(req.body.code || '').trim().toUpperCase();
        if (!code) {
            return res.status(400).json({ success: false, message: 'Voucher code is required' });
        }

        const settings = await req.propertyDb.models.system_settings.findOne({
            where: { outlet_id }
        });

        if (!settings) {
            return res.status(400).json({ success: false, message: 'Create settings before adding vouchers' });
        }

        const existing = Array.isArray(settings.voucher_rules) ? settings.voucher_rules : [];
        if (existing.some((entry) => String(entry.code || '').trim().toUpperCase() === code)) {
            return res.status(400).json({ success: false, message: 'Voucher code already exists' });
        }

        const voucher = {
            code,
            label: req.body.label || code,
            discount_type: req.body.discount_type || 'AMOUNT',
            discount_value: Number(req.body.discount_value) || 0,
            valid_from: req.body.valid_from || null,
            valid_to: req.body.valid_to || null,
            minimum_purchase_amount: Number(req.body.minimum_purchase_amount) || 0
        };

        settings.voucher_rules = [...existing, voucher];
        await settings.save();

        res.json({ success: true, data: voucher });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.updateVoucher = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const code = String(req.params.code || '').trim().toUpperCase();
        const settings = await req.propertyDb.models.system_settings.findOne({
            where: { outlet_id }
        });

        if (!settings) {
            return res.status(404).json({ success: false, message: 'Settings not found' });
        }

        const existing = Array.isArray(settings.voucher_rules) ? settings.voucher_rules : [];
        const index = existing.findIndex((entry) => String(entry.code || '').trim().toUpperCase() === code);
        if (index == -1) {
            return res.status(404).json({ success: false, message: 'Voucher not found' });
        }

        existing[index] = {
            ...existing[index],
            label: req.body.label || existing[index].label || code,
            discount_type: req.body.discount_type || existing[index].discount_type || 'AMOUNT',
            discount_value: Number(req.body.discount_value) || 0,
            valid_from: req.body.valid_from || null,
            valid_to: req.body.valid_to || null,
            minimum_purchase_amount: Number(req.body.minimum_purchase_amount) || 0
        };

        settings.voucher_rules = [...existing];
        await settings.save();

        res.json({ success: true, data: existing[index] });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.deleteVoucher = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const code = String(req.params.code || '').trim().toUpperCase();
        const settings = await req.propertyDb.models.system_settings.findOne({
            where: { outlet_id }
        });

        if (!settings) {
            return res.status(404).json({ success: false, message: 'Settings not found' });
        }

        const existing = Array.isArray(settings.voucher_rules) ? settings.voucher_rules : [];
        const filtered = existing.filter((entry) => String(entry.code || '').trim().toUpperCase() !== code);
        settings.voucher_rules = filtered;
        await settings.save();

        res.json({ success: true, message: 'Voucher deleted successfully' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.validateVoucher = async (req, res) => {
    try {
        const code = String(req.body.code || '').trim().toUpperCase();
        if (!code) {
            return res.status(400).json({ success: false, message: 'Voucher code is required' });
        }

        const result = await validateVoucherUsage(req, {
            code,
            orderAmount: req.body.order_amount || 0,
            header: req.body.header || {}
        });

        if (!result.valid) {
            return res.status(400).json({
                success: false,
                code: result.reason,
                message: result.message
            });
        }

        res.json({ success: true, data: result.voucher });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.deleteSubscription = async (req, res) => {
    await resolveOutletId(req);
    const t = await req.propertyDb.transaction();
    try {
        const subscriptionId = Number(req.params.id);
        console.log("[DEBUG deleteSubscription] Called with ID:", subscriptionId);
        console.log("[DEBUG deleteSubscription] User resolved:", req.user);

        if (!Number.isFinite(subscriptionId) || subscriptionId <= 0) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Invalid subscription id' });
        }

        const subscription = await req.propertyDb.models.milk_subscriptions.findOne({
            where: {
                id: subscriptionId,
                outlet_id: req.user.outlet_id
            },
            transaction: t
        });

        console.log("[DEBUG deleteSubscription] Found subscription database record:", subscription ? subscription.toJSON() : null);

        if (!subscription) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Subscription not found' });
        }

        // Delete associated customer item advances
        const itemAdvance = await findSubscriptionItemAdvance(req, subscriptionId, subscription.item_id, t);
        if (itemAdvance) {
            await itemAdvance.destroy({ transaction: t });
        }

        // Delete associated customer cash advances
        const customerAdvance = await findSubscriptionCustomerAdvance(req, subscriptionId, t);
        if (customerAdvance) {
            await customerAdvance.destroy({ transaction: t });
        }

        // Delete and recalculate ledger entries
        const entriesToDelete = await req.propertyDb.models.cash_ledger.findAll({
            where: {
                outlet_id: req.user.outlet_id,
                reference_type: 'SUBSCRIPTION',
                reference_id: subscriptionId
            },
            transaction: t
        });

        if (entriesToDelete.length > 0) {
            let earliestDate = new Date();
            for (const entry of entriesToDelete) {
                const entryDate = new Date(entry.txn_date);
                if (entryDate < earliestDate) {
                    earliestDate = entryDate;
                }
            }

            await req.propertyDb.models.cash_ledger.destroy({
                where: {
                    id: { [Op.in]: entriesToDelete.map(e => e.id) }
                },
                transaction: t
            });

            await recalculateLedgerBalances({
                db: req.propertyDb,
                outlet_id: req.user.outlet_id,
                fromDate: earliestDate,
                transaction: t
            });
        }

        // Log audit
        await audit.log({
            req,
            module: 'SALES',
            action: 'DELETE',
            table: 'milk_subscriptions',
            recordId: subscriptionId,
            old_data: subscription.toJSON(),
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });

        // Finally destroy the subscription. Cascade delete takes care of schemes, consumptions, settlements.
        await subscription.destroy({ transaction: t });

        await t.commit();
        res.json({ success: true, message: 'Subscription deleted successfully' });
    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.updateSubscriptionStatus = async (req, res) => {
    try {
        await resolveOutletId(req);
        const subscriptionId = Number(req.params.id);
        if (!Number.isFinite(subscriptionId) || subscriptionId <= 0) {
            return res.status(400).json({ success: false, message: 'Invalid subscription id' });
        }

        const subscription = await req.propertyDb.models.milk_subscriptions.findOne({
            where: {
                id: subscriptionId,
                outlet_id: req.user.outlet_id
            }
        });

        if (!subscription) {
            return res.status(404).json({ success: false, message: 'Subscription not found' });
        }

        const newStatus = String(req.body.status || '').trim().toUpperCase();
        if (!newStatus) {
            return res.status(400).json({ success: false, message: 'Status is required' });
        }

        const validStatuses = ['ACTIVE', 'EXPIRED', 'SETTLED', 'CANCELLED'];
        if (!validStatuses.includes(newStatus)) {
            return res.status(400).json({ success: false, message: 'Invalid status' });
        }

        const updates = {
            status: newStatus,
            updated_by: req.user.id
        };

        if (newStatus === 'CANCELLED' || newStatus === 'SETTLED' || newStatus === 'EXPIRED') {
            updates.active_subscription = false;
        } else if (newStatus === 'ACTIVE') {
            updates.active_subscription = true;
        }

        await subscription.update(updates);

        // Log audit
        await audit.log({
            req,
            module: 'SALES',
            action: 'UPDATE',
            table: 'milk_subscriptions',
            recordId: subscriptionId,
            new_data: subscription.toJSON(),
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });

        res.json({ success: true, data: subscription });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.returnSale = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { sale_id, items } = req.body;
        const outlet_id = req.user.outlet_id;

        const sale = await req.propertyDb.models.sales_headers.findOne({
            where: { id: sale_id, outlet_id, is_deleted: false },
            include: [{ model: req.propertyDb.models.sales_items, as: 'items' }],
            transaction: t
        });

        if (!sale) {
            return res.status(404).json({ success: false, message: 'Sale not found' });
        }

        if (sale.status !== 'COMPLETED' && sale.status !== 'RETURNED') {
            return res.status(400).json({ success: false, message: 'Only completed sales can be returned' });
        }

        // Load existing Credit Notes for this sale to compute remaining quantities
        const existingCNs = await req.propertyDb.models.sales_credit_notes.findAll({
            where: { sale_id: sale.id, outlet_id },
            transaction: t
        });
        const alreadyReturned = {};
        for (const cn of existingCNs) {
            if (Array.isArray(cn.items)) {
                for (const it of cn.items) {
                    alreadyReturned[it.item_id] = (alreadyReturned[it.item_id] || 0) + Number(it.qty);
                }
            }
        }

        const cnItems = [];
        let cnTotalQty = 0;
        let cnSubTotal = 0;
        let cnTaxableAmount = 0;
        let cnCgstAmount = 0;
        let cnSgstAmount = 0;
        let cnIgstAmount = 0;
        let cnTotalTax = 0;
        let cnNetAmount = 0;

        // Revert stock for selected return items and build credit note items
        for (const returnItem of items) {
            const saleItem = sale.items.find(it => it.item_id === returnItem.item_id);
            if (!saleItem) continue;

            const qtyToReturn = Number(returnItem.qty_to_return || 0);
            if (qtyToReturn <= 0) continue;

            const prevReturned = alreadyReturned[saleItem.item_id] || 0;
            const maxReturnable = Number(saleItem.qty) - prevReturned;
            if (qtyToReturn > maxReturnable + 0.009) {
                await t.rollback();
                return res.status(400).json({
                    success: false,
                    message: `Cannot return more than remaining quantity (${maxReturnable.toFixed(2)}) for item ${saleItem.item_name}`
                });
            }

            // Calculate proportionate values
            const proportion = qtyToReturn / Number(saleItem.qty);
            const taxable_amount = toAmount(Number(saleItem.taxable_amount) * proportion);
            const tax_amount = toAmount(Number(saleItem.tax_amount) * proportion);
            const line_total = toAmount(Number(saleItem.line_total) * proportion);
            const rate = Number(saleItem.rate);
            const tax_percent = Number(saleItem.tax_percent);

            let cgst_amount = 0;
            let sgst_amount = 0;
            let igst_amount = 0;
            let tax_breakup = [];

            if (Array.isArray(saleItem.tax_breakup)) {
                tax_breakup = saleItem.tax_breakup.map(tax => {
                    const taxAmt = toAmount(Number(tax.taxAmount) * proportion);
                    if (tax.code === 'CGST') cgst_amount += taxAmt;
                    if (tax.code === 'SGST') sgst_amount += taxAmt;
                    if (tax.code === 'IGST') igst_amount += taxAmt;
                    return {
                        ...tax,
                        taxAmount: taxAmt
                    };
                });
            }

            cnItems.push({
                item_id: saleItem.item_id,
                item_code: saleItem.item_code,
                item_name: saleItem.item_name,
                qty: qtyToReturn,
                rate,
                tax_percent,
                taxable_amount,
                cgst_amount,
                sgst_amount,
                igst_amount,
                tax_amount,
                line_total,
                tax_breakup
            });

            cnTotalQty += qtyToReturn;
            cnSubTotal += toAmount(rate * qtyToReturn);
            cnTaxableAmount += taxable_amount;
            cnCgstAmount += cgst_amount;
            cnSgstAmount += sgst_amount;
            cnIgstAmount += igst_amount;
            cnTotalTax += tax_amount;
            cnNetAmount += line_total;

            // Always revert the parent item itself in stock ledger
            await insertLedger({
                db: req.propertyDb,
                outlet_id,
                item_code: saleItem.item_code,
                txn_date: new Date(),
                txn_type: 'SALE_RETURN',
                ref_no: sale.sale_no,
                qty_in: qtyToReturn,
                transaction: t
            });

            // If it is a composite item, also revert components
            const bomComponents = await req.propertyDb.models.item_boms.findAll({
                where: { outlet_id, parent_item_id: saleItem.item_id },
                include: [
                    {
                        model: req.propertyDb.models.item_master,
                        as: 'component_item',
                        where: { is_active: true }
                    }
                ],
                transaction: t
            });

            if (bomComponents && bomComponents.length > 0) {
                for (const bomComp of bomComponents) {
                    const compItem = bomComp.component_item;
                    if (!compItem) continue;
                    const qtyRequiredPerUnit = Number(bomComp.quantity);
                    const totalQtyToRevert = qtyRequiredPerUnit * qtyToReturn;

                    await insertLedger({
                        db: req.propertyDb,
                        outlet_id,
                        item_code: compItem.item_code,
                        txn_date: new Date(),
                        txn_type: 'SALE_RETURN',
                        ref_no: sale.sale_no,
                        qty_in: totalQtyToRevert,
                        transaction: t
                    });
                }
            }
        }

        if (cnItems.length === 0) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'No valid items/quantities to return' });
        }

        // Generate Credit Note Number
        const nowCN = new Date();
        const todayStr = `${nowCN.getFullYear()}${String(nowCN.getMonth() + 1).padStart(2, '0')}${String(nowCN.getDate()).padStart(2, '0')}`;
        const cnCount = await req.propertyDb.models.sales_credit_notes.count({
            where: { outlet_id, credit_note_date: new Date() },
            transaction: t
        });
        const seqCN = String(cnCount + 1).padStart(4, '0');
        const credit_note_no = `CN-${todayStr}-${seqCN}`;

        // Create the Credit Note record
        const creditNote = await req.propertyDb.models.sales_credit_notes.create({
            outlet_id,
            sale_id: sale.id,
            credit_note_no,
            credit_note_date: new Date(),
            customer_name: sale.customer_name,
            customer_phone: sale.customer_phone,
            customer_gstin: sale.customer_gstin,
            items: cnItems,
            total_qty: cnTotalQty,
            sub_total: cnSubTotal,
            taxable_amount: cnTaxableAmount,
            cgst_amount: cnCgstAmount,
            sgst_amount: cnSgstAmount,
            igst_amount: cnIgstAmount,
            total_tax: cnTotalTax,
            net_amount: cnNetAmount,
            reason: 'Sales Return',
            status: 'PENDING',
            notes: `Credit Note issued for sales return on bill ${sale.sale_no}`,
            created_by: req.user.id
        }, { transaction: t });

        // Update sale status to RETURNED only if all items are fully returned
        let allFullyReturned = true;
        for (const saleItem of sale.items) {
            const prevRet = alreadyReturned[saleItem.item_id] || 0;
            const returnedThisTime = cnItems.find(it => it.item_id === saleItem.item_id)?.qty || 0;
            if (prevRet + returnedThisTime < Number(saleItem.qty) - 0.009) {
                allFullyReturned = false;
                break;
            }
        }
        if (allFullyReturned) {
            await sale.update({ status: 'RETURNED' }, { transaction: t });
        }

        // Generate and insert a pending refund record
        const refundCount = await req.propertyDb.models.sales_refunds.count({
            where: { outlet_id, refund_date: new Date() },
            transaction: t
        });
        const seqRefund = String(refundCount + 1).padStart(4, '0');
        const refund_no = `REF-${todayStr}-${seqRefund}`;

        await req.propertyDb.models.sales_refunds.create({
            outlet_id,
            sale_id: sale.id,
            refund_no,
            refund_date: new Date(),
            amount_pending: cnNetAmount,
            amount_paid: 0,
            status: 'PENDING',
            notes: `Pending refund for Credit Note ${credit_note_no} against bill ${sale.sale_no}`,
            created_by: req.user.id
        }, { transaction: t });

        await audit.log({
            req,
            module: 'SALES',
            action: 'RETURN',
            table: 'sales_headers',
            recordId: sale.id,
            newData: { status: allFullyReturned ? 'RETURNED' : 'COMPLETED', credit_note: creditNote.toJSON() },
            outlet_id,
            user_id: req.user.id
        });

        await t.commit();
        res.json({
            success: true,
            message: 'Sale returned, Credit Note generated, and pending refund recorded successfully',
            credit_note: creditNote
        });
    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.listRefunds = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const status = String(req.query.status || '').trim().toUpperCase();
        const search = String(req.query.search || '').trim();
        const fromDate = parseDateOnly(req.query.from_date);
        const toDate = parseDateOnly(req.query.to_date);

        const where = { outlet_id };
        if (status) {
            where.status = status;
        }

        if (fromDate || toDate) {
            where.refund_date = {};
            if (fromDate) {
                fromDate.setHours(0, 0, 0, 0);
                where.refund_date[Op.gte] = fromDate;
            }
            if (toDate) {
                toDate.setHours(23, 59, 59, 999);
                where.refund_date[Op.lte] = toDate;
            }
        }

        const include = [
            {
                model: req.propertyDb.models.sales_headers,
                as: 'sale',
                attributes: ['sale_no', 'customer_name', 'customer_phone', 'customer_gstin']
            }
        ];

        if (search) {
            where[Op.or] = [
                { refund_no: { [Op.iLike]: `%${search}%` } },
                { notes: { [Op.iLike]: `%${search}%` } },
                { '$sale.sale_no$': { [Op.iLike]: `%${search}%` } },
                { '$sale.customer_name$': { [Op.iLike]: `%${search}%` } },
                { '$sale.customer_phone$': { [Op.iLike]: `%${search}%` } }
            ];
        }

        const data = await req.propertyDb.models.sales_refunds.findAll({
            where,
            include,
            order: [['refund_date', 'DESC'], ['id', 'DESC']]
        });

        res.json({ success: true, data });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.payRefund = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;
        const { refund_id, amount_paid, payment_mode, reference_no, notes } = req.body;

        const refund = await req.propertyDb.models.sales_refunds.findOne({
            where: { id: refund_id, outlet_id },
            transaction: t
        });

        if (!refund) {
            return res.status(404).json({ success: false, message: 'Refund record not found' });
        }

        if (refund.status === 'PAID') {
            return res.status(400).json({ success: false, message: 'Refund is already fully paid' });
        }

        const amountPaidNumeric = Number(amount_paid || 0);
        if (amountPaidNumeric <= 0) {
            return res.status(400).json({ success: false, message: 'Paid amount must be positive' });
        }

        const newAmountPaid = Number(refund.amount_paid) + amountPaidNumeric;
        const newAmountPending = Number(refund.amount_pending);
        
        let newStatus = 'PARTIALLY_PAID';
        if (newAmountPaid >= newAmountPending) {
            newStatus = 'PAID';
        }

        await refund.update({
            amount_paid: newAmountPaid,
            status: newStatus,
            payment_mode,
            reference_no,
            notes: notes || refund.notes,
            updated_by: req.user.id
        }, { transaction: t });

        // Fetch sale to log correct party_name
        const sale = await req.propertyDb.models.sales_headers.findOne({
            where: { id: refund.sale_id, outlet_id },
            transaction: t
        });

        // Insert into Cash Ledger
        await createLedgerEntry({
            db: req.propertyDb,
            outlet_id,
            txn_date: new Date(),
            transaction_type: 'SALE_REFUND',
            reference_type: 'SALE_REFUND',
            reference_id: refund.id,
            reference_no: refund.refund_no,
            party_name: sale?.customer_name || sale?.customer_phone || 'Walk-in Customer',
            payment_method: payment_mode || 'CASH',
            amount_out: amountPaidNumeric,
            notes: notes || `Refund paid against bill ${sale?.sale_no || ''}`,
            created_by: req.user.id,
            transaction: t
        });

        await audit.log({
            req,
            module: 'SALES',
            action: 'PAY_REFUND',
            table: 'sales_refunds',
            recordId: refund.id,
            newData: refund.toJSON(),
            outlet_id,
            user_id: req.user.id
        });

        await t.commit();
        res.json({ success: true, message: 'Refund processed successfully and cash ledger updated.' });
    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.allocateMilkSubscriptionCoverage = allocateMilkSubscriptionCoverage;
exports.persistMilkSubscriptionConsumptions = persistMilkSubscriptionConsumptions;
exports.findSubscriptionItemAdvance = findSubscriptionItemAdvance;
exports.consumeSubscriptionItemAdvance = consumeSubscriptionItemAdvance;
exports.findSubscriptionCustomerAdvance = findSubscriptionCustomerAdvance;
exports.consumeSubscriptionCustomerAdvance = consumeSubscriptionCustomerAdvance;


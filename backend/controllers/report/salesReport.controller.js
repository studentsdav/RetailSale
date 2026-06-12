const { Op } = require('sequelize');

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

function normalizeDate(value) {
    const date = value instanceof Date ? value : new Date(value);
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

function formatDayKey(dateValue) {
    const date = startOfDay(dateValue);
    return date.toISOString().slice(0, 10);
}

function formatMonthKey(dateValue) {
    const date = startOfMonth(dateValue);
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
}

function formatWeekKey(dateValue) {
    const date = startOfWeek(dateValue);
    return formatDayKey(date);
}

function sumChargeTotals(charges) {
    let packingCharges = 0;
    let otherCharges = 0;

    for (const charge of safeArray(charges)) {
        const amount = toNumber(charge.amount);
        const name = String(charge.name || charge.code || '').toUpperCase();

        if (name.includes('PACK')) {
            packingCharges += amount;
        } else {
            otherCharges += amount;
        }
    }

    return { packingCharges, otherCharges };
}

function aggregateTaxes({ sale, taxAccumulator }) {
    const saleBreakup = safeArray(sale.tax_breakup);

    let gst = 0;
    let vat = 0;
    let otherTaxes = 0;

    for (const tax of saleBreakup) {
        const code = String(tax.code || tax.label || '').toUpperCase();
        const amount = toNumber(tax.tax_amount);

        if (code.includes('CGST') || code.includes('SGST') || code.includes('IGST') || code.includes('GST')) {
            gst += amount;
        } else if (code.includes('VAT')) {
            vat += amount;
        } else {
            otherTaxes += amount;
        }

        const summaryKey = String(tax.label || tax.code || 'Other Tax');
        taxAccumulator[summaryKey] = (taxAccumulator[summaryKey] || 0) + amount;
    }

    return { gst, vat, otherTaxes };
}

function buildPeriodComparison(entries) {
    const ordered = entries.sort((a, b) => a.period.localeCompare(b.period));

    return ordered.map((entry, index) => {
        const previous = ordered[index - 1];
        return {
            ...entry,
            previous_profit: previous ? previous.profit : 0,
            previous_loss: previous ? previous.loss : 0,
            profit_change: previous ? entry.profit - previous.profit : entry.profit,
            loss_change: previous ? entry.loss - previous.loss : entry.loss
        };
    });
}

exports.getSalesReport = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { from_date, to_date, payment_mode, search } = req.query;

        // Query sales headers
        const where = {
            outlet_id,
            status: { [Op.in]: ['COMPLETED', 'RETURNED'] },
            is_deleted: false,
            is_latest: true
        };

        if (from_date && to_date) {
            where.sale_date = {
                [Op.between]: [
                    new Date(`${from_date}T00:00:00`),
                    new Date(`${to_date}T23:59:59`)
                ]
            };
        }

        if (payment_mode) {
            where.payment_mode = payment_mode;
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
            include: [{
                model: req.propertyDb.models.sales_items,
                as: 'items',
                include: [{
                    model: req.propertyDb.models.item_master,
                    as: 'item',
                    attributes: ['rate', 'retail_sale_price', 'item_group', 'sub_category', 'brand']
                }]
            }],
            order: [['sale_date', 'DESC'], ['id', 'DESC']]
        });

        // Query sales credit notes in parallel
        const cnWhere = {
            outlet_id,
        };
        if (from_date && to_date) {
            cnWhere.credit_note_date = {
                [Op.between]: [from_date, to_date]
            };
        }
        if (search) {
            cnWhere[Op.or] = [
                { credit_note_no: { [Op.iLike]: `%${search}%` } },
                { customer_name: { [Op.iLike]: `%${search}%` } },
                { customer_phone: { [Op.iLike]: `%${search}%` } }
            ];
        }

        const cnInclude = [{
            model: req.propertyDb.models.sales_headers,
            as: 'sale'
        }];
        if (payment_mode) {
            cnInclude[0].where = { payment_mode };
        }

        const creditNotes = await req.propertyDb.models.sales_credit_notes.findAll({
            where: cnWhere,
            include: cnInclude,
            order: [['credit_note_date', 'DESC'], ['id', 'DESC']]
        });

        let totalSubscriptionAmount = 0;
        if (from_date && to_date) {
            const subConsumption = await req.propertyDb.query(`
                SELECT COALESCE(SUM(covered_amount), 0) as total_subscription_amount
                FROM milk_subscription_consumptions
                WHERE outlet_id = :outletId
                  AND txn_date BETWEEN :fromDate AND :toDate
                  AND status != 'CANCELLED'
            `, {
                replacements: {
                    outletId: outlet_id,
                    fromDate: `${from_date}T00:00:00`,
                    toDate: `${to_date}T23:59:59`
                },
                type: req.propertyDb.QueryTypes.SELECT
            });
            totalSubscriptionAmount = toNumber(subConsumption?.[0]?.total_subscription_amount);
        }

        const paymentModeSummary = {};
        const timeZoneMap = Object.fromEntries(
            SALES_ZONES.map((zone) => [zone.key, {
                zone: zone.key,
                label: zone.label,
                sales_count: 0,
                total_sales: 0,
                taxable_amount: 0,
                profit: 0
            }])
        );
        const itemZoneMap = {};
        const taxAccumulator = {};
        const monthMap = {};
        const weekMap = {};
        const dayMap = {};

        let totalQty = 0;
        let grossSales = 0;
        let taxableAmount = 0;
        let totalDiscount = 0;
        let totalRevenue = 0;
        let totalCharges = 0;
        let totalPackingCharges = 0;
        let totalOtherCharges = 0;
        let gst = 0;
        let vat = 0;
        let otherTaxes = 0;
        let estimatedCost = 0;
        let profit = 0;
        let loss = 0;

        // Combine sales and credit notes into a unified array, sorted by date DESC
        const allRecords = [
            ...sales.map(s => ({ type: 'SALE', record: s, date: new Date(s.sale_date) })),
            ...creditNotes.map(cn => ({ type: 'CN', record: cn, date: new Date(cn.credit_note_date) }))
        ];
        allRecords.sort((a, b) => b.date - a.date);

        const data = allRecords.map((rec) => {
            if (rec.type === 'SALE') {
                const sale = rec.record;
                const saleDate = normalizeDate(sale.sale_date);
                const charges = safeArray(sale.charges);
                const saleTaxBreakup = safeArray(sale.tax_breakup);
                const zone = resolveSaleZone(saleDate);
                const chargeSplit = sumChargeTotals(charges);
                const saleTaxSplit = aggregateTaxes({ sale, taxAccumulator });

                const lineItems = sale.items.map((item) => {
                    const qty = toNumber(item.qty);
                    const saleRate = toNumber(item.rate);
                    const lineAmount = toNumber(item.amount);
                    const lineNetAmount = toNumber(item.net_amount);
                    const lineTaxAmount = toNumber(item.tax_amount);
                    const lineDiscount = toNumber(item.line_discount);
                    const itemCostRate = toNumber(item.item?.rate);
                    const lineCost = itemCostRate * qty;
                    const lineProfit = lineNetAmount - lineCost;

                    totalQty += qty;
                    estimatedCost += lineCost;

                    const itemName = item.item_name;
                    if (!itemZoneMap[itemName]) {
                        itemZoneMap[itemName] = {
                            item_name: itemName,
                            item_code: item.item_code,
                            zones: Object.fromEntries(SALES_ZONES.map((entry) => [entry.key, 0])),
                            total_qty: 0,
                            total_sales: 0
                        };
                    }

                    itemZoneMap[itemName].zones[zone.key] = roundAmount(
                        itemZoneMap[itemName].zones[zone.key] + lineNetAmount
                    );
                    itemZoneMap[itemName].total_qty = roundAmount(
                        itemZoneMap[itemName].total_qty + qty
                    );
                    itemZoneMap[itemName].total_sales = roundAmount(
                        itemZoneMap[itemName].total_sales + lineNetAmount
                    );

                    return {
                        item_code: item.item_code,
                        item_name: item.item_name,
                        item_group: item.item?.item_group || '',
                        sub_category: item.item?.sub_category || '',
                        brand: item.item?.brand || '',
                        hsn_sac_code: item.hsn_sac_code || item.item?.hsn_sac_code || '',
                        barcode: item.barcode,
                        unit: item.unit,
                        qty,
                        rate: saleRate,
                        amount: lineAmount,
                        line_discount: lineDiscount,
                        taxable_amount: toNumber(item.taxable_amount),
                        tax_amount: lineTaxAmount,
                        line_total: toNumber(item.line_total),
                        net_amount: lineNetAmount,
                        cost_rate: itemCostRate,
                        estimated_cost: lineCost,
                        estimated_profit: lineProfit,
                        tax_breakup: safeArray(item.tax_breakup)
                    };
                });

                const saleGross = toNumber(sale.sub_total);
                const saleTaxable = toNumber(sale.taxable_amount);
                const saleDiscount = toNumber(sale.total_discount);
                const saleChargeTotal = toNumber(sale.charge_total);
                const saleTotalTax = toNumber(sale.total_tax);
                const saleNetRevenue = toNumber(sale.net_amount);
                const saleEstimatedCost = lineItems.reduce((sum, item) => sum + item.estimated_cost, 0);
                const saleProfit = saleNetRevenue - saleEstimatedCost;
                const saleLoss = saleProfit < 0 ? Math.abs(saleProfit) : 0;
                const salePositiveProfit = saleProfit > 0 ? saleProfit : 0;

                grossSales = roundAmount(grossSales + saleGross);
                taxableAmount = roundAmount(taxableAmount + saleTaxable);
                totalDiscount = roundAmount(totalDiscount + saleDiscount);
                totalRevenue = roundAmount(totalRevenue + saleNetRevenue);
                totalCharges = roundAmount(totalCharges + saleChargeTotal);
                totalPackingCharges = roundAmount(totalPackingCharges + chargeSplit.packingCharges);
                totalOtherCharges = roundAmount(totalOtherCharges + chargeSplit.otherCharges);
                gst = roundAmount(gst + saleTaxSplit.gst);
                vat = roundAmount(vat + saleTaxSplit.vat);
                otherTaxes = roundAmount(otherTaxes + saleTaxSplit.otherTaxes);
                profit = roundAmount(profit + salePositiveProfit);
                loss = roundAmount(loss + saleLoss);

                const paymentKey = String(sale.payment_mode || 'UNKNOWN').trim().toUpperCase() || 'UNKNOWN';
                if (!paymentModeSummary[paymentKey]) {
                    paymentModeSummary[paymentKey] = {
                        payment_mode: paymentKey,
                        amount: 0,
                        sales_count: 0
                    };
                }
                paymentModeSummary[paymentKey].amount = roundAmount(
                    paymentModeSummary[paymentKey].amount + saleNetRevenue
                );
                paymentModeSummary[paymentKey].sales_count += 1;

                timeZoneMap[zone.key].sales_count += 1;
                timeZoneMap[zone.key].total_sales = roundAmount(
                    timeZoneMap[zone.key].total_sales + saleNetRevenue
                );
                timeZoneMap[zone.key].taxable_amount = roundAmount(
                    timeZoneMap[zone.key].taxable_amount + saleTaxable
                );
                timeZoneMap[zone.key].profit = roundAmount(
                    timeZoneMap[zone.key].profit + saleProfit
                );

                const monthKey = formatMonthKey(saleDate);
                const weekKey = formatWeekKey(saleDate);
                const dayKey = formatDayKey(saleDate);

                for (const [key, store] of [[monthKey, monthMap], [weekKey, weekMap], [dayKey, dayMap]]) {
                    if (!store[key]) {
                        store[key] = { period: key, sales: 0, profit: 0, loss: 0 };
                    }
                    store[key].sales = roundAmount(store[key].sales + saleNetRevenue);
                    store[key].profit = roundAmount(store[key].profit + salePositiveProfit);
                    store[key].loss = roundAmount(store[key].loss + saleLoss);
                }

                return {
                    id: sale.id,
                    sale_no: sale.sale_no,
                    sale_date: sale.sale_date,
                    sale_zone: zone.key,
                    customer_name: sale.customer_name,
                    customer_phone: sale.customer_phone,
                    customer_address: sale.customer_address,
                    customer_gstin: sale.customer_gstin,
                    payment_mode: sale.payment_mode,
                    payment_reference: sale.payment_reference,
                    order_type: sale.order_type,
                    billing_country: sale.billing_country,
                    billing_tax_mode: sale.billing_tax_mode,
                    bill_format: sale.bill_format,
                    scheme_name: sale.scheme_name,
                    total_qty: toNumber(sale.total_qty),
                    sub_total: saleGross,
                    taxable_amount: saleTaxable,
                    cgst_amount: toNumber(sale.cgst_amount),
                    sgst_amount: toNumber(sale.sgst_amount),
                    igst_amount: toNumber(sale.igst_amount),
                    total_tax: saleTotalTax,
                    charge_total: saleChargeTotal,
                    charge_tax_total: toNumber(sale.charge_tax_total),
                    total_discount: saleDiscount,
                    net_amount: saleNetRevenue,
                    estimated_cost: saleEstimatedCost,
                    estimated_profit: saleProfit,
                    estimated_loss: saleLoss,
                    charges,
                    tax_breakup: saleTaxBreakup,
                    items: lineItems
                };
            } else {
                // Process Credit Note as a negative sale entry to reduce monthly returns
                const cn = rec.record;
                const cnDate = normalizeDate(cn.credit_note_date);
                const zone = resolveSaleZone(cnDate);

                const cnTaxBreakup = [];
                const cgst = toNumber(cn.cgst_amount);
                const sgst = toNumber(cn.sgst_amount);
                const igst = toNumber(cn.igst_amount);
                if (cgst > 0) {
                    taxAccumulator['CGST'] = (taxAccumulator['CGST'] || 0) - cgst;
                    cnTaxBreakup.push({ code: 'CGST', label: 'CGST', tax_amount: -cgst });
                }
                if (sgst > 0) {
                    taxAccumulator['SGST'] = (taxAccumulator['SGST'] || 0) - sgst;
                    cnTaxBreakup.push({ code: 'SGST', label: 'SGST', tax_amount: -sgst });
                }
                if (igst > 0) {
                    taxAccumulator['IGST'] = (taxAccumulator['IGST'] || 0) - igst;
                    cnTaxBreakup.push({ code: 'IGST', label: 'IGST', tax_amount: -igst });
                }

                const lineItems = safeArray(cn.items).map((item) => {
                    const qty = -toNumber(item.qty);
                    const saleRate = toNumber(item.rate);
                    const lineAmount = -toNumber(item.amount || (item.rate * item.qty));
                    const lineNetAmount = -toNumber(item.line_total || item.net_amount);
                    const lineTaxAmount = -toNumber(item.tax_amount);
                    const lineDiscount = 0;
                    const lineCost = 0;
                    const lineProfit = lineNetAmount;

                    totalQty += qty;

                    const itemName = item.item_name;
                    if (!itemZoneMap[itemName]) {
                        itemZoneMap[itemName] = {
                            item_name: itemName,
                            item_code: item.item_code,
                            zones: Object.fromEntries(SALES_ZONES.map((entry) => [entry.key, 0])),
                            total_qty: 0,
                            total_sales: 0
                        };
                    }

                    itemZoneMap[itemName].zones[zone.key] = roundAmount(
                        itemZoneMap[itemName].zones[zone.key] + lineNetAmount
                    );
                    itemZoneMap[itemName].total_qty = roundAmount(
                        itemZoneMap[itemName].total_qty + qty
                    );
                    itemZoneMap[itemName].total_sales = roundAmount(
                        itemZoneMap[itemName].total_sales + lineNetAmount
                    );

                    const itemTaxBreakup = safeArray(item.tax_breakup).map(t => ({
                        ...t,
                        tax_amount: -toNumber(t.tax_amount)
                    }));

                    return {
                        item_code: item.item_code,
                        item_name: item.item_name,
                        item_group: item.item_group || '',
                        sub_category: item.sub_category || '',
                        brand: item.brand || '',
                        hsn_sac_code: item.hsn_sac_code || '',
                        barcode: item.barcode || '',
                        unit: item.unit || 'PCS',
                        qty,
                        rate: saleRate,
                        amount: lineAmount,
                        line_discount: lineDiscount,
                        taxable_amount: -toNumber(item.taxable_amount),
                        tax_amount: lineTaxAmount,
                        line_total: lineNetAmount,
                        net_amount: lineNetAmount,
                        cost_rate: 0,
                        estimated_cost: lineCost,
                        estimated_profit: lineProfit,
                        tax_breakup: itemTaxBreakup
                    };
                });

                const saleGross = -toNumber(cn.sub_total);
                const saleTaxable = -toNumber(cn.taxable_amount);
                const saleDiscount = 0;
                const saleChargeTotal = 0;
                const saleTotalTax = -toNumber(cn.total_tax);
                const saleNetRevenue = -toNumber(cn.net_amount);
                const saleEstimatedCost = 0;
                const saleProfit = saleNetRevenue;
                const saleLoss = 0;
                const salePositiveProfit = saleProfit;

                grossSales = roundAmount(grossSales + saleGross);
                taxableAmount = roundAmount(taxableAmount + saleTaxable);
                totalDiscount = roundAmount(totalDiscount + saleDiscount);
                totalRevenue = roundAmount(totalRevenue + saleNetRevenue);
                gst = roundAmount(gst - cgst - sgst - igst);
                profit = roundAmount(profit + salePositiveProfit);

                const paymentKey = String(cn.sale?.payment_mode || 'CREDIT_NOTE').trim().toUpperCase() || 'UNKNOWN';
                if (!paymentModeSummary[paymentKey]) {
                    paymentModeSummary[paymentKey] = {
                        payment_mode: paymentKey,
                        amount: 0,
                        sales_count: 0
                    };
                }
                paymentModeSummary[paymentKey].amount = roundAmount(
                    paymentModeSummary[paymentKey].amount + saleNetRevenue
                );
                paymentModeSummary[paymentKey].sales_count -= 1;

                timeZoneMap[zone.key].sales_count -= 1;
                timeZoneMap[zone.key].total_sales = roundAmount(
                    timeZoneMap[zone.key].total_sales + saleNetRevenue
                );
                timeZoneMap[zone.key].taxable_amount = roundAmount(
                    timeZoneMap[zone.key].taxable_amount + saleTaxable
                );
                timeZoneMap[zone.key].profit = roundAmount(
                    timeZoneMap[zone.key].profit + saleProfit
                );

                const monthKey = formatMonthKey(cnDate);
                const weekKey = formatWeekKey(cnDate);
                const dayKey = formatDayKey(cnDate);

                for (const [key, store] of [[monthKey, monthMap], [weekKey, weekMap], [dayKey, dayMap]]) {
                    if (!store[key]) {
                        store[key] = { period: key, sales: 0, profit: 0, loss: 0 };
                    }
                    store[key].sales = roundAmount(store[key].sales + saleNetRevenue);
                    store[key].profit = roundAmount(store[key].profit + salePositiveProfit);
                }

                return {
                    id: `cn-${cn.id}`,
                    sale_no: cn.credit_note_no,
                    sale_date: cn.credit_note_date,
                    sale_zone: zone.key,
                    customer_name: cn.customer_name,
                    customer_phone: cn.customer_phone,
                    customer_address: cn.sale?.customer_address || '',
                    customer_gstin: cn.customer_gstin,
                    payment_mode: cn.sale?.payment_mode || 'CREDIT_NOTE',
                    payment_reference: cn.credit_note_no,
                    order_type: cn.sale?.order_type || 'RETAIL',
                    billing_country: cn.sale?.billing_country || 'INDIA',
                    billing_tax_mode: cn.sale?.billing_tax_mode || 'GST',
                    bill_format: cn.sale?.bill_format || 'A4',
                    scheme_name: cn.sale?.scheme_name || '',
                    total_qty: -toNumber(cn.total_qty),
                    sub_total: saleGross,
                    taxable_amount: saleTaxable,
                    cgst_amount: -cgst,
                    sgst_amount: -sgst,
                    igst_amount: -igst,
                    total_tax: saleTotalTax,
                    charge_total: saleChargeTotal,
                    charge_tax_total: 0,
                    total_discount: saleDiscount,
                    net_amount: saleNetRevenue,
                    estimated_cost: 0,
                    estimated_profit: saleProfit,
                    estimated_loss: 0,
                    charges: [],
                    tax_breakup: cnTaxBreakup,
                    items: lineItems
                };
            }
        });

        const zoneSummary = Object.values(timeZoneMap);
        const highZone = [...zoneSummary].sort((a, b) => b.total_sales - a.total_sales)[0] || null;
        const lowZone = [...zoneSummary].sort((a, b) => a.total_sales - b.total_sales)[0] || null;

        const itemZoneHeatmap = Object.values(itemZoneMap)
            .sort((a, b) => b.total_sales - a.total_sales)
            .slice(0, 12);

        const summary = {
            total_bills: sales.length, // Count only actual sales bills
            total_qty: roundAmount(totalQty),
            gross_sales: roundAmount(grossSales),
            taxable_amount: roundAmount(taxableAmount),
            total_discount: roundAmount(totalDiscount),
            total_charges: roundAmount(totalCharges),
            packing_charges_collected: roundAmount(totalPackingCharges),
            other_charges_collected: roundAmount(totalOtherCharges),
            gst_collected: roundAmount(gst),
            vat_collected: roundAmount(vat),
            other_taxes_collected: roundAmount(otherTaxes),
            total_taxes_collected: roundAmount(gst + vat + otherTaxes),
            total_revenue: roundAmount(totalRevenue),
            subscription_realized: roundAmount(totalSubscriptionAmount),
            estimated_cost: roundAmount(estimatedCost),
            estimated_profit: roundAmount(profit),
            estimated_loss: roundAmount(loss)
        };

        res.json({
            success: true,
            count: data.length,
            summary,
            payment_mode_breakdown: Object.values(paymentModeSummary).filter(entry => entry.sales_count !== 0 || entry.amount !== 0),
            time_zone_breakdown: zoneSummary,
            insights: {
                highest_sale_zone: highZone,
                lowest_sale_zone: lowZone
            },
            heatmaps: {
                item_zone_sales: itemZoneHeatmap
            },
            tax_summary: Object.entries(taxAccumulator).map(([label, amount]) => ({
                label,
                amount
            })).sort((a, b) => b.amount - a.amount),
            comparisons: {
                month_on_month: buildPeriodComparison(Object.values(monthMap)),
                week_on_week: buildPeriodComparison(Object.values(weekMap)),
                day_on_day: buildPeriodComparison(Object.values(dayMap))
            },
            data
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};;

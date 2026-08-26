const cron = require('node-cron');
const { Op } = require('sequelize');
const { createLedgerEntry } = require('../services/cashLedger.service');

const lastRunDateByOutlet = new Map();
let globalLastRunDate = null;

function todayStr() {
    const now = new Date();
    const offsetMs = 5.5 * 60 * 60 * 1000;
    const ist = new Date(now.getTime() + offsetMs);
    const y = ist.getUTCFullYear();
    const m = String(ist.getUTCMonth() + 1).padStart(2, '0');
    const d = String(ist.getUTCDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
}

function log(msg, isError = false) {
    const ts = new Date().toISOString();
    const prefix = isError ? '[ERROR]' : '[INFO]';
    const line = ts + ' [SUBSCRIPTION_JOB] ' + prefix + ' ' + msg;
    if (isError) console.error(line); else console.log(line);
}

async function createDraftForSubscription(db, sub, outletId, today) {
    try {
        const r = await db.query(
            "SELECT COALESCE(MAX(CAST(NULLIF(regexp_replace(sale_no,'[^0-9]','','g'),'') AS INTEGER)),0)+1 AS n FROM sales_headers WHERE outlet_id=:oid",
            { replacements: { oid: outletId }, type: db.QueryTypes.SELECT }
        );
        const saleNo = 'SUB-' + today.replace(/-/g,'') + '-' + String(r?.[0]?.n ?? 1).padStart(4,'0');

        // Check if there are multi-item mappings
        const subItems = await db.models.milk_subscription_items.findAll({
            where: { subscription_id: sub.id },
            include: [{ model: db.models.item_master, as: 'item_master' }]
        });

        let lines = [];
        let totalQty = 0;
        let subTotal = 0;

        if (subItems && subItems.length > 0) {
            for (const sItem of subItems) {
                if (!sItem.item_master) continue;
                const rate = parseFloat(sItem.item_master.retail_sale_price ?? sItem.item_master.rate ?? 0);
                const qty = parseFloat(sItem.qty ?? 1);
                const lineAmt = rate * qty;
                totalQty += qty;
                subTotal += lineAmt;
                lines.push({
                    item_id: sItem.item_id,
                    item_master: sItem.item_master,
                    qty,
                    rate,
                    amount: lineAmt
                });
            }
        } else if (sub.item_master) {
            const rate = parseFloat(sub.item_master.retail_sale_price ?? sub.item_master.rate ?? 0);
            const qty = parseFloat(sub.daily_allowed_qty ?? 1);
            const lineAmt = rate * qty;
            totalQty = qty;
            subTotal = lineAmt;
            lines.push({
                item_id: sub.item_id,
                item_master: sub.item_master,
                qty,
                rate,
                amount: lineAmt
            });
        }

        if (lines.length === 0) {
            throw new Error('No items to subscribe');
        }

        const dailyDeliveryCharge = parseFloat(sub.delivery_charge_amount || 0.0);
        const dailyDeliveryGstPercent = parseFloat(sub.delivery_charge_gst_percent || 0.0);
        const dailyDeliveryTaxAmount = parseFloat(sub.delivery_charge_tax_amount || 0.0);

        const charges = dailyDeliveryCharge > 0 ? [
            {
                name: 'Subscription Delivery',
                code: 'DELIVERY',
                amount: dailyDeliveryCharge,
                calculationValue: dailyDeliveryCharge,
                taxable: dailyDeliveryGstPercent > 0,
                autoApply: true,
                isEnabled: true,
                taxType: 'GST',
                taxPercent: dailyDeliveryGstPercent,
                taxAmount: dailyDeliveryTaxAmount
            }
        ] : [];

        const totalChargesAmount = dailyDeliveryCharge + dailyDeliveryTaxAmount;
        const totalPayable = subTotal + totalChargesAmount;

        const header = await db.models.sales_headers.create({
            outlet_id: outletId, sale_no: saleNo, sale_date: new Date(today),
            customer_name: sub.customer_name || 'Subscription Customer',
            customer_phone: sub.customer_phone || '', customer_address: sub.customer_address || '',
            customer_gstin: sub.customer_gstin || null, payment_mode: 'CASH',
            payment_reference: null, initial_amount_paid: 0, amount_paid: 0,
            change_amount: 0, balance_due: totalPayable, order_type: 'B2C',
            billing_country: 'India', billing_tax_mode: 'CGST_SGST', bill_format: 'A4',
            tax_percent: 0, total_qty: totalQty, sub_total: subTotal, taxable_amount: subTotal,
            cgst_amount: 0, sgst_amount: 0, igst_amount: 0, total_tax: 0,
            tax_breakup: [], charges: charges, charge_total: dailyDeliveryCharge, charge_tax_total: dailyDeliveryTaxAmount,
            total_discount: 0, round_off_amount: 0, net_amount: totalPayable,
            scheme_discount: 0, manual_discount_type: null,
            manual_discount_value: 0, manual_discount_amount: 0,
            notes: '[SUBSCRIPTION_AUTO] subscription_id=' + sub.id + ' | ' + (sub.customer_name||''),
            status: 'DRAFT', version_no: 1, is_latest: true, is_deleted: false,
        });

        if (db.models.sales_items) {
            for (const ln of lines) {
                await db.models.sales_items.create({
                    outlet_id: outletId, sale_id: header.id, item_id: ln.item_id,
                    item_code: ln.item_master.item_code||'', item_name: ln.item_master.item_name||'',
                    hsn_code: ln.item_master.hsn_code||'', batch_no: null, expiry_date: null,
                    qty: ln.qty, original_qty: ln.qty, unit: ln.item_master.unit||'PCS', rate: ln.rate, amount: ln.amount,
                    tax_percent: 0, cgst_percent: 0, sgst_percent: 0, igst_percent: 0, cess_percent: 0,
                    taxable_amount: ln.amount, cgst_amount: 0, sgst_amount: 0, igst_amount: 0,
                    cess_amount: 0, tax_amount: 0, discount_percent: 0, discount_amount: 0,
                    scheme_id: null, scheme_name: null, is_scheme_free: true, is_advance_free: false,
                });
            }
        }
        log('Draft created sub=' + sub.id + ' sale=' + saleNo + ' outlet=' + outletId);
        return header.id;
    } catch (err) { log('Draft create failed sub=' + sub.id + ': ' + err.message, true); return null; }
}

async function createAcceptedSaleForSubscription(db, sub, outletId, today) {
    try {
        const r = await db.query(
            "SELECT COALESCE(MAX(CAST(NULLIF(regexp_replace(sale_no,'[^0-9]','','g'),'') AS INTEGER)),0)+1 AS n FROM sales_headers WHERE outlet_id=:oid",
            { replacements: { oid: outletId }, type: db.QueryTypes.SELECT }
        );
        const saleNo = 'SUB-' + today.replace(/-/g,'') + '-' + String(r?.[0]?.n ?? 1).padStart(4,'0');

        // Check if there are multi-item mappings
        const subItems = await db.models.milk_subscription_items.findAll({
            where: { subscription_id: sub.id },
            include: [{ model: db.models.item_master, as: 'item_master' }]
        });

        let lines = [];
        let totalQty = 0;
        let subTotal = 0;
        let totalTax = 0;
        let totalCgst = 0;
        let totalSgst = 0;

        if (subItems && subItems.length > 0) {
            for (const sItem of subItems) {
                if (!sItem.item_master) continue;
                const isTaxInclusive = String(sItem.item_master.tax_type || '').toUpperCase() === 'GST_INCLUSIVE' || sItem.item_master.is_tax_inclusive === true;
                const rate = parseFloat(sItem.item_master.retail_sale_price ?? sItem.item_master.rate ?? 0);
                const qty = parseFloat(sItem.qty ?? 1);
                const amt = rate * qty;
                totalQty += qty;
                subTotal += amt;

                const taxPercent = parseFloat(sItem.item_master.tax_percent || 0.0);
                let taxableAmount = amt;
                let taxAmount = 0;
                let lineTotal = amt;

                if (isTaxInclusive) {
                    if (taxPercent > 0) {
                        taxableAmount = parseFloat((amt / (1 + taxPercent / 100)).toFixed(2));
                        taxAmount = parseFloat((amt - taxableAmount).toFixed(2));
                    } else {
                        taxableAmount = amt;
                        taxAmount = 0;
                    }
                    lineTotal = amt;
                } else {
                    taxableAmount = amt;
                    taxAmount = parseFloat(((amt * taxPercent) / 100).toFixed(2));
                    lineTotal = amt + taxAmount;
                }

                totalTax += taxAmount;
                const halfRate = taxPercent / 2;
                const halfAmount = parseFloat((taxAmount / 2).toFixed(2));
                const sgstAmount = parseFloat((taxAmount - halfAmount).toFixed(2));
                totalCgst += halfAmount;
                totalSgst += sgstAmount;

                const taxBreakup = taxPercent > 0 ? [
                    {
                        code: 'CGST',
                        label: `CGST ${halfRate % 1 === 0 ? halfRate.toFixed(0) : halfRate.toFixed(2)}%`,
                        taxType: 'GST',
                        tax_type: 'GST',
                        rate: halfRate,
                        taxableAmount: taxableAmount,
                        taxable_amount: taxableAmount,
                        taxAmount: halfAmount,
                        tax_amount: halfAmount
                    },
                    {
                        code: 'SGST',
                        label: `SGST ${halfRate % 1 === 0 ? halfRate.toFixed(0) : halfRate.toFixed(2)}%`,
                        taxType: 'GST',
                        tax_type: 'GST',
                        rate: halfRate,
                        taxableAmount: taxableAmount,
                        taxable_amount: taxableAmount,
                        taxAmount: sgstAmount,
                        tax_amount: sgstAmount
                    }
                ] : [];

                lines.push({
                    item_id: sItem.item_id,
                    item_master: sItem.item_master,
                    qty,
                    rate,
                    amount: amt,
                    taxableAmount,
                    taxPercent,
                    taxAmount,
                    halfRate,
                    halfAmount,
                    lineTotal,
                    taxBreakup
                });
            }
        } else if (sub.item_master) {
            const isTaxInclusive = String(sub.item_master?.tax_type || '').toUpperCase() === 'GST_INCLUSIVE' || sub.item_master?.is_tax_inclusive === true;
            const rate = parseFloat(sub.item_master.retail_sale_price ?? sub.item_master.rate ?? 0);
            const qty = parseFloat(sub.daily_allowed_qty ?? 1);
            const amt = rate * qty;
            totalQty = qty;
            subTotal = amt;

            const taxPercent = parseFloat(sub.item_master.tax_percent || 0.0);
            let taxableAmount = amt;
            let taxAmount = 0;
            let lineTotal = amt;

            if (isTaxInclusive) {
                if (taxPercent > 0) {
                    taxableAmount = parseFloat((amt / (1 + taxPercent / 100)).toFixed(2));
                    taxAmount = parseFloat((amt - taxableAmount).toFixed(2));
                } else {
                    taxableAmount = amt;
                    taxAmount = 0;
                }
                lineTotal = amt;
            } else {
                taxableAmount = amt;
                taxAmount = parseFloat(((amt * taxPercent) / 100).toFixed(2));
                lineTotal = amt + taxAmount;
            }

            totalTax = taxAmount;
            const halfRate = taxPercent / 2;
            const halfAmount = parseFloat((taxAmount / 2).toFixed(2));
            totalCgst = halfAmount;
            totalSgst = parseFloat((taxAmount - halfAmount).toFixed(2));

            const taxBreakup = taxPercent > 0 ? [
                {
                    code: 'CGST',
                    label: `CGST ${halfRate % 1 === 0 ? halfRate.toFixed(0) : halfRate.toFixed(2)}%`,
                    taxType: 'GST',
                    tax_type: 'GST',
                    rate: halfRate,
                    taxableAmount: taxableAmount,
                    taxable_amount: taxableAmount,
                    taxAmount: halfAmount,
                    tax_amount: halfAmount
                },
                {
                    code: 'SGST',
                    label: `SGST ${halfRate % 1 === 0 ? halfRate.toFixed(0) : halfRate.toFixed(2)}%`,
                    taxType: 'GST',
                    tax_type: 'GST',
                    rate: halfRate,
                    taxableAmount: taxableAmount,
                    taxable_amount: taxableAmount,
                    taxAmount: totalSgst,
                    tax_amount: totalSgst
                }
            ] : [];

            lines.push({
                item_id: sub.item_id,
                item_master: sub.item_master,
                qty,
                rate,
                amount: amt,
                taxableAmount,
                taxPercent,
                taxAmount,
                halfRate,
                halfAmount,
                lineTotal,
                taxBreakup
            });
        }

        if (lines.length === 0) {
            throw new Error('No items to subscribe');
        }

        const dailyDeliveryCharge = parseFloat(sub.delivery_charge_amount || 0.0);
        const dailyDeliveryGstPercent = parseFloat(sub.delivery_charge_gst_percent || 0.0);
        const dailyDeliveryTaxAmount = parseFloat(sub.delivery_charge_tax_amount || 0.0);

        const charges = dailyDeliveryCharge > 0 ? [
            {
                name: 'Subscription Delivery',
                code: 'DELIVERY',
                amount: dailyDeliveryCharge,
                calculationValue: dailyDeliveryCharge,
                taxable: dailyDeliveryGstPercent > 0,
                autoApply: true,
                isEnabled: true,
                taxType: 'GST',
                taxPercent: dailyDeliveryGstPercent,
                taxAmount: dailyDeliveryTaxAmount
            }
        ] : [];

        const totalChargesAmount = dailyDeliveryCharge + dailyDeliveryTaxAmount;
        const netAmount = totalChargesAmount;
        const totalLineTotals = lines.reduce((sum, ln) => sum + ln.lineTotal, 0);
        const deductionAmount = totalLineTotals + totalChargesAmount;

        const combinedTaxBreakups = [];
        for (const ln of lines) {
            combinedTaxBreakups.push(...ln.taxBreakup);
        }

        const header = await db.models.sales_headers.create({
            outlet_id: outletId, sale_no: saleNo, sale_date: new Date(today),
            customer_name: sub.customer_name || 'Subscription Customer',
            customer_phone: sub.customer_phone || '', customer_address: sub.customer_address || '',
            customer_gstin: sub.customer_gstin || null, payment_mode: 'CASH',
            payment_reference: null, initial_amount_paid: netAmount, amount_paid: netAmount,
            change_amount: 0, balance_due: 0, order_type: 'B2C',
            billing_country: 'India', billing_tax_mode: 'CGST_SGST', bill_format: 'A4',
            tax_percent: 0, total_qty: totalQty, sub_total: subTotal, taxable_amount: subTotal,
            cgst_amount: totalCgst, sgst_amount: totalSgst, igst_amount: 0, total_tax: totalTax,
            tax_breakup: combinedTaxBreakups, charges: charges, charge_total: dailyDeliveryCharge, charge_tax_total: dailyDeliveryTaxAmount,
            total_discount: totalLineTotals, round_off_amount: 0, net_amount: netAmount,
            notes: '[SUBSCRIPTION_AUTO] subscription_id=' + sub.id + ' | ' + (sub.customer_name||''),
            status: 'COMPLETED', version_no: 1, is_latest: true, is_deleted: false,
        });

        for (const ln of lines) {
            if (db.models.sales_items) {
                await db.models.sales_items.create({
                    outlet_id: outletId, sale_id: header.id, item_id: ln.item_id,
                    item_code: ln.item_master.item_code||'', item_name: ln.item_master.item_name||'',
                    hsn_code: ln.item_master.hsn_code||'', batch_no: null, expiry_date: null,
                    qty: ln.qty, original_qty: ln.qty, unit: ln.item_master.unit||'PCS', rate: ln.rate, amount: ln.amount,
                    tax_percent: ln.taxPercent, cgst_percent: ln.halfRate, sgst_percent: ln.halfRate, igst_percent: 0, cess_percent: 0,
                    taxable_amount: ln.amount, cgst_amount: ln.halfAmount, sgst_amount: ln.halfAmount, igst_amount: 0,
                    cess_amount: 0, tax_amount: ln.taxAmount, discount_percent: 0, discount_amount: 0,
                    scheme_id: null, scheme_name: null, is_scheme_free: false, is_advance_free: true,
                    line_total: ln.lineTotal, net_amount: ln.lineTotal, tax_breakup: ln.taxBreakup
                });
            }

            if (db.models.milk_subscription_consumptions) {
                await db.models.milk_subscription_consumptions.create({
                    outlet_id: outletId, subscription_id: sub.id, sale_id: header.id,
                    item_id: ln.item_id, txn_date: new Date(today),
                    cart_qty: ln.qty, covered_qty: ln.qty, excess_qty: 0, source: 'AUTO_JOB',
                    rate: parseFloat(ln.lineTotal / ln.qty).toFixed(2),
                    covered_amount: parseFloat(ln.lineTotal).toFixed(2),
                }).catch(() => {});
            }

            try {
                const advance = await db.models.customer_item_advances.findOne({
                    where: {
                        outlet_id: outletId,
                        item_id: ln.item_id,
                        [Op.or]: [
                            { source_sale_id: sub.id },
                            { note: { [Op.iLike]: `%Subscription #${sub.id}%` } }
                        ]
                    }
                });
                if (advance) {
                    const currentAvailable = parseFloat(advance.available_qty ?? 0);
                    const nextAvailable = Math.max(currentAvailable - ln.qty, 0);
                    await advance.update({ available_qty: nextAvailable });
                }
            } catch (e) {
                log('Failed to sync item advance for item=' + ln.item_id + ' sub=' + sub.id + ': ' + e.message, true);
            }
        }

        try {
            const cashAdvance = await db.models.customer_advances.findOne({
                where: {
                    outlet_id: outletId,
                    [Op.or]: [
                        { source_sale_id: sub.id },
                        { reference_no: `SUBSCRIPTION-${sub.id}` }
                    ]
                }
            });
            if (cashAdvance) {
                const currentCashAvailable = parseFloat(cashAdvance.available_amount ?? 0);
                const nextCashAvailable = Math.max(currentCashAvailable - deductionAmount, 0);
                await cashAdvance.update({ available_amount: nextCashAvailable });
            }

            await createLedgerEntry({
                db,
                outlet_id: outletId,
                txn_date: new Date(today),
                transaction_type: 'ADVANCE_APPLY',
                reference_type: 'SUBSCRIPTION',
                reference_id: sub.id,
                reference_no: saleNo,
                party_name: sub.customer_name || sub.customer_phone || 'Subscription Customer',
                payment_method: 'SUBSCRIPTION',
                amount_out: deductionAmount,
                notes: `Advance adjusted for subscription items consumption in ${saleNo}`,
                created_by: sub.created_by || null
            });
        } catch (e) {
            log('Failed to sync global advances for sub=' + sub.id + ': ' + e.message, true);
        }

        log('Accepted sale created sub=' + sub.id + ' sale=' + saleNo + ' outlet=' + outletId);
        return header.id;
    } catch (err) { log('Accepted create failed sub=' + sub.id + ': ' + err.message, true); return null; }
}

async function runSubscriptionDelivery(db) {
    const today = todayStr();
    log('Starting for date: ' + today);
    try {
        const outlets = await db.models.system_settings.findAll({ attributes: ['outlet_id'] });
        if (!outlets || outlets.length === 0) { log('No outlets. Skipping.'); return; }
        for (const outletSetting of outlets) {
            const outletId = outletSetting.outlet_id;
            if (lastRunDateByOutlet.get(outletId) === today) { log('Outlet ' + outletId + ': already ran today.'); continue; }
            let subscriptions = [];
            try {
                subscriptions = await db.models.milk_subscriptions.findAll({
                    where: {
                        outlet_id: outletId,
                        status: 'ACTIVE',
                        active_subscription: true,
                        start_date: { [Op.lte]: today },
                        end_date: { [Op.gte]: today }
                    },
                    include: [{ model: db.models.item_master, as: 'item_master', required: false,
                        attributes: ['item_code','item_name','unit','rate','retail_sale_price','hsn_code','tax_percent','tax_type'] }],
                });
            } catch (err) {
                log('subscription lookup failed (' + err.message + '), retrying with minimal filter');
                try {
                    subscriptions = await db.models.milk_subscriptions.findAll({
                        where: {
                            outlet_id: outletId,
                            status: 'ACTIVE',
                            active_subscription: true,
                            start_date: { [Op.lte]: today },
                            end_date: { [Op.gte]: today }
                        },
                        include: [{ model: db.models.item_master, as: 'item_master', required: false,
                            attributes: ['item_code','item_name','unit','rate','retail_sale_price','hsn_code','tax_percent','tax_type'] }],
                    });
                } catch (e2) { log('Fallback also failed: ' + e2.message, true); }
            }
            log('Outlet ' + outletId + ': ' + subscriptions.length + ' active subscriptions');
            let processed = 0, skipped = 0;
            for (const sub of subscriptions) {
                let alreadyDone = false;
                try {
                    const ex = await db.query(
                        'SELECT id FROM sales_headers WHERE outlet_id=:oid AND notes LIKE :pat AND sale_date::date=:today AND is_deleted=FALSE LIMIT 1',
                        { replacements: { oid: outletId, pat: '%[SUBSCRIPTION_AUTO] subscription_id=' + sub.id + '%', today }, type: db.QueryTypes.SELECT }
                    );
                    alreadyDone = ex && ex.length > 0;
                } catch (_) {}
                if (alreadyDone) { skipped++; continue; }
                await createAcceptedSaleForSubscription(db, sub, outletId, today);
                processed++;
            }
            log('Outlet ' + outletId + ': processed=' + processed + ' skipped=' + skipped);
            lastRunDateByOutlet.set(outletId, today);
        }
        log('Job completed.');
    } catch (err) { log('Job failed: ' + err.message, true); }
}

async function tryRunOnce(db) {
    const today = todayStr();
    if (globalLastRunDate === today) return;
    globalLastRunDate = today;
    await runSubscriptionDelivery(db);
}

function startSubscriptionDeliveryJob(db) {
    log('Scheduler init...');
    cron.schedule('0 6 * * *', async () => { log('6AM trigger'); await tryRunOnce(db); });
    cron.schedule('0 7 * * *', async () => { log('7AM trigger'); await tryRunOnce(db); });
    cron.schedule('0 8 * * *', async () => { log('8AM trigger'); await tryRunOnce(db); });
    const hour = new Date().getHours();
    if (hour >= 6 && hour < 11) {
        log('Server start at hour=' + hour + ', running immediately');
        tryRunOnce(db).catch(e => log('Server-start failed: ' + e.message, true));
    } else {
        log('Server start at hour=' + hour + ', waiting for 6-8 AM cron.');
    }
    log('Scheduler ready. Crons: 0 6/7/8 * * *');
}

async function getSubscriptionDraftOrdersToday(req, res) {
    try {
        const outletId = req.user.outlet_id;
        const today = todayStr();
        const results = await req.propertyDb.query(
            'SELECT sh.id,sh.sale_no,sh.customer_name,sh.customer_phone,sh.net_amount,sh.notes,sh.sale_date,sh.status,sh.customer_address FROM sales_headers sh WHERE sh.outlet_id=:oid AND sh.status=:st AND sh.notes LIKE :pat AND sh.sale_date::date=:today AND sh.is_deleted=FALSE AND sh.is_latest=TRUE ORDER BY sh.created_at ASC',
            { replacements: { oid: outletId, st: 'DRAFT', pat: '%[SUBSCRIPTION_AUTO]%', today }, type: req.propertyDb.QueryTypes.SELECT }
        );
        res.json({ success: true, data: results, count: results.length });
    } catch (err) { res.status(500).json({ success: false, error: err.message }); }
}

module.exports = { startSubscriptionDeliveryJob, getSubscriptionDraftOrdersToday };

const { Op } = require('sequelize');

/**
 * Get or initialize current business day for an outlet
 */
async function getCurrentBusinessDay(propertyDb, outletId, userId = null) {
    let day = await propertyDb.models.business_day_status.findOne({
        where: { outlet_id: outletId, status: 'OPEN' },
        order: [['created_at', 'DESC']],
        bypassOutletFilter: true
    });

    if (!day) {
        // Fallback: Check if any business day exists
        const lastDay = await propertyDb.models.business_day_status.findOne({
            where: { outlet_id: outletId },
            order: [['business_date', 'DESC']],
            bypassOutletFilter: true
        });

        let nextDateStr = new Date().toISOString().split('T')[0];
        if (lastDay) {
            const lastDate = new Date(lastDay.business_date);
            lastDate.setDate(lastDate.getDate() + 1);
            nextDateStr = lastDate.toISOString().split('T')[0];
        }

        day = await propertyDb.models.business_day_status.create({
            outlet_id: outletId,
            business_date: nextDateStr,
            status: 'OPEN',
            opened_at: new Date(),
            opened_by: userId
        }, { bypassOutletFilter: true });
    }

    return day;
}

/**
 * Pre-Audit Validation Checks
 */
async function validatePreAuditConditions(propertyDb, outletId, businessDate) {
    const warnings = [];

    // Check if outlet has restaurant features
    let isRestaurantModule = true;
    try {
        const sysSettings = await propertyDb.models.system_settings.findOne({ where: { outlet_id: outletId }, bypassOutletFilter: true });
        const modType = String(sysSettings?.module_type || sysSettings?.business_type || sysSettings?.active_module || '').toUpperCase();
        if (modType.includes('RETAIL') || modType.includes('SUPERMARKET') || modType.includes('GROCERY') || modType.includes('STORE')) {
            isRestaurantModule = false;
        }
    } catch (_) {}

    // 1. Check open KOTs (aligned strictly with KDS Active Order filtering for Restaurant outlets)
    let openKotCount = 0;
    if (isRestaurantModule && propertyDb.models.kot_headers) {
        try {
            const kots = await propertyDb.models.kot_headers.findAll({
                where: {
                    outlet_id: outletId,
                    sales_header_id: null,
                    kds_dismissed: { [Op.ne]: true },
                    status: { [Op.notIn]: ['BILLED', 'CANCELLED', 'CLOSED', 'SERVED', 'DELIVERED', 'COMPLETED', 'DISMISSED'] }
                },
                include: [
                    { model: propertyDb.models.restaurant_tables, as: 'table', attributes: ['status'], required: false }
                ],
                raw: true,
                nest: true,
                bypassOutletFilter: true
            });

            const activeKots = kots.filter(kot => {
                if (kot.table && kot.table.status) {
                    const tableStatus = kot.table.status.toLowerCase();
                    if (['billed', 'available', 'dirty', 'cleaning', 'needs cleaning'].includes(tableStatus)) {
                        return false;
                    }
                }
                return true;
            });

            openKotCount = activeKots.length;
        } catch (e) {
            openKotCount = 0;
        }
    }

    if (openKotCount > 0) {
        warnings.push({
            type: 'OPEN_KOTS',
            message: `There are ${openKotCount} open/active Kitchen Orders (KOTs) pending billing or cancellation.`
        });
    }

    // 2. Check unclosed cashier shifts / handovers
    let unclosedShiftCount = 0;
    const startDate = new Date(`${businessDate}T00:00:00.000Z`);
    const endDate = new Date(`${businessDate}T23:59:59.999Z`);

    try {
        const activeCashiers = await propertyDb.models.sales_headers.findAll({
            attributes: [[propertyDb.Sequelize.fn('DISTINCT', propertyDb.Sequelize.col('created_by')), 'cashier_id']],
            where: { outlet_id: outletId, sale_date: { [Op.gte]: startDate, [Op.lte]: endDate } },
            raw: true,
            bypassOutletFilter: true
        });

        const cashierIds = activeCashiers.map(c => c.cashier_id).filter(Boolean);
        if (cashierIds.length > 0) {
            const closedHandovers = await propertyDb.models.hr_cashier_handovers.findAll({
                attributes: ['cashier_id'],
                where: {
                    outlet_id: outletId,
                    handover_date: businessDate,
                    cashier_id: { [Op.in]: cashierIds }
                },
                raw: true,
                bypassOutletFilter: true
            });

            const closedCashierIds = new Set(closedHandovers.map(h => h.cashier_id));
            unclosedShiftCount = cashierIds.filter(id => !closedCashierIds.has(id)).length;
        }
    } catch (e) {
        unclosedShiftCount = 0;
    }

    if (unclosedShiftCount > 0) {
        warnings.push({
            type: 'UNCLOSED_SHIFTS',
            message: `There are ${unclosedShiftCount} cashier(s) who have not submitted their Shift Handover for ${businessDate}.`
        });
    }

    // 3. Check pending draft bills
    const draftBillCount = await propertyDb.models.sales_headers.count({
        where: {
            outlet_id: outletId,
            sale_date: { [Op.gte]: startDate, [Op.lte]: endDate },
            status: 'DRAFT'
        },
        bypassOutletFilter: true
    }).catch(() => 0);

    if (draftBillCount > 0) {
        warnings.push({
            type: 'DRAFT_BILLS',
            message: `There are ${draftBillCount} draft sales bills that have not been finalized.`
        });
    }

    // 4. Check if business date is overdue (system was closed at 2 AM)
    const todayStr = new Date().toISOString().split('T')[0];
    const isOverdue = businessDate < todayStr;
    if (isOverdue) {
        warnings.push({
            type: 'MISSED_NIGHT_AUDIT',
            message: `Business date ${businessDate} is past due. The system was closed/offline during the scheduled 2:00 AM audit. Execute audit now to advance to ${todayStr}.`
        });
    }

    return {
        valid: warnings.length === 0,
        isOverdue,
        todayDate: todayStr,
        businessDate,
        openKotCount,
        unclosedShiftCount,
        draftBillCount,
        warnings
    };
}

/**
 * Core Night Audit Execution Pipeline
 */
async function executeNightAudit(propertyDb, outletId, userId, options = {}) {
    const { physicalCash = 0, denominations = {}, forceRun = false, notes = '' } = options;

    const currentDay = await getCurrentBusinessDay(propertyDb, outletId, userId);
    const businessDate = currentDay.business_date;

    // Run Pre-Audit Validation
    const validation = await validatePreAuditConditions(propertyDb, outletId, businessDate);
    if (!validation.valid && !forceRun) {
        return {
            success: false,
            message: 'Pre-audit validation failed. Please clear pending warnings or run with force override.',
            validation
        };
    }

    const t = await propertyDb.transaction();
    const executionLog = [];

    try {
        executionLog.push(`[${new Date().toISOString()}] Night audit initiated for business date: ${businessDate}`);

        const startDate = new Date(`${businessDate}T00:00:00.000Z`);
        const endDate = new Date(`${businessDate}T23:59:59.999Z`);

        // 1. Summarize Revenue & Sales for the business date
        const salesHeaders = await propertyDb.models.sales_headers.findAll({
            where: {
                outlet_id: outletId,
                sale_date: { [Op.gte]: startDate, [Op.lte]: endDate },
                status: { [Op.notIn]: ['CANCELLED', 'DRAFT'] }
            },
            transaction: t,
            bypassOutletFilter: true
        });

        let grossSales = 0;
        let totalDiscounts = 0;
        let totalTaxes = 0;
        let netSales = 0;
        let cashExpected = 0;
        const paymentBreakdown = {
            CASH: 0,
            CARD: 0,
            UPI: 0,
            ROOM_POSTING: 0,
            CREDIT: 0,
            OTHER: 0
        };

        salesHeaders.forEach(sale => {
            const subtotal = parseFloat(sale.subtotal_amount || 0);
            const discount = parseFloat(sale.discount_amount || 0);
            const tax = parseFloat(sale.tax_amount || 0);
            const net = parseFloat(sale.net_amount || sale.grand_total || 0);

            grossSales += subtotal;
            totalDiscounts += discount;
            totalTaxes += tax;
            netSales += net;

            const mode = (sale.payment_mode || 'CASH').toUpperCase();
            const paymentRef = String(sale.payment_reference || '').trim();
            const changeAmount = parseFloat(sale.change_amount || 0);

            if (paymentRef.startsWith('POSPAY:')) {
                try {
                    const parsed = JSON.parse(paymentRef.substring(7));
                    if (Array.isArray(parsed) && parsed.length > 0) {
                        for (const line of parsed) {
                            const m = String(line?.method || '').trim().toUpperCase();
                            const amt = parseFloat(line?.amount || 0);
                            if (m === 'CASH') {
                                const netCash = changeAmount > 0 ? Math.max(0, amt - changeAmount) : amt;
                                paymentBreakdown.CASH += netCash;
                                cashExpected += netCash;
                            } else if (m === 'CARD') paymentBreakdown.CARD += amt;
                            else if (m === 'UPI' || m === 'ONLINE' || m === 'PAYTM' || m === 'GPAY' || m === 'PHONEPE') paymentBreakdown.UPI += amt;
                            else if (m === 'ROOM') paymentBreakdown.ROOM_POSTING += amt;
                            else if (m === 'CREDIT') paymentBreakdown.CREDIT += amt;
                            else paymentBreakdown.OTHER += amt;
                        }
                        return;
                    }
                } catch (_) {}
            }

            if (mode.includes('CASH')) {
                const netCash = net > 0 ? net : Math.max(0, parseFloat(sale.amount_paid || 0) - changeAmount);
                paymentBreakdown.CASH += netCash;
                cashExpected += netCash;
            } else if (mode.includes('CARD')) {
                paymentBreakdown.CARD += net;
            } else if (mode.includes('UPI') || mode.includes('ONLINE') || mode.includes('PAYTM') || mode.includes('GPAY')) {
                paymentBreakdown.UPI += net;
            } else if (mode.includes('ROOM')) {
                paymentBreakdown.ROOM_POSTING += net;
            } else if (mode.includes('CREDIT')) {
                paymentBreakdown.CREDIT += net;
            } else {
                paymentBreakdown.OTHER += net;
            }
        });

        const cashPhysicalVal = parseFloat(physicalCash || 0);
        const cashVariance = cashPhysicalVal - cashExpected;

        executionLog.push(`[${new Date().toISOString()}] Sales aggregated: Gross: ${grossSales.toFixed(2)}, Net: ${netSales.toFixed(2)}, Tax: ${totalTaxes.toFixed(2)}, Cash Expected: ${cashExpected.toFixed(2)}, Physical: ${cashPhysicalVal.toFixed(2)}, Variance: ${cashVariance.toFixed(2)}`);

        // 2. Create Master Audit Run Record
        const auditRun = await propertyDb.models.night_audit_runs.create({
            outlet_id: outletId,
            audit_date: businessDate,
            run_type: options.runType || 'MANUAL',
            status: validation.warnings.length > 0 ? 'COMPLETED_WITH_WARNINGS' : 'SUCCESS',
            gross_sales: grossSales,
            total_discounts: totalDiscounts,
            total_taxes: totalTaxes,
            net_sales: netSales,
            cash_expected: cashExpected,
            cash_physical: cashPhysicalVal,
            cash_variance: cashVariance,
            denominations: denominations,
            open_kot_count: validation.openKotCount,
            unclosed_shift_count: validation.unclosedShiftCount,
            execution_log: executionLog,
            started_at: currentDay.opened_at || new Date(),
            completed_at: new Date(),
            performed_by: userId
        }, { transaction: t, bypassOutletFilter: true });

        // 3. Save Breakdown Details
        await propertyDb.models.night_audit_details.bulkCreate([
            {
                audit_run_id: auditRun.id,
                outlet_id: outletId,
                section_type: 'PAYMENT_METHODS',
                detail_key: 'PAYMENT_BREAKDOWN',
                detail_value: paymentBreakdown
            },
            {
                audit_run_id: auditRun.id,
                outlet_id: outletId,
                section_type: 'TAX_SUMMARY',
                detail_key: 'TOTAL_TAXES',
                detail_value: { total_taxes: totalTaxes }
            },
            {
                audit_run_id: auditRun.id,
                outlet_id: outletId,
                section_type: 'CHECKLIST_WARNINGS',
                detail_key: 'VALIDATION_WARNINGS',
                detail_value: { warnings: validation.warnings }
            }
        ], { transaction: t, bypassOutletFilter: true });

        // 4. Update Current Business Day Status to CLOSED
        await currentDay.update({
            status: 'CLOSED',
            closed_at: new Date(),
            closed_by: userId,
            notes: notes || 'Night audit completed'
        }, { transaction: t, bypassOutletFilter: true });

        // 5. Advance Business Date to Next Day (YYYY-MM-DD + 1)
        const currentDateObj = new Date(businessDate);
        currentDateObj.setDate(currentDateObj.getDate() + 1);
        const nextBusinessDate = currentDateObj.toISOString().split('T')[0];

        const nextDay = await propertyDb.models.business_day_status.create({
            outlet_id: outletId,
            business_date: nextBusinessDate,
            status: 'OPEN',
            opened_at: new Date(),
            opened_by: userId,
            notes: `Opened automatically following Night Audit run #${auditRun.id}`
        }, { transaction: t, bypassOutletFilter: true });

        // 6. Log Audit Trail
        if (propertyDb.models.audit_logs) {
            await propertyDb.models.audit_logs.create({
                outlet_id: outletId,
                user_id: userId,
                module: 'NIGHT_AUDIT',
                action: 'NIGHT_AUDIT_COMPLETED',
                details: JSON.stringify({
                    audit_run_id: auditRun.id,
                    closed_date: businessDate,
                    next_date: nextBusinessDate,
                    net_sales: netSales
                })
            }, { transaction: t, bypassOutletFilter: true }).catch(() => {});
        }

        await t.commit();

        executionLog.push(`[${new Date().toISOString()}] Business day closed for ${businessDate}. Advanced date to ${nextBusinessDate}`);

        // Try dispatching notifications in background (Email / WhatsApp)
        try {
            await dispatchNightAuditAlert(propertyDb, outletId, auditRun, businessDate, netSales, cashVariance);
        } catch (alertErr) {
            console.warn('⚠️ Night Audit Alert dispatch error:', alertErr.message);
        }

        return {
            success: true,
            message: `Night Audit completed successfully for ${businessDate}. Advanced to ${nextBusinessDate}.`,
            auditRun,
            previousBusinessDate: businessDate,
            nextBusinessDate,
            zReportSummary: {
                auditRunId: auditRun.id,
                businessDate,
                grossSales,
                totalDiscounts,
                totalTaxes,
                netSales,
                cashExpected,
                cashPhysical: cashPhysicalVal,
                cashVariance,
                paymentBreakdown
            }
        };
    } catch (err) {
        await t.rollback();
        console.error('❌ Night Audit execution error:', err);
        return {
            success: false,
            message: `Night Audit failed: ${err.message}`
        };
    }
}

/**
 * Dispatch EOD Audit Notification Alert
 */
async function dispatchNightAuditAlert(propertyDb, outletId, auditRun, businessDate, netSales, cashVariance) {
    // Queue WhatsApp alert if whatsapp queue service exists
    try {
        const { queueMessage } = require('./whatsappQueue.service');
        if (queueMessage) {
            const alertText = `🌙 *Night Audit Report - ${businessDate}*\n\n` +
                `📊 Net Sales: ₹${netSales.toFixed(2)}\n` +
                `💵 Cash Variance: ₹${cashVariance.toFixed(2)}\n` +
                `✅ Audit Run #${auditRun.id} completed successfully.`;

            // Retrieve admin phone from system_settings or property_info
            const sysSettings = await propertyDb.models.system_settings.findOne({ where: { outlet_id: outletId }, bypassOutletFilter: true });
            const adminPhone = sysSettings?.owner_phone || sysSettings?.admin_whatsapp;
            if (adminPhone) {
                await queueMessage(propertyDb, outletId, adminPhone, alertText, 'NIGHT_AUDIT_ALERT');
            }
        }
    } catch (e) {
        // Ignore if whatsapp queue not active
    }
}

/**
 * Fetch Night Audit History
 */
async function getAuditHistory(propertyDb, outletId, limit = 20, offset = 0) {
    const runs = await propertyDb.models.night_audit_runs.findAndCountAll({
        where: { outlet_id: outletId },
        order: [['created_at', 'DESC']],
        limit: parseInt(limit, 10),
        offset: parseInt(offset, 10),
        include: [
            { model: propertyDb.models.users, as: 'user', attributes: ['id', 'username', 'full_name', 'contact_email'] },
            { model: propertyDb.models.night_audit_details, as: 'details' }
        ],
        bypassOutletFilter: true
    });

    return runs;
}

/**
 * Clear/Dismiss Open KOTs for Outlet
 */
async function clearOpenKots(propertyDb, outletId) {
    const { Op } = propertyDb.Sequelize;
    await propertyDb.models.kot_headers.update(
        { status: 'CLOSED', kds_dismissed: true },
        {
            where: {
                outlet_id: outletId,
                sales_header_id: null,
                status: { [Op.notIn]: ['BILLED', 'CANCELLED', 'CLOSED'] }
            },
            bypassOutletFilter: true
        }
    );
    return true;
}

module.exports = {
    getCurrentBusinessDay,
    validatePreAuditConditions,
    executeNightAudit,
    getAuditHistory,
    clearOpenKots
};

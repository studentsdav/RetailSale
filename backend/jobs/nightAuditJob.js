const cron = require('node-cron');
const nightAuditService = require('../services/nightAudit.service');

async function checkStartupCatchup(propertyDb) {
    try {
        console.log('🌙 Checking for missed Night Audits (system offline at 02:00 AM)...');
        const outlets = await propertyDb.models.outlets.findAll({
            where: { is_active: true },
            bypassOutletFilter: true
        }).catch(() => []);

        const todayStr = new Date().toISOString().split('T')[0];

        for (const outlet of outlets) {
            try {
                const currentDay = await nightAuditService.getCurrentBusinessDay(propertyDb, outlet.id, 1);
                if (currentDay && currentDay.business_date < todayStr) {
                    const settings = await propertyDb.models.system_settings.findOne({
                        where: { outlet_id: outlet.id },
                        bypassOutletFilter: true
                    });

                    if (settings && settings.auto_night_audit_enabled) {
                        console.log(`⚠️ Missed Night Audit detected for outlet #${outlet.id} (Date: ${currentDay.business_date} < Today: ${todayStr}). Running catch-up audit...`);
                        const result = await nightAuditService.executeNightAudit(propertyDb, outlet.id, 1, {
                            runType: 'AUTO_CATCHUP',
                            forceRun: true,
                            notes: `System startup catch-up execution for missed 02:00 AM audit (${currentDay.business_date})`
                        });
                        console.log(`✅ Catch-up Night Audit completed for outlet #${outlet.id}:`, result.message);
                    } else {
                        console.log(`⚠️ Overdue business date detected for outlet #${outlet.id} (${currentDay.business_date}). Manual audit recommended via UI.`);
                    }
                }
            } catch (err) {
                console.error(`❌ Startup catch-up error for outlet #${outlet.id}:`, err.message);
            }
        }
    } catch (e) {
        console.error('❌ Failed to execute startup catch-up check:', e.message);
    }
}

function startNightAuditJob(propertyDb) {
    // Schedule cron job to run every night at 02:00 AM
    cron.schedule('0 2 * * *', async () => {
        console.log('🌙 [CRON] Triggering automated Night Audit worker...');

        try {
            const outlets = await propertyDb.models.outlets.findAll({
                where: { is_active: true },
                bypassOutletFilter: true
            }).catch(() => []);

            for (const outlet of outlets) {
                try {
                    const settings = await propertyDb.models.system_settings.findOne({
                        where: { outlet_id: outlet.id },
                        bypassOutletFilter: true
                    });

                    if (settings && settings.auto_night_audit_enabled) {
                        console.log(`🌙 Running auto Night Audit for outlet #${outlet.id} (${outlet.name || 'Store'})...`);
                        const result = await nightAuditService.executeNightAudit(propertyDb, outlet.id, 1, {
                            runType: 'AUTO',
                            forceRun: true,
                            notes: 'Automated nightly cron execution'
                        });
                        console.log(`✅ Auto Night Audit completed for outlet #${outlet.id}:`, result.message);
                    }
                } catch (outletErr) {
                    console.error(`❌ Error running auto Night Audit for outlet #${outlet.id}:`, outletErr.message);
                }
            }
        } catch (err) {
            console.error('❌ Failed to run Night Audit cron worker:', err.message);
        }
    });

    // Run startup catch-up check immediately
    checkStartupCatchup(propertyDb);

    console.log('🌙 Night Audit cron worker initialized (Scheduled for 02:00 AM daily + Startup Catch-up).');
}

module.exports = { startNightAuditJob, checkStartupCatchup };

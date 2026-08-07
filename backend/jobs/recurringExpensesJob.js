const cron = require('node-cron');
const { Op } = require('sequelize');

/**
 * Starts the automated recurring expenses generator cron job
 * @param {Object} db Sequelize instance
 */
function startRecurringExpensesJob(db) {
    // Run daily at 00:05 AM (5 minutes past midnight)
    cron.schedule('5 0 * * *', async () => {
        console.log('[JOBS] Running recurring expenses generation check...');
        const t = await db.transaction();
        try {
            const today = new Date();
            const todayStr = today.toISOString().split('T')[0];

            // Find all active recurring expenses whose generation date is due or past
            const dueExpenses = await db.models.recurring_expenses.findAll({
                where: {
                    is_active: true,
                    next_generation_date: {
                        [Op.lte]: todayStr
                    }
                },
                transaction: t
            });

            if (dueExpenses.length === 0) {
                await t.commit();
                return;
            }

            for (const item of dueExpenses) {
                // Fetch category name if category ID is available
                let categoryName = 'General';
                if (item.expense_category_id) {
                    const cat = await db.models.expense_categories.findOne({
                        where: { id: item.expense_category_id },
                        transaction: t
                    });
                    if (cat) {
                        categoryName = cat.name || cat.category_name || 'General';
                    }
                }

                // Insert dynamic expense record
                await db.models.expense_entries.create({
                    outlet_id: item.outlet_id,
                    expense_date: todayStr,
                    category: categoryName,
                    amount: item.amount,
                    note: `[Automated Recurring] ${item.description || ''}`
                }, { transaction: t });

                // Compute next trigger date
                const nextDate = new Date(item.next_generation_date);
                if (item.frequency === 'DAILY') {
                    nextDate.setDate(nextDate.getDate() + 1);
                } else if (item.frequency === 'WEEKLY') {
                    nextDate.setDate(nextDate.getDate() + 7);
                } else if (item.frequency === 'MONTHLY') {
                    nextDate.setMonth(nextDate.getMonth() + 1);
                } else if (item.frequency === 'YEARLY') {
                    nextDate.setFullYear(nextDate.getFullYear() + 1);
                }

                const nextDateStr = nextDate.toISOString().split('T')[0];

                // Update date logs
                await item.update({
                    last_generation_date: todayStr,
                    next_generation_date: nextDateStr
                }, { transaction: t });
            }

            await t.commit();
            console.log(`[JOBS] Successfully generated ${dueExpenses.length} recurring expense entries`);
        } catch (error) {
            await t.rollback();
            console.error('[JOBS] Error during recurring expenses cron run:', error);
        }
    });
}

module.exports = { startRecurringExpensesJob };

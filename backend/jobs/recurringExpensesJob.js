const cron = require('node-cron');
const { Op } = require('sequelize');
const { toOutletDateYmd } = require('../utils/timezoneHelper');

/**
 * Process all recurring expenses:
 * 1. Generate expense entries for due/past items, and shift next_generation_date to the future.
 * 2. Auto-create Sticky Notes in user_notes for expenses coming up within remind_days_before (default 7 days).
 * @param {Object} db Sequelize instance
 */
async function processRecurringExpenses(db) {
    try {
        const today = new Date();
        const todayStr = toOutletDateYmd(today, process.env.TZ || 'Asia/Kolkata');

        // 1. Process due or past recurring expenses
        const dueExpenses = await db.models.recurring_expenses.findAll({
            where: {
                is_active: true,
                next_generation_date: {
                    [Op.lte]: todayStr
                }
            }
        });

        for (const item of dueExpenses) {
            const t = await db.transaction();
            try {
                // Fetch category name if available
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

                // Insert expense entry
                await db.models.expense_entries.create({
                    outlet_id: item.outlet_id,
                    expense_date: todayStr,
                    category: categoryName,
                    amount: item.amount,
                    note: `[Automated Recurring] ${item.description || ''}`
                }, { transaction: t });

                // Compute next trigger date step-by-step until nextDate > todayStr
                let nextDate = new Date(item.next_generation_date);
                while (true) {
                    if (item.frequency === 'DAILY') {
                        nextDate.setDate(nextDate.getDate() + 1);
                    } else if (item.frequency === 'WEEKLY') {
                        nextDate.setDate(nextDate.getDate() + 7);
                    } else if (item.frequency === 'MONTHLY') {
                        nextDate.setMonth(nextDate.getMonth() + 1);
                    } else if (item.frequency === 'YEARLY') {
                        nextDate.setFullYear(nextDate.getFullYear() + 1);
                    } else {
                        break;
                    }

                    const checkStr = nextDate.toISOString().split('T')[0];
                    if (checkStr > todayStr) break;
                }

                const nextDateStr = nextDate.toISOString().split('T')[0];

                await item.update({
                    last_generation_date: todayStr,
                    next_generation_date: nextDateStr
                }, { transaction: t });

                await t.commit();
                console.log(`[JOBS] Generated recurring expense #${item.id} (${item.description}) & shifted next date to ${nextDateStr}`);
            } catch (itemErr) {
                if (t && !t.finished) await t.rollback();
                console.error(`[JOBS] Failed to process recurring expense #${item.id}:`, itemErr.message);
            }
        }

        // 2. Advance reminder Sticky Note auto-creation
        const activeExpenses = await db.models.recurring_expenses.findAll({
            where: { is_active: true }
        });

        for (const item of activeExpenses) {
            const remindDays = parseInt(item.remind_days_before !== undefined && item.remind_days_before !== null ? item.remind_days_before : 7, 10);
            const dueDate = new Date(item.next_generation_date);
            const remindDate = new Date(dueDate);
            remindDate.setDate(remindDate.getDate() - remindDays);
            const remindDateStr = remindDate.toISOString().split('T')[0];

            if (todayStr >= remindDateStr) {
                const noteTitle = `💸 Recurring Expense: ${item.description || 'Bill'} (₹${item.amount})`;

                const existingNotes = await db.query(`
                    SELECT id FROM user_notes 
                    WHERE outlet_id = :outlet_id 
                      AND title = :title 
                      AND (is_trashed = false OR is_trashed IS NULL)
                    LIMIT 1
                `, {
                    replacements: {
                        outlet_id: item.outlet_id,
                        title: noteTitle
                    },
                    type: db.QueryTypes.SELECT
                });

                if (!existingNotes || existingNotes.length === 0) {
                    await db.query(`
                        INSERT INTO user_notes (outlet_id, user_id, title, content, color_hex, is_pinned, is_completed, is_archived, is_trashed, reminder_type, reminder_date, reminder_time, "createdAt", "updatedAt")
                        VALUES (:outlet_id, 1, :title, :content, '#FFEDD5', true, false, false, false, 'SPECIFIC_DATE', :reminder_date, '09:00 AM', NOW(), NOW())
                    `, {
                        replacements: {
                            outlet_id: item.outlet_id,
                            title: noteTitle,
                            content: `Scheduled recurring expense of ₹${item.amount} due on ${item.next_generation_date}. Frequency: ${item.frequency}.`,
                            reminder_date: item.next_generation_date
                        },
                        type: db.QueryTypes.INSERT
                    });
                    console.log(`[JOBS] Auto-created Sticky Note reminder for recurring expense #${item.id} (${item.description}) due on ${item.next_generation_date}`);
                }
            }
        }
    } catch (error) {
        console.error('[JOBS] Error during processRecurringExpenses run:', error.message);
    }
}

/**
 * Starts the automated recurring expenses generator job
 * @param {Object} db Sequelize instance
 */
function startRecurringExpensesJob(db) {
    console.log('▶️ [JOBS] Starting Recurring Expenses job...');

    // Run immediately on server boot
    processRecurringExpenses(db);

    // Run every 15 minutes for load balancing
    cron.schedule('*/15 * * * *', async () => {
        await processRecurringExpenses(db);
    });
}

module.exports = { startRecurringExpensesJob, processRecurringExpenses };

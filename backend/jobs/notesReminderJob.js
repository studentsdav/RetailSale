const cron = require('node-cron');

/**
 * Helper to parse reminderTime and construct a full Date object
 */
function getReminderDateTime(reminderDate, reminderTime) {
    let d = reminderDate ? new Date(reminderDate) : new Date();
    if (isNaN(d.getTime())) d = new Date();

    let hours = 9;
    let minutes = 0;

    if (reminderTime && typeof reminderTime === 'string') {
        const timeStr = reminderTime.trim().toUpperCase();
        const match12 = timeStr.match(/^(\d{1,2}):(\d{2})\s*(AM|PM)$/i);
        if (match12) {
            let h = parseInt(match12[1], 10);
            const m = parseInt(match12[2], 10);
            const ampm = match12[3].toUpperCase();
            if (ampm === 'PM' && h < 12) h += 12;
            if (ampm === 'AM' && h === 12) h = 0;
            hours = h;
            minutes = m;
        } else {
            const match24 = timeStr.match(/^(\d{1,2}):(\d{2})$/);
            if (match24) {
                hours = parseInt(match24[1], 10);
                minutes = parseInt(match24[2], 10);
            }
        }
    }

    const result = new Date(d);
    result.setHours(hours, minutes, 0, 0);
    return result;
}

/**
 * Process all active user notes with reminders:
 * 1. Triggers notifications for overdue/due reminders.
 * 2. Reschedules recurring reminders (DAILY, WEEKLY, MONTHLY, YEARLY) to the next future occurrence.
 * 3. Clears SPECIFIC_DATE reminders after triggering.
 */
async function processNotesReminders(db) {
    try {
        const now = new Date();

        const notes = await db.query(`
            SELECT * FROM user_notes
            WHERE is_completed = false
              AND (is_archived = false OR is_archived IS NULL)
              AND (is_trashed = false OR is_trashed IS NULL)
              AND reminder_type IS NOT NULL
              AND reminder_type != 'NONE'
        `, { type: db.QueryTypes.SELECT });

        if (!notes || notes.length === 0) return;

        for (const note of notes) {
            const targetDT = getReminderDateTime(note.reminder_date, note.reminder_time);

            if (targetDT <= now) {
                const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                const dateLabel = `${targetDT.getDate()} ${months[targetDT.getMonth()]}, ${note.reminder_time || '09:00 AM'}`;
                const notifTitle = note.title ? `📌 Sticky Note: ${note.title} (${dateLabel})` : `📌 Sticky Note Reminder (${dateLabel})`;
                const notifBody = note.content ? note.content : 'Scheduled reminder reached.';

                // Check if notification has already been created for this note title or unread instance
                const [existingNotif] = await db.query(`
                    SELECT id FROM system_notifications 
                    WHERE module = 'STICKY_NOTES' 
                      AND entity_id = :note_id 
                      AND (
                        title = :full_title
                        OR (is_read = false AND title ILIKE :base_pattern)
                      )
                    LIMIT 1
                `, {
                    replacements: {
                        note_id: note.id,
                        full_title: notifTitle,
                        base_pattern: `📌 Sticky Note: ${note.title || 'Reminder'}%`
                    },
                    type: db.QueryTypes.SELECT
                });

                if (!existingNotif) {
                    try {
                        if (db.models && db.models.system_notifications) {
                            await db.models.system_notifications.create({
                                outlet_id: note.outlet_id || 0,
                                module: 'STICKY_NOTES',
                                title: notifTitle,
                                message: notifBody,
                                type: 'INFO',
                                entity_id: note.id,
                                is_read: false,
                                created_at: new Date()
                            });
                        } else {
                            await db.query(`
                                INSERT INTO system_notifications (outlet_id, module, title, message, type, entity_id, is_read, created_at)
                                VALUES (:outlet_id, 'STICKY_NOTES', :title, :message, 'INFO', :entity_id, false, NOW())
                            `, {
                                replacements: {
                                    outlet_id: note.outlet_id || 0,
                                    title: notifTitle,
                                    message: notifBody,
                                    entity_id: note.id
                                },
                                type: db.QueryTypes.INSERT
                            });
                        }
                    } catch (nErr) {
                        console.warn('[JOBS] Warning inserting notification for note reminder:', nErr.message);
                    }
                }

                // Reschedule or clear reminder
                if (note.reminder_type === 'SPECIFIC_DATE') {
                    await db.query(`
                        UPDATE user_notes
                        SET reminder_type = 'NONE',
                            reminder_date = NULL,
                            reminder_time = NULL,
                            "updatedAt" = NOW()
                        WHERE id = :id
                    `, {
                        replacements: { id: note.id },
                        type: db.QueryTypes.UPDATE
                    });
                } else {
                    let nextDT = new Date(targetDT);

                    while (nextDT <= now) {
                        if (note.reminder_type === 'DAILY') {
                            nextDT.setDate(nextDT.getDate() + 1);
                        } else if (note.reminder_type === 'WEEKLY') {
                            nextDT.setDate(nextDT.getDate() + 7);
                        } else if (note.reminder_type === 'MONTHLY') {
                            nextDT.setMonth(nextDT.getMonth() + 1);
                        } else if (note.reminder_type === 'YEARLY') {
                            nextDT.setFullYear(nextDT.getFullYear() + 1);
                        } else {
                            break;
                        }
                    }

                    await db.query(`
                        UPDATE user_notes
                        SET reminder_date = :reminder_date,
                            "updatedAt" = NOW()
                        WHERE id = :id
                    `, {
                        replacements: {
                            id: note.id,
                            reminder_date: nextDT.toISOString()
                        },
                        type: db.QueryTypes.UPDATE
                    });
                }
            }
        }
    } catch (err) {
        console.error('[JOBS] Error in processNotesReminders:', err.message);
    }
}

/**
 * Starts the notes reminder background job
 * @param {Object} db Sequelize instance
 */
function startNotesReminderJob(db) {
    console.log('▶️ [JOBS] Starting Notes Reminder job...');

    // Run immediately on server boot
    processNotesReminders(db);

    // Run every 15 minutes for load balancing
    cron.schedule('*/15 * * * *', async () => {
        await processNotesReminders(db);
    });
}

module.exports = { startNotesReminderJob, processNotesReminders };

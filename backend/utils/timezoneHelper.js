const DEFAULT_TIMEZONE = process.env.DEFAULT_TIMEZONE || 'Asia/Kolkata';

/**
 * Retrieves configured timezone for an outlet from system_settings,
 * falling back to global system_settings or process.env.DEFAULT_TIMEZONE / Asia/Kolkata.
 */
async function getOutletTimeZone(outletId, db) {
    if (!db || !db.models || !db.models.system_settings) {
        return DEFAULT_TIMEZONE;
    }

    try {
        if (outletId) {
            const settings = await db.models.system_settings.findOne({
                where: { outlet_id: outletId },
                attributes: ['time_zone']
            });
            if (settings && settings.time_zone && String(settings.time_zone).trim()) {
                return String(settings.time_zone).trim();
            }
        }

        // Global fallback: check if any system_settings row defines a time_zone
        const globalSettings = await db.models.system_settings.findOne({
            where: { time_zone: { [db.Sequelize.Op.ne]: null } },
            attributes: ['time_zone']
        });
        if (globalSettings && globalSettings.time_zone && String(globalSettings.time_zone).trim()) {
            return String(globalSettings.time_zone).trim();
        }
    } catch (_) {
        // Fallback to default if query fails
    }

    return DEFAULT_TIMEZONE;
}

/**
 * Returns current Date adjusted to wall-clock time in the given timezone.
 */
function getNowInTimeZone(timeZone = DEFAULT_TIMEZONE) {
    const now = new Date();
    try {
        const formatter = new Intl.DateTimeFormat('en-CA', {
            timeZone: timeZone,
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
            hourCycle: 'h23'
        });
        const parts = formatter.formatToParts(now);
        const map = {};
        for (const p of parts) map[p.type] = p.value;
        const hourNum = Number(map.hour || 0) % 24;
        return new Date(
            Number(map.year),
            Number(map.month) - 1,
            Number(map.day),
            hourNum,
            Number(map.minute || 0),
            Number(map.second || 0)
        );
    } catch (err) {
        // Fallback to current system time if invalid timezone ID
        return now;
    }
}

/**
 * Returns structured date & time strings formatted according to specified timezone.
 */
function getTimeZoneContext(timeZone = DEFAULT_TIMEZONE) {
    const now = new Date();
    
    let currentDateString, currentDisplayString, currentTimeString, yesterdayDateString, yesterdayDisplayString;

    try {
        currentDateString = now.toLocaleDateString('en-CA', { timeZone }); // YYYY-MM-DD
        currentDisplayString = now.toLocaleDateString('en-US', {
            timeZone,
            month: 'long',
            day: 'numeric',
            year: 'numeric'
        });
        currentTimeString = now.toLocaleTimeString('en-US', { timeZone, hour12: true });

        const y = new Date(now.getTime() - 24 * 60 * 60 * 1000);
        yesterdayDateString = y.toLocaleDateString('en-CA', { timeZone });
        yesterdayDisplayString = y.toLocaleDateString('en-US', {
            timeZone,
            month: 'long',
            day: 'numeric',
            year: 'numeric'
        });
    } catch (_) {
        // Fallback if timezone ID is unsupported
        currentDateString = now.toISOString().split('T')[0];
        currentDisplayString = now.toDateString();
        currentTimeString = now.toTimeString();

        const y = new Date(now.getTime() - 24 * 60 * 60 * 1000);
        yesterdayDateString = y.toISOString().split('T')[0];
        yesterdayDisplayString = y.toDateString();
    }

    return {
        currentDateString,
        currentDisplayString,
        currentTimeString,
        yesterdayDateString,
        yesterdayDisplayString,
        timeZone
    };
}

/**
 * Formats a Date object or timestamp into YYYY-MM-DD in the specified timezone.
 */
function toOutletDateYmd(date = new Date(), timeZone = DEFAULT_TIMEZONE) {
    const dt = date instanceof Date ? date : new Date(date);
    try {
        return dt.toLocaleDateString('en-CA', { timeZone });
    } catch (_) {
        return dt.toISOString().split('T')[0];
    }
}

/**
 * Resolves timezone ID from express request or fallback.
 */
function getReqTimeZone(req, defaultTz = DEFAULT_TIMEZONE) {
    return req?.outletTimeZone || defaultTz;
}

/**
 * Returns current date/time adjusted to outlet time zone.
 */
async function getNowInOutletTimeZone(outletId, db) {
    const tz = await getOutletTimeZone(outletId, db);
    return getNowInTimeZone(tz);
}

module.exports = {
    getOutletTimeZone,
    getNowInTimeZone,
    getTimeZoneContext,
    toOutletDateYmd,
    getReqTimeZone,
    getNowInOutletTimeZone
};


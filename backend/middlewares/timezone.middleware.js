const { getOutletTimeZone, getNowInTimeZone, getTimeZoneContext, toOutletDateYmd } = require('../utils/timezoneHelper');

const DEFAULT_TIMEZONE = process.env.DEFAULT_TIMEZONE || 'Asia/Kolkata';

module.exports = async (req, res, next) => {
    try {
        const outletId = req.outlet?.id || req.user?.outlet_id || req.headers['x-outlet-id'];
        const db = req.propertyDb;

        const timeZone = await getOutletTimeZone(outletId, db);

        req.outletTimeZone = timeZone;
        req.nowInTimeZone = getNowInTimeZone(timeZone);
        req.timeZoneContext = getTimeZoneContext(timeZone);
        req.toOutletDateYmd = (date) => toOutletDateYmd(date, timeZone);
    } catch (_) {
        req.outletTimeZone = DEFAULT_TIMEZONE;
        req.nowInTimeZone = getNowInTimeZone(DEFAULT_TIMEZONE);
        req.timeZoneContext = getTimeZoneContext(DEFAULT_TIMEZONE);
        req.toOutletDateYmd = (date) => toOutletDateYmd(date, DEFAULT_TIMEZONE);
    }
    next();
};

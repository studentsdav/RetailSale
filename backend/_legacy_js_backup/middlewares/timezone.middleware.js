const { getOutletTimeZone, getNowInTimeZone, getTimeZoneContext, toOutletDateYmd, getOutletDateBounds } = require('../utils/timezoneHelper');

const DEFAULT_TIMEZONE = process.env.DEFAULT_TIMEZONE || 'Asia/Kolkata';

module.exports = async (req, res, next) => {
    try {
        const outletId = req.outlet?.id || req.user?.outlet_id || req.headers['x-outlet-id'] || req.query?.outlet_id;
        const db = req.propertyDb;

        const timeZone = await getOutletTimeZone(outletId, db);

        req.outletTimeZone = timeZone;
        req.nowInTimeZone = getNowInTimeZone(timeZone);
        req.timeZoneContext = getTimeZoneContext(timeZone);
        req.toOutletDateYmd = (date) => toOutletDateYmd(date, timeZone);
        req.getDateBounds = (fromDate, toDate) => getOutletDateBounds(fromDate, toDate, timeZone);
    } catch (_) {
        req.outletTimeZone = DEFAULT_TIMEZONE;
        req.nowInTimeZone = getNowInTimeZone(DEFAULT_TIMEZONE);
        req.timeZoneContext = getTimeZoneContext(DEFAULT_TIMEZONE);
        req.toOutletDateYmd = (date) => toOutletDateYmd(date, DEFAULT_TIMEZONE);
        req.getDateBounds = (fromDate, toDate) => getOutletDateBounds(fromDate, toDate, DEFAULT_TIMEZONE);
    }
    next();
};

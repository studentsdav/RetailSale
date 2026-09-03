function normalizeDateKey(value) {
    if (!value) return null;

    if (value instanceof Date) {
        if (Number.isNaN(value.getTime())) return null;
        const year = value.getFullYear();
        const month = String(value.getMonth() + 1).padStart(2, '0');
        const day = String(value.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    const trimmed = String(value).trim();
    if (!trimmed) return null;

    const iso = /^(\d{4})-(\d{2})-(\d{2})$/.exec(trimmed);
    if (iso) {
        return `${iso[1]}-${iso[2]}-${iso[3]}`;
    }

    const parts = trimmed.split(/[\/-]/).map(part => part.trim());
    if (parts.length === 3) {
        const first = Number(parts[0]);
        const second = Number(parts[1]);
        const third = Number(parts[2]);

        if ([first, second, third].every(Number.isFinite)) {
            const isYearLast = third >= 1000;
            const isYearFirst = first >= 1000;

            if (isYearLast) {
                // DD-MM-YYYY format (e.g. 04-09-2026: first=4 (day), second=9 (month), third=2026 (year))
                if (first >= 1 && first <= 31 && second >= 1 && second <= 12) {
                    return `${third}-${String(second).padStart(2, '0')}-${String(first).padStart(2, '0')}`;
                }
                // MM-DD-YYYY format fallback if second > 12
                if (second > 12 && first >= 1 && first <= 12) {
                    return `${third}-${String(first).padStart(2, '0')}-${String(second).padStart(2, '0')}`;
                }
            }

            if (isYearFirst) {
                return `${first}-${String(second).padStart(2, '0')}-${String(third).padStart(2, '0')}`;
            }
        }
    }

    const parsed = new Date(trimmed);
    if (Number.isNaN(parsed.getTime())) return null;
    const year = parsed.getFullYear();
    const month = String(parsed.getMonth() + 1).padStart(2, '0');
    const day = String(parsed.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}

module.exports = {
    normalizeDateKey
};

const analyticsService = require('../../services/analytics.service');

function resolveOutletId(req) {
    return Number(req?.user?.outlet_id) || 0;
}

exports.getRfmSegments = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await analyticsService.getRfmSegments(req.propertyDb, outletId);
        return res.json({ success: true, data });
    } catch (error) {
        console.error('[ANALYTICS] rfm-segments failed:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to load RFM segments'
        });
    }
};

exports.getSalesTrend = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await analyticsService.getSalesTrend(req.propertyDb, outletId);
        return res.json({ success: true, data });
    } catch (error) {
        console.error('[ANALYTICS] sales-trend failed:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to load sales trend'
        });
    }
};

exports.getMarketBasket = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await analyticsService.getMarketBasket(req.propertyDb, outletId);
        return res.json({ success: true, data });
    } catch (error) {
        console.error('[ANALYTICS] market-basket failed:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to load market basket analytics'
        });
    }
};

exports.getTopCustomerItems = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await analyticsService.getTopCustomerItems(req.propertyDb, outletId);
        return res.json({ success: true, data });
    } catch (error) {
        console.error('[ANALYTICS] top-customer-items failed:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to load top customer item analytics'
        });
    }
};

// ---------------- TEXT-TO-QUERY AI ANALYTICS ENGINE (Phase 3) ----------------

const crypto = require('crypto');
const aiService = require('../../services/ai.service');
const pdfService = require('../../services/analyticsReportPdf.service');

// Memory cache Map for full dataset exports (10 min TTL)
const queryCache = new Map();

function setCachedData(key, data, ttlSeconds = 600) {
    queryCache.set(key, {
        data,
        expiresAt: Date.now() + (ttlSeconds * 1000)
    });
}

function getCachedData(key) {
    const entry = queryCache.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
        queryCache.delete(key);
        return null;
    }
    return entry.data;
}

exports.executeNaturalLanguageQuery = async (req, res) => {
    try {
        const { question, aiProvider, aiApiKey } = req.body;
        const outletId = resolveOutletId(req);

        if (!question || String(question).trim().isEmpty) {
            return res.status(400).json({ success: false, message: 'Question prompt is required' });
        }

        // 1. Translate prompt to raw SQL query
        const sqlQuery = await aiService.translateTextToQuery(question, { aiProvider, aiApiKey });

        // 2. Execute securely inside read-only transaction
        const t = await req.propertyDb.transaction();
        let results = [];
        try {
            await req.propertyDb.query('SET TRANSACTION READ ONLY', { transaction: t });
            results = await req.propertyDb.query(sqlQuery, {
                replacements: { outletId },
                type: req.propertyDb.QueryTypes.SELECT,
                transaction: t
            });
            await t.commit();
        } catch (dbErr) {
            await t.rollback();
            console.error('[AI QUERY SYSTEM] Database execution failed:', dbErr.message);
            return res.status(400).json({
                success: false,
                message: `Failed to execute generated query: ${dbErr.message}`,
                query: sqlQuery
            });
        }

        // 3. Narrative analysis summary on top 100 rows
        const sampleRows = results.slice(0, 100);
        const summaryText = await aiService.analyzeDatasetSummary(question, JSON.stringify(sampleRows), { aiProvider, aiApiKey });

        // 4. Cache full result
        const cacheId = crypto.randomUUID();
        setCachedData(cacheId, {
            results,
            summaryText,
            question
        });

        res.json({
            success: true,
            cacheId,
            summaryText,
            sampleRows,
            totalRows: results.length,
            query: sqlQuery
        });

    } catch (error) {
        console.error('[AI ANALYTICS ENGINE CRASH]:', error.message);
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.exportQueryCsv = async (req, res) => {
    try {
        const cacheId = req.query.cacheId;
        const cached = getCachedData(cacheId);

        if (!cached || !cached.results) {
            return res.status(404).send('Cache expired or invalid report session.');
        }

        const data = cached.results;
        if (data.length === 0) {
            return res.status(200).send('No data records available');
        }

        const keys = Object.keys(data[0]);
        const csvRows = [];
        csvRows.push(keys.join(',')); // headers

        for (const row of data) {
            const values = keys.map(k => {
                const val = row[k] != null ? String(row[k]) : '';
                // Escape double quotes and commas
                const escaped = val.replace(/"/g, '""');
                return `"${escaped}"`;
            });
            csvRows.push(values.join(','));
        }

        const csvContent = csvRows.join('\n');
        
        res.setHeader('Content-Type', 'text/csv');
        res.setHeader('Content-Disposition', 'attachment; filename="ai_analytics_report.csv"');
        res.status(200).send(csvContent);

    } catch (error) {
        console.error('[CSV EXPORT ERROR]:', error.message);
        res.status(500).send('Failed to compile CSV file');
    }
};

exports.exportQueryPdf = async (req, res) => {
    try {
        const cacheId = req.query.cacheId;
        const cached = getCachedData(cacheId);

        if (!cached || !cached.results) {
            return res.status(404).send('Cache expired or invalid report session.');
        }

        const pdfBuffer = await pdfService.generateAnalyticsReportPdf(
            cached.summaryText || 'AI summary analysis dataset report.',
            cached.results
        );

        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', 'attachment; filename="ai_analytics_report.pdf"');
        res.setHeader('Content-Length', pdfBuffer.length);
        
        res.end(pdfBuffer);

    } catch (error) {
        console.error('[PDF REPORT ERROR]:', error.message);
        res.status(500).send('Failed to compile PDF document');
    }
};

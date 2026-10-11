const { Router } = require('express');

const router = Router();

// GET /api/marketplace/vendors
// Returns ONLY registered platform outlets that have become distributors (Strictly excludes supplier_master)
router.get('/vendors', async (req, res) => {
    try {
        const { city, search, category, exclude_outlet_id, exclude_code } = req.query;
        const currentOutletId = req.user?.outlet_id || exclude_outlet_id;
        const currentOutletCode = (req.user?.outlet_code || exclude_code || '').toString().trim().toLowerCase();
        const db = req.propertyDb || require('../db/models');

        const vendors = [];
        const seenCodes = new Set();

        if (db) {
            // Fetch ONLY outlets registered on our system that are marked as distributors
            try {
                let outletSql = `
                    SELECT 
                        o.id as outlet_id,
                        o.outlet_code,
                        COALESCE(NULLIF(p.property_name, ''), o.outlet_name) as business_name,
                        COALESCE(NULLIF(p.legal_name, ''), p.property_name, o.outlet_name) as trade_name,
                        COALESCE(p.address, '') as address,
                        COALESCE(NULLIF(p.city, ''), 'Global') as city,
                        COALESCE(p.state, '') as state,
                        COALESCE(p.mobile, o.contact_phone, '') as phone,
                        COALESCE(p.email, o.contact_email, '') as email,
                        COALESCE(p.gst_no, o.tax_id, '') as gstin,
                        COALESCE(o.outlet_type, 'DISTRIBUTOR') as outlet_type,
                        COALESCE(o.is_distributor, true) as is_distributor
                    FROM outlets o
                    LEFT JOIN property_info p ON (p.outlet_id = o.id OR p.id = o.id)
                    WHERE o.is_active = true
                      AND COALESCE(o.is_distributor, true) = true
                `;
                if (currentOutletId) {
                    outletSql += ` AND o.id != ${Number(currentOutletId)}`;
                }
                if (currentOutletCode) {
                    outletSql += ` AND LOWER(o.outlet_code) != LOWER('${currentOutletCode.replace(/'/g, "''")}')`;
                }
                outletSql += ` ORDER BY o.id ASC`;

                const [outlets] = await db.query(outletSql);
                if (Array.isArray(outlets)) {
                    for (const o of outlets) {
                        const code = (o.outlet_code || `OUTLET_${o.outlet_id}`).trim();
                        const name = (o.business_name || '').trim();
                        if (!name) continue;
                        if (seenCodes.has(code.toLowerCase())) continue;
                        seenCodes.add(code.toLowerCase());

                        vendors.push({
                            id: code,
                            vendor_code: code,
                            business_name: name,
                            trade_name: o.trade_name || name,
                            address: o.address || 'Registered Platform Distribution Center',
                            city: o.city || 'Global',
                            state: o.state || '',
                            phone: o.phone || '',
                            email: o.email || '',
                            gstin: o.gstin || '',
                            is_verified: Boolean(o.gstin && String(o.gstin).trim()),
                            is_b2b_supplier: true,
                            is_b2c_retailer: false,
                            min_order_amount: 1000.0,
                            delivery_estimate: 'Same Day / Global Dispatch',
                            categories: ['Wholesale Supply', 'Distributor', 'All Products'],
                            is_open: true,
                            rating: 4.9,
                            total_reviews: 128
                        });
                    }
                }
            } catch (err) {
                console.warn('[MARKETPLACE] Registered distributors query warn:', err.message);
            }
        }

        // Apply search filter if provided
        let result = vendors;
        if (search && String(search).trim()) {
            const q = String(search).trim().toLowerCase();
            result = result.filter(v =>
                v.business_name.toLowerCase().includes(q) ||
                v.trade_name.toLowerCase().includes(q) ||
                v.gstin.toLowerCase().includes(q) ||
                v.city.toLowerCase().includes(q) ||
                v.address.toLowerCase().includes(q) ||
                v.phone.includes(q)
            );
        }

        // Apply city filter if not global
        if (city && String(city).trim()) {
            const targetCity = String(city).trim().toLowerCase();
            const isGlobal = targetCity === 'all' || targetCity.includes('global') || targetCity === 'all locations (global)';
            if (!isGlobal) {
                const matches = result.filter(v =>
                    v.city.toLowerCase().includes(targetCity) ||
                    v.address.toLowerCase().includes(targetCity)
                );
                if (matches.length > 0) {
                    const others = result.filter(v => !matches.includes(v));
                    result = [...matches, ...others];
                }
            }
        }

        // Apply category filter
        if (category && category !== 'All') {
            const cat = String(category).toLowerCase();
            result = result.filter(v =>
                Array.isArray(v.categories) && v.categories.some((c) => c.toLowerCase().includes(cat))
            );
        }

        return res.json({ success: true, data: result });
    } catch (error) {
        console.error('[MARKETPLACE VENDORS ERROR]:', error.message);
        return res.status(500).json({ success: false, message: error.message });
    }
});

// POST /api/marketplace/distributor-status
router.post('/distributor-status', async (req, res) => {
    try {
        const outletId = req.user?.outlet_id || req.body?.outlet_id;
        const { is_distributor } = req.body;
        if (!outletId) {
            return res.status(400).json({ success: false, message: 'Outlet ID is required' });
        }
        const db = req.propertyDb || require('../db/models');
        await db.query(
            'UPDATE outlets SET is_distributor = :is_distributor WHERE id = :outletId',
            { replacements: { is_distributor: Boolean(is_distributor), outletId } }
        );
        return res.json({ success: true, message: 'Distributor status updated successfully' });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
});

// GET /api/marketplace/vendors/:id/catalog
router.get('/vendors/:id/catalog', async (req, res) => {
    try {
        const db = req.propertyDb || require('../db/models');
        if (!db) {
            return res.json({ success: true, data: [] });
        }

        let sql = `
            SELECT 
                id,
                item_code,
                item_name,
                brand,
                unit,
                COALESCE(cost_price, 0) as wholesale_price,
                COALESCE(mrp, 0) as mrp,
                COALESCE(sales_price, 0) as retail_price,
                COALESCE(pack_size, '1') as pack_size,
                5 as min_b2b_order_qty,
                true as in_stock,
                category
            FROM item_master
            WHERE is_active = true
            LIMIT 50
        `;
        const [items] = await db.query(sql);
        return res.json({ success: true, data: items || [] });
    } catch (error) {
        return res.status(500).json({ success: false, message: error.message });
    }
});

module.exports = router;

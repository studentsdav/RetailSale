function toNumber(value) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
}

function roundAmount(value) {
    return Number(toNumber(value).toFixed(2));
}

async function calculateCommissionFields(db, saleSource, baseAmount, netAmount, saleItems = [], transaction = null) {
    let platform_commission_rate = 0;
    let platform_gst_rate = 0;
    let platform_tds_rate = 0;
    let platform_tcs_rate = 0;
    let platform_id = null;

    // 1. Resolve Platform
    const sourceSettings = saleSource
        ? await db.models.sale_sources.findOne({
            where: { name: saleSource, is_active: true },
            transaction
          })
        : null;

    if (sourceSettings) {
        platform_id = sourceSettings.id;
        platform_commission_rate = toNumber(sourceSettings.commission_rate);
        platform_gst_rate = toNumber(sourceSettings.gst_rate_on_commission);
        platform_tds_rate = toNumber(sourceSettings.tds_rate);
        platform_tcs_rate = toNumber(sourceSettings.tcs_rate);
    }

    const base = baseAmount > 0 ? baseAmount : netAmount;

    let totalCommission = 0;

    // 2. Run Hierarchical Rule Engine if items are provided
    if (platform_id && Array.isArray(saleItems) && saleItems.length > 0) {
        // Fetch items master details
        const itemIds = saleItems.map(item => Number(item.item_id || item.product_id)).filter(Boolean);
        const itemMasters = itemIds.length > 0
            ? await db.models.item_master.findAll({ where: { id: itemIds }, transaction })
            : [];
        const itemMasterMap = new Map(itemMasters.map(item => [item.id, item]));

        // Fetch category group details
        const allGroups = await db.models.item_groups.findAll({ transaction });
        const groupNameToId = new Map(allGroups.map(g => [g.group_name, g.id]));

        // Fetch active platform rules
        const rules = await db.models.commission_rules.findAll({
            where: { platform_id, is_active: true },
            transaction
        });

        for (const item of saleItems) {
            const itemId = Number(item.item_id || item.product_id);
            const qty = toNumber(item.qty);
            const rate = toNumber(item.rate);

            const itemMaster = itemMasterMap.get(itemId);
            const categoryId = itemMaster ? groupNameToId.get(itemMaster.item_group) : null;

            // Filter matching rules by price slab
            const matchingRules = rules.filter(r => {
                const minPrice = toNumber(r.min_price);
                const maxPrice = toNumber(r.max_price);
                const priceMatch = rate >= minPrice && rate <= maxPrice;
                if (!priceMatch) return false;

                // Match specific product
                if (r.product_id && r.product_id === itemId) return true;
                // Match specific category
                if (r.category_id && r.category_id === categoryId && !r.product_id) return true;
                // Match platform default
                if (!r.product_id && !r.category_id) return true;

                return false;
            });

            if (matchingRules.length > 0) {
                // Sort matching rules by specificity and priority:
                // Specificity score: ProductSpecific (3) > CategorySpecific (2) > PlatformDefault (1)
                matchingRules.sort((a, b) => {
                    const scoreA = a.product_id ? 3 : (a.category_id ? 2 : 1);
                    const scoreB = b.product_id ? 3 : (b.category_id ? 2 : 1);
                    if (scoreA !== scoreB) {
                        return scoreB - scoreA;
                    }
                    return b.priority - a.priority;
                });

                const rule = matchingRules[0];
                const percentageFee = toNumber(rule.percentage_fee);
                const fixedFee = toNumber(rule.fixed_fee);
                const itemCommission = (rate * (percentageFee / 100)) + fixedFee;
                totalCommission += itemCommission * qty;
            } else {
                // Platform fallback
                totalCommission += (rate * (platform_commission_rate / 100)) * qty;
            }
        }
    } else {
        // Flat calculation fallback
        totalCommission = base * (platform_commission_rate / 100);
    }

    const commission_amount = roundAmount(totalCommission);
    const commission_tax_amount = roundAmount(commission_amount * (platform_gst_rate / 100));
    const tcs_amount = roundAmount(base * (platform_tcs_rate / 100));
    const tds_amount = roundAmount(base * (platform_tds_rate / 100));
    const net_payout = roundAmount(netAmount);

    return {
        commission_rate: platform_commission_rate,
        gst_rate_on_commission: platform_gst_rate,
        tds_rate: platform_tds_rate,
        tcs_rate: platform_tcs_rate,
        commission_amount,
        commission_tax_amount,
        tcs_amount,
        tds_amount,
        net_payout
    };
}

module.exports = { calculateCommissionFields };

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
    let appliedRulesList = [];
    let totalPercentageCommission = 0;
    let totalBaseForPercentage = 0;
    let totalFixedCommAmount = 0;

    // 2. Run Hierarchical Rule Engine if items are provided
    if (platform_id && Array.isArray(saleItems) && saleItems.length > 0) {
        // Fetch items master details
        const itemIds = saleItems.map(item => Number(item.item_id || item.product_id)).filter(Boolean);
        const itemMasters = itemIds.length > 0
            ? await db.models.item_master.findAll({ where: { id: itemIds }, transaction })
            : [];
        const itemMasterMap = new Map(itemMasters.map(item => [item.id, item]));

        // Fetch category group details for the current outlet to avoid duplicate name conflicts
        const store = require('./context').contextStorage.getStore();
        const currentOutletId = store?.get('outlet_id') || itemMasters[0]?.outlet_id;
        const allGroups = await db.models.item_groups.findAll({
            where: currentOutletId ? { outlet_id: currentOutletId } : {},
            transaction
        });
        const groupNameToId = new Map(allGroups.map(g => [g.group_name, g.id]));

        // Fetch active platform rules
        const rules = await db.models.commission_rules.findAll({
            where: { platform_id, is_active: true },
            transaction
        });

        const appliedRulesSet = new Set();
        const ruleGroups = new Map();

        for (const item of saleItems) {
            const itemId = Number(item.item_id || item.product_id);
            const qty = toNumber(item.qty);
            const rate = toNumber(item.rate);

            totalBaseForPercentage += rate * qty;

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

            let appliedRule = null;
            let groupKey = 'fallback';

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

                appliedRule = matchingRules[0];
                groupKey = `rule_${appliedRule.id}`;
            }

            if (!ruleGroups.has(groupKey)) {
                ruleGroups.set(groupKey, {
                    rule: appliedRule,
                    items: [],
                    totalValue: 0
                });
            }

            const group = ruleGroups.get(groupKey);
            group.items.push({ qty, rate });
            group.totalValue += rate * qty;
        }

        // Process groups and aggregate commissions
        for (const [groupKey, group] of ruleGroups.entries()) {
            if (groupKey === 'fallback') {
                const fallbackPctAmount = group.totalValue * (platform_commission_rate / 100);
                totalCommission += fallbackPctAmount;
                totalPercentageCommission += fallbackPctAmount;
                appliedRulesSet.add('Platform Fallback');
            } else {
                const rule = group.rule;
                const percentageFee = toNumber(rule.percentage_fee);
                const fixedFee = toNumber(rule.fixed_fee);

                const groupPercentageAmount = group.totalValue * (percentageFee / 100);
                totalCommission += groupPercentageAmount + fixedFee;
                totalPercentageCommission += groupPercentageAmount;
                totalFixedCommAmount += fixedFee;

                if (rule.product_id) {
                    appliedRulesSet.add(`Product: ${itemMasterMap.get(rule.product_id)?.item_name || 'Item ' + rule.product_id}`);
                } else if (rule.category_id) {
                    const matchedGrp = allGroups.find(g => g.id === rule.category_id);
                    appliedRulesSet.add(`Category: ${matchedGrp?.group_name || 'Category ' + rule.category_id}`);
                } else {
                    appliedRulesSet.add('Platform Default');
                }
            }
        }

        appliedRulesList = Array.from(appliedRulesSet);
    } else {
        // Flat calculation fallback
        totalCommission = base * (platform_commission_rate / 100);
        totalPercentageCommission = totalCommission;
        totalBaseForPercentage = base;
        appliedRulesList = ['Platform Fallback'];
    }

    const resolved_commission_rate = totalBaseForPercentage > 0
        ? roundAmount((totalPercentageCommission / totalBaseForPercentage) * 100)
        : platform_commission_rate;

    const commission_amount = roundAmount(totalCommission);
    const commission_tax_amount = roundAmount(commission_amount * (platform_gst_rate / 100));
    const tcs_amount = roundAmount(base * (platform_tcs_rate / 100));
    const tds_amount = roundAmount(base * (platform_tds_rate / 100));
    const net_payout = roundAmount(netAmount);
    const applied_rules = appliedRulesList.join(', ');

    return {
        commission_rate: resolved_commission_rate,
        gst_rate_on_commission: platform_gst_rate,
        tds_rate: platform_tds_rate,
        tcs_rate: platform_tcs_rate,
        commission_amount,
        commission_tax_amount,
        tcs_amount,
        tds_amount,
        net_payout,
        applied_rules,
        commission_percentage_amount: roundAmount(totalPercentageCommission),
        commission_fixed_amount: roundAmount(totalFixedCommAmount)
    };
}

module.exports = { calculateCommissionFields };

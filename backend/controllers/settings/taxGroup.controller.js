function getDefaultTaxGroupsForCountry(country) {
    const norm = (country || 'INDIA').toString().trim().toUpperCase();

    if (norm.includes('INDIA') || norm === 'IN' || norm === 'IND') {
        return [
            {
                group_name: 'GST 0% (NIL)',
                group_code: 'GST_0',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'CGST_0', component_name: 'CGST', rate: 0.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' },
                    { component_code: 'SGST_0', component_name: 'SGST', rate: 0.0, calculation_order: 2, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'GST 5%',
                group_code: 'GST_5',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'CGST_2.5', component_name: 'CGST', rate: 2.5, calculation_order: 1, calculation_type: 'FLAT_PERCENT' },
                    { component_code: 'SGST_2.5', component_name: 'SGST', rate: 2.5, calculation_order: 2, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'GST 12%',
                group_code: 'GST_12',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'CGST_6', component_name: 'CGST', rate: 6.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' },
                    { component_code: 'SGST_6', component_name: 'SGST', rate: 6.0, calculation_order: 2, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'GST 18%',
                group_code: 'GST_18',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'CGST_9', component_name: 'CGST', rate: 9.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' },
                    { component_code: 'SGST_9', component_name: 'SGST', rate: 9.0, calculation_order: 2, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'GST 28%',
                group_code: 'GST_28',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'CGST_14', component_name: 'CGST', rate: 14.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' },
                    { component_code: 'SGST_14', component_name: 'SGST', rate: 14.0, calculation_order: 2, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'IGST 5%',
                group_code: 'IGST_5',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'IGST_5', component_name: 'IGST', rate: 5.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'IGST 12%',
                group_code: 'IGST_12',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'IGST_12', component_name: 'IGST', rate: 12.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'IGST 18%',
                group_code: 'IGST_18',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'IGST_18', component_name: 'IGST', rate: 18.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'IGST 28%',
                group_code: 'IGST_28',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'IGST_28', component_name: 'IGST', rate: 28.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            }
        ];
    }

    if (norm.includes('USA') || norm.includes('UNITED STATES') || norm === 'US') {
        return [
            {
                group_name: 'USA Zero / Exempt (0%)',
                group_code: 'USA_EXEMPT',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'EXEMPT_0', component_name: 'Exempt', rate: 0.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'USA Standard Sales Tax (6.25%)',
                group_code: 'USA_SALES_6.25',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'STATE_TAX_6.25', component_name: 'State Sales Tax', rate: 6.25, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'USA Retail Sales Tax (7.25%)',
                group_code: 'USA_SALES_7.25',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'STATE_TAX_6', component_name: 'State Sales Tax', rate: 6.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' },
                    { component_code: 'LOCAL_TAX_1.25', component_name: 'Local County Tax', rate: 1.25, calculation_order: 2, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'USA Combined Sales Tax (8.25%)',
                group_code: 'USA_SALES_8.25',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'STATE_TAX_6.25', component_name: 'State Sales Tax', rate: 6.25, calculation_order: 1, calculation_type: 'FLAT_PERCENT' },
                    { component_code: 'CITY_TAX_2', component_name: 'City Sales Tax', rate: 2.0, calculation_order: 2, calculation_type: 'FLAT_PERCENT' }
                ]
            }
        ];
    }

    if (norm.includes('KENYA') || norm === 'KE') {
        return [
            {
                group_name: 'Kenya Zero-Rated (0%)',
                group_code: 'KE_VAT_0',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'KE_ZERO_0', component_name: 'Zero-Rated VAT', rate: 0.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'Kenya Standard VAT (16%)',
                group_code: 'KE_VAT_16',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'KE_VAT_16', component_name: 'VAT', rate: 16.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'Kenya Hospitality & Catering (18%)',
                group_code: 'KE_HOSP_18',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'KE_VAT_16', component_name: 'VAT', rate: 16.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' },
                    { component_code: 'KE_CTL_2', component_name: 'Catering & Tourism Levy', rate: 2.0, calculation_order: 2, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'Kenya Fuel VAT (8%)',
                group_code: 'KE_VAT_8',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'KE_VAT_8', component_name: 'Fuel VAT', rate: 8.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            }
        ];
    }

    if (norm.includes('UK') || norm.includes('ENGLAND') || norm.includes('BRITAIN') || norm.includes('UNITED KINGDOM') || norm === 'GB') {
        return [
            {
                group_name: 'UK Zero Rate (0%)',
                group_code: 'UK_VAT_0',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'UK_ZERO_0', component_name: 'Zero Rate VAT', rate: 0.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'UK Reduced VAT (5%)',
                group_code: 'UK_VAT_5',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'UK_RED_5', component_name: 'Reduced VAT', rate: 5.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'UK Standard VAT (20%)',
                group_code: 'UK_VAT_20',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'UK_STD_20', component_name: 'Standard VAT', rate: 20.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            }
        ];
    }

    if (norm.includes('GERMANY') || norm.includes('DEUTSCH') || norm === 'DE') {
        return [
            {
                group_name: 'DE Steuerfrei (0%)',
                group_code: 'DE_MWST_0',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'DE_ZERO_0', component_name: 'Steuerfrei', rate: 0.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'DE Ermäßigter Satz (7%)',
                group_code: 'DE_MWST_7',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'DE_RED_7', component_name: 'Ermäßigter MwSt', rate: 7.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'DE Regelsteuersatz (19%)',
                group_code: 'DE_MWST_19',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'DE_STD_19', component_name: 'Regelsteuersatz MwSt', rate: 19.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            }
        ];
    }

    if (norm.includes('BRAZIL') || norm.includes('BRASIL') || norm === 'BR') {
        return [
            {
                group_name: 'BR Isento (0%)',
                group_code: 'BR_ISENTO',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'BR_ISENTO_0', component_name: 'Isento de Impostos', rate: 0.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'BR ICMS Padrão (18%)',
                group_code: 'BR_ICMS_18',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'BR_ICMS_18', component_name: 'ICMS Estadual', rate: 18.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'BR Tributação Completa (27.25%)',
                group_code: 'BR_TRIB_27.25',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'BR_ICMS_18', component_name: 'ICMS', rate: 18.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' },
                    { component_code: 'BR_PIS_1.65', component_name: 'PIS', rate: 1.65, calculation_order: 2, calculation_type: 'FLAT_PERCENT' },
                    { component_code: 'BR_COFINS_7.6', component_name: 'COFINS', rate: 7.6, calculation_order: 3, calculation_type: 'FLAT_PERCENT' }
                ]
            }
        ];
    }

    if (norm.includes('EU') || norm.includes('EUROPE')) {
        return [
            {
                group_name: 'EU Zero-Rated (0%)',
                group_code: 'EU_VAT_0',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'EU_ZERO_0', component_name: 'Zero Rate VAT', rate: 0.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'EU Reduced VAT (10%)',
                group_code: 'EU_VAT_10',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'EU_RED_10', component_name: 'Reduced VAT', rate: 10.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            },
            {
                group_name: 'EU Standard VAT (21%)',
                group_code: 'EU_VAT_21',
                is_tax_inclusive: false,
                components: [
                    { component_code: 'EU_STD_21', component_name: 'Standard VAT', rate: 21.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
                ]
            }
        ];
    }

    return [
        {
            group_name: 'Zero Tax (0%)',
            group_code: 'TAX_0',
            is_tax_inclusive: false,
            components: [
                { component_code: 'ZERO_0', component_name: 'Zero Tax', rate: 0.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
            ]
        },
        {
            group_name: 'Standard Tax (10%)',
            group_code: 'TAX_10',
            is_tax_inclusive: false,
            components: [
                { component_code: 'TAX_10', component_name: 'Standard Tax', rate: 10.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
            ]
        },
        {
            group_name: 'Standard Tax (15%)',
            group_code: 'TAX_15',
            is_tax_inclusive: false,
            components: [
                { component_code: 'TAX_15', component_name: 'Standard Tax', rate: 15.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
            ]
        },
        {
            group_name: 'Standard Tax (18%)',
            group_code: 'TAX_18',
            is_tax_inclusive: false,
            components: [
                { component_code: 'TAX_18', component_name: 'Standard Tax', rate: 18.0, calculation_order: 1, calculation_type: 'FLAT_PERCENT' }
            ]
        }
    ];
}

async function resolveOutletId(req, inputOutletId) {
    let outletId = Number(inputOutletId || req.outlet?.id || req.user?.outlet_id || req.headers?.['x-outlet-id'] || 0);
    if (!outletId || outletId <= 0) {
        try {
            const outlet = await req.propertyDb.models.outlets.findOne({
                attributes: ['id'],
                order: [['id', 'ASC']]
            });
            if (outlet) outletId = outlet.id;
        } catch (_) {}
    }
    return outletId || 1;
}

async function resolveBillingCountry(req, outletId, queryCountry) {
    if (queryCountry && String(queryCountry).trim().length > 0) {
        return String(queryCountry).trim();
    }
    if (req.headers && req.headers['x-country']) {
        return String(req.headers['x-country']).trim();
    }

    try {
        if (req.propertyDb.models.system_settings) {
            const settings = await req.propertyDb.models.system_settings.findOne({
                where: { outlet_id: outletId },
                attributes: ['billing_country']
            });
            if (settings && settings.billing_country && settings.billing_country.trim().length > 0) {
                return settings.billing_country.trim();
            }
        }
    } catch (_) {}

    try {
        if (req.propertyDb.models.outlets) {
            const outlet = await req.propertyDb.models.outlets.findByPk(outletId, {
                attributes: ['country']
            });
            if (outlet && outlet.country && outlet.country.trim().length > 0) {
                return outlet.country.trim();
            }
        }
    } catch (_) {}

    return 'India';
}

async function autoSeedTaxGroupsInternal(req, outletId, country) {
    const seedDefs = getDefaultTaxGroupsForCountry(country);
    const createdGroups = [];

    for (const def of seedDefs) {
        const t = await req.propertyDb.transaction();
        try {
            let totalRate = 0;
            for (const c of def.components) {
                totalRate += Number(c.rate || 0);
            }

            const group = await req.propertyDb.models.tax_groups.create({
                outlet_id: outletId,
                group_name: def.group_name,
                group_code: def.group_code,
                total_rate: totalRate,
                is_tax_inclusive: def.is_tax_inclusive,
                is_active: true
            }, { transaction: t });

            if (Array.isArray(def.components) && def.components.length > 0) {
                const compRows = def.components.map((c, idx) => ({
                    tax_group_id: group.id,
                    component_code: c.component_code || `TAX_${idx + 1}`,
                    component_name: c.component_name || `Tax Component ${idx + 1}`,
                    rate: Number(c.rate || 0),
                    calculation_order: c.calculation_order || (idx + 1),
                    calculation_type: c.calculation_type || 'FLAT_PERCENT',
                    gl_account_code: null
                }));
                await req.propertyDb.models.tax_group_components.bulkCreate(compRows, { transaction: t });
            }

            await t.commit();

            const created = await req.propertyDb.models.tax_groups.findByPk(group.id, {
                include: [{ model: req.propertyDb.models.tax_group_components, as: 'components' }]
            });
            if (created) createdGroups.push(created);
        } catch (err) {
            await t.rollback();
            console.error(`Error auto-seeding group ${def.group_name}:`, err);
        }
    }

    return createdGroups;
}

async function getTaxGroups(req, res) {
    try {
        const outlet_id = await resolveOutletId(req, req.query.outlet_id);
        let groups = await req.propertyDb.models.tax_groups.findAll({
            where: { outlet_id, is_active: true },
            include: [
                {
                    model: req.propertyDb.models.tax_group_components,
                    as: 'components'
                }
            ],
            order: [['id', 'ASC']]
        });

        if (!groups || groups.length === 0) {
            const country = await resolveBillingCountry(req, outlet_id, req.query.country);
            console.log(`[taxGroup] Auto-seeding default tax groups for outlet ${outlet_id} (Country: ${country})...`);
            await autoSeedTaxGroupsInternal(req, outlet_id, country);

            groups = await req.propertyDb.models.tax_groups.findAll({
                where: { outlet_id, is_active: true },
                include: [
                    {
                        model: req.propertyDb.models.tax_group_components,
                        as: 'components'
                    }
                ],
                order: [['id', 'ASC']]
            });
        }

        return res.json({ success: true, data: groups });
    } catch (err) {
        console.error('Error fetching tax groups:', err);
        return res.status(500).json({ success: false, message: err.message });
    }
}

async function seedDefaultTaxGroups(req, res) {
    try {
        const outlet_id = await resolveOutletId(req, req.body.outlet_id || req.query.outlet_id);
        const country = req.body.country || req.query.country || (await resolveBillingCountry(req, outlet_id));
        const overwrite = !!req.body.overwrite;
        let preservedLinkedCount = 0;

        if (overwrite) {
            // Find all existing active tax groups for this outlet
            const existingGroups = await req.propertyDb.models.tax_groups.findAll({
                where: { outlet_id, is_active: true }
            });

            const unlinkedGroupIds = [];

            for (const grp of existingGroups) {
                let isLinked = false;
                if (req.propertyDb.models.item_master) {
                    const count = await req.propertyDb.models.item_master.count({
                        where: { tax_group_id: grp.id }
                    });
                    if (count > 0) {
                        isLinked = true;
                    }
                }
                if (isLinked) {
                    preservedLinkedCount++;
                } else {
                    unlinkedGroupIds.push(grp.id);
                }
            }

            if (unlinkedGroupIds.length > 0) {
                await req.propertyDb.models.tax_groups.update(
                    { is_active: false },
                    { where: { id: unlinkedGroupIds } }
                );
            }
        }

        const seeded = await autoSeedTaxGroupsInternal(req, outlet_id, country);
        const preservedMsg = preservedLinkedCount > 0 ? ` (Preserved ${preservedLinkedCount} tax group(s) linked to items in Item Master)` : '';
        return res.json({
            success: true,
            message: `Successfully configured standard default taxes for ${country}.${preservedMsg}`,
            data: seeded
        });
    } catch (err) {
        console.error('Error seeding default tax groups:', err);
        return res.status(500).json({ success: false, message: err.message });
    }
}

async function createTaxGroup(req, res) {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = await resolveOutletId(req, req.body.outlet_id);
        const { group_name, group_code, is_tax_inclusive, components = [] } = req.body;

        let totalRate = 0;
        for (const c of components) {
            totalRate += Number(c.rate || 0);
        }

        const group = await req.propertyDb.models.tax_groups.create({
            outlet_id,
            group_name,
            group_code,
            total_rate: totalRate,
            is_tax_inclusive: !!is_tax_inclusive,
            is_active: true
        }, { transaction: t });

        if (Array.isArray(components) && components.length > 0) {
            const compRows = components.map((c, idx) => ({
                tax_group_id: group.id,
                component_code: c.component_code || `TAX_${idx + 1}`,
                component_name: c.component_name || `Tax Component ${idx + 1}`,
                rate: Number(c.rate || 0),
                calculation_order: c.calculation_order || (idx + 1),
                calculation_type: c.calculation_type || 'FLAT_PERCENT',
                gl_account_code: c.gl_account_code || null
            }));
            await req.propertyDb.models.tax_group_components.bulkCreate(compRows, { transaction: t });
        }

        await t.commit();

        const created = await req.propertyDb.models.tax_groups.findByPk(group.id, {
            include: [{ model: req.propertyDb.models.tax_group_components, as: 'components' }]
        });

        return res.json({ success: true, data: created });
    } catch (err) {
        await t.rollback();
        console.error('Error creating tax group:', err);
        return res.status(500).json({ success: false, message: err.message });
    }
}

async function updateTaxGroup(req, res) {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const { group_name, group_code, is_tax_inclusive, components = [] } = req.body;

        const group = await req.propertyDb.models.tax_groups.findByPk(id);
        if (!group) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Tax Group not found' });
        }

        let totalRate = 0;
        for (const c of components) {
            totalRate += Number(c.rate || 0);
        }

        await group.update({
            group_name: group_name || group.group_name,
            group_code: group_code ?? group.group_code,
            total_rate: totalRate,
            is_tax_inclusive: is_tax_inclusive ?? group.is_tax_inclusive
        }, { transaction: t });

        await req.propertyDb.models.tax_group_components.destroy({
            where: { tax_group_id: id },
            transaction: t
        });

        if (Array.isArray(components) && components.length > 0) {
            const compRows = components.map((c, idx) => ({
                tax_group_id: id,
                component_code: c.component_code || `TAX_${idx + 1}`,
                component_name: c.component_name || `Tax Component ${idx + 1}`,
                rate: Number(c.rate || 0),
                calculation_order: c.calculation_order || (idx + 1),
                calculation_type: c.calculation_type || 'FLAT_PERCENT',
                gl_account_code: c.gl_account_code || null
            }));
            await req.propertyDb.models.tax_group_components.bulkCreate(compRows, { transaction: t });
        }

        await t.commit();

        const updated = await req.propertyDb.models.tax_groups.findByPk(id, {
            include: [{ model: req.propertyDb.models.tax_group_components, as: 'components' }]
        });

        return res.json({ success: true, data: updated });
    } catch (err) {
        await t.rollback();
        console.error('Error updating tax group:', err);
        return res.status(500).json({ success: false, message: err.message });
    }
}

async function deleteTaxGroup(req, res) {
    try {
        const { id } = req.params;
        const group = await req.propertyDb.models.tax_groups.findByPk(id);
        if (!group) return res.status(404).json({ success: false, message: 'Tax Group not found' });

        // Check if any items in item_master are linked to this tax_group
        if (req.propertyDb.models.item_master) {
            const linkedItemsCount = await req.propertyDb.models.item_master.count({
                where: { tax_group_id: id }
            });
            if (linkedItemsCount > 0) {
                return res.status(400).json({
                    success: false,
                    message: `Cannot delete "${group.group_name}". It is currently linked to ${linkedItemsCount} item(s) in Item Master. Please reassign those items before deleting.`
                });
            }
        }

        await group.update({ is_active: false });
        return res.json({ success: true, message: `Tax group "${group.group_name}" deleted successfully` });
    } catch (err) {
        console.error('Error deleting tax group:', err);
        return res.status(500).json({ success: false, message: err.message });
    }
}

module.exports = {
    getTaxGroups,
    seedDefaultTaxGroups,
    createTaxGroup,
    updateTaxGroup,
    deleteTaxGroup,
    resolveOutletId,
    resolveBillingCountry,
    getDefaultTaxGroupsForCountry,
    autoSeedTaxGroupsInternal
};

module.exports = (sequelize, DataTypes) => {
    const salesItem = sequelize.define('sales_items', {
        sale_id: DataTypes.INTEGER,
        item_id: DataTypes.INTEGER,
        item_code: DataTypes.STRING,
        item_name: DataTypes.STRING,
        hsn_sac_code: DataTypes.STRING,
        barcode: DataTypes.STRING,
        unit: DataTypes.STRING,
        qty: DataTypes.DECIMAL(12, 2),
        rate: DataTypes.DECIMAL(12, 2),
        tax_type: DataTypes.STRING,
        tax_percent: DataTypes.DECIMAL(7, 2),
        discount_applicable: DataTypes.BOOLEAN,
        scheme_applicable: DataTypes.BOOLEAN,
        line_discount: DataTypes.DECIMAL(12, 2),
        amount: DataTypes.DECIMAL(12, 2),
        taxable_amount: DataTypes.DECIMAL(12, 2),
        tax_amount: DataTypes.DECIMAL(12, 2),
        line_total: DataTypes.DECIMAL(12, 2),
        tax_breakup: DataTypes.JSONB,
        net_amount: DataTypes.DECIMAL(12, 2),
        is_scheme_free: DataTypes.BOOLEAN,
        applied_scheme_id: DataTypes.INTEGER,
        is_advance_free: DataTypes.BOOLEAN
    }, {
        tableName: 'sales_items',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    salesItem.associate = (models) => {
        salesItem.belongsTo(models.sales_headers, {
            foreignKey: 'sale_id',
            as: 'sale'
        });

        salesItem.belongsTo(models.item_master, {
            foreignKey: 'item_id',
            as: 'item'
        });
    };

    return salesItem;
};

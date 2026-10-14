module.exports = (sequelize, DataTypes) => {
    const goods_receipt_items = sequelize.define('goods_receipt_items', {
        grn_id: DataTypes.INTEGER,
        item_id: DataTypes.INTEGER,
        item_code: DataTypes.STRING,
        item_name: DataTypes.STRING,
        brand: DataTypes.STRING,
        unit: DataTypes.STRING,
        qty: DataTypes.DECIMAL(12, 2),
        rate: DataTypes.DECIMAL(12, 2),
        tax: DataTypes.DECIMAL(5, 2),
        amount: DataTypes.DECIMAL(12, 2),
        gst_amount: DataTypes.DECIMAL(12, 2),
        tax_amount: DataTypes.DECIMAL(12, 2),
        total_after_tax: DataTypes.DECIMAL(12, 2),
        department: DataTypes.STRING,
        sale_rate: DataTypes.DECIMAL(12, 2),
        expiry_date: DataTypes.DATEONLY,
        remarks: DataTypes.TEXT
    }, {
        tableName: 'goods_receipt_items',
        timestamps: false
    });

    if (sequelize && typeof sequelize.query === 'function') {
        sequelize.query(`
            ALTER TABLE goods_receipt_items 
            ADD COLUMN IF NOT EXISTS sale_rate DECIMAL(12, 2);
        `).catch(() => {});
    }
    goods_receipt_items.associate = (models) => {

        goods_receipt_items.belongsTo(models.goods_receipts, {
            foreignKey: 'grn_id',
            as: 'grn'
        });

    };
    return goods_receipt_items;
};

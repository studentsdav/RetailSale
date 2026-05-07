module.exports = (sequelize, DataTypes) => {

    const purchase_item = sequelize.define('purchase_order_items', {
        po_id: DataTypes.INTEGER,
        item_id: DataTypes.INTEGER,
        item_code: DataTypes.STRING,
        item_name: DataTypes.STRING,
        brand: DataTypes.STRING,
        unit: DataTypes.STRING,
        qty: DataTypes.DECIMAL(12, 2),
        rate: DataTypes.DECIMAL(12, 2),
        tax: DataTypes.DECIMAL(5, 2),
        tax_amount: DataTypes.DECIMAL(12, 2),
        total_after_tax: DataTypes.DECIMAL(12, 2),
        amount: DataTypes.DECIMAL(12, 2),
        department: DataTypes.STRING,
        line_status: {
            type: DataTypes.STRING,
            defaultValue: 'CLOSED'
        }
    }, {
        tableName: 'purchase_order_items',
        timestamps: false
    });

    purchase_item.associate = (models) => {
        purchase_item.belongsTo(models.purchase_orders, {
            foreignKey: 'po_id',
            as: 'purchase_order'
        });
    };

    return purchase_item;
};

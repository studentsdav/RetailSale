module.exports = (sequelize, DataTypes) => {
    const SupplierReturnItem = sequelize.define('supplier_return_items', {
        return_id: DataTypes.INTEGER,
        receipt_item_id: DataTypes.INTEGER,
        item_id: DataTypes.INTEGER,
        item_code: DataTypes.STRING(30),
        item_name: DataTypes.STRING(150),
        unit: DataTypes.STRING(20),
        qty: DataTypes.DECIMAL(12, 2),
        rate: DataTypes.DECIMAL(12, 2),
        amount: DataTypes.DECIMAL(12, 2)
    }, {
        tableName: 'supplier_return_items',
        timestamps: false
    });

    SupplierReturnItem.associate = (models) => {
        SupplierReturnItem.belongsTo(models.supplier_return_headers, {
            foreignKey: 'return_id',
            as: 'return_header'
        });

        SupplierReturnItem.belongsTo(models.goods_receipt_items, {
            foreignKey: 'receipt_item_id',
            as: 'receipt_item'
        });

        SupplierReturnItem.belongsTo(models.item_master, {
            foreignKey: 'item_id',
            as: 'item_master'
        });
    };

    return SupplierReturnItem;
};
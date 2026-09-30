module.exports = (sequelize, DataTypes) => {
    const purchase_order = sequelize.define('purchase_orders', {
        outlet_id: DataTypes.INTEGER,
        po_no: DataTypes.STRING,
        manual_no: DataTypes.STRING,
        supplier_id: DataTypes.INTEGER,
        po_date: DataTypes.DATEONLY,
        total_amount: DataTypes.DECIMAL(12, 2),
        status: DataTypes.STRING,
        created_by: DataTypes.INTEGER
    }, {
        tableName: 'purchase_orders',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    purchase_order.associate = (models) => {
        purchase_order.hasMany(models.purchase_order_items, {
            foreignKey: 'po_id',
            as: 'items'
        });
    };

    purchase_order.associate = (models) => {

        purchase_order.belongsTo(models.supplier_master, {
            foreignKey: 'supplier_id',
            as: 'supplier'
        });

        purchase_order.hasMany(models.purchase_order_items, {
            foreignKey: 'po_id',
            as: 'items'
        });
    };

    return purchase_order;
};

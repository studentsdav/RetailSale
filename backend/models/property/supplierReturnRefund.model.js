module.exports = (sequelize, DataTypes) => {
    const SupplierReturnRefund = sequelize.define('supplier_return_refunds', {
        return_id: DataTypes.INTEGER,
        outlet_id: DataTypes.INTEGER,
        supplier_id: DataTypes.INTEGER,
        refund_date: DataTypes.DATEONLY,
        amount: DataTypes.DECIMAL(12, 2),
        payment_mode: DataTypes.STRING(20),
        reference_no: DataTypes.STRING(50),
        notes: DataTypes.TEXT,
        created_by: DataTypes.INTEGER
    }, {
        tableName: 'supplier_return_refunds',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    SupplierReturnRefund.associate = (models) => {
        SupplierReturnRefund.belongsTo(models.supplier_return_headers, {
            foreignKey: 'return_id',
            as: 'return_header'
        });

        SupplierReturnRefund.belongsTo(models.supplier_master, {
            foreignKey: 'supplier_id',
            as: 'supplier'
        });
    };

    return SupplierReturnRefund;
};
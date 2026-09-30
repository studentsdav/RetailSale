module.exports = (sequelize, DataTypes) => {

    const SupplierPayments = sequelize.define('supplier_payments', {
        outlet_id: { type: DataTypes.INTEGER, allowNull: false },
        supplier_id: { type: DataTypes.INTEGER, allowNull: false },
        bill_id: { type: DataTypes.INTEGER, allowNull: false },

        payment_date: { type: DataTypes.DATEONLY, allowNull: false },
        amount: { type: DataTypes.DECIMAL(12, 2), allowNull: false },
        credit_adjusted: { type: DataTypes.DECIMAL(12, 2), allowNull: false, defaultValue: 0.00 },

        payment_mode: DataTypes.STRING(20),
        reference_no: DataTypes.STRING(50),
        created_by: DataTypes.INTEGER
    }, {
        tableName: 'supplier_payments',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    SupplierPayments.associate = (models) => {

        SupplierPayments.belongsTo(models.supplier_master, {
            foreignKey: 'supplier_id',
            as: 'supplier'
        });

        SupplierPayments.belongsTo(models.supplier_bills, {
            foreignKey: 'bill_id',
            as: 'bill'
        });
    };

    return SupplierPayments;
};

module.exports = (sequelize, DataTypes) => {
    const SupplierBills = sequelize.define('supplier_bills', {
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },

        supplier_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },

        bill_no: DataTypes.STRING(50),
        bill_date: DataTypes.DATEONLY,
        bill_amount: DataTypes.DECIMAL(12, 2),
        paid_amount: DataTypes.DECIMAL(12, 2),
        status: DataTypes.STRING(20)

    }, {
        tableName: 'supplier_bills',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    SupplierBills.associate = (models) => {

        SupplierBills.belongsTo(models.supplier_master, {
            foreignKey: 'supplier_id',
            as: 'supplier'
        });

        SupplierBills.hasMany(models.supplier_payments, {
            foreignKey: 'bill_id',
            as: 'payments'
        });
    };

    return SupplierBills;
};

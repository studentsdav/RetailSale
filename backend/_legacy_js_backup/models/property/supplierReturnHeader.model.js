module.exports = (sequelize, DataTypes) => {
    const SupplierReturnHeader = sequelize.define('supplier_return_headers', {
        return_no: DataTypes.STRING(30),
        outlet_id: DataTypes.INTEGER,
        supplier_id: DataTypes.INTEGER,
        grn_id: DataTypes.INTEGER,
        return_date: DataTypes.DATEONLY,
        total_amount: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0
        },
        refunded_amount: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0
        },
        status: {
            type: DataTypes.STRING(20),
            defaultValue: 'PENDING'
        },
        notes: DataTypes.TEXT,
        created_by: DataTypes.INTEGER
    }, {
        tableName: 'supplier_return_headers',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    SupplierReturnHeader.associate = (models) => {
        SupplierReturnHeader.belongsTo(models.supplier_master, {
            foreignKey: 'supplier_id',
            as: 'supplier'
        });

        SupplierReturnHeader.belongsTo(models.goods_receipts, {
            foreignKey: 'grn_id',
            as: 'grn'
        });

        SupplierReturnHeader.hasMany(models.supplier_return_items, {
            foreignKey: 'return_id',
            as: 'items'
        });

        SupplierReturnHeader.hasMany(models.supplier_return_refunds, {
            foreignKey: 'return_id',
            as: 'refunds'
        });
    };

    return SupplierReturnHeader;
};
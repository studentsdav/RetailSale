module.exports = (sequelize, DataTypes) => {
    const SupplierMaster = sequelize.define('supplier_master', {
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        supplier_code: {
            type: DataTypes.STRING(30),
            allowNull: false
        },
        supplier_name: {
            type: DataTypes.STRING(150),
            allowNull: false
        },
        address: {
            type: DataTypes.TEXT,
            allowNull: false,
            defaultValue: ''
        },
        phone: DataTypes.STRING(20),
        state: DataTypes.STRING(100),
        gstin: DataTypes.STRING(20),
        tax_id_number: DataTypes.STRING(100),
        tax_id_type: DataTypes.STRING(50),
        tax_country_code: DataTypes.STRING(10),
        tax_id_type: DataTypes.STRING(50),
        tax_country_code: DataTypes.STRING(10),
        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        }
    }, {
        tableName: 'supplier_master',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
        indexes: [
            {
                unique: true,
                fields: ['outlet_id', 'supplier_code']
            },
            {
                unique: true,
                fields: ['outlet_id', 'supplier_name']
            }
        ]
    });

    SupplierMaster.associate = (models) => {

        SupplierMaster.hasMany(models.supplier_bills, {
            foreignKey: 'supplier_id',
            as: 'bills'
        });

        SupplierMaster.hasMany(models.supplier_payments, {
            foreignKey: 'supplier_id',
            as: 'payments'
        });
    };


    SupplierMaster.associate = (models) => {

        SupplierMaster.hasMany(models.purchase_orders, {
            foreignKey: 'supplier_id',
            as: 'purchaseOrders'
        });

        SupplierMaster.hasMany(models.supplier_bills, {
            foreignKey: 'supplier_id',
            as: 'bills'
        });

        SupplierMaster.hasMany(models.supplier_payments, {
            foreignKey: 'supplier_id',
            as: 'payments'
        });
    };

    return SupplierMaster;
};

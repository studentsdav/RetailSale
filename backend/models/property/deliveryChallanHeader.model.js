module.exports = (sequelize, DataTypes) => {
    const DeliveryChallanHeader = sequelize.define('delivery_challan_headers', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        challan_no: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        challan_date: {
            type: DataTypes.DATE,
            defaultValue: DataTypes.NOW
        },
        customer_name: {
            type: DataTypes.STRING(150),
            allowNull: true
        },
        customer_phone: {
            type: DataTypes.STRING(20),
            allowNull: true
        },
        total_qty: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        status: {
            type: DataTypes.STRING(30),
            defaultValue: 'Issued'
        },
        created_by: {
            type: DataTypes.INTEGER,
            allowNull: true
        }
    }, {
        tableName: 'delivery_challan_headers',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    DeliveryChallanHeader.associate = (models) => {
        DeliveryChallanHeader.belongsTo(models.users, {
            foreignKey: 'created_by',
            as: 'creator'
        });
        DeliveryChallanHeader.hasMany(models.delivery_challan_items, {
            foreignKey: 'challan_id',
            as: 'items'
        });
    };

    return DeliveryChallanHeader;
};

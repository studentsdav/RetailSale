module.exports = (sequelize, DataTypes) => {
    const model = sequelize.define('milk_subscription_consumptions', {
        outlet_id: DataTypes.INTEGER,
        subscription_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        sale_id: DataTypes.INTEGER,
        sale_no: DataTypes.STRING(50),
        txn_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        item_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        item_name: DataTypes.STRING(150),
        cart_qty: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        covered_qty: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        excess_qty: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        daily_allowed_qty: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        rate: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        covered_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        excess_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        settlement_id: DataTypes.INTEGER,
        status: {
            type: DataTypes.STRING(20),
            allowNull: false,
            defaultValue: 'PENDING'
        },
        created_by: DataTypes.INTEGER
    }, {
        tableName: 'milk_subscription_consumptions',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    model.associate = (models) => {
        model.belongsTo(models.milk_subscriptions, {
            foreignKey: 'subscription_id',
            as: 'subscription'
        });
        model.belongsTo(models.sales_headers, {
            foreignKey: 'sale_id',
            as: 'sale'
        });
        model.belongsTo(models.milk_subscription_settlements, {
            foreignKey: 'settlement_id',
            as: 'settlement'
        });
    };

    return model;
};

module.exports = (sequelize, DataTypes) => {
    const MilkSubscription = sequelize.define('milk_subscriptions', {
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        customer_name: DataTypes.STRING(150),
        customer_phone: DataTypes.STRING(20),
        customer_gstin: DataTypes.STRING(20),
        customer_address: DataTypes.TEXT,
        item_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        item_name: DataTypes.STRING(150),
        start_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        end_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        daily_allowed_qty: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        total_payment_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        scheme_discount_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        bonus_qty: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        selected_schemes: {
            type: DataTypes.JSONB,
            allowNull: false,
            defaultValue: []
        },
        status: {
            type: DataTypes.STRING(20),
            allowNull: false,
            defaultValue: 'ACTIVE'
        },
        active_subscription: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: true
        },
        settled_at: DataTypes.DATE,
        created_by: DataTypes.INTEGER,
        updated_by: DataTypes.INTEGER
    }, {
        tableName: 'milk_subscriptions',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    MilkSubscription.associate = (models) => {
        MilkSubscription.belongsTo(models.item_master, {
            foreignKey: 'item_id',
            as: 'item'
        });

        MilkSubscription.hasMany(models.milk_subscription_schemes, {
            foreignKey: 'subscription_id',
            as: 'schemes'
        });

        MilkSubscription.hasMany(models.milk_subscription_consumptions, {
            foreignKey: 'subscription_id',
            as: 'consumptions'
        });

        MilkSubscription.hasMany(models.milk_subscription_settlements, {
            foreignKey: 'subscription_id',
            as: 'settlements'
        });
    };

    return MilkSubscription;
};

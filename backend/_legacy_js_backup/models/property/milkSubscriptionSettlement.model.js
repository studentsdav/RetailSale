module.exports = (sequelize, DataTypes) => {
    const model = sequelize.define('milk_subscription_settlements', {
        outlet_id: DataTypes.INTEGER,
        subscription_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        settlement_no: DataTypes.STRING(50),
        settlement_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        period_start: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        period_end: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        gross_excess_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        scheme_discount_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        bonus_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        total_due: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        payment_mode: {
            type: DataTypes.STRING(20),
            allowNull: false,
            defaultValue: 'CASH'
        },
        amount_paid: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        balance_due: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        advance_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        notes: DataTypes.TEXT,
        created_by: DataTypes.INTEGER
    }, {
        tableName: 'milk_subscription_settlements',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    model.associate = (models) => {
        model.belongsTo(models.milk_subscriptions, {
            foreignKey: 'subscription_id',
            as: 'subscription'
        });
        model.hasMany(models.milk_subscription_consumptions, {
            foreignKey: 'settlement_id',
            as: 'consumptions'
        });
    };

    return model;
};

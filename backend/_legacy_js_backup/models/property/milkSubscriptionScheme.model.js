module.exports = (sequelize, DataTypes) => {
    const model = sequelize.define('milk_subscription_schemes', {
        outlet_id: DataTypes.INTEGER,
        subscription_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        scheme_type: {
            type: DataTypes.STRING(40),
            allowNull: false
        },
        scheme_name: DataTypes.STRING(150),
        scheme_value: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        bonus_qty: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        discount_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        notes: DataTypes.TEXT,
        created_by: DataTypes.INTEGER
    }, {
        tableName: 'milk_subscription_schemes',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    model.associate = (models) => {
        model.belongsTo(models.milk_subscriptions, {
            foreignKey: 'subscription_id',
            as: 'subscription'
        });
    };

    return model;
};

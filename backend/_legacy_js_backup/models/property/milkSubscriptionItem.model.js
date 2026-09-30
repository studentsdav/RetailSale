module.exports = (sequelize, DataTypes) => {
    const MilkSubscriptionItem = sequelize.define('milk_subscription_items', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        subscription_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        item_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        daily_qty: {
            type: DataTypes.DECIMAL(12, 4),
            defaultValue: 1.0000
        },
        rate_override: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: true
        }
    }, {
        tableName: 'milk_subscription_items',
        timestamps: false
    });

    MilkSubscriptionItem.associate = (models) => {
        MilkSubscriptionItem.belongsTo(models.milk_subscriptions, {
            foreignKey: 'subscription_id',
            as: 'subscription'
        });
        MilkSubscriptionItem.belongsTo(models.item_master, {
            foreignKey: 'item_id',
            as: 'item'
        });
    };

    return MilkSubscriptionItem;
};

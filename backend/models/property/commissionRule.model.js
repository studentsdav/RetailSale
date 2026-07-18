module.exports = (sequelize, DataTypes) => {
    const CommissionRule = sequelize.define('commission_rules', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        platform_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        category_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        product_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        min_price: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        max_price: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 9999999.99
        },
        percentage_fee: {
            type: DataTypes.DECIMAL(5, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        fixed_fee: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        priority: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 0
        },
        is_active: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: true
        }
    }, {
        timestamps: true,
        underscored: true,
        tableName: 'commission_rules'
    });

    CommissionRule.associate = (models) => {
        CommissionRule.belongsTo(models.sale_sources, {
            foreignKey: 'platform_id',
            as: 'platform'
        });
        CommissionRule.belongsTo(models.item_groups, {
            foreignKey: 'category_id',
            as: 'category'
        });
        CommissionRule.belongsTo(models.item_master, {
            foreignKey: 'product_id',
            as: 'product'
        });
    };

    return CommissionRule;
};

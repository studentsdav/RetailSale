module.exports = (sequelize, DataTypes) => {
    const CustomerDrawProgress = sequelize.define('customer_draw_progress', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        campaign_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        customer_phone: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        customer_name: {
            type: DataTypes.STRING(150),
            allowNull: true
        },
        accumulated_spend: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        }
    }, {
        tableName: 'customer_draw_progress',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
        indexes: [
            {
                unique: true,
                fields: ['outlet_id', 'campaign_id', 'customer_phone']
            }
        ]
    });

    CustomerDrawProgress.associate = (models) => {
        CustomerDrawProgress.belongsTo(models.lucky_draw_campaigns, {
            foreignKey: 'campaign_id',
            as: 'campaign'
        });
    };

    return CustomerDrawProgress;
};

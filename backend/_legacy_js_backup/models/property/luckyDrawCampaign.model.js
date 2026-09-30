module.exports = (sequelize, DataTypes) => {
    const LuckyDrawCampaign = sequelize.define('lucky_draw_campaigns', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        name: {
            type: DataTypes.STRING,
            allowNull: false
        },
        status: {
            type: DataTypes.STRING(50),
            allowNull: false,
            defaultValue: 'ACTIVE' // ACTIVE, PENDING_RESULT, COMPLETED
        },
        threshold_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 2000.00
        },
        start_date: {
            type: DataTypes.DATE,
            allowNull: false,
            defaultValue: DataTypes.NOW
        },
        draw_date: {
            type: DataTypes.DATE,
            allowNull: false
        },
        winner_voucher_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        description: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        allow_creditors: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: true
        }
    }, {
        tableName: 'lucky_draw_campaigns',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    LuckyDrawCampaign.associate = (models) => {
        LuckyDrawCampaign.hasMany(models.draw_vouchers, {
            foreignKey: 'campaign_id',
            as: 'vouchers'
        });
        LuckyDrawCampaign.hasMany(models.customer_draw_progress, {
            foreignKey: 'campaign_id',
            as: 'progress'
        });
        LuckyDrawCampaign.belongsTo(models.draw_vouchers, {
            foreignKey: 'winner_voucher_id',
            as: 'winner'
        });
    };

    return LuckyDrawCampaign;
};

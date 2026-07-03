module.exports = (sequelize, DataTypes) => {
    const WhatsappCampaign = sequelize.define('whatsapp_campaigns', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        template_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        campaign_name: {
            type: DataTypes.STRING,
            allowNull: false
        },
        total_recipients: {
            type: DataTypes.INTEGER,
            defaultValue: 0
        },
        scheduled_at: {
            type: DataTypes.DATE,
            allowNull: true
        }
    }, {
        tableName: 'whatsapp_campaigns',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    WhatsappCampaign.associate = (models) => {
        WhatsappCampaign.belongsTo(models.whatsapp_templates, {
            foreignKey: 'template_id',
            as: 'template'
        });
        WhatsappCampaign.hasMany(models.whatsapp_logs, {
            foreignKey: 'campaign_id',
            as: 'logs'
        });
    };

    return WhatsappCampaign;
};

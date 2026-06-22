module.exports = (sequelize, DataTypes) => {
    const WhatsappLog = sequelize.define('whatsapp_logs', {
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
            allowNull: true
        },
        recipient_phone: {
            type: DataTypes.STRING,
            allowNull: false
        },
        message_type: {
            type: DataTypes.STRING,
            allowNull: false // UTILITY or MARKETING
        },
        delivery_status: {
            type: DataTypes.STRING,
            defaultValue: 'queued' // queued, sent, delivered, read, failed
        },
        meta_message_id: {
            type: DataTypes.STRING,
            allowNull: true
        },
        error_message: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        retry_count: {
            type: DataTypes.INTEGER,
            defaultValue: 0
        },
        next_retry_time: {
            type: DataTypes.DATE,
            defaultValue: DataTypes.NOW
        },
        variables_mapped: {
            type: DataTypes.JSONB,
            allowNull: true
        },
        cost: {
            type: DataTypes.DECIMAL(6, 2),
            defaultValue: 0.00
        }
    }, {
        tableName: 'whatsapp_logs',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
        indexes: [
            { fields: ['delivery_status'] },
            { fields: ['meta_message_id'] }
        ]
    });

    WhatsappLog.associate = (models) => {
        WhatsappLog.belongsTo(models.whatsapp_campaigns, {
            foreignKey: 'campaign_id',
            as: 'campaign'
        });
    };

    return WhatsappLog;
};

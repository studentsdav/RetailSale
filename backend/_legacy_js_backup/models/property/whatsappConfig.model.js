module.exports = (sequelize, DataTypes) => {
    return sequelize.define('whatsapp_configurations', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        waba_id: {
            type: DataTypes.STRING,
            allowNull: false
        },
        phone_number_id: {
            type: DataTypes.STRING,
            allowNull: false
        },
        encrypted_access_token: {
            type: DataTypes.TEXT,
            allowNull: false
        },
        webhook_verify_token: {
            type: DataTypes.STRING,
            allowNull: false
        },
        app_secret: {
            type: DataTypes.STRING,
            allowNull: true
        },
        allow_automatic_messages: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        }
    }, {
        tableName: 'whatsapp_configurations',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
        indexes: [
            { unique: true, fields: ['outlet_id'] }
        ]
    });
};

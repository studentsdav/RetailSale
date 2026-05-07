module.exports = (sequelize, DataTypes) => {

    const SystemNotification = sequelize.define(
        'system_notifications',
        {
            id: {
                type: DataTypes.INTEGER,
                primaryKey: true,
                autoIncrement: true,
            },

            outlet_id: {
                type: DataTypes.INTEGER,
                allowNull: false,
            },

            module: {
                type: DataTypes.STRING(50),
                allowNull: false,
            },

            title: {
                type: DataTypes.STRING(150),
                allowNull: false,
            },

            message: {
                type: DataTypes.TEXT,
                allowNull: false,
            },

            type: {
                type: DataTypes.STRING(30),
                allowNull: false,
                defaultValue: 'INFO',
            },

            entity_id: {
                type: DataTypes.INTEGER,
                allowNull: true,
            },

            is_read: {
                type: DataTypes.BOOLEAN,
                defaultValue: false,
            },

            created_at: {
                type: DataTypes.DATE,
                defaultValue: DataTypes.NOW,
            }
        },
        {
            tableName: 'system_notifications',
            timestamps: false,
        }
    );

    return SystemNotification;
};
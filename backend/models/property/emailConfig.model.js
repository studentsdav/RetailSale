module.exports = (sequelize, DataTypes) => {
    const EmailConfig = sequelize.define('email_configurations', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        smtp_host: {
            type: DataTypes.STRING(255),
            allowNull: false
        },
        smtp_port: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        smtp_user: {
            type: DataTypes.STRING(255),
            allowNull: false
        },
        smtp_pass: {
            type: DataTypes.STRING(255),
            allowNull: false
        },
        encryption_type: {
            type: DataTypes.STRING(20),
            defaultValue: 'TLS'
        },
        from_name: {
            type: DataTypes.STRING(255),
            allowNull: true
        },
        from_email: {
            type: DataTypes.STRING(255),
            allowNull: false
        },
        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        }
    }, {
        tableName: 'email_configurations',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    return EmailConfig;
};

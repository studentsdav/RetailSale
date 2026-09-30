module.exports = (sequelize, DataTypes) => {
    const EmailTemplate = sequelize.define('email_templates', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        template_type: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        subject: {
            type: DataTypes.STRING(255),
            allowNull: false
        },
        body_html: {
            type: DataTypes.TEXT,
            allowNull: false
        },
        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        }
    }, {
        tableName: 'email_templates',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    return EmailTemplate;
};

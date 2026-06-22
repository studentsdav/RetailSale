module.exports = (sequelize, DataTypes) => {
    const WhatsappTemplate = sequelize.define('whatsapp_templates', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        template_name: {
            type: DataTypes.STRING,
            allowNull: false
        },
        category: {
            type: DataTypes.STRING,
            allowNull: false // UTILITY or MARKETING
        },
        language: {
            type: DataTypes.STRING,
            allowNull: false
        },
        body_text: {
            type: DataTypes.TEXT,
            allowNull: false
        },
        status: {
            type: DataTypes.STRING,
            defaultValue: 'DRAFT' // DRAFT, PENDING, APPROVED, REJECTED
        },
        meta_template_id: {
            type: DataTypes.STRING,
            allowNull: true
        },
        header_type: {
            type: DataTypes.STRING,
            defaultValue: 'NONE' // NONE, TEXT, IMAGE, DOCUMENT
        },
        header_text: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        footer_text: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        buttons: {
            type: DataTypes.JSONB,
            allowNull: true
        },
        variables: {
            type: DataTypes.JSONB,
            allowNull: true
        },
        is_default_invoice_template: {
            type: DataTypes.BOOLEAN,
            defaultValue: false
        }
    }, {
        tableName: 'whatsapp_templates',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
        indexes: [
            { unique: true, fields: ['outlet_id', 'template_name', 'language'] }
        ]
    });

    WhatsappTemplate.associate = (models) => {
        WhatsappTemplate.hasMany(models.whatsapp_campaigns, {
            foreignKey: 'template_id',
            as: 'campaigns'
        });
    };

    return WhatsappTemplate;
};

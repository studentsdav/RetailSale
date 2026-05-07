module.exports = (sequelize, DataTypes) => {
    return sequelize.define('app_branding', {
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        company_name: {
            type: DataTypes.STRING(255),
            allowNull: false,
            defaultValue: 'Famalth Technologies'
        },
        product_name: {
            type: DataTypes.STRING(255),
            allowNull: false,
            defaultValue: 'Famalth Inventory'
        },
        support_email: {
            type: DataTypes.STRING(255),
            allowNull: false,
            defaultValue: 'support@famalth.com'
        },
        support_website: {
            type: DataTypes.STRING(255),
            allowNull: false,
            defaultValue: 'www.famalth.com'
        },
        support_phone: {
            type: DataTypes.STRING(80),
            allowNull: false,
            defaultValue: '+91-00000-00000'
        },
        open_source_notice: {
            type: DataTypes.TEXT,
            allowNull: false,
            defaultValue: 'Famalth Technologies branding is applied across the product. Third-party packages remain available under their respective open-source licenses.'
        },
        powered_by_label: {
            type: DataTypes.STRING(255),
            allowNull: false,
            defaultValue: 'Powered by Famalth Technologies'
        },
        theme_key: {
            type: DataTypes.STRING(80),
            allowNull: false,
            defaultValue: 'famalth_classic'
        }
    }, {
        tableName: 'app_branding',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
        indexes: [{ unique: true, fields: ['outlet_id'] }]
    });
};

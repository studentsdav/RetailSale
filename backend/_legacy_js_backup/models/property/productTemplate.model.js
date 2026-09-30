module.exports = (sequelize, DataTypes) => {
    const ProductTemplate = sequelize.define(
        'product_templates',
        {
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
                type: DataTypes.STRING(150),
                allowNull: false
            },
            item_group: {
                type: DataTypes.STRING(100),
                allowNull: false
            },
            sub_category: {
                type: DataTypes.STRING(100),
                allowNull: false
            },
            brand: {
                type: DataTypes.STRING(100),
                allowNull: true
            },
            hsn_sac_code: {
                type: DataTypes.STRING(30),
                allowNull: true
            },
            tax_type: {
                type: DataTypes.STRING(20),
                defaultValue: 'GST'
            },
            tax_percent: {
                type: DataTypes.DECIMAL(7, 2),
                defaultValue: 0
            },
            discount_applicable: {
                type: DataTypes.BOOLEAN,
                defaultValue: true
            },
            scheme_applicable: {
                type: DataTypes.BOOLEAN,
                defaultValue: true
            },
            is_active: {
                type: DataTypes.BOOLEAN,
                defaultValue: true
            }
        },
        {
            tableName: 'product_templates',
            timestamps: true,
            createdAt: 'created_at',
            updatedAt: 'updated_at'
        }
    );

    ProductTemplate.associate = (models) => {
        ProductTemplate.hasMany(models.item_master, {
            foreignKey: 'product_template_id',
            as: 'variants'
        });
    };

    return ProductTemplate;
};

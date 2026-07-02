module.exports = (sequelize, DataTypes) => {

    console.log({
        response: "itemamster___"
    })

    const ItemMaster = sequelize.define(
        'item_master',
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

            item_code: {
                type: DataTypes.STRING(30),
                allowNull: false
            },

            item_name: {
                type: DataTypes.STRING(150),
                allowNull: false
            },

            hsn_sac_code: {
                type: DataTypes.STRING(30),
                allowNull: true
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
                type: DataTypes.STRING(100)
            },

            unit: {
                type: DataTypes.STRING(20),
                allowNull: false
            },

            barcode: {
                type: DataTypes.STRING(64),
                allowNull: true
            },

            image_path: {
                type: DataTypes.TEXT,
                allowNull: true
            },

            rate: {
                type: DataTypes.DECIMAL(12, 2),
                defaultValue: 0
            },

            retail_sale_price: {
                type: DataTypes.DECIMAL(12, 2),
                defaultValue: 0
            },

            b2b_rate: {
                type: DataTypes.DECIMAL(12, 2),
                defaultValue: 0
            },

            return_window_days: {
                type: DataTypes.INTEGER,
                defaultValue: 7
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

            opening_balance: {
                type: DataTypes.DECIMAL(12, 2),
                defaultValue: 0
            },

            pack_qty: {
                type: DataTypes.DECIMAL(12, 2),
                defaultValue: 0
            },

            loose_item_code: {
                type: DataTypes.STRING(30),
                allowNull: true
            },

            min_level: {
                type: DataTypes.INTEGER,
                defaultValue: 0
            },

            max_level: {
                type: DataTypes.INTEGER,
                defaultValue: 0
            },

            stockable: {
                type: DataTypes.BOOLEAN,
                defaultValue: true
            },

            is_saleable: {
                type: DataTypes.BOOLEAN,
                defaultValue: true
            },

            is_active: {
                type: DataTypes.BOOLEAN,
                defaultValue: true
            },

            product_template_id: {
                type: DataTypes.INTEGER,
                allowNull: true
            },

            created_at: {
                type: DataTypes.DATE,
                defaultValue: DataTypes.NOW
            },

            updated_at: {
                type: DataTypes.DATE,
                defaultValue: DataTypes.NOW
            }
        },
        {
            tableName: 'item_master',
            timestamps: true,
            createdAt: 'created_at',
            updatedAt: 'updated_at',

            indexes: [
                {
                    unique: true,
                    fields: ['outlet_id', 'item_code']
                },
                {
                    fields: ['item_name']
                },
                {
                    fields: ['barcode']
                },
                {
                    fields: ['item_group']
                },
                {
                    fields: ['sub_category']
                },
                {
                    fields: ['loose_item_code']
                },
                {
                    fields: ['is_active']
                }
            ]
        }
    );
    ItemMaster.associate = (models) => {
        ItemMaster.hasMany(models.issue_items, {
            foreignKey: 'item_id',
            as: 'issue_items'
        });

        ItemMaster.hasMany(models.damage_items, {
            foreignKey: 'item_id',
            as: 'damage_items'
        });

        ItemMaster.belongsTo(models.product_templates, {
            foreignKey: 'product_template_id',
            as: 'product_template'
        });

        ItemMaster.belongsToMany(models.attribute_values, {
            through: models.variant_attribute_values,
            foreignKey: 'item_id',
            otherKey: 'attribute_value_id',
            as: 'attribute_values'
        });
    };





    return ItemMaster;
};

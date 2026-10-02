module.exports = (sequelize, DataTypes) => {
    const ItemModifier = sequelize.define('item_modifiers', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        item_master_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        modifier_name: {
            type: DataTypes.STRING(150),
            allowNull: false
        },
        price: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        tax_percent: {
            type: DataTypes.DECIMAL(5, 2),
            allowNull: true,
            defaultValue: null
        },
        inventory_item_id: {
            type: DataTypes.INTEGER,
            allowNull: true,
            defaultValue: 0
        },
        deduct_qty: {
            type: DataTypes.DECIMAL(12, 4),
            defaultValue: 0.0000
        },
        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        }
    }, {
        tableName: 'item_modifiers',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    ItemModifier.associate = (models: any) => {
        ItemModifier.belongsTo(models.item_master, {
            foreignKey: 'item_master_id',
            as: 'item'
        });
        ItemModifier.belongsTo(models.item_master, {
            foreignKey: 'inventory_item_id',
            as: 'inventory_item'
        });
    };

    return ItemModifier;
};


export default module.exports;

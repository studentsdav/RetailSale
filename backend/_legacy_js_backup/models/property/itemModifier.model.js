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

    ItemModifier.associate = (models) => {
        ItemModifier.belongsTo(models.item_master, {
            foreignKey: 'item_master_id',
            as: 'item'
        });
    };

    return ItemModifier;
};

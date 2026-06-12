module.exports = (sequelize, DataTypes) => {
    const ItemBom = sequelize.define('item_boms', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        parent_item_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        component_item_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        quantity: {
            type: DataTypes.DECIMAL(12, 4),
            allowNull: false,
            defaultValue: 1.0000
        }
    }, {
        timestamps: true,
        underscored: true,
        tableName: 'item_boms'
    });

    ItemBom.associate = (models) => {
        ItemBom.belongsTo(models.item_master, {
            foreignKey: 'parent_item_id',
            as: 'parent_item'
        });
        ItemBom.belongsTo(models.item_master, {
            foreignKey: 'component_item_id',
            as: 'component_item'
        });
    };

    return ItemBom;
};

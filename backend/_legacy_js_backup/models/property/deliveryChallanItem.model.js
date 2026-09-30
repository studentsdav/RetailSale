module.exports = (sequelize, DataTypes) => {
    const DeliveryChallanItem = sequelize.define('delivery_challan_items', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        challan_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        item_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        item_code: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        item_name: {
            type: DataTypes.STRING(150),
            allowNull: false
        },
        qty: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 1.00
        },
        unit: {
            type: DataTypes.STRING(30),
            allowNull: true
        }
    }, {
        tableName: 'delivery_challan_items',
        timestamps: false
    });

    DeliveryChallanItem.associate = (models) => {
        DeliveryChallanItem.belongsTo(models.delivery_challan_headers, {
            foreignKey: 'challan_id',
            as: 'challan'
        });
        DeliveryChallanItem.belongsTo(models.item_master, {
            foreignKey: 'item_id',
            as: 'item'
        });
    };

    return DeliveryChallanItem;
};

module.exports = (sequelize, DataTypes) => {
    const DamageItem = sequelize.define('damage_items', {
        damage_id: DataTypes.INTEGER,
        item_id: DataTypes.INTEGER,
        qty: DataTypes.DECIMAL(12, 2),
        rate: DataTypes.DECIMAL(12, 2),
        remarks: DataTypes.TEXT,
        amount: DataTypes.DECIMAL(12, 2)
    }, {
        tableName: 'damage_items',
        timestamps: false
    });

    DamageItem.associate = (models) => {
        DamageItem.belongsTo(models.damage_headers, {
            foreignKey: 'damage_id',
            as: 'header'
        });
        DamageItem.belongsTo(models.item_master, {
            foreignKey: 'item_id',
            as: 'item'
        });
    };

    return DamageItem;
};

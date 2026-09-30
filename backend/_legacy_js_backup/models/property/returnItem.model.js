module.exports = (sequelize, DataTypes) => {
    const return_items = sequelize.define('return_items', {
        return_id: DataTypes.INTEGER,
        issue_item_id: DataTypes.INTEGER,
        item_id: DataTypes.INTEGER,
        qty: DataTypes.DECIMAL(12, 2),
        rate: DataTypes.DECIMAL(12, 2)
    }, {
        tableName: 'return_items',
        timestamps: false
    });

    return_items.associate = (models) => {


        return_items.belongsTo(models.return_headers, {
            foreignKey: 'return_id',
            as: 'return_header'
        });

        return_items.belongsTo(models.item_master, {
            foreignKey: 'item_id',
            as: 'item_master'
        });
    };
    return return_items;
};

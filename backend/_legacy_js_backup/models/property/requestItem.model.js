module.exports = (sequelize, DataTypes) => {

    const RequestItem = sequelize.define('request_items', {
        request_id: DataTypes.INTEGER,
        item_id: DataTypes.INTEGER,
        item_code: DataTypes.STRING,
        qty: DataTypes.DECIMAL(12, 2),
        rate: DataTypes.DECIMAL(12, 2),
        line_status: {
            type: DataTypes.STRING,
            defaultValue: 'CLOSED'
        }
    }, {
        tableName: 'request_items',
        timestamps: false
    });

    RequestItem.associate = (models) => {

        RequestItem.belongsTo(models.request_headers, {
            foreignKey: 'request_id',
            as: 'header'
        });

        RequestItem.belongsTo(models.item_master, {
            foreignKey: 'item_id',
            as: 'item_master'
        });
    };

    return RequestItem;
};

module.exports = (sequelize, DataTypes) => {
    const StockTransferItem = sequelize.define('stock_transfer_items', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        transfer_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        item_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        item_code: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        item_name: {
            type: DataTypes.STRING(200),
            allowNull: true
        },
        transfer_qty: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        unit_cost: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        total_cost: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        }
    }, {
        tableName: 'stock_transfer_items',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    return StockTransferItem;
};

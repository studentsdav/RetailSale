module.exports = (sequelize, DataTypes) => {
    const StockTransferHeader = sequelize.define('stock_transfer_headers', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        transfer_no: {
            type: DataTypes.STRING(50),
            unique: true,
            allowNull: false
        },
        source_outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        destination_outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        status: {
            type: DataTypes.STRING(30),
            allowNull: false,
            defaultValue: 'DISPATCHED'
        },
        dispatch_date: {
            type: DataTypes.DATE,
            allowNull: false,
            defaultValue: DataTypes.NOW
        },
        received_date: {
            type: DataTypes.DATE,
            allowNull: true
        },
        total_qty: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        total_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        dispatched_by_user_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        received_by_user_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        notes: {
            type: DataTypes.TEXT,
            allowNull: true
        }
    }, {
        tableName: 'stock_transfer_headers',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    return StockTransferHeader;
};

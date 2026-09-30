module.exports = (sequelize, DataTypes) => {
    return sequelize.define('stock_ledger', {
        outlet_id: DataTypes.INTEGER,
        item_code: DataTypes.STRING,
        txn_date: DataTypes.DATEONLY,
        txn_type: DataTypes.STRING,
        ref_no: DataTypes.STRING,
        qty_in: DataTypes.DECIMAL(12, 2),
        qty_out: DataTypes.DECIMAL(12, 2),
        balance: DataTypes.DECIMAL(12, 2),
    }, {
        tableName: 'stock_ledger',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });
};

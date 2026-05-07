module.exports = (sequelize, DataTypes) => {
    const CashLedger = sequelize.define('cash_ledger', {
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        txn_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        transaction_type: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        reference_type: DataTypes.STRING(50),
        reference_id: DataTypes.INTEGER,
        reference_no: DataTypes.STRING(50),
        party_name: DataTypes.STRING(150),
        payment_method: DataTypes.STRING(20),
        amount_in: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0
        },
        amount_out: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0
        },
        adjustment_amount: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0
        },
        balance: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0
        },
        notes: DataTypes.TEXT,
        created_by: DataTypes.INTEGER
    }, {
        tableName: 'cash_ledger',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    return CashLedger;
};

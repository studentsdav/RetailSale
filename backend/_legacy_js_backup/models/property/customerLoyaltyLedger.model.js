module.exports = (sequelize, DataTypes) => {
    return sequelize.define('customer_loyalty_ledger', {
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        customer_name: DataTypes.STRING,
        customer_phone: DataTypes.STRING,
        customer_gstin: DataTypes.STRING,
        customer_key: {
            type: DataTypes.STRING,
            allowNull: false
        },
        transaction_date: {
            type: DataTypes.DATE,
            allowNull: false,
            defaultValue: DataTypes.NOW
        },
        transaction_type: {
            type: DataTypes.STRING,
            allowNull: false
        },
        points_delta: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        points_balance_after: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 0
        },
        bill_number: DataTypes.STRING,
        sale_id: DataTypes.INTEGER,
        expiry_date: DataTypes.DATEONLY,
        available_points: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 0
        },
        source_ledger_id: DataTypes.INTEGER,
        meta: {
            type: DataTypes.JSONB,
            allowNull: false,
            defaultValue: {}
        },
        created_by: DataTypes.INTEGER
    }, {
        tableName: 'customer_loyalty_ledger',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });
};

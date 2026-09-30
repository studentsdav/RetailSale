module.exports = (sequelize, DataTypes) => {
    const DailyOpeningBalance = sequelize.define('daily_opening_balances', {
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        balance_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        opening_balance: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        note: DataTypes.TEXT,
        created_by: DataTypes.INTEGER,
        updated_by: DataTypes.INTEGER
    }, {
        tableName: 'daily_opening_balances',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    return DailyOpeningBalance;
};
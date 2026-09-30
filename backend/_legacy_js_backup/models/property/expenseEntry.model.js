module.exports = (sequelize, DataTypes) => {
    const ExpenseEntry = sequelize.define('expense_entries', {
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        expense_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        category: {
            type: DataTypes.STRING(100),
            allowNull: false
        },
        amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false
        },
        note: DataTypes.TEXT,
        created_by: DataTypes.INTEGER
    }, {
        tableName: 'expense_entries',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    return ExpenseEntry;
};
module.exports = (sequelize, DataTypes) => {
    const ExpenseDeduction = sequelize.define('expense_deductions', {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true
        },
        expense_id: {
            type: DataTypes.UUID,
            allowNull: false
        },
        deduction_type: {
            type: DataTypes.STRING(255),
            allowNull: false
        },
        deduction_percentage: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        deduction_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        }
    }, {
        tableName: 'expense_deductions',
        timestamps: false
    });

    ExpenseDeduction.associate = (models) => {
        ExpenseDeduction.belongsTo(models.expenses, {
            foreignKey: 'expense_id'
        });
    };

    return ExpenseDeduction;
};

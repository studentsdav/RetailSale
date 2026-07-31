module.exports = (sequelize, DataTypes) => {
    const HrLoanTransaction = sequelize.define('hr_loan_transactions', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        loan_id: { type: DataTypes.INTEGER, allowNull: false },
        transaction_type: { type: DataTypes.STRING(50), allowNull: false },
        amount: { type: DataTypes.DECIMAL(12, 2), allowNull: false },
        transaction_date: { type: DataTypes.DATEONLY, allowNull: false },
        payroll_run_id: { type: DataTypes.INTEGER, allowNull: true },
        notes: { type: DataTypes.TEXT, allowNull: true },
        created_by: { type: DataTypes.INTEGER, allowNull: false }
    }, {
        tableName: 'hr_loan_transactions',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    HrLoanTransaction.associate = (models) => {
        HrLoanTransaction.belongsTo(models.hr_loans, { foreignKey: 'loan_id', as: 'loan' });
    };

    return HrLoanTransaction;
};

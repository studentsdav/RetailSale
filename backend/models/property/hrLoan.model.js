module.exports = (sequelize, DataTypes) => {
    const HrLoan = sequelize.define('hr_loans', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        outlet_id: { type: DataTypes.INTEGER, allowNull: false },
        employee_id: { type: DataTypes.INTEGER, allowNull: false },
        loan_amount: { type: DataTypes.DECIMAL(12, 2), allowNull: false },
        monthly_emi: { type: DataTypes.DECIMAL(12, 2), allowNull: false },
        remaining_balance: { type: DataTypes.DECIMAL(12, 2), allowNull: false },
        status: { type: DataTypes.STRING(50), allowNull: false, defaultValue: 'Active' },
        notes: { type: DataTypes.TEXT, allowNull: true },
        created_by: { type: DataTypes.INTEGER, allowNull: false }
    }, {
        tableName: 'hr_loans',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    HrLoan.associate = (models) => {
        HrLoan.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
        HrLoan.belongsTo(models.hr_employees, { foreignKey: 'employee_id', as: 'employee' });
        HrLoan.hasMany(models.hr_loan_transactions, { foreignKey: 'loan_id', as: 'transactions' });
    };

    return HrLoan;
};

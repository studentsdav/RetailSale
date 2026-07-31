module.exports = (sequelize, DataTypes) => {
    const HrPayrollRun = sequelize.define('hr_payroll_runs', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        outlet_id: { type: DataTypes.INTEGER, allowNull: false },
        pay_period: { type: DataTypes.STRING(7), allowNull: false },
        run_date: { type: DataTypes.DATEONLY, allowNull: false },
        status: { type: DataTypes.STRING(50), allowNull: false, defaultValue: 'Draft' },
        approved_by: { type: DataTypes.INTEGER, allowNull: true },
        expense_id: { type: DataTypes.UUID, allowNull: true },
        total_gross: { type: DataTypes.DECIMAL(12, 2), allowNull: false, defaultValue: 0.00 },
        total_deductions: { type: DataTypes.DECIMAL(12, 2), allowNull: false, defaultValue: 0.00 },
        total_net: { type: DataTypes.DECIMAL(12, 2), allowNull: false, defaultValue: 0.00 }
    }, {
        tableName: 'hr_payroll_runs',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    HrPayrollRun.associate = (models) => {
        HrPayrollRun.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
        HrPayrollRun.hasMany(models.hr_payroll_details, { foreignKey: 'payroll_run_id', as: 'details' });
    };

    return HrPayrollRun;
};

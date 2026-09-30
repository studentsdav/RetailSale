module.exports = (sequelize, DataTypes) => {
    const HrPayrollDetail = sequelize.define('hr_payroll_details', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        payroll_run_id: { type: DataTypes.INTEGER, allowNull: false },
        employee_id: { type: DataTypes.INTEGER, allowNull: false },
        base_salary: { type: DataTypes.DECIMAL(12, 2), allowNull: false },
        prorated_salary: { type: DataTypes.DECIMAL(12, 2), allowNull: false },
        overtime_pay: { type: DataTypes.DECIMAL(12, 2), allowNull: false, defaultValue: 0.00 },
        sales_commission: { type: DataTypes.DECIMAL(12, 2), allowNull: false, defaultValue: 0.00 },
        arrears: { type: DataTypes.DECIMAL(12, 2), allowNull: false, defaultValue: 0.00 },
        bonuses: { type: DataTypes.DECIMAL(12, 2), allowNull: false, defaultValue: 0.00 },
        total_additions: { type: DataTypes.DECIMAL(12, 2), allowNull: false, defaultValue: 0.00 },
        shortage_penalties: { type: DataTypes.DECIMAL(12, 2), allowNull: false, defaultValue: 0.00 },
        loan_emi: { type: DataTypes.DECIMAL(12, 2), allowNull: false, defaultValue: 0.00 },
        statutory_deductions: { type: DataTypes.DECIMAL(12, 2), allowNull: false, defaultValue: 0.00 },
        total_deductions: { type: DataTypes.DECIMAL(12, 2), allowNull: false, defaultValue: 0.00 },
        gross_pay: { type: DataTypes.DECIMAL(12, 2), allowNull: false, defaultValue: 0.00 },
        net_pay: { type: DataTypes.DECIMAL(12, 2), allowNull: false, defaultValue: 0.00 },
        components_breakdown: { type: DataTypes.JSONB, allowNull: false, defaultValue: {} },
        days_present: { type: DataTypes.DECIMAL(4, 1), allowNull: false, defaultValue: 0.0 },
        days_absent: { type: DataTypes.DECIMAL(4, 1), allowNull: false, defaultValue: 0.0 },
        days_on_leave: { type: DataTypes.DECIMAL(4, 1), allowNull: false, defaultValue: 0.0 }
    }, {
        tableName: 'hr_payroll_details',
        timestamps: false
    });

    HrPayrollDetail.associate = (models) => {
        HrPayrollDetail.belongsTo(models.hr_payroll_runs, { foreignKey: 'payroll_run_id', as: 'payrollRun' });
        HrPayrollDetail.belongsTo(models.hr_employees, { foreignKey: 'employee_id', as: 'employee' });
    };

    return HrPayrollDetail;
};

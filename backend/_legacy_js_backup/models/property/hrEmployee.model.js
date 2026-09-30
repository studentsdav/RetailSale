module.exports = (sequelize, DataTypes) => {
    const HrEmployee = sequelize.define('hr_employees', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        user_id: { type: DataTypes.INTEGER, allowNull: true },
        outlet_id: { type: DataTypes.INTEGER, allowNull: false },
        employee_code: { type: DataTypes.STRING(50), allowNull: false },
        full_name: { type: DataTypes.STRING(255), allowNull: false },
        father_name: { type: DataTypes.STRING(255), allowNull: true },
        contact_email: { type: DataTypes.STRING(150), allowNull: true },
        mobile: { type: DataTypes.STRING(30), allowNull: true },
        gender: { type: DataTypes.STRING(20), allowNull: true },
        date_of_birth: { type: DataTypes.DATEONLY, allowNull: true },
        blood_group: { type: DataTypes.STRING(10), allowNull: true },
        bank_name: { type: DataTypes.STRING(150), allowNull: true },
        bank_account_no: { type: DataTypes.STRING(100), allowNull: true },
        bank_ifsc: { type: DataTypes.STRING(30), allowNull: true },
        hire_date: { type: DataTypes.DATEONLY, allowNull: false },
        base_salary: { type: DataTypes.DECIMAL(12, 2), allowNull: false, defaultValue: 0.00 },
        requires_attendance: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
        pay_if_unmarked: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
        status: { type: DataTypes.STRING(50), allowNull: false, defaultValue: 'Active' },
        kyc_documents: { type: DataTypes.JSONB, allowNull: true },
        pay_structure_id: { type: DataTypes.INTEGER, allowNull: true },
        designation_id: { type: DataTypes.INTEGER, allowNull: true },
        shift_id: { type: DataTypes.INTEGER, allowNull: true },
        commission_percent: { type: DataTypes.DECIMAL(5, 2), allowNull: false, defaultValue: 0.00 },
        commission_target_type: { type: DataTypes.STRING(50), allowNull: true },
        commission_target_amount: { type: DataTypes.DECIMAL(12, 2), allowNull: false, defaultValue: 0.00 },
        level1_approver_id: { type: DataTypes.INTEGER, allowNull: true },
        level2_approver_id: { type: DataTypes.INTEGER, allowNull: true },
        terminated_date: { type: DataTypes.DATEONLY, allowNull: true },
        termination_reason: { type: DataTypes.TEXT, allowNull: true },
        payroll_start_date: { type: DataTypes.DATEONLY, allowNull: true },
        created_by: { type: DataTypes.INTEGER, allowNull: true }
    }, {
        tableName: 'hr_employees',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    HrEmployee.associate = (models) => {
        HrEmployee.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
        HrEmployee.belongsTo(models.hr_pay_structures, { foreignKey: 'pay_structure_id', as: 'payStructure' });
        HrEmployee.belongsTo(models.hr_designations, { foreignKey: 'designation_id', as: 'designation' });
        HrEmployee.belongsTo(models.hr_shifts, { foreignKey: 'shift_id', as: 'shift' });
        HrEmployee.hasMany(models.hr_attendance_punches, { foreignKey: 'employee_id', as: 'punches' });
        HrEmployee.hasMany(models.hr_leave_applications, { foreignKey: 'employee_id', as: 'leaveApplications' });
        HrEmployee.hasMany(models.hr_loans, { foreignKey: 'employee_id', as: 'loans' });
        HrEmployee.hasMany(models.hr_sales_commissions, { foreignKey: 'employee_id', as: 'commissions' });
        HrEmployee.hasMany(models.hr_leave_balances, { foreignKey: 'employee_id', as: 'leaveBalances' });
    };

    return HrEmployee;
};

module.exports = (sequelize, DataTypes) => {
    const HrLeaveBalance = sequelize.define('hr_leave_balances', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        outlet_id: { type: DataTypes.INTEGER, allowNull: false },
        employee_id: { type: DataTypes.INTEGER, allowNull: false },
        leave_type_id: { type: DataTypes.INTEGER, allowNull: false },
        year: { type: DataTypes.INTEGER, allowNull: false },
        allocated_quota: { type: DataTypes.INTEGER, allowNull: false },
        used_quota: { type: DataTypes.DECIMAL(4, 1), allowNull: false, defaultValue: 0.0 }
    }, {
        tableName: 'hr_leave_balances',
        timestamps: false
    });

    HrLeaveBalance.associate = (models) => {
        HrLeaveBalance.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
        HrLeaveBalance.belongsTo(models.hr_employees, { foreignKey: 'employee_id', as: 'employee' });
        HrLeaveBalance.belongsTo(models.hr_leave_types, { foreignKey: 'leave_type_id', as: 'leaveType' });
    };

    return HrLeaveBalance;
};

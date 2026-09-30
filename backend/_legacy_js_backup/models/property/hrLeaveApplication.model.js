module.exports = (sequelize, DataTypes) => {
    const HrLeaveApplication = sequelize.define('hr_leave_applications', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        outlet_id: { type: DataTypes.INTEGER, allowNull: false },
        employee_id: { type: DataTypes.INTEGER, allowNull: false },
        leave_type_id: { type: DataTypes.INTEGER, allowNull: false },
        start_date: { type: DataTypes.DATEONLY, allowNull: false },
        end_date: { type: DataTypes.DATEONLY, allowNull: false },
        total_days: { type: DataTypes.DECIMAL(4, 1), allowNull: false },
        reason: { type: DataTypes.TEXT, allowNull: true },
        status: { type: DataTypes.STRING(50), allowNull: false, defaultValue: 'Pending' },
        approved_by: { type: DataTypes.INTEGER, allowNull: true }
    }, {
        tableName: 'hr_leave_applications',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    HrLeaveApplication.associate = (models) => {
        HrLeaveApplication.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
        HrLeaveApplication.belongsTo(models.hr_employees, { foreignKey: 'employee_id', as: 'employee' });
        HrLeaveApplication.belongsTo(models.hr_leave_types, { foreignKey: 'leave_type_id', as: 'leaveType' });
    };

    return HrLeaveApplication;
};

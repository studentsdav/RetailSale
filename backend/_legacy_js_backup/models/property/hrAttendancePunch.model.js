module.exports = (sequelize, DataTypes) => {
    const HrAttendancePunch = sequelize.define('hr_attendance_punches', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        outlet_id: { type: DataTypes.INTEGER, allowNull: false },
        employee_id: { type: DataTypes.INTEGER, allowNull: false },
        punch_date: { type: DataTypes.DATEONLY, allowNull: false },
        punch_in: { type: DataTypes.DATE, allowNull: true },
        punch_out: { type: DataTypes.DATE, allowNull: true },
        hours_worked: { type: DataTypes.DECIMAL(5, 2), allowNull: false, defaultValue: 0.00 },
        overtime_hours: { type: DataTypes.DECIMAL(5, 2), allowNull: false, defaultValue: 0.00 },
        lateness_mins: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 0 },
        status: { type: DataTypes.STRING(50), allowNull: false, defaultValue: 'Absent' },
        punch_source: { type: DataTypes.STRING(50), allowNull: false, defaultValue: 'Manual' },
        updated_by: { type: DataTypes.INTEGER, allowNull: true },
        leave_type_id: { type: DataTypes.INTEGER, allowNull: true }
    }, {
        tableName: 'hr_attendance_punches',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    HrAttendancePunch.associate = (models) => {
        HrAttendancePunch.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
        HrAttendancePunch.belongsTo(models.hr_employees, { foreignKey: 'employee_id', as: 'employee' });
        HrAttendancePunch.belongsTo(models.hr_leave_types, { foreignKey: 'leave_type_id', as: 'leaveType' });
    };

    return HrAttendancePunch;
};

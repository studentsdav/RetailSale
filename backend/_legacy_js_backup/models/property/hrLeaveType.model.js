module.exports = (sequelize, DataTypes) => {
    const HrLeaveType = sequelize.define('hr_leave_types', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        outlet_id: { type: DataTypes.INTEGER, allowNull: false },
        name: { type: DataTypes.STRING(100), allowNull: false },
        is_paid: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
        annual_quota: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 14 },
        is_active: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true }
    }, {
        tableName: 'hr_leave_types',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    HrLeaveType.associate = (models) => {
        HrLeaveType.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
    };

    return HrLeaveType;
};

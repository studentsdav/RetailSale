module.exports = (sequelize, DataTypes) => {
    const HrSalaryRevision = sequelize.define('hr_salary_revisions', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        outlet_id: { type: DataTypes.INTEGER, allowNull: false },
        employee_id: { type: DataTypes.INTEGER, allowNull: false },
        previous_salary: { type: DataTypes.DECIMAL(12, 2), allowNull: false },
        new_salary: { type: DataTypes.DECIMAL(12, 2), allowNull: false },
        effective_date: { type: DataTypes.DATEONLY, allowNull: false },
        status: { type: DataTypes.STRING(50), allowNull: false, defaultValue: 'Pending' },
        approved_by: { type: DataTypes.INTEGER, allowNull: true },
        created_by: { type: DataTypes.INTEGER, allowNull: false }
    }, {
        tableName: 'hr_salary_revisions',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    HrSalaryRevision.associate = (models) => {
        HrSalaryRevision.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
        HrSalaryRevision.belongsTo(models.hr_employees, { foreignKey: 'employee_id', as: 'employee' });
    };

    return HrSalaryRevision;
};

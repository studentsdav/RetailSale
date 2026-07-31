module.exports = (sequelize, DataTypes) => {
    const HrSalaryComponent = sequelize.define('hr_salary_components', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        outlet_id: { type: DataTypes.INTEGER, allowNull: false },
        name: { type: DataTypes.STRING(150), allowNull: false },
        nature: { type: DataTypes.STRING(50), allowNull: false, defaultValue: 'Earning' },
        type: { type: DataTypes.STRING(50), allowNull: false, defaultValue: 'Fixed' },
        formula: { type: DataTypes.STRING(255), allowNull: true },
        is_taxable: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
        frequency: { type: DataTypes.STRING(50), allowNull: false, defaultValue: 'Monthly' },
        is_active: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true }
    }, {
        tableName: 'hr_salary_components',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    HrSalaryComponent.associate = (models) => {
        HrSalaryComponent.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
        HrSalaryComponent.belongsToMany(models.hr_pay_structures, {
            through: models.hr_pay_structure_components,
            foreignKey: 'salary_component_id',
            otherKey: 'pay_structure_id',
            as: 'payStructures'
        });
    };

    return HrSalaryComponent;
};

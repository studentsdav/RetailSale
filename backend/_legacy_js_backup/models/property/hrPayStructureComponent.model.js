module.exports = (sequelize, DataTypes) => {
    const HrPayStructureComponent = sequelize.define('hr_pay_structure_components', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        pay_structure_id: { type: DataTypes.INTEGER, allowNull: false },
        salary_component_id: { type: DataTypes.INTEGER, allowNull: false }
    }, {
        tableName: 'hr_pay_structure_components',
        timestamps: false
    });

    HrPayStructureComponent.associate = (models) => {
        HrPayStructureComponent.belongsTo(models.hr_pay_structures, { foreignKey: 'pay_structure_id', as: 'payStructure' });
        HrPayStructureComponent.belongsTo(models.hr_salary_components, { foreignKey: 'salary_component_id', as: 'component' });
    };

    return HrPayStructureComponent;
};

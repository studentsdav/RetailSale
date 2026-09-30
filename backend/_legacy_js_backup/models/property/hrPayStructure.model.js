module.exports = (sequelize, DataTypes) => {
    const HrPayStructure = sequelize.define('hr_pay_structures', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        outlet_id: { type: DataTypes.INTEGER, allowNull: false },
        name: { type: DataTypes.STRING(150), allowNull: false },
        description: { type: DataTypes.TEXT, allowNull: true },
        is_active: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true }
    }, {
        tableName: 'hr_pay_structures',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    HrPayStructure.associate = (models) => {
        HrPayStructure.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
        HrPayStructure.hasMany(models.hr_pay_structure_components, { foreignKey: 'pay_structure_id', as: 'structureComponents' });
        HrPayStructure.belongsToMany(models.hr_salary_components, {
            through: models.hr_pay_structure_components,
            foreignKey: 'pay_structure_id',
            otherKey: 'salary_component_id',
            as: 'components'
        });
    };

    return HrPayStructure;
};

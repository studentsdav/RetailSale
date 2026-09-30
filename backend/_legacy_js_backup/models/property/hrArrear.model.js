module.exports = (sequelize, DataTypes) => {
    const HrArrear = sequelize.define('hr_arrears', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        outlet_id: { type: DataTypes.INTEGER, allowNull: false },
        employee_id: { type: DataTypes.INTEGER, allowNull: false },
        amount: { type: DataTypes.DECIMAL(12, 2), allowNull: false },
        reason: { type: DataTypes.TEXT, allowNull: false },
        payment_month: { type: DataTypes.STRING(7), allowNull: false },
        status: { type: DataTypes.STRING(50), allowNull: false, defaultValue: 'Pending' }
    }, {
        tableName: 'hr_arrears',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    HrArrear.associate = (models) => {
        HrArrear.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
        HrArrear.belongsTo(models.hr_employees, { foreignKey: 'employee_id', as: 'employee' });
    };

    return HrArrear;
};

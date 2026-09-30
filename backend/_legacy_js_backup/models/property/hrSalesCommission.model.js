module.exports = (sequelize, DataTypes) => {
    const HrSalesCommission = sequelize.define('hr_sales_commissions', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        outlet_id: { type: DataTypes.INTEGER, allowNull: false },
        employee_id: { type: DataTypes.INTEGER, allowNull: false },
        sale_id: { type: DataTypes.INTEGER, allowNull: false },
        sale_amount: { type: DataTypes.DECIMAL(12, 2), allowNull: false },
        commission_percent: { type: DataTypes.DECIMAL(5, 2), allowNull: false },
        commission_amount: { type: DataTypes.DECIMAL(12, 2), allowNull: false },
        status: { type: DataTypes.STRING(50), allowNull: false, defaultValue: 'Queued' },
        payroll_run_id: { type: DataTypes.INTEGER, allowNull: true }
    }, {
        tableName: 'hr_sales_commissions',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    HrSalesCommission.associate = (models) => {
        HrSalesCommission.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
        HrSalesCommission.belongsTo(models.hr_employees, { foreignKey: 'employee_id', as: 'employee' });
        HrSalesCommission.belongsTo(models.sales_headers, { foreignKey: 'sale_id', as: 'sale' });
    };

    return HrSalesCommission;
};

module.exports = (sequelize, DataTypes) => {
    const HrCashierHandover = sequelize.define('hr_cashier_handovers', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        outlet_id: { type: DataTypes.INTEGER, allowNull: false },
        cashier_id: { type: DataTypes.INTEGER, allowNull: false },
        handover_date: { type: DataTypes.DATEONLY, allowNull: false },
        expected_cash: { type: DataTypes.DECIMAL(12, 2), allowNull: false },
        physical_cash: { type: DataTypes.DECIMAL(12, 2), allowNull: false },
        denominations: { type: DataTypes.JSONB, allowNull: false, defaultValue: {} },
        variance: { type: DataTypes.DECIMAL(12, 2), allowNull: false },
        shortage_status: { type: DataTypes.STRING(50), allowNull: false, defaultValue: 'Logged' },
        penalty_amount: { type: DataTypes.DECIMAL(12, 2), allowNull: false, defaultValue: 0.00 },
        payroll_run_id: { type: DataTypes.INTEGER, allowNull: true }
    }, {
        tableName: 'hr_cashier_handovers',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    HrCashierHandover.associate = (models) => {
        HrCashierHandover.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
        HrCashierHandover.belongsTo(models.users, { foreignKey: 'cashier_id', as: 'cashier' });
    };

    return HrCashierHandover;
};

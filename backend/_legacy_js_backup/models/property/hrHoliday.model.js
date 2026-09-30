module.exports = (sequelize, DataTypes) => {
    const HrHoliday = sequelize.define('hr_holidays', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        outlet_id: { type: DataTypes.INTEGER, allowNull: false },
        name: { type: DataTypes.STRING(150), allowNull: false },
        holiday_date: { type: DataTypes.DATEONLY, allowNull: false },
        is_recurring: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false }
    }, {
        tableName: 'hr_holidays',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    HrHoliday.associate = (models) => {
        HrHoliday.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
    };

    return HrHoliday;
};

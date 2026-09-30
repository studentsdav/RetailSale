module.exports = (sequelize, DataTypes) => {
    const HrShift = sequelize.define('hr_shifts', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        outlet_id: { type: DataTypes.INTEGER, allowNull: false },
        name: { type: DataTypes.STRING(100), allowNull: false },
        start_time: { type: DataTypes.STRING, allowNull: false },
        end_time: { type: DataTypes.STRING, allowNull: false },
        grace_period_mins: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 15 },
        is_active: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
        weekly_offs: { type: DataTypes.JSONB, allowNull: false, defaultValue: ["Sunday"] }
    }, {
        tableName: 'hr_shifts',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    HrShift.associate = (models) => {
        HrShift.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
    };

    return HrShift;
};

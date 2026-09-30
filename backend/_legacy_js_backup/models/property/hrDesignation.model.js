module.exports = (sequelize, DataTypes) => {
    const HrDesignation = sequelize.define('hr_designations', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        outlet_id: { type: DataTypes.INTEGER, allowNull: false },
        name: { type: DataTypes.STRING(150), allowNull: false },
        is_active: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true }
    }, {
        tableName: 'hr_designations',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    HrDesignation.associate = (models) => {
        HrDesignation.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
    };

    return HrDesignation;
};

module.exports = (sequelize, DataTypes) => {
    const CustomState = sequelize.define('custom_states', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        country_code: {
            type: DataTypes.STRING(10),
            allowNull: false,
            defaultValue: 'IN'
        },
        state_name: {
            type: DataTypes.STRING(150),
            allowNull: false
        },
        state_code: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        is_custom: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        },
        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        }
    }, {
        tableName: 'custom_states',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    return CustomState;
};

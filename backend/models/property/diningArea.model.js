module.exports = (sequelize, DataTypes) => {
    const DiningArea = sequelize.define('dining_areas', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        name: {
            type: DataTypes.STRING(100),
            allowNull: false
        },
        description: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        status: {
            type: DataTypes.STRING(20),
            defaultValue: 'ACTIVE'
        }
    }, {
        tableName: 'dining_areas',
        timestamps: false
    });

    return DiningArea;
};

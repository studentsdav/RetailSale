module.exports = (sequelize, DataTypes) => {
    const Floor = sequelize.define('floors', {
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
        status: {
            type: DataTypes.STRING(20),
            defaultValue: 'ACTIVE'
        }
    }, {
        tableName: 'floors',
        timestamps: false
    });

    return Floor;
};

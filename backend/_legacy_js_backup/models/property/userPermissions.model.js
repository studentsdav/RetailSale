module.exports = (sequelize, DataTypes) => {
    return sequelize.define('user_permissions', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        user_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },


        perm_key: DataTypes.STRING
    }, {
        tableName: 'user_permissions',
        timestamps: false
    });
};

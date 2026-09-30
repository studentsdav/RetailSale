module.exports = (sequelize, DataTypes) => {
    const return_headers = sequelize.define('return_headers', {
        return_no: DataTypes.STRING,
        issue_id: DataTypes.INTEGER,
        return_date: DataTypes.DATEONLY,
        outlet_id: DataTypes.INTEGER,
        created_by: DataTypes.INTEGER
    }, {
        tableName: 'return_headers',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    return_headers.associate = (models) => {
        return_headers.hasMany(models.return_items, {
            foreignKey: 'return_id',
            as: 'return_items'
        });

        return_headers.belongsTo(models.issue_headers, {
            foreignKey: 'issue_id',
            as: 'issue'
        });
    };


    return return_headers;

};

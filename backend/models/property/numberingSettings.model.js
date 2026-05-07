module.exports = (sequelize, DataTypes) => {
    return sequelize.define('numbering_settings', {
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },

        module: {
            type: DataTypes.STRING(50),
            allowNull: false
        },

        start_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },

        start_no: {
            type: DataTypes.INTEGER,
            allowNull: false
        },

        prefix: {
            type: DataTypes.STRING(20)
        },

        postfix: {
            type: DataTypes.STRING(20)
        },

        last_used_no: {
            type: DataTypes.INTEGER,
            defaultValue: 0
        }
    }, {
        tableName: 'numbering_settings',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });
};

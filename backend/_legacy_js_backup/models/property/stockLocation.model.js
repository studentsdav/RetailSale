module.exports = (sequelize, DataTypes) => {
    return sequelize.define('stock_locations', {
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },

        location_code: {
            type: DataTypes.STRING(30),
            allowNull: false
        },

        location_name: {
            type: DataTypes.STRING(150),
            allowNull: false
        },

        description: {
            type: DataTypes.TEXT
        },

        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        }
    }, {
        tableName: 'stock_locations',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });
};

module.exports = (sequelize, DataTypes) => {
    return sequelize.define('outlet_settings', {
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        meta_data: {
            type: DataTypes.JSONB,
            defaultValue: {}
        }
    }, {
        tableName: 'outlet_settings',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
        indexes: [{ unique: true, fields: ['outlet_id'] }]
    });
};

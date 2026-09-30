module.exports = (sequelize, DataTypes) => {
    const Attribute = sequelize.define(
        'attributes',
        {
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
                type: DataTypes.STRING(50),
                allowNull: false
            },
            is_active: {
                type: DataTypes.BOOLEAN,
                defaultValue: true
            }
        },
        {
            tableName: 'attributes',
            timestamps: true,
            createdAt: 'created_at',
            updatedAt: 'updated_at'
        }
    );

    Attribute.associate = (models) => {
        Attribute.hasMany(models.attribute_values, {
            foreignKey: 'attribute_id',
            as: 'values'
        });
    };

    return Attribute;
};

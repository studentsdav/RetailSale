module.exports = (sequelize, DataTypes) => {
    const AttributeValue = sequelize.define(
        'attribute_values',
        {
            id: {
                type: DataTypes.INTEGER,
                primaryKey: true,
                autoIncrement: true
            },
            attribute_id: {
                type: DataTypes.INTEGER,
                allowNull: false
            },
            value: {
                type: DataTypes.STRING(100),
                allowNull: false
            },
            is_active: {
                type: DataTypes.BOOLEAN,
                defaultValue: true
            }
        },
        {
            tableName: 'attribute_values',
            timestamps: true,
            createdAt: 'created_at',
            updatedAt: 'updated_at'
        }
    );

    AttributeValue.associate = (models) => {
        AttributeValue.belongsTo(models.attributes, {
            foreignKey: 'attribute_id',
            as: 'attribute'
        });
        AttributeValue.belongsToMany(models.item_master, {
            through: models.variant_attribute_values,
            foreignKey: 'attribute_value_id',
            as: 'variants'
        });
    };

    return AttributeValue;
};

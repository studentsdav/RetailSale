module.exports = (sequelize, DataTypes) => {
    const VariantAttributeValue = sequelize.define(
        'variant_attribute_values',
        {
            id: {
                type: DataTypes.INTEGER,
                primaryKey: true,
                autoIncrement: true
            },
            item_id: {
                type: DataTypes.INTEGER,
                allowNull: false
            },
            attribute_value_id: {
                type: DataTypes.INTEGER,
                allowNull: false
            }
        },
        {
            tableName: 'variant_attribute_values',
            timestamps: false
        }
    );

    return VariantAttributeValue;
};

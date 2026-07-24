module.exports = (sequelize, DataTypes) => {
    const TaxesMaster = sequelize.define('taxes_master', {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        tax_name: {
            type: DataTypes.STRING(255),
            allowNull: false
        },
        default_rate: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        is_editable: {
            type: DataTypes.BOOLEAN,
            defaultValue: true,
            allowNull: false
        }
    }, {
        tableName: 'taxes_master',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    TaxesMaster.associate = (models) => {
        TaxesMaster.belongsTo(models.outlets, {
            foreignKey: 'outlet_id',
            as: 'outlet'
        });
    };

    return TaxesMaster;
};

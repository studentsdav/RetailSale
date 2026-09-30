module.exports = (sequelize, DataTypes) => {
    const TaxGroupComponent = sequelize.define('tax_group_components', {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true
        },
        tax_group_id: {
            type: DataTypes.UUID,
            allowNull: false
        },
        component_code: {
            type: DataTypes.STRING(50),
            allowNull: false // e.g. "STATE_TAX", "CITY_TAX", "TRANSIT_TAX", "CGST", "SGST", "PST", "CTL"
        },
        component_name: {
            type: DataTypes.STRING(100),
            allowNull: false // e.g. "State Sales Tax", "City Tax", "MTA Transit Tax"
        },
        rate: {
            type: DataTypes.DECIMAL(7, 4),
            allowNull: false,
            defaultValue: 0.0000
        },
        calculation_order: {
            type: DataTypes.INTEGER,
            defaultValue: 1
        },
        calculation_type: {
            type: DataTypes.STRING(30),
            defaultValue: 'FLAT_PERCENT' // 'FLAT_PERCENT', 'COMPOUND_ON_SUBTOTAL', 'PERCENT_OF_TAX'
        },
        gl_account_code: {
            type: DataTypes.STRING(50),
            allowNull: true
        }
    }, {
        tableName: 'tax_group_components',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    TaxGroupComponent.associate = (models) => {
        TaxGroupComponent.belongsTo(models.tax_groups, {
            foreignKey: 'tax_group_id',
            as: 'tax_group'
        });
    };

    return TaxGroupComponent;
};

export {};

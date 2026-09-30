module.exports = (sequelize, DataTypes) => {
    const TaxGroup = sequelize.define('tax_groups', {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        tax_profile_id: {
            type: DataTypes.UUID,
            allowNull: true
        },
        group_name: {
            type: DataTypes.STRING(150),
            allowNull: false // e.g. "Sweet Scoops TX (8.25%)", "Kenya Rest. (18%)", "ON HST (13%)"
        },
        group_code: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        total_rate: {
            type: DataTypes.DECIMAL(7, 4),
            allowNull: false,
            defaultValue: 0.0000
        },
        is_tax_inclusive: {
            type: DataTypes.BOOLEAN,
            defaultValue: false
        },
        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        }
    }, {
        tableName: 'tax_groups',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    TaxGroup.associate = (models) => {
        TaxGroup.belongsTo(models.outlets, {
            foreignKey: 'outlet_id',
            as: 'outlet'
        });
        TaxGroup.belongsTo(models.tax_profiles, {
            foreignKey: 'tax_profile_id',
            as: 'tax_profile'
        });
        TaxGroup.hasMany(models.tax_group_components, {
            foreignKey: 'tax_group_id',
            as: 'components'
        });
        TaxGroup.hasMany(models.item_master, {
            foreignKey: 'tax_group_id',
            as: 'items'
        });
    };

    return TaxGroup;
};

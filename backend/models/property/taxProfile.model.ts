module.exports = (sequelize, DataTypes) => {
    const TaxProfile = sequelize.define('tax_profiles', {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        country_code: {
            type: DataTypes.STRING(10),
            allowNull: false,
            defaultValue: 'US' // 'US', 'KE', 'IN', 'CA', 'EU', 'CN', 'JP', 'AU'
        },
        tax_regime: {
            type: DataTypes.STRING(50),
            allowNull: false,
            defaultValue: 'SALES_TAX' // 'SALES_TAX', 'VAT', 'GST', 'DUAL_GST_PST'
        },
        default_is_inclusive: {
            type: DataTypes.BOOLEAN,
            defaultValue: false
        },
        tax_id_label: {
            type: DataTypes.STRING(50),
            defaultValue: 'Tax ID'
        },
        tax_registration_no: {
            type: DataTypes.STRING(100),
            allowNull: true
        },
        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        }
    }, {
        tableName: 'tax_profiles',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    TaxProfile.associate = (models) => {
        TaxProfile.belongsTo(models.outlets, {
            foreignKey: 'outlet_id',
            as: 'outlet'
        });
        TaxProfile.hasMany(models.tax_groups, {
            foreignKey: 'tax_profile_id',
            as: 'tax_groups'
        });
    };

    return TaxProfile;
};


export default module.exports;

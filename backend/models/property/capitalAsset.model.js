module.exports = (sequelize, DataTypes) => {
    const CapitalAsset = sequelize.define('capital_assets', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        asset_name: {
            type: DataTypes.STRING(150),
            allowNull: false
        },
        asset_category: {
            type: DataTypes.STRING(50),
            defaultValue: 'FIXED_ASSET'
        },
        purchase_date: {
            type: DataTypes.DATEONLY,
            defaultValue: DataTypes.NOW
        },
        purchase_cost: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        current_value: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        notes: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        created_by: {
            type: DataTypes.INTEGER,
            allowNull: true
        }
    }, {
        tableName: 'capital_assets',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    return CapitalAsset;
};

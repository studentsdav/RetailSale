module.exports = (sequelize, DataTypes) => {
    const SaleSource = sequelize.define('sale_sources', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        name: {
            type: DataTypes.STRING,
            allowNull: false,
            unique: true
        },
        is_system: {
            type: DataTypes.BOOLEAN,
            defaultValue: false
        },
        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        },
        commission_rate: {
            type: DataTypes.DECIMAL(5, 2),
            defaultValue: 0.00
        },
        gst_rate_on_commission: {
            type: DataTypes.DECIMAL(5, 2),
            defaultValue: 0.00
        },
        tds_rate: {
            type: DataTypes.DECIMAL(5, 2),
            defaultValue: 0.00
        },
        tcs_rate: {
            type: DataTypes.DECIMAL(5, 2),
            defaultValue: 0.00
        }
    }, {
        timestamps: true,
        underscored: true,
        tableName: 'sale_sources'
    });

    return SaleSource;
};

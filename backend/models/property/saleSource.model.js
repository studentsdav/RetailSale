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
        }
    }, {
        timestamps: true,
        underscored: true,
        tableName: 'sale_sources'
    });

    return SaleSource;
};

module.exports = (sequelize, DataTypes) => {
    const RestaurantPrinter = sequelize.define('restaurant_printers', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        printer_name: {
            type: DataTypes.STRING(150),
            allowNull: false
        },
        printer_type: {
            type: DataTypes.STRING(30),
            defaultValue: 'NETWORK'
        },
        ip_address: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        port: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        status: {
            type: DataTypes.STRING(20),
            defaultValue: 'ACTIVE'
        }
    }, {
        tableName: 'restaurant_printers',
        timestamps: false
    });

    return RestaurantPrinter;
};

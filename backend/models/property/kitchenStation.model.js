module.exports = (sequelize, DataTypes) => {
    const KitchenStation = sequelize.define('kitchen_stations', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        station_name: {
            type: DataTypes.STRING(100),
            allowNull: false
        },
        printer_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        status: {
            type: DataTypes.STRING(20),
            defaultValue: 'ACTIVE'
        }
    }, {
        tableName: 'kitchen_stations',
        timestamps: false
    });

    KitchenStation.associate = (models) => {
        KitchenStation.belongsTo(models.restaurant_printers, {
            foreignKey: 'printer_id',
            as: 'printer'
        });
    };

    return KitchenStation;
};

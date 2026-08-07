module.exports = (sequelize, DataTypes) => {
    const KotItem = sequelize.define('kot_items', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        kot_header_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        item_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        item_name: {
            type: DataTypes.STRING(255),
            allowNull: false
        },
        qty: {
            type: DataTypes.DECIMAL(12, 4),
            defaultValue: 1.0000
        },
        status: {
            type: DataTypes.STRING(30),
            defaultValue: 'New'
        },
        item_remark: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        modifier_details: {
            type: DataTypes.JSONB,
            defaultValue: []
        },
        kitchen_station_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        }
    }, {
        tableName: 'kot_items',
        timestamps: false
    });

    KotItem.associate = (models) => {
        KotItem.belongsTo(models.kot_headers, {
            foreignKey: 'kot_header_id',
            as: 'header'
        });
        KotItem.belongsTo(models.item_master, {
            foreignKey: 'item_id',
            as: 'item'
        });
        KotItem.belongsTo(models.kitchen_stations, {
            foreignKey: 'kitchen_station_id',
            as: 'station'
        });
    };

    return KotItem;
};

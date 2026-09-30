module.exports = (sequelize, DataTypes) => {
    const RestaurantTable = sequelize.define('restaurant_tables', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        floor_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        dining_area_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        table_type_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        table_name: {
            type: DataTypes.STRING(100),
            allowNull: false
        },
        capacity: {
            type: DataTypes.INTEGER,
            defaultValue: 4
        },
        status: {
            type: DataTypes.STRING(30),
            defaultValue: 'Available'
        },
        current_guest_count: {
            type: DataTypes.INTEGER,
            defaultValue: 0
        },
        current_waiter_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        current_captain_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        active_sale_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        x_coordinate: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        y_coordinate: {
            type: DataTypes.INTEGER,
            allowNull: true
        }
    }, {
        tableName: 'restaurant_tables',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    RestaurantTable.associate = (models) => {
        RestaurantTable.belongsTo(models.floors, {
            foreignKey: 'floor_id',
            as: 'floor'
        });
        RestaurantTable.belongsTo(models.dining_areas, {
            foreignKey: 'dining_area_id',
            as: 'dining_area'
        });
        RestaurantTable.belongsTo(models.table_types, {
            foreignKey: 'table_type_id',
            as: 'table_type'
        });
        RestaurantTable.belongsTo(models.hr_employees, {
            foreignKey: 'current_waiter_id',
            as: 'waiter'
        });
        RestaurantTable.belongsTo(models.hr_employees, {
            foreignKey: 'current_captain_id',
            as: 'captain'
        });
    };

    return RestaurantTable;
};

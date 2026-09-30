module.exports = (sequelize, DataTypes) => {
    const HappyHour = sequelize.define(
        'happy_hours',
        {
            id: {
                type: DataTypes.INTEGER,
                primaryKey: true,
                autoIncrement: true
            },
            outlet_id: {
                type: DataTypes.INTEGER,
                allowNull: false
            },
            start_time: {
                type: DataTypes.STRING(10),
                allowNull: false
            },
            end_time: {
                type: DataTypes.STRING(10),
                allowNull: false
            },
            days_of_week: {
                type: DataTypes.STRING(255),
                allowNull: true
            },
            buy_qty: {
                type: DataTypes.DECIMAL(12, 4),
                defaultValue: 2
            },
            free_qty: {
                type: DataTypes.DECIMAL(12, 4),
                defaultValue: 1
            },
            apply_to_all_happy_hour_items: {
                type: DataTypes.BOOLEAN,
                defaultValue: true
            },
            parent_item_id: {
                type: DataTypes.INTEGER,
                allowNull: true
            },
            free_item_id: {
                type: DataTypes.INTEGER,
                allowNull: true
            },
            is_active: {
                type: DataTypes.BOOLEAN,
                defaultValue: true
            }
        },
        {
            tableName: 'happy_hours',
            timestamps: true,
            createdAt: 'created_at',
            updatedAt: 'updated_at'
        }
    );

    HappyHour.associate = (models) => {
        HappyHour.belongsTo(models.item_master, {
            foreignKey: 'parent_item_id',
            as: 'parent_item'
        });
        HappyHour.belongsTo(models.item_master, {
            foreignKey: 'free_item_id',
            as: 'free_item'
        });
    };

    return HappyHour;
};

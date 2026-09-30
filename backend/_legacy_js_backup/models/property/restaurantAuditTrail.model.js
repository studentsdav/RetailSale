module.exports = (sequelize, DataTypes) => {
    const RestaurantAuditTrail = sequelize.define('restaurant_audit_trail', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        event_time: {
            type: DataTypes.DATE,
            defaultValue: DataTypes.NOW
        },
        user_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        action_type: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        description: {
            type: DataTypes.TEXT,
            allowNull: true
        }
    }, {
        tableName: 'restaurant_audit_trail',
        timestamps: false
    });

    RestaurantAuditTrail.associate = (models) => {
        RestaurantAuditTrail.belongsTo(models.users, {
            foreignKey: 'user_id',
            as: 'user'
        });
    };

    return RestaurantAuditTrail;
};

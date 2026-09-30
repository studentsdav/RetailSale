module.exports = (sequelize, DataTypes) => {
    const DeliveryPartner = sequelize.define('delivery_partners', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        name: {
            type: DataTypes.STRING,
            allowNull: false
        },
        phone: {
            type: DataTypes.STRING,
            allowNull: false
        },
        password_hash: {
            type: DataTypes.STRING,
            allowNull: true
        },
        status: {
            type: DataTypes.STRING,
            defaultValue: 'AVAILABLE' // AVAILABLE, BUSY, OFFLINE
        },
        latitude: {
            type: DataTypes.DECIMAL(10, 6),
            defaultValue: 0.000000
        },
        longitude: {
            type: DataTypes.DECIMAL(10, 6),
            defaultValue: 0.000000
        }
    }, {
        timestamps: true,
        underscored: true
    });

    DeliveryPartner.associate = (models) => {
        DeliveryPartner.hasMany(models.customer_orders, {
            foreignKey: 'assigned_partner_id',
            as: 'orders'
        });
    };

    return DeliveryPartner;
};

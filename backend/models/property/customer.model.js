module.exports = (sequelize, DataTypes) => {
    const Customer = sequelize.define('customers', {
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        customer_name: {
            type: DataTypes.STRING(150),
            allowNull: true
        },
        customer_phone: {
            type: DataTypes.STRING(20),
            allowNull: true
        },
        customer_address: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        customer_gstin: {
            type: DataTypes.STRING(20),
            allowNull: true
        }
    }, {
        tableName: 'customers',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    return Customer;
};

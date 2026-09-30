module.exports = (sequelize, DataTypes) => {
    const PaymentMethod = sequelize.define('payment_methods', {
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
        tableName: 'payment_methods'
    });

    return PaymentMethod;
};

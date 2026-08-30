module.exports = (sequelize, DataTypes) => {
    return sequelize.define('users', {
        username: { type: DataTypes.STRING, unique: true },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },

        password_hash: DataTypes.TEXT,
        full_name: DataTypes.STRING,
        mobile: DataTypes.STRING,
        contact_email: {
            type: DataTypes.STRING(50)
        },
        role: DataTypes.STRING,
        max_discount_percent: { type: DataTypes.DECIMAL(5, 2), defaultValue: 100.00 },
        is_active: { type: DataTypes.BOOLEAN, defaultValue: true },
        last_login: DataTypes.DATE
    }, {
        tableName: 'users',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });
};

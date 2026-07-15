module.exports = (sequelize, DataTypes) => {
    return sequelize.define('outlets', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_code: {
            type: DataTypes.STRING(20),
            unique: true,
            allowNull: false
        },

        outlet_name: {
            type: DataTypes.STRING(100),
            allowNull: false
        },
        outlet_type: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        recovery_pin_hash: {
            type: DataTypes.STRING(255),
            allowNull: false
        },
        contact_email: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        contact_phone: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        tax_id: {
            type: DataTypes.STRING(50),
            allowNull: false
        },

        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        }
    }, {
        tableName: 'outlets',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'

    });
};

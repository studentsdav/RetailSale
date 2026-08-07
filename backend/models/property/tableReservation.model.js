module.exports = (sequelize, DataTypes) => {
    const TableReservation = sequelize.define('table_reservations', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        table_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        customer_name: {
            type: DataTypes.STRING(150),
            allowNull: false
        },
        customer_phone: {
            type: DataTypes.STRING(20),
            allowNull: false
        },
        reservation_time: {
            type: DataTypes.DATE,
            allowNull: false
        },
        guest_count: {
            type: DataTypes.INTEGER,
            defaultValue: 1
        },
        status: {
            type: DataTypes.STRING(30),
            defaultValue: 'Pending'
        },
        remarks: {
            type: DataTypes.TEXT,
            allowNull: true
        }
    }, {
        tableName: 'table_reservations',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    TableReservation.associate = (models) => {
        TableReservation.belongsTo(models.restaurant_tables, {
            foreignKey: 'table_id',
            as: 'table'
        });
    };

    return TableReservation;
};

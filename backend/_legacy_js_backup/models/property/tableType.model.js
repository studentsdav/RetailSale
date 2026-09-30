module.exports = (sequelize, DataTypes) => {
    const TableType = sequelize.define('table_types', {
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
            type: DataTypes.STRING(100),
            allowNull: false
        },
        charge_type: {
            type: DataTypes.STRING(20),
            defaultValue: 'FLAT'
        },
        charge_amount: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        }
    }, {
        tableName: 'table_types',
        timestamps: false
    });

    return TableType;
};

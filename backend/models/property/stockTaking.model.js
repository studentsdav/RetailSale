module.exports = (sequelize, DataTypes) => {
    const StockTaking = sequelize.define('stock_taking', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        audit_no: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        audit_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        item_code: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        item_name: {
            type: DataTypes.STRING(200),
            allowNull: false
        },
        unit: {
            type: DataTypes.STRING(30),
            defaultValue: 'PCS'
        },
        department: {
            type: DataTypes.STRING(100),
            defaultValue: 'General'
        },
        system_balance: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        counted_qty: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        variance: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        reason: {
            type: DataTypes.STRING(255),
            defaultValue: 'Physical Stock Count'
        },
        status: {
            type: DataTypes.STRING(30),
            defaultValue: 'COMPLETED'
        },
        reconciled_by: {
            type: DataTypes.STRING(100),
            allowNull: true
        }
    }, {
        tableName: 'stock_taking',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    return StockTaking;
};

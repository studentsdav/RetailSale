module.exports = (sequelize, DataTypes) => {
    const SalesRefund = sequelize.define('sales_refunds', {
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        sale_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        refund_no: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        refund_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        amount_pending: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        amount_paid: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        payment_mode: {
            type: DataTypes.STRING(20),
            allowNull: true
        },
        reference_no: {
            type: DataTypes.STRING(100),
            allowNull: true
        },
        status: {
            type: DataTypes.STRING(20),
            allowNull: false,
            defaultValue: 'PENDING'
        },
        notes: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        created_by: DataTypes.INTEGER,
        updated_by: DataTypes.INTEGER
    }, {
        tableName: 'sales_refunds',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    SalesRefund.associate = (models) => {
        SalesRefund.belongsTo(models.sales_headers, {
            foreignKey: 'sale_id',
            as: 'sale'
        });
    };

    return SalesRefund;
};

module.exports = (sequelize, DataTypes) => {
    const CustomerRepayment = sequelize.define('customer_repayments', {
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        sale_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        payment_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false
        },
        payment_mode: {
            type: DataTypes.STRING(20),
            allowNull: false
        },
        reference_no: DataTypes.STRING(100),
        note: DataTypes.TEXT,
        created_by: DataTypes.INTEGER,
        updated_by: DataTypes.INTEGER
    }, {
        tableName: 'customer_repayments',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    CustomerRepayment.associate = (models) => {
        CustomerRepayment.belongsTo(models.sales_headers, {
            foreignKey: 'sale_id',
            as: 'sale'
        });
    };

    return CustomerRepayment;
};
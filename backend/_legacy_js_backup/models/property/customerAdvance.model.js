module.exports = (sequelize, DataTypes) => {
    const CustomerAdvance = sequelize.define('customer_advances', {
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        source_sale_id: DataTypes.INTEGER,
        customer_name: DataTypes.STRING(150),
        customer_phone: DataTypes.STRING(20),
        customer_gstin: DataTypes.STRING(20),
        advance_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        original_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false
        },
        available_amount: {
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
        tableName: 'customer_advances',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    CustomerAdvance.associate = (models) => {
        CustomerAdvance.belongsTo(models.sales_headers, {
            foreignKey: 'source_sale_id',
            as: 'source_sale'
        });
    };

    return CustomerAdvance;
};

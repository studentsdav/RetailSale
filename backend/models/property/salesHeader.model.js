module.exports = (sequelize, DataTypes) => {
    const salesHeader = sequelize.define('sales_headers', {
        outlet_id: DataTypes.INTEGER,
        sale_no: DataTypes.STRING,
        sale_date: DataTypes.DATE,
        customer_name: DataTypes.STRING,
        customer_phone: DataTypes.STRING,
        customer_address: DataTypes.TEXT,
        customer_gstin: DataTypes.STRING,
        payment_mode: DataTypes.STRING,
        payment_reference: DataTypes.TEXT,

        initial_amount_paid: DataTypes.DECIMAL(12, 2),
        amount_paid: DataTypes.DECIMAL(12, 2),
        change_amount: DataTypes.DECIMAL(12, 2),
        balance_due: DataTypes.DECIMAL(12, 2),
        order_type: DataTypes.STRING,
        billing_country: DataTypes.STRING,
        billing_tax_mode: DataTypes.STRING,
        bill_format: DataTypes.STRING,
        tax_percent: DataTypes.DECIMAL(7, 2),
        scheme_id: DataTypes.INTEGER,
        scheme_name: DataTypes.STRING,
        scheme_discount: DataTypes.DECIMAL(12, 2),
        manual_discount_type: DataTypes.STRING,
        manual_discount_value: DataTypes.DECIMAL(12, 2),
        manual_discount_amount: DataTypes.DECIMAL(12, 2),
        total_qty: DataTypes.DECIMAL(12, 2),
        sub_total: DataTypes.DECIMAL(12, 2),
        taxable_amount: DataTypes.DECIMAL(12, 2),
        cgst_amount: DataTypes.DECIMAL(12, 2),
        sgst_amount: DataTypes.DECIMAL(12, 2),
        igst_amount: DataTypes.DECIMAL(12, 2),
        total_tax: DataTypes.DECIMAL(12, 2),
        tax_breakup: DataTypes.JSONB,
        charges: DataTypes.JSONB,
        charge_total: DataTypes.DECIMAL(12, 2),
        charge_tax_total: DataTypes.DECIMAL(12, 2),
        total_discount: DataTypes.DECIMAL(12, 2),
        round_off_amount: DataTypes.DECIMAL(12, 2),
        net_amount: DataTypes.DECIMAL(12, 2),
        voucher_code: DataTypes.STRING,
        voucher_label: DataTypes.STRING,
        loyalty_points_earned: DataTypes.INTEGER,
        loyalty_points_redeemed: DataTypes.INTEGER,
        loyalty_discount_amount: DataTypes.DECIMAL(12, 2),
        notes: DataTypes.TEXT,
        status: DataTypes.STRING,
        created_by: DataTypes.INTEGER,
        original_sale_id: DataTypes.INTEGER,
        previous_sale_id: DataTypes.INTEGER,
        replaced_by_sale_id: DataTypes.INTEGER,
        version_no: DataTypes.INTEGER,
        is_latest: DataTypes.BOOLEAN,
        is_deleted: DataTypes.BOOLEAN,
        modified_by: DataTypes.INTEGER,
        modified_at: DataTypes.DATE,
        modification_note: DataTypes.TEXT
    }, {
        tableName: 'sales_headers',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    salesHeader.associate = (models) => {
        salesHeader.hasMany(models.sales_items, {
            foreignKey: 'sale_id',
            as: 'items'
        });
         salesHeader.hasMany(models.customer_repayments, {
            foreignKey: 'sale_id',
            as: 'repayments'
        });
    };

    return salesHeader;
};

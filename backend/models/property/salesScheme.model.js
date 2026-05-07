module.exports = (sequelize, DataTypes) => {
    return sequelize.define('sales_schemes', {
        outlet_id: DataTypes.INTEGER,
        scheme_name: DataTypes.STRING,
        scheme_type: DataTypes.STRING,
        scheme_scope: DataTypes.STRING,
        discount_type: DataTypes.STRING,
        discount_value: DataTypes.DECIMAL(12, 2),
        start_time: DataTypes.STRING,
        end_time: DataTypes.STRING,
        min_qty: DataTypes.DECIMAL(12, 2),
        min_amount: DataTypes.DECIMAL(12, 2),
        item_id: DataTypes.INTEGER,
        required_daily_qty: DataTypes.DECIMAL(12, 2),
        free_qty: DataTypes.DECIMAL(12, 2),
        cycle_days: DataTypes.INTEGER,
        require_no_gaps: DataTypes.BOOLEAN,
        repeat_mode: DataTypes.STRING,
        apply_timing: DataTypes.STRING,
        auto_select_on_customer: DataTypes.BOOLEAN,
        next_purchase_valid_days: DataTypes.INTEGER,
        is_active: DataTypes.BOOLEAN,
        created_by: DataTypes.INTEGER
    }, {
        tableName: 'sales_schemes',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });
};

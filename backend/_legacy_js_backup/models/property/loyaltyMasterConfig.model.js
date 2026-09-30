module.exports = (sequelize, DataTypes) => {
    return sequelize.define('loyalty_master_config', {
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        program_status: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false
        },
        start_date: DataTypes.DATEONLY,
        end_date: DataTypes.DATEONLY,
        min_purchase_threshold: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        earning_ratio: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 1000
        },
        redemption_value: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 1
        },
        max_redeem_per_bill: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 0
        },
        point_expiry_days: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 90
        },
        created_by: DataTypes.INTEGER,
        updated_by: DataTypes.INTEGER
    }, {
        tableName: 'loyalty_master_config',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
        indexes: [{ unique: true, fields: ['outlet_id'] }]
    });
};

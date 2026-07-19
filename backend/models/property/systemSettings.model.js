module.exports = (sequelize, DataTypes) => {
    return sequelize.define('system_settings', {
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },

        auto_reorder: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        },

        is_cloud_enabled: {
            type: DataTypes.BOOLEAN,
            defaultValue: false
        },

        allow_negative_stock: {
            type: DataTypes.BOOLEAN,
            defaultValue: false
        },

        damage_approval_required: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        },

        enable_audit_log: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        },

        auto_print_on_save: {
            type: DataTypes.BOOLEAN,
            defaultValue: false
        },

        enable_item_images_in_sales: {
            type: DataTypes.BOOLEAN,
            defaultValue: false
        },

        print_mode: {
            type: DataTypes.STRING(30),
            defaultValue: 'PRINT_DIALOG'
        },

        default_printer_name: {
            type: DataTypes.STRING(255),
            defaultValue: ''
        },

        default_printer_url: {
            type: DataTypes.STRING(500),
            defaultValue: ''
        },

        billing_country: {
            type: DataTypes.STRING(80),
            defaultValue: 'India'
        },

        billing_tax_mode: {
            type: DataTypes.STRING(30),
            defaultValue: 'CGST_SGST'
        },

        bill_format: {
            type: DataTypes.STRING(20),
            defaultValue: 'A4'
        },

        default_charges: {
            type: DataTypes.JSONB,
            defaultValue: []
        },

        voucher_rules: {
            type: DataTypes.JSONB,
            defaultValue: []
        },
        enable_app_subscription: {
            type: DataTypes.BOOLEAN,
            defaultValue: false
        },
        enable_payment_gateway: {
            type: DataTypes.BOOLEAN,
            defaultValue: false
        },
        payment_gateway_provider: {
            type: DataTypes.STRING(50),
            defaultValue: 'SANDBOX'
        },
        payment_gateway_api_key: {
            type: DataTypes.STRING(255),
            defaultValue: ''
        },
        payment_gateway_secret_key: {
            type: DataTypes.STRING(255),
            defaultValue: ''
        },
        merchant_upi_id: {
            type: DataTypes.STRING(255),
            defaultValue: ''
        },
        sub_delivery_charge_enabled: {
            type: DataTypes.BOOLEAN,
            defaultValue: false
        },
        sub_delivery_charge_name: {
            type: DataTypes.STRING(255),
            defaultValue: 'Subscription Delivery'
        },
        sub_delivery_charge_amount: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.0
        },
        sub_delivery_charge_type: {
            type: DataTypes.STRING(50),
            defaultValue: 'FLAT'
        },
        sub_delivery_charge_gst_percent: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.0
        },
        sub_delivery_free_above: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.0
        }
    }, {
        tableName: 'system_settings',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
        indexes: [{ unique: true, fields: ['outlet_id'] }]
    });
};

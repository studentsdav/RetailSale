module.exports = (sequelize, DataTypes) => {
    const CustomerOrder = sequelize.define('customer_orders', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        customer_name: {
            type: DataTypes.STRING,
            allowNull: false
        },
        customer_phone: {
            type: DataTypes.STRING,
            allowNull: false
        },
        customer_address: {
            type: DataTypes.TEXT,
            allowNull: false
        },
        items: {
            type: DataTypes.JSONB,
            allowNull: false
        },
        sub_total: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        tax_amount: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        delivery_charge: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        net_amount: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        payment_status: {
            type: DataTypes.STRING,
            defaultValue: 'UNPAID' // UNPAID, PAID
        },
        status: {
            type: DataTypes.STRING,
            defaultValue: 'PENDING' // PENDING, ACCEPTED, ASSIGNED, OUT_FOR_DELIVERY, DELIVERED, CANCELLED
        },
        payment_mode: {
            type: DataTypes.STRING,
            defaultValue: 'CASH'
        },
        commission_amount: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 20.00
        },
        commission_status: {
            type: DataTypes.STRING,
            defaultValue: 'UNPAID'
        },
        assigned_partner_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        assigned_at: {
            type: DataTypes.DATE,
            allowNull: true
        },
        picked_up_at: {
            type: DataTypes.DATE,
            allowNull: true
        },
        delivered_at: {
            type: DataTypes.DATE,
            allowNull: true
        },
        return_status: {
            type: DataTypes.STRING,
            allowNull: true
        },
        return_type: {
            type: DataTypes.STRING,
            allowNull: true
        },
        refund_status: {
            type: DataTypes.STRING,
            allowNull: true
        },
        return_item_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        return_item_name: {
            type: DataTypes.STRING,
            allowNull: true
        },
        returned_items: {
            type: DataTypes.JSONB,
            allowNull: true
        },
        gstin: {
            type: DataTypes.STRING,
            allowNull: true
        },
        charges: {
            type: DataTypes.JSONB,
            allowNull: true
        },
        notes: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        cancellation_reason: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        feedback: {
            type: DataTypes.JSONB,
            allowNull: true
        },
        return_rejection_reason: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        received_items: {
            type: DataTypes.JSONB,
            allowNull: true
        },
        original_net_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: true
        },
        modification_reason: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        refund_payment_mode: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        refund_paid_at: {
            type: DataTypes.DATE,
            allowNull: true
        },
        is_prepaid: {
            type: DataTypes.BOOLEAN,
            defaultValue: false
        }
    }, {
        timestamps: true,
        underscored: true
    });

    CustomerOrder.associate = (models) => {
        CustomerOrder.belongsTo(models.delivery_partners, {
            foreignKey: 'assigned_partner_id',
            as: 'partner'
        });
    };

    return CustomerOrder;
};

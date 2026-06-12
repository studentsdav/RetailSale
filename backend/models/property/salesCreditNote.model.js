module.exports = (sequelize, DataTypes) => {
    const SalesCreditNote = sequelize.define('sales_credit_notes', {
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        sale_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        credit_note_no: {
            type: DataTypes.STRING(50),
            allowNull: false,
            unique: true
        },
        credit_note_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        customer_name: {
            type: DataTypes.STRING(150),
            allowNull: true
        },
        customer_phone: {
            type: DataTypes.STRING(20),
            allowNull: true
        },
        customer_gstin: {
            type: DataTypes.STRING(20),
            allowNull: true
        },
        items: {
            type: DataTypes.JSONB,
            allowNull: false
        },
        total_qty: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        sub_total: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        taxable_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        cgst_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        sgst_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        igst_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        total_tax: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        net_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0
        },
        reason: {
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
        created_by: DataTypes.INTEGER
    }, {
        tableName: 'sales_credit_notes',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    SalesCreditNote.associate = (models) => {
        SalesCreditNote.belongsTo(models.sales_headers, {
            foreignKey: 'sale_id',
            as: 'sale'
        });
    };

    return SalesCreditNote;
};

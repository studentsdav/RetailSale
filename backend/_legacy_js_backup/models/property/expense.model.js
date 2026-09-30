module.exports = (sequelize, DataTypes) => {
    const Expense = sequelize.define('expenses', {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        vendor_id: {
            type: DataTypes.INTEGER
        },
        category_id: {
            type: DataTypes.UUID
        },
        invoice_ref_no: {
            type: DataTypes.STRING(255)
        },
        payment_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        payment_method: {
            type: DataTypes.STRING(100),
            allowNull: false
        },
        is_tax_inclusive: {
            type: DataTypes.BOOLEAN,
            defaultValue: false,
            allowNull: false
        },
        base_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        total_tax_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        total_deduction_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        net_payable_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        expense_note: {
            type: DataTypes.TEXT
        },
        status: {
            type: DataTypes.STRING(50),
            defaultValue: 'Paid',
            allowNull: false
        },
        created_by: {
            type: DataTypes.INTEGER
        }
    }, {
        tableName: 'expenses',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    Expense.associate = (models) => {
        Expense.belongsTo(models.outlets, {
            foreignKey: 'outlet_id',
            as: 'outlet'
        });
        Expense.belongsTo(models.supplier_master, {
            foreignKey: 'vendor_id',
            as: 'vendor'
        });
        Expense.belongsTo(models.expense_categories, {
            foreignKey: 'category_id',
            as: 'category'
        });
        Expense.hasMany(models.expense_taxes, {
            foreignKey: 'expense_id',
            as: 'taxes',
            onDelete: 'CASCADE'
        });
        Expense.hasMany(models.expense_deductions, {
            foreignKey: 'expense_id',
            as: 'deductions',
            onDelete: 'CASCADE'
        });
    };

    return Expense;
};

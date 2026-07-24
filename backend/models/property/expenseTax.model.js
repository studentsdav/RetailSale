module.exports = (sequelize, DataTypes) => {
    const ExpenseTax = sequelize.define('expense_taxes', {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true
        },
        expense_id: {
            type: DataTypes.UUID,
            allowNull: false
        },
        tax_name: {
            type: DataTypes.STRING(255),
            allowNull: false
        },
        tax_percentage: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        tax_amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        }
    }, {
        tableName: 'expense_taxes',
        timestamps: false
    });

    ExpenseTax.associate = (models) => {
        ExpenseTax.belongsTo(models.expenses, {
            foreignKey: 'expense_id'
        });
    };

    return ExpenseTax;
};

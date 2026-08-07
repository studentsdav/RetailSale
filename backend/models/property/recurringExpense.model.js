module.exports = (sequelize, DataTypes) => {
    const RecurringExpense = sequelize.define('recurring_expenses', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        expense_category_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        description: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        amount: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        frequency: {
            type: DataTypes.STRING(30),
            defaultValue: 'MONTHLY'
        },
        start_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        end_date: {
            type: DataTypes.DATEONLY,
            allowNull: true
        },
        last_generation_date: {
            type: DataTypes.DATEONLY,
            allowNull: true
        },
        next_generation_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        }
    }, {
        tableName: 'recurring_expenses',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    RecurringExpense.associate = (models) => {
        RecurringExpense.belongsTo(models.expense_categories, {
            foreignKey: 'expense_category_id',
            as: 'category'
        });
    };

    return RecurringExpense;
};

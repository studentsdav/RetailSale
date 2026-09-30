module.exports = (sequelize, DataTypes) => {
    const ExpenseCategory = sequelize.define('expense_categories', {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        user_id: {
            type: DataTypes.INTEGER
        },
        category_name: {
            type: DataTypes.STRING(255),
            allowNull: false
        },
        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true,
            allowNull: false
        }
    }, {
        tableName: 'expense_categories',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    ExpenseCategory.associate = (models) => {
        ExpenseCategory.belongsTo(models.outlets, {
            foreignKey: 'outlet_id',
            as: 'outlet'
        });
        ExpenseCategory.belongsTo(models.users, {
            foreignKey: 'user_id',
            as: 'user'
        });
    };

    return ExpenseCategory;
};

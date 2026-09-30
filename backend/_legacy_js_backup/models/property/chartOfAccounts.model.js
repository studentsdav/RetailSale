module.exports = (sequelize, DataTypes) => {
    const ChartOfAccounts = sequelize.define('chart_of_accounts', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        account_code: {
            type: DataTypes.STRING(30),
            allowNull: true
        },
        account_name: {
            type: DataTypes.STRING(150),
            allowNull: false
        },
        group_name: {
            type: DataTypes.STRING(100),
            allowNull: false
        },
        nature: {
            type: DataTypes.ENUM('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE'),
            allowNull: false
        },
        opening_debit: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        opening_credit: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        current_balance: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        is_system: {
            type: DataTypes.BOOLEAN,
            defaultValue: false
        },
        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        }
    }, {
        tableName: 'chart_of_accounts',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    return ChartOfAccounts;
};

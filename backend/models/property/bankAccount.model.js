module.exports = (sequelize, DataTypes) => {
    const BankAccount = sequelize.define('bank_accounts', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        bank_name: {
            type: DataTypes.STRING(150),
            allowNull: false
        },
        account_name: {
            type: DataTypes.STRING(150),
            allowNull: false
        },
        account_number: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        ifsc_code: {
            type: DataTypes.STRING(20),
            allowNull: true
        },
        branch_name: {
            type: DataTypes.STRING(100),
            allowNull: true
        },
        account_type: {
            type: DataTypes.STRING(30),
            defaultValue: 'CURRENT'
        },
        opening_balance: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        current_balance: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        },
        created_by: {
            type: DataTypes.INTEGER,
            allowNull: true
        }
    }, {
        tableName: 'bank_accounts',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    return BankAccount;
};

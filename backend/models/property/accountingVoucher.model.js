module.exports = (sequelize, DataTypes) => {
    const AccountingVoucher = sequelize.define('accounting_vouchers', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        voucher_no: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        voucher_type: {
            type: DataTypes.ENUM('CONTRA', 'PAYMENT', 'RECEIPT', 'JOURNAL', 'SALES', 'PURCHASE'),
            allowNull: false
        },
        voucher_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        payment_mode: {
            type: DataTypes.STRING(30),
            defaultValue: 'CASH'
        },
        bank_account_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        reference_no: {
            type: DataTypes.STRING(100),
            allowNull: true
        },
        narration: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        total_debit: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        total_credit: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        status: {
            type: DataTypes.STRING(20),
            defaultValue: 'POSTED'
        },
        created_by: {
            type: DataTypes.INTEGER,
            allowNull: false
        }
    }, {
        tableName: 'accounting_vouchers',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    return AccountingVoucher;
};

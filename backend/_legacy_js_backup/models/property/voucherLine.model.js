module.exports = (sequelize, DataTypes) => {
    const VoucherLine = sequelize.define('voucher_lines', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        voucher_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        line_type: {
            type: DataTypes.ENUM('DEBIT', 'CREDIT'),
            allowNull: false
        },
        account_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        account_name: {
            type: DataTypes.STRING(150),
            allowNull: false
        },
        account_type: {
            type: DataTypes.STRING(50),
            defaultValue: 'GENERAL'
        },
        debit_amount: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        credit_amount: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        particulars: {
            type: DataTypes.STRING(255),
            allowNull: true
        }
    }, {
        tableName: 'voucher_lines',
        timestamps: false
    });

    return VoucherLine;
};

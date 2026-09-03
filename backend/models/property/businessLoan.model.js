module.exports = (sequelize, DataTypes) => {
    const BusinessLoan = sequelize.define('business_loans', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        loan_name: {
            type: DataTypes.STRING(150),
            allowNull: false
        },
        lender_name: {
            type: DataTypes.STRING(150),
            allowNull: true
        },
        principal_amount: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        interest_rate: {
            type: DataTypes.DECIMAL(5, 2),
            defaultValue: 0.00
        },
        tenure_months: {
            type: DataTypes.INTEGER,
            defaultValue: 12
        },
        monthly_emi: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        remaining_principal: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        status: {
            type: DataTypes.STRING(30),
            defaultValue: 'ACTIVE'
        },
        notes: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        created_by: {
            type: DataTypes.INTEGER,
            allowNull: true
        }
    }, {
        tableName: 'business_loans',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    return BusinessLoan;
};

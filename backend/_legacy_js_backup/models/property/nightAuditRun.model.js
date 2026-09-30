module.exports = (sequelize, DataTypes) => {
    const NightAuditRun = sequelize.define('night_audit_runs', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        audit_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        run_type: {
            type: DataTypes.STRING(20),
            allowNull: false,
            defaultValue: 'MANUAL' // MANUAL, AUTO
        },
        status: {
            type: DataTypes.STRING(30),
            allowNull: false,
            defaultValue: 'IN_PROGRESS' // IN_PROGRESS, SUCCESS, FAILED, COMPLETED_WITH_WARNINGS
        },
        gross_sales: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        total_discounts: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        total_taxes: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        net_sales: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        cash_expected: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        cash_physical: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        cash_variance: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        denominations: {
            type: DataTypes.JSONB,
            allowNull: true,
            defaultValue: {}
        },
        open_kot_count: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 0
        },
        unclosed_shift_count: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 0
        },
        execution_log: {
            type: DataTypes.JSONB,
            allowNull: true,
            defaultValue: []
        },
        z_report_url: {
            type: DataTypes.STRING(500),
            allowNull: true
        },
        started_at: {
            type: DataTypes.DATE,
            allowNull: false,
            defaultValue: DataTypes.NOW
        },
        completed_at: {
            type: DataTypes.DATE,
            allowNull: true
        },
        performed_by: {
            type: DataTypes.INTEGER,
            allowNull: true
        }
    }, {
        tableName: 'night_audit_runs',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    NightAuditRun.associate = (models) => {
        NightAuditRun.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
        NightAuditRun.belongsTo(models.users, { foreignKey: 'performed_by', as: 'user' });
        NightAuditRun.hasMany(models.night_audit_details, { foreignKey: 'audit_run_id', as: 'details' });
    };

    return NightAuditRun;
};

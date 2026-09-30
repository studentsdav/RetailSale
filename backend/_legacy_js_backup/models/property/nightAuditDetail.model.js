module.exports = (sequelize, DataTypes) => {
    const NightAuditDetail = sequelize.define('night_audit_details', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        audit_run_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        section_type: {
            type: DataTypes.STRING(50), // PAYMENT_METHODS, TAX_SUMMARY, CATEGORY_SALES, INVENTORY_SNAPSHOT, CHECKLIST_WARNINGS
            allowNull: false
        },
        detail_key: {
            type: DataTypes.STRING(100),
            allowNull: false
        },
        detail_value: {
            type: DataTypes.JSONB,
            allowNull: false,
            defaultValue: {}
        }
    }, {
        tableName: 'night_audit_details',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    NightAuditDetail.associate = (models) => {
        NightAuditDetail.belongsTo(models.night_audit_runs, { foreignKey: 'audit_run_id', as: 'auditRun' });
        NightAuditDetail.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
    };

    return NightAuditDetail;
};

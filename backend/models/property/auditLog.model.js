module.exports = (sequelize, DataTypes) => {
    return sequelize.define('audit_logs', {
        outlet_id: DataTypes.INTEGER,
        user_id: DataTypes.INTEGER,
        module: DataTypes.STRING,
        action: DataTypes.STRING,
        table_name: DataTypes.STRING,
        record_id: DataTypes.INTEGER,
        old_data: DataTypes.JSONB,
        new_data: DataTypes.JSONB,
        ip_address: DataTypes.STRING,
        user_agent: DataTypes.TEXT
    }, {
        tableName: 'audit_logs',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });
};

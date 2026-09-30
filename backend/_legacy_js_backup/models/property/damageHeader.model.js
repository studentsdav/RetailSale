module.exports = (sequelize, DataTypes) => {
    const DamageHeader = sequelize.define('damage_headers', {
        damage_no: DataTypes.STRING,
        damage_date: DataTypes.DATEONLY,
        total_value: DataTypes.DECIMAL(12, 2),
        status: DataTypes.STRING,
        approval_status: DataTypes.STRING,
        approved_by: DataTypes.INTEGER,
        approved_at: DataTypes.DATE,
        rejected_by: DataTypes.INTEGER,
        rejected_at: DataTypes.DATE,
        rejection_reason: DataTypes.TEXT,
        outlet_id: DataTypes.INTEGER,
        created_by: DataTypes.INTEGER
    }, {
        tableName: 'damage_headers',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    DamageHeader.associate = (models) => {
        DamageHeader.hasMany(models.damage_items, {
            foreignKey: 'damage_id',
            as: 'items'
        });
    };

    return DamageHeader;
};

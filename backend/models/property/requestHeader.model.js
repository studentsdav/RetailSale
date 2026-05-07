module.exports = (sequelize, DataTypes) => {

    const RequestHeader = sequelize.define('request_headers', {
        request_no: DataTypes.STRING,
        department: DataTypes.STRING,
        request_date: DataTypes.DATEONLY,
        open_request_no: DataTypes.STRING,
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
        tableName: 'request_headers',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    RequestHeader.associate = (models) => {
        RequestHeader.hasMany(models.request_items, {
            foreignKey: 'request_id',
            as: 'items'
        });
    };

    return RequestHeader;
};

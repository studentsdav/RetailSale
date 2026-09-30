module.exports = (sequelize, DataTypes) => {

    const IssueHeaders = sequelize.define('issue_headers', {
        issue_no: DataTypes.STRING,
        department: DataTypes.STRING,
        indent_no: DataTypes.STRING,
        issue_type: DataTypes.STRING,
        issue_date: DataTypes.DATEONLY,
        open_request_no: DataTypes.STRING,
        status: DataTypes.STRING,
        outlet_id: DataTypes.INTEGER,
        created_by: DataTypes.INTEGER,
        created_at: DataTypes.DATE
    }, {
        tableName: 'issue_headers',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    IssueHeaders.associate = (models) => {
        IssueHeaders.hasMany(models.issue_items, {
            foreignKey: 'issue_id',
            as: 'items'
        });
    };

    return IssueHeaders;
};

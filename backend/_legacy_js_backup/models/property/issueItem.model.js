module.exports = (sequelize, DataTypes) => {
    const IssueItems = sequelize.define(
        'issue_items',
        {
            issue_id: DataTypes.INTEGER,
            item_id: DataTypes.INTEGER,
            qty: DataTypes.DECIMAL(12, 2),
            rate: DataTypes.DECIMAL(12, 2),
            tax: DataTypes.DECIMAL(12, 2)
        },
        {
            tableName: 'issue_items',
            timestamps: false
        }
    );

    // ✅ THIS IS THE MISSING LINK
    IssueItems.associate = (models) => {

        IssueItems.belongsTo(models.issue_headers, {
            foreignKey: 'issue_id',
            as: 'issue'
        });
        IssueItems.belongsTo(models.item_master, {
            foreignKey: 'item_id',
            as: 'item_master'
        });
    };

    return IssueItems;
};

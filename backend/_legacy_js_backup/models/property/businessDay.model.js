module.exports = (sequelize, DataTypes) => {
    const BusinessDay = sequelize.define('business_day_status', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        business_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        status: {
            type: DataTypes.STRING(30),
            allowNull: false,
            defaultValue: 'OPEN' // OPEN, IN_AUDIT, CLOSED
        },
        opened_at: {
            type: DataTypes.DATE,
            allowNull: false,
            defaultValue: DataTypes.NOW
        },
        closed_at: {
            type: DataTypes.DATE,
            allowNull: true
        },
        opened_by: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        closed_by: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        notes: {
            type: DataTypes.TEXT,
            allowNull: true
        }
    }, {
        tableName: 'business_day_status',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    BusinessDay.associate = (models) => {
        BusinessDay.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
        BusinessDay.belongsTo(models.users, { foreignKey: 'opened_by', as: 'openedByUser' });
        BusinessDay.belongsTo(models.users, { foreignKey: 'closed_by', as: 'closedByUser' });
    };

    return BusinessDay;
};

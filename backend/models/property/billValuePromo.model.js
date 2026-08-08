module.exports = (sequelize, DataTypes) => {
    const BillValuePromo = sequelize.define(
        'bill_value_promos',
        {
            id: {
                type: DataTypes.INTEGER,
                primaryKey: true,
                autoIncrement: true
            },
            outlet_id: {
                type: DataTypes.INTEGER,
                allowNull: false
            },
            name: {
                type: DataTypes.STRING(255),
                allowNull: false
            },
            min_bill_amount: {
                type: DataTypes.DECIMAL(12, 2),
                defaultValue: 0.00
            },
            target_item_id: {
                type: DataTypes.INTEGER,
                allowNull: false
            },
            discount_value: {
                type: DataTypes.DECIMAL(12, 2),
                defaultValue: 100.00
            },
            is_active: {
                type: DataTypes.BOOLEAN,
                defaultValue: true
            },
            created_at: {
                type: DataTypes.DATE,
                defaultValue: DataTypes.NOW
            },
            updated_at: {
                type: DataTypes.DATE,
                defaultValue: DataTypes.NOW
            }
        },
        {
            tableName: 'bill_value_promos',
            timestamps: true,
            createdAt: 'created_at',
            updatedAt: 'updated_at'
        }
    );

    BillValuePromo.associate = (models) => {
        BillValuePromo.belongsTo(models.item_master, {
            foreignKey: 'target_item_id',
            as: 'target_item'
        });
    };

    return BillValuePromo;
};

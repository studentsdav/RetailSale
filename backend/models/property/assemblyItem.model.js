module.exports = (sequelize, DataTypes) => {
    const AssemblyItem = sequelize.define('assembly_items', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        assembly_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        component_item_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        qty_required: {
            type: DataTypes.DECIMAL(12, 4),
            allowNull: false
        },
        qty_used: {
            type: DataTypes.DECIMAL(12, 4),
            allowNull: false
        },
        rate: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false
        },
        total_cost: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false
        }
    }, {
        timestamps: false,
        underscored: true,
        tableName: 'assembly_items'
    });

    AssemblyItem.associate = (models) => {
        AssemblyItem.belongsTo(models.assembly_headers, {
            foreignKey: 'assembly_id',
            as: 'assembly'
        });
        AssemblyItem.belongsTo(models.item_master, {
            foreignKey: 'component_item_id',
            as: 'component_item'
        });
    };

    return AssemblyItem;
};

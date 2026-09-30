module.exports = (sequelize, DataTypes) => {
    const AssemblyHeader = sequelize.define('assembly_headers', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        assembly_no: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        assembly_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        parent_item_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        qty: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false
        },
        composite_cost: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false
        },
        total_cost: {
            type: DataTypes.DECIMAL(12, 2),
            allowNull: false
        },
        notes: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        created_by: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        status: {
            type: DataTypes.STRING(20),
            allowNull: false,
            defaultValue: 'RUNNING'
        }
    }, {
        timestamps: true,
        underscored: true,
        tableName: 'assembly_headers'
    });

    AssemblyHeader.associate = (models) => {
        AssemblyHeader.belongsTo(models.item_master, {
            foreignKey: 'parent_item_id',
            as: 'parent_item'
        });
        AssemblyHeader.belongsTo(models.users, {
            foreignKey: 'created_by',
            as: 'creator'
        });
        AssemblyHeader.hasMany(models.assembly_items, {
            foreignKey: 'assembly_id',
            as: 'items'
        });
    };

    return AssemblyHeader;
};

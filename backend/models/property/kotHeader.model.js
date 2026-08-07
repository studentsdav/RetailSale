module.exports = (sequelize, DataTypes) => {
    const KotHeader = sequelize.define('kot_headers', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        kot_no: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        table_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        service_type: {
            type: DataTypes.STRING(50),
            defaultValue: 'Dine In'
        },
        status: {
            type: DataTypes.STRING(30),
            defaultValue: 'New'
        },
        waiter_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        captain_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        remarks: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        revision_no: {
            type: DataTypes.INTEGER,
            defaultValue: 1
        },
        created_time: {
            type: DataTypes.DATE,
            defaultValue: DataTypes.NOW
        },
        accepted_time: {
            type: DataTypes.DATE,
            allowNull: true
        },
        cooking_start: {
            type: DataTypes.DATE,
            allowNull: true
        },
        ready_time: {
            type: DataTypes.DATE,
            allowNull: true
        },
        served_time: {
            type: DataTypes.DATE,
            allowNull: true
        },
        closed_time: {
            type: DataTypes.DATE,
            allowNull: true
        },
        sales_header_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        }
    }, {
        tableName: 'kot_headers',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    KotHeader.associate = (models) => {
        KotHeader.belongsTo(models.restaurant_tables, {
            foreignKey: 'table_id',
            as: 'table'
        });
        KotHeader.belongsTo(models.hr_employees, {
            foreignKey: 'waiter_id',
            as: 'waiter'
        });
        KotHeader.belongsTo(models.hr_employees, {
            foreignKey: 'captain_id',
            as: 'captain'
        });
        KotHeader.belongsTo(models.sales_headers, {
            foreignKey: 'sales_header_id',
            as: 'sales_header'
        });
        KotHeader.hasMany(models.kot_items, {
            foreignKey: 'kot_header_id',
            as: 'items'
        });
        KotHeader.hasMany(models.kot_revisions, {
            foreignKey: 'kot_header_id',
            as: 'revisions'
        });
    };

    return KotHeader;
};

module.exports = (sequelize, DataTypes) => {
    const KotRevision = sequelize.define('kot_revisions', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        kot_header_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        revision_no: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        change_details: {
            type: DataTypes.JSONB,
            defaultValue: []
        },
        modified_by: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        modification_reason: {
            type: DataTypes.STRING(255),
            allowNull: true
        }
    }, {
        tableName: 'kot_revisions',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false
    });

    KotRevision.associate = (models) => {
        KotRevision.belongsTo(models.kot_headers, {
            foreignKey: 'kot_header_id',
            as: 'header'
        });
        KotRevision.belongsTo(models.users, {
            foreignKey: 'modified_by',
            as: 'user'
        });
    };

    return KotRevision;
};

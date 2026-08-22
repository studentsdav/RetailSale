module.exports = (sequelize, DataTypes) => {
    return sequelize.define('user_notes', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 0
        },
        user_id: {
            type: DataTypes.INTEGER,
            allowNull: true,
            defaultValue: 1
        },
        title: {
            type: DataTypes.STRING(255),
            allowNull: false
        },
        content: {
            type: DataTypes.TEXT,
            allowNull: true,
            defaultValue: ''
        },
        color_hex: {
            type: DataTypes.STRING(20),
            allowNull: false,
            defaultValue: '#FEF08A' // Default Yellow Sticky Note
        },
        is_pinned: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false
        },
        is_completed: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false
        },
        reminder_type: {
            type: DataTypes.ENUM('NONE', 'SPECIFIC_DATE', 'DAILY', 'WEEKLY', 'MONTHLY'),
            allowNull: false,
            defaultValue: 'NONE'
        },
        reminder_date: {
            type: DataTypes.DATE,
            allowNull: true
        },
        reminder_time: {
            type: DataTypes.STRING(30),
            allowNull: true
        }
    }, {
        tableName: 'user_notes',
        timestamps: true
    });
};

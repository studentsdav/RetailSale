module.exports = (sequelize, DataTypes) => {
    return sequelize.define('property_info', {
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },

        property_name: {
            type: DataTypes.STRING(150),
            allowNull: false
        },

        legal_name: {
            type: DataTypes.STRING(150)
        },

        address: {
            type: DataTypes.TEXT
        },

        city: {
            type: DataTypes.STRING(100)
        },

        state: {
            type: DataTypes.STRING(100)
        },

        pin_code: {
            type: DataTypes.STRING(10)
        },

        contact_person: {
            type: DataTypes.STRING(100)
        },

        mobile: {
            type: DataTypes.STRING(20)
        },

        email: {
            type: DataTypes.STRING(100)
        },

        gst_no: {
            type: DataTypes.STRING(20)
        },

        pan_no: {
            type: DataTypes.STRING(20)
        },

        fssai_no: {
            type: DataTypes.STRING(30)
        },

        drug_license_no: {
            type: DataTypes.STRING(50)
        },

        logo_path: {
            type: DataTypes.TEXT
        },

        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        }
    }, {
        tableName: 'property_info',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });
};

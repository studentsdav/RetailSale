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

        website: {
            type: DataTypes.STRING(150)
        },

        print_mobile: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        },

        print_email: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        },

        print_website: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        },

        thermal_footer_note: {
            type: DataTypes.TEXT,
            defaultValue: 'Thank you for shopping with us. Please visit again.\nReturn Policy: Exchange within 7 days with original receipt.\nHave a nice day!'
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

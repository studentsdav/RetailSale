module.exports = (sequelize, DataTypes) => {
    const DrawVoucher = sequelize.define('draw_vouchers', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        campaign_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        customer_phone: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        customer_name: {
            type: DataTypes.STRING(150),
            allowNull: true
        },
        sale_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        voucher_code: {
            type: DataTypes.STRING(100),
            allowNull: false,
            unique: true
        },
        is_winner: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false
        }
    }, {
        tableName: 'draw_vouchers',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    DrawVoucher.associate = (models) => {
        DrawVoucher.belongsTo(models.lucky_draw_campaigns, {
            foreignKey: 'campaign_id',
            as: 'campaign'
        });
        DrawVoucher.belongsTo(models.sales_headers, {
            foreignKey: 'sale_id',
            as: 'sale'
        });
    };

    return DrawVoucher;
};

module.exports = (sequelize, DataTypes) => {

    const goods_receipts =
        sequelize.define('goods_receipts', {
            outlet_id: DataTypes.INTEGER,
            grn_no: DataTypes.STRING,
            manual_no: DataTypes.STRING,
            po_no: DataTypes.STRING,
            supplier_id: DataTypes.INTEGER,
            receipt_date: DataTypes.DATEONLY,
            supplier_bill_no: DataTypes.STRING,
            total_amount: DataTypes.DECIMAL(12, 2),
            total_gst: DataTypes.DECIMAL(12, 2),
            net_amount: DataTypes.DECIMAL(12, 2),
            status: DataTypes.STRING,
            created_by: DataTypes.INTEGER
        }, {
            tableName: 'goods_receipts',
            timestamps: true,
            createdAt: 'created_at',
            updatedAt: 'updated_at'
        });


    goods_receipts.associate = (models) => {

        goods_receipts.hasMany(models.goods_receipt_items, {
            foreignKey: 'grn_id',
            as: 'items',
            onDelete: 'CASCADE'
        });

        goods_receipts.belongsTo(models.supplier_master, {
            foreignKey: 'supplier_id',
            as: 'supplier'
        });

    };


    return goods_receipts;
};

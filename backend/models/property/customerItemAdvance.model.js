module.exports = (sequelize, DataTypes) => {
  const model = sequelize.define(
    "customer_item_advances",
    {
      outlet_id: DataTypes.INTEGER,
      source_sale_id: DataTypes.INTEGER,
      customer_name: DataTypes.STRING,
      customer_phone: DataTypes.STRING,
      customer_gstin: DataTypes.STRING,
      item_id: DataTypes.INTEGER,
      advance_date: DataTypes.DATEONLY,
      original_qty: DataTypes.DECIMAL(12, 2),
      available_qty: DataTypes.DECIMAL(12, 2),
      rate: DataTypes.DECIMAL(12, 2),
      note: DataTypes.TEXT,
      created_by: DataTypes.INTEGER,
      updated_by: DataTypes.INTEGER,
    },
    {
      tableName: "customer_item_advances",
      timestamps: true,
      createdAt: "created_at",
      updatedAt: "updated_at",
    }
  );

  model.associate = (models) => {
    model.belongsTo(models.item_master, {
      foreignKey: "item_id",
      as: "item",
    });
    model.belongsTo(models.sales_headers, {
      foreignKey: "source_sale_id",
      as: "sourceSale",
    });
  };

  return model;
};


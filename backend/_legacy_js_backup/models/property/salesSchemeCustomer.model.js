module.exports = (sequelize, DataTypes) => {
  const model = sequelize.define(
    "sales_scheme_customers",
    {
      outlet_id: DataTypes.INTEGER,
      scheme_id: DataTypes.INTEGER,
      customer_name: DataTypes.STRING,
      customer_phone: DataTypes.STRING,
      customer_gstin: DataTypes.STRING,
      start_date: DataTypes.DATEONLY,
      usage_type: DataTypes.STRING,
      is_consumed: DataTypes.BOOLEAN,
      last_applied_cycle_start: DataTypes.DATEONLY,
      last_applied_cycle_end: DataTypes.DATEONLY,
      is_active: DataTypes.BOOLEAN,
      created_by: DataTypes.INTEGER,
    },
    {
      tableName: "sales_scheme_customers",
      timestamps: true,
      createdAt: "created_at",
      updatedAt: "updated_at",
    }
  );

  model.associate = (models) => {
    model.belongsTo(models.sales_schemes, {
      foreignKey: "scheme_id",
      as: "scheme",
    });
  };

  return model;
};

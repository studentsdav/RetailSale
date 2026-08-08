const { Sequelize } = require('sequelize');
const loadConfig = require('./utils/decryptConfig');

async function test() {
  const config = loadConfig();
  const testDb = new Sequelize(config.db_database, config.db_user, config.db_password, {
      host: config.db_host || "127.0.0.1",
      port: Number(config.db_port || 5432),
      dialect: "postgres",
      logging: false
  });
  
  await testDb.authenticate();
  
  const [results] = await testDb.query("SELECT id, item_code, item_name, rate, retail_sale_price, mrp, is_tax_inclusive, tax_percent FROM item_master WHERE mrp > 0");
  console.log("ITEM_RESULTS:", JSON.stringify(results, null, 2));
  
  await testDb.close();
}
test().catch(console.error);

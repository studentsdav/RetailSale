const { Client } = require('pg');
const c = new Client({ host: '127.0.0.1', port: 5432, database: 'POSINVRETAIL', user: 'inv_admin_retail', password: 'R4QQB5NorGu5B5pK' });
c.connect().then(async () => {
  const cols = await c.query("SELECT column_name FROM information_schema.columns WHERE table_name = 'outlets'");
  console.log("outlets:", cols.rows.map(r => r.column_name));
  const pcols = await c.query("SELECT column_name FROM information_schema.columns WHERE table_name = 'property_info'");
  console.log("property_info:", pcols.rows.map(r => r.column_name));
  const mcols = await c.query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND (table_name LIKE '%vendor%' OR table_name LIKE '%distrib%' OR table_name LIKE '%market%')");
  console.log("vendor/market tables:", mcols.rows.map(r => r.table_name));
  await c.end();
}).catch(console.error);

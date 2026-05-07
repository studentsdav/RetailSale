// async function detectPostgresPort(config) {

//     const { Sequelize } = require("sequelize");

//     const portsToTry = [5432, 5433];

//     for (const port of portsToTry) {

//         try {

//             const sequelize = new Sequelize(
//                 "postgres",
//                 config.db_user || "postgres",
//                 config.db_password,
//                 {
//                     host: config.db_host || "127.0.0.1",
//                     port: Number(config.db_port || 5432),
//                     dialect: "postgres",
//                     logging: false,
//                     dialectOptions: { connectTimeout: 2000 }
//                 }
//             );

//             await sequelize.authenticate();

//             await sequelize.close();

//             console.log("✅ PostgreSQL running on port:", port);

//             return port;

//         } catch (err) {

//         }
//     }

//     throw new Error("PostgreSQL not reachable on 5432 or 5433");
// }
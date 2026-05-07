const dns = require("dns");

function isOnline() {
    return new Promise((resolve) => {
        dns.lookup("google.com", (err) => {
            resolve(!err);
        });
    });
}

// async function logActivity(client_id, action, status = "SUCCESS") {
//     const sheets = google.sheets({ version: "v4", auth });

//     await sheets.spreadsheets.values.append({
//         spreadsheetId: SHEET_ID,
//         range: "Logs!A:D",
//         requestBody: {
//             values: [[
//                 client_id,
//                 action,
//                 status,
//                 new Date().toISOString()
//             ]]
//         }
//     });
// }

module.exports = { isOnline };
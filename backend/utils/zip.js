const archiver = require("archiver");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const ALGORITHM = "aes-256-cbc";
const SECRET = process.env.BACKUP_SECRET || "my_super_secret_key";
const isCompiled = typeof process.pkg !== "undefined";
const baseDir = isCompiled ? path.dirname(process.execPath) : path.join(__dirname, "..");

function getKey() {
    return crypto.createHash("sha256").update(SECRET).digest();
}

function zipAndEncrypt(inputFile, backupStem) {
    return new Promise((resolve, reject) => {
        try {
            const stem = backupStem || path.basename(inputFile, path.extname(inputFile));
            const zipFile = path.join(baseDir, "backups", `${stem}.zip`);
            const encFile = path.join(baseDir, "backups", `${stem}.enc`);

            const output = fs.createWriteStream(zipFile);
            const archive = archiver("zip", { zlib: { level: 9 } });

            archive.on("error", reject);
            output.on("error", reject);
            output.on("close", () => {
                try {
                    const key = getKey();
                    const iv = crypto.randomBytes(16);
                    const cipher = crypto.createCipheriv(ALGORITHM, key, iv);

                    const input = fs.createReadStream(zipFile);
                    const out = fs.createWriteStream(encFile);

                    out.on("error", reject);
                    input.on("error", reject);

                    out.write(iv);

                    input
                        .pipe(cipher)
                        .pipe(out)
                        .on("finish", () => {
                            console.log("🔐 Backup encrypted successfully");
                            fs.unlink(zipFile, () => { });
                            resolve(encFile);
                        })
                        .on("error", reject);
                } catch (err) {
                    reject(err);
                }
            });

            archive.pipe(output);
            archive.file(inputFile, { name: "backup.sql" });
            archive.finalize();
        } catch (err) {
            reject(err);
        }
    });
}

module.exports = { zipAndEncrypt };


// const archiver = require("archiver");
// const fs = require("fs");
// const path = require("path");

// function zipAndEncrypt(inputFile) {
//     return new Promise((resolve, reject) => {
//         try {
//             const zipFile = path.join(__dirname, "../backup.zip");

//             const output = fs.createWriteStream(zipFile);
//             const archive = archiver("zip", { zlib: { level: 9 } });

//             console.log("📦 Creating ZIP backup...");

//             output.on("close", () => {
//                 console.log(`✅ ZIP created (${archive.pointer()} bytes)`);

//                 // 🧹 optional: delete .sql file after zip
//                 fs.unlink(inputFile, () => { });

//                 resolve(zipFile);
//             });

//             archive.on("error", (err) => reject(err));

//             archive.pipe(output);

//             archive.file(inputFile, { name: "backup.sql" });

//             archive.finalize();

//         } catch (err) {
//             reject(err);
//         }
//     });
// }

// module.exports = { zipAndEncrypt };
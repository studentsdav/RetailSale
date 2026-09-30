const archiver = require("archiver");
import crypto from "crypto";
import fs from "fs";
import path from "path";

const ALGORITHM = "aes-256-cbc";
const SECRET = process.env.BACKUP_SECRET || "my_super_secret_key";
const isCompiled = typeof (process as any).pkg !== "undefined";
const baseDir = isCompiled ? path.dirname(process.execPath) : path.join(__dirname, "..");

function getKey(): Buffer {
    return crypto.createHash("sha256").update(SECRET).digest();
}

export function zipAndEncrypt(inputFile: string, backupStem?: string): Promise<string> {
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

export default { zipAndEncrypt };

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");

const ALGORITHM = "aes-256-cbc";
const SECRET = process.env.BACKUP_SECRET || "my_super_secret_key";

function getKey() {
    return crypto.createHash("sha256").update(SECRET).digest();
}

/**
 * Reads the prepended IV, decrypts the file, and extracts the ZIP
 */
function decryptAndUnzip(encFilePath, zipFilePath, extractDir = path.dirname(zipFilePath)) {
    return new Promise((resolve, reject) => {
        console.log("[DECRYPT] Initiating backup decryption sequence...");

        const key = getKey();
        fs.mkdirSync(extractDir, { recursive: true });

        // 1. Safely extract exactly 16 bytes for the IV before streaming
        let fd;
        let iv = Buffer.alloc(16);
        try {
            fd = fs.openSync(encFilePath, 'r');
            const bytesRead = fs.readSync(fd, iv, 0, 16, 0);
            fs.closeSync(fd);

            if (bytesRead !== 16) {
                return reject(new Error("File is too small or corrupted; missing 16-byte IV."));
            }
        } catch (err) {
            if (fd !== undefined) {
                try { fs.closeSync(fd); } catch (e) { }
            }
            return reject(new Error(`Failed to read IV from backup: ${err.message}`));
        }

        // 2. Initialize the Decipher with the key and extracted IV
        const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);

        // 3. Create streams, strictly starting at byte 16 (skipping the IV)
        const readStream = fs.createReadStream(encFilePath, { start: 16 });
        const writeStream = fs.createWriteStream(zipFilePath);

        // Catch individual stream errors to prevent unhandled process crashes
        readStream.on("error", (err) => reject(new Error(`Read stream error: ${err.message}`)));
        writeStream.on("error", (err) => reject(new Error(`Write stream error: ${err.message}`)));
        decipher.on("error", (err) => reject(new Error(`Decryption failed (Corrupt file): ${err.message}`)));

        readStream
            .pipe(decipher)
            .pipe(writeStream)
            .on("finish", () => {
                console.log("[DECRYPT] Payload decrypted to ZIP successfully.");
                console.log("[DECRYPT] Extracting archive contents...");

                const extract = spawn("tar", ["-xf", zipFilePath, "-C", extractDir]);
                let errorOutput = "";

                extract.stderr.on("data", (data) => {
                    errorOutput += data.toString();
                });

                extract.on("error", (err) => {
                    reject(new Error(`Failed to spawn tar extraction process: ${err.message}`));
                });

                extract.on("close", (code) => {
                    if (code === 0) {
                        console.log("[DECRYPT] SQL payload extracted successfully.");
                        resolve(path.join(extractDir, "backup.sql"));
                    } else {
                        reject(new Error(`Archive extraction failed (Exit Code ${code}). Details: ${errorOutput.trim()}`));
                    }
                });
            });
    });
}

module.exports = { decryptAndUnzip };

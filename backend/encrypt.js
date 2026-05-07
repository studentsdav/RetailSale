const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const rootDir = process.pkg ? path.dirname(process.execPath) : process.cwd();

const SECRET = "INTERNAL_SECRET";

function encryptConfig(inputFile, outputFile) {

    const data = fs.readFileSync(inputFile);

    const key = crypto.createHash("sha256").update(SECRET).digest();
    const iv = Buffer.alloc(16, 0);

    const cipher = crypto.createCipheriv("aes-256-cbc", key, iv);

    let encrypted = cipher.update(data);
    encrypted = Buffer.concat([encrypted, cipher.final()]);

    fs.writeFileSync(outputFile, encrypted);

    console.log("Config encrypted successfully.");
}

const input = path.join(rootDir, "config.json");
const output = path.join(rootDir, "config.enc");

encryptConfig(input, output);
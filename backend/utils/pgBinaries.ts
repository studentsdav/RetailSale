import fsSync from "fs";
import path from "path";
import { execSync } from "child_process";

export function findPostgresBinary(binaryName: string): string {
    const exeName = process.platform === "win32" ? `${binaryName}.exe` : binaryName;

    // 1. Try finding in system PATH
    try {
        const cmd = process.platform === "win32" ? `where.exe ${exeName}` : `which ${binaryName}`;
        const output = execSync(cmd, { stdio: ["pipe", "pipe", "ignore"], encoding: "utf8" });
        const firstLine = output.split(/\r?\n/)[0]?.trim();
        if (firstLine && fsSync.existsSync(firstLine)) {
            return firstLine;
        }
    } catch (_) {}

    // 2. Try known Windows Program Files directories for versions 20 down to 10
    if (process.platform === "win32") {
        const basePaths = [
            process.env.ProgramFiles || "C:\\Program Files",
            process.env["ProgramFiles(x86)"] || "C:\\Program Files (x86)",
            "C:\\PostgreSQL",
            "D:\\PostgreSQL"
        ];

        for (let ver = 20; ver >= 10; ver--) {
            for (const base of basePaths) {
                const candidate = path.join(base, "PostgreSQL", String(ver), "bin", exeName);
                if (fsSync.existsSync(candidate)) {
                    return candidate;
                }
            }
        }
    }

    // 3. Fallback to binary name
    return binaryName;
}

export default { findPostgresBinary };

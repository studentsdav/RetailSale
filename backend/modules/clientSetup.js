const os = require("os");
const fs = require("fs");
const path = require("path");
const { v4: uuidv4 } = require("uuid");

const { startBackupJob } = require("../jobs/backupJob");
const { upsertClient, createClientFolder } = require("./driveService");
const { uploadSystemConfigs } = require("./updownconfig");
const { getSyncState, updateSyncState } = require("../utils/syncTracker");
const { getBackupStatus } = require("../utils/backupTracker");
const rootDir = process.pkg ? path.dirname(process.execPath) : process.cwd();

const CLIENT_FILE = path.join(rootDir, "client.json");
const DATA_DIR = path.dirname(CLIENT_FILE);
const LOG_FILE = path.join(rootDir, "init_process.log");




function logToFile(message, isError = false) {
    const timestamp = new Date().toISOString();
    const logPrefix = isError ? "[ERROR]" : "[INFO]";
    const formattedMessage = `${timestamp} ${logPrefix} ${message}\n`;


    if (isError) {
        console.error(formattedMessage.trim());
    } else {
        console.log(formattedMessage.trim());
    }


    try {
        fs.appendFileSync(LOG_FILE, formattedMessage);
    } catch (err) {
        console.error(`Failed to write to log file: ${err.message}`);
    }
}

// Use a Set to track running backup jobs per outlet to prevent duplicate executions
const activeBackupJobs = new Set();

async function initClient(config, outlet) {

    if (!fs.existsSync(DATA_DIR)) {
        fs.mkdirSync(DATA_DIR, { recursive: true });
    }

    let clients = [];
    let needsSave = false;

    // 1. Load and parse the client file as an array
    try {
        if (fs.existsSync(CLIENT_FILE)) {
            const fileData = fs.readFileSync(CLIENT_FILE, "utf8");
            clients = JSON.parse(fileData);

            // Migrate legacy single-object configurations to an array format
            if (!Array.isArray(clients)) {
                clients = [clients];
                needsSave = true;
            }
        } else {
            needsSave = true;
        }
    } catch (err) {
        logToFile("[INIT] Invalid client.json format. Reinitializing file.", true);
        clients = [];
        needsSave = true;
    }

    // 2. Identify or create the specific client configuration
    let clientIndex = clients.findIndex(c => c.outlet_code === outlet.outlet_code);
    let client = clientIndex >= 0 ? clients[clientIndex] : null;

    if (!client) {
        client = {
            client_id: uuidv4(),
            folderId: null,
            outlet_code: outlet.outlet_code,
            outlet_id: outlet.id,
            property_name: outlet.outlet_name,
            machine_id: os.hostname(),
            db_name: config.db_database,
            created_at: new Date().toISOString(),
            status: "ACTIVE",
            expiry_date: "",
            contact_email: outlet.contact_email || "",
            contact_phone: outlet.contact_phone || "",
            tax_id: outlet.tax_id || "",
            pin: outlet.recovery_pin_hash || "",
        };
        clients.push(client);
        clientIndex = clients.length - 1;
        needsSave = true;
    }


    // Fetch synchronization state specific to this outlet
    // Note: Ensure your syncTracker.js is updated to accept the outlet_code as a parameter
    const syncState = getSyncState(client.outlet_code);

    // 3. Task: Create Cloud Directory
    if (!syncState.folder_created || !client.folderId) {
        try {
            logToFile(`[INIT] Creating cloud directory for outlet: ${client.outlet_code}`);
            const newFolderId = await createClientFolder(client.outlet_code);

            if (newFolderId) {
                client.folderId = newFolderId;
                clients[clientIndex] = client;
                updateSyncState(client.outlet_code, 'folder_created', true);

                fs.writeFileSync(CLIENT_FILE, JSON.stringify(clients, null, 2));
                needsSave = false;

                logToFile(`[INIT] Directory allocated. ID: ${client.folderId}`);
            }
        } catch (err) {
            logToFile(`[INIT] Directory creation failed: ${err.message}`, true);
            client.folderId = null;
        }
    }

    // 4. Task: Initialize Backup Scheduler
    if (client.folderId && !syncState.backup_synced) {
        if (!activeBackupJobs.has(client.outlet_code)) {
            try {
                activeBackupJobs.add(client.outlet_code);
                updateSyncState(client.outlet_code, 'backup_synced', true);

                startBackupJob(client, config);
                logToFile(`[INIT] Backup scheduler activated for outlet: ${client.outlet_code}`);
            } catch (err) {
                logToFile(`[INIT] Backup scheduler failed: ${err.message}`, true);
                activeBackupJobs.delete(client.outlet_code);
            }
        }
    }

    // 5. Task: Synchronize Cloud Ledger (Sheets)
    if (!syncState.sheet_synced) {
        try {
            logToFile(`[INIT] Synchronizing ledger for outlet: ${client.outlet_code}`);
            await upsertClient(client);
            updateSyncState(client.outlet_code, 'sheet_synced', true);
        } catch (err) {
            logToFile(`[INIT] Ledger synchronization failed: ${err.message}`, true);
        }
    }


    if (!syncState.config_synced && client.folderId) {
        try {

            const cloudbackupStatus = await getBackupStatus(client.outlet_code);

            if (cloudbackupStatus.isCloudEnabled) {
                console.log(cloudbackupStatus.isCloudEnabled);
                logToFile(`[INIT] Uploading system configurations for outlet: ${client.outlet_code}`);
                await uploadSystemConfigs(client.folderId);
                updateSyncState(client.outlet_code, 'config_synced', true);
            }

        } catch (err) {
            logToFile(`[INIT] Configuration upload failed: ${err.message}`, true);
        }
    }

    if (needsSave) {
        try {
            fs.writeFileSync(CLIENT_FILE, JSON.stringify(clients, null, 2));
            logToFile(`[INIT] Local configuration updated successfully.`);
        } catch (err) {
            logToFile(`[INIT] Failed to persist local configuration: ${err.message}`, true);
        }
    }

    return client;
}

module.exports = { initClient };
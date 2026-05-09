# Config and Sync Files Guide

This guide explains these files:

- `server_config.json`
- `backend/sync_status.json`
- `backend/client.json`
- `backend/backup_status.json`

## 1. `server_config.json`

Purpose:

- Controls which backend URL this terminal uses.
- Controls which outlet codes are available on this terminal.

Current example:

```json
{"baseUrl":"http://127.0.0.1:3000","outlets":["OUTLET202604212159"]}
```

Fields:

- `baseUrl`: backend API base URL.
- `outlets`: outlet code list mapped to this machine.

When to update:

- Backend server IP/port changed.
- Terminal should access different/additional outlets.

## 2. `backend/sync_status.json`

Purpose:

- Tracks cloud sync progress per outlet.

Current example:

```json
{
  "OUTLET202604212159": {
    "folder_created": true,
    "sheet_synced": true,
    "config_synced": true,
    "file_created": false,
    "backup_synced": true
  }
}
```

Meaning of keys:

- `folder_created`: Drive folder created for outlet.
- `sheet_synced`: client row synced to Google Sheet.
- `config_synced`: config payload synced.
- `file_created`: local marker state.
- `backup_synced`: backup upload completed.

Note:

- This is a runtime status file. Usually do not edit manually.

## 3. `backend/client.json`

Purpose:

- Stores per-outlet local runtime identity and cloud mapping.

Typical fields:

- `client_id`
- `folderId` (Google Drive folder id)
- `outlet_code`
- `outlet_id`
- `property_name`
- `machine_id`
- `db_name`
- `created_at`
- `status`
- `expiry_date`
- `contact_email`
- `contact_phone`
- `tax_id`
- `pin` (hashed recovery pin value)

Important:

- Keep valid JSON array format.
- Do not remove `folderId` for active cloud-synced outlets.
- Treat file as sensitive operational data.

## 4. `backend/backup_status.json`

Purpose:

- Stores cloud backup enable flag and latest successful sync timestamp per outlet.

Current example:

```json
{
  "undefined": {
    "lastSyncTime": null,
    "isCloudEnabled": true
  },
  "OUTLET202604212159": {
    "lastSyncTime": 1778160608614,
    "isCloudEnabled": true
  }
}
```

Fields:

- `lastSyncTime`: epoch milliseconds of last successful cloud sync.
- `isCloudEnabled`: true/false cloud backup toggle.

Operational note:

- If you see `undefined` key, it means one backup status update happened without a resolved outlet code. Prefer fixing outlet mapping flow instead of manual file edits.

## 5. Safe Handling Rules

1. Take a backup copy before any manual edit.
2. Stop backend before editing runtime JSON files.
3. Validate JSON syntax after edit.
4. Restart backend and verify `/health`.
5. Run a test sync and check file updates.

## 6. Which File to Use for What

1. Change server endpoint or terminal outlets:
   - Edit `server_config.json`
2. Check cloud sync progress:
   - Read `backend/sync_status.json`
3. Verify outlet-cloud mapping and client identity:
   - Read `backend/client.json`
4. Check last backup sync time and cloud toggle:
   - Read `backend/backup_status.json`

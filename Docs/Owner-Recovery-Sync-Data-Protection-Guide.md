# Owner Recovery, Sync, and Data Protection Guide

This guide is separate from Windows installation and focuses on daily operations, recovery, and data safety for owners/admins.

## 1. Software Installation Guide (Operations View)

Use this order when setting up a new machine:

1. Install the main software package (`Inventory_Installer.exe` / `backend_Installer.exe` as provided by your team).
2. Start the application and complete outlet setup.
3. Verify backend is reachable (`http://127.0.0.1:3000/health`).
4. Confirm cloud settings are active (`sysConfig.enc` in install folder).
5. Run one test backup/sync and verify success status.

Important:

- This guide does not replace packaging/build instructions. For build pipeline and `.iss` scripts, use Windows installer developer guide.

## 2. Username Recovery Guide

Use when user forgot username.

Required:

- Correct `outletCode`
- Registered outlet contact email

Flow:

1. User enters outlet code + email.
2. System validates outlet and exact email match.
3. System finds all active usernames under that outlet.
4. System emails the username list to registered email.

If recovery fails:

- Check outlet is active.
- Check registered contact email exists.
- Ensure entered email exactly matches saved email.

## 3. Outlet Recovery Guide

Use when owner forgot outlet code.

Required:

- Registered email or phone linked to outlet

Flow:

1. User requests recovery with contact (email/phone).
2. System queries cloud records for matching active outlets.
3. OTP is sent to registered email.
4. After OTP verification, outlet list is returned and also emailed.

Security behavior:

- OTP expires in 10 minutes.
- Resend cooldown is enforced (about 3 minutes).

## 4. Forgot Password Guide

Use when user knows username but forgot password.

Required:

- `outletCode`
- `username`
- Access to registered outlet email inbox

Flow:

1. Request password reset OTP.
2. System validates outlet + username and sends OTP email.
3. Enter OTP + new password.
4. System hashes password and updates user record.
5. User logs in with new password.

Rules:

- OTP valid for 10 minutes.
- OTP request cooldown is enforced (about 2 minutes).
- New password minimum length is 8 characters.

## 5. Last Data Sync Guide

Use when owner wants latest data on this machine before starting work or recovery.

Typical cases:

- Machine restored/reinstalled
- Internet outage ended
- Before accounting close
- Before full recovery

How to run:

1. Login with authorized user.
2. Run sync from recovery/settings flow.
3. Wait for completion message.
4. Confirm latest sync timestamp/status.

Why latest sync is useful for owner:

- Reduces risk of working on old data.
- Pulls most recent cloud backup state.
- Improves confidence before billing/reporting.
- Helps avoid data mismatch across terminals.

## 6. Where Data Is Stored

Local machine:

- App/runtime folder contains:
  - `server.exe`, `run_hidden.vbs`, `license.key`, `sysConfig.enc`, `config.enc`, `client.json`
- Local backup folder:
  - `backups\backup_*.enc`
- Backup status metadata:
  - `backup_status.json`
- Recovery OTP store:
  - `data\otp_store.json`

Cloud:

- Google Drive client folder(s) contain encrypted backup and config payloads.
- Google Sheet (`Clients`, `Update`) stores outlet identity, status, and update metadata.

## 7. How Backups Are Protected

Current protections in system:

1. Backups are encrypted archives (`.enc`) before retention/upload.
2. Raw SQL dump is deleted after encryption step.
3. Backup file integrity is verified before final retention/upload.
4. Cloud cleanup keeps only latest backups in cloud script logic.
5. Local retention cleanup removes older backups based on policy.
6. OTP verification gates sensitive recovery operations.
7. Recovery PIN hash is validated for outlet-level restore.

## 8. Owner Best Practices for Data Safety

1. Keep at least one admin who regularly verifies backup success.
2. Test full restore on a non-production machine every month.
3. Keep outlet contact email/phone updated and accessible.
4. Restrict who can perform recovery actions.
5. Protect Google account used for script and drive (2FA recommended).
6. Never share `sysConfig.enc`, `config.enc`, or recovery credentials over chat.
7. Before major changes, confirm latest sync completed successfully.

## 9. Where This Logic Exists in Code

Username + password recovery:

- `backend\modules\passwordRecoveryController.js`
- `backend\modules\emailService.js`

Outlet recovery + full recovery + OTP flows:

- `backend\controllers\public\recoveryController.js`
- `installer\scriptgoogle.txt`

Cloud sync and backup:

- `backend\modules\driveService.js`
- `backend\modules\sheetService.js`
- `backend\modules\updownconfig.js`
- `backend\modules\restore.js`
- `backend\modules\backupService.js`
- `backend\jobs\backupJob.js`
- `backend\utils\backupTracker.js`

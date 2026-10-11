# 🐘 PostgreSQL Complete Removal & Clean Reinstall Guide (Windows)

This document explains how to completely remove PostgreSQL from a Windows system, including all Windows services, registry keys, data directories, and system user accounts.

> [!CAUTION]
> **Data Loss Warning**: This process permanently deletes all PostgreSQL databases, clusters, tables, and users. It cannot be undone. Ensure you have backed up any necessary data before proceeding.

---

## 📑 Table of Contents
1. [When is Complete Removal Required?](#1-when-is-complete-removal-required)
2. [Prerequisites](#2-prerequisites)
3. [Step-by-Step Removal Instructions](#3-step-by-step-removal-instructions)
4. [Inno Setup Automated Uninstallation Script](#4-inno-setup-automated-uninstallation-script)
5. [Production Best Practices](#5-production-best-practices)
6. [Summary Checklist](#6-summary-checklist)

---

## 1. When is Complete Removal Required?

- Resetting or recovering a lost PostgreSQL superuser (`postgres`) password when normal reset methods fail.
- Resolving corrupted database clusters or broken initializations (`initdb` failures).
- Performing a clean bare-metal reinstall for testing or deployment packaging.

---

## 2. Prerequisites

- Windows Administrator access.
- Close all client applications using PostgreSQL (Retail POS, pgAdmin, Node.js server).

---

## 3. Step-by-Step Removal Instructions

### Step 1: Stop the PostgreSQL Windows Service
Open Command Prompt or PowerShell as **Administrator**:
```cmd
net stop postgresql-x64-18
```
*(If running PostgreSQL 14, 15, or 16, replace `18` with your installed version number, e.g. `net stop postgresql-x64-16`)*

To check the exact service name:
```cmd
sc query type= service | findstr /I postgres
```

### Step 2: Delete the PostgreSQL Service
```cmd
sc delete postgresql-x64-18
```

### Step 3: Uninstall via Control Panel
1. Open **Control Panel** $\rightarrow$ **Programs and Features** (or Windows Settings $\rightarrow$ Installed Apps).
2. Uninstall:
   - **PostgreSQL 18** (or installed version)
   - **pgAdmin 4** (optional)

### Step 4: Delete the Installation Directory
```cmd
rmdir /s /q "C:\Program Files\PostgreSQL\18"
```

### Step 5: Delete the Data Directory (Critical)
The data directory holds all database records, users, and passwords. Purging this directory is essential for a clean reinstall:
```cmd
rmdir /s /q "C:\Program Files\PostgreSQL\18\data"
```
Or if configured in `ProgramData`:
```cmd
rmdir /s /q "C:\ProgramData\PostgreSQL"
```

### Step 6: Remove the PostgreSQL Windows User (Optional)
```cmd
net user postgres /delete
```

### Step 7: Clean Windows Registry Keys (Optional)
```cmd
reg delete HKLM\SOFTWARE\PostgreSQL /f
reg delete HKCU\SOFTWARE\PostgreSQL /f
```

### Step 8: Verify Complete Removal
Verify that:
1. No PostgreSQL service appears in `services.msc`.
2. Neither `C:\Program Files\PostgreSQL` nor `C:\ProgramData\PostgreSQL` exist on disk.

### Step 9: Clean Reinstall
1. Run the PostgreSQL installer again.
2. Set your new superuser password (e.g. `postgres`).
3. Specify port `5432`.
4. A clean database cluster is initialized.

---

## 4. Inno Setup Automated Uninstallation Script

For automated installer cleanups in Inno Setup (`.iss` scripts):

```pascal
procedure RemovePostgres();
var
  ResultCode: Integer;
begin
  Exec('cmd.exe', '/c net stop postgresql-x64-18', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('cmd.exe', '/c sc delete postgresql-x64-18', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('cmd.exe', '/c rmdir /s /q "C:\Program Files\PostgreSQL\18"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('cmd.exe', '/c rmdir /s /q "C:\ProgramData\PostgreSQL"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;
```

---

## 5. Production Best Practices

In a live production store environment, avoid complete PostgreSQL removals:
- Install PostgreSQL once as a system prerequisite.
- Create isolated databases per outlet or tenant instead of wiping the cluster.
- Use application-scoped database users with restricted permissions.
- Maintain regular automated encrypted database dumps (`pg_dump`).

---

## 6. Summary Checklist

| Component | Action Required | Command / Location |
| :--- | :--- | :--- |
| **Service** | Stop + Delete | `net stop postgresql-x64-18` & `sc delete postgresql-x64-18` |
| **Program Files** | Delete Folder | `rmdir /s /q "C:\Program Files\PostgreSQL\18"` |
| **Data Directory** | Delete Cluster (Critical) | `rmdir /s /q "C:\Program Files\PostgreSQL\18\data"` |
| **System User** | Optional Delete | `net user postgres /delete` |
| **Registry** | Optional Delete | `reg delete HKLM\SOFTWARE\PostgreSQL /f` |

---

*Document Source: `Docs/PostgreSQL-Complete-Removal-Guide.md` | Verified Native Markdown for GitHub*

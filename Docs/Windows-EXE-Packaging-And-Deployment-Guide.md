# 🪟 Node.js Backend to Windows EXE Compilation & Packaging Guide

This technical guide details the complete procedure for packaging the Node.js Express backend into a standalone Windows executable (`server.exe`). This obscures the source code, prevents end-user modification, and allows the POS system to run offline on local Windows hardware.

---

## 📑 Table of Contents
1. [Why Compile to a Windows EXE?](#1-why-compile-to-a-windows-exe)
2. [Project Structure Overview](#2-project-structure-overview)
3. [Installing Compilation Tools (`pkg`)](#3-installing-compilation-tools-pkg)
4. [Source Code Obfuscation Pipeline](#4-source-code-obfuscation-pipeline)
5. [Compiling the Backend to `server.exe`](#5-compiling-the-backend-to-serverexe)
6. [Resolving Common Compilation & Native Module Errors](#6-resolving-common-compilation--native-module-errors)
7. [Offline POS Desktop Deployment & Startup Script](#7-offline-pos-desktop-deployment--startup-script)

---

## 1. Why Compile to a Windows EXE?

Packaging the Node.js backend into a native Windows executable (`.exe`) ensures:
- **Intellectual Property Protection**: Backend TypeScript and JavaScript logic is compiled into binary bytecode; raw source code is hidden.
- **Tamper Resistance**: Retail cashiers and store operators cannot accidentally delete or alter backend controllers, pricing calculations, or tax logic.
- **Zero-Dependency Runtime**: The terminal PC does not require a pre-installed Node.js runtime or `npm` command line.
- **Fully Offline Operations**: The local Flutter desktop application communicates directly with `localhost:3000` without requiring an active internet connection.

---

## 2. Project Structure Overview

```text
pms_backend/
├── controllers/       # Business logic controllers
├── routes/            # Express route groups
├── models/            # Sequelize database models
├── services/          # Tax, print, and AI service helpers
├── server.js          # Main HTTP server entrypoint
├── package.json       # Dependencies & pkg asset declarations
└── node_modules/      # Installed vendor libraries
```

---

## 3. Installing Compilation Tools (`pkg`)

Install `pkg` globally to compile Node.js projects into executables:
```bash
npm install -g pkg
```

Ensure all runtime dependencies are installed:
```bash
npm install
```

---

## 4. Source Code Obfuscation Pipeline (Optional but Recommended)

Before packaging into an EXE, you can obfuscate JavaScript files to transform variables and control flows into unreadable code:

```bash
npm install -g javascript-obfuscator
```

Execute obfuscation excluding `node_modules`:
```bash
javascript-obfuscator . --output dist --exclude node_modules --compact true --control-flow-flattening true
```
This generates the obfuscated source bundle inside `dist/`.

---

## 5. Compiling the Backend to `server.exe`

### 1. Configure Asset Bundling in `package.json`:
Because Sequelize and database drivers load files dynamically, declare them in the `pkg` section of `package.json`:

```json
{
  "name": "retail-backend",
  "version": "1.0.0",
  "bin": "dist/server.js",
  "pkg": {
    "scripts": "dist/**/*.js",
    "assets": [
      "node_modules/pg/**/*",
      "node_modules/pg-hstore/**/*"
    ],
    "targets": [
      "node18-win-x64"
    ]
  }
}
```

### 2. Execute the Build:
```bash
pkg dist/server.js --targets node18-win-x64 --output server.exe
```
This produces `server.exe` ready for Windows execution.

---

## 6. Resolving Common Compilation & Native Module Errors

### Error 1: Native C++ Module Failure (`bcrypt`)
* **Error**: `No native build was found for platform win32`
* **Cause**: `bcrypt` relies on platform-specific C++ binaries that cannot be easily embedded into a portable Node.js executable.
* **Fix**: Replace `bcrypt` with pure JavaScript `bcryptjs`:
  ```bash
  npm uninstall bcrypt
  npm install bcryptjs
  ```
  In source code:
  ```javascript
  const bcrypt = require("bcryptjs");
  ```

### Error 2: Sequelize Cannot Find PostgreSQL Driver
* **Error**: `Please install pg package manually`
* **Cause**: Sequelize uses dynamic `require()` calls to resolve database dialect drivers, which static compilers cannot automatically trace.
* **Fix**: Explicitly import `pg` and `pg-hstore` in `server.js`:
  ```javascript
  require("pg");
  require("pg-hstore");
  ```

### Error 3: Flutter Client Shows "Server Not Running"
* **Error**: `Connection refused: localhost:3000`
* **Cause**: The server was bound to `127.0.0.1` or blocked by Windows Defender Firewall.
* **Fix**: Ensure the server listens on `0.0.0.0`:
  ```javascript
  app.listen(3000, "0.0.0.0", () => {
    console.log("Server running on port 3000");
  });
  ```
  Verify active listening port:
  ```cmd
  netstat -ano | findstr :3000
  ```

---

## 7. Offline POS Desktop Deployment & Startup Script

### Production Directory Layout:
```text
RetailPOS/
├── RetailSale.exe          # Flutter Windows desktop UI
├── server.exe              # Compiled Node.js backend
├── server_config.json      # Local API connection config
└── start.bat               # Automated startup script
```

### Launcher Script (`start.bat`):
Create a launcher batch script to ensure the backend launches before the Flutter client:

```bat
@echo off
echo Starting Retail POS Backend Service...
start /b "" server.exe

echo Waiting for backend API to initialize...
timeout /t 3 /nobreak > nul

echo Launching Retail POS Application...
start "" RetailSale.exe
exit
```

---

*Document Source: `Docs/Windows-EXE-Packaging-And-Deployment-Guide.md` | Verified Native Markdown for GitHub*

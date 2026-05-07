# Init Setup Guide

This guide covers the first-time setup and initialization flow for the project.

## What You Need

- Flutter SDK
- Node.js `18+`
- npm
- PostgreSQL
- Git

## Required Files

Make sure these files exist in `backend/` before starting the server:

- `license.key`
- `config.enc`
- `sysConfig.enc`
- `client.json`

If these files are missing, the backend may boot in recovery mode or fail health checks.

## First-Time Setup

1. Clone the repository.
2. Install Flutter packages:

```bash
flutter pub get
```

3. Install backend packages:

```bash
cd backend
npm install
```

4. Start PostgreSQL.
5. Start the backend:

```bash
cd backend
npm start
```

6. Start the Flutter app:

```bash
flutter run
```

## Initialization Flow

When the backend starts, it generally:

1. Loads `.env` from `backend/.env` if present.
2. Checks license validity.
3. Loads encrypted config.
4. Waits for PostgreSQL.
5. Ensures the database exists.
6. Runs migrations.
7. Syncs Sequelize models.
8. Starts background jobs.
9. Mounts the API routes.

## Client Configuration

The Flutter client reads `server_config.json` from the current working directory.

Example:

```json
{
  "baseUrl": "http://127.0.0.1:3000",
  "outlets": ["OUTLET202604212159"]
}
```

Default backend URL:

```text
http://127.0.0.1:3000
```

## Health Check

Use this endpoint to confirm the backend is running and healthy:

- `GET /health`

## Recovery Notes

The project includes recovery and setup endpoints under `/api/public` for:

- OTP verification
- setup recovery
- config recovery
- reinstall triggering
- password recovery

## After Setup

Once the server is running and the client can connect, users can log in and begin normal operations.


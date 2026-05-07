# Developer Guide

This project has two main layers:

- Flutter client in `lib/`
- Node.js + Express API in `backend/`

## Prerequisites

- Flutter SDK compatible with Dart `>=3.4.0`
- Node.js `18+`
- npm
- PostgreSQL
- Git

## Setup

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

4. Make sure these backend files exist:

- `backend/license.key`
- `backend/config.enc`
- `backend/sysConfig.enc`
- `backend/client.json`

5. Start PostgreSQL.
6. Start the backend:

```bash
cd backend
npm start
```

7. Run the Flutter app:

```bash
flutter run
```

## Local Development Notes

- The backend listens on port `3000` by default.
- The client defaults to `http://127.0.0.1:3000`.
- `server_config.json` can override the backend URL and outlet list.

## Suggested Workflow

- Keep API changes in sync with controller and route updates
- Update docs when setup or behavior changes
- Avoid committing local secrets or machine-specific files


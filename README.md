# Retail Store Management System

Flutter client + Node.js backend for inventory, sales, purchase orders, receiving, suppliers, finance, reporting, and recovery workflows.

## Documentation

- [Developer Guide](./Docs/Developer-Guide.md)
- [User Guide](./Docs/User-Guide.md)
- [Frontend Guide](./Docs/Frontend-Guide.md)
- [Backend Guide](./Docs/Backend-Guide.md)
- [Endpoint Reference](./Docs/Endpoint-Reference.md)
- [Init Setup Guide](./Docs/Init-Setup.md)

## Quick Start

1. Install Flutter dependencies with `flutter pub get`.
2. Install backend dependencies with `cd backend && npm install`.
3. Start PostgreSQL and confirm the backend config files are present.
4. Run the backend with `cd backend && npm start`.
5. Run the Flutter app with `flutter run`.

## Default API URL

The Flutter app reads its backend URL from `server_config.json`.

Default:

```text
http://127.0.0.1:3000
```

## Project Layout

- `lib/` - Flutter app
- `backend/` - Express API server
- `Docs/` - documentation files
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/` - platform targets

## Screenshots

### Dashboard

![Retail Inventory Dashboard](./assets/Screenshot%202026-05-07%20171632.png)

### Sales Screen

![Sales screen](./assets/Screenshot%202026-05-07%20171711.png)

### Stock Balance Report

![Stock balance report](./assets/Screenshot%202026-05-07%20171814.png)

### Finance and Reports

![Finance and reports screen](./assets/Screenshot%202026-05-07%20171846.png)


## Contributing

Please update the relevant guide when setup, runtime behavior, or APIs change.

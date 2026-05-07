# Frontend Guide

This document describes the Flutter client.

## Main Files

- `lib/main.dart` - app bootstrap
- `lib/core/config/app_config.dart` - backend URL and outlet config
- `lib/screens/` - UI screens
- `lib/controllers/` - state and business logic

## App Startup Flow

1. Flutter bindings are initialized.
2. Notifications are initialized.
3. `AppConfig` loads `server_config.json`.
4. Providers are registered.
5. The splash screen is shown first.

## Backend Connection

The app uses this default API base URL:

```text
http://127.0.0.1:3000
```

Override it by creating `server_config.json` in the working directory:

```json
{
  "baseUrl": "http://127.0.0.1:3000",
  "outlets": ["OUTLET202604212159"]
}
```

## Frontend Dependencies

Key packages used by the app include:

- `provider`
- `http`
- `shared_preferences`
- `file_picker`
- `printing`
- `open_file`
- `flutter_local_notifications`
- `package_info_plus`

## Notes for UI Changes

- Keep controllers and screens in sync when adding new features
- Check app config loading if the API connection changes
- Test on the target platform you are changing


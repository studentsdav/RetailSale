# Backend Guide

This document describes the Node.js API server in `backend/`.

## Stack

- Express
- Sequelize
- PostgreSQL
- CORS
- JSON Web Tokens
- cron jobs
- file-based config and recovery utilities

## Startup

Run the backend from the `backend/` folder:

```bash
npm start
```

The server starts from `backend/server.js` and listens on port `3000` by default.

## Important Runtime Files

- `license.key`
- `config.enc`
- `sysConfig.enc`
- `client.json`
- `uploads/`

## Health Check

- `GET /health`

This endpoint verifies license state, configuration availability, and database connectivity.

## API Groups

All routes are mounted under `/api`.

- `/api/auth`
- `/api/public`
- `/api/inventory`
- `/api/purchase-orders`
- `/api/receiving`
- `/api/suppliers`
- `/api/sales`
- `/api/analytics`
- `/api/users`
- `/api/reports`
- `/api/finance`
- `/api/notifications`

## Operational Notes

- Uploaded files are served from `/uploads`
- API rate limiting is enabled under `/api`
- Background jobs handle backups, loyalty expiry, and analytics refresh
- Database initialization runs on startup when config files are available

## API Reference

See the dedicated [Endpoint Reference](./Endpoint-Reference.md) for the exact endpoint list.

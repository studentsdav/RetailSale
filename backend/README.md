# RetailSale Community Chat Backend & Migrations

This folder provides the complete, production-ready backend for the **RetailSale Business Community & Regional Chat System**, supporting both **JavaScript (Node.js)** and **TypeScript (Node.js + Prisma)**.

---

## 📁 Directory Structure

```
backend/
├── migrations/
│   └── 001_create_community_chat_tables.sql  # SQL schema for PostgreSQL / MySQL
├── js/                                       # JavaScript (Node.js + Express + pg + Socket.IO)
│   ├── config/
│   │   └── db.js                             # Database connection pool
│   ├── controllers/
│   │   └── communityController.js            # Business logic (2-hour limit, mentions, delete-for-me)
│   ├── routes/
│   │   └── communityRoutes.js                # Express routing
│   ├── package.json
│   ├── server.js                             # Entry point with HTTP & Socket.IO
│   └── .env.example
├── ts/                                       # TypeScript (Express + Prisma + Socket.IO)
│   ├── prisma/
│   │   └── schema.prisma                     # Prisma schema models & relations
│   ├── src/
│   │   ├── community/
│   │   │   ├── community.types.ts            # DTOs & Interfaces
│   │   │   ├── community.service.ts          # Core service layer
│   │   │   ├── community.controller.ts       # Express route handlers
│   │   │   └── community.routes.ts           # Router definition
│   │   └── server.ts                         # Entry point with HTTP & Socket.IO
│   ├── tsconfig.json
│   ├── package.json
│   └── .env.example
└── README.md
```

---

## 🗄️ Step 1: Run Database Migrations

Run the SQL script on your PostgreSQL or MySQL database:

```bash
psql -U postgres -d retailsale_db -f migrations/001_create_community_chat_tables.sql
```

---

## 🚀 Step 2: Running the JavaScript Backend

```bash
cd backend/js
npm install
cp .env.example .env
npm run dev
```

* **Server URL**: `http://localhost:4000`
* **Health Check**: `GET http://localhost:4000/health`

---

## ⚡ Step 3: Running the TypeScript Backend

```bash
cd backend/ts
npm install
cp .env.example .env
npm run prisma:generate
npm run dev
```

---

## 📡 REST API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/community/conversations?city=Dehradun&merchant_id=...` | List regional channels & direct conversations |
| `GET` | `/api/community/messages?conversation_id=...&merchant_id=...` | Get conversation messages (filtered for user) |
| `POST` | `/api/community/messages` | Send a new message with `@mentions` |
| `POST` | `/api/community/messages/delete-for-everyone` | Delete within strict 2-hour window |
| `POST` | `/api/community/messages/delete-for-me` | Hide message locally anytime |

# Contributing to RetailSale (FAMALTH LYNX Ecosystem)

Thank you for your interest in contributing to **RetailSale**! We welcome contributions from developers of all skill levels. Whether you are fixing a bug, improving documentation, adding new features, or optimizing performance, your help is appreciated.

---

## 📜 Table of Contents

1. [Code of Conduct](#-code-of-conduct)
2. [How Can I Contribute?](#-how-can-i-contribute)
3. [Development Workflow](#-development-workflow)
4. [Environment Setup & Requirements](#-environment-setup--requirements)
5. [Code Standards & Conventions](#-code-standards--conventions)
6. [Database Schema & Migrations](#-database-schema--migrations)
7. [Submitting a Pull Request (PR)](#-submitting-a-pull-request-pr)
8. [Reporting Security Vulnerabilities](#-reporting-security-vulnerabilities)

---

## 🤝 Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](./CODE_OF_CONDUCT.md). Please read it to understand our community standards and expectations for respectful interaction.

---

## 💡 How Can I Contribute?

- **Report Bugs**: Submit a detailed issue using our [Bug Report Template](.github/ISSUE_TEMPLATE/bug_report.md).
- **Suggest Features**: Submit feature requests using our [Feature Request Template](.github/ISSUE_TEMPLATE/feature_request.md).
- **Fix Issues**: Look for issues tagged with `good first issue` or `help wanted`.
- **Improve Documentation**: Help clarify guides, installation steps, and API references in the `Docs/` directory.

---

## 🔄 Development Workflow

We follow standard GitHub Flow:

1. **Fork the Repository**: Create a personal fork of `studentsdav/RetailSale`.
2. **Clone your Fork**:
   ```bash
   git clone https://github.com/YOUR-USERNAME/RetailSale.git
   cd RetailSale
   ```
3. **Create a Topic Branch**: Branch off from `main` using descriptive names:
   - `feature/add-receipt-discount-ui`
   - `fix/pos-cart-total-calculation`
   - `docs/update-backend-endpoints`
4. **Make Changes & Commit**: Write clean, concise commit messages following standard conventions (`feat: ...`, `fix: ...`, `docs: ...`).
5. **Push to Your Fork**:
   ```bash
   git push origin feature/your-feature-name
   ```
6. **Open a Pull Request**: Submit a PR to the upstream `main` branch with a filled-out PR template.

---

## 💻 Environment Setup & Requirements

### Minimum Software Requirements

| Technology | Minimum Version | Recommended |
| :--- | :--- | :--- |
| **Flutter SDK** | `>=3.4.0 <4.0.0` | Latest Stable |
| **Node.js** | `v18 LTS` | `v20 LTS` |
| **PostgreSQL** | `14+` | `16+` |
| **Git** | `2.30+` | Latest |

### Local Project Setup

1. **Flutter Dependencies**:
   ```bash
   flutter pub get
   ```
2. **Backend Dependencies**:
   ```bash
   cd backend
   npm install
   ```
3. **Configuration**:
   - Verify local configuration files (`server_config.json`, `backend/config.enc`, `backend/license.key`).
   - For backend initialization details, see [Docs/Developer-Guide.md](./Docs/Developer-Guide.md).

---

## 📏 Code Standards & Conventions

### Flutter / Dart Guidelines

- Run static code analysis locally before committing:
  ```bash
  flutter analyze
  ```
  All PRs must pass with **0 errors and 0 warnings**.
- Follow **Effective Dart** styling rules:
  - Use `camelCase` for variables and functions.
  - Use `PascalCase` for classes and widgets.
  - Use `snake_case` for file names.
- Keep widget sub-trees modular and separated into dedicated component files under `lib/`.

### Node.js / Express Backend Guidelines

- **Async / Await**: Use `async/await` for asynchronous code and wrap asynchronous handlers with clean error-handling middleware.
- **SQL Parameterization**: **ALWAYS** use parameterized queries when executing PostgreSQL SQL queries via `pg` or Sequelize to prevent SQL Injection:
  ```javascript
  // GOOD:
  const result = await db.query('SELECT * FROM users WHERE id = $1', [userId]);

  // BAD (DO NOT DO THIS):
  const result = await db.query(`SELECT * FROM users WHERE id = '${userId}'`);
  ```
- Keep routes concise in `backend/routes/` and delegate core business logic to `backend/controllers/`.

---

## 🗄️ Database Schema & Migrations

- Do **NOT** modify existing historical database structure files directly.
- Add new, sequential SQL migration scripts under `backend/migrations/` (e.g., `001_add_discount_columns.sql`) or document schema updates clearly in PR descriptions.
- Ensure all new columns have default values or explicit NULL/NOT NULL constraints so existing production deployments do not break.

---

## 📋 Submitting a Pull Request (PR)

Before submitting your Pull Request, verify the following checklist:

1. Ran `flutter analyze` and fixed all warnings and errors.
2. Verified local Node.js backend syntax and API endpoint execution.
3. Tested desktop/mobile build functionality on your platform (Windows/Web/Mobile).
4. Provided screenshots or screen recordings for any visual UI changes in Flutter.
5. Linked the relevant GitHub issue in the PR description (e.g., `Fixes #42`).

---

## 🔒 Reporting Security Vulnerabilities

If you discover a security vulnerability, please **DO NOT** open a public issue. Review our [Security Policy](./SECURITY.md) for instructions on confidential disclosure.

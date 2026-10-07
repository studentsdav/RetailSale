# ðŸ”Œ Developer Guide: Plugins, Workflows & Automation Architecture

This technical document details the plugin sandboxing framework, event-driven workflow automation engine, WhatsApp BullMQ queue worker, and developer ecosystem API key architecture.

---

## ðŸ—ï¸ System Architecture Overview

```text
Extensibility & Automation Layer
â”œâ”€â”€ ðŸ§© Plugin Marketplace & Sandboxed Execution Engine (`/api/v1/plugins`)
â”œâ”€â”€ âš¡ Event-Driven Workflow Automation Engine (`/api/v1/workflows`)
â”œâ”€â”€ ðŸ“± WhatsApp Cloud API & Async BullMQ Queue (`/api/whatsapp`)
â””â”€â”€ ðŸ”‘ Developer API Token & Outbound Webhook Subsystem (`/api/v1/developer`)
```

---

## ðŸ§© Plugin Marketplace & Sandbox Lifecycle

The plugin subsystem (`backend/services/plugin_manager.service.ts`) enables third-party developers to extend the POS with custom integrations (payment gateways, accounting exports, loyalty providers):

### 1. Plugin Manifest Schema (`manifest.json`)
```json
{
  "id": "com.famalth.tally-export",
  "name": "Tally XML Exporter",
  "version": "1.2.0",
  "author": "Famalth Developer Network",
  "entry": "dist/index.js",
  "permissions": ["READ_SALES", "READ_PURCHASE", "WRITE_EXPORT"],
  "hooks": ["ON_SALE_COMPLETED", "ON_DAY_CLOSE"]
}
```

### 2. Sandbox Execution & Security Isolation
- Plugins execute inside isolated Node.js `VM2` or isolated worker threads.
- Direct filesystem access, network sockets to unauthorized IPs, and raw database connections are strictly blocked.
- Plugins access system resources only via the authenticated `PluginSDK` bridge.

---

## âš¡ Event-Driven Workflow Automation Engine

The workflow engine executes user-defined **Trigger âž” Condition âž” Action** rules:

```mermaid
flowchart LR
    A["Event Trigger (e.g., Low Stock, Sale > $500)"] --> B["Evaluate Rule Conditions"]
    B -- Condition Met --> C{"Action Router"}
    C --> D["Send WhatsApp Alert"]
    C --> E["Draft Auto PO"]
    C --> F["Trigger Webhook to External CRM"]
    C --> G["Apply VIP Customer Tag"]
```

### Supported Triggers:
- `EVENT_SALE_COMPLETED`: Fired after a sale is committed.
- `EVENT_STOCK_BELOW_MIN`: Fired when an item reaches reorder level.
- `EVENT_NIGHT_AUDIT_COMPLETED`: Fired at end of day closing.
- `EVENT_NEW_CUSTOMER_REGISTERED`: Fired on new CRM signup.

---

## ðŸ“± WhatsApp Cloud API & Async BullMQ Queue

Transactional messages (e-invoices, POs, OTPs, promotional campaigns) are dispatched asynchronously to guarantee sub-millisecond POS checkout without waiting for HTTP network calls:

```mermaid
sequenceDiagram
    participant POS as POS Billing Screen
    participant API as WhatsApp Controller
    participant Redis as BullMQ Redis Queue
    participant Worker as Background Queue Worker
    participant Meta as Meta WhatsApp Cloud API
    
    POS->>API: Sale Done -> Send E-Receipt to Customer
    API->>Redis: Enqueue Job SEND_WHATSAPP_INVOICE (Priority: HIGH)
    API-->>POS: HTTP 200 OK (Job Enqueued, Checkout completes instantly)
    
    loop Worker Loop
        Redis->>Worker: Dequeue Job
        Worker->>Meta: POST https://graph.facebook.com/v18.0/...
        Meta-->>Worker: HTTP 200 OK (Message ID)
        Worker->>Worker: Log Status: DELIVERED in whatsapp_logs
    end
```

---

## ðŸ”‘ Developer Ecosystem: API Keys & Webhooks

External systems (custom eCommerce websites, ERPs, mobile apps) can integrate using scoped Developer API Keys:

### 1. Registering Webhooks
`POST /api/v1/developer/webhooks`
```json
{
  "target_url": "https://my-store.com/api/webhooks/pos-events",
  "events": ["sale.created", "inventory.updated", "customer.created"],
  "secret_token": "whsec_9938482018384029"
}
```

### 2. HMAC-SHA256 Webhook Verification
Every outgoing webhook payload includes an `X-Famalth-Signature` header computed as:
$$\text{Signature} = \text{HMAC-SHA256}(\text{payload\_json}, \text{secret\_token})$$
Receiving servers can verify this signature to guarantee authenticity.

---

## ðŸ“¡ REST API Endpoint Specifications

- `GET /api/v1/plugins/marketplace` â€” Fetch available plugin directory.
- `POST /api/v1/plugins/install` â€” Download and register plugin sandbox.
- `POST /api/v1/plugins/:id/toggle` â€” Enable or disable installed plugin.
- `GET /api/v1/workflows/rules` â€” List configured automation rules.
- `POST /api/v1/workflows/rules/:id/toggle` â€” Activate/deactivate rule.
- `POST /api/v1/workflows/trigger` â€” Emit event into workflow pipeline.
- `GET /api/whatsapp/config` â€” Retrieve WhatsApp API setup.
- `POST /api/whatsapp/config` â€” Update Meta Cloud API tokens & phone number ID.
- `GET /api/v1/developer/api-keys` â€” List generated developer integration keys.
- `POST /api/v1/developer/api-keys` â€” Generate new scoped developer API key.

---

*Document Source: `Docs/Developer-Guide-Plugins-Workflows-Automation.md`*

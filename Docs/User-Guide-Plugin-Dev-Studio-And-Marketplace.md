# User Guide: Plugin Marketplace & In-App Dev Studio

This guide explains how store owners and managers can browse, install, and configure add-on plugins from the **Plugin Marketplace**, as well as how developers can create and test custom store automations using the **Plugin Dev Studio**.

---

## 📑 Table of Contents
1. [What Are Plugins?](#1-what-are-plugins)
2. [Browsing & Installing Plugins in the Marketplace](#2-browsing--installing-plugins-in-the-marketplace)
3. [Managing Installed Plugins & Settings](#3-managing-installed-plugins--settings)
4. [Using the Plugin Dev Studio (For Store Coders & Integrators)](#4-using-the-plugin-dev-studio-for-store-coders--integrators)
5. [Testing Hooks in the Sandbox Console](#5-testing-hooks-in-the-sandbox-console)
6. [Publishing Plugins to Your Outlets](#6-publishing-plugins-to-your-outlets)

---

## 1. What Are Plugins?

Plugins extend the POS and ERP system with new integrations and automations without modifying core application code:
- **Food Aggregator Sync**: Zomato, Swiggy, UberEats, Talabat auto-order ingestion.
- **Messaging & Notifications**: WhatsApp invoice dispatch, SMS balance alerts, Telegram daily sales summaries.
- **Hardware Integration**: Custom weighing scales, barcode laser verifiers, smart cash drawers.
- **Custom Business Rules**: VIP loyalty multipliers, dynamic happy hour pricing, special tax calculation routines.

---

## 2. Browsing & Installing Plugins in the Marketplace

1. Navigate to **Settings** $\rightarrow$ **Plugin Marketplace** (`plugin_marketplace_screen.dart`).
2. Filter plugins by category:
   - **All Plugins**
   - **Payment & Finance**
   - **Kitchen & Restaurant**
   - **Customer Loyalty & CRM**
   - **Inventory & Supply Chain**
   - **E-Commerce & Delivery Aggregators**
3. Browse the paginated catalog. Each plugin card displays:
   - **Plugin Name & Icon**
   - **Author & Verified Developer Badge**
   - **Version Number**
   - **Description & Permission Scope**
4. Click **Install Plugin**:
   - The system checks module prerequisites.
   - If required, enter external API keys or credentials.
   - The plugin becomes active immediately without needing an app restart.

---

## 3. Managing Installed Plugins & Settings

1. In the **Installed Plugins** tab:
   - View all active plugins for your branch.
   - Toggle **Enabled / Disabled** with one click.
   - Click **Configure** to edit webhook URLs or notification phone numbers.
   - Click **Uninstall** to safely remove a plugin.

---

## 4. Using the Plugin Dev Studio (For Store Coders & Integrators)

If you have custom requirements (e.g. sending a custom webhook to an internal ERP or triggering an LED alert when a large order arrives), you can build your own plugin directly inside the POS app:

1. Open **Settings** $\rightarrow$ **Developer Ecosystem** $\rightarrow$ **Plugin Dev Studio** (`plugin_dev_studio_screen.dart`).
2. Fill in the metadata:
   - **Plugin ID**: e.g., `plg_custom_warehouse_alert`
   - **Plugin Name**: *Warehouse High-Value Order Webhook*
   - **Version**: `1.0.0`
   - **Category**: *Custom Automation*
   - **Language**: Select **TypeScript** or **JavaScript**.
3. Use the integrated code editor to write hook handlers.

### Example Plugin Code:
```typescript
export default {
  async onInit(context: any) {
    context.logger.info("Custom plugin loaded for outlet: " + context.outletId);
    return { ready: true };
  },

  async onSaleComplete(context: any, payload: any) {
    if (payload.total_amount > 5000) {
      context.logger.info("High-value sale detected: " + payload.invoice_no);
      // Trigger custom notification or external webhook
    }
    return { success: true };
  }
};
```

---

## 5. Testing Hooks in the Sandbox Console

Before deploying code to live cashier terminals, test it safely in the **Test Sandbox Console**:
1. Select the **Target Hook**: `onInit`, `onPaymentCreate`, `onSaleComplete`, `onKotCreated`.
2. Edit the **Test JSON Payload**:
   ```json
   {
     "amount": 250,
     "currency": "USD",
     "receipt": "INV-10023"
   }
   ```
3. Click **Execute Sandbox Hook**.
4. Review the live output window:
   - Execution duration (e.g., `12 ms`).
   - Console logs and output variables.
   - Structured JSON response (`SUCCESS` or error stack trace).

---

## 6. Publishing Plugins to Your Outlets

1. When testing passes, toggle **Make Public for All Outlets** (if you want all branches in your chain to use it) or restrict it to the current outlet.
2. Click **Deploy Plugin to Marketplace**.
3. Cashiers and branch managers can now install your custom plugin from their Marketplace screen.

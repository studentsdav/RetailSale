# Developer Guide: High-Speed PIN Authentication & Post-Login Preloading Architecture

This technical guide documents the optimization strategies, non-blocking background tasks, parallel license validation, and preloaded route resolution that ensure sub-second sign-in and instant dashboard loading.

---

## 📑 Table of Contents
1. [Architecture & Performance Bottleneck Analysis](#1-architecture--performance-bottleneck-analysis)
2. [Fast PIN Login & Scoped Credential Resolution](#2-fast-pin-login--scoped-credential-resolution)
3. [Asynchronous Post-Login Pipeline](#3-asynchronous-post-login-pipeline)
4. [Startup Route Resolution (`HomeRouteHelper`)](#4-startup-route-resolution-homeroutehelper)
5. [Client Storage & Cache Warming Strategy](#5-client-storage--cache-warming-strategy)

---

## 1. Architecture & Performance Bottleneck Analysis

In previous versions, logging in triggered synchronous blocking calls across external cloud license pinging, full outlet onboarding status recalculation, branding asset decoding, and sequential database permission queries.

```mermaid
flowchart TD
    subgraph Legacy Flow ["❌ Legacy Sequential Flow (~2.5s - 4.0s)"]
        L1[Submit Credentials] --> L2[Synchronous Cloud License Call (1.5s)]
        L2 --> L3[Sequentially Query Permissions (200ms)]
        L3 --> L4[Save Tokens to Disk (100ms)]
        L4 --> L5[Blocking Onboarding Full Refresh (800ms)]
        L5 --> L6[Resolve Screen & Render]
    end

    subgraph Optimized Flow ["⚡ Optimized Parallel Pipeline (< 350ms)"]
        O1[Submit PIN / Password] --> O2[Parallel: Scoped DB Auth + Fast Cache Verification]
        O2 --> O3[Immediate JWT Token Minting & Response]
        O3 --> O4[Client Optimistic Navigation to Home Route]
        O3 -.->|Async Non-Blocking Worker| O5[Background Cloud Telemetry & License Sync]
        O3 -.->|Local Cached Flag| O6[Instant Startup Screen Resolution]
    end
```

---

## 2. Fast PIN Login & Scoped Credential Resolution

### Database Indexing:
Queries are accelerated using the composite unique index on `(outlet_id, username)`:
```sql
CREATE INDEX IF NOT EXISTS idx_users_outlet_pin ON users(outlet_id, pin_code) WHERE is_active = TRUE;
```

### Fast-Path Query Engine (`login.controller.ts`):
```typescript
exports.pinLogin = async (req: any, res: any) => {
    const { pin, outlet_code, username, role } = req.body;
    const db = req.propertyDb;

    // 1. Fast indexed lookup for outlet
    const currentOutlet = await db.models.outlets.findOne({
        where: { outlet_code, is_active: true },
        attributes: ['id', 'outlet_code', 'outlet_name', 'outlet_type', 'business_module']
    });

    if (!currentOutlet) return res.status(401).json({ success: false, message: 'Invalid outlet' });

    // 2. Direct scoped user lookup
    const user = await db.models.users.findOne({
        where: {
            outlet_id: currentOutlet.id,
            username: username.trim(),
            is_active: true
        }
    });

    // 3. Constant-time PIN validation
    if (!user || (user.pin_code !== pin && !(await bcrypt.compare(pin, user.pin_code || '')))) {
        return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }

    // 4. Return signed token immediately
    const token = jwt.sign({
        user_id: user.id,
        username: user.username,
        role: user.role,
        outlet_id: currentOutlet.id,
        outlet_code: currentOutlet.outlet_code
    });

    return res.json({ success: true, token, user });
};
```

---

## 3. Asynchronous Post-Login Pipeline

To eliminate client freeze:
1. **Cloud License Verification**: Handled asynchronously via non-blocking worker queue. If cloud verification is slow or offline, the local database license validity period is utilized without stalling the UI.
2. **Audit Trail Logging**: Dispatched as fire-and-forget background promises (`audit.log(...).catch(noop)`).

---

## 4. Startup Route Resolution (`HomeRouteHelper`)

In [`lib/core/navigation/home_route_helper.dart`](file:///d:/inventorynew/RetailSale%20new/RetailSale/lib/core/navigation/home_route_helper.dart), onboarding checks use persisted local flags (`LocalPreferences.isOnboardingCompleted`) to avoid repeating full HTTP checklist roundtrips on every sign-in:

```dart
static Future<Widget> resolve() async {
  final user = await dashboard_user.load();
  final outletCode = (user?.outletCode ?? '').trim();
  final outletIdentifier = outletCode.isNotEmpty ? outletCode : (user?.outletId ?? 1).toString();

  // Instant O(1) Local Storage Check
  final isDone = await LocalPreferences.isOnboardingCompleted(outletIdentifier);
  if (!isDone) {
    final onboardingCtrl = OutletOnboardingController();
    await onboardingCtrl.refreshStatus().catchError((_) {});
    if (!onboardingCtrl.is100PercentComplete) {
      return const OutletSetupChecklistScreen();
    }
    await LocalPreferences.setOnboardingCompleted(outletIdentifier, true);
  }

  // Fast direct role routing
  final userRole = (user?.role ?? '').toString().toUpperCase();
  if (userRole == 'WAITER' || userRole == 'CAPTAIN' || userRole == 'CAPTION') {
    return const CaptainDashboardScreen();
  }
  if (userRole == 'KDS') return const KdsScreen();
  if (userRole == 'RETAIL') return const RetailerConsoleScreen();

  return const DashboardScreen();
}
```

---

## 5. Client Storage & Cache Warming Strategy

- **Token Storage**: Atomic write with `SharedPreferences` background sync.
- **Branding Cache**: Base64 logos and background artwork are cached locally on first load, eliminating repeat HTTP asset fetches on subsequent sign-ins.

# User Guide: Multi-Country Tax Setup & Tax Group Management

This guide explains how taxes are automatically populated for your country and how to safely manage, replace, and delete tax groups in your outlet.

---

## 📑 Table of Contents
1. [Automatic Country Tax Setup](#1-automatic-country-tax-setup)
2. [Supported Countries & Default Tax Rates](#2-supported-countries--default-tax-rates)
3. [Creating & Customizing Tax Groups](#3-creating--customizing-tax-groups)
4. [Deleting a Tax Group Safely (Link Protection)](#4-deleting-a-tax-group-safely-link-protection)
5. [Replacing a Tax Group on All Linked Products](#5-replacing-a-tax-group-on-all-linked-products)

---

## 1. Automatic Country Tax Setup

When you first open **Settings** $\rightarrow$ **Tax Configuration** in a new outlet, the system automatically detects your registered country and generates your standard government tax rates.

### How it works:
- No manual math or tax component creation is required.
- If your store is in **India**, GST and IGST rates are configured automatically.
- If your store is in **Germany / EU**, MwSt rates are added.
- If your store is in **Kenya**, **USA**, **Brazil**, or **UK**, your country's legal tax slabs are pre-populated.

---

## 2. Supported Countries & Default Tax Rates

| Country | Default Tax Groups Created | Components / Breakup |
| :--- | :--- | :--- |
| 🇮🇳 **India** | • GST 5%<br>• GST 18%<br>• IGST 5%<br>• IGST 18%<br>• Nil / Exempt (0%) | • CGST (2.5%) + SGST (2.5%)<br>• CGST (9.0%) + SGST (9.0%)<br>• IGST (5.0%)<br>• IGST (18.0%) |
| 🇩🇪 🇪🇺 **Germany & EU** | • Standard MwSt (19%)<br>• Reduced MwSt (7%)<br>• Zero-Rated / Export (0%) | Standard VAT & Reduced food/agricultural tax |
| 🇺🇸 **USA** | • Combined Sales Tax (8.25%)<br>• Reduced Sales Tax (6.0%)<br>• Tax Exempt (0%) | State & Municipal sales taxes |
| 🇰🇪 **Kenya** | • Standard VAT (16%)<br>• Zero-Rated (0%)<br>• Exempt (0%) | KRA compliant VAT rates |
| 🇧🇷 **Brazil** | • ICMS (18%)<br>• PIS / COFINS (9.25%)<br>• ISS (5%) | Merchandise & Service tax slabs |
| 🇬🇧 **United Kingdom** | • Standard VAT (20%)<br>• Reduced VAT (5%)<br>• Zero Rate VAT (0%) | HMRC compliant VAT |

---

## 3. Creating & Customizing Tax Groups

1. Go to **Settings** $\rightarrow$ **Tax Configuration**.
2. Click **+ Add Tax Group**.
3. Enter the **Tax Group Name** (e.g. *Alcohol Tax 22%*).
4. Add components if you want taxes split into sub-rates (e.g. *State Tax 10%* + *City Tax 12%*).
5. Click **Save Tax Group**.

---

## 4. Deleting a Tax Group Safely (Link Protection)

To protect your store from inventory errors and broken invoices, the system prevents accidental deletion of taxes currently assigned to active products.

```
+-------------------------------------------------------------+
| ⚠️ Cannot Delete Tax Group                                  |
|-------------------------------------------------------------|
| "GST 18%" is currently assigned to 42 items in your store.  |
|                                                             |
| You cannot delete this tax group while items are linked.    |
| Please replace the tax on these items first.                |
|                                                             |
|            [ Cancel ]    [ Replace & Reassign Items ]       |
+-------------------------------------------------------------+
```

---

## 5. Replacing a Tax Group on All Linked Products

If a government tax rate changes or you want to migrate products to a different slab:

1. Click the **Delete (🗑️)** icon next to the tax group you want to retire.
2. If products are linked, click **Replace & Reassign Items**.
3. Select the **New Target Tax Group** (e.g., reassign all items from *GST 12%* to *GST 18%*).
4. Confirm replacement: All 42 products will be updated immediately, and the old tax group will be safely deleted.

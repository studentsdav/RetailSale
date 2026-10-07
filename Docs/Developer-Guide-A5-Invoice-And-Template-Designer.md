# Developer Guide: A5 Invoice Format & Multi-Format Template Designer

This technical guide documents the design, dimension calculations, PDF rendering pipelines, and template configuration models for **A5 Invoice Printing** alongside Thermal 80mm, Thermal 58mm, and A4 formats.

---

## 📑 Table of Contents
1. [Architecture & Document Rendering Pipeline](#1-architecture--document-rendering-pipeline)
2. [Supported Paper Formats & Geometry](#2-supported-paper-formats--geometry)
3. [Database Configuration Model (`system_settings`)](#3-database-configuration-model-system_settings)
4. [PDF Rendering Implementation (`pos_invoice_printer.dart`)](#4-pdf-rendering-implementation-pos_invoice_printerdart)
5. [Preview Dialog Format Dispatcher (`pdf_preview_dialog.dart`)](#5-preview-dialog-format-dispatcher-pdf_preview_dialogdart)
6. [Backend API Endpoints](#6-backend-api-endpoints)

---

## 1. Architecture & Document Rendering Pipeline

```mermaid
flowchart TD
    A[Checkout / Reprint Invoice] --> B[Fetch Outlet Print Settings & Template Configs]
    B --> C{Selected Print Format}
    C -->|THERMAL_80MM| D[Render Roll 80mm ESC/POS or PDF Slip]
    C -->|THERMAL_58MM| E[Render Roll 58mm ESC/POS or PDF Slip]
    C -->|A4| F[Render Full Page A4 PDF (210 x 297 mm)]
    C -->|A5| G[Render Half Page A5 PDF (148 x 210 mm)]
    
    G --> H[Apply A5 Template Configuration: Margins, Headers, Tax Grid, Footers]
    H --> I[Generate Byte Stream via `pdf/pdf.dart` & `pdf/widgets.dart`]
    I --> J[PdfPreviewDialog Preview & Native Windows/Android Spooler Output]
```

---

## 2. Supported Paper Formats & Geometry

| Format Key | Display Name | Standard Dimensions | Typical Use Case |
| :--- | :--- | :--- | :--- |
| `THERMAL_80MM` | Thermal 80mm (3 Inch) | $80\text{ mm} \times \text{Continuous}$ | High-speed retail, restaurant KOT, grocery billing |
| `THERMAL_58MM` | Thermal 58mm (2 Inch) | $58\text{ mm} \times \text{Continuous}$ | Mobile handheld POS, delivery riders, kiosks |
| `A4` | Standard A4 Page | $210\text{ mm} \times 297\text{ mm}$ | B2B tax invoices, wholesale billing, detailed GST invoices |
| `A5` | Compact A5 Page | $148\text{ mm} \times 210\text{ mm}$ | Retail boutiques, clinic bills, half-page laser/inkjet receipts |

### A5 PDF Geometry in Points (72 DPI standard):
$$\text{Width} = 148\text{ mm} \times \frac{72}{25.4} \approx 419.53\text{ pt}$$
$$\text{Height} = 210\text{ mm} \times \frac{72}{25.4} \approx 595.28\text{ pt}$$

---

## 3. Database Configuration Model (`system_settings`)

### Migration Definition:
```sql
ALTER TABLE system_settings 
  ADD COLUMN IF NOT EXISTS a5_template_config JSONB DEFAULT '{
    "header_alignment": "CENTER",
    "show_logo": true,
    "show_tax_breakup": true,
    "show_discount_column": true,
    "show_bank_details": true,
    "show_qr_code": true,
    "primary_color": "#0F766E",
    "font_size_scale": 1.0,
    "footer_note": "Thank you for shopping with us!"
  }'::jsonb;
```

---

## 4. PDF Rendering Implementation (`lib/core/printing/pos_invoice_printer.dart`)

The invoice generator evaluates format configuration to produce vector-crisp documents:

```dart
static Future<Uint8List> generateA5Invoice({
  required SalesHeader sale,
  required List<SalesItem> items,
  required PropertyInfo property,
  required SystemSettings settings,
}) async {
  final pdf = pw.Document();
  final config = settings.a5TemplateConfig;

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(18),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _buildA5Header(property, sale, config),
            pw.SizedBox(height: 8),
            _buildA5ItemTable(items, config),
            pw.SizedBox(height: 8),
            _buildA5TotalsAndTaxBreakup(sale, config),
            pw.Spacer(),
            _buildA5Footer(property, config),
          ],
        );
      },
    ),
  );

  return pdf.save();
}
```

---

## 5. Preview Dialog Format Dispatcher (`lib/core/printing/pdf_preview_dialog.dart`)

When a user selects **A5** in the print dropdown, the preview dialog now directly maps to `PdfPageFormat.a5` and invokes `generateA5Invoice` without defaulting to A4:

```dart
if (selectedFormat == 'A5' || selectedFormat == 'a5') {
  pageFormat = PdfPageFormat.a5;
  pdfData = await PosInvoicePrinter.generateA5Invoice(
    sale: sale,
    items: items,
    property: property,
    settings: settings,
  );
}
```

---

## 6. Backend API Endpoints

- `GET /api/inventory/settings`: Fetches active print configurations including `a5_template_config`.
- `PUT /api/inventory/settings`: Updates visual styling, color accents, and toggle switches for A5 invoice generation.

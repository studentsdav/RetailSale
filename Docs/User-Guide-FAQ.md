# ❓ Store Operator & Cashier Frequently Asked Questions (FAQ)

Welcome to the **Store Operator & Cashier FAQ**. This guide provides simple, step-by-step solutions to common daily questions and challenges encountered while running your retail store or restaurant—**no coding or technical knowledge required!**

---

## 📑 Table of Contents
1. [Billing & POS Counter Questions](#1-billing--pos-counter-questions)
2. [Discounts, Happy Hours & Coupons](#2-discounts-happy-hours--coupons)
3. [Thermal Printer, Barcode Scanner & Hardware](#3-thermal-printer-barcode-scanner--hardware)
4. [Returns, Exchanges & Refunds](#4-returns-exchanges--refunds)
5. [Inventory, Out of Stock & Barcodes](#5-inventory-out-of-stock--barcodes)
6. [Restaurant, KOT & Dining Table Questions](#6-restaurant-kot--dining-table-questions)
7. [Accounting, Cash Drawer & Night Audit](#7-accounting-cash-drawer--night-audit)
8. [Staff, Attendance & Shifts](#8-staff-attendance--shifts)
9. [Offline Mode & Internet Disconnection](#9-offline-mode--internet-disconnection)
10. [Forgot Passwords & Login Troubleshooting](#10-forgot-passwords--login-troubleshooting)

---

## 1. Billing & POS Counter Questions

### Q1: How do I split a payment between Cash and Card / UPI?
1. Scan all customer items into the cart.
2. Click the green **Pay / Settle** button.
3. In the Payment Modal, choose **Split Payment**.
4. Enter the amount paid in **Cash** (e.g., \$50.00).
5. Enter the remaining amount under **Card** or **UPI** (e.g., \$75.00).
6. Click **Confirm & Print Receipt**. The bill will display both payment modes clearly.

### Q2: What should I do if a customer changes their mind before paying?
- **To remove a single item**: Click the 🗑️ **Trash** icon next to that item in the cart.
- **To cancel the entire transaction**: Click the red **Clear / Void Cart** button at the bottom.
- **To hold the cart for another customer**: Click **Hold Cart / Park Bill**. You can serve the next customer and recall the held bill later by clicking **Resume Held Bills**.

### Q3: How do I reprint a receipt for a past customer?
1. Open the left sidebar and go to **Modify > Reprint / Modify Sales Bill**.
2. Search for the bill by **Invoice Number**, **Customer Phone**, or **Date Range**.
3. Select the bill from the list.
4. Click **Reprint Thermal Receipt** (for 3-inch/2-inch roll printer) or **Print Tax Invoice (A4)**.

---

## 2. Discounts, Happy Hours & Coupons

### Q1: Why is the Happy Hour or Bill-Value discount not applying automatically?
1. Check the system clock on your POS computer. Happy hours apply only during configured time windows (e.g., 4:00 PM – 7:00 PM).
2. Ensure the total bill amount meets the minimum threshold (e.g., Minimum spend \$100 for 10% off).
3. Ensure items in the cart are not marked as *'Non-discountable'* in the Item Master.

### Q2: How can I give a manual manager discount on a bill?
1. Add items to the cart.
2. In the bill summary panel, click **Add Discount**.
3. Select either **Percentage (%)** (e.g., 5%) or **Flat Amount** (e.g., \$10.00).
4. If prompted, enter your Manager PIN to authorize the discount.

---

## 3. Thermal Printer, Barcode Scanner & Hardware

### Q1: The thermal printer prints blank receipts or gibberish text. What should I do?
1. **Blank paper**: The thermal paper roll is likely inserted upside-down. Open the printer cover, flip the paper roll over, and close the lid firmly.
2. **Gibberish text**: Go to **Settings > Receipt Template Designer**, verify that the paper width matches your printer (80mm vs 58mm), and click **Test Print**.

### Q2: The barcode scanner is not reading barcodes. How do I fix it?
1. Unplug the USB barcode scanner and plug it into another USB port.
2. Open Notepad on your computer and scan any item barcode.
   - If numbers appear in Notepad, the scanner is working. Click into the **Scan Barcode** box in the POS software before scanning.
   - If no numbers appear in Notepad, the scanner cable may be loose or defective.

### Q3: How do I print barcode price tags for newly arrived items?
1. Go to **Operations > Item Barcode Manager**.
2. Select the items you want to print labels for.
3. Enter the number of stickers needed for each item.
4. Choose your sticker template (e.g., 50mm x 25mm 2-column or A4 24-label sheet).
5. Click **Print Barcode Labels**.

---

## 4. Returns, Exchanges & Refunds

### Q1: How do I process an item return or exchange?
1. Go to **Operations > Return Department Items** (or click **Return Item** on the POS screen).
2. Scan or enter the original **Sales Invoice Number**.
3. Select the specific item(s) being returned and enter the return quantity.
4. Select the return reason (e.g., *Defective*, *Wrong Size*, *Customer Changed Mind*).
5. Choose the refund method:
   - **Cash Refund**: Cash drawer opens to refund cash.
   - **Store Credit / Gift Voucher**: Issues credit balance to customer account.
   - **Exchange**: Adds return value as credit towards new items scanned in POS.
6. Click **Process Return**.

---

## 5. Inventory, Out of Stock & Barcodes

### Q1: The system says an item is out of stock, but I have physical items on the shelf. Can I still sell it?
- If **Negative Stock Billing** is enabled in *Settings > General Preferences*, you can proceed with the sale. The stock will temporarily show negative (e.g., -1).
- Perform a **Stock Adjustment** or complete the pending **Goods Receiving (GRN)** to correct the physical inventory count.

### Q2: How do I create a Purchase Order (PO) to reorder low stock?
1. Go to **Operations > Purchase Order**.
2. Select the **Supplier / Vendor**.
3. Click **Auto-fill Low Stock** to automatically pull all items below minimum stock level.
4. Review quantities and purchase prices.
5. Click **Submit Purchase Order** to save and export as PDF/WhatsApp to the supplier.

---

## 6. Restaurant, KOT & Dining Table Questions

### Q1: How do I transfer an order from Table 4 to Table 8?
1. Open **Restaurant > Running Orders** (or **Floor Plan**).
2. Click on **Table 4**.
3. Click **Transfer Table**.
4. Select **Table 8** from the available tables list and click **Confirm Transfer**. All ordered items and KOTs will move automatically to Table 8.

### Q2: How do I merge Table 2 and Table 3 for a large family?
1. In the **Floor Plan**, select **Table 2**.
2. Click **Merge Tables**.
3. Choose **Table 3** and confirm. Both tables will turn orange/busy, and all food orders will be billed on a single consolidated invoice.

### Q3: A dish is taking too long in the kitchen. How do I check its status?
1. Open **Restaurant > Kitchen Display System (KDS)**.
2. Locate the table or KOT number.
3. Orders color-code automatically:
   - 🟢 **Green**: Under 10 minutes.
   - 🟡 **Yellow**: 10–20 minutes.
   - 🔴 **Red**: Delayed (Over 20 minutes).
4. You can click **Remind Kitchen** to send an urgent ping to the kitchen screen.

---

## 7. Accounting, Cash Drawer & Night Audit

### Q1: How do I record daily petty cash expenses (tea, cleaning, delivery fee)?
1. Go to **Restaurant / Accounting > Expense Entry**.
2. Select the **Expense Category** (e.g., *Office Supplies*, *Refreshments*, *Logistics*).
3. Enter the amount paid and payment method (*Cash Drawer* or *Bank Transfer*).
4. Enter notes/remarks and click **Save Expense**. The cash drawer balance will adjust automatically.

### Q2: How do I perform the Day-End / Night Audit closing?
1. At the end of the shift/day, go to **Reports > Night Audit** (or **Cashier Handover**).
2. Count the physical cash in the cash drawer.
3. Enter the physical cash count in the **Counted Cash** field.
4. The system compares physical cash with expected sales cash and reports any **Overage** or **Shortage**.
5. Click **Execute Day End Closing**. The register is closed, and a summary PDF report is generated for the owner.

---

## 8. Staff, Attendance & Shifts

### Q1: How do employees punch in / punch out for attendance?
1. Go to **HRMS > Attendance**.
2. Enter the employee code or scan employee ID badge.
3. Click **Punch In** when starting work and **Punch Out** when leaving.
4. The system calculates shift hours, late arrivals, and overtime automatically.

### Q2: How do I generate monthly payslips for staff?
1. Go to **HRMS > Payroll**.
2. Select the Month and Year (e.g., *October 2026*).
3. Click **Calculate Payroll**. The system computes basic pay, overtime, allowances, and deductions.
4. Review the calculations and click **Process Payroll & Print Payslips**.

---

## 9. Offline Mode & Internet Disconnection

### Q1: What happens if the internet goes down while billing?
- **The software continues to work normally!**
- You can scan items, accept cash payments, and print thermal receipts without internet.
- When internet connectivity returns, the system automatically synchronizes sales data and cloud backups in the background.

---

## 10. Forgot Passwords & Login Troubleshooting

### Q1: What should I do if a cashier forgets their login password?
1. Have an **Admin / Store Manager** log in.
2. Go to **Masters > User Management**.
3. Select the cashier's account and click **Reset Password**.
4. Set a new temporary password and have the cashier log in and update it.

### Q2: What if the Admin forgets their Master Password?
1. On the login screen, click **Emergency Recovery / Forgot Password**.
2. Enter the registered store **Owner Mobile Number** or **Email**.
3. Enter the 6-digit OTP received via SMS/Email.
4. Create a new Admin password and confirm.

---

*Need additional assistance? Click the **Lynx AI 🤖** button at the top of your dashboard and ask your question in plain English, or check the detailed feature guides in the Docs folder.*

# 🎁 Promotions, Loyalty & Lucky Draw User Guide

This user guide is written for **store managers, marketing leads, and cashiers**. Learn how to drive customer retention and increase store revenue using Happy Hours, Bill-Value Promotions, Tiered Customer Loyalty Points, and Lucky Draw Raffles with zero coding required!

---

## 📑 Table of Contents
1. [Overview & Benefits](#1-overview--benefits)
2. [Happy Hour Automation](#2-happy-hour-automation)
3. [Bill-Value Promotions (Spend \$X, Get \$Y Off)](#3-bill-value-promotions-spend-x-get-y-off)
4. [Customer Loyalty Program & Tiered Points](#4-customer-loyalty-program--tiered-points)
   - [Configuring Points Earning & Redemption](#configuring-points-earning--redemption)
   - [Customer Tier Levels (Silver, Gold, Platinum)](#customer-tier-levels-silver-gold-platinum)
   - [Redeeming Points at POS Counter](#redeeming-points-at-pos-counter)
5. [Lucky Draw & Raffle Campaigns](#5-lucky-draw--raffle-campaigns)
   - [Creating a Lucky Draw Campaign](#creating-a-lucky-draw-campaign)
   - [Automatic Coupon Issuance at POS](#automatic-coupon-issuance-at-pos)
   - [Drawing Certified Winners Live](#drawing-certified-winners-live)
6. [Promotions & Scheme Reports](#6-promotions--scheme-reports)

---

## 1. Overview & Benefits

Drive customer traffic, boost average order value, and build lifelong customer loyalty:

```text
Promotions & Loyalty
├── ⏰ Happy Hour Rules (Time-based automatic discounts)
├── 🏷️ Bill-Value Promos (Tiered basket discounts)
├── 👑 Loyalty Master Config (Points per spend & redemption)
├── 🎟️ Lucky Draw Campaigns (Automated raffle draws)
└── 📊 Scheme & Loyalty Analytics Reports
```

---

## 2. Happy Hour Automation

Boost sales during slow hours (e.g., weekday afternoons from 2:00 PM to 5:00 PM) automatically without cashiers needing to remember promo codes:

### Setting Up a Happy Hour Rule
1. Go to **Settings > Happy Hour Config**.
2. Click **Add Happy Hour Rule ➕**.
3. Configure Rule Parameters:
   - **Rule Name**: e.g., *'Afternoon Beverage Blitz 🍹'*.
   - **Active Days**: Select days of week (e.g., *Monday through Thursday*).
   - **Time Window**: Set Start Time (e.g., `02:00 PM`) and End Time (e.g., `05:00 PM`).
   - **Applicable Categories / Items**: Choose specific category (e.g., *Beverages & Desserts*) or all items.
   - **Discount Type**: Percentage (e.g., `20% Off`) or Flat Amount (e.g., `\$2.00 Off`).
4. Click **Activate Happy Hour**.
5. During POS billing, any qualifying items scanned within the active time window will automatically show discounted pricing with a *Happy Hour* tag!

---

## 3. Bill-Value Promotions (Spend \$X, Get \$Y Off)

Encourage customers to add more items to their cart to reach higher discount thresholds:

### Setting Up Bill Value Tiers
1. Go to **Settings > Bill Value Promo Config**.
2. Click **Create Promotion Tier ➕**.
3. Configure Spend Slabs:
   - **Slab 1**: Spend \$50 to \$99 ➔ Get **5% Off** or **\$5 Flat Discount**.
   - **Slab 2**: Spend \$100 to \$199 ➔ Get **10% Off** or **\$15 Flat Discount**.
   - **Slab 3**: Spend \$200 or more ➔ Get **15% Off** + Free Delivery.
4. Set valid date range (e.g., *Holiday Season Promo from Dec 1 to Jan 5*).
5. Click **Save Promo Slabs**.
6. At the POS counter, the software automatically highlights the next tier: *"Add \$12 more to get 10% Off!"*

---

## 4. Customer Loyalty Program & Tiered Points

Turn one-time shoppers into repeat regular customers with a digital points wallet:

### Configuring Points Earning & Redemption
1. Go to **Settings > Loyalty Master Config** (or **Masters > Loyalty Program**).
2. Set **Earning Rule**: e.g., Every **\$10 spent = 1 Loyalty Point earned**.
3. Set **Redemption Value**: e.g., **1 Loyalty Point = \$0.50 discount** on future bills.
4. Set **Minimum Redemption Threshold**: e.g., Customer must have at least 50 points to redeem.
5. Set **Expiry Policy**: e.g., Points expire after 12 months from issuance.

### Customer Tier Levels (Silver, Gold, Platinum)
| Tier | Annual Spend Target | Earning Multiplier | Special Perks |
| :--- | :--- | :--- | :--- |
| 🥈 **Silver** | Entry Level (\$0 – \$500) | 1x Points | Standard member deals |
| 🥇 **Gold** | \$501 – \$2,000 | 1.5x Points | Free delivery, birthday bonus |
| 💎 **Platinum** | \$2,001+ | 2x Points | Priority service, exclusive VIP events |

### Redeeming Points at POS Counter
1. During checkout, enter or scan the customer's phone number.
2. The customer's available points balance displays on screen (e.g., *'140 Points Available (\$70 Value)'*).
3. Ask the customer: *"Would you like to redeem your points today?"*
4. Click **Redeem Points** and enter the points to use.
5. The bill total is immediately discounted, and remaining points are updated!

---

## 5. Lucky Draw & Raffle Campaigns

Create exciting mega-contests (e.g., *'Shop for \$50 this Festive Season & Win a 55" Smart TV!'*):

### Creating a Lucky Draw Campaign
1. Go to **Reports / Settings > Lucky Draw Campaign Screen**.
2. Click **Create New Campaign 🎟️**.
3. Set Campaign Details:
   - **Campaign Title**: e.g., *'Diwali / New Year Mega Bonanza'*.
   - **Minimum Bill Amount to Qualify**: e.g., \$50.00.
   - **Coupon Calculation**: 1 Ticket per \$50 spent (e.g., \$150 bill = 3 Lucky Draw tickets).
   - **Prizes**: 1st Prize: Smart TV, 2nd Prize: Microwave Oven, 3rd Prize: \$50 Gift Cards (5 winners).
   - **Campaign Duration**: Start Date to Draw Date.
4. Click **Launch Campaign**.

### Automatic Coupon Issuance at POS
- Every customer whose invoice meets the minimum spend receives unique serialized **Lucky Draw Ticket Numbers** printed directly at the bottom of their thermal bill receipt!
- Customer details (Name, Phone, Bill No, Ticket IDs) are securely logged in the campaign database.

### Drawing Certified Winners Live
1. On the draw date, open the **Lucky Draw Campaign Screen**.
2. Connect your POS computer to a big screen/projector if hosting a customer event.
3. Click **Draw Certified Winner 🎲**.
4. The animated raffle selector spins and selects random certified winning ticket numbers with complete cryptographic fairness.
5. Click **Publish Winners & Notify via WhatsApp/SMS** to send congratulatory messages to the winners automatically!

---

## 6. Promotions & Scheme Reports

Analyze the return on investment of all marketing campaigns:
- **Loyalty Report**: Total points issued, redeemed, and customer wallet liabilities.
- **Scheme / Promo Report**: Revenue generated by Happy Hours vs Bill-Value promos.
- **Lucky Draw Analytics**: Total participant count, ticket distribution, and sales lift during the campaign period.

---

*Delight your customers and multiply repeat store visits!*

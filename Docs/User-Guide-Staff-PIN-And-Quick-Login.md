# User Guide: Staff Quick PIN Login & User Dropdown Selector

This guide explains how to set up, configure, and use the **Staff Quick PIN Login** system on both mobile devices (Waiter App) and desktop POS terminals.

---

## 📑 Table of Contents
1. [What is Quick PIN Login?](#1-what-is-quick-pin-login)
2. [Setting Up Staff PINs in User Management](#2-setting-up-staff-pins-in-user-management)
3. [Enabling / Disabling the Quick Login Dropdown](#3-enabling--disabling-the-quick-login-dropdown)
4. [Using Quick PIN on the Waiter / Captain Mobile App](#4-using-quick-pin-on-the-waiter--captain-mobile-app)
5. [Using Quick PIN on the Main POS Login Screen](#5-using-quick-pin-on-the-main-pos-login-screen)
6. [Frequently Asked Questions (FAQ)](#6-frequently-asked-questions-faq)

---

## 1. What is Quick PIN Login?

Quick PIN Login allows restaurant waiters, captains, retail cashiers, and store operators to sign in to their terminals in seconds without typing lengthy passwords.

### Key Benefits:
- **Lightning Fast**: Select your name and tap your 4 to 6 digit PIN.
- **Shared or Custom PINs**: Multiple staff members can use the same convenient store default PIN (e.g. `1234`) or individual private PINs. The system validates the exact staff member selected in the dropdown.
- **Privacy Controls**: Administrators can choose exactly which users appear in the login dropdown and hide sensitive accounts (e.g., Owner, Head Accountant).

---

## 2. Setting Up Staff PINs in User Management

### To Add or Edit a User PIN:
1. Log in as **Admin** or **Manager**.
2. Navigate to **Settings** $\rightarrow$ **User Management** (or press the *User Management* icon on the dashboard).
3. Click **Add User** or click the **Edit (✏️)** button next to an existing staff member.
4. In the dialog, locate the field:
   - **Quick Login PIN (4-6 Digits)**: Enter a numeric PIN (e.g., `1234`, `5678`, `9999`).
5. Save the user.

```
+-------------------------------------------------------------+
| Create / Edit User                                          |
|-------------------------------------------------------------|
| Full Name: Rahul Sharma                                     |
| Username:  waiter_rahul                                     |
| Role:      WAITER                                           |
| Password:  ••••••••                                         |
| Quick PIN: 1234                                             |
| [X] Show in Quick Login Dropdown                            |
|     Staff can pick this username on PIN login screen        |
+-------------------------------------------------------------+
```

---

## 3. Enabling / Disabling the Quick Login Dropdown

In the **Create User** or **Edit User** dialog:
- **Toggle ON [✓] "Show in Quick Login Dropdown"**: The staff member's name and role will appear in the quick picker on the mobile floor app and desktop login screen.
- **Toggle OFF [ ] "Show in Quick Login Dropdown"**: The user will be hidden from the public login screen picker. (They can still log in using the standard **Password** tab by typing their username and password).

---

## 4. Using Quick PIN on the Waiter / Captain Mobile App

On the Waiter / Captain Mobile Console (`waiter_auth_screen.dart`):

1. **Select Role**: Tap **Waiter Floor** or **Captain Console** on the top switch.
2. **Choose Your Name**: Tap the user dropdown at the top. The list shows all active staff in your outlet with their name, `@username`, and role badge.
3. **Enter PIN**: Tap your 4 to 6 digit PIN on the on-screen keypad.
4. **Auto Sign-in**: The system verifies your credentials and immediately opens your active table order screen.

```
+---------------------------------------+
|  🍽️ RetailPOS Floor App              |
|  Captain & Waiter Mobile Console      |
|---------------------------------------|
|  [ Waiter Floor ]  [ Captain Console ]|
|  [ Quick PIN* ]    [ Staff Login ]    |
|---------------------------------------|
|  👤 Rahul Sharma (@waiter_rahul)  [▼] |
|                                       |
|          Enter PIN for Rahul          |
|               ● ● ● ●                 |
|                                       |
|          [ 1 ] [ 2 ] [ 3 ]            |
|          [ 4 ] [ 5 ] [ 6 ]            |
|          [ 7 ] [ 8 ] [ 9 ]            |
|        [CLEAR] [ 0 ] [ ⌫ ]            |
|                                       |
|      [ Login as Rahul Sharma -> ]     |
+---------------------------------------+
```

---

## 5. Using Quick PIN on the Main POS Login Screen

On desktop and tablet POS login screens (`login_screen.dart`):

1. Choose your **Outlet Code** from the top dropdown.
2. Select the **Quick PIN** tab.
3. In the **Select Staff Member / User** dropdown, select your name.
4. Enter your numeric PIN using your physical keyboard or the on-screen numeric keypad.
5. Click **QUICK PIN SIGN IN**.

---

## 6. Frequently Asked Questions (FAQ)

#### Q1: Can 3 different waiters in my restaurant all have the PIN `1234`?
> **Yes!** Because each waiter selects their own name from the dropdown first, the system validates `Outlet + Rahul + 1234` and `Outlet + Anita + 1234` independently without any conflict.

#### Q2: How do I hide the Admin account from the public login dropdown?
> Edit the Admin user in **User Management**, uncheck **"Show in Quick Login Dropdown"**, and save. The Admin account will now only be accessible via the **Password** tab.

#### Q3: What happens if a waiter enters the wrong PIN?
> The system displays an *"Invalid PIN or user not found"* error, clears the PIN dots, and prompts for re-entry. All failed and successful logins are logged in the audit trail.

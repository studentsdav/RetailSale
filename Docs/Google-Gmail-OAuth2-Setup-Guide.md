# 🔑 Google Gmail OAuth2 Setup Guide for Render & Cloud Deployment

This step-by-step guide explains how to set up **Google Gmail OAuth2 authentication** for sending automated emails and OTP verification codes from cloud hosting environments like [Render.com](https://render.com).

---

## 🎯 Why Use Gmail OAuth2 on Render?

1. **Bypasses Port Blocking:** Uses standard HTTPS API tokens over port `443` / `587`, which cloud hosting providers (Render, AWS, DigitalOcean) **never block**.
2. **No Password Lockouts:** Eliminates "Less Secure Apps" errors or random password authentication blocks by Google Security.
3. **High Deliverability:** Direct Google token authentication ensures fast (0.5s) email delivery to recipient inboxes.

---

## 📋 Prerequisites

* A Gmail or Google Workspace account (`yourname@gmail.com`).
* Access to [Google Cloud Console](https://console.cloud.google.com/).
* Access to [Google OAuth2 Playground](https://developers.google.com/oauthplayground).

---

## 🛠️ Step-by-Step Setup Instructions

### Step 1: Create a Google Cloud Project

1. Open the **[Google Cloud Console](https://console.cloud.google.com/)**.
2. Click the project dropdown in the top bar and click **New Project**.
3. Set Project Name: `Retail POS Email Service` -> Click **Create**.

---

### Step 2: Enable the Gmail API

1. In the top search bar of Google Cloud Console, search for **Gmail API**.
2. Click **Gmail API** from the Marketplace / API list.
3. Click **Enable**.

---

### Step 3: Configure the OAuth Consent Screen

1. In the left navigation menu, go to **APIs & Services** → **OAuth consent screen**.
2. Select **External** as the User Type -> Click **Create**.
3. Fill in the required fields:
   * **App Name:** `Retail POS System`
   * **User Support Email:** Your Gmail address
   * **Developer Contact Information:** Your Email address
4. Click **Save and Continue**.
5. **Scopes:** Click **Add or Remove Scopes**:
   * Search for `https://mail.google.com/` (Gmail API full access).
   * Check the box next to `https://mail.google.com/` -> Click **Update**.
6. Click **Save and Continue**.
7. **Test Users:** Click **+ Add Users**:
   * Add your sender Gmail address (`yourname@gmail.com`).
8. Click **Save and Continue**.

---

### Step 4: Create OAuth2 Credentials (Client ID & Client Secret)

1. In the left navigation menu, go to **Credentials**.
2. Click **+ Create Credentials** → **OAuth client ID**.
3. Fill in the details:
   * **Application type:** `Web application`
   * **Name:** `Render Backend Client`
   * **Authorized redirect URIs:** Add exactly:
     ```text
     https://developers.google.com/oauthplayground
     ```
4. Click **Create**.
5. Copy and save your **Client ID** and **Client Secret**:
   * `GMAIL_CLIENT_ID` (e.g., `123456789-xyz.apps.googleusercontent.com`)
   * `GMAIL_CLIENT_SECRET` (e.g., `GOCSPX-your_client_secret`)

---

### Step 5: Generate the Refresh Token via OAuth2 Playground

1. Open the **[Google OAuth 2.0 Playground](https://developers.google.com/oauthplayground)**.
2. Click the ⚙️ **Gear Icon** in the top-right corner.
3. Check the box: **"Use your own OAuth credentials"**.
4. Paste your credentials:
   * **OAuth Client ID:** Paste `GMAIL_CLIENT_ID`
   * **OAuth Client Secret:** Paste `GMAIL_CLIENT_SECRET`
5. On the left sidebar under **Select & authorize APIs**:
   * Scroll down to **Gmail API v1**.
   * Expand it and check `https://mail.google.com/`.
6. Click **Authorize APIs**.
7. Log into your Gmail account and click **Continue / Allow**.
8. You will be redirected back to OAuth Playground. Click **Exchange authorization code for tokens**.
9. Copy your **Refresh Token** (`GMAIL_REFRESH_TOKEN`).

---

## 🚀 Step 6: Add Variables to Render Environment

In your Render Dashboard (or `.env` file), set the following key-value pairs:

```env
EMAIL_PROVIDER=GMAIL
EMAIL_USER=yourname@gmail.com
GMAIL_CLIENT_ID=123456789-xyz.apps.googleusercontent.com
GMAIL_CLIENT_SECRET=GOCSPX-your_client_secret_here
GMAIL_REFRESH_TOKEN=1//04_your_refresh_token_here
```

---

## ✅ Verification & Testing

Once deployed on Render with these environment variables, check your container logs:

```text
🔍 [EMAIL DEBUG] Target: customer@example.com | Provider Mode: GMAIL | User: YES (yourname@gmail.com)
[EMAIL MODE] Sending strictly via Gmail OAuth2 REST API (Port 443) to customer@example.com...
[GMAIL API] Fetching OAuth2 access token for yourname@gmail.com...
[GMAIL API SUCCESS] Sent to customer@example.com: {"id": "191...", "threadId": "191..."}
```

> [!TIP]
> **Why it works so fast (0.2s):** The backend uses Google's official **Gmail REST API over Port 443 (HTTPS)**. It does **not** rely on raw SMTP socket connections, ensuring instant email delivery without any port blocking or socket timeouts on Render.

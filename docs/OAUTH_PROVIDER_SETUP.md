# OAuth Provider Setup Guide

Setup guide for configuring OAuth apps with external providers. These credentials allow Vault to authenticate users on behalf of their connected accounts.

**Redirect URI for all providers**: `{VAULT_URL}/oauth/callback`
- Production: `https://vault.brainzlab.ai/oauth/callback`
- Development: `http://localhost:4006/oauth/callback`

---

## How It Works

1. You (the platform operator) create ONE OAuth app per provider
2. Set the client_id/secret as ENV variables in Vault
3. All tenants/projects share your OAuth app
4. Each tenant's tokens are encrypted separately (AES-256-GCM, per-project key)
5. Enterprise tenants can override with their own OAuth app via project settings (BYOA)

---

## Provider Setup

### 1. Google (Sheets, Gmail, Calendar, Drive)

One app covers all Google products. Same client_id/secret for all.

**Console**: https://console.cloud.google.com

**Steps**:
1. Create or select a project
2. **APIs & Services > Library** — enable required APIs:
   - Google Sheets API
   - Gmail API
   - Google Calendar API
   - Google Drive API
3. **APIs & Services > OAuth consent screen**:
   - User type: External
   - App name: your brand name
   - Add required scopes per API
   - Add authorized domains
4. **APIs & Services > Credentials > + Create Credentials > OAuth client ID**:
   - Application type: Web application
   - Authorized redirect URIs: `{VAULT_URL}/oauth/callback`
5. Copy Client ID and Client Secret

**ENVs** (same values repeated — Activepieces uses separate piece_names):
```bash
VAULT_OAUTH_GOOGLE_SHEETS_CLIENT_ID=xxxx.apps.googleusercontent.com
VAULT_OAUTH_GOOGLE_SHEETS_CLIENT_SECRET=GOCSPX-xxxx
VAULT_OAUTH_GMAIL_CLIENT_ID=xxxx.apps.googleusercontent.com
VAULT_OAUTH_GMAIL_CLIENT_SECRET=GOCSPX-xxxx
VAULT_OAUTH_GOOGLE_CALENDAR_CLIENT_ID=xxxx.apps.googleusercontent.com
VAULT_OAUTH_GOOGLE_CALENDAR_CLIENT_SECRET=GOCSPX-xxxx
VAULT_OAUTH_GOOGLE_DRIVE_CLIENT_ID=xxxx.apps.googleusercontent.com
VAULT_OAUTH_GOOGLE_DRIVE_CLIENT_SECRET=GOCSPX-xxxx
```

**Verification**: Apps in "Testing" mode are limited to 100 users. Submit for verification (2-4 weeks) to go production.

**Scopes reference**:
- Sheets: `https://www.googleapis.com/auth/spreadsheets`
- Gmail: `https://www.googleapis.com/auth/gmail.modify`
- Calendar: `https://www.googleapis.com/auth/calendar`
- Drive: `https://www.googleapis.com/auth/drive`

---

### 2. Slack

**Console**: https://api.slack.com/apps

**Steps**:
1. Create New App > From scratch
2. App Name: your brand name, Workspace: your dev workspace
3. **OAuth & Permissions**:
   - Redirect URLs: `{VAULT_URL}/oauth/callback`
   - Bot Token Scopes: `chat:write`, `channels:read`, `users:read`
   - Add more scopes as needed
4. **Basic Information** > copy Client ID and Client Secret

**ENVs**:
```bash
VAULT_OAUTH_SLACK_CLIENT_ID=xxxx.xxxx
VAULT_OAUTH_SLACK_CLIENT_SECRET=xxxx
```

**Notes**: Slack apps can be distributed publicly via the Slack App Directory. Requires Slack review.

---

### 3. GitHub

**Console**: https://github.com/settings/developers

**Steps**:
1. OAuth Apps > New OAuth App
2. Application name: your brand name
3. Homepage URL: your site
4. Authorization callback URL: `{VAULT_URL}/oauth/callback`
5. Copy Client ID > Generate a new client secret

**ENVs**:
```bash
VAULT_OAUTH_GITHUB_CLIENT_ID=Iv1.xxxx
VAULT_OAUTH_GITHUB_CLIENT_SECRET=xxxx
```

**Notes**: For GitHub Apps (vs OAuth Apps), use https://github.com/settings/apps instead. GitHub Apps have finer permissions.

---

### 4. HubSpot

**Console**: https://developers.hubspot.com

**Steps**:
1. Create developer account
2. Apps > Create app
3. Tab **Auth**:
   - Redirect URL: `{VAULT_URL}/oauth/callback`
   - Scopes: `crm.objects.contacts.read`, `crm.objects.contacts.write`, `crm.objects.deals.read`
4. Copy Client ID and Client Secret from Auth tab

**ENVs**:
```bash
VAULT_OAUTH_HUBSPOT_CLIENT_ID=xxxx
VAULT_OAUTH_HUBSPOT_CLIENT_SECRET=xxxx
```

---

### 5. Microsoft 365 (Outlook, Teams, OneDrive, Excel)

One Azure AD app covers all Microsoft products.

**Console**: https://portal.azure.com

**Steps**:
1. Azure Active Directory > App registrations > New registration
2. Name: your brand name
3. Supported account types: Accounts in any organizational directory and personal Microsoft accounts
4. Redirect URI: Web > `{VAULT_URL}/oauth/callback`
5. **Certificates & secrets > New client secret** > copy Value (not the ID)
6. **API permissions > Add a permission > Microsoft Graph**:
   - `Mail.Read`, `Mail.Send`, `Calendars.ReadWrite`, `Files.ReadWrite`, `User.Read`

**ENVs** (same values — different piece_names):
```bash
VAULT_OAUTH_MICROSOFT_OUTLOOK_CLIENT_ID=xxxx-xxxx-xxxx
VAULT_OAUTH_MICROSOFT_OUTLOOK_CLIENT_SECRET=xxxx
VAULT_OAUTH_MICROSOFT_TEAMS_CLIENT_ID=xxxx-xxxx-xxxx
VAULT_OAUTH_MICROSOFT_TEAMS_CLIENT_SECRET=xxxx
VAULT_OAUTH_MICROSOFT_EXCEL_CLIENT_ID=xxxx-xxxx-xxxx
VAULT_OAUTH_MICROSOFT_EXCEL_CLIENT_SECRET=xxxx
VAULT_OAUTH_MICROSOFT_ONE_DRIVE_CLIENT_ID=xxxx-xxxx-xxxx
VAULT_OAUTH_MICROSOFT_ONE_DRIVE_CLIENT_SECRET=xxxx
```

**Notes**: Microsoft client secrets expire (default 6 months or 2 years). Set a reminder to rotate.

---

### 6. Notion

**Console**: https://www.notion.so/my-integrations

**Steps**:
1. New integration
2. Type: **Public** (required for OAuth; Internal is for API key only)
3. Redirect URIs: `{VAULT_URL}/oauth/callback`
4. Capabilities: Read content, Update content, Insert content
5. Copy OAuth client ID and OAuth client secret

**ENVs**:
```bash
VAULT_OAUTH_NOTION_CLIENT_ID=xxxx
VAULT_OAUTH_NOTION_CLIENT_SECRET=secret_xxxx
```

---

### 7. Salesforce

**Console**: Salesforce Setup (login.salesforce.com)

**Steps**:
1. Setup > App Manager > New Connected App
2. Enable OAuth Settings: checked
3. Callback URL: `{VAULT_URL}/oauth/callback`
4. Selected OAuth Scopes: `api`, `refresh_token`, `offline_access`
5. Copy Consumer Key (= client_id) and Consumer Secret

**ENVs**:
```bash
VAULT_OAUTH_SALESFORCE_CLIENT_ID=xxxx
VAULT_OAUTH_SALESFORCE_CLIENT_SECRET=xxxx
```

**Notes**: Salesforce has sandbox environments. Use `test.salesforce.com` for sandbox OAuth.

---

### 8. Jira / Atlassian

**Console**: https://developer.atlassian.com/console/myapps/

**Steps**:
1. Create > OAuth 2.0 integration
2. Callback URL: `{VAULT_URL}/oauth/callback`
3. Permissions > Jira API: `read:jira-work`, `write:jira-work`
4. Settings > copy Client ID and Secret

**ENVs**:
```bash
VAULT_OAUTH_JIRA_CLOUD_CLIENT_ID=xxxx
VAULT_OAUTH_JIRA_CLOUD_CLIENT_SECRET=xxxx
```

---

### 9. Airtable

**Console**: https://airtable.com/create/oauth

**Steps**:
1. Create new OAuth integration
2. Redirect URLs: `{VAULT_URL}/oauth/callback`
3. Scopes: `data.records:read`, `data.records:write`, `schema.bases:read`
4. Copy Client ID and Client Secret

**ENVs**:
```bash
VAULT_OAUTH_AIRTABLE_CLIENT_ID=xxxx
VAULT_OAUTH_AIRTABLE_CLIENT_SECRET=xxxx
```

---

### 10. Stripe (Connect)

**Console**: https://dashboard.stripe.com/settings/connect

**Steps**:
1. Platform settings > Redirect URIs: `{VAULT_URL}/oauth/callback`
2. Copy platform Client ID (starts with `ca_`)
3. Use your Stripe API secret key as client_secret

**ENVs**:
```bash
VAULT_OAUTH_STRIPE_CLIENT_ID=ca_xxxx
VAULT_OAUTH_STRIPE_CLIENT_SECRET=sk_live_xxxx
```

**Notes**: Most Stripe integrations use API keys, not OAuth. OAuth is for Stripe Connect (multi-merchant platforms).

---

## ENV Naming Convention

The ENV key is derived from the connector's `piece_name`:

```
piece_name.upcase.gsub(/[^A-Z0-9]/, "_")
```

Examples:
| piece_name | ENV prefix |
|---|---|
| `google-sheets` | `VAULT_OAUTH_GOOGLE_SHEETS_` |
| `slack` | `VAULT_OAUTH_SLACK_` |
| `hubspot` | `VAULT_OAUTH_HUBSPOT_` |
| `microsoft-outlook` | `VAULT_OAUTH_MICROSOFT_OUTLOOK_` |
| `jira-cloud` | `VAULT_OAUTH_JIRA_CLOUD_` |

Each provider needs both `_CLIENT_ID` and `_CLIENT_SECRET` suffixes.

---

## Enterprise: Bring Your Own OAuth App

Enterprise tenants can use their own OAuth apps instead of the platform default by creating a Vault secret in their project. No migrations, no extra config — uses Vault's existing secret management.

**How it works**:
1. Tenant creates a secret in their Vault project:
   - Key: `OAUTH_GOOGLE_SHEETS` (pattern: `OAUTH_{CONNECTOR_KEY}`)
   - Type: `credential`
   - Username: their OAuth client_id
   - Password: their OAuth client_secret
   - Environment: production

2. ProviderFactory checks this secret FIRST, then falls back to platform ENV

**Lookup order**:
```
1. Vault secret "OAUTH_{CONNECTOR}" in project  →  enterprise override
2. ENV "VAULT_OAUTH_{CONNECTOR}_CLIENT_ID"       →  platform default
```

**Example via MCP**:
```bash
curl -X POST http://vault:4006/mcp/tools/vault_set_credential \
  -H "Authorization: Bearer $PROJECT_TOKEN" \
  -d '{
    "params": {
      "name": "OAUTH_GOOGLE_SHEETS",
      "username": "their-client-id.apps.googleusercontent.com",
      "password": "GOCSPX-their-secret",
      "environment": "production"
    }
  }'
```

**When the secret exists**: the tenant's own OAuth app is used, tokens go through their app's quota.
**When it doesn't exist**: the platform's ENV credentials are used (default for all tenants).

---

## Priority Matrix

| Priority | Provider | Impact | Setup Difficulty |
|---|---|---|---|
| P0 | Google (Sheets/Gmail/Drive) | Critical | Medium (verification) |
| P0 | Slack | Critical | Low |
| P0 | GitHub | High | Low |
| P1 | HubSpot | High | Low |
| P1 | Microsoft 365 | High | Medium (Azure AD) |
| P1 | Notion | Medium | Low |
| P1 | Jira/Atlassian | High | Low |
| P2 | Salesforce | High (enterprise) | Medium |
| P2 | Airtable | Medium | Low |
| P2 | Stripe Connect | Medium | Low |

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| "Missing VAULT_OAUTH_X_CLIENT_ID" | ENV not set | Add the ENV variable |
| "redirect_uri_mismatch" | Callback URL mismatch | Ensure `{VAULT_URL}/oauth/callback` matches exactly what's in the provider console |
| "invalid_client" | Wrong client_id or secret | Verify credentials in provider console |
| "access_denied" | User declined authorization | Normal — user clicked "Deny" |
| "invalid_scope" | Requested scope not configured | Add the scope in the provider's app settings |
| Tokens expire immediately | Provider returns no refresh_token | Add `offline_access` or `access_type=offline` scope |
| Google "App not verified" | Still in testing mode | Submit for Google verification or add user as test user |
| Microsoft secret expired | Azure secrets have expiry | Rotate in Azure portal, update ENV |

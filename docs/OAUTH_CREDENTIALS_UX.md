# OAuth Credentials UX Guide

Design guide for the OAuth connection experience in Axon + Vault, based on competitive analysis of n8n, Zapier, Make.com, and Pipedream.

---

## Design Principles

1. **Zero-config for the user** — One click, authorize, done. No client IDs, no redirect URIs, no developer consoles.
2. **Popup, not redirect** — Keep the user in context of the Flow Builder. Popup closes on success.
3. **Connections are reusable** — Connect once, use in unlimited flows. Reconnect updates ALL flows automatically.
4. **Status is always visible** — Green = connected, Red = expired, at every level (node, panel, global page).
5. **Private by default** — Only the owner sees and uses the connection. Explicit sharing for teams.

---

## Architecture: Two-Tier Model

Every platform that does this well has the same two-tier architecture:

```
GLOBAL LEVEL                              IN-CONTEXT LEVEL
─────────────                             ────────────────

Connections Page                          Flow Builder Node
(Vault Dashboard)                         (Axon)

┌─────────────────────────────┐          ┌──────────────────────┐
│ Connected Accounts          │          │ Slack                │
│                             │          │                      │
│ Google Sheets  ● Connected  │          │ Account: [dropdown]  │
│   marketing@acme.com        │          │  ● marketing@slack   │
│   Used by: 4 flows          │          │  ● devops@slack      │
│   [Reconnect] [Revoke]      │          │  + Connect new       │
│                             │          │                      │
│ Slack          ● Connected  │          │ Channel: #general    │
│   Acme Workspace            │          │ Message: ...         │
│   Used by: 12 flows         │          └──────────────────────┘
│   [Reconnect] [Revoke]      │
│                             │
│ HubSpot        ● Expired    │
│   ops@acme.com              │
│   [Reauthorize]             │
└─────────────────────────────┘
```

### Tier 1: Global Connections Page (Vault Dashboard)

Centralized management of all OAuth connections for a project.

**Table columns**:
| Column | Description |
|---|---|
| Service | App icon + name (Google Sheets, Slack, etc.) |
| Account Label | Auto-generated from OAuth response (email, workspace name) |
| Status | Green dot "Connected" / Red dot "Expired" / Yellow dot "Refreshing" |
| Flows Using | Count of flows referencing this connection |
| Connected By | User who authorized |
| Last Used | Timestamp of last execution |
| Actions | Reconnect, Test, Revoke |

**Filters**: By status (Active/Expired), by service, by owner.

**Key interactions**:
- **Reconnect**: Opens OAuth popup, refreshes tokens in-place. All flows keep working.
- **Test**: Calls provider API (e.g. `GET /users/me`) to verify credential is valid.
- **Revoke**: Disconnects. Shows warning with count of affected flows.

### Tier 2: In-Context Connection Selector (Axon Flow Builder)

When a user configures a connector node in the Flow Builder.

**States**:

```
No connection exists:
┌──────────────────────────┐
│ Slack                    │
│                          │
│  ┌────────────────────┐  │
│  │ ⚡ Connect Slack   │  │
│  └────────────────────┘  │
│                          │
│  No account connected    │
└──────────────────────────┘

Connection exists:
┌──────────────────────────┐
│ Slack                    │
│                          │
│  Account:                │
│  ┌────────────────────┐  │
│  │ ● Acme Workspace ▾│  │
│  └────────────────────┘  │
│  + Connect another       │
│                          │
│  Channel: [dropdown]     │
│  Message: [textarea]     │
└──────────────────────────┘

Connection expired:
┌──────────────────────────┐
│ Slack                    │
│                          │
│  Account:                │
│  ┌────────────────────┐  │
│  │ ● Acme Workspace ▾│  │
│  └────────────────────┘  │
│  ⚠ Connection expired    │
│  [Reauthorize]           │
└──────────────────────────┘
```

---

## Connection Flow: Step by Step

### Happy Path (OAuth2)

```
1. User adds connector node (e.g. Google Sheets) to flow
2. Config panel shows "Connect Google Sheets" button
3. User clicks button
4. Popup opens: vault.brainzlab.ai/oauth/authorize?...
5. Vault redirects popup to accounts.google.com
6. User selects Google account, grants permissions
7. Google redirects back to vault.brainzlab.ai/oauth/callback
8. Vault exchanges code for tokens, encrypts, stores
9. Popup sends postMessage to Axon: {type: "oauth_complete", connection_id: "..."}
10. Popup closes automatically
11. Axon updates node: dropdown shows "marketing@acme.com ●"
12. Config panel renders the rest of the fields (spreadsheet picker, etc.)
```

**Total user effort**: 2 clicks + select Google account. ~10 seconds.

### API Key Services (non-OAuth)

For services that use API keys (Stripe, SendGrid, OpenAI, etc.):

```
1. User clicks "Connect Stripe" in node config
2. Modal opens (not popup — stays in Axon)
3. Shows single field: "API Key" with a link to "Get your API key →"
4. User pastes key, clicks Save
5. Vault encrypts and stores as ConnectorCredential
6. Modal closes, node shows "Connected ●"
```

### Basic Auth Services

```
1. User clicks "Connect [Service]"
2. Modal shows two fields: Username, Password
3. User fills in, clicks Save & Test
4. Vault tests the credentials, then encrypts and stores
5. Modal shows success or error
```

---

## Connection Labels

Auto-generate meaningful labels from OAuth response data so users can distinguish accounts:

| Provider | Label Source | Example |
|---|---|---|
| Google | email from userinfo | marketing@acme.com |
| Slack | team.name from auth.test | Acme Workspace |
| GitHub | login from /user | @johndoe |
| HubSpot | user email from /oauth/v1/access-tokens | ops@acme.com |
| Microsoft | userPrincipalName from /me | john@acme.onmicrosoft.com |
| Notion | workspace name | Acme's Workspace |
| Salesforce | username from /services/oauth2/userinfo | john@acme.com.sandbox |

**Implementation**: After successful OAuth token exchange, make one API call to the provider's "who am I" endpoint. Store the result in `ConnectorConnection.metadata["account_label"]`.

---

## Status Indicators

Consistent across global page and flow builder:

| Status | Icon | Color | Meaning |
|---|---|---|---|
| Connected | Filled circle | Green `#22c55e` | Tokens valid, ready to use |
| Expired | Filled circle | Red `#ef4444` | Tokens expired, needs reauthorization |
| Refreshing | Spinning circle | Yellow `#eab308` | Token refresh in progress |
| Error | Filled circle | Red `#ef4444` | Auth failed (3+ refresh failures) |
| Not connected | Empty circle | Gray `#9ca3af` | No credential linked |

---

## Reconnection Without Breakage

Critical pattern from Zapier and Make.com: reconnecting updates the credential **in-place**.

```
ConnectorConnection (id: "conn-123")
  └── ConnectorCredential (id: "cred-456")
        └── encrypted tokens ← THESE get replaced

Flows reference "conn-123", NOT the tokens.
Reconnecting replaces tokens inside "cred-456".
All flows using "conn-123" immediately get new tokens.
Zero manual updates needed.
```

This is how our current implementation already works — `create_or_update_credential` in `OauthController` finds existing credential by `(project, connector, auth_type)` and calls `store_oauth_tokens!` to replace tokens.

---

## Competitive Comparison

| Feature | Zapier | n8n | Make | Pipedream | **Axon/Vault** |
|---|---|---|---|---|---|
| One-click OAuth | Yes | Yes (cloud) | Yes | Yes | **Yes** |
| Popup-based | Yes | Yes | Yes | Yes | **Yes** |
| Global connections page | Yes | Yes | Yes | Yes | **Needed** |
| Auto connection labels | Yes | No | No | No | **Planned** |
| Reusable across flows | Yes | Yes | Yes | Yes | **Yes** |
| In-place reconnect | Yes | Yes | Yes | Yes | **Yes** |
| Status indicators | Yes | Limited | Yes | Yes | **Planned** |
| Team sharing | Yes | Yes | Yes | Limited | **Future** |
| BYOA (own OAuth app) | No | Yes (self-host) | No | Yes | **Yes** (Vault secrets) |
| Encrypted at rest | Unknown | Yes | Unknown | Unknown | **Yes** (AES-256-GCM) |
| Auto token refresh | Yes | Yes | Partial | Yes | **Yes** (job + inline) |
| Usage count per connection | Yes | No | No | No | **Yes** (execution_count) |

### Our advantages over competition:
- **BYOA via Vault secrets** — Enterprise can bring own OAuth app without any code changes
- **AES-256-GCM encryption** with per-project keys — strongest credential security
- **Dual refresh strategy** — background job every 5min + inline refresh at execution time
- **Full audit trail** — every credential access logged in Vault's append-only audit log
- **MCP tool access** — AI agents can manage connections programmatically

---

## Implementation Checklist

### Already Built
- [x] OAuth authorize + callback flow (OauthController)
- [x] Token encryption (ConnectorCredential + Encryptor)
- [x] Automatic token refresh (OAuthTokenRefreshJob + inline)
- [x] BYOA via Vault secrets (ProviderFactory)
- [x] Popup postMessage flow
- [x] Connection model (ConnectorConnection with status, metadata)

### Needed for UX Parity

**P0 — Launch**:
- [ ] Connection label auto-generation (API call after OAuth exchange)
- [ ] Status indicators in Axon Flow Builder connector nodes
- [ ] "Connect" button in node config panel that opens Vault popup
- [ ] Connection dropdown in node config when multiple accounts exist

**P1 — Global Management**:
- [ ] Connections page in Vault dashboard (table view with status, label, usage count, actions)
- [ ] Reconnect action (re-runs OAuth flow, updates tokens in-place)
- [ ] Test action (calls provider's /me endpoint)
- [ ] Revoke action with affected flows warning

**P2 — Polish**:
- [ ] Team sharing (share connection with project members)
- [ ] Connection health notifications via Signal
- [ ] Scope display (what permissions were granted)
- [ ] "Last used" tracking on connections page

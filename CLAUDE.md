# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: Vault by Brainz Lab

Secrets management for API keys, credentials, and environment variables with encryption at rest.

**Domain**: vault.brainzlab.ai

**Tagline**: "Secrets, secured"

**Status**: Not yet implemented - see vault-claude-code-prompt.md for full specification

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          VAULT (Rails 8)                         │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │  Dashboard   │  │     API      │  │  MCP Server  │           │
│  │  (Hotwire)   │  │  (JSON API)  │  │   (Ruby)     │           │
│  │ /dashboard/* │  │  /api/v1/*   │  │   /mcp/*     │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│                           │                  │                   │
│                           ▼                  ▼                   │
│              ┌─────────────────────────────────────┐            │
│              │ PostgreSQL (encrypted) + AWS KMS    │            │
│              └─────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
        │
        │ Inject
        ▼
┌───────────────┐
│ Deployments   │
│ Synapse/K8s   │
└───────────────┘
```

## Tech Stack

- **Backend**: Rails 8 API + Dashboard
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS
- **Database**: PostgreSQL (encrypted storage)
- **Encryption**: AES-256-GCM at rest
- **Key Management**: AWS KMS or local master key
- **Cache**: Redis (session, rate limiting)
- **Audit**: Append-only audit log

## Key Models

- **Secret**: Encrypted secret value
- **SecretVersion**: Version history for rollback
- **SecretEnvironment**: Environment-specific values
- **AccessToken**: API tokens for secret access
- **AccessPolicy**: RBAC policies
- **AuditLog**: Who accessed what, when

## Security Features

| Feature | Description |
|---------|-------------|
| **Encryption** | AES-256-GCM at rest |
| **Key Management** | AWS KMS or local |
| **Version History** | Full audit trail |
| **RBAC** | Role-based permissions |
| **Audit Logging** | Append-only access log |
| **Environment Separation** | Prod/Staging/Dev isolation |

## Key Services

- **EncryptionService**: AES-256-GCM encryption/decryption
- **KmsService**: AWS KMS integration
- **AccessControl**: RBAC enforcement
- **AuditLogger**: Immutable audit trail
- **SecretRotation**: Automatic rotation support

## MCP Tools

| Tool | Description |
|------|-------------|
| `vault_get` | Retrieve a secret value |
| `vault_set` | Set/update a secret |
| `vault_list` | List secrets (names only) |
| `vault_history` | Get version history |
| `vault_rotate` | Rotate a secret |

## API Endpoints

- `GET /api/v1/secrets` - List secret names
- `GET /api/v1/secrets/:name` - Get secret value
- `POST /api/v1/secrets` - Create secret
- `PUT /api/v1/secrets/:name` - Update secret
- `GET /api/v1/secrets/:name/versions` - Version history
- `POST /api/v1/secrets/:name/rotate` - Rotate secret
- `GET /api/v1/audit-logs` - Audit log

Authentication: `Authorization: Bearer <key>` or `X-API-Key: <key>`

## Environment Separation

Secrets isolated by environment:
- **Production** - Locked, requires approval
- **Staging** - Team access
- **Development** - Open access

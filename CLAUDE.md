# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: Vault by Brainz Lab

Secrets management for API keys, credentials, and environment variables with encryption at rest.

**Domain**: vault.brainzlab.ai

**Tagline**: "Secrets, secured"

**Status**: Fully implemented

**Port**: 4006 (Docker), 3000 (local dev)

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

- **Secret**: Encrypted secret value with support for credentials and OTP
- **SecretVersion**: Version history for rollback with encrypted values
- **SecretEnvironment**: Environment-specific values (dev/staging/prod)
- **SecretFolder**: Organizational folders for secrets
- **AccessToken**: API tokens for secret access with permissions
- **AccessPolicy**: RBAC policies (principal-based)
- **AuditLog**: Append-only audit trail for all operations
- **EncryptionKey**: Per-project encryption keys (encrypted with master key)
- **ProviderKey**: Encrypted API keys for LLM providers
- **Project**: Multi-tenant project isolation
- **SshClientKey**: Encrypted SSH private keys (identity keys)
- **SshServerKey**: Known host public keys for verification
- **SshConnection**: SSH connection profiles with key references

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

- **Encryption::Encryptor**: AES-256-GCM encryption/decryption (`app/services/encryption/encryptor.rb`)
- **Encryption::KeyManager**: Key rotation and management (`app/services/encryption/key_manager.rb`)
- **Encryption::LocalKeyProvider**: Local master key provider (`app/services/encryption/local_key_provider.rb`)
- **Mcp::Server**: MCP protocol server with all tools (`app/services/mcp/server.rb`)
- **AccessChecker**: RBAC enforcement (`app/services/access_checker.rb`)
- **SecretResolver**: Environment-based secret resolution (`app/services/secret_resolver.rb`)
- **Otp::Generator**: TOTP/HOTP code generation (`app/services/otp/generator.rb`)
- **Otp::Verifier**: OTP verification (`app/services/otp/verifier.rb`)
- **Ssh::KeyGenerator**: Generate RSA/Ed25519 SSH key pairs (`app/services/ssh/key_generator.rb`)
- **Ssh::KeyImporter**: Import and validate existing SSH keys (`app/services/ssh/key_importer.rb`)

## MCP Tools

| Tool | Description |
|------|-------------|
| `vault_list_secrets` | List all secret names in the vault |
| `vault_get_secret` | Retrieve a secret value |
| `vault_set_secret` | Set/update a secret |
| `vault_delete_secret` | Delete a secret |
| `vault_list_environments` | List available environments |
| `vault_get_history` | Get version history for a secret |
| `vault_export` | Export secrets (names only, not values) |
| `vault_import` | Import secrets from JSON |
| `vault_get_credential` | Get credential (username/password) |
| `vault_set_credential` | Set credential with optional OTP |
| `vault_generate_otp` | Generate OTP code for TOTP/HOTP secrets |
| `vault_verify_otp` | Verify an OTP code |
| `vault_ssh_list_client_keys` | List SSH identity keys |
| `vault_ssh_get_client_key` | Get SSH private key (decrypted) |
| `vault_ssh_set_client_key` | Import existing SSH key |
| `vault_ssh_delete_client_key` | Archive/delete SSH key |
| `vault_ssh_generate_key` | Generate new RSA/Ed25519 key pair |
| `vault_ssh_list_server_keys` | List known host keys |
| `vault_ssh_get_server_key` | Get server public key |
| `vault_ssh_set_server_key` | Add/update server key |
| `vault_ssh_delete_server_key` | Archive server key |
| `vault_ssh_list_connections` | List SSH connection profiles |
| `vault_ssh_get_connection` | Get connection with resolved key |
| `vault_ssh_set_connection` | Create/update connection |
| `vault_ssh_delete_connection` | Archive connection |

MCP Endpoint: `POST /mcp/rpc` or `POST /mcp/tools/:name`

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

## Credential & OTP Support

Vault supports storing credentials (username/password) with optional OTP:
- **credential**: Username + password
- **totp**: Time-based OTP (RFC 6238)
- **hotp**: Counter-based OTP (RFC 4226)

OTP configuration fields:
- `otp_algorithm`: sha1, sha256, sha512 (default: sha1)
- `otp_digits`: 6-8 digits (default: 6)
- `otp_period`: TOTP interval in seconds (default: 30)
- `otp_issuer`: Optional issuer name

## Running Locally

```bash
# With Docker (recommended)
cd /Users/afmp/brainz/brainzlab
./bin/brainzlab up vault

# Or manually
cd /Users/afmp/brainz/brainzlab/vault
bundle install
bin/rails db:prepare
bin/rails server -p 3000
```

## Running Tests

```bash
cd /Users/afmp/brainz/brainzlab/vault
bin/rails test
```

## SSH Key Management

Vault provides SSH key and connection management via MCP tools (no dashboard UI):

### Client Keys (Identity Keys)
Store SSH private/public key pairs encrypted at rest:
- **Key Types**: `rsa-2048`, `rsa-4096`, `ed25519`
- **Features**: Key generation, import, passphrase support
- **Encryption**: Private keys encrypted with AES-256-GCM

### Server Keys (Known Hosts)
Store trusted server public keys:
- **Key Types**: `ssh-rsa`, `ssh-ed25519`, `ecdsa-sha2-*`
- **Features**: Fingerprint verification, trust management

### Connection Profiles
Store SSH connection configurations:
- **Fields**: host, port, username, client key reference
- **Features**: Jump host support (ProxyJump), custom SSH options
- **Output**: SSH config format generation

### Example Usage (MCP)
```bash
# Generate a new Ed25519 key
curl -X POST http://localhost:4006/mcp/tools/vault_ssh_generate_key \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"params": {"name": "deploy-key", "key_type": "ed25519"}}'

# Create a connection profile
curl -X POST http://localhost:4006/mcp/tools/vault_ssh_set_connection \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"params": {"name": "prod-server", "host": "prod.example.com", "username": "deploy", "client_key_name": "deploy-key"}}'

# Get connection with decrypted key
curl -X POST http://localhost:4006/mcp/tools/vault_ssh_get_connection \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"params": {"name": "prod-server"}}'
```

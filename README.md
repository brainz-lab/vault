# Vault

Secrets management with encryption at rest.

[![CI](https://github.com/brainz-lab/vault/actions/workflows/ci.yml/badge.svg)](https://github.com/brainz-lab/vault/actions/workflows/ci.yml)
[![CodeQL](https://github.com/brainz-lab/vault/actions/workflows/codeql.yml/badge.svg)](https://github.com/brainz-lab/vault/actions/workflows/codeql.yml)
[![codecov](https://codecov.io/gh/brainz-lab/vault/graph/badge.svg)](https://codecov.io/gh/brainz-lab/vault)
[![License: OSAaSy](https://img.shields.io/badge/License-OSAaSy-blue.svg)](LICENSE)
[![Ruby](https://img.shields.io/badge/Ruby-3.2+-red.svg)](https://www.ruby-lang.org)

## Quick Start

```bash
# Store a secret
vault_set_secret(name: "api_key", value: "sk_live_xxx")

# Retrieve it
vault_get_secret(name: "api_key", environment: "production")
```

## Installation

### With Docker

```bash
docker pull brainzllc/vault:latest

docker run -d \
  -p 3000:3000 \
  -e DATABASE_URL=postgres://user:pass@host:5432/vault \
  -e REDIS_URL=redis://host:6379/9 \
  -e RAILS_MASTER_KEY=your-master-key \
  -e VAULT_MASTER_KEY=your-vault-key \
  brainzllc/vault:latest
```

### Local Development

```bash
bin/setup
bin/rails server
```

## Configuration

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection | Yes |
| `REDIS_URL` | Redis for sessions | Yes |
| `RAILS_MASTER_KEY` | Rails credentials | Yes |
| `VAULT_MASTER_KEY` | Master encryption key | Yes |
| `AWS_KMS_KEY_ID` | AWS KMS key (optional) | No |

### Tech Stack

- **Ruby** 3.4.7 / **Rails** 8.1
- **PostgreSQL** 16 (encrypted storage)
- **Redis** 7 (session, rate limiting)
- **Encryption**: AES-256-GCM at rest
- **Key Management**: AWS KMS or local master key
- **Audit**: Append-only audit log

## Usage

### Store Secrets

```ruby
# Simple secret
vault_set_secret(name: "api_key", value: "sk_live_xxx")

# With environment
vault_set_secret(
  name: "database_url",
  value: "postgres://...",
  environment: "production"
)

# Credential with OTP
vault_set_credential(
  name: "github",
  username: "deploy",
  password: "secret",
  otp_secret: "JBSWY3DPEHPK3PXP"
)
```

### Retrieve Secrets

```ruby
# Get secret value
vault_get_secret(name: "api_key")

# Get credential
vault_get_credential(name: "github")

# Generate OTP code
vault_generate_otp(name: "github")
```

### SSH Key Management

```ruby
# Generate new SSH key
vault_ssh_generate_key(name: "deploy-key", key_type: "ed25519")

# Import existing key
vault_ssh_set_client_key(
  name: "legacy-key",
  private_key: "-----BEGIN OPENSSH PRIVATE KEY-----...",
  public_key: "ssh-ed25519 AAAA..."
)

# Create connection profile
vault_ssh_set_connection(
  name: "prod-server",
  host: "prod.example.com",
  username: "deploy",
  client_key_name: "deploy-key"
)
```

### Security Features

| Feature | Description |
|---------|-------------|
| **Encryption** | AES-256-GCM at rest |
| **Key Management** | AWS KMS or local |
| **Version History** | Full audit trail |
| **RBAC** | Role-based permissions |
| **Audit Logging** | Append-only access log |
| **Environment Separation** | Prod/Staging/Dev isolation |

### Environment Separation

Secrets are isolated by environment:
- **Production** - Locked, requires approval
- **Staging** - Team access
- **Development** - Open access

## API Reference

### Secrets
- `GET /api/v1/secrets` - List secret names
- `GET /api/v1/secrets/:name` - Get secret value
- `POST /api/v1/secrets` - Create secret
- `PUT /api/v1/secrets/:name` - Update secret
- `GET /api/v1/secrets/:name/versions` - Version history
- `POST /api/v1/secrets/:name/rotate` - Rotate secret

### Audit
- `GET /api/v1/audit-logs` - Audit log

### MCP Tools

| Tool | Description |
|------|-------------|
| `vault_list_secrets` | List all secret names |
| `vault_get_secret` | Retrieve a secret value |
| `vault_set_secret` | Set/update a secret |
| `vault_delete_secret` | Delete a secret |
| `vault_get_credential` | Get credential (username/password) |
| `vault_set_credential` | Set credential with optional OTP |
| `vault_generate_otp` | Generate OTP code |
| `vault_ssh_generate_key` | Generate new SSH key pair |
| `vault_ssh_get_connection` | Get SSH connection with key |

Full documentation: [docs.brainzlab.ai/products/vault](https://docs.brainzlab.ai/products/vault/overview)

## Self-Hosting

### Docker Compose

```yaml
services:
  vault:
    image: brainzllc/vault:latest
    ports:
      - "4006:3000"
    environment:
      DATABASE_URL: postgres://user:pass@db:5432/vault
      REDIS_URL: redis://redis:6379/9
      RAILS_MASTER_KEY: ${RAILS_MASTER_KEY}
      VAULT_MASTER_KEY: ${VAULT_MASTER_KEY}
      BRAINZLAB_PLATFORM_URL: http://platform:3000
    depends_on:
      - db
      - redis
```

### Testing

```bash
bin/rails test
bin/rubocop
```

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for development setup and contribution guidelines.

## License

This project is licensed under the [OSAaSy License](LICENSE).

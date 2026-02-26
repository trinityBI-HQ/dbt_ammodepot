# Railway CLI

> **Purpose**: Command-line interface for local development, deployment, and project management
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

The Railway CLI enables developers to interact with Railway projects from their terminal. It supports project initialization, deployment, log streaming, environment management, and running applications locally with Railway environment variables. The `railway dev` command (Dec 2025) provides a TUI with tabbed interface to run your entire environment locally. The CLI is the primary tool for CI/CD integration and developer workflows.

## Installation

### macOS/Linux
```bash
# Homebrew
brew install railway

# npm
npm install -g @railway/cli

# Shell script
curl -fsSL https://railway.app/install.sh | sh
```

### Windows
```bash
# npm
npm install -g @railway/cli

# Scoop
scoop install railway
```

## Authentication

```bash
# Login (opens browser)
railway login

# Login with token (CI/CD)
export RAILWAY_TOKEN=your_token_here
railway whoami
```

## Project Management

```bash
railway init                        # Create new project
railway link                        # Link to existing project
railway status                      # Show current project
railway list                        # List all projects
railway open                        # Open in browser
```

## Deployment Commands

```bash
railway up                                 # Deploy current directory
railway up --environment production        # Deploy specific env
railway up --service api                   # Deploy specific service
railway up --detach                        # Deploy without log stream
```

## Environment Management

```bash
railway environment                        # List environments
railway environment production             # Switch environment
railway environment create staging         # Create new environment
```

## Variables

```bash
railway variables                              # List all
railway variables --environment production     # List for env
railway variables set KEY=VALUE                # Set variable
railway variables set --from .env              # Set from file
railway variables delete KEY                   # Delete variable
```

## Local Development

### railway dev (TUI - Dec 2025+)
```bash
# Run entire environment locally with tabbed TUI
railway dev

# Features:
# - Tabbed interface: one tab per service
# - Injects Railway environment variables
# - Watches for file changes and auto-restarts
# - Shows logs per service in separate tabs
```

### Run with Railway Environment
```bash
# Run single command with Railway variables injected
railway run npm start

# Run arbitrary command
railway run python manage.py migrate

# Run shell with environment
railway run bash
```

## Logs and Domains

```bash
railway logs                        # Stream logs
railway logs --service api          # Specific service
railway logs --tail 100             # Tail last N lines
railway domain                      # List domains
railway domain add myapp.com        # Add custom domain
```

## Advanced Commands

```bash
railway shell                       # SSH into running container
railway shell -- ls -la             # Execute command in container
railway run psql $DATABASE_URL      # Connect to PostgreSQL
railway restart                     # Restart current service
railway restart --service worker    # Restart specific service
```

## CI/CD Integration

Use `RAILWAY_TOKEN` for non-interactive deployments. See [deployment-strategies](../patterns/deployment-strategies.md) for full CI/CD patterns.

## Best Practices

1. **Use railway.json**: Define config in code, not just CLI
2. **Use `railway dev`**: Run full environment locally with TUI for multi-service projects
3. **Environment Switching**: Always verify current environment
4. **CI/CD Token**: Use project tokens, not personal tokens
5. **Log Monitoring**: Use `railway logs` to debug deployments

## Related

- [deployments](../concepts/deployments.md)
- [variables](../concepts/variables.md)
- [environments](../concepts/environments.md)

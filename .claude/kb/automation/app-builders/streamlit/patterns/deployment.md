# Deployment Pattern

> **Purpose**: Deploy Streamlit apps to Community Cloud, Docker, and production environments
> **MCP Validated**: 2026-03-03

## When to Use

- Deploying a Streamlit app for team or public access
- Containerizing an app for Kubernetes or cloud hosting
- Configuring production settings (port, CORS, authentication)
- Setting up secrets management for deployed apps

## Implementation

### Streamlit Community Cloud (Fastest)

```text
Prerequisites:
1. App code in a public or private GitHub repo
2. requirements.txt or pyproject.toml at repo root
3. Streamlit Community Cloud account (share.streamlit.io)

Steps:
1. Push code to GitHub
2. Go to share.streamlit.io
3. Click "New app" and select repo, branch, and entrypoint file
4. Add secrets via the app settings dashboard
5. Deploy -- app gets a URL like https://yourapp.streamlit.app
```

```text
# Required repo structure for Community Cloud
my-app/
├── app.py                    # or any .py entrypoint
├── requirements.txt          # pip dependencies
├── .streamlit/
│   └── config.toml           # optional: app configuration
└── pages/                    # optional: multipage
    └── dashboard.py
```

### Docker Deployment

```dockerfile
# Dockerfile
FROM python:3.12-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app code
COPY . .

# Expose Streamlit port
EXPOSE 8501

# Health check
HEALTHCHECK CMD curl --fail http://localhost:8501/_stcore/health || exit 1

# Run Streamlit
ENTRYPOINT ["streamlit", "run", "app.py", \
    "--server.port=8501", \
    "--server.address=0.0.0.0", \
    "--server.headless=true", \
    "--browser.gatherUsageStats=false"]
```

```yaml
# docker-compose.yml
services:
  streamlit:
    build: .
    ports:
      - "8501:8501"
    environment:
      - STREAMLIT_SERVER_PORT=8501
    volumes:
      - ./.streamlit/secrets.toml:/app/.streamlit/secrets.toml:ro
    restart: unless-stopped
```

## Configuration

```toml
# .streamlit/config.toml
[server]
port = 8501
address = "0.0.0.0"
headless = true
maxUploadSize = 200          # MB
maxMessageSize = 200         # MB

[browser]
gatherUsageStats = false

[theme]
primaryColor = "#FF6B6B"
backgroundColor = "#FFFFFF"
secondaryBackgroundColor = "#F0F2F6"
textColor = "#262730"
font = "sans serif"

[client]
showSidebarNavigation = true
toolbarMode = "minimal"      # "developer", "viewer", "minimal"
```

## Environment Variables

```bash
# All config.toml settings can be set via environment variables
# Pattern: STREAMLIT_{SECTION}_{KEY} (uppercase, underscores)
export STREAMLIT_SERVER_PORT=8080
export STREAMLIT_SERVER_HEADLESS=true
export STREAMLIT_BROWSER_GATHERUSAGESTATS=false
export STREAMLIT_THEME_PRIMARYCOLOR="#FF6B6B"
```

## Secrets in Production

```python
# Access secrets in code
api_key = st.secrets["api"]["openai_key"]
db_password = st.secrets["connections"]["my_db"]["password"]

# Community Cloud: set via dashboard UI
# Docker: mount secrets.toml as a volume
# Kubernetes: use ConfigMap/Secret mounted as file
```

## Authentication (1.42+)

```python
import streamlit as st

# OIDC authentication with any provider
# Configure in secrets.toml:
# [auth]
# redirect_uri = "https://myapp.streamlit.app/oauth2callback"
# cookie_secret = "random-secret-string"
#
# [auth.google]
# client_id = "..."
# client_secret = "..."
# server_metadata_url = "https://accounts.google.com/.well-known/openid-configuration"

if not st.user.is_logged_in:
    st.login()
    st.stop()

st.write(f"Welcome, {st.user.name}!")
if st.button("Sign Out"):
    st.logout()
```

## Production Checklist

| Item | Setting | Notes |
|------|---------|-------|
| Headless mode | `server.headless = true` | No browser auto-open |
| Usage stats | `gatherUsageStats = false` | Disable telemetry |
| Health check | `/_stcore/health` endpoint | For load balancers |
| Max upload size | `server.maxUploadSize` | Default 200MB |
| CORS | `server.enableCORS = true` | Required for embeddi |
| Secrets | Never commit `secrets.toml` | Use env vars or mounts |

## Example Usage

```bash
# Local development
streamlit run app.py

# Production (Docker)
docker build -t myapp .
docker run -p 8501:8501 myapp

# Custom port
streamlit run app.py --server.port 8080

# Scaffold new project (1.44+)
streamlit init
```

## See Also

- [Multi-Page Apps](../patterns/multi-page-apps.md)
- [Database Integration](../patterns/database-integration.md)
- [Docker Compose KB](../../../devops-sre/containerization/docker-compose/)

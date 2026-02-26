# Python CDK

> **Purpose**: Framework for building custom source and destination connectors
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

The Airbyte Python CDK (Connector Development Kit) enables developers to build custom connectors when pre-built options don't exist. It provides base classes for handling API pagination, authentication, rate limiting, and schema discovery. For 90% of connectors, the low-code Connector Builder is recommended. Use the Python CDK for complex APIs requiring custom logic.

## The Pattern

```python
from airbyte_cdk.sources import AbstractSource
from airbyte_cdk.sources.streams.http import HttpStream
from typing import Any, Iterable, Mapping

class UsersStream(HttpStream):
    """Stream for /users endpoint."""

    url_base = "https://api.example.com/v1/"
    primary_key = "id"

    def path(self, **kwargs) -> str:
        return "users"

    def next_page_token(self, response) -> dict | None:
        """Handle pagination."""
        json_response = response.json()
        if json_response.get("next_page"):
            return {"page": json_response["next_page"]}
        return None

    def request_params(
        self, next_page_token: dict | None = None, **kwargs
    ) -> dict:
        """Add pagination params."""
        params = {"limit": 100}
        if next_page_token:
            params.update(next_page_token)
        return params

    def parse_response(self, response, **kwargs) -> Iterable[Mapping]:
        """Parse API response."""
        json_response = response.json()
        yield from json_response.get("data", [])


class SourceMyApi(AbstractSource):
    """Main source class."""

    def check_connection(self, config) -> tuple[bool, Any]:
        """Test credentials."""
        try:
            stream = UsersStream(authenticator=None)
            next(stream.read_records(sync_mode="full_refresh"))
            return True, None
        except Exception as e:
            return False, str(e)

    def streams(self, config: Mapping[str, Any]) -> list[HttpStream]:
        """Return list of streams."""
        return [UsersStream(authenticator=self._get_authenticator(config))]
```

## Quick Reference

| Class | Purpose | Use Case |
|-------|---------|----------|
| `AbstractSource` | Source connector entry point | All connectors |
| `HttpStream` | REST API stream | Most API connectors |
| `IncrementalMixin` | Incremental sync support | Cursor-based APIs |
| `Oauth2Authenticator` | OAuth 2.0 authentication | OAuth APIs |
| `TokenAuthenticator` | API key/token auth | Token-based APIs |
| `SourceDeclarativeManifest` | Low-code YAML connector | 90% of connectors |

## Core Components

### 1. Source Class

Entry point for the connector:

```python
class SourceMyApi(AbstractSource):
    def check_connection(self, config):
        """Validate credentials and connectivity."""
        pass

    def streams(self, config):
        """Return list of available streams."""
        pass
```

### 2. Stream Classes

Each API endpoint or table becomes a stream:

```python
class OrdersStream(HttpStream):
    url_base = "https://api.example.com/"
    primary_key = "order_id"

    def path(self):
        return "orders"

    def parse_response(self, response):
        """Extract records from response."""
        return response.json()["orders"]
```

### 3. Authentication

```python
from airbyte_cdk.sources.streams.http.auth import TokenAuthenticator

authenticator = TokenAuthenticator(
    token=config["api_key"],
    auth_method="Bearer"
)

# OAuth example
from airbyte_cdk.sources.streams.http.auth import Oauth2Authenticator

authenticator = Oauth2Authenticator(
    token_refresh_endpoint="https://api.example.com/oauth/token",
    client_id=config["client_id"],
    client_secret=config["client_secret"],
    refresh_token=config["refresh_token"]
)
```

### 4. Incremental Sync

```python
from airbyte_cdk.sources.streams.http import HttpStream
from airbyte_cdk.sources.streams import IncrementalMixin

class IncrementalOrdersStream(HttpStream, IncrementalMixin):
    cursor_field = "updated_at"
    primary_key = "order_id"

    def get_updated_state(self, current_stream_state, latest_record):
        """Update cursor value."""
        current_cursor = current_stream_state.get(self.cursor_field, "")
        latest_cursor = latest_record.get(self.cursor_field, "")
        return {self.cursor_field: max(current_cursor, latest_cursor)}

    def request_params(self, stream_state=None, **kwargs):
        """Filter by cursor."""
        params = super().request_params(**kwargs)
        if stream_state:
            params["updated_since"] = stream_state.get(self.cursor_field)
        return params
```

### 5. Pagination

```python
def next_page_token(self, response):
    """Cursor-based pagination."""
    data = response.json()
    if data.get("has_more"):
        return {"cursor": data["next_cursor"]}
    return None

# Offset pagination
def next_page_token(self, response):
    """Offset-based pagination."""
    data = response.json()
    if len(data["items"]) == self.page_size:
        return {"offset": self.offset + self.page_size}
    return None
```

## Stream Templates (v1.7+, Jun 2025)

Generate multiple streams from a single template definition. Ideal for APIs with many similar endpoints (e.g., one template for all Salesforce objects or all database tables).

## Low-Code CDK (Recommended)

For 90% of connectors, use declarative YAML:

```yaml
# manifest.yaml
version: "0.29.0"

definitions:
  selector:
    extractor:
      field_path: ["data"]

  requester:
    url_base: "https://api.example.com/v1"
    http_method: "GET"
    authenticator:
      type: "BearerAuthenticator"
      api_token: "{{ config['api_key'] }}"

  users_stream:
    $ref: "#/definitions/base_stream"
    name: "users"
    primary_key: "id"
    $parameters:
      path: "/users"

streams:
  - "#/definitions/users_stream"
```

## Connector Builder UI

Build connectors without code:

1. Navigate to Connector Builder in Airbyte UI
2. Configure API base URL and authentication
3. Define streams and field mappings
4. Test with sample data
5. Export as low-code connector

## Testing

```python
# tests/unit_tests/test_streams.py
import pytest
from source_my_api.source import UsersStream

def test_users_stream():
    stream = UsersStream(authenticator=None)
    assert stream.primary_key == "id"
    assert stream.path() == "users"

# Integration test
def test_check_connection():
    source = SourceMyApi()
    success, message = source.check_connection(config={"api_key": "test"})
    assert success
```

## Common Mistakes

### Wrong

```python
# Anti-pattern: Hardcoded credentials
class UsersStream(HttpStream):
    def request_headers(self):
        return {"Authorization": "Bearer sk-1234567890"}  # Hardcoded!
```

### Correct

```python
# Correct: Use authenticator
class UsersStream(HttpStream):
    def __init__(self, authenticator, **kwargs):
        super().__init__(authenticator=authenticator, **kwargs)

# In source
def streams(self, config):
    auth = TokenAuthenticator(token=config["api_key"])
    return [UsersStream(authenticator=auth)]
```

## Deployment

```bash
# Build connector Docker image
docker build -t airbyte/source-my-api:0.1.0 .

# Test locally
airbyte-ci connectors test --name=source-my-api

# Publish to Airbyte (community connector)
# Submit PR to airbytehq/airbyte repository
```

## Related

- [connectors](../concepts/connectors.md)
- [catalog-schema](../concepts/catalog-schema.md)
- [custom-python-connector](../patterns/custom-python-connector.md)

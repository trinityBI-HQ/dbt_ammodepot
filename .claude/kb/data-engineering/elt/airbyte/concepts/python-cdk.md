# Python CDK

> **Purpose**: Framework for building custom source and destination connectors
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

The Airbyte Python CDK (Connector Development Kit) enables developers to build custom connectors when pre-built options don't exist. It provides base classes for API pagination, authentication, rate limiting, and schema discovery. For 90% of connectors, the low-code Connector Builder is recommended. Use the Python CDK for complex APIs requiring custom logic.

## Quick Reference

| Class | Purpose |
|-------|---------|
| `AbstractSource` | Source connector entry point |
| `HttpStream` | REST API stream |
| `IncrementalMixin` | Incremental sync support |
| `Oauth2Authenticator` | OAuth 2.0 authentication |
| `TokenAuthenticator` | API key/token auth |
| `SourceDeclarativeManifest` | Low-code YAML connector |

## The Pattern

```python
from airbyte_cdk.sources import AbstractSource
from airbyte_cdk.sources.streams.http import HttpStream
from airbyte_cdk.sources.streams.http.auth import TokenAuthenticator
from typing import Any, Iterable, Mapping

class UsersStream(HttpStream):
    url_base = "https://api.example.com/v1/"
    primary_key = "id"

    def path(self, **kwargs) -> str:
        return "users"

    def next_page_token(self, response) -> dict | None:
        data = response.json()
        return {"page": data["next_page"]} if data.get("next_page") else None

    def request_params(self, next_page_token: dict | None = None, **kwargs) -> dict:
        params = {"limit": 100}
        if next_page_token:
            params.update(next_page_token)
        return params

    def parse_response(self, response, **kwargs) -> Iterable[Mapping]:
        yield from response.json().get("data", [])

class SourceMyApi(AbstractSource):
    def check_connection(self, config) -> tuple[bool, Any]:
        try:
            next(UsersStream(authenticator=None).read_records(sync_mode="full_refresh"))
            return True, None
        except Exception as e:
            return False, str(e)

    def streams(self, config: Mapping[str, Any]) -> list[HttpStream]:
        auth = TokenAuthenticator(token=config["api_key"])
        return [UsersStream(authenticator=auth)]
```

## Authentication

```python
# Token auth
auth = TokenAuthenticator(token=config["api_key"], auth_method="Bearer")

# OAuth 2.0
from airbyte_cdk.sources.streams.http.auth import Oauth2Authenticator
auth = Oauth2Authenticator(
    token_refresh_endpoint="https://api.example.com/oauth/token",
    client_id=config["client_id"],
    client_secret=config["client_secret"],
    refresh_token=config["refresh_token"]
)
```

## Incremental Sync

```python
from airbyte_cdk.sources.streams import IncrementalMixin

class IncrementalOrdersStream(HttpStream, IncrementalMixin):
    cursor_field = "updated_at"
    primary_key = "order_id"

    def get_updated_state(self, current_stream_state, latest_record):
        current = current_stream_state.get(self.cursor_field, "")
        latest = latest_record.get(self.cursor_field, "")
        return {self.cursor_field: max(current, latest)}

    def request_params(self, stream_state=None, **kwargs):
        params = super().request_params(**kwargs)
        if stream_state:
            params["updated_since"] = stream_state.get(self.cursor_field)
        return params
```

## Low-Code CDK (Recommended for 90% of connectors)

```yaml
version: "0.29.0"
definitions:
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

## Stream Templates (v1.7+)

Generate multiple streams from a single template definition. Ideal for APIs with many similar endpoints (e.g., one template for all Salesforce objects).

## Deployment

```bash
docker build -t airbyte/source-my-api:0.1.0 .
airbyte-ci connectors test --name=source-my-api
```

## Related

- [connectors](../concepts/connectors.md)
- [catalog-schema](../concepts/catalog-schema.md)
- [custom-python-connector](../patterns/custom-python-connector.md)

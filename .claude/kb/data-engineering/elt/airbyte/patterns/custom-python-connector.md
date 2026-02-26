# Custom Python Connector

> **Purpose**: Build custom source connectors for REST APIs using Python CDK
> **MCP Validated**: 2026-02-19

## When to Use

- Source API not available in Airbyte's 350+ connectors
- Need custom transformation logic during extraction
- API requires complex authentication or pagination
- Building internal/proprietary system integration
- Prototyping before contributing to Airbyte community

## Implementation

```python
# source_my_api/source.py
from airbyte_cdk.sources import AbstractSource
from airbyte_cdk.sources.streams.http import HttpStream
from airbyte_cdk.sources.streams.http.auth import TokenAuthenticator
from typing import Any, Iterable, List, Mapping, MutableMapping, Optional

class UsersStream(HttpStream):
    """Stream for fetching user data."""

    url_base = "https://api.example.com/v2/"
    primary_key = "id"

    def __init__(self, config: Mapping[str, Any], **kwargs):
        super().__init__(**kwargs)
        self.start_date = config.get("start_date")

    def path(
        self,
        stream_state: Mapping[str, Any] = None,
        stream_slice: Mapping[str, Any] = None,
        next_page_token: Mapping[str, Any] = None,
    ) -> str:
        return "users"

    def next_page_token(
        self, response: requests.Response
    ) -> Optional[Mapping[str, Any]]:
        """Implement cursor-based pagination."""
        json_response = response.json()
        next_cursor = json_response.get("pagination", {}).get("next_cursor")

        if next_cursor:
            return {"cursor": next_cursor}
        return None

    def request_params(
        self,
        stream_state: Mapping[str, Any],
        stream_slice: Mapping[str, any] = None,
        next_page_token: Mapping[str, Any] = None,
    ) -> MutableMapping[str, Any]:
        """Set query parameters."""
        params = {"limit": 100}

        # Pagination
        if next_page_token:
            params["cursor"] = next_page_token["cursor"]

        # Incremental sync
        if stream_state and stream_state.get("updated_at"):
            params["updated_since"] = stream_state["updated_at"]

        return params

    def parse_response(
        self,
        response: requests.Response,
        stream_state: Mapping[str, Any],
        stream_slice: Mapping[str, Any] = None,
        next_page_token: Mapping[str, Any] = None,
    ) -> Iterable[Mapping]:
        """Extract records from API response."""
        json_response = response.json()
        yield from json_response.get("data", [])

    def get_json_schema(self) -> Mapping[str, Any]:
        """Define stream schema."""
        return {
            "type": "object",
            "properties": {
                "id": {"type": "integer"},
                "email": {"type": "string"},
                "name": {"type": "string"},
                "created_at": {"type": "string", "format": "date-time"},
                "updated_at": {"type": "string", "format": "date-time"},
            },
        }


class IncrementalUsersStream(UsersStream):
    """Incremental version of users stream."""

    cursor_field = "updated_at"
    state_checkpoint_interval = 1000

    def get_updated_state(
        self,
        current_stream_state: MutableMapping[str, Any],
        latest_record: Mapping[str, Any],
    ) -> Mapping[str, Any]:
        """Update cursor value with latest record."""
        current_cursor = current_stream_state.get(self.cursor_field, "")
        latest_cursor = latest_record.get(self.cursor_field, "")
        return {self.cursor_field: max(current_cursor, latest_cursor)}


class SourceMyApi(AbstractSource):
    """Main source implementation."""

    def check_connection(
        self, logger, config: Mapping[str, Any]
    ) -> tuple[bool, Any]:
        """Test connectivity and credentials."""
        try:
            authenticator = self._get_authenticator(config)
            stream = UsersStream(config=config, authenticator=authenticator)

            # Try to read one record
            records = stream.read_records(sync_mode="full_refresh")
            next(records)
            return True, None

        except Exception as e:
            return False, f"Connection check failed: {str(e)}"

    def streams(
        self, config: Mapping[str, Any]
    ) -> List[HttpStream]:
        """Return list of streams."""
        authenticator = self._get_authenticator(config)

        return [
            IncrementalUsersStream(
                config=config,
                authenticator=authenticator
            ),
            OrdersStream(
                config=config,
                authenticator=authenticator
            ),
        ]

    def _get_authenticator(self, config: Mapping[str, Any]):
        """Create authenticator from config."""
        return TokenAuthenticator(
            token=config["api_key"],
            auth_method="Bearer"
        )
```

## Configuration

```python
# source_my_api/spec.yaml
documentationUrl: https://docs.example.com/api
connectionSpecification:
  $schema: http://json-schema.org/draft-07/schema#
  title: My API Source Spec
  type: object
  required:
    - api_key
  properties:
    api_key:
      type: string
      title: API Key
      description: API key for authentication
      airbyte_secret: true
    start_date:
      type: string
      title: Start Date
      description: Date to start syncing from (YYYY-MM-DD)
      pattern: ^[0-9]{4}-[0-9]{2}-[0-9]{2}$
      examples:
        - "2024-01-01"
```

## Advanced Pagination

```python
# Offset-based pagination
class OffsetPaginationStream(HttpStream):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.page_size = 100
        self.current_offset = 0

    def next_page_token(self, response):
        json_response = response.json()
        records = json_response.get("data", [])

        if len(records) == self.page_size:
            self.current_offset += self.page_size
            return {"offset": self.current_offset}
        return None

    def request_params(self, next_page_token=None, **kwargs):
        params = {"limit": self.page_size}
        if next_page_token:
            params["offset"] = next_page_token["offset"]
        return params

# Link header pagination
class LinkHeaderPaginationStream(HttpStream):
    def next_page_token(self, response):
        link_header = response.headers.get("Link")
        if link_header and 'rel="next"' in link_header:
            # Parse Link: <https://api.example.com/users?page=2>; rel="next"
            next_url = link_header.split(";")[0].strip("<>")
            return {"next_url": next_url}
        return None

    def path(self, next_page_token=None, **kwargs):
        if next_page_token:
            return next_page_token["next_url"]
        return "users"
```

## OAuth 2.0 Authentication

```python
from airbyte_cdk.sources.streams.http.auth import Oauth2Authenticator

class SourceWithOAuth(AbstractSource):
    def _get_authenticator(self, config):
        return Oauth2Authenticator(
            token_refresh_endpoint="https://api.example.com/oauth/token",
            client_id=config["client_id"],
            client_secret=config["client_secret"],
            refresh_token=config["refresh_token"],
        )
```

## Rate Limiting

```python
from airbyte_cdk.sources.streams.http.rate_limiting import default_backoff_handler
import time

class RateLimitedStream(HttpStream):
    @default_backoff_handler(max_tries=5, factor=5)
    def _send_request(self, request, request_kwargs):
        """Add rate limiting with backoff."""
        response = super()._send_request(request, request_kwargs)

        # Respect rate limit headers
        remaining = response.headers.get("X-RateLimit-Remaining")
        if remaining and int(remaining) < 10:
            reset_time = int(response.headers.get("X-RateLimit-Reset", 0))
            wait_seconds = max(0, reset_time - time.time())
            time.sleep(wait_seconds)

        return response
```

## Testing

```python
# tests/unit_tests/test_source.py
import pytest
from source_my_api.source import SourceMyApi, UsersStream

def test_check_connection(mocker):
    """Test connection check."""
    source = SourceMyApi()
    config = {"api_key": "test_key"}

    # Mock HTTP request
    mocker.patch.object(
        UsersStream,
        'read_records',
        return_value=iter([{"id": 1}])
    )

    success, message = source.check_connection(None, config)
    assert success is True

def test_streams():
    """Test stream initialization."""
    source = SourceMyApi()
    config = {"api_key": "test_key"}
    streams = source.streams(config)

    assert len(streams) > 0
    assert all(isinstance(s, HttpStream) for s in streams)

# tests/integration_tests/test_streams.py
def test_users_stream(config):
    """Integration test with real API."""
    stream = IncrementalUsersStream(
        config=config,
        authenticator=TokenAuthenticator(config["api_key"])
    )

    records = list(stream.read_records(sync_mode="full_refresh"))
    assert len(records) > 0
    assert "id" in records[0]
```

## Example Usage

```bash
# Install Airbyte CDK
pip install airbyte-cdk

# Create connector from template
airbyte-cdk generate source --name my-api

# Test locally
python main.py check --config secrets/config.json
python main.py discover --config secrets/config.json
python main.py read --config secrets/config.json --catalog integration_tests/configured_catalog.json

# Build Docker image
docker build -t airbyte/source-my-api:0.1.0 .

# Test in Airbyte
docker run --rm -i airbyte/source-my-api:0.1.0 check --config config.json
```

## Project Structure

```
source-my-api/
├── source_my_api/
│   ├── __init__.py
│   ├── source.py           # Main source implementation
│   ├── streams.py          # Stream classes
│   └── spec.yaml           # Connector specification
├── tests/
│   ├── unit_tests/
│   └── integration_tests/
├── Dockerfile
├── setup.py
└── README.md
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Hardcode credentials | Use config parameters |
| Ignore rate limits | Implement backoff |
| Skip error handling | Try/except and log |
| No incremental support | Implement cursor |
| Load all pages in memory | Stream records |

## See Also

- [python-cdk](../concepts/python-cdk.md)
- [connectors](../concepts/connectors.md)
- [catalog-schema](../concepts/catalog-schema.md)

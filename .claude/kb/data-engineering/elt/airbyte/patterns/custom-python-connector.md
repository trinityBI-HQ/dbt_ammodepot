# Custom Python Connector

> **Purpose**: Build custom source connectors for REST APIs using Python CDK
> **MCP Validated**: 2026-02-19

## When to Use

- Source API not available in Airbyte's 350+ connectors
- API requires complex authentication or pagination
- Need custom transformation logic during extraction
- Building internal/proprietary system integration

## Implementation

```python
from airbyte_cdk.sources import AbstractSource
from airbyte_cdk.sources.streams.http import HttpStream
from airbyte_cdk.sources.streams.http.auth import TokenAuthenticator
from typing import Any, Iterable, List, Mapping, MutableMapping, Optional

class UsersStream(HttpStream):
    url_base = "https://api.example.com/v2/"
    primary_key = "id"

    def __init__(self, config: Mapping[str, Any], **kwargs):
        super().__init__(**kwargs)
        self.start_date = config.get("start_date")

    def path(self, **kwargs) -> str:
        return "users"

    def next_page_token(self, response) -> Optional[Mapping[str, Any]]:
        next_cursor = response.json().get("pagination", {}).get("next_cursor")
        return {"cursor": next_cursor} if next_cursor else None

    def request_params(self, stream_state=None, next_page_token=None, **kwargs) -> MutableMapping[str, Any]:
        params = {"limit": 100}
        if next_page_token:
            params["cursor"] = next_page_token["cursor"]
        if stream_state and stream_state.get("updated_at"):
            params["updated_since"] = stream_state["updated_at"]
        return params

    def parse_response(self, response, **kwargs) -> Iterable[Mapping]:
        yield from response.json().get("data", [])

    def get_json_schema(self) -> Mapping[str, Any]:
        return {
            "type": "object",
            "properties": {
                "id": {"type": "integer"},
                "email": {"type": "string"},
                "name": {"type": "string"},
                "updated_at": {"type": "string", "format": "date-time"},
            },
        }


class IncrementalUsersStream(UsersStream):
    cursor_field = "updated_at"
    state_checkpoint_interval = 1000

    def get_updated_state(self, current_stream_state, latest_record):
        current = current_stream_state.get(self.cursor_field, "")
        latest = latest_record.get(self.cursor_field, "")
        return {self.cursor_field: max(current, latest)}


class SourceMyApi(AbstractSource):
    def check_connection(self, logger, config) -> tuple[bool, Any]:
        try:
            auth = self._get_authenticator(config)
            next(UsersStream(config=config, authenticator=auth).read_records(sync_mode="full_refresh"))
            return True, None
        except Exception as e:
            return False, f"Connection check failed: {e}"

    def streams(self, config) -> List[HttpStream]:
        auth = self._get_authenticator(config)
        return [IncrementalUsersStream(config=config, authenticator=auth)]

    def _get_authenticator(self, config):
        return TokenAuthenticator(token=config["api_key"], auth_method="Bearer")
```

## Configuration Spec

```yaml
# source_my_api/spec.yaml
connectionSpecification:
  $schema: http://json-schema.org/draft-07/schema#
  type: object
  required: [api_key]
  properties:
    api_key:
      type: string
      title: API Key
      airbyte_secret: true
    start_date:
      type: string
      title: Start Date
      pattern: ^[0-9]{4}-[0-9]{2}-[0-9]{2}$
```

## Advanced Pagination

```python
# Offset-based
class OffsetStream(HttpStream):
    page_size = 100

    def next_page_token(self, response):
        records = response.json().get("data", [])
        if len(records) == self.page_size:
            offset = (getattr(self, '_offset', 0)) + self.page_size
            self._offset = offset
            return {"offset": offset}
        return None

# Link header
class LinkStream(HttpStream):
    def next_page_token(self, response):
        link = response.headers.get("Link")
        if link and 'rel="next"' in link:
            return {"next_url": link.split(";")[0].strip("<>")}
        return None
```

## OAuth 2.0

```python
from airbyte_cdk.sources.streams.http.auth import Oauth2Authenticator

auth = Oauth2Authenticator(
    token_refresh_endpoint="https://api.example.com/oauth/token",
    client_id=config["client_id"],
    client_secret=config["client_secret"],
    refresh_token=config["refresh_token"],
)
```

## Rate Limiting

```python
from airbyte_cdk.sources.streams.http.rate_limiting import default_backoff_handler

class RateLimitedStream(HttpStream):
    @default_backoff_handler(max_tries=5, factor=5)
    def _send_request(self, request, request_kwargs):
        response = super()._send_request(request, request_kwargs)
        remaining = response.headers.get("X-RateLimit-Remaining")
        if remaining and int(remaining) < 10:
            import time
            reset = int(response.headers.get("X-RateLimit-Reset", 0))
            time.sleep(max(0, reset - time.time()))
        return response
```

## Testing and Deployment

```bash
# Local testing
python main.py check --config secrets/config.json
python main.py discover --config secrets/config.json
python main.py read --config secrets/config.json --catalog configured_catalog.json

# Build and publish
docker build -t airbyte/source-my-api:0.1.0 .
airbyte-ci connectors test --name=source-my-api
```

## Project Structure

```
source-my-api/
├── source_my_api/
│   ├── __init__.py
│   ├── source.py       # Main source
│   ├── streams.py      # Stream classes
│   └── spec.yaml       # Connector spec
├── tests/
├── Dockerfile
└── setup.py
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Hardcode credentials | Use config + `airbyte_secret` |
| Ignore rate limits | Implement backoff handler |
| Skip error handling | Try/except with logging |
| Load all pages in memory | Stream records with `yield` |

## See Also

- [python-cdk](../concepts/python-cdk.md)
- [connectors](../concepts/connectors.md)
- [catalog-schema](../concepts/catalog-schema.md)

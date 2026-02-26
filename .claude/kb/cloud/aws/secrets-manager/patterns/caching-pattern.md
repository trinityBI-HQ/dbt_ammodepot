# Client-Side Caching Pattern

> **Purpose**: Reduce API calls and latency by caching secrets locally in applications
> **MCP Validated**: 2026-02-19

## When to Use

- High-throughput applications calling GetSecretValue frequently
- Lambda functions reusing secrets across invocations
- Reducing Secrets Manager API costs ($0.05 per 10,000 calls)
- Low-latency secret access requirements

## Implementation — AWS Caching Library

```python
"""Using the official aws-secretsmanager-caching library."""
# pip install aws-secretsmanager-caching

from aws_secretsmanager_caching import SecretCache, SecretCacheConfig
import botocore.session
import json

# Configure cache
cache_config = SecretCacheConfig(
    max_cache_size=1000,           # Max secrets to cache
    exception_retry_delay_base=1,  # Base retry delay (seconds)
    exception_retry_growth_factor=2,
    exception_retry_delay_max=3600,
    default_secret_version_stage="AWSCURRENT",
    secret_refresh_interval=3600,  # Refresh every hour (seconds)
    secret_version_stage_refresh_interval=3600,
)

botocore_client = botocore.session.get_session().create_client("secretsmanager")
cache = SecretCache(config=cache_config, client=botocore_client)

# Retrieve (cached after first call)
secret_string = cache.get_secret_string("prod/myapp/db-credentials")
creds = json.loads(secret_string)

# Binary secrets
secret_binary = cache.get_secret_binary("prod/myapp/tls-cert")
```

## Implementation — Decorator Pattern

```python
"""Using the @InjectKeywordedSecretString decorator."""
from aws_secretsmanager_caching import SecretCache, InjectKeywordedSecretString

cache = SecretCache()

@InjectKeywordedSecretString(
    secret_id="prod/myapp/db-credentials",
    cache=cache,
    func_username="username",
    func_password="password",
    func_host="host",
)
def connect_to_db(func_username, func_password, func_host):
    """Secret values are injected as keyword arguments."""
    return f"postgresql://{func_username}:{func_password}@{func_host}/mydb"
```

## Implementation — Manual Cache (No Dependencies)

```python
"""Lightweight manual caching for Lambda or simple apps."""
import boto3
import json
import time

_cache: dict[str, tuple[dict, float]] = {}
CACHE_TTL = 300  # 5 minutes


def get_secret_cached(secret_id: str, ttl: int = CACHE_TTL) -> dict:
    """Get secret with simple TTL-based cache."""
    now = time.time()
    if secret_id in _cache:
        value, cached_at = _cache[secret_id]
        if now - cached_at < ttl:
            return value

    client = boto3.client("secretsmanager")
    response = client.get_secret_value(SecretId=secret_id)
    value = json.loads(response["SecretString"])
    _cache[secret_id] = (value, now)
    return value


# Lambda handler — cache persists across warm invocations
def lambda_handler(event, context):
    creds = get_secret_cached("prod/myapp/db-credentials")
    # Use creds...
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `max_cache_size` | 1000 | Maximum number of cached secrets |
| `secret_refresh_interval` | 3600 | Seconds before cache refresh |
| `secret_version_stage_refresh_interval` | 3600 | Stage refresh interval |
| `exception_retry_delay_base` | 1 | Base retry delay (seconds) |
| `exception_retry_delay_max` | 3600 | Maximum retry delay |

## Cache Behavior

| Scenario | Behavior |
|----------|----------|
| First call | Fetches from API, stores in cache |
| Subsequent (within TTL) | Returns cached value, no API call |
| After TTL expires | Fetches fresh value from API |
| After rotation | New value available after cache refresh |
| Lambda cold start | Cache empty, fetches from API |
| Lambda warm invocation | Uses cached value |

## Cost Impact

| Pattern | API Calls/hour (100 req/sec) | Monthly Cost |
|---------|------------------------------|-------------|
| No cache | 360,000 | ~$1.80 |
| 5-min cache | 12 | ~$0.00 |
| 1-hour cache | 1 | ~$0.00 |

## See Also

- [Boto3 Integration](../patterns/boto3-integration.md)
- [Secrets Overview](../concepts/secrets-overview.md)

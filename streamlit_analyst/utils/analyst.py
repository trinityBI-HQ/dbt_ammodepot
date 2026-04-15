"""Cortex Analyst REST API wrapper.

Handles authentication for both SiS container runtime and local development,
sends messages to the Cortex Analyst API, and parses responses.

SiS container runtime: reads OAuth token from /snowflake/session/token
Local development: uses snowflake-connector token via db._get_local_connection()
"""

import os

import requests

SNOWFLAKE_ACCOUNT = os.environ.get("SNOWFLAKE_ACCOUNT", "iwb48385.us-east-1")
SEMANTIC_VIEW = "AD_ANALYTICS.GOLD.AMMODEPOT_ANALYST"
API_TIMEOUT = int(os.environ.get("API_TIMEOUT", "90"))

_API_URL = (
    f"https://{SNOWFLAKE_ACCOUNT}.snowflakecomputing.com"
    f"/api/v2/cortex/analyst/message"
)


def _get_token() -> str:
    """Read OAuth token for Cortex Analyst API authentication.

    Container runtime: /snowflake/session/token is auto-injected.
    Local dev: falls back to snowflake-connector REST token.
    """
    try:
        with open("/snowflake/session/token", "r") as f:
            return f.read().strip()
    except FileNotFoundError:
        from utils.db import _get_local_connection
        conn = _get_local_connection()
        return conn.rest.token


def send_message(messages: list[dict]) -> dict:
    """Call Cortex Analyst with full conversation history.

    Args:
        messages: List of {"role": "user"|"analyst", "content": [...]} dicts.
                  Include full history for multi-turn context.

    Returns:
        Parsed JSON response from Cortex Analyst.

    Raises:
        RuntimeError: On non-2xx HTTP responses.
    """
    resp = requests.post(
        _API_URL,
        headers={
            "Authorization": f"Bearer {_get_token()}",
            "Content-Type": "application/json",
            "X-Snowflake-Authorization-Token-Type": "OAUTH",
        },
        json={
            "messages": messages,
            "semantic_view": SEMANTIC_VIEW,
        },
        timeout=API_TIMEOUT,
    )
    if not resp.ok:
        raise RuntimeError(
            f"Cortex Analyst error {resp.status_code}: {resp.text[:500]}"
        )
    return resp.json()


def extract_content(
    response: dict,
) -> tuple[str | None, str | None, list[str]]:
    """Extract text, SQL, and suggestions from a Cortex Analyst response.

    Returns:
        Tuple of (text_explanation, sql_statement, suggestion_list).
        Any element can be None/empty if not present in the response.
    """
    text, sql, suggestions = None, None, []
    for block in response.get("message", {}).get("content", []):
        block_type = block.get("type")
        if block_type == "text":
            text = block["text"]
        elif block_type == "sql":
            sql = block["statement"]
        elif block_type == "suggestions":
            suggestions = block.get("suggestions", [])
    return text, sql, suggestions

# API Integration

> **Purpose**: Deploy Langflow flows as production REST APIs with authentication and monitoring
> **MCP Validated**: 2026-02-06

## When to Use

- Embed Langflow flows in web/mobile applications
- Provide programmatic access to AI workflows
- Build microservices architecture with AI components

## Implementation

```python
# Python API Client
import os, json, requests

class LangflowAPIClient:
    def __init__(self, base_url: str, api_key: str, timeout: int = 30):
        self.base_url = base_url.rstrip('/')
        self.timeout = timeout
        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        })

    def run_flow(self, flow_id: str, inputs: dict, tweaks: dict = None, stream: bool = False) -> dict:
        url = f"{self.base_url}/api/v1/run/{flow_id}"
        payload = {"inputs": inputs, "tweaks": tweaks or {}}
        if stream:
            return self._stream_response(url, payload)
        response = self.session.post(url, json=payload, timeout=self.timeout)
        response.raise_for_status()
        return response.json()

    def _stream_response(self, url: str, payload: dict):
        response = self.session.post(url, json={**payload, "stream": True}, stream=True, timeout=self.timeout)
        for line in response.iter_lines():
            if line:
                yield json.loads(line.decode('utf-8'))

    def list_flows(self) -> list[dict]:
        response = self.session.get(f"{self.base_url}/api/v1/flows", timeout=self.timeout)
        response.raise_for_status()
        return response.json()

# Usage
client = LangflowAPIClient(
    base_url="https://api.langflow.app",
    api_key=os.getenv("LANGFLOW_API_KEY")
)
result = client.run_flow("abc-123", inputs={"question": "How do I reset my password?"})
```

```javascript
// JavaScript Client
class LangflowClient {
    constructor(baseUrl, apiKey, timeout = 30000) {
        this.baseUrl = baseUrl.replace(/\/$/, '');
        this.apiKey = apiKey;
        this.timeout = timeout;
    }

    async runFlow(flowId, inputs, tweaks = {}) {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), this.timeout);
        const response = await fetch(`${this.baseUrl}/api/v1/run/${flowId}`, {
            method: 'POST',
            headers: { 'Authorization': `Bearer ${this.apiKey}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({ inputs, tweaks }),
            signal: controller.signal
        });
        clearTimeout(timeoutId);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return await response.json();
    }
}
```

## Webhook Integration

```python
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/webhook/process', methods=['POST'])
def process_webhook():
    try:
        result = langflow_client.run_flow(
            flow_id="webhook-processor",
            inputs={"webhook_payload": request.json}
        )
        return jsonify({"status": "success", "result": result}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `base_url` | Required | Langflow API base URL |
| `api_key` | Required | Authentication key |
| `timeout` | 30 | Request timeout (seconds) |
| `max_retries` | 3 | Retry failed requests |

## Error Handling

```python
class RateLimitError(Exception): pass
class AuthenticationError(Exception): pass

def run_flow_with_retry(client, flow_id, inputs, max_retries=3):
    for attempt in range(max_retries):
        try:
            return client.run_flow(flow_id, inputs)
        except RateLimitError:
            if attempt == max_retries - 1: raise
            time.sleep(2 ** attempt)
        except AuthenticationError:
            raise  # Don't retry auth errors
```

## Example Usage

```bash
curl -X POST https://api.langflow.app/api/v1/run/abc-123 \
  -H "Authorization: Bearer sk_langflow_abc123" \
  -H "Content-Type: application/json" \
  -d '{"inputs": {"question": "What is Langflow?"}, "tweaks": {"temperature": 0.7}}'
```

## Common Pitfalls

```python
# Always handle errors, use env vars for credentials, set timeouts
# Bad: no try/except, hardcoded API keys, no timeout
# Good: error handling, os.getenv(), timeout=30
```

## See Also

- [api-deployment.md](../concepts/api-deployment.md) - Deployment configuration
- [production-deployment.md](../patterns/production-deployment.md) - Production setup

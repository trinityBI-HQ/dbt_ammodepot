# API Integration

> **Purpose**: Deploy Langflow flows as production REST APIs with authentication and monitoring
> **MCP Validated**: 2026-02-06

## When to Use

- Embed Langflow flows in web/mobile applications
- Provide programmatic access to AI workflows
- Build microservices architecture with AI components
- Enable third-party integrations via API

## Implementation

```python
# Complete API integration setup

# 1. FLOW PREPARATION

# Enable API access in flow settings
flow_config = {
    "name": "customer-support-rag",
    "api_enabled": True,
    "api_path": "/api/v1/support",
    "authentication": "api_key",
    "rate_limit": {
        "requests_per_minute": 60,
        "requests_per_hour": 1000
    }
}


# 2. API CLIENT LIBRARY

class LangflowAPIClient:
    """Python client for Langflow API"""

    def __init__(self, base_url: str, api_key: str, timeout: int = 30):
        self.base_url = base_url.rstrip('/')
        self.api_key = api_key
        self.timeout = timeout
        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        })

    def run_flow(
        self,
        flow_id: str,
        inputs: dict,
        tweaks: dict = None,
        stream: bool = False
    ) -> dict:
        """
        Execute a Langflow flow via API.

        Args:
            flow_id: Flow identifier
            inputs: Input parameters for the flow
            tweaks: Optional parameter overrides
            stream: Enable streaming responses

        Returns:
            Flow execution results
        """
        url = f"{self.base_url}/api/v1/run/{flow_id}"

        payload = {
            "inputs": inputs,
            "tweaks": tweaks or {}
        }

        try:
            if stream:
                return self._stream_response(url, payload)
            else:
                response = self.session.post(
                    url,
                    json=payload,
                    timeout=self.timeout
                )
                response.raise_for_status()
                return response.json()

        except requests.exceptions.Timeout:
            raise TimeoutError(f"Request timed out after {self.timeout}s")
        except requests.exceptions.HTTPError as e:
            raise APIError(f"API request failed: {e.response.status_code}")

    def _stream_response(self, url: str, payload: dict):
        """Stream responses for real-time output"""
        response = self.session.post(
            url,
            json={**payload, "stream": True},
            stream=True,
            timeout=self.timeout
        )

        for line in response.iter_lines():
            if line:
                yield json.loads(line.decode('utf-8'))

    def get_flow(self, flow_id: str) -> dict:
        """Retrieve flow configuration"""
        url = f"{self.base_url}/api/v1/flows/{flow_id}"
        response = self.session.get(url, timeout=self.timeout)
        response.raise_for_status()
        return response.json()

    def list_flows(self) -> list[dict]:
        """List all available flows"""
        url = f"{self.base_url}/api/v1/flows"
        response = self.session.get(url, timeout=self.timeout)
        response.raise_for_status()
        return response.json()


# 3. USAGE EXAMPLES

# Basic usage
client = LangflowAPIClient(
    base_url="https://api.langflow.app",
    api_key=os.getenv("LANGFLOW_API_KEY")
)

# Run flow
result = client.run_flow(
    flow_id="abc-123",
    inputs={
        "question": "How do I reset my password?",
        "user_id": "12345"
    }
)

print(result["outputs"]["answer"])


# Streaming responses
for chunk in client.run_flow(
    flow_id="abc-123",
    inputs={"question": "Explain quantum computing"},
    stream=True
):
    print(chunk["token"], end="", flush=True)


# With parameter tweaks
result = client.run_flow(
    flow_id="abc-123",
    inputs={"question": "Tell me a joke"},
    tweaks={
        "temperature": 0.9,  # Override default
        "max_tokens": 100
    }
)


# 4. JAVASCRIPT/TYPESCRIPT CLIENT

```javascript
// JavaScript client for Langflow API
class LangflowClient {
    constructor(baseUrl, apiKey, timeout = 30000) {
        this.baseUrl = baseUrl.replace(/\/$/, '');
        this.apiKey = apiKey;
        this.timeout = timeout;
    }

    async runFlow(flowId, inputs, tweaks = {}, stream = false) {
        const url = `${this.baseUrl}/api/v1/run/${flowId}`;

        const payload = {
            inputs,
            tweaks,
            stream
        };

        try {
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), this.timeout);

            const response = await fetch(url, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.apiKey}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(payload),
                signal: controller.signal
            });

            clearTimeout(timeoutId);

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            if (stream) {
                return this._streamResponse(response);
            }

            return await response.json();

        } catch (error) {
            if (error.name === 'AbortError') {
                throw new Error(`Request timed out after ${this.timeout}ms`);
            }
            throw error;
        }
    }

    async *_streamResponse(response) {
        const reader = response.body.getReader();
        const decoder = new TextDecoder();

        while (true) {
            const { done, value } = await reader.read();
            if (done) break;

            const chunk = decoder.decode(value);
            yield JSON.parse(chunk);
        }
    }

    async getFlow(flowId) {
        const url = `${this.baseUrl}/api/v1/flows/${flowId}`;

        const response = await fetch(url, {
            headers: { 'Authorization': `Bearer ${this.apiKey}` }
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }

        return await response.json();
    }
}

// Usage in React
const client = new LangflowClient(
    'https://api.langflow.app',
    process.env.REACT_APP_LANGFLOW_API_KEY
);

const result = await client.runFlow(
    'abc-123',
    { question: 'How do I deploy?' }
);
```


# 5. WEBHOOK INTEGRATION

```python
# Trigger Langflow flow from webhook
from flask import Flask, request, jsonify

app = Flask(__name__)
langflow_client = LangflowAPIClient(
    base_url=os.getenv("LANGFLOW_URL"),
    api_key=os.getenv("LANGFLOW_API_KEY")
)

@app.route('/webhook/process', methods=['POST'])
def process_webhook():
    """Process incoming webhook and trigger Langflow"""
    try:
        # Extract webhook data
        data = request.json

        # Run Langflow flow
        result = langflow_client.run_flow(
            flow_id="webhook-processor",
            inputs={
                "webhook_payload": data,
                "timestamp": datetime.now().isoformat()
            }
        )

        return jsonify({
            "status": "success",
            "result": result
        }), 200

    except Exception as e:
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `base_url` | Required | Langflow API base URL |
| `api_key` | Required | Authentication key |
| `timeout` | 30 | Request timeout (seconds) |
| `max_retries` | 3 | Retry failed requests |
| `backoff_factor` | 2 | Exponential backoff multiplier |

## Example Usage

```bash
# cURL example
curl -X POST https://api.langflow.app/api/v1/run/abc-123 \
  -H "Authorization: Bearer sk_langflow_abc123" \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": {
      "question": "What is Langflow?"
    },
    "tweaks": {
      "temperature": 0.7
    }
  }'

# Response
{
  "outputs": {
    "answer": "Langflow is a visual framework for building LLM applications...",
    "sources": ["https://docs.langflow.org"]
  },
  "execution_time_ms": 1250,
  "flow_id": "abc-123"
}
```

## Error Handling

```python
# Comprehensive error handling
class APIError(Exception):
    """Base exception for API errors"""
    pass

class RateLimitError(APIError):
    """Rate limit exceeded"""
    pass

class AuthenticationError(APIError):
    """Invalid API key"""
    pass

def run_flow_with_retry(client, flow_id, inputs, max_retries=3):
    """Run flow with exponential backoff retry"""
    for attempt in range(max_retries):
        try:
            return client.run_flow(flow_id, inputs)

        except RateLimitError:
            if attempt == max_retries - 1:
                raise
            wait_time = 2 ** attempt  # 1s, 2s, 4s
            time.sleep(wait_time)

        except AuthenticationError:
            # Don't retry auth errors
            raise

        except APIError as e:
            if attempt == max_retries - 1:
                raise
            time.sleep(1)

    raise APIError("Max retries exceeded")
```

## Common Pitfalls

```python
# ❌ Don't: No error handling
result = client.run_flow(flow_id, inputs)  # Can fail

# ✓ Do: Handle errors
try:
    result = client.run_flow(flow_id, inputs)
except RateLimitError:
    # Wait and retry
    pass
except APIError as e:
    # Log and notify
    pass

# ❌ Don't: Hardcoded credentials
client = LangflowClient("https://api.com", "sk_abc123")

# ✓ Do: Use environment variables
client = LangflowClient(
    os.getenv("LANGFLOW_URL"),
    os.getenv("LANGFLOW_API_KEY")
)

# ❌ Don't: No timeout
response = requests.post(url, json=payload)  # Can hang

# ✓ Do: Always set timeout
response = requests.post(url, json=payload, timeout=30)
```

## See Also

- [api-deployment.md](../concepts/api-deployment.md) - Deployment configuration
- [production-deployment.md](../patterns/production-deployment.md) - Production setup
- [mcp-server.md](../concepts/mcp-server.md) - MCP integration

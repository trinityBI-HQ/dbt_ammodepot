# Custom Components

> **Purpose**: Create reusable custom components to extend Langflow functionality
> **MCP Validated**: 2026-02-06

## When to Use

- Need domain-specific logic not available in built-in components
- Want to encapsulate complex multi-step operations
- Building reusable component library for your team
- Integrating proprietary APIs or internal services

## Implementation

```python
# Method 1: Class-Based Component
from langflow import CustomComponent
from langchain.schema import Document

class CustomDocumentProcessor(CustomComponent):
    display_name = "Custom Document Processor"
    description = "Processes documents with custom business rules"

    def build_config(self):
        return {
            "documents": {"display_name": "Documents", "type": "Document", "required": True, "list": True},
            "filter_keyword": {"display_name": "Filter Keyword", "type": "str", "default": ""},
            "min_length": {"display_name": "Minimum Length", "type": "int", "default": 100},
            "output_format": {"display_name": "Output Format", "type": "str", "default": "text",
                              "options": ["text", "json", "markdown"]}
        }

    def build(self, documents: list[Document], filter_keyword: str = "",
              min_length: int = 100, output_format: str = "text") -> list[Document]:
        processed = []
        for doc in documents:
            if filter_keyword and filter_keyword.lower() not in doc.page_content.lower():
                continue
            if len(doc.page_content) < min_length:
                continue
            processed.append(Document(
                page_content=doc.page_content,
                metadata={**doc.metadata, "processed": True, "original_length": len(doc.page_content)}
            ))
        return processed


# Method 2: Decorator-Based Component
from langflow.custom import component
from langflow.inputs import StrInput, IntInput, SecretStrInput
from langflow.template import Output

@component(display_name="API Data Fetcher", description="Fetches data from custom API", icon="download")
class APIDataFetcher:
    inputs = [
        StrInput(name="api_endpoint", display_name="API Endpoint", required=True),
        SecretStrInput(name="api_key", display_name="API Key", required=True),
        IntInput(name="timeout", display_name="Timeout (seconds)", value=30)
    ]
    outputs = [Output(display_name="Data", name="data", method="fetch_data")]

    def fetch_data(self) -> dict:
        import requests
        try:
            response = requests.get(
                self.api_endpoint,
                headers={"Authorization": f"Bearer {self.api_key}"},
                timeout=self.timeout
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            self.status = f"Error: {str(e)}"
            return {"error": str(e)}
```

## Configuration

| Setting | Type | Description |
|---------|------|-------------|
| `display_name` | str | Component name in UI |
| `description` | str | Short description |
| `icon` | str | Icon name for UI |
| `build_config()` | method | Define inputs/outputs |
| `build()` | method | Main component logic |

## Input Types

```python
from langflow.inputs import (
    StrInput, IntInput, FloatInput, BoolInput, DictInput,
    FileInput, DropdownInput, MessageTextInput, SecretStrInput
)

# Example: Dropdown
DropdownInput(name="model", options=["gpt-4", "claude-3-5-sonnet", "gemini-pro"], value="gpt-4")
```

## Error Handling

```python
class RobustComponent(CustomComponent):
    def build(self, input_data: str):
        try:
            result = self._process(input_data)
            self.status = "Processing complete"
            return result
        except ValueError as e:
            self.status = f"Invalid input: {str(e)}"
            return {"error": "invalid_input", "message": str(e)}
        except Exception as e:
            self.status = f"Error: {str(e)}"
            return {"error": "processing_failed", "message": str(e)}
```

## Testing

```python
def test_custom_document_processor():
    processor = CustomDocumentProcessor()
    documents = [
        Document(page_content="Short", metadata={}),
        Document(page_content="This is a longer text that passes the minimum length filter", metadata={})
    ]
    result = processor.build(documents=documents, min_length=50)
    assert len(result) == 1
    assert result[0].metadata["processed"] is True
```

## Common Pitfalls

```python
# Always set timeouts on external calls
# Always handle errors and update self.status
# Use SecretStrInput (password=True) for API keys, never hardcode
```

## See Also

- [flows-components.md](../concepts/flows-components.md) - Component fundamentals
- [api-integration.md](../patterns/api-integration.md) - API integration patterns

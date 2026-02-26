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
# Create custom component in Langflow

# Method 1: Python Class Component
from langflow import CustomComponent
from langchain.schema import Document

class CustomDocumentProcessor(CustomComponent):
    """
    Custom component for processing documents with domain-specific logic.
    """

    display_name = "Custom Document Processor"
    description = "Processes documents with custom business rules"
    documentation = "https://docs.example.com/custom-processor"

    def build_config(self):
        """Define component inputs and configuration"""
        return {
            "documents": {
                "display_name": "Documents",
                "type": "Document",
                "required": True,
                "list": True
            },
            "filter_keyword": {
                "display_name": "Filter Keyword",
                "type": "str",
                "required": False,
                "default": ""
            },
            "min_length": {
                "display_name": "Minimum Length",
                "type": "int",
                "required": False,
                "default": 100
            },
            "output_format": {
                "display_name": "Output Format",
                "type": "str",
                "required": False,
                "default": "text",
                "options": ["text", "json", "markdown"]
            }
        }

    def build(
        self,
        documents: list[Document],
        filter_keyword: str = "",
        min_length: int = 100,
        output_format: str = "text"
    ) -> list[Document]:
        """
        Process documents according to business rules.

        Args:
            documents: Input documents to process
            filter_keyword: Filter documents containing this keyword
            min_length: Minimum document length to keep
            output_format: Output format for processed documents

        Returns:
            Processed documents
        """
        processed = []

        for doc in documents:
            # Apply filtering
            if filter_keyword and filter_keyword.lower() not in doc.page_content.lower():
                continue

            # Apply length filter
            if len(doc.page_content) < min_length:
                continue

            # Apply custom processing
            processed_content = self._custom_processing(
                doc.page_content,
                output_format
            )

            # Create new document with processed content
            processed_doc = Document(
                page_content=processed_content,
                metadata={
                    **doc.metadata,
                    "processed": True,
                    "original_length": len(doc.page_content),
                    "processed_length": len(processed_content)
                }
            )

            processed.append(processed_doc)

        return processed

    def _custom_processing(self, content: str, format: str) -> str:
        """Apply domain-specific processing logic"""
        # Example: Remove PII, standardize format, etc.
        # ... custom logic here ...
        return content


# Method 2: Function-Based Component
from langflow.custom import component
from langflow.inputs import StrInput, IntInput
from langflow.template import Output

@component(
    display_name="API Data Fetcher",
    description="Fetches data from custom API endpoint",
    icon="download"
)
class APIDataFetcher:
    inputs = [
        StrInput(
            name="api_endpoint",
            display_name="API Endpoint",
            required=True
        ),
        StrInput(
            name="api_key",
            display_name="API Key",
            required=True,
            password=True  # Hide in UI
        ),
        IntInput(
            name="timeout",
            display_name="Timeout (seconds)",
            value=30
        )
    ]

    outputs = [
        Output(
            display_name="Data",
            name="data",
            method="fetch_data"
        )
    ]

    def fetch_data(self) -> dict:
        """Fetch data from API"""
        import requests

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        try:
            response = requests.get(
                self.api_endpoint,
                headers=headers,
                timeout=self.timeout
            )
            response.raise_for_status()
            return response.json()

        except requests.exceptions.RequestException as e:
            self.status = f"Error: {str(e)}"
            return {"error": str(e)}


# Method 3: Group Multiple Components
class RAGComponentGroup(CustomComponent):
    """
    Reusable RAG component group.
    Combines loader, splitter, embeddings, vector store.
    """

    display_name = "RAG Pipeline"
    description = "Complete RAG indexing pipeline"

    def build_config(self):
        return {
            "documents_path": {"type": "str", "required": True},
            "chunk_size": {"type": "int", "default": 1000},
            "vector_store_name": {"type": "str", "default": "pinecone"}
        }

    def build(
        self,
        documents_path: str,
        chunk_size: int = 1000,
        vector_store_name: str = "pinecone"
    ):
        """Build complete RAG pipeline"""
        # Load documents
        loader = self._get_loader(documents_path)
        documents = loader.load()

        # Split text
        splitter = self._get_splitter(chunk_size)
        chunks = splitter.split_documents(documents)

        # Create embeddings and store
        vector_store = self._get_vector_store(vector_store_name)
        vector_store.add_documents(chunks)

        return {
            "documents_loaded": len(documents),
            "chunks_created": len(chunks),
            "vector_store": vector_store
        }
```

## Configuration

| Setting | Type | Description |
|---------|------|-------------|
| `display_name` | str | Component name in UI |
| `description` | str | Short description |
| `icon` | str | Icon name for UI |
| `documentation` | str | URL to docs |
| `build_config()` | method | Define inputs/outputs |
| `build()` | method | Main component logic |

## Example Usage

```python
# Use custom component in flow

# Add to flow via UI
# 1. Go to "Custom Components" in sidebar
# 2. Import your Python file
# 3. Drag custom component to canvas
# 4. Configure parameters
# 5. Connect to other components

# Or programmatically
from langflow import load_flow_from_json

flow = load_flow_from_json("my_flow.json")
custom_processor = flow.get_component("custom_document_processor")

result = custom_processor.build(
    documents=documents,
    filter_keyword="important",
    min_length=200,
    output_format="json"
)
```

## Input Types

```python
# Available input types for custom components

from langflow.inputs import (
    StrInput,      # String input
    IntInput,      # Integer input
    FloatInput,    # Float input
    BoolInput,     # Boolean checkbox
    DictInput,     # JSON dictionary
    FileInput,     # File upload
    DropdownInput, # Dropdown select
    MessageTextInput,  # Large text area
    SecretStrInput     # Password field
)

# Example: Dropdown with options
inputs = [
    DropdownInput(
        name="model_name",
        display_name="Model",
        options=["gpt-4", "claude-3-5-sonnet", "gemini-pro"],
        value="gpt-4"
    )
]
```

## Output Types

```python
# Define multiple outputs
from langflow.template import Output

outputs = [
    Output(
        display_name="Processed Text",
        name="text",
        method="process_text"
    ),
    Output(
        display_name="Metadata",
        name="metadata",
        method="extract_metadata"
    ),
    Output(
        display_name="Statistics",
        name="stats",
        method="calculate_stats"
    )
]

# Each output can be connected to different components
```

## Error Handling

```python
class RobustCustomComponent(CustomComponent):
    """Component with comprehensive error handling"""

    def build(self, input_data: str):
        try:
            # Main logic
            result = self._process(input_data)

            # Update status (shows in UI)
            self.status = "✓ Processing complete"

            return result

        except ValueError as e:
            self.status = f"⚠ Invalid input: {str(e)}"
            return {"error": "invalid_input", "message": str(e)}

        except Exception as e:
            self.status = f"✗ Error: {str(e)}"
            self.log(f"Unexpected error: {str(e)}")
            return {"error": "processing_failed", "message": str(e)}

    def _process(self, data: str):
        """Main processing logic with validation"""
        if not data:
            raise ValueError("Input data cannot be empty")

        # Processing...
        return processed_data
```

## Testing Custom Components

```python
# Unit test for custom component
import pytest
from langflow.schema import Document

def test_custom_document_processor():
    """Test custom document processor"""
    processor = CustomDocumentProcessor()

    # Test data
    documents = [
        Document(page_content="Short text", metadata={"source": "test"}),
        Document(page_content="This is a much longer text that should pass the minimum length filter", metadata={"source": "test"})
    ]

    # Execute
    result = processor.build(
        documents=documents,
        filter_keyword="",
        min_length=50,
        output_format="text"
    )

    # Assertions
    assert len(result) == 1  # Only long document passes
    assert result[0].metadata["processed"] is True
    assert "original_length" in result[0].metadata


# Integration test in Langflow
def test_in_flow():
    """Test component in actual flow"""
    from langflow import load_flow_from_json

    flow = load_flow_from_json("test_flow.json")
    result = flow.run({"input": "test data"})

    assert result["output"] is not None
    assert "error" not in result
```

## Packaging for Distribution

```python
# Component metadata for sharing
# custom_components/
# ├── __init__.py
# ├── document_processor.py
# ├── api_fetcher.py
# ├── requirements.txt
# └── README.md

# requirements.txt
langflow>=1.0.0
requests>=2.31.0
pandas>=2.0.0

# README.md with usage instructions
# Include examples and configuration guide
```

## Common Pitfalls

```python
# ❌ Don't: Blocking operations without timeout
def build(self):
    result = requests.get(url)  # No timeout, can hang

# ✓ Do: Always set timeouts
def build(self):
    result = requests.get(url, timeout=30)

# ❌ Don't: Ignore error cases
def build(self, data):
    return process(data)  # What if it fails?

# ✓ Do: Handle errors gracefully
def build(self, data):
    try:
        return process(data)
    except Exception as e:
        self.status = f"Error: {e}"
        return None

# ❌ Don't: Hardcode configuration
API_KEY = "sk-abc123..."  # Security risk

# ✓ Do: Use inputs with password=True
inputs = [StrInput(name="api_key", password=True)]
```

## See Also

- [flows-components.md](../concepts/flows-components.md) - Component fundamentals
- [api-integration.md](../patterns/api-integration.md) - API integration patterns
- [langchain-integration.md](../patterns/langchain-integration.md) - LangChain components

# LangChain Integration

> **Purpose**: Leverage LangChain components and patterns within Langflow visual workflows
> **MCP Validated**: 2026-02-06

## When to Use

- Need advanced LangChain features (chains, memory, callbacks)
- Migrating existing LangChain code to Langflow
- Building complex chains with custom LangChain components

## Implementation

```python
# 1. CHAINS
from langchain.chains import LLMChain, SequentialChain
from langchain.prompts import PromptTemplate

llm_chain_config = {
    "type": "LLMChain",
    "llm": {"type": "OpenAI", "model_name": "gpt-4", "temperature": 0.7},
    "prompt": {
        "type": "PromptTemplate",
        "template": "Translate the following to {language}: {text}",
        "input_variables": ["language", "text"]
    }
}

sequential_chain_config = {
    "type": "SequentialChain",
    "chains": [
        {"chain": "summarization_chain", "output_variables": ["summary"]},
        {"chain": "sentiment_chain", "input_variables": ["summary"], "output_variables": ["sentiment"]},
        {"chain": "recommendation_chain", "input_variables": ["summary", "sentiment"], "output_variables": ["recommendation"]}
    ],
    "input_variables": ["text"],
    "output_variables": ["recommendation"]
}


# 2. MEMORY
from langchain.memory import ConversationBufferMemory, ConversationSummaryMemory

memory_config = {
    "type": "ConversationBufferMemory",
    "memory_key": "chat_history",
    "return_messages": True
}

summary_memory_config = {
    "type": "ConversationSummaryMemory",
    "llm": openai_llm,
    "max_token_limit": 2000  # Summarize when exceeded
}


# 3. RETRIEVERS
retriever_config = {
    "type": "VectorStoreRetriever",
    "search_type": "mmr",
    "search_kwargs": {"k": 5, "fetch_k": 20, "lambda_mult": 0.5}
}

multi_query_config = {
    "type": "MultiQueryRetriever",
    "retriever": base_retriever,
    "llm": openai_llm
}

compression_config = {
    "type": "ContextualCompressionRetriever",
    "base_retriever": base_retriever,
    "base_compressor": {"type": "LLMChainExtractor", "llm": openai_llm}
}


# 4. AGENTS
from langchain.agents import AgentType

agent_config = {
    "type": "Agent",
    "agent_type": AgentType.ZERO_SHOT_REACT_DESCRIPTION,
    "llm": openai_llm,
    "tools": [search_tool, calculator_tool],
    "max_iterations": 5,
    "early_stopping_method": "force"
}


# 5. CALLBACKS (monitoring)
from langchain.callbacks.base import BaseCallbackHandler

class LangflowCallbackHandler(BaseCallbackHandler):
    def on_llm_start(self, serialized, prompts, **kwargs):
        print(f"LLM started with {len(prompts)} prompts")
    def on_chain_start(self, serialized, inputs, **kwargs):
        print(f"Chain started: {serialized.get('name')}")
    def on_chain_end(self, outputs, **kwargs):
        print(f"Chain completed: {outputs}")


# 6. COMPLETE RAG FLOW
langchain_rag_flow = {
    "components": [
        {"name": "retriever", "type": "MultiQueryRetriever", "llm": openai_llm},
        {"name": "memory", "type": "ConversationBufferMemory"},
        {"name": "qa_chain", "type": "ConversationalRetrievalChain",
         "retriever": "retriever", "memory": "memory", "llm": openai_llm}
    ],
    "connections": [
        {"from": "retriever", "to": "qa_chain"},
        {"from": "memory", "to": "qa_chain"}
    ]
}
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `chain_type` | stuff | How to combine docs (stuff/map_reduce/refine) |
| `memory_type` | buffer | Memory type (buffer/summary/window) |
| `search_type` | similarity | Retrieval strategy (similarity/mmr/threshold) |
| `verbose` | False | Log chain execution |
| `callbacks` | [] | Callback handlers for monitoring |

## Example Usage

```python
from langflow import Flow

flow = Flow.from_components([vector_store, retriever, memory, qa_chain])
result = flow.run({"question": "What is the capital of France?"})
# Follow-up with memory
result2 = flow.run({"question": "What's its population?", "chat_history": result["chat_history"]})
```

## LangChain vs Langflow

| Feature | LangChain | Langflow |
|---------|-----------|----------|
| Visual building | No | Yes |
| Code flexibility | High | Medium |
| Component library | 100+ | 50+ |
| Learning curve | Steep | Gentle |

## Common Pitfalls

```python
# Always provide memory for ConversationalRetrievalChain
# Always persist memory state between runs with memory.save_context()
# Use callbacks (not verbose=True) for production logging
```

## See Also

- [agents-tools.md](../concepts/agents-tools.md) - Agent components
- [vector-rag-chatbot.md](../patterns/vector-rag-chatbot.md) - RAG patterns

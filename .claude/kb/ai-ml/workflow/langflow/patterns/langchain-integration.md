# LangChain Integration

> **Purpose**: Leverage LangChain components and patterns within Langflow visual workflows
> **MCP Validated**: 2026-02-06

## When to Use

- Need advanced LangChain features (chains, memory, callbacks)
- Migrating existing LangChain code to Langflow
- Want to combine LangChain's flexibility with Langflow's visual editor
- Building complex chains with custom LangChain components

## Implementation

```python
# LangChain components in Langflow

# 1. LANGCHAIN CHAINS

# Simple LLM Chain
from langchain.chains import LLMChain
from langchain.prompts import PromptTemplate
from langchain.llms import OpenAI

llm_chain_component = {
    "type": "LLMChain",
    "llm": {
        "type": "OpenAI",
        "model_name": "gpt-4",
        "temperature": 0.7,
        "api_key": "${OPENAI_API_KEY}"
    },
    "prompt": {
        "type": "PromptTemplate",
        "template": "Translate the following to {language}: {text}",
        "input_variables": ["language", "text"]
    },
    "output_key": "translation"
}


# Sequential Chain (multiple steps)
from langchain.chains import SequentialChain

sequential_chain = {
    "type": "SequentialChain",
    "chains": [
        {
            "chain": "summarization_chain",
            "input_variables": ["text"],
            "output_variables": ["summary"]
        },
        {
            "chain": "sentiment_chain",
            "input_variables": ["summary"],
            "output_variables": ["sentiment"]
        },
        {
            "chain": "recommendation_chain",
            "input_variables": ["summary", "sentiment"],
            "output_variables": ["recommendation"]
        }
    ],
    "input_variables": ["text"],
    "output_variables": ["recommendation"]
}


# 2. LANGCHAIN MEMORY

# Conversation Buffer Memory
from langchain.memory import ConversationBufferMemory

memory_component = {
    "type": "ConversationBufferMemory",
    "memory_key": "chat_history",
    "return_messages": True,
    "input_key": "question",
    "output_key": "answer"
}

# Conversation with memory chain
conversational_chain = {
    "type": "ConversationalRetrievalChain",
    "retriever": vector_store_retriever,
    "memory": memory_component,
    "llm": openai_llm,
    "return_source_documents": True
}


# Summary Memory (for long conversations)
from langchain.memory import ConversationSummaryMemory

summary_memory = {
    "type": "ConversationSummaryMemory",
    "llm": openai_llm,
    "memory_key": "chat_history",
    "max_token_limit": 2000  # Summarize when exceeded
}


# 3. LANGCHAIN RETRIEVERS

# Vector Store Retriever with MMR
from langchain.retrievers import VectorStoreRetriever

retriever_component = {
    "type": "VectorStoreRetriever",
    "vectorstore": pinecone_vector_store,
    "search_type": "mmr",  # Maximum Marginal Relevance
    "search_kwargs": {
        "k": 5,
        "fetch_k": 20,
        "lambda_mult": 0.5  # Diversity vs relevance
    }
}


# Multi-Query Retriever
from langchain.retrievers.multi_query import MultiQueryRetriever

multi_query_retriever = {
    "type": "MultiQueryRetriever",
    "retriever": base_retriever,
    "llm": openai_llm,
    "parser_key": "lines"  # Parse multiple queries
}


# Contextual Compression Retriever
from langchain.retrievers import ContextualCompressionRetriever
from langchain.retrievers.document_compressors import LLMChainExtractor

compression_retriever = {
    "type": "ContextualCompressionRetriever",
    "base_retriever": base_retriever,
    "base_compressor": {
        "type": "LLMChainExtractor",
        "llm": openai_llm
    }
}


# 4. LANGCHAIN DOCUMENT TRANSFORMERS

# Embedding Redundant Filter
from langchain.retrievers.document_compressors import EmbeddingsFilter

embeddings_filter = {
    "type": "EmbeddingsFilter",
    "embeddings": openai_embeddings,
    "similarity_threshold": 0.76,
    "k": 5  # Top k after filtering
}


# Document Compressor Pipeline
from langchain.retrievers.document_compressors import DocumentCompressorPipeline

compressor_pipeline = {
    "type": "DocumentCompressorPipeline",
    "transformers": [
        embeddings_filter,
        {
            "type": "EmbeddingsRedundantFilter",
            "embeddings": openai_embeddings
        },
        {
            "type": "LLMChainExtractor",
            "llm": openai_llm
        }
    ]
}


# 5. LANGCHAIN AGENTS (Advanced)

# Zero-Shot React Agent
from langchain.agents import initialize_agent, AgentType

agent_component = {
    "type": "Agent",
    "agent_type": AgentType.ZERO_SHOT_REACT_DESCRIPTION,
    "llm": openai_llm,
    "tools": [
        search_tool,
        calculator_tool,
        python_repl_tool
    ],
    "max_iterations": 5,
    "early_stopping_method": "force",
    "verbose": True
}


# Structured Chat Agent (for chat models)
structured_agent = {
    "type": "Agent",
    "agent_type": AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
    "llm": {
        "type": "ChatOpenAI",
        "model": "gpt-4",
        "temperature": 0
    },
    "tools": tools_list,
    "memory": conversational_memory
}


# 6. LANGCHAIN CALLBACKS

# Custom callback for monitoring
from langchain.callbacks.base import BaseCallbackHandler

class LangflowCallbackHandler(BaseCallbackHandler):
    """Custom callback for Langflow integration"""

    def on_llm_start(self, serialized, prompts, **kwargs):
        """Log LLM calls"""
        print(f"LLM started with {len(prompts)} prompts")

    def on_llm_end(self, response, **kwargs):
        """Log LLM completion"""
        print(f"LLM completed: {response.llm_output}")

    def on_chain_start(self, serialized, inputs, **kwargs):
        """Log chain execution"""
        print(f"Chain started: {serialized.get('name')}")

    def on_chain_end(self, outputs, **kwargs):
        """Log chain completion"""
        print(f"Chain completed with outputs: {outputs}")

callback_handler = LangflowCallbackHandler()


# 7. COMPLETE LANGCHAIN RAG FLOW

langchain_rag_flow = {
    "components": [
        {
            "name": "vector_store",
            "type": "Pinecone",
            "config": pinecone_config
        },
        {
            "name": "retriever",
            "type": "MultiQueryRetriever",
            "vectorstore": "vector_store",
            "llm": openai_llm
        },
        {
            "name": "compression",
            "type": "ContextualCompressionRetriever",
            "base_retriever": "retriever",
            "compressor": compressor_pipeline
        },
        {
            "name": "memory",
            "type": "ConversationBufferMemory",
            "memory_key": "chat_history"
        },
        {
            "name": "qa_chain",
            "type": "ConversationalRetrievalChain",
            "retriever": "compression",
            "memory": "memory",
            "llm": openai_llm,
            "callbacks": [callback_handler]
        }
    ],
    "connections": [
        {"from": "vector_store", "to": "retriever"},
        {"from": "retriever", "to": "compression"},
        {"from": "compression", "to": "qa_chain"},
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
# Using LangChain components in Langflow

# 1. Create flow with LangChain components
from langflow import Flow

flow = Flow.from_components([
    vector_store_component,
    retriever_component,
    memory_component,
    qa_chain_component
])

# 2. Execute flow
result = flow.run({
    "question": "What is the capital of France?",
    "chat_history": []
})

print(result["answer"])
# Output: "The capital of France is Paris."

# 3. With memory (follow-up question)
result2 = flow.run({
    "question": "What's its population?",
    "chat_history": result["chat_history"]
})

print(result2["answer"])
# Output: "Paris has a population of approximately 2.2 million..."
```

## LangChain vs Langflow Components

| Feature | LangChain | Langflow | Best Choice |
|---------|-----------|----------|-------------|
| **Visual building** | No | Yes | Langflow for prototyping |
| **Code flexibility** | High | Medium | LangChain for custom logic |
| **Built-in UI** | No | Yes | Langflow for demos |
| **Component library** | 100+ | 50+ | LangChain for variety |
| **Learning curve** | Steep | Gentle | Langflow for beginners |

## Migration from LangChain

```python
# Before (pure LangChain)
from langchain.chains import RetrievalQA
from langchain.llms import OpenAI
from langchain.vectorstores import Pinecone

llm = OpenAI(temperature=0)
vectorstore = Pinecone.from_existing_index("my-index")
qa = RetrievalQA.from_chain_type(
    llm=llm,
    retriever=vectorstore.as_retriever(),
    chain_type="stuff"
)

result = qa.run("What is Langflow?")

# After (Langflow visual flow)
# 1. Drag OpenAI LLM component
# 2. Drag Pinecone vector store component
# 3. Drag RetrievalQA chain component
# 4. Connect: Pinecone → RetrievalQA, OpenAI → RetrievalQA
# 5. Test in playground

# Code still accessible for customization
```

## Common Pitfalls

```python
# ❌ Don't: Mix incompatible chain types
chain = ConversationalRetrievalChain(
    memory=None,  # Requires memory!
    retriever=retriever
)

# ✓ Do: Provide required components
chain = ConversationalRetrievalChain(
    memory=ConversationBufferMemory(),
    retriever=retriever
)

# ❌ Don't: Forget to handle memory state
# Memory not persisted between runs
result = qa_chain.run(question)

# ✓ Do: Manage memory properly
memory.save_context({"input": question}, {"output": result})

# ❌ Don't: Use verbose=True in production
agent = initialize_agent(tools, llm, verbose=True)  # Logs everything

# ✓ Do: Use callbacks for production logging
agent = initialize_agent(
    tools,
    llm,
    callbacks=[production_callback]
)
```

## See Also

- [agents-tools.md](../concepts/agents-tools.md) - Agent components
- [vector-stores.md](../concepts/vector-stores.md) - Vector store integration
- [vector-rag-chatbot.md](../patterns/vector-rag-chatbot.md) - RAG patterns

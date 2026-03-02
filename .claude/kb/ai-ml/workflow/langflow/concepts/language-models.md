# Language Models

> **Purpose**: LLM integration, prompt templates, and model configuration for text generation
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-06

## Overview

Language models are the core AI components in Langflow for text generation, question answering, and powering agents. Langflow supports multiple providers through unified interfaces, enabling easy model switching.

## Supported Providers

| Provider | Models | Use Case |
|----------|--------|----------|
| **OpenAI** | GPT-4, GPT-3.5 | General purpose, function calling |
| **Anthropic** | Claude 3.5 Sonnet, Opus | Long context, reasoning |
| **Google** | Gemini Pro, Flash | Multimodal, cost-effective |
| **Ollama** | Llama 3, Mistral | Local, private |
| **HuggingFace** | Any HF model | Open source models |
| **Azure OpenAI** | GPT-4, GPT-3.5 | Enterprise compliance |

## Model Configuration

```python
openai_config = {
    "model": "gpt-4", "api_key": "${OPENAI_API_KEY}",
    "temperature": 0.7, "max_tokens": 500, "top_p": 0.9,
    "frequency_penalty": 0.0, "presence_penalty": 0.0, "streaming": True
}

claude_config = {
    "model": "claude-3-5-sonnet-20241022", "api_key": "${ANTHROPIC_API_KEY}",
    "temperature": 0.5, "max_tokens": 4096,
    "system": "You are a helpful assistant"
}
```

## Prompt Templates

```python
# Basic
prompt = {"template": "Answer the question: {question}", "input_variables": ["question"]}

# RAG with context
rag_prompt = {"template": "Use the context to answer.\n\nContext:\n{context}\n\nQuestion: {question}\n\nAnswer:", "input_variables": ["context", "question"]}

# Chain of thought
cot_prompt = {"template": "Question: {question}\n\nLet's think step by step:\n1. First...\n2. Then...\n3. Finally...\n\nAnswer:", "input_variables": ["question"]}
```

## Model Selection Strategy

| Use Case | Recommended Model | Reasoning |
|----------|------------------|-----------|
| **Quick answers** | GPT-3.5, Gemini Flash | Fast, cost-effective |
| **Complex reasoning** | GPT-4, Claude Opus | Better accuracy |
| **Long documents** | Claude models | 200K context window |
| **Private data** | Ollama (local) | No data leaves server |
| **Multimodal** | Gemini, GPT-4V | Image understanding |

## Common Mistakes

```python
# Wrong: high temp for facts, no limit, vague prompt
factual_task.temperature = 1.0
model.max_tokens = None
prompt = "Do something with {input}"

# Correct: low temp, token limit, specific prompt
factual_task.temperature = 0.2
model.max_tokens = 1000
prompt = "Summarize the following text in 3 sentences: {text}"
```

## Streaming & Token Management

```python
# Streaming: set streaming=True for real-time output, lower perceived latency
# Token estimation
from tiktoken import encoding_for_model
enc = encoding_for_model("gpt-4")
total_tokens = len(enc.encode(prompt)) + max_response_tokens
cost = (total_tokens / 1000) * cost_per_1k
```

## Output Formatting

```python
json_prompt = {
    "template": "Extract info as JSON:\n\nText: {text}\n\nJSON (name, age, city):",
    "output_parser": "json"
}
```

## Fallback & Rate Limiting

```python
# Fallback chain: gpt-4 → gpt-3.5-turbo → ollama/llama3
# Rate limiting
rate_config = {"max_requests_per_minute": 60, "max_tokens_per_minute": 150000, "exponential_backoff": True}
```

## Related

- [agents-tools.md](../concepts/agents-tools.md) - Using LLMs in agents
- [vector-stores.md](../concepts/vector-stores.md) - RAG with LLMs
- [langchain-integration.md](../patterns/langchain-integration.md) - LangChain components

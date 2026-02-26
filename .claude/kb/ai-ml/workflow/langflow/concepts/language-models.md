# Language Models

> **Purpose**: LLM integration, prompt templates, and model configuration for text generation
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-06

## Overview

Language models are the core AI components in Langflow that generate text, answer questions, and power agents. Langflow supports multiple LLM providers through unified interfaces, enabling easy switching between models. Configuration includes model selection, prompt engineering, parameters like temperature, and output formatting.

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
# OpenAI component
openai_config = {
    "model": "gpt-4",
    "api_key": "${OPENAI_API_KEY}",
    "temperature": 0.7,  # 0=deterministic, 1=creative
    "max_tokens": 500,  # Response length limit
    "top_p": 0.9,  # Nucleus sampling
    "frequency_penalty": 0.0,  # Reduce repetition
    "presence_penalty": 0.0,  # Encourage new topics
    "streaming": True  # Real-time response
}

# Anthropic component
claude_config = {
    "model": "claude-3-5-sonnet-20241022",
    "api_key": "${ANTHROPIC_API_KEY}",
    "temperature": 0.5,
    "max_tokens": 4096,
    "system": "You are a helpful assistant"  # System prompt
}
```

## Prompt Templates

```python
# Basic template
prompt_template = {
    "template": "Answer the question: {question}",
    "input_variables": ["question"]
}

# RAG template with context
rag_template = {
    "template": """
Use the following context to answer the question.

Context:
{context}

Question: {question}

Answer:""",
    "input_variables": ["context", "question"]
}

# Few-shot template
few_shot_template = {
    "template": """
Example 1:
Q: What is 2+2?
A: 4

Example 2:
Q: What is the capital of France?
A: Paris

Now answer:
Q: {question}
A:""",
    "input_variables": ["question"]
}
```

## Chain of Thought

```python
# Encourage step-by-step reasoning
cot_template = {
    "template": """
Question: {question}

Let's think step by step:
1. First, I need to...
2. Then, I should...
3. Finally, I can conclude...

Answer:""",
    "input_variables": ["question"]
}

# Improves accuracy for complex reasoning
```

## Streaming Responses

```python
# Enable streaming for real-time output
stream_config = {
    "streaming": True,
    "callback_handler": stream_callback
}

# Benefits:
# - Better user experience (see output as generated)
# - Lower perceived latency
# - Can cancel long generations
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

### Wrong

```python
# Temperature too high for factual tasks
factual_task.temperature = 1.0  # Too random

# No max_tokens limit
model.max_tokens = None  # Can exceed budget

# Vague prompt
prompt = "Do something with {input}"  # Ambiguous
```

### Correct

```python
# Low temperature for factual tasks
factual_task.temperature = 0.2

# Reasonable token limit
model.max_tokens = 1000

# Clear, specific prompt
prompt = "Summarize the following text in 3 sentences: {text}"
```

## Token Management

```python
# Estimate token usage
from tiktoken import encoding_for_model

enc = encoding_for_model("gpt-4")
prompt_tokens = len(enc.encode(prompt))
max_response_tokens = 500
total_tokens = prompt_tokens + max_response_tokens

# Cost calculation
cost_per_1k_tokens = 0.03  # Example rate
estimated_cost = (total_tokens / 1000) * cost_per_1k_tokens
```

## Output Formatting

```python
# JSON output for structured data
json_prompt = {
    "template": """
Extract information and return as JSON:

Text: {text}

JSON (name, age, city):""",
    "output_parser": "json"
}

# Response validation
# Ensure model returns valid format
```

## Fallback Strategy

```python
# Multiple model fallback
primary_model = "gpt-4"
fallback_model = "gpt-3.5-turbo"
local_fallback = "ollama/llama3"

# If primary fails or rate limited:
# 1. Try fallback_model
# 2. Try local_fallback
# 3. Return error message
```

## Rate Limiting

```python
# Handle API rate limits
rate_limit_config = {
    "max_requests_per_minute": 60,
    "max_tokens_per_minute": 150000,
    "retry_after_seconds": 20,
    "exponential_backoff": True
}

# Automatically retry with backoff
```

## Model Comparison

```python
# Test multiple models for same task
models_to_test = ["gpt-4", "claude-3-5-sonnet", "gemini-pro"]

results = {}
for model in models_to_test:
    response = model.generate(prompt)
    results[model] = {
        "output": response.text,
        "tokens": response.tokens,
        "latency": response.latency,
        "cost": response.cost
    }

# Compare quality, speed, cost
```

## Related

- [agents-tools.md](../concepts/agents-tools.md) - Using LLMs in agents
- [vector-stores.md](../concepts/vector-stores.md) - RAG with LLMs
- [langchain-integration.md](../patterns/langchain-integration.md) - LangChain components

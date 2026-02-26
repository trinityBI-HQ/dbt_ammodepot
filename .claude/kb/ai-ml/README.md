# AI/ML Knowledge Base

> **Last Updated:** 2026-02-19
> **Maintained By:** Claude Code Lab Team

## Overview

The AI/ML category covers production-grade LLM applications, multi-agent systems, and AI observability. This KB focuses on **building reliable AI systems** with proper monitoring, validation, and orchestration—not research or model training.

## Philosophy

**Build AI systems that are:**
- **Observable**: Track every LLM call, cost, latency, and error
- **Validated**: Structured outputs with type safety (Pydantic)
- **Resilient**: Fallback models, retries, error handling
- **Cost-effective**: Route to the right model for each task

**Avoid:**
- ❌ Unmonitored LLM calls (how do you debug?)
- ❌ String-based outputs (use structured JSON)
- ❌ Single-model dependency (what if it goes down?)
- ❌ No cost tracking (surprised by bills?)

## Categories

### 🤖 LLM Platforms

**Technologies:** [Gemini](llm-platforms/gemini/), [OpenRouter](llm-platforms/openrouter/)

**What it does:** Access LLMs for text, vision, and multimodal tasks.

**When to use:**
- **Gemini**: Multimodal (text + images), Google Vertex AI integration, large context windows
- **OpenRouter**: Model routing, fallback strategies, access to 400+ models

**Key capabilities:**
- **Gemini**: Native vision, JSON mode, function calling, affordable pricing
- **OpenRouter**: Unified API, automatic fallbacks, cost optimization routing

**Decision guide:**
| Use Case | Recommended |
|----------|-------------|
| Document/invoice extraction | **Gemini 2.0 Flash** (vision + structured output) |
| Chat applications | **OpenRouter** (fallback routing across providers) |
| Large document analysis | **Gemini 1.5 Pro** (2M token context) |
| Cost-sensitive tasks | **OpenRouter** (route to cheapest model) |

### 📊 Observability

**Technologies:** [LangFuse](observability/langfuse/)

**What it does:** LLMOps platform for tracing, monitoring, and optimizing LLM applications.

**When to use:**
- Debugging production LLM issues
- Tracking costs across models and prompts
- Monitoring latency and error rates
- Analyzing prompt performance over time

**Key capabilities:**
- Distributed tracing (chain-of-calls)
- Cost tracking by model, user, and session
- Prompt versioning and A/B testing
- Integration with LangChain, LlamaIndex, custom code

**Metrics to track:**
- Latency (p50, p95, p99)
- Cost per request/user/day
- Error rates by model
- Token usage (input/output)

### ✅ Validation

**Technologies:** [Pydantic](validation/pydantic/)

**What it does:** Type-safe data validation for LLM outputs.

**When to use:**
- Parsing LLM JSON responses
- Enforcing schema on structured outputs
- Runtime type checking (Python)
- Building reliable data pipelines with LLMs

**Key capabilities:**
- Automatic validation and type coercion
- Nested models and complex types
- Custom validators and constraints
- JSON schema generation

**Best practices:**
```python
from pydantic import BaseModel, Field

class Invoice(BaseModel):
    invoice_number: str = Field(..., description="Unique invoice ID")
    total_amount: float = Field(gt=0, description="Total amount (positive)")
    line_items: list[LineItem]

# LLM returns JSON → Pydantic validates
invoice = Invoice(**llm_response)
```

### 🧠 Multi-Agent

**Technologies:** [CrewAI](multi-agent/crewai/)

**What it does:** Orchestrate multiple AI agents with specialized roles working together.

**When to use:**
- Complex tasks requiring multiple steps
- Need for specialized roles (researcher, writer, analyst)
- Iterative refinement workflows
- Autonomous task execution

**Key capabilities:**
- Role-based agents with specific goals
- Sequential and hierarchical task execution
- Memory and context sharing between agents
- Integration with LangChain tools

**Example use cases:**
- Research + writing pipelines
- Data analysis + visualization
- Code generation + testing + review
- Customer support triage + resolution

### 🔄 Workflow

**Technologies:** [LangFlow](workflow/langflow/)

**What it does:** Visual workflow builder for LLM applications.

**When to use:**
- Prototyping AI workflows quickly
- Non-coders building LLM apps
- Visualizing complex agent interactions
- Iterating on prompt chains

**Key capabilities:**
- Drag-and-drop component library
- Pre-built templates for common patterns
- Integration with LangChain ecosystem
- Export to production-ready code

## Decision Frameworks

### Model Selection: Gemini vs OpenAI vs OpenRouter?

| Factor | Gemini | OpenAI | OpenRouter |
|--------|--------|--------|------------|
| **Best For** | Multimodal, cost | Quality, function calling | Flexibility, fallbacks |
| **Pricing** | $$ Affordable | $$$ Premium | $ Varies by model |
| **Context Window** | Up to 2M tokens | 128K tokens | Varies (up to 2M) |
| **Vision** | ✅ Native | ✅ GPT-4V | ✅ Multiple models |
| **Structured Output** | ✅ JSON mode | ✅ JSON mode | ⚠️ Model-dependent |
| **Reliability** | ✅ High (Google SLA) | ✅ High | ⚠️ Depends on provider |

### When to Use Multi-Agent vs Single LLM?

| Use Case | Approach | Why |
|----------|----------|-----|
| Simple Q&A | **Single LLM** | Overhead of agents not needed |
| Complex research | **Multi-agent (CrewAI)** | Specialized roles improve quality |
| Iterative refinement | **Multi-agent** | Separate generation and critique |
| Real-time chat | **Single LLM** | Latency-sensitive |
| Document processing | **Single LLM (Gemini)** | Vision + extraction in one call |

### Observability Strategy

**What to monitor at each stage:**

1. **Development**: Local tracing with LangFuse (find slow calls)
2. **Staging**: Cost + latency analysis (optimize before production)
3. **Production**: Error rates, uptime, cost per user (SLOs)

## Common Patterns

### Structured Extraction Pipeline

```
Document (PDF/Image) → Gemini Vision → JSON → Pydantic Validation → Database
                          ↓
                      LangFuse Trace
```

**Why this pattern:**
- Gemini handles multimodal input (text + images)
- JSON mode ensures structured output
- Pydantic validates schema at runtime
- LangFuse tracks failures and costs

### Fallback Routing

```python
# OpenRouter with fallback
primary_model = "anthropic/claude-3.5-sonnet"
fallback_model = "google/gemini-2.0-flash"

try:
    response = openrouter.complete(primary_model, prompt)
except Exception:
    response = openrouter.complete(fallback_model, prompt)
```

**Why:** Resilience to provider outages and rate limits.

### Multi-Agent Research Pipeline

```
User Query → Researcher Agent (search + summarize)
                ↓
            Analyst Agent (extract insights)
                ↓
            Writer Agent (generate report)
                ↓
            Critic Agent (review + refine)
```

**Tools:** CrewAI with LangChain tools (Google Search, Wikipedia, custom APIs)

### Prompt Versioning

**LangFuse pattern:**
1. Create prompt template in LangFuse UI
2. Version prompts (v1, v2, v3)
3. Reference by name in code: `get_prompt("invoice_extraction", version="v2")`
4. A/B test versions in production
5. Analyze performance metrics per version

## Integration Patterns

### Gemini + LangFuse + Pydantic

```python
from langfuse import Langfuse
from pydantic import BaseModel
import google.generativeai as genai

langfuse = Langfuse()
trace = langfuse.trace(name="invoice_extraction")

class Invoice(BaseModel):
    invoice_number: str
    total: float

# Call Gemini with tracing
with trace.span(name="gemini_call"):
    response = genai.generate_content(prompt, generation_config={"response_mime_type": "application/json"})

# Validate with Pydantic
invoice = Invoice(**json.loads(response.text))
```

### OpenRouter + LangChain

```python
from langchain.chat_models import ChatOpenRouter
from langchain.chains import LLMChain

llm = ChatOpenRouter(
    model="anthropic/claude-3.5-sonnet",
    openrouter_api_key=api_key
)

chain = LLMChain(llm=llm, prompt=prompt_template)
```

### CrewAI + LangFuse

```python
from crewai import Crew, Agent, Task
from langfuse.decorators import observe

@observe()  # Trace agent execution
def run_research_crew():
    researcher = Agent(role="Researcher", goal="Find accurate information")
    writer = Agent(role="Writer", goal="Create compelling content")

    crew = Crew(agents=[researcher, writer], tasks=[research_task, write_task])
    return crew.kickoff()
```

## Best Practices

### LLM Calls
✅ Always use structured output (JSON mode)
✅ Set temperature based on use case (0 for extraction, 0.7 for creative)
✅ Use system prompts for consistent behavior
✅ Implement retries with exponential backoff
✅ Track costs per call/user/endpoint

### Validation
✅ Use Pydantic for all LLM outputs
✅ Add field descriptions (helps LLMs generate correct format)
✅ Set constraints (gt=0, min_length=5, etc.)
✅ Handle validation errors gracefully (retry with error in prompt)

### Observability
✅ Trace every LLM call (dev and prod)
✅ Tag traces (user_id, endpoint, version)
✅ Set up alerts (error rate > 5%, cost spike)
✅ Review traces weekly (optimize slow calls)

### Multi-Agent
✅ Define clear roles and goals for each agent
✅ Limit agent iterations (prevent infinite loops)
✅ Share context efficiently (avoid re-processing)
✅ Test agents individually before orchestration

## Anti-Patterns

❌ **Unvalidated outputs**: Trusting LLM JSON without Pydantic → Runtime errors
❌ **No observability**: Can't debug production failures → Add LangFuse
❌ **Single point of failure**: One model down = system down → Use fallbacks
❌ **Ignoring costs**: Surprised by $10K bill → Track costs per call
❌ **Over-engineering**: Multi-agent for simple tasks → Start with single LLM
❌ **Prompt in code**: Hardcoded prompts → Version in LangFuse

## Recommended Learning Path

1. **Foundations** (1-2 weeks)
   - LLM basics (tokens, temperature, system prompts)
   - JSON mode and structured outputs
   - Pydantic fundamentals

2. **Platform Integration** (1 week)
   - Gemini API (text + vision)
   - OpenRouter setup and routing
   - Error handling and retries

3. **Observability** (1 week)
   - LangFuse setup and tracing
   - Cost tracking and optimization
   - Prompt versioning

4. **Advanced Patterns** (2-3 weeks)
   - Multi-agent systems with CrewAI
   - LangChain integration
   - Production deployment patterns

5. **Optimization** (ongoing)
   - Prompt engineering and testing
   - Model selection and routing
   - Cost optimization strategies

## Related Knowledge

- **Data Engineering**: See [data-engineering/](../data-engineering/) for data pipelines feeding AI systems
- **Cloud**: See [cloud/](../cloud/) for deploying LLM applications (Cloud Run, Lambda)
- **Document Processing**: See [document-processing/](../document-processing/) for extraction pipelines
- **DevOps**: See [devops-sre/](../devops-sre/) for CI/CD and monitoring

## Agents

Specialized agents for AI/ML tasks:
- `/genai-architect` - Multi-agent orchestration and AI system design
- `/ai-prompt-specialist` - Prompt optimization and extraction
- `/extraction-specialist` - Invoice/document processing with LLMs

---

**Build observable AI • Validate everything • Route intelligently**

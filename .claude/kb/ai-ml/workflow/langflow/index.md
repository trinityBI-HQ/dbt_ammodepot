# Langflow Knowledge Base

> **Purpose**: Visual low-code builder for AI agents, RAG pipelines, and multi-agent workflows with MCP-first architecture
> **Version**: 1.7.x (stable) / 1.8.0 (RC)
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/flows-components.md](concepts/flows-components.md) | Core building blocks: flows, components, edges, and DAG execution |
| [concepts/visual-editor.md](concepts/visual-editor.md) | Drag-and-drop interface, component library, and testing |
| [concepts/agents-tools.md](concepts/agents-tools.md) | Agent components, tool integration, and LangChain agents |
| [concepts/vector-stores.md](concepts/vector-stores.md) | Vector store components for RAG (Pinecone, Weaviate, etc.) |
| [concepts/language-models.md](concepts/language-models.md) | LLM integration, prompt templates, and model configuration |
| [concepts/data-loaders.md](concepts/data-loaders.md) | Document loaders, text splitters, and chunking strategies |
| [concepts/api-deployment.md](concepts/api-deployment.md) | REST API exposure, authentication, and deployment options |
| [concepts/mcp-server.md](concepts/mcp-server.md) | Model Context Protocol server and client integration |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/vector-rag-chatbot.md](patterns/vector-rag-chatbot.md) | Build RAG chatbot with vector store retrieval |
| [patterns/multi-agent-workflow.md](patterns/multi-agent-workflow.md) | Multi-agent system with specialized agents |
| [patterns/custom-components.md](patterns/custom-components.md) | Create reusable custom components |
| [patterns/api-integration.md](patterns/api-integration.md) | Deploy flows as REST APIs with authentication |
| [patterns/langchain-integration.md](patterns/langchain-integration.md) | Use LangChain components in Langflow |
| [patterns/production-deployment.md](patterns/production-deployment.md) | Deploy to production with Docker/Kubernetes |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Component types, common flows, deployment options

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Flow** | Visual DAG representing an AI application workflow with connected components |
| **Component** | Individual node (LLM, vector store, agent, tool) in a flow |
| **Agent** | Autonomous component that uses tools (ALTK, CUGA agents in v1.7) |
| **RAG** | Retrieval-Augmented Generation using vector stores for context |
| **MCP** | First-class MCP server/client with Streamable HTTP (v1.7), OAuth (v1.6) |
| **Guardrails** | Content safety and validation layer (v1.8+) |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/flows-components.md, concepts/visual-editor.md, patterns/vector-rag-chatbot.md |
| **Intermediate** | concepts/agents-tools.md, concepts/vector-stores.md, patterns/multi-agent-workflow.md |
| **Advanced** | concepts/mcp-server.md, patterns/custom-components.md, patterns/production-deployment.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| genai-architect | patterns/multi-agent-workflow.md, concepts/agents-tools.md | Design multi-agent AI systems |
| ai-prompt-specialist | concepts/language-models.md, patterns/vector-rag-chatbot.md | Optimize prompts for RAG pipelines |
| function-developer | patterns/api-integration.md, concepts/api-deployment.md | Deploy Langflow APIs to production |

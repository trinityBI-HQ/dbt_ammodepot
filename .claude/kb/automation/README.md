# Automation Knowledge Base

> **Last Updated:** 2026-02-19
> **Maintained By:** Claude Code Lab Team

## Overview

Automation enables systems to perform tasks without manual intervention, increasing efficiency, reducing errors, and freeing humans to focus on higher-value work. This category covers workflow automation, integration platforms, and process orchestration.

## Philosophy

**Automate when:**
- ✅ Task is repetitive (done more than twice)
- ✅ Task is error-prone when done manually
- ✅ Task requires consistency (exact same steps every time)
- ✅ Task needs to run on a schedule or trigger
- ✅ Time savings justify automation effort

**Don't automate when:**
- ❌ Task is done rarely (once per year)
- ❌ Task requires human judgment or creativity
- ❌ Requirements change frequently
- ❌ Automation would be more complex than manual process

**Best practices:**
- **Start simple**: Automate one step at a time
- **Make it observable**: Log every action, track failures
- **Design for failure**: Retries, error notifications, rollback
- **Document the automation**: Why it exists, how it works, how to fix it

## Categories

### 📊 Diagramming

**Technologies:** [Mermaid](diagramming/mermaid/)

**What it does:** Generate diagrams and charts from text-based definitions, enabling diagrams-as-code workflows.

**When to use:**
- Documenting architecture in Markdown files (GitHub READMEs, wikis)
- Visualizing data pipelines, CI/CD flows, and system designs
- Creating version-controlled diagrams that live alongside code
- Rapid prototyping of flowcharts, sequence diagrams, and ER diagrams
- Embedding diagrams in documentation sites (Docusaurus, MkDocs, Notion)

**Key capabilities:**
- 20+ diagram types (flowchart, sequence, class, state, ER, Gantt, pie, mindmap, timeline, C4, git graph, and more)
- Native rendering on GitHub, GitLab, Notion, Obsidian
- 5 built-in themes with customizable variables
- Markdown-first syntax (text in, SVG out)
- Live editor at [mermaid.live](https://mermaid.live/)

**Mermaid vs Alternatives:**
| Tool | Best For | Pros | Cons |
|------|----------|------|------|
| **Mermaid** | Markdown-native, docs-as-code | Native GitHub/GitLab support, version-controlled, 20+ diagram types | Less visual editing, limited styling |
| **PlantUML** | UML-heavy workflows | Mature, extensive UML support | Requires server, no native GitHub support |
| **D2** | Declarative diagrams | Modern syntax, auto-layout | Newer, smaller ecosystem |
| **draw.io** | Visual editing, non-developers | Drag-and-drop, free | Not text-based, harder to version control |
| **Excalidraw** | Whiteboard-style sketches | Hand-drawn look, collaborative | Not text-based, limited diagram types |

---

### 🔄 Workflow Automation

**Technologies:** [n8n](workflow-automation/n8n/)

**What it does:** Connect APIs, databases, and services to create automated workflows without code.

**When to use:**
- Integrating SaaS tools (Slack, Google Sheets, Notion, etc.)
- Event-driven workflows (new file → process → notify)
- Data synchronization between systems
- Scheduled tasks (daily reports, backups, reminders)
- Webhooks and API orchestration

**Key capabilities (v2.x):**
- Visual workflow builder (drag-and-drop)
- 400+ integrations (pre-built nodes)
- 70+ AI nodes (LangChain-based agents, LLM backends, vector stores)
- MCP support (client and server — bidirectional)
- Human-in-the-loop approval gates for AI tools
- Custom JavaScript/Python code nodes (isolated task runners)
- Triggers: webhook, chat, MCP server, form, schedule
- Self-hosted or cloud (n8n.cloud)
- Save/Publish workflow paradigm

**n8n vs Alternatives:**
| Tool | Best For | Pros | Cons |
|------|----------|------|------|
| **n8n** | Self-hosted, developer-friendly, AI agents | Open source, 70+ AI nodes, MCP, affordable | Smaller community than Zapier |
| **Zapier** | Non-technical users, SaaS | Easiest to use, largest ecosystem | Expensive at scale, limited logic |
| **Make (Integromat)** | Complex workflows | Visual, powerful branching | Steeper learning curve |
| **Temporal** | Developer workflows | Code-based, versioned, testable | Requires coding, more setup |

### 🤖 Robotic Process Automation (RPA)

**Status:** Placeholder - Knowledge base content coming soon

**Why RPA?**
Automate repetitive UI-based tasks (clicking, typing, copying) that lack APIs.

**When to use RPA:**
- Legacy systems without APIs
- Desktop applications (not web-based)
- High-volume data entry
- Screen scraping when APIs unavailable

**Technologies to be added:**
- UiPath
- Automation Anywhere
- Blue Prism
- Microsoft Power Automate Desktop

**Related Technologies:**
- See [workflow-automation/n8n/](workflow-automation/n8n/) for API-based automation (preferred when available)

### 📧 Email Automation

**Status:** Placeholder - Knowledge base content coming soon

**Why Email Automation?**
Trigger workflows from email events, send notifications, process attachments.

**Technologies to be added:**
- SendGrid / Mailgun (transactional email)
- Gmail API automation
- Email parsing and routing

**Related Technologies:**
- See [workflow-automation/n8n/](workflow-automation/n8n/) for email integration workflows

### 🔀 iPaaS (Integration Platform as a Service)

**Status:** Placeholder - Knowledge base content coming soon

**Why iPaaS?**
Enterprise-grade integration between cloud and on-premises applications.

**Technologies to be added:**
- MuleSoft
- Dell Boomi
- Workato
- Tray.io

## Decision Frameworks

### Workflow Automation Tool Selection

| Scenario | Recommended Tool | Why |
|----------|------------------|-----|
| Developer-friendly, self-hosted | **n8n** | Open source, code nodes, affordable |
| Non-technical users, simple zaps | **Zapier** | Easiest to use, largest connector library |
| Complex branching logic | **Make (Integromat)** | Visual logic, powerful conditional routing |
| Code-first, versioned workflows | **Temporal** or **Dagster** | Testable, version-controlled, developer tools |
| Enterprise with compliance needs | **Workato** or **MuleSoft** | Security, governance, support |

### When to Use Automation vs Manual Process

| Factor | Automate | Keep Manual |
|--------|----------|-------------|
| **Frequency** | Daily, hourly | Monthly, quarterly |
| **Volume** | 100+ items | < 20 items |
| **Consistency** | Must be exact | Flexible, varies |
| **Complexity** | Well-defined steps | Requires judgment |
| **Risk** | High (human error likely) | Low (mistakes easily corrected) |
| **Cost** | Automation < labor savings | Automation > labor savings |

### API-First vs UI Automation

| Approach | When to Use | Pros | Cons |
|----------|-------------|------|------|
| **API-first (n8n, Zapier)** | APIs available | Reliable, fast, maintainable | Requires API access |
| **UI automation (RPA)** | No APIs available | Works with any UI | Brittle, breaks on UI changes |

## Common Patterns

### Event-Driven Integration

```
Trigger (webhook, schedule, file upload)
  ↓
Data transformation
  ↓
Conditional logic (if/else)
  ↓
Action (API call, database write, notification)
  ↓
Error handling (retry, log, alert)
```

**Example (n8n):**
```
Webhook (new invoice uploaded to GCS)
  ↓
Extract file metadata
  ↓
If file type = PDF → Process with Gemini Vision
  ↓
Parse extracted data with Pydantic
  ↓
Write to BigQuery
  ↓
Send Slack notification
```

### Multi-System Synchronization

```
System A (source of truth)
  ↓
Detect changes (webhook or polling)
  ↓
Transform data (map fields)
  ↓
Update System B
  ↓
Update System C
  ↓
Log sync status
```

**Example:**
- Salesforce opportunity created → Sync to Hubspot → Notify team in Slack

### Scheduled Reporting

```
Cron trigger (daily at 8 AM)
  ↓
Query database or API
  ↓
Aggregate and format data
  ↓
Generate report (PDF, CSV, or Google Sheet)
  ↓
Email to stakeholders
```

**Example:**
- Daily sales report from Snowflake → Format → Email to sales team

### Approval Workflows

```
Form submission or API call
  ↓
Create approval request (Slack message with buttons)
  ↓
Wait for approval
  ↓
If approved → Execute action
  ↓
If denied → Notify submitter
```

**Example:**
- Expense submission → Manager approval via Slack → Sync to accounting system

## Integration Patterns

### n8n + Google Sheets + Slack

**Use case:** Team lead submits form → Log to Google Sheets → Notify team in Slack

```
Google Form submission
  ↓
n8n webhook trigger
  ↓
Append to Google Sheet
  ↓
Send Slack message with summary
```

### n8n + GCS + Gemini + BigQuery

**Use case:** Process uploaded invoices

```
GCS file upload (Cloud Function triggers n8n webhook)
  ↓
n8n downloads file
  ↓
HTTP request to Gemini API (vision extraction)
  ↓
Parse response with Pydantic validation
  ↓
Insert into BigQuery
  ↓
Move file to processed/ folder
```

### n8n + Airtable + Notion

**Use case:** Sync project tasks between tools

```
Airtable record updated
  ↓
n8n webhook trigger
  ↓
Transform data (map fields)
  ↓
Update corresponding Notion page
  ↓
Log sync to Google Sheets
```

## Best Practices

### Workflow Design
✅ Start with manual process documentation (write down every step)
✅ Automate one step at a time (iterate)
✅ Use descriptive node names (future you will thank you)
✅ Add error handling for every external call (APIs can fail)
✅ Log workflow execution (start, end, errors)

### Error Handling
✅ Implement retries with exponential backoff
✅ Send notifications on failure (email, Slack)
✅ Store failed items in a queue for manual review
✅ Use try-catch blocks in code nodes
✅ Test failure scenarios (don't just test happy path)

### Security
✅ Use environment variables for credentials (never hardcode)
✅ Rotate API keys regularly
✅ Principle of least privilege (minimum permissions needed)
✅ Audit logs for sensitive workflows
✅ Encrypt data in transit (HTTPS, TLS)

### Performance
✅ Batch API calls when possible (reduce latency)
✅ Use webhooks instead of polling (more efficient)
✅ Cache data when appropriate (reduce API calls)
✅ Monitor workflow execution time (optimize slow steps)
✅ Set timeouts to prevent hanging workflows

### Maintainability
✅ Document why the automation exists (context is key)
✅ Version control workflow definitions (export as JSON)
✅ Create runbooks for common issues
✅ Monitor and review logs regularly
✅ Deprecate unused automations (reduce clutter)

## Anti-Patterns

❌ **Over-automation**: Automating rarely-used processes → Waste of effort
❌ **No error handling**: Workflow fails silently → Add notifications
❌ **Tight coupling**: Hardcoded IDs and values → Use variables and lookups
❌ **No logging**: Can't debug failures → Log every step
❌ **Ignoring edge cases**: Only testing happy path → Test failures, edge cases
❌ **No monitoring**: Set-and-forget → Monitor execution and failures
❌ **Hardcoded credentials**: API keys in workflow → Use environment variables

## Use Cases by Industry

### E-commerce
- Order confirmation → Update inventory → Ship notification
- Abandoned cart → Email reminder (1 hour, 24 hours, 1 week)
- New product → Sync to multiple marketplaces (Amazon, eBay, Shopify)

### Marketing
- Lead captured → Add to CRM → Assign to sales rep → Send welcome email
- Social media post scheduled → Publish to multiple platforms
- Campaign performance → Daily report → Email to marketing team

### Finance
- Invoice uploaded → Extract data → Validate → Upload to accounting system
- Expense submitted → Manager approval → Sync to ERP
- Daily reconciliation → Compare systems → Flag discrepancies

### HR
- New hire onboarding → Create accounts (email, Slack, etc.) → Assign training
- Time-off request → Manager approval → Update calendar
- Exit process → Revoke access → Archive data

### Operations
- Server alert → Attempt auto-recovery → Escalate if failed → Page on-call
- Backup scheduled → Execute → Verify → Notify if failed
- Monitoring alert → Create ticket → Assign to team

## Recommended Learning Path

1. **Foundations** (1 week)
   - APIs and webhooks basics
   - JSON structure and parsing
   - HTTP methods (GET, POST, PUT, DELETE)

2. **n8n Basics** (1-2 weeks)
   - Installation (self-hosted or cloud)
   - Core nodes (HTTP Request, Set, IF, Switch)
   - Triggers (webhook, schedule, manual)

3. **Integrations** (2 weeks)
   - Common integrations (Slack, Google Sheets, Gmail)
   - Authentication (OAuth, API keys)
   - Data transformation (mapping fields)

4. **Advanced Patterns** (2 weeks)
   - Error handling and retries
   - Conditional logic and branching
   - Loops and iteration
   - Sub-workflows

5. **Production Deployment** (1 week)
   - Environment variables and secrets
   - Monitoring and logging
   - Scaling and performance
   - Backup and version control

## Related Knowledge

- **AI/ML**: See [ai-ml/](../ai-ml/) for LLM-powered automation (extract, classify, generate)
- **Data Engineering**: See [data-engineering/](../data-engineering/) for data pipeline orchestration
- **Cloud**: See [cloud/](../cloud/) for serverless functions and event-driven architectures
- **DevOps**: See [devops-sre/](../devops-sre/) for CI/CD and infrastructure automation
- **Diagramming**: See [diagramming/mermaid/](diagramming/mermaid/) for diagrams-as-code in Markdown

## Agents

Specialized agents for automation tasks:
- (No specialized agents yet - automation is well-served by general agents)

---

**Automate repetitive tasks • Handle errors gracefully • Monitor everything**

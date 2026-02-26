# Create Knowledge Base Command

> Create a complete KB section from scratch with MCP validation within the hierarchical structure.

## Usage

```
/create-kb <CATEGORY>/<SUBCATEGORY>/<DOMAIN>
```

**Examples:**
- `/create-kb data-engineering/orchestration/airflow` — Create Airflow KB under Data Engineering
- `/create-kb ai-ml/llm-platforms/claude` — Create Claude KB under AI/ML
- `/create-kb devops-sre/monitoring/prometheus` — Create Prometheus KB under DevOps/SRE
- `/create-kb cloud/aws` — Create AWS KB (no subcategory needed)

**Shorthand (auto-detect category):**
- `/create-kb redis` — Agent will prompt for category/subcategory placement

## What Happens

1. **Validates prerequisites** — checks `_templates/` and `_index.yaml` exist
2. **Determines placement** — ensures category/subcategory exists or prompts to create
3. **Invokes kb-architect agent** — executes full workflow with MCP validation
4. **Creates structure** — generates index.md, quick-reference.md, concepts/, patterns/
5. **Reports completion** — shows quality score and files created

## KB Structure

The KB is organized hierarchically:

```
.claude/kb/
├── data-engineering/    # Orchestration, transformation, platforms, ELT
├── ai-ml/              # LLM platforms, observability, multi-agent
├── cloud/              # GCP, AWS, Azure
├── devops-sre/         # IaC, CI/CD, monitoring, containers
├── automation/         # Workflow automation, RPA
└── document-processing/ # Parsing, extraction
```

**Categories:**
- `data-engineering/` — Data pipelines, orchestration, warehouses
- `ai-ml/` — LLMs, observability, multi-agent systems
- `cloud/` — Cloud providers and services
- `devops-sre/` — Infrastructure, deployment, operations
- `automation/` — Workflow automation and integration
- `document-processing/` — Document intelligence and extraction

**When creating a new KB:**
1. Choose appropriate category based on primary use case
2. Select or create subcategory (e.g., `orchestration/`, `llm-platforms/`)
3. Technology folder created within subcategory
4. Metadata includes category for cross-referencing

## Options

| Command | Action |
|---------|--------|
| `/create-kb <category>/<subcategory>/<domain>` | Create new KB in specific location |
| `/create-kb <domain>` | Create KB (agent prompts for placement) |
| `/create-kb --audit` | Audit existing KB health across all categories |
| `/create-kb --list-categories` | Show available categories and subcategories |

## File Structure Created

For each new KB domain, the following structure is created:

```
<category>/<subcategory>/<domain>/
├── index.md              # Overview, installation, getting started
├── quick-reference.md    # Cheat sheet (max 100 lines)
├── .metadata.json        # Technology metadata
├── concepts/             # Core concepts (max 150 lines each)
│   ├── concept1.md
│   └── concept2.md
└── patterns/             # Implementation patterns (max 200 lines each)
    ├── pattern1.md
    └── pattern2.md
```

## Examples

### Create Airflow KB
```
/create-kb data-engineering/orchestration/airflow
```

Creates: `.claude/kb/data-engineering/orchestration/airflow/`

### Create Datadog KB
```
/create-kb devops-sre/monitoring/datadog
```

Creates: `.claude/kb/devops-sre/monitoring/datadog/`

### Create Claude KB
```
/create-kb ai-ml/llm-platforms/claude
```

Creates: `.claude/kb/ai-ml/llm-platforms/claude/`

## See Also

- **Agent**: `.claude/agents/exploration/kb-architect.md`
- **Master Index**: `.claude/kb/README.md`
- **Category READMEs**: `.claude/kb/<category>/README.md`
- **Templates**: `.claude/kb/_templates/`
- **Registry**: `.claude/kb/_index.yaml`
- **Validation**: `scripts/validate_kb_structure.sh`
- **Reorganization Summary**: `KB_REORGANIZATION_SUMMARY.md`

# DEFINE: Infra Monitor Expansion

> Expand the Cost Monitor Streamlit app into an Infra Monitor with dbt pipeline health metrics and embedded dbt documentation

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | INFRA_MONITOR |
| **Date** | 2026-04-15 |
| **Author** | define-agent |
| **Status** | Ready for Design |
| **Clarity Score** | 15/15 |
| **Source** | [BRAINSTORM_INFRA_MONITOR.md](BRAINSTORM_INFRA_MONITOR.md) |

---

## Problem Statement

The Snowflake + AWS Cost Monitor app (`AD_ANALYTICS.OPS.COST_MONITOR`) covers compute and storage spend but provides no visibility into dbt pipeline health — forcing the data engineer to monitor build duration separately in CloudWatch and leaving the analytics team with no self-serve access to dbt model documentation, lineage, or test coverage.

---

## Target Users

| User | Role | Pain Point |
|------|------|------------|
| Victor | Data engineer / pipeline owner | Monitors build duration in a separate CloudWatch dashboard; no single pane of glass for infra + pipeline health. The 10-min ECS schedule ceiling is the main watchpoint and needs a visual indicator. |
| Analytics team | BI / reporting consumers | No self-serve access to dbt model documentation — cannot explore model lineage, descriptions, or test coverage without asking the data engineer or reading raw YAML. |

---

## Goals

| Priority | Goal |
|----------|------|
| **MUST** | Rename app from COST_MONITOR to INFRA_MONITOR (Snowflake object, CI workflow, all display titles, viewer grants) |
| **MUST** | Add Page 5 "dbt Pipeline" with a Build Duration line chart sourced from CloudWatch metric `AmmoDepot/dbt.BuildDurationMinutes`, including a 10-min ceiling reference line |
| **MUST** | Add Build Health table on Page 5 showing recent builds with status, duration, Iceberg refresh time, and pass/warn/error counts parsed from CloudWatch Logs `/ecs/ammodepot-dbt` |
| **MUST** | Embed interactive dbt documentation on Page 5 via iframe pointing to an S3-hosted static site (full DAG, search, model descriptions, test definitions) |
| **MUST** | Create CI workflow (`deploy-dbt-docs.yml`) that runs `dbt parse` and uploads the generated static site to S3 on pushes to main that change `ammodepot/` |
| **MUST** | Update EAI with CloudWatch + Logs endpoint egress rules |
| **SHOULD** | Maintain dark theme consistency — duration chart uses `apply_theme()`, health table uses `dark_dataframe()` |
| **SHOULD** | Cache CloudWatch API calls with appropriate TTL (short for metrics, longer for logs) to minimize API cost |
| **COULD** | Add Iceberg Refresh duration as a secondary metric on the duration chart |

---

## Success Criteria

- [ ] Snowflake object is `AD_ANALYTICS.OPS.INFRA_MONITOR` (old `COST_MONITOR` dropped)
- [ ] `DASHBOARD_VIEWER_ROLE` + `POWERBI_READONLY_ROLE` have USAGE on the new object
- [ ] App title, sidebar, and page descriptions reference "Infra Monitor" (not "Cost Monitor")
- [ ] Pages 1-4 render identically to current production (no regressions)
- [ ] Page 5 "dbt Pipeline" loads in both SiS and local dev
- [ ] Build Duration chart shows 7 days of data with datapoints every 10 min
- [ ] 10-min ceiling reference line is visible and labeled on the duration chart
- [ ] Build Health table shows the last 20+ builds with columns: timestamp, status (pass/fail), duration (min), Iceberg refresh (s), models pass, tests warn, tests error
- [ ] dbt Docs iframe loads the full interactive site (DAG navigable, search functional, model descriptions visible)
- [ ] CI workflow triggers only on `ammodepot/` path changes and successfully uploads to S3
- [ ] EAI allows egress to `monitoring.us-east-1.amazonaws.com` + `logs.us-east-1.amazonaws.com`
- [ ] CI re-attach step handles the updated EAI after `--replace` deploy

---

## Acceptance Tests

| ID | Scenario | Given | When | Then |
|----|----------|-------|------|------|
| AT-001 | Rename is complete | App deployed as INFRA_MONITOR | User navigates to app in Snowsight | Title shows "Snowflake + AWS Infra Monitor", sidebar shows "Infra Monitor v0.2" |
| AT-002 | Old object cleaned up | COST_MONITOR dropped | User searches for COST_MONITOR in Snowsight | Object not found |
| AT-003 | Viewer access preserved | DASHBOARD_VIEWER_ROLE user | User opens INFRA_MONITOR | All 5 pages accessible |
| AT-004 | Duration chart renders | Page 5 loaded, CloudWatch has metric data | User views Build Duration section | Line chart shows 7d of BuildDurationMinutes with a horizontal red dashed line at 10 min |
| AT-005 | Duration chart empty state | CloudWatch has no metric data (e.g., new namespace) | User views Build Duration section | Informational message displayed instead of empty chart |
| AT-006 | Build health table renders | CloudWatch Logs contain recent build output | User views Build Health section | Table shows recent builds with parsed status, duration, iceberg refresh, pass/warn/error |
| AT-007 | Build health — failed build | A build with `[31mERROR` in logs | User views Build Health table | Row shows status "FAIL" with error count > 0 |
| AT-008 | dbt Docs iframe loads | S3 static site deployed, browser can reach S3 URL | User views dbt Docs section | iframe renders interactive dbt docs; DAG is navigable, search works |
| AT-009 | dbt Docs not yet deployed | S3 bucket empty or URL unreachable | User views dbt Docs section | Graceful fallback message: "dbt docs not yet deployed" |
| AT-010 | CI generates docs | Push to main with `ammodepot/models/` change | GitHub Actions runs deploy-dbt-docs.yml | manifest.json + index.html uploaded to S3; static site accessible |
| AT-011 | CI skips non-model changes | Push to main with only `streamlit_app/` change | GitHub Actions | deploy-dbt-docs.yml does NOT trigger |
| AT-012 | Pages 1-4 regression | App deployed as INFRA_MONITOR | User navigates Pages 1-4 | All KPIs, charts, and tables render identically to pre-rename |
| AT-013 | EAI re-attach after deploy | CI runs `snow streamlit deploy --replace` | Post-deploy step executes | EAI with CloudWatch + Logs endpoints attached to INFRA_MONITOR |
| AT-014 | Local dev works | Developer runs `streamlit run app.py` locally | Page 5 loads | CloudWatch data fetched via default boto3 chain (AWS_PROFILE=ammodepot); iframe points to S3 URL |

---

## Out of Scope

- **catalog.json** — column types and row counts require Snowflake creds in CI; deferred to future enhancement
- **CloudFront / signed URLs** — non-guessable S3 bucket name is sufficient for internal team
- **Alarm status display** — build health table + ceiling line cover the monitoring need
- **Trend analysis / anomaly detection** on build duration — visual ceiling line is sufficient
- **Compute pool rename** — cosmetic, nobody sees it
- **Custom domain** for docs site — over-engineering for internal use
- **Directory rename** — `streamlit_cost_monitor/` stays as-is to avoid CI/CD churn; only the Snowflake object and display names change

---

## Constraints

| Type | Constraint | Impact |
|------|------------|--------|
| EAI egress | Must add `monitoring.us-east-1.amazonaws.com` + `logs.us-east-1.amazonaws.com` to existing `aws_cost_explorer_integration` | Bootstrap SQL script needed; CI re-attach must include updated EAI |
| S3 public access | Static website hosting makes docs bucket publicly accessible | Mitigate with non-guessable bucket name; no secrets in dbt docs |
| Log format coupling | CloudWatch Logs parsing depends on structured markers in `ecs/entrypoint.sh` (`BUILD_DURATION_SECONDS`, `ICEBERG_REFRESH_SECONDS`, ANSI color codes for pass/warn/error) | If entrypoint format changes, log parser breaks — document the contract |
| CI environment | `dbt parse` requires dbt-core + dbt-snowflake + project files in CI | Use uv for lightweight install; no Snowflake connection needed (manifest-only) |
| SiS deploy strips EAI | `snow streamlit deploy --replace` removes EAI binding | Existing CI pattern: re-attach via `snow sql` step immediately after deploy |
| AWS credentials | Same dual-mode mechanism as Cost Explorer (SiS: Snowflake secret → env var; local: default boto3 chain) | New `cloudwatch` + `logs` clients reuse same credential loader |
| Dark theme | All new visuals must use `apply_theme()` / `dark_dataframe()` for consistency | Follow existing patterns in `utils/chart_theme.py` |
| Iframe in SiS | `st.components.v1.iframe()` must work in SiS container runtime (Streamlit 1.55+) | Needs validation — low risk since container runtime supports full Streamlit |

---

## Technical Context

| Aspect | Value | Notes |
|--------|-------|-------|
| **Deployment Location** | `streamlit_cost_monitor/` (existing app) | Extend, don't create a new app |
| **KB Domains** | streamlit, cloudwatch, fargate, github | SiS patterns, CW API, ECS log format, GH Actions |
| **IaC Impact** | New S3 bucket + EAI update + viewer grants | Bootstrap SQL for Snowflake; AWS CLI or Terraform for S3 |

---

## Assumptions

| ID | Assumption | If Wrong, Impact | Validated? |
|----|------------|------------------|------------|
| A-001 | `svc_iac` IAM user (ADBIadmin group) has CloudWatch `GetMetricData` + Logs `FilterLogEvents` permissions | Would need IAM policy update | [ ] Verify before build |
| A-002 | `svc_iac` can create S3 buckets with static website hosting | Would need IAM policy update or manual bucket creation | [ ] Verify before build |
| A-003 | `st.components.v1.iframe()` works in SiS container runtime (Streamlit 1.55+) | Would need alternative embedding (e.g., `st.html` with manual iframe tag) | [ ] Verify during build |
| A-004 | CloudWatch retains metric data for 7+ days at 10-min resolution | Standard retention is 15 days for 1-min data, 63 days for 5-min — should be fine | [x] AWS docs confirm |
| A-005 | `dbt parse` produces sufficient artifacts for `dbt docs generate --no-compile` or the static site can be assembled from manifest alone | May need `dbt docs generate` which still works without warehouse for manifest portion | [ ] Verify in CI workflow |
| A-006 | S3 static website endpoint is reachable from corporate network / VPN (no firewall blocking) | iframe would show blank; would need CloudFront or internal hosting | [ ] Verify with team |
| A-007 | The Snowflake secret env var mechanism works for both `ce` (Cost Explorer) and `cloudwatch`/`logs` clients (same AWS creds) | `svc_snowflake_costs` IAM user would need CloudWatch permissions added | [ ] Verify IAM policy |

---

## Clarity Score Breakdown

| Element | Score (0-3) | Notes |
|---------|-------------|-------|
| Problem | 3 | Specific: two separate tools, no dbt docs access, 10-min ceiling watchpoint |
| Users | 3 | Two personas with distinct pain points identified during brainstorm |
| Goals | 3 | 9 goals with MUST/SHOULD/COULD prioritization, all actionable |
| Success | 3 | 12 measurable criteria + 14 acceptance tests with Given/When/Then |
| Scope | 3 | 7 explicit out-of-scope items confirmed during brainstorm YAGNI pass |
| **Total** | **15/15** | |

---

## Open Questions

None — ready for Design. All questions resolved during brainstorm session (6 discovery questions with user confirmation).

**Assumptions A-001, A-002, A-003, A-005, A-006, A-007 should be validated early in the Design or Build phase.** These are low-risk (likely true based on existing patterns) but would change the approach if wrong.

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-04-15 | define-agent | Initial version from BRAINSTORM_INFRA_MONITOR.md |

---

## Next Step

**Ready for:** `/design .claude/sdd/features/DEFINE_INFRA_MONITOR.md`

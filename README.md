# OpsBot: AI-Powered Site Reliability Assistant

> **Hackathon Submission** — H2S/Google Cloud Gen AI Academy APAC Edition  
> Multi-Agent Productivity Assistant for Incident Response

## Problem Statement

On-call engineers spend 40-60% of incident response time on manual tasks: classifying alerts, searching runbooks, checking service health, and drafting status updates. OpsBot reduces **Mean Time To Resolution (MTTR)** by coordinating AI agents that automate each phase of incident response.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Cloud Run (Agent)                      │
│                                                           │
│   ┌───────────────────────────────────┐                  │
│   │     root_agent (Orchestrator)     │                  │
│   │         Gemini 2.0 Flash          │                  │
│   └──────┬────┬────┬────┬────────────┘                  │
│          │    │    │    │                                 │
│   ┌──────▼─┐ ┌▼────▼┐ ┌▼──────┐ ┌───▼───┐              │
│   │Triage  │ │Analy-│ │Resolu-│ │ Task  │              │
│   │Agent   │ │sis   │ │tion   │ │ Agent │              │
│   │        │ │Agent │ │Agent  │ │       │              │
│   └────────┘ └──┬───┘ └──┬────┘ └───┬───┘              │
│                  │        │          │                    │
└──────────────────┼────────┼──────────┼───────────────────┘
                   │        │          │
            ┌──────▼────────▼──────────▼──────┐
            │   MCP Toolbox for Databases      │
            │        (Cloud Run)               │
            └──────────────┬──────────────────┘
                           │
            ┌──────────────▼──────────────────┐
            │   Cloud SQL PostgreSQL           │
            │   (services, incidents,          │
            │    runbooks, on-call, tasks)     │
            └─────────────────────────────────┘
```

## Core Requirements Mapping

| Requirement | Implementation |
|-------------|----------------|
| Primary agent coordinating sub-agents | `root_agent` (LlmAgent) routes to 4 specialized sub-agents |
| Store/retrieve structured data | Cloud SQL PostgreSQL with 5 tables, queried via MCP |
| Multiple tools via MCP | 10 MCP tools via MCP Toolbox for Databases |
| Multi-step workflows | Alert → Triage → Analysis → Resolution → Status Update |
| API-based deployment | Cloud Run with ADK HTTP endpoints + Web UI |

## Agents

### 1. Orchestrator (root_agent)
Routes user requests to the appropriate specialist agent. Handles multi-step workflows by coordinating between agents sequentially.

### 2. Triage Agent
- Classifies log entries and alerts by **severity** (P1-P4), **subsystem**, and **category**
- Uses keyword analysis + Gemini reasoning
- Estimates SLO budget impact

### 3. Analysis Agent
- Queries operations database via **10 MCP tools**
- Shows open incidents, service health, SLO status
- Finds historical patterns and recurring issues
- Provides data-driven context for decision-making

### 4. Resolution Agent
- Searches runbook database for matching procedures
- Drafts formatted status page updates
- Provides escalation guidance
- Suggests likely root causes from patterns

### 5. Task Agent
- Queries on-call schedules (who to page)
- Tracks incident-linked tasks and assignments
- Provides task board overview with priorities

## MCP Tools (via MCP Toolbox for Databases)

| Tool | Purpose |
|------|---------|
| `query_open_incidents` | All active incidents with severity and timing |
| `query_incidents_by_service` | Incident history for a specific service |
| `query_incident_patterns` | Recurring failure types with avg MTTR |
| `query_service_health` | SLO status of all services |
| `query_degraded_services` | Services breaching SLO |
| `search_runbook` | Find resolution procedures by category |
| `query_on_call_now` | Current on-call schedule for all teams |
| `query_on_call_for_team` | On-call for a specific team |
| `query_tasks_for_incident` | Tasks linked to an incident |
| `query_open_tasks` | All open tasks with priorities |

## Database Schema

**5 tables** with realistic sample data:
- `services` (10 services across 8 teams with SLO tracking)
- `incidents` (9 incidents, mix of open and resolved)
- `runbooks` (8 runbooks covering common failure categories)
- `on_call_schedule` (9 on-call entries across teams)
- `tasks` (5 tasks linked to active incidents)

## Quick Start

### Prerequisites
- Google Cloud project with billing enabled
- `gcloud` CLI authenticated

### Deploy (3 steps)

```bash
# 1. Set up database (~10 min for Cloud SQL provisioning)
bash scripts/01_setup_database.sh

# 2. Deploy MCP Toolbox (~3 min)
bash scripts/02_deploy_toolbox.sh

# 3. Deploy OpsBot agent (~5 min)
bash scripts/03_deploy_agent.sh
```

### Test Locally

```bash
pip install -r requirements.txt

# Start MCP Toolbox locally (in separate terminal)
# ./toolbox --tools-file mcp-toolbox/tools.yaml --address 0.0.0.0 --port 5000

# Start agent
adk web
```

## Example Interactions

**Incident Triage:**
```
User: ALERT: Pod payments-api-7d8f9b memory at 95%. OOMKilled 2x in last hour.
→ triage_agent: P2 High, subsystem=kubernetes, category=memory_leak
```

**System Health Check:**
```
User: What's the current system health?
→ analysis_agent: 3 services degraded, 1 P1 incident active
```

**Multi-step Workflow:**
```
User: We got a payment latency alert. Diagnose it and draft a status update.
→ triage_agent: Classifies as P1 high_latency/database
→ analysis_agent: Finds similar past incident, checks service health
→ resolution_agent: Provides runbook steps + drafts status update
```

## Technologies

- **Google ADK** (Agent Development Kit) — Multi-agent orchestration
- **Gemini 2.0 Flash** — LLM for reasoning and classification
- **MCP Toolbox for Databases** — Standardized database-to-agent integration
- **Cloud SQL PostgreSQL** — Structured data storage
- **Google Cloud Run** — Serverless deployment
- **Python 3.11+** — Agent implementation

## Cleanup

```bash
bash scripts/cleanup.sh
```

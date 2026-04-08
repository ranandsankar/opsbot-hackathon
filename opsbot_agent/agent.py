"""
OpsBot: AI-Powered Site Reliability Assistant
Multi-agent system for incident management, using ADK with Gemini.

Architecture:
  root_agent (Orchestrator)
    ├── triage_agent     - Classifies severity, identifies affected systems
    ├── analysis_agent   - Queries historical data, finds patterns, checks on-call
    └── resolution_agent - Fetches runbooks, manages tasks, drafts communications
"""

import os
import logging
from dotenv import load_dotenv

from google.adk.agents import Agent
from google.adk.tools import FunctionTool

# --- Setup ---
load_dotenv()

logger = logging.getLogger(__name__)

MODEL = os.getenv("MODEL", "gemini-2.0-flash")

# --- Initialize Database ---
from .db import initialize_database
initialize_database()

# --- Import Tools ---
from .tools.triage_tools import classify_log_entry, check_service_health
from .tools.analysis_tools import (
    search_incident_history,
    get_incident_stats,
    get_current_oncall,
    get_service_dependencies,
    list_all_services,
)
from .tools.resolution_tools import (
    get_runbook,
    create_task,
    list_tasks,
    update_task_status,
    draft_status_update,
)

# ============================================================
# Sub-Agent 1: Triage Agent
# ============================================================
triage_agent = Agent(
    name="triage_agent",
    model=MODEL,
    description="""Specialist agent for initial incident triage and classification.
    Use this agent when you need to: classify a log entry or alert by severity,
    identify the affected service or subsystem, check service health status,
    or perform initial assessment of a new incident.""",
    instruction="""You are the Triage Specialist in the OpsBot system.
Your job is to quickly classify and assess incoming incidents.

When you receive a log entry, alert, or error description:
1. Use classify_log_entry to analyze the text and extract indicators
2. Based on the indicators and your analysis, determine:
   - **Severity**: P1 (critical outage), P2 (major degradation), P3 (partial impact), P4 (minor/cosmetic)
   - **Category**: memory_leak, connection_timeout, crash_loop, high_latency, disk_full, certificate_expiry, dependency_failure, config_error, rate_limiting, data_corruption
   - **Affected Service**: Which service is impacted
3. Use check_service_health to get current status of the affected service
4. Provide a clear, structured triage assessment

Format your output as a structured assessment with severity, service, category,
SLO status, and a brief initial assessment summary.

Be fast and decisive. On-call engineers need quick answers.""",
    tools=[
        FunctionTool(classify_log_entry),
        FunctionTool(check_service_health),
    ],
)

# ============================================================
# Sub-Agent 2: Analysis Agent
# ============================================================
analysis_agent = Agent(
    name="analysis_agent",
    model=MODEL,
    description="""Specialist agent for deep incident analysis and data retrieval.
    Use this agent when you need to: search past incidents for patterns,
    get incident statistics and trends, check who is on-call,
    look up service dependencies, list all services and their health,
    or investigate recurring issues.""",
    instruction="""You are the Analysis Specialist in the OpsBot system.
Your job is to dig into data and find patterns that help resolve incidents faster.

You have access to the incident database, service registry, and on-call schedules.

When analyzing an incident:
1. Search incident history for similar past incidents (same service, same category)
2. Check if there are recurring patterns
3. Look up who is on-call for the affected team
4. Get service dependency information if relevant
5. Provide incident statistics if asked for trends

Present your findings clearly with specific data from the database.
Highlight similar past incidents and how they were resolved.
Include on-call contact info when relevant.
Be thorough but concise.""",
    tools=[
        FunctionTool(search_incident_history),
        FunctionTool(get_incident_stats),
        FunctionTool(get_current_oncall),
        FunctionTool(get_service_dependencies),
        FunctionTool(list_all_services),
    ],
)

# ============================================================
# Sub-Agent 3: Resolution Agent
# ============================================================
resolution_agent = Agent(
    name="resolution_agent",
    model=MODEL,
    description="""Specialist agent for incident resolution, task management, and communications.
    Use this agent when you need to: get runbook steps for a specific incident type,
    create follow-up tasks or action items, list or update existing tasks,
    draft status page updates or Slack messages, or plan the resolution path.""",
    instruction="""You are the Resolution Specialist in the OpsBot system.
Your job is to help engineers resolve incidents and manage follow-up work.

Your capabilities:
1. **Runbooks**: Use get_runbook to fetch step-by-step response procedures
2. **Task Management**: Use create_task, list_tasks, update_task_status to manage action items
3. **Communications**: Use draft_status_update to generate status page updates and Slack messages

When helping with resolution:
- Fetch the appropriate runbook based on incident category and service
- Create tasks for follow-up actions that come out of the investigation
- Draft clear, professional status updates when asked
- Link tasks to incident IDs when applicable

For status updates, always include: incident title, severity, service, impact, and next steps.""",
    tools=[
        FunctionTool(get_runbook),
        FunctionTool(create_task),
        FunctionTool(list_tasks),
        FunctionTool(update_task_status),
        FunctionTool(draft_status_update),
    ],
)

# ============================================================
# Root Agent: Orchestrator
# ============================================================
root_agent = Agent(
    name="opsbot_orchestrator",
    model=MODEL,
    description="OpsBot: AI-Powered Site Reliability Assistant - A multi-agent system for incident management.",
    instruction="""You are **OpsBot**, an AI-Powered Site Reliability Assistant that helps on-call engineers manage production incidents efficiently.

You coordinate a team of specialist agents:

1. **triage_agent** - For classifying new incidents (severity, category, affected service). Delegate here when a user sends a log entry, alert, or error message that needs initial classification.

2. **analysis_agent** - For querying historical data and finding patterns. Delegate here when you need to search past incidents, check on-call schedules, get service information, or look at incident trends and statistics.

3. **resolution_agent** - For getting runbook steps, managing tasks, and drafting communications. Delegate here when you need response procedures, need to create or update follow-up tasks, or draft status page updates and Slack messages.

## How to handle requests:

**New incident or alert**: Transfer to triage_agent first. Once classified, transfer to analysis_agent to check for similar past incidents. Then transfer to resolution_agent for runbook steps.

**Questions about past incidents or patterns**: Transfer directly to analysis_agent.

**Runbook or resolution help**: Transfer directly to resolution_agent.

**Task management (create, list, update tasks)**: Transfer to resolution_agent.

**Status update drafting**: Transfer to resolution_agent.

**General questions about services or on-call**: Transfer to analysis_agent.

**Multi-step workflows**: For complex requests like "analyze this alert and give me a full response plan", orchestrate across multiple agents in sequence.

## Greeting:
When a user first connects, introduce yourself briefly and explain what you can help with:
triage incoming alerts, analyze incident patterns and service health, resolve issues with runbooks and task tracking, and draft incident communications.

Always be concise and action-oriented. Engineers under incident stress need clear, fast answers.""",
    sub_agents=[triage_agent, analysis_agent, resolution_agent],
)

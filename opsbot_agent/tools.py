"""
OpsBot - Function Tools
Non-database tools used by agents for classification, status drafting, and impact estimation.
"""


def classify_log_entry(log_entry: str) -> dict:
    """Analyzes a production log entry or alert and provides keyword-based
    initial classification to assist the LLM in incident triage.

    Args:
        log_entry: The raw log entry, error message, or alert text to analyze.

    Returns:
        dict: Detected keywords and classification hints.
    """
    keywords = {
        "OOMKilled": "memory_leak", "oom": "memory_leak",
        "timeout": "connection_timeout", "deadline exceeded": "connection_timeout",
        "CrashLoopBackOff": "crash_loop", "panic": "crash_loop",
        "certificate": "certificate_expiry", "TLS": "certificate_expiry",
        "rate limit": "rate_limiting", "429": "rate_limiting",
        "disk full": "disk_full", "no space": "disk_full",
        "corrupt": "data_corruption",
        "nil pointer": "crash_loop",
        "connection refused": "dependency_failure",
        "502": "connection_timeout", "503": "dependency_failure",
        "latency": "high_latency", "slow": "high_latency",
        "config": "config_error", "env var": "config_error",
    }

    detected = []
    log_lower = log_entry.lower()
    for kw, cat in keywords.items():
        if kw.lower() in log_lower:
            detected.append(cat)

    return {
        "input_received": True,
        "log_length": len(log_entry),
        "detected_keywords": list(set(detected)) if detected else ["unknown"],
        "instruction": "Based on the log and detected keywords, determine severity (P1-P4), subsystem, and category.",
    }


def draft_status_update(
    incident_title: str,
    severity: str,
    status: str,
    affected_services: str,
    summary: str,
    next_steps: str,
) -> dict:
    """Drafts a formatted status page update for stakeholder communication.

    Args:
        incident_title: Title of the incident.
        severity: Severity level (P1, P2, P3, P4).
        status: Current status (investigating, identified, monitoring, resolved).
        affected_services: Comma-separated list of affected services.
        summary: Brief description of impact.
        next_steps: Actions being taken or planned.

    Returns:
        dict: Formatted status update ready for posting.
    """
    emoji = {"investigating": "🔍", "identified": "🎯", "monitoring": "👀", "resolved": "✅"}
    label = {"P1": "Critical", "P2": "Major", "P3": "Minor", "P4": "Low"}

    return {
        "status_update": {
            "title": f"[{severity}] {incident_title}",
            "severity_label": label.get(severity, severity),
            "status": f"{emoji.get(status, '📋')} {status.upper()}",
            "affected_services": affected_services,
            "summary": summary,
            "next_steps": next_steps,
        },
        "formatted_message": (
            f"**{emoji.get(status, '')} Incident Update - {label.get(severity, severity)}**\n\n"
            f"**Title:** {incident_title}\n"
            f"**Status:** {status.upper()}\n"
            f"**Affected:** {affected_services}\n\n"
            f"**Summary:** {summary}\n\n"
            f"**Next Steps:** {next_steps}"
        ),
    }


def estimate_impact(
    service_name: str,
    service_tier: str,
    error_rate_percent: float,
    duration_minutes: int,
) -> dict:
    """Estimates business impact based on service tier, error rate, and duration.

    Args:
        service_name: Name of the affected service.
        service_tier: Service tier (T0, T1, T2).
        error_rate_percent: Current error rate as percentage (0-100).
        duration_minutes: How long the incident has been ongoing.

    Returns:
        dict: Impact assessment with SLO budget consumption and urgency.
    """
    budgets = {
        "T0": {"slo": 99.99, "budget_min": 4.3},
        "T1": {"slo": 99.9, "budget_min": 43.2},
        "T2": {"slo": 99.5, "budget_min": 216.0},
    }
    tier = budgets.get(service_tier, budgets["T2"])
    effective = duration_minutes * (error_rate_percent / 100)
    consumed = (effective / tier["budget_min"]) * 100

    if consumed > 80:
        urgency = "CRITICAL - SLO budget nearly exhausted"
    elif consumed > 50:
        urgency = "HIGH - Significant SLO budget consumed"
    elif consumed > 20:
        urgency = "MEDIUM - Noticeable SLO impact"
    else:
        urgency = "LOW - Minimal SLO impact"

    return {
        "service": service_name,
        "tier": service_tier,
        "slo_target": f"{tier['slo']}%",
        "monthly_budget_minutes": round(tier["budget_min"], 1),
        "effective_downtime_minutes": round(effective, 1),
        "budget_consumed_percent": round(consumed, 1),
        "urgency": urgency,
    }

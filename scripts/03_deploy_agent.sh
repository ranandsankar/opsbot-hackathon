#!/bin/bash
# ============================================================
# OpsBot - Step 3: Deploy Multi-Agent System to Cloud Run
# Run this AFTER database and MCP Toolbox are deployed
# ============================================================
set -e

export PROJECT_ID=$(gcloud config get-value project)
export REGION=${REGION:-us-central1}
export TOOLBOX_URL=${TOOLBOX_URL:-"https://opsbot-toolbox-XXXXX.${REGION}.run.app"}

echo "=== Deploying OpsBot Multi-Agent System ==="
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Toolbox URL: $TOOLBOX_URL"

# Create service account
export SA_NAME=opsbot-agent-sa
export SERVICE_ACCOUNT=${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com

gcloud iam service-accounts create $SA_NAME \
  --display-name="OpsBot Agent Service Account" \
  2>/dev/null || echo "Service account exists"

# Grant roles
for ROLE in roles/aiplatform.user roles/run.invoker roles/cloudsql.client; do
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="$ROLE" \
    --quiet
done

# Update .env with toolbox URL
cat > opsbot_agent/.env << EOF
MODEL=gemini-2.0-flash
GOOGLE_GENAI_USE_VERTEXAI=TRUE
TOOLBOX_URL=${TOOLBOX_URL}
EOF

echo ">>> Deploying agent to Cloud Run..."
uvx --from google-adk adk deploy cloud_run \
  --project=$PROJECT_ID \
  --region=$REGION \
  --service_name=opsbot-agent \
  --with_ui \
  . \
  -- \
  --allow-unauthenticated \
  --service-account=$SERVICE_ACCOUNT \
  --set-env-vars="TOOLBOX_URL=${TOOLBOX_URL}"

# Get the deployed URL
export AGENT_URL=$(gcloud run services describe opsbot-agent --region=$REGION --format='value(status.url)')
echo ""
echo "============================================"
echo "  OpsBot Deployed Successfully! 🚀"
echo "============================================"
echo ""
echo "Agent URL: $AGENT_URL"
echo "Toolbox URL: $TOOLBOX_URL"
echo ""
echo "Open the Agent URL in your browser to interact with OpsBot."
echo ""
echo "Try these test prompts:"
echo "  1. 'Hello' (introduction)"
echo "  2. 'What is the current system health?' (analysis_agent)"
echo "  3. 'Show me all open incidents' (analysis_agent)"
echo "  4. 'Who is on-call for the Payments team?' (task_agent)"
echo "  5. 'Classify this alert: Pod payments-api OOMKilled, memory at 95%' (triage_agent)"
echo "  6. 'Draft a status update for the payment latency issue' (resolution_agent)"
echo "  7. 'What are the open tasks?' (task_agent)"
echo ""
echo "Submit this URL as your Cloud Run link: $AGENT_URL"

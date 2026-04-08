#!/bin/bash
# OpsBot - Cleanup all resources
set -e
export PROJECT_ID=$(gcloud config get-value project)
export REGION=${REGION:-us-central1}

echo "=== Cleaning up OpsBot resources ==="
gcloud run services delete opsbot-agent --region=$REGION --quiet 2>/dev/null || true
gcloud run services delete opsbot-toolbox --region=$REGION --quiet 2>/dev/null || true
gcloud sql instances delete opsbot-db-instance --quiet 2>/dev/null || true
gcloud iam service-accounts delete opsbot-agent-sa@${PROJECT_ID}.iam.gserviceaccount.com --quiet 2>/dev/null || true
echo "=== Cleanup complete ==="

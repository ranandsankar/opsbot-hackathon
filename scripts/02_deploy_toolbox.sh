#!/bin/bash
# ============================================================
# OpsBot - Step 2: Deploy MCP Toolbox for Databases
# Run this AFTER database setup is complete
# ============================================================
set -e

export PROJECT_ID=$(gcloud config get-value project)
export REGION=${REGION:-us-central1}
export DB_INSTANCE=${CLOUD_SQL_INSTANCE:-opsbot-db-instance}
export DB_PASSWORD="your-actual-password-here"

echo "=== Deploying MCP Toolbox for Databases ==="

# Create deployment directory
mkdir -p deploy-toolbox
cp mcp-toolbox/tools.yaml deploy-toolbox/

# Create Dockerfile for the toolbox
cat > deploy-toolbox/Dockerfile << 'DOCKERFILE'
FROM golang:1.23 AS builder
RUN CGO_ENABLED=0 GOOS=linux go install github.com/googleapis/genai-toolbox@latest

FROM alpine:3.19
RUN apk add --no-cache ca-certificates
COPY --from=builder /go/bin/genai-toolbox /usr/local/bin/toolbox
COPY tools.yaml /app/tools.yaml
WORKDIR /app
EXPOSE 5000
CMD ["toolbox", "--tools-file", "tools.yaml", "--address", "0.0.0.0", "--port", "5000"]
DOCKERFILE

# Substitute environment variables in tools.yaml
sed -i "s|\${GOOGLE_CLOUD_PROJECT}|$PROJECT_ID|g" deploy-toolbox/tools.yaml
sed -i "s|\${REGION}|$REGION|g" deploy-toolbox/tools.yaml
sed -i "s|\${CLOUD_SQL_INSTANCE}|$DB_INSTANCE|g" deploy-toolbox/tools.yaml
sed -i "s|\${DB_PASSWORD}|$DB_PASSWORD|g" deploy-toolbox/tools.yaml

echo ">>> Deploying MCP Toolbox to Cloud Run..."
gcloud run deploy opsbot-toolbox \
  --source deploy-toolbox/ \
  --region $REGION \
  --set-env-vars "GOOGLE_CLOUD_PROJECT=$PROJECT_ID,REGION=$REGION" \
  --allow-unauthenticated \
  --quiet

# Get the deployed URL
export TOOLBOX_URL=$(gcloud run services describe opsbot-toolbox --region=$REGION --format='value(status.url)')
echo ""
echo "=== MCP Toolbox Deployed ==="
echo "URL: $TOOLBOX_URL"
echo ""
echo "Save this! You'll need it for the agent:"
echo "export TOOLBOX_URL=$TOOLBOX_URL"

# Clean up
rm -rf deploy-toolbox

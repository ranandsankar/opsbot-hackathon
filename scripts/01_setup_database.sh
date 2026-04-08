#!/bin/bash
# ============================================================
# OpsBot - Step 1: Database Setup (Cloud SQL PostgreSQL)
# Run this in Google Cloud Shell FIRST
# ============================================================
set -e

export PROJECT_ID=$(gcloud config get-value project)
export REGION=${REGION:-us-central1}
export DB_INSTANCE=opsbot-db-instance
export DB_PASSWORD=${DB_PASSWORD:-opsbot-hackathon-2025}
export DB_NAME=opsbot_db

echo "=== OpsBot Database Setup ==="
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Instance: $DB_INSTANCE"

# Enable APIs
echo ">>> Enabling APIs..."
gcloud services enable \
  sqladmin.googleapis.com \
  aiplatform.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  cloudresourcemanager.googleapis.com \
  servicenetworking.googleapis.com

# Create Cloud SQL instance (this takes ~5-10 minutes)
echo ">>> Creating Cloud SQL PostgreSQL instance (this takes a few minutes)..."
gcloud sql instances create $DB_INSTANCE \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=$REGION \
  --root-password=$DB_PASSWORD \
  --database-flags=cloudsql.iam_authentication=on \
  --edition=enterprise \
  --availability-type=zonal \
  --storage-size=10GB \
  --no-assign-ip \
  --network=default \
  || echo "Instance may already exist, continuing..."

# Create the database
echo ">>> Creating database..."
gcloud sql databases create $DB_NAME \
  --instance=$DB_INSTANCE \
  || echo "Database may already exist, continuing..."

# Get connection name
export CONNECTION_NAME=$(gcloud sql instances describe $DB_INSTANCE --format='value(connectionName)')
echo "Connection name: $CONNECTION_NAME"

# Initialize schema and data using Cloud SQL Proxy or gcloud sql connect
echo ">>> Loading schema and sample data..."
echo "Run the following command to connect and load data:"
echo ""
echo "  gcloud sql connect $DB_INSTANCE --database=$DB_NAME --user=postgres"
echo ""
echo "Then paste the contents of database/init.sql"
echo ""
echo "Or use Cloud SQL Proxy:"
echo "  cloud-sql-proxy $CONNECTION_NAME &"
echo "  PGPASSWORD=$DB_PASSWORD psql -h 127.0.0.1 -U postgres -d $DB_NAME -f database/init.sql"

echo ""
echo "=== Database setup initiated ==="
echo "Instance: $DB_INSTANCE"
echo "Database: $DB_NAME"
echo "Connection: $CONNECTION_NAME"
echo ""
echo "Save these values! You'll need them for the MCP Toolbox setup."
echo "export CLOUD_SQL_INSTANCE=$DB_INSTANCE"
echo "export DB_PASSWORD=$DB_PASSWORD"
echo "export CONNECTION_NAME=$CONNECTION_NAME"

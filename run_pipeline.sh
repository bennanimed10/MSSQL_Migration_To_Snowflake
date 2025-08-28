#!/bin/bash
# Main orchestration script for the entire data pipeline

set -e  # Exit on any error

# Load environment variables
if [ -f .env ]; then
    source .env
fi

# Log file
LOG_FILE="pipeline_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Starting Data Pipeline at $(date) ==="

# Step 1: Export data from SQL Server to CSV and upload to S3
echo "Step 1: Exporting data from SQL Server to S3..."
./run_export.sh
if [ $? -ne 0 ]; then
    echo "Error: SQL Server export failed. Exiting pipeline."
    exit 1
fi
echo "SQL Server export completed successfully."

# Step 2: Run dbt to transform data in Snowflake
echo "Step 2: Running dbt transformations..."
cd "$(dirname "$0")"  # Ensure we're in the project directory

# Install dbt dependencies
echo "Installing dbt dependencies..."
dbt deps

# Run dbt models
echo "Running dbt models..."
dbt run --profiles-dir .

# Run dbt tests
echo "Running dbt tests..."
dbt test --profiles-dir .

if [ $? -ne 0 ]; then
    echo "Warning: Some dbt tests failed. Check the logs for details."
    # Continue pipeline but flag the issue
fi

# Step 3: Generate documentation
echo "Step 3: Generating dbt documentation..."
dbt docs generate --profiles-dir .

# Optional: Serve the documentation locally
# echo "Documentation available at http://localhost:8080"
# dbt docs serve --profiles-dir . --port 8080

echo "=== Data Pipeline completed at $(date) ==="
echo "Log file: $LOG_FILE"

# Success!
exit 0


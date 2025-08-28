#!/bin/bash
# Script to run the SQL Server to S3 export

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    source .env
fi

# Default values
SERVER=${SQL_SERVER:-"localhost"}
DATABASE=${SQL_DATABASE:-"cas_snowflake_data_export"}
SCHEMA=${SQL_SCHEMA:-"dbo"}
OUTPUT_DIR=${OUTPUT_DIR:-"./data"}
S3_BUCKET=${S3_BUCKET:-"my-data-pipeline-bucket"}
S3_PREFIX=${S3_PREFIX:-"raw-data"}

# Check if we should use trusted connection or username/password
if [ -n "$SQL_USERNAME" ] && [ -n "$SQL_PASSWORD" ]; then
    AUTH_PARAMS="--username $SQL_USERNAME --password $SQL_PASSWORD"
else
    AUTH_PARAMS="--use-trusted-connection"
fi

# Run the Python script
echo "Starting SQL Server to S3 export at $(date)"
python3 sql_to_s3.py \
    --server "$SERVER" \
    --database "$DATABASE" \
    --schema "$SCHEMA" \
    --output-dir "$OUTPUT_DIR" \
    --s3-bucket "$S3_BUCKET" \
    --s3-prefix "$S3_PREFIX" \
    $AUTH_PARAMS

# Check if the export was successful
if [ $? -eq 0 ]; then
    echo "Export completed successfully at $(date)"
    exit 0
else
    echo "Export failed at $(date)"
    exit 1
fi


# Airflow Orchestration for SQL Server to Snowflake Pipeline

This directory contains the Airflow implementation for orchestrating the data pipeline from SQL Server to Snowflake via AWS S3.

## Overview

The Airflow DAG (`mssql_to_snowflake_dag.py`) orchestrates the following steps:

1. Dynamically discover tables to export from SQL Server
2. Extract data from SQL Server tables and export to CSV files
3. Upload CSV files to AWS S3 with timestamp-based folder structure
4. Create or update tables in Snowflake
5. Load data from S3 into Snowflake
6. Run dbt transformations
7. Run dbt tests
8. Generate dbt documentation

## Prerequisites

- Docker and Docker Compose
- SQL Server with ODBC Driver 17
- AWS S3 bucket with appropriate permissions
- Snowflake account with appropriate permissions
- dbt project configured for Snowflake

## Setup

1. Create a `.env` file in the `airflow` directory with the following variables:

```
# Airflow
AIRFLOW_UID=50000
AIRFLOW_GID=0

# SQL Server
SQL_SERVER_HOST=your_sql_server_host
SQL_DATABASE=your_database
SQL_USERNAME=your_username
SQL_PASSWORD=your_password

# AWS S3
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=your_aws_region

# Snowflake
SNOWFLAKE_ACCOUNT=your_snowflake_account
SNOWFLAKE_USER=your_snowflake_user
SNOWFLAKE_PASSWORD=your_snowflake_password
SNOWFLAKE_DATABASE=your_snowflake_database
SNOWFLAKE_WAREHOUSE=your_snowflake_warehouse
SNOWFLAKE_ROLE=your_snowflake_role
```

2. Create Airflow connections:

After starting Airflow, you'll need to create the following connections in the Airflow UI:

- `snowflake_conn`: Connection to Snowflake
- `aws_conn`: Connection to AWS
- `mssql_conn`: Connection to SQL Server

## Running Airflow

1. Start the Airflow services:

```bash
cd airflow
docker-compose up -d
```

2. Access the Airflow UI at http://localhost:8080 (default username/password: airflow/airflow)

3. Enable the DAG in the Airflow UI

## DAG Configuration

The DAG is configured to run daily at 1:00 AM. You can modify the schedule in the DAG file.

### Airflow Variables

The DAG uses the following Airflow variables:

- `sql_server_host`: SQL Server hostname
- `sql_database`: SQL Server database name
- `sql_username`: SQL Server username
- `sql_password`: SQL Server password
- `sql_schema`: SQL Server schema (default: dbo)
- `s3_bucket`: AWS S3 bucket name
- `s3_prefix`: AWS S3 prefix for raw data
- `snowflake_account`: Snowflake account
- `snowflake_user`: Snowflake username
- `snowflake_password`: Snowflake password
- `snowflake_database`: Snowflake database
- `snowflake_warehouse`: Snowflake warehouse
- `snowflake_role`: Snowflake role
- `dbt_project_dir`: Path to dbt project directory

You can set these variables in the Airflow UI or via the Airflow CLI.

## Customization

### Adding More Tables

The DAG dynamically discovers tables to export from the `tbl_CASReportTableExport` table in SQL Server. You can add more tables by inserting rows into this table.

If the table doesn't exist, the DAG will fall back to a default list of tables: `tbl_Contract`, `tbl_Customer`, and `tbl_Vehicle`.

### Modifying Transformations

The dbt transformations are defined in the dbt project. You can modify the dbt models to customize the transformations.

## Monitoring

The Airflow UI provides monitoring capabilities for the DAG runs. You can view the task status, logs, and execution times.

## Troubleshooting

If you encounter issues with the DAG, check the task logs in the Airflow UI for detailed error messages.

Common issues:

- **SQL Server Connection**: Ensure the SQL Server ODBC driver is installed and the connection details are correct.
- **AWS S3 Access**: Verify the AWS credentials and bucket permissions.
- **Snowflake Connection**: Check the Snowflake connection details and permissions.
- **dbt Configuration**: Ensure the dbt project is properly configured for Snowflake.


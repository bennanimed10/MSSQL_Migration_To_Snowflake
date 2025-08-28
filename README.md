# Advanced Data Pipeline: SQL Server to Snowflake via AWS S3

This repository contains a complete data pipeline solution for exporting data from SQL Server, storing it in AWS S3, and loading it into Snowflake with dbt transformations.

## Pipeline Overview

![Data Pipeline Architecture](https://mermaid.ink/img/pako:eNqNkk9PwzAMxb9KlBMgdYFe9jdCQkgcEBInLiE4pK6zaLRJlTgwTeW74yZlGtIOPSWx_fz8bOcEhWoQCrjTrWl0Z1Gy2Ky1Qm_ZYbfRrUVvWGvYYbNTrfLWdEjOsEZbXDvVeXZnrDLIXpRHdmUcOvZgHDYqsM9KO_ZSK4-VCjyYRnWWvRvdqhbZWmvlkd0aZVXwYBxbK-2Vw1p5rHRvnbXqkT0Z1QYPxrJKOWQvyqJXwYNxbKWsVx5r5bFWvXXWqkf2bFQTPBjLKuWQvSqLXgUPxrGVsl55rJXHWvXWWase2YtRdfBgLKuUQ_amLHoVPBjHVsp65bFWHmvVW2eteuRQwJlwKGCPDYYvHQqHHAoYUCCHEoZUwqGCIVVwqGFINRwaGNIJhxaG1MHBwJDOcejgUMCQzuHQw5AucBjgUMKQLnEY4VDBkK5wGOFQw5CucZjgUMOQbnCY4NDAkG5xmODQwZDucJjg0MOQ7nGY4DDAkB5wmOAwwpAecZjgMMGQnnGY4DDDkF5wmOGwwJBecZjhsMKQ3nCY4WBgSO84zHDYYEgfOMxw2GFInzjMcDhgSF84zHA4YUjfOMxwuGBI_3CY4XDDkH5wmOHwwJB-cZjh8MKQ_uMww-GDIX3hMMPhhyF94zDD4YchfeAwwxGAIf3iMMNhgPMfGFdnrw)

The pipeline consists of the following components:

1. **SQL Server Export**: Extract data from SQL Server tables and export to CSV files
2. **AWS S3 Storage**: Store the CSV files in S3 buckets with a timestamp-based folder structure
3. **Snowflake Loading**: Load the data from S3 into Snowflake raw tables
4. **dbt Transformations**: Transform the raw data into staging, intermediate, and mart models
5. **Orchestration**: Coordinate the entire pipeline with shell scripts

## Prerequisites

- Python 3.7+
- SQL Server with ODBC drivers
- AWS account with S3 access
- Snowflake account
- dbt (data build tool)

## Setup Instructions

### 1. Environment Setup

1. Clone this repository
2. Create a virtual environment: `python -m venv venv`
3. Activate the virtual environment:
   - Windows: `venv\Scripts\activate`
   - Unix/Mac: `source venv/bin/activate`
4. Install dependencies: `pip install -r requirements.txt`
5. Copy `.env.example` to `.env` and fill in your configuration details

### 2. SQL Server Configuration

The SQL Server database should be set up with the tables you want to export. The existing SQL scripts in this repository can help set up a sample database:

- `0001_mssql_setup.sql`: Creates the database and tables
- `0002_sp_preprocess_castbls.sql`: Preprocesses tables for export
- `0003_sp_snapshot_timestamp_setup.sql`: Sets up timestamp tracking
- `0004_sp_cas_Snapshot_Export.sql`: Exports data to CSV files

### 3. AWS S3 Setup

1. Create an S3 bucket for storing the exported data
2. Configure AWS credentials in your `.env` file or use AWS CLI profiles

### 4. Snowflake Setup

1. Run the `snowflake_setup.sql` script to create the necessary Snowflake objects:
   - Database, schemas, and tables
   - File format and external stage
   - Stored procedures and tasks
   - Warehouse, role, and user for dbt

2. Configure your Snowflake connection in the dbt profiles:
   - Copy `profiles.yml.example` to `~/.dbt/profiles.yml`
   - Update with your Snowflake credentials

### 5. dbt Setup

1. Install dbt dependencies: `dbt deps`
2. Test the connection: `dbt debug`
3. Run the models: `dbt run`
4. Test the models: `dbt test`
5. Generate documentation: `dbt docs generate`

## Running the Pipeline

To run the complete pipeline:

```bash
./run_pipeline.sh
```

This script will:
1. Export data from SQL Server to CSV files
2. Upload the CSV files to S3
3. Load the data into Snowflake
4. Run dbt transformations
5. Generate documentation

## Pipeline Components

### SQL Server Export

The `sql_to_s3.py` script exports data from SQL Server tables to CSV files and uploads them to S3. It uses:

- pyodbc for SQL Server connection
- pandas for data processing
- boto3 for S3 uploads

### dbt Models

The dbt project is organized into three layers:

1. **Staging**: Clean and standardize raw data
   - `stg_contract.sql`
   - `stg_customer.sql`
   - `stg_vehicle.sql`

2. **Intermediate**: Join and transform staging models
   - `int_contracts_with_details.sql`

3. **Marts**: Business-level aggregations and metrics
   - `fct_contracts.sql`
   - `dim_customers.sql`

### Snowflake Integration

Snowflake is configured with:

- External stage pointing to S3
- Stored procedure for loading data
- Scheduled task for daily loads
- Dedicated warehouse and role for dbt

## Maintenance and Monitoring

- Pipeline logs are stored in the `pipeline_*.log` files
- dbt logs are available in the `logs/` directory
- Snowflake query history can be used to monitor load operations

## Extending the Pipeline

To add new tables to the pipeline:

1. Add the table to `tbl_CASReportTableExport` in SQL Server
2. Create a staging model in `models/staging/`
3. Update intermediate and mart models as needed
4. Add the table to the Snowflake load procedure

## License

This project is licensed under the MIT License - see the LICENSE file for details.


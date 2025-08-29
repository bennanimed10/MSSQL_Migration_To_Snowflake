"""
Airflow DAG for SQL Server to Snowflake Data Pipeline

This DAG orchestrates the entire data pipeline:
1. Extract data from SQL Server
2. Upload to AWS S3
3. Load into Snowflake
4. Transform with dbt

Schedule: Daily at 1:00 AM
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.providers.snowflake.operators.snowflake import SnowflakeOperator
from airflow.providers.amazon.aws.transfers.sql_to_s3 import SqlToS3Operator
from airflow.providers.amazon.aws.transfers.s3_to_snowflake import S3ToSnowflakeOperator
from airflow.models import Variable
from airflow.utils.task_group import TaskGroup
import os
import sys
import logging
import pandas as pd
import pyodbc
import boto3
from datetime import datetime
import gzip
import shutil
from pathlib import Path
from botocore.exceptions import ClientError

# Default arguments for the DAG
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 3,
    'retry_delay': timedelta(minutes=5),
    'start_date': datetime(2023, 1, 1),
}

# Create the DAG
dag = DAG(
    'mssql_to_snowflake_pipeline',
    default_args=default_args,
    description='SQL Server to Snowflake Data Pipeline',
    schedule_interval='0 1 * * *',  # Daily at 1:00 AM
    catchup=False,
    max_active_runs=1,
    tags=['sql_server', 'snowflake', 's3', 'dbt'],
)

# Get configuration from Airflow Variables
SQL_SERVER = Variable.get("sql_server_host", "localhost")
SQL_DATABASE = Variable.get("sql_database", "cas_snowflake_data_export")
SQL_USERNAME = Variable.get("sql_username", "")
SQL_PASSWORD = Variable.get("sql_password", "")
SQL_SCHEMA = Variable.get("sql_schema", "dbo")

S3_BUCKET = Variable.get("s3_bucket", "my-data-pipeline-bucket")
S3_PREFIX = Variable.get("s3_prefix", "raw-data")

SNOWFLAKE_ACCOUNT = Variable.get("snowflake_account", "")
SNOWFLAKE_USER = Variable.get("snowflake_user", "")
SNOWFLAKE_PASSWORD = Variable.get("snowflake_password", "")
SNOWFLAKE_DATABASE = Variable.get("snowflake_database", "CAS_DATA")
SNOWFLAKE_WAREHOUSE = Variable.get("snowflake_warehouse", "COMPUTE_WH")
SNOWFLAKE_ROLE = Variable.get("snowflake_role", "ACCOUNTADMIN")

# Path to the dbt project
DBT_PROJECT_DIR = Variable.get("dbt_project_dir", "/opt/airflow/dags/dbt")

# Define Python function to export data from SQL Server to S3
def export_table_to_s3(table_name, schema, **kwargs):
    """
    Export a table from SQL Server to S3
    """
    # Configure logging
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger(f"export_{table_name}")
    
    # Generate timestamp for the export
    timestamp = kwargs['ts_nodash']
    s3_path = f"{S3_PREFIX}/{timestamp[:8]}/{timestamp[8:]}"
    
    try:
        # Connect to SQL Server
        conn_params = {
            'DRIVER': '{ODBC Driver 17 for SQL Server}',
            'SERVER': SQL_SERVER,
            'DATABASE': SQL_DATABASE
        }
        
        if SQL_USERNAME and SQL_PASSWORD:
            conn_params['UID'] = SQL_USERNAME
            conn_params['PWD'] = SQL_PASSWORD
        else:
            conn_params['Trusted_Connection'] = 'yes'
        
        # Build connection string
        conn_str_parts = []
        for key, value in conn_params.items():
            conn_str_parts.append(f"{key}={value}")
        
        conn_str = ';'.join(conn_str_parts)
        logger.info(f"Connecting to SQL Server: {SQL_SERVER}, Database: {SQL_DATABASE}")
        
        # Create connection and export data
        conn = pyodbc.connect(conn_str)
        
        # Create a temporary directory for the CSV file
        temp_dir = f"/tmp/export_{timestamp}"
        os.makedirs(temp_dir, exist_ok=True)
        
        # Export to CSV
        csv_path = os.path.join(temp_dir, f"{table_name}.csv")
        compressed_path = f"{csv_path}.gz"
        
        # Read data from SQL Server
        query = f"SELECT * FROM {schema}.{table_name}"
        df = pd.read_sql(query, conn)
        
        # Write to CSV
        df.to_csv(csv_path, index=False, sep='|')
        
        # Compress the CSV file
        with open(csv_path, 'rb') as f_in:
            with gzip.open(compressed_path, 'wb') as f_out:
                shutil.copyfileobj(f_in, f_out)
        
        # Upload to S3
        s3_client = boto3.client('s3')
        s3_key = f"{s3_path}/{table_name}.csv.gz"
        
        logger.info(f"Uploading {compressed_path} to s3://{S3_BUCKET}/{s3_key}")
        s3_client.upload_file(compressed_path, S3_BUCKET, s3_key)
        logger.info(f"Successfully uploaded to s3://{S3_BUCKET}/{s3_key}")
        
        # Clean up
        os.remove(csv_path)
        os.remove(compressed_path)
        os.rmdir(temp_dir)
        conn.close()
        
        # Return the S3 path for downstream tasks
        return f"s3://{S3_BUCKET}/{s3_key}"
    
    except Exception as e:
        logger.error(f"Error exporting {schema}.{table_name}: {e}")
        raise

# Get list of tables to export
def get_tables_to_export(**kwargs):
    """
    Get the list of tables to export from SQL Server
    """
    try:
        # Connect to SQL Server
        conn_params = {
            'DRIVER': '{ODBC Driver 17 for SQL Server}',
            'SERVER': SQL_SERVER,
            'DATABASE': SQL_DATABASE
        }
        
        if SQL_USERNAME and SQL_PASSWORD:
            conn_params['UID'] = SQL_USERNAME
            conn_params['PWD'] = SQL_PASSWORD
        else:
            conn_params['Trusted_Connection'] = 'yes'
        
        # Build connection string
        conn_str_parts = []
        for key, value in conn_params.items():
            conn_str_parts.append(f"{key}={value}")
        
        conn_str = ';'.join(conn_str_parts)
        
        # Create connection
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        
        # Query to get tables from tbl_CASReportTableExport
        cursor.execute("""
            SELECT table_name
            FROM tbl_CASReportTableExport
            WHERE database_name = ?
        """, (SQL_DATABASE,))
        
        tables = [row.table_name for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        
        return tables
    
    except Exception as e:
        logging.error(f"Error getting tables to export: {e}")
        # Return a default list of tables if the query fails
        return ['tbl_Contract', 'tbl_Customer', 'tbl_Vehicle']

# Task to get the list of tables
get_tables_task = PythonOperator(
    task_id='get_tables_to_export',
    python_callable=get_tables_to_export,
    provide_context=True,
    dag=dag,
)

# Create a task group for SQL Server export tasks
with TaskGroup(group_id='export_tables_to_s3', dag=dag) as export_group:
    # This will be dynamically populated based on the output of get_tables_task
    # We'll create a placeholder task that will be replaced at runtime
    export_placeholder = BashOperator(
        task_id='export_placeholder',
        bash_command='echo "This is a placeholder task that will be replaced at runtime"',
    )

# Create a task to prepare Snowflake for data loading
snowflake_setup = SnowflakeOperator(
    task_id='snowflake_setup',
    snowflake_conn_id='snowflake_conn',
    sql="""
    -- Create schemas if they don't exist
    CREATE SCHEMA IF NOT EXISTS {{ params.database }}.RAW;
    CREATE SCHEMA IF NOT EXISTS {{ params.database }}.STAGING;
    CREATE SCHEMA IF NOT EXISTS {{ params.database }}.INTERMEDIATE;
    CREATE SCHEMA IF NOT EXISTS {{ params.database }}.MARTS;
    
    -- Create file format for CSV files
    CREATE OR REPLACE FILE FORMAT {{ params.database }}.RAW.CSV_FORMAT
        TYPE = 'CSV'
        FIELD_DELIMITER = '|'
        SKIP_HEADER = 1
        NULL_IF = ('NULL', 'null')
        EMPTY_FIELD_AS_NULL = TRUE
        COMPRESSION = GZIP;
    
    -- Create external stage pointing to S3
    CREATE OR REPLACE STAGE {{ params.database }}.RAW.S3_STAGE
        URL = 's3://{{ params.s3_bucket }}/{{ params.s3_prefix }}'
        FILE_FORMAT = {{ params.database }}.RAW.CSV_FORMAT;
    """,
    params={
        'database': SNOWFLAKE_DATABASE,
        's3_bucket': S3_BUCKET,
        's3_prefix': S3_PREFIX
    },
    dag=dag,
)

# Create a task group for loading data into Snowflake
with TaskGroup(group_id='load_to_snowflake', dag=dag) as load_group:
    # This will be dynamically populated based on the output of get_tables_task
    # We'll create a placeholder task that will be replaced at runtime
    load_placeholder = BashOperator(
        task_id='load_placeholder',
        bash_command='echo "This is a placeholder task that will be replaced at runtime"',
    )

# Run dbt to transform the data
dbt_run = BashOperator(
    task_id='dbt_run',
    bash_command=f"""
    cd {DBT_PROJECT_DIR} && \
    dbt deps && \
    dbt run --profiles-dir {DBT_PROJECT_DIR} --target prod
    """,
    dag=dag,
)

# Run dbt tests
dbt_test = BashOperator(
    task_id='dbt_test',
    bash_command=f"""
    cd {DBT_PROJECT_DIR} && \
    dbt test --profiles-dir {DBT_PROJECT_DIR} --target prod
    """,
    dag=dag,
)

# Generate dbt documentation
dbt_docs = BashOperator(
    task_id='dbt_docs',
    bash_command=f"""
    cd {DBT_PROJECT_DIR} && \
    dbt docs generate --profiles-dir {DBT_PROJECT_DIR} --target prod
    """,
    dag=dag,
)

# Define task dependencies
get_tables_task >> export_group >> snowflake_setup >> load_group >> dbt_run >> dbt_test >> dbt_docs

# Dynamic task generation based on the output of get_tables_task
def create_dynamic_tasks(context, dag_run=None):
    """
    Create dynamic tasks based on the list of tables returned by get_tables_task
    """
    tables = context['ti'].xcom_pull(task_ids='get_tables_to_export')
    
    if not tables:
        logging.warning("No tables found to export")
        return
    
    # Clear the placeholder tasks
    dag.get_task('export_tables_to_s3.export_placeholder').skip(context['execution_date'])
    dag.get_task('load_to_snowflake.load_placeholder').skip(context['execution_date'])
    
    # Create export tasks
    export_tasks = []
    for table in tables:
        export_task = PythonOperator(
            task_id=f'export_{table}_to_s3',
            python_callable=export_table_to_s3,
            op_kwargs={'table_name': table, 'schema': SQL_SCHEMA},
            provide_context=True,
            dag=dag,
            task_group=export_group,
        )
        export_tasks.append(export_task)
        get_tables_task >> export_task
    
    # Create load tasks
    load_tasks = []
    for table in tables:
        # Create or replace the table in Snowflake
        create_table_task = SnowflakeOperator(
            task_id=f'create_{table}_table',
            snowflake_conn_id='snowflake_conn',
            sql=f"""
            CREATE TABLE IF NOT EXISTS {SNOWFLAKE_DATABASE}.RAW.{table.upper()} (
                -- This is a simplified schema, you would need to adjust based on your actual table structure
                -- The VARIANT column allows us to load the data without knowing the schema in advance
                DATA VARIANT,
                _FILENAME VARCHAR(255),
                _LOADED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
            );
            """,
            dag=dag,
            task_group=load_group,
        )
        
        # Load data from S3 to Snowflake
        load_task = SnowflakeOperator(
            task_id=f'load_{table}_to_snowflake',
            snowflake_conn_id='snowflake_conn',
            sql=f"""
            COPY INTO {SNOWFLAKE_DATABASE}.RAW.{table.upper()} (DATA, _FILENAME)
            FROM @{SNOWFLAKE_DATABASE}.RAW.S3_STAGE/{context['ts_nodash'][:8]}/{context['ts_nodash'][8:]}/ 
            FILES = ('{table}.csv.gz')
            FILE_FORMAT = (FORMAT_NAME = {SNOWFLAKE_DATABASE}.RAW.CSV_FORMAT)
            PATTERN = '.*{table}.csv.gz'
            ON_ERROR = 'CONTINUE';
            """,
            dag=dag,
            task_group=load_group,
        )
        
        load_tasks.append(load_task)
        snowflake_setup >> create_table_task >> load_task
        
        # Connect export tasks to load tasks
        for export_task in export_tasks:
            if export_task.task_id.startswith(f'export_{table}_'):
                export_task >> create_table_task
    
    # Connect load tasks to dbt_run
    for load_task in load_tasks:
        load_task >> dbt_run

# Add a listener to create dynamic tasks
get_tables_task.set_downstream(
    PythonOperator(
        task_id='create_dynamic_tasks',
        python_callable=create_dynamic_tasks,
        provide_context=True,
        dag=dag,
    )
)

if __name__ == "__main__":
    dag.cli()


"""
AWS Lambda function for orchestrating SQL Server to Snowflake migration.
This function handles S3 events, coordinates data loading, and manages the migration workflow.
"""

import json
import boto3
import os
import logging
from datetime import datetime, timezone
from typing import Dict, List, Any, Optional
import snowflake.connector
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
sns_client = boto3.client('sns')
dms_client = boto3.client('dms')
cloudwatch = boto3.client('cloudwatch')

# Environment variables
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')
S3_STAGING_BUCKET = os.environ.get('S3_STAGING_BUCKET')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
SNOWFLAKE_ACCOUNT = os.environ.get('SNOWFLAKE_ACCOUNT')
SNOWFLAKE_USER = os.environ.get('SNOWFLAKE_USER')
SNOWFLAKE_ROLE = os.environ.get('SNOWFLAKE_ROLE', 'MIGRATION_USER')
SNOWFLAKE_WAREHOUSE = os.environ.get('SNOWFLAKE_WAREHOUSE', 'MIGRATION_WH')
SNOWFLAKE_DATABASE = os.environ.get('SNOWFLAKE_DATABASE', 'MIGRATION_DB')

class MigrationOrchestrator:
    """Main orchestrator class for migration operations."""
    
    def __init__(self):
        self.snowflake_conn = None
        
    def get_snowflake_connection(self) -> snowflake.connector.SnowflakeConnection:
        """Establish connection to Snowflake."""
        if self.snowflake_conn is None:
            try:
                # In production, use AWS Secrets Manager for credentials
                password = self._get_secret('snowflake-password')
                
                self.snowflake_conn = snowflake.connector.connect(
                    user=SNOWFLAKE_USER,
                    password=password,
                    account=SNOWFLAKE_ACCOUNT,
                    warehouse=SNOWFLAKE_WAREHOUSE,
                    database=SNOWFLAKE_DATABASE,
                    schema='PUBLIC',
                    role=SNOWFLAKE_ROLE
                )
                logger.info("Successfully connected to Snowflake")
            except Exception as e:
                logger.error(f"Failed to connect to Snowflake: {str(e)}")
                raise
                
        return self.snowflake_conn
    
    def _get_secret(self, secret_name: str) -> str:
        """Retrieve secret from AWS Secrets Manager."""
        try:
            secrets_client = boto3.client('secretsmanager')
            response = secrets_client.get_secret_value(SecretId=secret_name)
            return response['SecretString']
        except ClientError as e:
            logger.error(f"Failed to retrieve secret {secret_name}: {str(e)}")
            # Fallback to environment variable for development
            return os.environ.get('SNOWFLAKE_PASSWORD', '')
    
    def process_s3_event(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Process S3 event and trigger appropriate migration actions."""
        results = []
        
        for record in event.get('Records', []):
            if record.get('eventSource') == 'aws:s3':
                s3_info = record['s3']
                bucket_name = s3_info['bucket']['name']
                object_key = s3_info['object']['key']
                event_name = record['eventName']
                
                logger.info(f"Processing S3 event: {event_name} for {bucket_name}/{object_key}")
                
                try:
                    result = self._handle_s3_object(bucket_name, object_key, event_name)
                    results.append(result)
                except Exception as e:
                    logger.error(f"Error processing S3 object {object_key}: {str(e)}")
                    self._send_error_notification(f"Failed to process {object_key}", str(e))
                    results.append({
                        'object_key': object_key,
                        'status': 'error',
                        'message': str(e)
                    })
        
        return {'processed_objects': results}
    
    def _handle_s3_object(self, bucket_name: str, object_key: str, event_name: str) -> Dict[str, Any]:
        """Handle individual S3 object based on its path and type."""
        
        # Determine the type of data based on S3 path
        if 'dms-output/full-load/' in object_key:
            return self._process_full_load_file(bucket_name, object_key)
        elif 'dms-output/cdc/' in object_key:
            return self._process_cdc_file(bucket_name, object_key)
        elif 'manual-load/' in object_key:
            return self._process_manual_load_file(bucket_name, object_key)
        else:
            logger.info(f"Ignoring file {object_key} - not in a monitored path")
            return {
                'object_key': object_key,
                'status': 'ignored',
                'message': 'File not in monitored path'
            }
    
    def _process_full_load_file(self, bucket_name: str, object_key: str) -> Dict[str, Any]:
        """Process full load parquet file from DMS."""
        logger.info(f"Processing full load file: {object_key}")
        
        try:
            # Extract table information from file path
            table_info = self._extract_table_info_from_path(object_key)
            
            # Log migration start
            migration_id = self._log_migration_start(table_info['table_name'], 'FULL_LOAD', object_key)
            
            # Execute Snowflake COPY command
            rows_loaded = self._execute_snowflake_copy(
                table_info['table_name'],
                f"s3://{bucket_name}/{object_key}",
                'FULL_LOAD'
            )
            
            # Log migration completion
            self._log_migration_completion(migration_id, 'SUCCESS', rows_loaded)
            
            # Send success notification
            self._send_success_notification(
                f"Full load completed for {table_info['table_name']}",
                f"Loaded {rows_loaded} rows from {object_key}"
            )
            
            # Update CloudWatch metrics
            self._update_cloudwatch_metrics('FullLoadSuccess', 1, table_info['table_name'])
            self._update_cloudwatch_metrics('RowsLoaded', rows_loaded, table_info['table_name'])
            
            return {
                'object_key': object_key,
                'status': 'success',
                'table_name': table_info['table_name'],
                'rows_loaded': rows_loaded,
                'migration_id': migration_id
            }
            
        except Exception as e:
            logger.error(f"Error processing full load file {object_key}: {str(e)}")
            self._log_migration_completion(migration_id if 'migration_id' in locals() else None, 'FAILED', 0, str(e))
            self._update_cloudwatch_metrics('FullLoadError', 1, table_info.get('table_name', 'unknown'))
            raise
    
    def _process_cdc_file(self, bucket_name: str, object_key: str) -> Dict[str, Any]:
        """Process CDC parquet file from DMS."""
        logger.info(f"Processing CDC file: {object_key}")
        
        try:
            # Extract table information from file path
            table_info = self._extract_table_info_from_path(object_key)
            
            # Log migration start
            migration_id = self._log_migration_start(table_info['table_name'], 'CDC', object_key)
            
            # Execute Snowflake COPY command for CDC data
            rows_processed = self._execute_snowflake_copy(
                table_info['table_name'],
                f"s3://{bucket_name}/{object_key}",
                'CDC'
            )
            
            # Apply CDC changes to target table
            changes_applied = self._apply_cdc_changes(table_info['table_name'])
            
            # Log migration completion
            self._log_migration_completion(migration_id, 'SUCCESS', changes_applied)
            
            # Update CloudWatch metrics
            self._update_cloudwatch_metrics('CDCSuccess', 1, table_info['table_name'])
            self._update_cloudwatch_metrics('CDCChangesApplied', changes_applied, table_info['table_name'])
            
            return {
                'object_key': object_key,
                'status': 'success',
                'table_name': table_info['table_name'],
                'rows_processed': rows_processed,
                'changes_applied': changes_applied,
                'migration_id': migration_id
            }
            
        except Exception as e:
            logger.error(f"Error processing CDC file {object_key}: {str(e)}")
            self._log_migration_completion(migration_id if 'migration_id' in locals() else None, 'FAILED', 0, str(e))
            self._update_cloudwatch_metrics('CDCError', 1, table_info.get('table_name', 'unknown'))
            raise
    
    def _process_manual_load_file(self, bucket_name: str, object_key: str) -> Dict[str, Any]:
        """Process manually uploaded file."""
        logger.info(f"Processing manual load file: {object_key}")
        
        # For manual loads, we might need different handling
        # This is a placeholder for custom logic
        return {
            'object_key': object_key,
            'status': 'manual_load_detected',
            'message': 'Manual load files require separate processing'
        }
    
    def _extract_table_info_from_path(self, object_key: str) -> Dict[str, str]:
        """Extract table information from S3 object key."""
        # Example path: dms-output/full-load/public/customers/20241002/customers_20241002_123456.parquet
        path_parts = object_key.split('/')
        
        if len(path_parts) >= 4:
            schema_name = path_parts[2] if path_parts[2] != 'public' else 'PUBLIC'
            table_name = path_parts[3]
            
            return {
                'schema_name': schema_name,
                'table_name': table_name,
                'full_table_name': f"{schema_name}.{table_name}"
            }
        else:
            raise ValueError(f"Cannot extract table info from path: {object_key}")
    
    def _execute_snowflake_copy(self, table_name: str, s3_path: str, load_type: str) -> int:
        """Execute COPY command in Snowflake."""
        conn = self.get_snowflake_connection()
        cursor = conn.cursor()
        
        try:
            if load_type == 'FULL_LOAD':
                # For full load, copy directly to target table
                copy_sql = f"""
                COPY INTO {SNOWFLAKE_DATABASE}.PUBLIC.{table_name}
                FROM '{s3_path}'
                FILE_FORMAT = (TYPE = 'PARQUET')
                MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
                ON_ERROR = 'CONTINUE'
                PURGE = FALSE
                """
            else:  # CDC
                # For CDC, copy to staging table first
                copy_sql = f"""
                COPY INTO {SNOWFLAKE_DATABASE}.STAGING.{table_name}_CDC_STAGING
                FROM '{s3_path}'
                FILE_FORMAT = (TYPE = 'PARQUET')
                MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
                ON_ERROR = 'CONTINUE'
                PURGE = FALSE
                """
            
            logger.info(f"Executing COPY command: {copy_sql}")
            cursor.execute(copy_sql)
            
            # Get the number of rows loaded
            result = cursor.fetchone()
            rows_loaded = result[1] if result else 0  # Second column contains rows_loaded
            
            logger.info(f"Successfully loaded {rows_loaded} rows for {table_name}")
            return rows_loaded
            
        except Exception as e:
            logger.error(f"Error executing COPY command: {str(e)}")
            raise
        finally:
            cursor.close()
    
    def _apply_cdc_changes(self, table_name: str) -> int:
        """Apply CDC changes from staging table to target table."""
        conn = self.get_snowflake_connection()
        cursor = conn.cursor()
        
        try:
            # This is a simplified CDC application logic
            # In production, you'd want more sophisticated handling
            merge_sql = f"""
            MERGE INTO {SNOWFLAKE_DATABASE}.PUBLIC.{table_name} AS target
            USING {SNOWFLAKE_DATABASE}.STAGING.{table_name}_CDC_STAGING AS source
            ON target.id = source.id  -- Assuming 'id' is the primary key
            WHEN MATCHED AND source.dms_operation = 'U' THEN UPDATE SET *
            WHEN MATCHED AND source.dms_operation = 'D' THEN DELETE
            WHEN NOT MATCHED AND source.dms_operation IN ('I', 'U') THEN INSERT *
            """
            
            logger.info(f"Applying CDC changes: {merge_sql}")
            cursor.execute(merge_sql)
            
            # Get the number of rows affected
            result = cursor.fetchone()
            rows_affected = result[0] if result else 0
            
            # Clean up staging table
            cursor.execute(f"TRUNCATE TABLE {SNOWFLAKE_DATABASE}.STAGING.{table_name}_CDC_STAGING")
            
            logger.info(f"Successfully applied {rows_affected} CDC changes for {table_name}")
            return rows_affected
            
        except Exception as e:
            logger.error(f"Error applying CDC changes: {str(e)}")
            raise
        finally:
            cursor.close()
    
    def _log_migration_start(self, table_name: str, operation: str, s3_path: str) -> str:
        """Log migration start in Snowflake audit table."""
        migration_id = f"{table_name}_{operation}_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}"
        
        conn = self.get_snowflake_connection()
        cursor = conn.cursor()
        
        try:
            insert_sql = f"""
            INSERT INTO {SNOWFLAKE_DATABASE}.AUDIT.MIGRATION_LOG 
            (MIGRATION_ID, TABLE_NAME, OPERATION, STATUS, START_TIME, S3_PATH)
            VALUES ('{migration_id}', '{table_name}', '{operation}', 'RUNNING', CURRENT_TIMESTAMP(), '{s3_path}')
            """
            cursor.execute(insert_sql)
            logger.info(f"Logged migration start: {migration_id}")
            return migration_id
        except Exception as e:
            logger.error(f"Error logging migration start: {str(e)}")
            return migration_id  # Return ID even if logging fails
        finally:
            cursor.close()
    
    def _log_migration_completion(self, migration_id: str, status: str, rows_processed: int, error_message: str = None):
        """Log migration completion in Snowflake audit table."""
        if not migration_id:
            return
            
        conn = self.get_snowflake_connection()
        cursor = conn.cursor()
        
        try:
            update_sql = f"""
            UPDATE {SNOWFLAKE_DATABASE}.AUDIT.MIGRATION_LOG 
            SET STATUS = '{status}',
                END_TIME = CURRENT_TIMESTAMP(),
                DURATION_SECONDS = DATEDIFF('second', START_TIME, CURRENT_TIMESTAMP()),
                ROWS_PROCESSED = {rows_processed},
                ERROR_MESSAGE = {'NULL' if not error_message else f"'{error_message[:4000]}'"}
            WHERE MIGRATION_ID = '{migration_id}'
            """
            cursor.execute(update_sql)
            logger.info(f"Logged migration completion: {migration_id} - {status}")
        except Exception as e:
            logger.error(f"Error logging migration completion: {str(e)}")
        finally:
            cursor.close()
    
    def _update_cloudwatch_metrics(self, metric_name: str, value: float, table_name: str):
        """Update CloudWatch custom metrics."""
        try:
            cloudwatch.put_metric_data(
                Namespace='Migration/SQLServer-Snowflake',
                MetricData=[
                    {
                        'MetricName': metric_name,
                        'Value': value,
                        'Unit': 'Count',
                        'Dimensions': [
                            {
                                'Name': 'Environment',
                                'Value': ENVIRONMENT
                            },
                            {
                                'Name': 'TableName',
                                'Value': table_name
                            }
                        ],
                        'Timestamp': datetime.now(timezone.utc)
                    }
                ]
            )
        except Exception as e:
            logger.error(f"Error updating CloudWatch metrics: {str(e)}")
    
    def _send_success_notification(self, subject: str, message: str):
        """Send success notification via SNS."""
        if SNS_TOPIC_ARN:
            try:
                sns_client.publish(
                    TopicArn=SNS_TOPIC_ARN,
                    Subject=f"[{ENVIRONMENT.upper()}] Migration Success: {subject}",
                    Message=message
                )
            except Exception as e:
                logger.error(f"Error sending success notification: {str(e)}")
    
    def _send_error_notification(self, subject: str, error_message: str):
        """Send error notification via SNS."""
        if SNS_TOPIC_ARN:
            try:
                sns_client.publish(
                    TopicArn=SNS_TOPIC_ARN,
                    Subject=f"[{ENVIRONMENT.upper()}] Migration Error: {subject}",
                    Message=f"Error occurred during migration:\n\n{error_message}"
                )
            except Exception as e:
                logger.error(f"Error sending error notification: {str(e)}")
    
    def close_connections(self):
        """Close database connections."""
        if self.snowflake_conn:
            self.snowflake_conn.close()
            self.snowflake_conn = None


def lambda_handler(event, context):
    """Main Lambda handler function."""
    logger.info(f"Received event: {json.dumps(event)}")
    
    orchestrator = MigrationOrchestrator()
    
    try:
        # Handle different event sources
        if 'Records' in event:
            # S3 event
            result = orchestrator.process_s3_event(event)
        elif 'source' in event and event['source'] == 'aws.events':
            # EventBridge scheduled event
            result = {'message': 'Scheduled event received but no action defined'}
        else:
            # Direct invocation or other event types
            result = {'message': 'Event processed but no specific action taken'}
        
        logger.info(f"Processing completed successfully: {result}")
        
        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
        
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        
        # Send error notification
        orchestrator._send_error_notification(
            "Lambda Function Error",
            f"Error in migration orchestrator: {str(e)}"
        )
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'message': 'Migration orchestration failed'
            })
        }
    
    finally:
        orchestrator.close_connections()


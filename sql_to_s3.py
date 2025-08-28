#!/usr/bin/env python3
"""
SQL Server to AWS S3 Data Export Pipeline

This script extracts data from SQL Server tables, exports to CSV files,
and uploads them to an AWS S3 bucket.
"""

import os
import sys
import logging
import argparse
import pandas as pd
import pyodbc
import boto3
from datetime import datetime
import gzip
import shutil
from pathlib import Path
from botocore.exceptions import ClientError
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("sql_to_s3.log"),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Export SQL Server data to S3')
    parser.add_argument('--server', required=True, help='SQL Server hostname')
    parser.add_argument('--database', required=True, help='Database name')
    parser.add_argument('--schema', default='dbo', help='Schema name (default: dbo)')
    parser.add_argument('--tables', help='Comma-separated list of tables to export (default: all)')
    parser.add_argument('--output-dir', default='./data', help='Local directory for CSV files')
    parser.add_argument('--s3-bucket', required=True, help='S3 bucket name')
    parser.add_argument('--s3-prefix', default='raw-data', help='S3 prefix/folder')
    parser.add_argument('--use-trusted-connection', action='store_true', help='Use Windows authentication')
    parser.add_argument('--username', help='SQL Server username (if not using trusted connection)')
    parser.add_argument('--password', help='SQL Server password (if not using trusted connection)')
    
    return parser.parse_args()

def get_connection(args):
    """Create a connection to SQL Server."""
    try:
        if args.use_trusted_connection:
            conn_str = f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={args.server};DATABASE={args.database};Trusted_Connection=yes;'
        else:
            # Use environment variables for sensitive information if available
            username = args.username or os.environ.get('SQL_USERNAME')
            password = args.password or os.environ.get('SQL_PASSWORD')
            
            if not username or not password:
                logger.error("SQL Server username and password must be provided via arguments or environment variables")
                sys.exit(1)
                
            conn_str = f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={args.server};DATABASE={args.database};UID={username};PWD={password}'
        
        return pyodbc.connect(conn_str)
    except pyodbc.Error as e:
        logger.error(f"Failed to connect to SQL Server: {e}")
        sys.exit(1)

def get_table_list(conn, schema, tables_arg):
    """Get list of tables to export."""
    if tables_arg:
        return [t.strip() for t in tables_arg.split(',')]
    
    # If no tables specified, get all tables from the schema
    cursor = conn.cursor()
    cursor.execute(f"""
        SELECT TABLE_NAME 
        FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_SCHEMA = '{schema}' AND TABLE_TYPE = 'BASE TABLE'
    """)
    tables = [row.TABLE_NAME for row in cursor.fetchall()]
    cursor.close()
    
    return tables

def export_table_to_csv(conn, schema, table, output_dir):
    """Export a table to CSV file."""
    output_path = os.path.join(output_dir, f"{table}.csv")
    compressed_path = f"{output_path}.gz"
    
    try:
        logger.info(f"Exporting {schema}.{table} to {output_path}")
        
        # Read data from SQL Server
        query = f"SELECT * FROM {schema}.{table}"
        df = pd.read_sql(query, conn)
        
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        # Write to CSV
        df.to_csv(output_path, index=False, sep='|')
        
        # Compress the CSV file
        with open(output_path, 'rb') as f_in:
            with gzip.open(compressed_path, 'wb') as f_out:
                shutil.copyfileobj(f_in, f_out)
        
        # Remove the uncompressed file
        os.remove(output_path)
        
        logger.info(f"Successfully exported and compressed {schema}.{table}")
        return compressed_path
    
    except Exception as e:
        logger.error(f"Error exporting {schema}.{table}: {e}")
        if os.path.exists(output_path):
            os.remove(output_path)
        if os.path.exists(compressed_path):
            os.remove(compressed_path)
        return None

def upload_to_s3(file_path, bucket, s3_key):
    """Upload a file to S3."""
    # Use environment variables for AWS credentials if not already configured
    aws_access_key = os.environ.get('AWS_ACCESS_KEY_ID')
    aws_secret_key = os.environ.get('AWS_SECRET_ACCESS_KEY')
    aws_region = os.environ.get('AWS_REGION', 'us-east-1')
    
    # Create S3 client with or without explicit credentials
    if aws_access_key and aws_secret_key:
        s3_client = boto3.client(
            's3',
            region_name=aws_region,
            aws_access_key_id=aws_access_key,
            aws_secret_access_key=aws_secret_key
        )
    else:
        # Use default credential provider chain (environment, ~/.aws/credentials, IAM role)
        s3_client = boto3.client('s3', region_name=aws_region)
    
    try:
        logger.info(f"Uploading {file_path} to s3://{bucket}/{s3_key}")
        s3_client.upload_file(file_path, bucket, s3_key)
        logger.info(f"Successfully uploaded to s3://{bucket}/{s3_key}")
        return True
    except ClientError as e:
        logger.error(f"Error uploading to S3: {e}")
        return False

def main():
    """Main function to export data from SQL Server to S3."""
    args = parse_args()
    
    # Create timestamp for the export
    timestamp = datetime.now().strftime("%Y/%m/%d/%H/%M/%S")
    export_dir = os.path.join(args.output_dir, args.database.lower())
    
    # Connect to SQL Server
    conn = get_connection(args)
    
    # Get list of tables to export
    tables = get_table_list(conn, args.schema, args.tables)
    logger.info(f"Found {len(tables)} tables to export")
    
    # Export each table and upload to S3
    for table in tables:
        # Export table to CSV
        csv_path = export_table_to_csv(conn, args.schema, table, export_dir)
        if not csv_path:
            continue
        
        # Upload to S3
        file_name = os.path.basename(csv_path)
        s3_key = f"{args.s3_prefix}/{timestamp}/{file_name}"
        upload_to_s3(csv_path, args.s3_bucket, s3_key)
    
    conn.close()
    logger.info("Export completed successfully")

if __name__ == "__main__":
    main()

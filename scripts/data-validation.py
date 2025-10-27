#!/usr/bin/env python3
"""
Data Validation Script for SQL Server to Snowflake Migration
This script performs comprehensive data validation between source and target systems.
"""

import os
import sys
import logging
import argparse
import yaml
import json
from datetime import datetime, timezone
from typing import Dict, List, Any, Optional, Tuple
import pandas as pd
import pyodbc
import snowflake.connector
from dataclasses import dataclass

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('data_validation.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

@dataclass
class ValidationResult:
    """Data class for validation results."""
    table_name: str
    check_type: str
    check_name: str
    status: str
    expected_value: Any
    actual_value: Any
    variance: float
    message: str
    timestamp: datetime

class DatabaseConnector:
    """Base class for database connections."""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.connection = None
    
    def connect(self):
        """Establish database connection."""
        raise NotImplementedError
    
    def disconnect(self):
        """Close database connection."""
        if self.connection:
            self.connection.close()
            self.connection = None
    
    def execute_query(self, query: str) -> pd.DataFrame:
        """Execute query and return results as DataFrame."""
        raise NotImplementedError

class SQLServerConnector(DatabaseConnector):
    """SQL Server database connector."""
    
    def connect(self):
        """Establish SQL Server connection."""
        try:
            connection_string = (
                f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                f"SERVER={self.config['host']},{self.config['port']};"
                f"DATABASE={self.config['database']};"
                f"UID={self.config['username']};"
                f"PWD={self.config['password']};"
                f"TrustServerCertificate=yes;"
                f"Encrypt=yes;"
            )
            
            self.connection = pyodbc.connect(connection_string)
            logger.info("Connected to SQL Server successfully")
        except Exception as e:
            logger.error(f"Failed to connect to SQL Server: {str(e)}")
            raise
    
    def execute_query(self, query: str) -> pd.DataFrame:
        """Execute SQL Server query."""
        if not self.connection:
            self.connect()
        
        try:
            return pd.read_sql(query, self.connection)
        except Exception as e:
            logger.error(f"Error executing SQL Server query: {str(e)}")
            raise

class SnowflakeConnector(DatabaseConnector):
    """Snowflake database connector."""
    
    def connect(self):
        """Establish Snowflake connection."""
        try:
            self.connection = snowflake.connector.connect(
                user=self.config['user'],
                password=self.config['password'],
                account=self.config['account'],
                warehouse=self.config['warehouse'],
                database=self.config['database'],
                schema=self.config['schema'],
                role=self.config['role']
            )
            logger.info("Connected to Snowflake successfully")
        except Exception as e:
            logger.error(f"Failed to connect to Snowflake: {str(e)}")
            raise
    
    def execute_query(self, query: str) -> pd.DataFrame:
        """Execute Snowflake query."""
        if not self.connection:
            self.connect()
        
        try:
            cursor = self.connection.cursor()
            cursor.execute(query)
            
            # Fetch results and column names
            results = cursor.fetchall()
            columns = [desc[0] for desc in cursor.description]
            
            # Create DataFrame
            df = pd.DataFrame(results, columns=columns)
            cursor.close()
            
            return df
        except Exception as e:
            logger.error(f"Error executing Snowflake query: {str(e)}")
            raise

class DataValidator:
    """Main data validation class."""
    
    def __init__(self, config_path: str):
        self.config = self._load_config(config_path)
        self.source_db = SQLServerConnector(self.config['sql_server'])
        self.target_db = SnowflakeConnector(self.config['snowflake'])
        self.validation_results: List[ValidationResult] = []
    
    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """Load configuration from YAML file."""
        try:
            with open(config_path, 'r') as file:
                return yaml.safe_load(file)
        except Exception as e:
            logger.error(f"Failed to load configuration: {str(e)}")
            raise
    
    def validate_row_counts(self, tables: List[str]) -> List[ValidationResult]:
        """Validate row counts between source and target tables."""
        logger.info("Starting row count validation...")
        results = []
        
        for table in tables:
            try:
                # Get source row count
                source_query = f"SELECT COUNT(*) as row_count FROM {table}"
                source_result = self.source_db.execute_query(source_query)
                source_count = source_result.iloc[0]['row_count']
                
                # Get target row count
                target_query = f"SELECT COUNT(*) as row_count FROM {table.upper()}"
                target_result = self.target_db.execute_query(target_query)
                target_count = target_result.iloc[0]['ROW_COUNT']
                
                # Calculate variance
                variance = abs(source_count - target_count)
                variance_percent = (variance / source_count * 100) if source_count > 0 else 0
                
                # Determine status (allow 1% variance)
                status = "PASS" if variance_percent <= 1.0 else "FAIL"
                
                result = ValidationResult(
                    table_name=table,
                    check_type="ROW_COUNT",
                    check_name="Row Count Validation",
                    status=status,
                    expected_value=source_count,
                    actual_value=target_count,
                    variance=variance_percent,
                    message=f"Source: {source_count}, Target: {target_count}, Variance: {variance_percent:.2f}%",
                    timestamp=datetime.now(timezone.utc)
                )
                
                results.append(result)
                logger.info(f"Row count validation for {table}: {status}")
                
            except Exception as e:
                logger.error(f"Error validating row count for {table}: {str(e)}")
                result = ValidationResult(
                    table_name=table,
                    check_type="ROW_COUNT",
                    check_name="Row Count Validation",
                    status="ERROR",
                    expected_value=None,
                    actual_value=None,
                    variance=0,
                    message=f"Error: {str(e)}",
                    timestamp=datetime.now(timezone.utc)
                )
                results.append(result)
        
        return results
    
    def validate_data_types(self, tables: List[str]) -> List[ValidationResult]:
        """Validate data types between source and target tables."""
        logger.info("Starting data type validation...")
        results = []
        
        for table in tables:
            try:
                # Get source schema
                source_query = f"""
                SELECT 
                    COLUMN_NAME,
                    DATA_TYPE,
                    IS_NULLABLE,
                    CHARACTER_MAXIMUM_LENGTH,
                    NUMERIC_PRECISION,
                    NUMERIC_SCALE
                FROM INFORMATION_SCHEMA.COLUMNS 
                WHERE TABLE_NAME = '{table}'
                ORDER BY ORDINAL_POSITION
                """
                source_schema = self.source_db.execute_query(source_query)
                
                # Get target schema
                target_query = f"""
                SELECT 
                    COLUMN_NAME,
                    DATA_TYPE,
                    IS_NULLABLE,
                    CHARACTER_MAXIMUM_LENGTH,
                    NUMERIC_PRECISION,
                    NUMERIC_SCALE
                FROM INFORMATION_SCHEMA.COLUMNS 
                WHERE TABLE_NAME = '{table.upper()}'
                ORDER BY ORDINAL_POSITION
                """
                target_schema = self.target_db.execute_query(target_query)
                
                # Compare schemas
                schema_match = self._compare_schemas(source_schema, target_schema)
                
                result = ValidationResult(
                    table_name=table,
                    check_type="SCHEMA",
                    check_name="Data Type Validation",
                    status="PASS" if schema_match['compatible'] else "FAIL",
                    expected_value=len(source_schema),
                    actual_value=len(target_schema),
                    variance=0,
                    message=schema_match['message'],
                    timestamp=datetime.now(timezone.utc)
                )
                
                results.append(result)
                logger.info(f"Schema validation for {table}: {result.status}")
                
            except Exception as e:
                logger.error(f"Error validating schema for {table}: {str(e)}")
                result = ValidationResult(
                    table_name=table,
                    check_type="SCHEMA",
                    check_name="Data Type Validation",
                    status="ERROR",
                    expected_value=None,
                    actual_value=None,
                    variance=0,
                    message=f"Error: {str(e)}",
                    timestamp=datetime.now(timezone.utc)
                )
                results.append(result)
        
        return results
    
    def validate_primary_keys(self, tables: List[str]) -> List[ValidationResult]:
        """Validate primary key constraints."""
        logger.info("Starting primary key validation...")
        results = []
        
        for table in tables:
            try:
                # Check for duplicate primary keys in target
                # This assumes the primary key is the first column or named 'ID'
                pk_column = f"{table.upper()}_ID"  # Adjust based on your naming convention
                
                duplicate_query = f"""
                SELECT COUNT(*) as duplicate_count
                FROM (
                    SELECT {pk_column}, COUNT(*) as cnt
                    FROM {table.upper()}
                    GROUP BY {pk_column}
                    HAVING COUNT(*) > 1
                )
                """
                
                duplicate_result = self.target_db.execute_query(duplicate_query)
                duplicate_count = duplicate_result.iloc[0]['DUPLICATE_COUNT']
                
                status = "PASS" if duplicate_count == 0 else "FAIL"
                
                result = ValidationResult(
                    table_name=table,
                    check_type="PRIMARY_KEY",
                    check_name="Primary Key Uniqueness",
                    status=status,
                    expected_value=0,
                    actual_value=duplicate_count,
                    variance=0,
                    message=f"Duplicate primary keys found: {duplicate_count}",
                    timestamp=datetime.now(timezone.utc)
                )
                
                results.append(result)
                logger.info(f"Primary key validation for {table}: {status}")
                
            except Exception as e:
                logger.error(f"Error validating primary keys for {table}: {str(e)}")
                result = ValidationResult(
                    table_name=table,
                    check_type="PRIMARY_KEY",
                    check_name="Primary Key Uniqueness",
                    status="ERROR",
                    expected_value=None,
                    actual_value=None,
                    variance=0,
                    message=f"Error: {str(e)}",
                    timestamp=datetime.now(timezone.utc)
                )
                results.append(result)
        
        return results
    
    def validate_sample_data(self, tables: List[str], sample_size: int = 1000) -> List[ValidationResult]:
        """Validate sample data between source and target."""
        logger.info(f"Starting sample data validation with sample size: {sample_size}...")
        results = []
        
        for table in tables:
            try:
                # Get sample data from source
                source_query = f"SELECT TOP {sample_size} * FROM {table} ORDER BY 1"
                source_data = self.source_db.execute_query(source_query)
                
                # Get corresponding data from target
                # This assumes we can match records by primary key
                if len(source_data) > 0:
                    pk_column = source_data.columns[0]  # Assume first column is PK
                    pk_values = "', '".join(str(v) for v in source_data[pk_column].tolist())
                    
                    target_query = f"""
                    SELECT * FROM {table.upper()} 
                    WHERE {pk_column.upper()} IN ('{pk_values}')
                    ORDER BY {pk_column.upper()}
                    """
                    target_data = self.target_db.execute_query(target_query)
                    
                    # Compare data
                    match_count = len(source_data)
                    found_count = len(target_data)
                    match_rate = (found_count / match_count * 100) if match_count > 0 else 0
                    
                    status = "PASS" if match_rate >= 95.0 else "FAIL"
                    
                    result = ValidationResult(
                        table_name=table,
                        check_type="SAMPLE_DATA",
                        check_name="Sample Data Validation",
                        status=status,
                        expected_value=match_count,
                        actual_value=found_count,
                        variance=100 - match_rate,
                        message=f"Match rate: {match_rate:.2f}% ({found_count}/{match_count})",
                        timestamp=datetime.now(timezone.utc)
                    )
                    
                    results.append(result)
                    logger.info(f"Sample data validation for {table}: {status}")
                
            except Exception as e:
                logger.error(f"Error validating sample data for {table}: {str(e)}")
                result = ValidationResult(
                    table_name=table,
                    check_type="SAMPLE_DATA",
                    check_name="Sample Data Validation",
                    status="ERROR",
                    expected_value=None,
                    actual_value=None,
                    variance=0,
                    message=f"Error: {str(e)}",
                    timestamp=datetime.now(timezone.utc)
                )
                results.append(result)
        
        return results
    
    def _compare_schemas(self, source_schema: pd.DataFrame, target_schema: pd.DataFrame) -> Dict[str, Any]:
        """Compare source and target schemas."""
        # This is a simplified schema comparison
        # In practice, you'd want more sophisticated logic
        
        source_columns = set(source_schema['COLUMN_NAME'].str.upper())
        target_columns = set(target_schema['COLUMN_NAME'].str.upper())
        
        missing_columns = source_columns - target_columns
        extra_columns = target_columns - source_columns
        
        compatible = len(missing_columns) == 0
        
        message = "Schema compatible"
        if missing_columns:
            message += f". Missing columns: {', '.join(missing_columns)}"
        if extra_columns:
            message += f". Extra columns: {', '.join(extra_columns)}"
        
        return {
            'compatible': compatible,
            'message': message,
            'missing_columns': list(missing_columns),
            'extra_columns': list(extra_columns)
        }
    
    def run_all_validations(self, tables: List[str]) -> List[ValidationResult]:
        """Run all validation checks."""
        logger.info("Starting comprehensive data validation...")
        
        all_results = []
        
        # Connect to databases
        self.source_db.connect()
        self.target_db.connect()
        
        try:
            # Run all validation types
            all_results.extend(self.validate_row_counts(tables))
            all_results.extend(self.validate_data_types(tables))
            all_results.extend(self.validate_primary_keys(tables))
            all_results.extend(self.validate_sample_data(tables))
            
            self.validation_results = all_results
            
        finally:
            # Disconnect from databases
            self.source_db.disconnect()
            self.target_db.disconnect()
        
        return all_results
    
    def generate_report(self, output_file: str = None) -> str:
        """Generate validation report."""
        if not self.validation_results:
            return "No validation results available"
        
        # Calculate summary statistics
        total_checks = len(self.validation_results)
        passed_checks = sum(1 for r in self.validation_results if r.status == "PASS")
        failed_checks = sum(1 for r in self.validation_results if r.status == "FAIL")
        error_checks = sum(1 for r in self.validation_results if r.status == "ERROR")
        
        pass_rate = (passed_checks / total_checks * 100) if total_checks > 0 else 0
        
        # Generate report
        report = f"""
# Data Validation Report
Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## Summary
- Total Checks: {total_checks}
- Passed: {passed_checks}
- Failed: {failed_checks}
- Errors: {error_checks}
- Pass Rate: {pass_rate:.2f}%

## Detailed Results
"""
        
        # Group results by table
        tables = {}
        for result in self.validation_results:
            if result.table_name not in tables:
                tables[result.table_name] = []
            tables[result.table_name].append(result)
        
        for table_name, results in tables.items():
            report += f"\n### {table_name}\n"
            for result in results:
                status_icon = "✅" if result.status == "PASS" else "❌" if result.status == "FAIL" else "⚠️"
                report += f"- {status_icon} {result.check_name}: {result.message}\n"
        
        # Save report to file if specified
        if output_file:
            with open(output_file, 'w') as f:
                f.write(report)
            logger.info(f"Validation report saved to: {output_file}")
        
        return report
    
    def save_results_to_snowflake(self):
        """Save validation results to Snowflake audit table."""
        if not self.validation_results:
            return
        
        logger.info("Saving validation results to Snowflake...")
        
        try:
            self.target_db.connect()
            cursor = self.target_db.connection.cursor()
            
            for result in self.validation_results:
                insert_query = """
                INSERT INTO MIGRATION_DB.AUDIT.DATA_QUALITY_LOG 
                (TABLE_NAME, CHECK_TYPE, CHECK_NAME, CHECK_RESULT, EXPECTED_VALUE, ACTUAL_VALUE, VARIANCE_ACTUAL, ERROR_MESSAGE)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """
                
                cursor.execute(insert_query, (
                    result.table_name,
                    result.check_type,
                    result.check_name,
                    result.status,
                    result.expected_value,
                    result.actual_value,
                    result.variance,
                    result.message
                ))
            
            cursor.close()
            logger.info("Validation results saved to Snowflake successfully")
            
        except Exception as e:
            logger.error(f"Error saving results to Snowflake: {str(e)}")
        finally:
            self.target_db.disconnect()

def main():
    """Main function."""
    parser = argparse.ArgumentParser(description="Data validation for SQL Server to Snowflake migration")
    parser.add_argument("--config", required=True, help="Path to configuration file")
    parser.add_argument("--tables", nargs="+", help="List of tables to validate")
    parser.add_argument("--output", help="Output file for validation report")
    parser.add_argument("--save-to-snowflake", action="store_true", help="Save results to Snowflake")
    
    args = parser.parse_args()
    
    try:
        # Initialize validator
        validator = DataValidator(args.config)
        
        # Get tables to validate
        tables = args.tables or ["customers", "orders", "products", "order_items"]
        
        # Run validations
        results = validator.run_all_validations(tables)
        
        # Generate report
        report = validator.generate_report(args.output)
        print(report)
        
        # Save to Snowflake if requested
        if args.save_to_snowflake:
            validator.save_results_to_snowflake()
        
        # Exit with appropriate code
        failed_count = sum(1 for r in results if r.status in ["FAIL", "ERROR"])
        sys.exit(1 if failed_count > 0 else 0)
        
    except Exception as e:
        logger.error(f"Validation failed: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()


-- =====================================================
-- Snowflake Stored Procedures for Migration Operations
-- =====================================================

-- Use the migration database and appropriate role
USE ROLE MIGRATION_ADMIN;
USE DATABASE MIGRATION_DB;
USE SCHEMA PUBLIC;
USE WAREHOUSE MIGRATION_WH;

-- =====================================================
-- Data Loading Procedures
-- =====================================================

-- Procedure to load data from external stage
CREATE OR REPLACE PROCEDURE SP_LOAD_TABLE_FROM_STAGE(
    TABLE_NAME STRING,
    STAGE_NAME STRING,
    FILE_PATTERN STRING DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    sql_command STRING;
    result STRING;
    rows_loaded NUMBER;
BEGIN
    -- Construct COPY command
    sql_command := 'COPY INTO ' || TABLE_NAME || 
                   ' FROM @' || STAGE_NAME;
    
    -- Add file pattern if specified
    IF (FILE_PATTERN IS NOT NULL) THEN
        sql_command := sql_command || ' PATTERN = ''' || FILE_PATTERN || '''';
    END IF;
    
    -- Add common options
    sql_command := sql_command || 
                   ' FILE_FORMAT = PARQUET_FORMAT' ||
                   ' MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE' ||
                   ' ON_ERROR = ''CONTINUE''' ||
                   ' PURGE = FALSE';
    
    -- Execute the COPY command
    EXECUTE IMMEDIATE sql_command;
    
    -- Get the result from the last query
    LET result_cursor CURSOR FOR SELECT $1, $2, $3 FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
    OPEN result_cursor;
    FETCH result_cursor INTO result, rows_loaded, result;
    CLOSE result_cursor;
    
    -- Log the operation
    INSERT INTO MIGRATION_DB.AUDIT.MIGRATION_LOG 
    (TABLE_NAME, OPERATION, STATUS, START_TIME, END_TIME, ROWS_PROCESSED)
    VALUES 
    (TABLE_NAME, 'LOAD_FROM_STAGE', 'SUCCESS', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), rows_loaded);
    
    RETURN 'Successfully loaded ' || rows_loaded || ' rows into ' || TABLE_NAME;
EXCEPTION
    WHEN OTHER THEN
        -- Log the error
        INSERT INTO MIGRATION_DB.AUDIT.MIGRATION_LOG 
        (TABLE_NAME, OPERATION, STATUS, START_TIME, END_TIME, ERROR_MESSAGE)
        VALUES 
        (TABLE_NAME, 'LOAD_FROM_STAGE', 'FAILED', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), SQLERRM);
        
        RETURN 'Error loading data into ' || TABLE_NAME || ': ' || SQLERRM;
END;
$$;

-- Procedure to apply CDC changes
CREATE OR REPLACE PROCEDURE SP_APPLY_CDC_CHANGES(
    TARGET_TABLE STRING,
    STAGING_TABLE STRING,
    PRIMARY_KEY_COLUMNS STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    merge_sql STRING;
    rows_affected NUMBER;
    inserts NUMBER;
    updates NUMBER;
    deletes NUMBER;
BEGIN
    -- Construct MERGE statement
    merge_sql := 'MERGE INTO ' || TARGET_TABLE || ' AS target ' ||
                 'USING ' || STAGING_TABLE || ' AS source ' ||
                 'ON ';
    
    -- Add primary key conditions
    -- This is a simplified version - in practice, you'd parse PRIMARY_KEY_COLUMNS
    merge_sql := merge_sql || 'target.' || PRIMARY_KEY_COLUMNS || ' = source.' || PRIMARY_KEY_COLUMNS || ' ' ||
                 'WHEN MATCHED AND source.DMS_OPERATION = ''U'' THEN UPDATE SET * ' ||
                 'WHEN MATCHED AND source.DMS_OPERATION = ''D'' THEN DELETE ' ||
                 'WHEN NOT MATCHED AND source.DMS_OPERATION IN (''I'', ''U'') THEN INSERT *';
    
    -- Execute the MERGE statement
    EXECUTE IMMEDIATE merge_sql;
    
    -- Get merge results
    LET result_cursor CURSOR FOR SELECT $1, $2, $3, $4 FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
    OPEN result_cursor;
    FETCH result_cursor INTO rows_affected, inserts, updates, deletes;
    CLOSE result_cursor;
    
    -- Clear staging table
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ' || STAGING_TABLE;
    
    -- Log the operation
    INSERT INTO MIGRATION_DB.AUDIT.MIGRATION_LOG 
    (TABLE_NAME, OPERATION, STATUS, START_TIME, END_TIME, ROWS_PROCESSED, ROWS_INSERTED, ROWS_UPDATED, ROWS_DELETED)
    VALUES 
    (TARGET_TABLE, 'APPLY_CDC', 'SUCCESS', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 
     rows_affected, inserts, updates, deletes);
    
    RETURN 'CDC applied to ' || TARGET_TABLE || ': ' || 
           inserts || ' inserts, ' || updates || ' updates, ' || deletes || ' deletes';
EXCEPTION
    WHEN OTHER THEN
        -- Log the error
        INSERT INTO MIGRATION_DB.AUDIT.MIGRATION_LOG 
        (TABLE_NAME, OPERATION, STATUS, START_TIME, END_TIME, ERROR_MESSAGE)
        VALUES 
        (TARGET_TABLE, 'APPLY_CDC', 'FAILED', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), SQLERRM);
        
        RETURN 'Error applying CDC to ' || TARGET_TABLE || ': ' || SQLERRM;
END;
$$;

-- =====================================================
-- Data Validation Procedures
-- =====================================================

-- Procedure to validate row counts between source and target
CREATE OR REPLACE PROCEDURE SP_VALIDATE_ROW_COUNTS(
    TABLE_NAME STRING,
    EXPECTED_COUNT NUMBER
)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    actual_count NUMBER;
    variance NUMBER;
    variance_percent FLOAT;
    status STRING;
BEGIN
    -- Get actual count from target table
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || TABLE_NAME INTO actual_count;
    
    -- Calculate variance
    variance := ABS(actual_count - EXPECTED_COUNT);
    variance_percent := CASE 
        WHEN EXPECTED_COUNT = 0 THEN 0 
        ELSE (variance * 100.0 / EXPECTED_COUNT) 
    END;
    
    -- Determine status (allow 1% variance)
    status := CASE WHEN variance_percent <= 1.0 THEN 'PASS' ELSE 'FAIL' END;
    
    -- Log validation result
    INSERT INTO MIGRATION_DB.AUDIT.DATA_QUALITY_LOG 
    (TABLE_NAME, CHECK_TYPE, CHECK_NAME, CHECK_RESULT, EXPECTED_VALUE, ACTUAL_VALUE, VARIANCE_ACTUAL)
    VALUES 
    (TABLE_NAME, 'ROW_COUNT', 'Row Count Validation', status, EXPECTED_COUNT, actual_count, variance_percent);
    
    RETURN 'Row count validation for ' || TABLE_NAME || ': ' || status || 
           ' (Expected: ' || EXPECTED_COUNT || ', Actual: ' || actual_count || 
           ', Variance: ' || variance_percent || '%)';
END;
$$;

-- Procedure to validate data types and constraints
CREATE OR REPLACE PROCEDURE SP_VALIDATE_DATA_QUALITY(
    TABLE_NAME STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    null_checks STRING;
    duplicate_checks STRING;
    result STRING;
BEGIN
    -- This is a simplified data quality check
    -- In practice, you'd have more sophisticated validation logic
    
    -- Check for null values in required fields (example for CUSTOMERS table)
    IF (TABLE_NAME = 'CUSTOMERS') THEN
        EXECUTE IMMEDIATE 
            'SELECT COUNT(*) FROM ' || TABLE_NAME || ' WHERE CUSTOMER_ID IS NULL OR EMAIL IS NULL'
            INTO null_checks;
        
        IF (null_checks::NUMBER > 0) THEN
            INSERT INTO MIGRATION_DB.AUDIT.DATA_QUALITY_LOG 
            (TABLE_NAME, CHECK_TYPE, CHECK_NAME, CHECK_RESULT, ACTUAL_VALUE)
            VALUES 
            (TABLE_NAME, 'NULL_CHECK', 'Required Fields Null Check', 'FAIL', null_checks);
            
            result := 'FAIL: Found ' || null_checks || ' records with null required fields';
        ELSE
            INSERT INTO MIGRATION_DB.AUDIT.DATA_QUALITY_LOG 
            (TABLE_NAME, CHECK_TYPE, CHECK_NAME, CHECK_RESULT, ACTUAL_VALUE)
            VALUES 
            (TABLE_NAME, 'NULL_CHECK', 'Required Fields Null Check', 'PASS', 0);
            
            result := 'PASS: No null values in required fields';
        END IF;
    END IF;
    
    RETURN 'Data quality validation for ' || TABLE_NAME || ': ' || result;
END;
$$;

-- =====================================================
-- Monitoring and Maintenance Procedures
-- =====================================================

-- Procedure to get migration status
CREATE OR REPLACE PROCEDURE SP_GET_MIGRATION_STATUS()
RETURNS TABLE (
    TABLE_NAME STRING,
    LAST_MIGRATION_TIME TIMESTAMP_NTZ,
    STATUS STRING,
    ROWS_PROCESSED NUMBER,
    SUCCESS_RATE FLOAT
)
LANGUAGE SQL
AS
$$
BEGIN
    RETURN TABLE(
        SELECT 
            ml.TABLE_NAME,
            MAX(ml.END_TIME) AS LAST_MIGRATION_TIME,
            CASE 
                WHEN SUM(CASE WHEN ml.STATUS = 'SUCCESS' THEN 1 ELSE 0 END) = COUNT(*) THEN 'SUCCESS'
                WHEN SUM(CASE WHEN ml.STATUS = 'FAILED' THEN 1 ELSE 0 END) > 0 THEN 'PARTIAL_FAILURE'
                ELSE 'RUNNING'
            END AS STATUS,
            SUM(ml.ROWS_PROCESSED) AS ROWS_PROCESSED,
            ROUND(
                (SUM(CASE WHEN ml.STATUS = 'SUCCESS' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)), 
                2
            ) AS SUCCESS_RATE
        FROM MIGRATION_DB.AUDIT.MIGRATION_LOG ml
        WHERE ml.END_TIME >= DATEADD('day', -1, CURRENT_TIMESTAMP())
        GROUP BY ml.TABLE_NAME
        ORDER BY LAST_MIGRATION_TIME DESC
    );
END;
$$;

-- Procedure to cleanup old data
CREATE OR REPLACE PROCEDURE SP_CLEANUP_OLD_DATA(
    RETENTION_DAYS NUMBER DEFAULT 30
)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    cutoff_date TIMESTAMP_NTZ;
    deleted_logs NUMBER;
    deleted_quality_logs NUMBER;
BEGIN
    cutoff_date := DATEADD('day', -RETENTION_DAYS, CURRENT_TIMESTAMP());
    
    -- Clean up old migration logs
    DELETE FROM MIGRATION_DB.AUDIT.MIGRATION_LOG 
    WHERE CREATED_AT < cutoff_date;
    
    deleted_logs := SQLROWCOUNT;
    
    -- Clean up old data quality logs
    DELETE FROM MIGRATION_DB.AUDIT.DATA_QUALITY_LOG 
    WHERE CHECK_TIMESTAMP < cutoff_date;
    
    deleted_quality_logs := SQLROWCOUNT;
    
    RETURN 'Cleanup completed: Deleted ' || deleted_logs || ' migration logs and ' || 
           deleted_quality_logs || ' data quality logs older than ' || RETENTION_DAYS || ' days';
END;
$$;

-- Procedure to refresh materialized views (if any)
CREATE OR REPLACE PROCEDURE SP_REFRESH_ANALYTICS_VIEWS()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    -- This procedure would refresh any materialized views
    -- For now, it's a placeholder since we're using regular views
    
    -- Example: If you had materialized views, you'd refresh them here
    -- ALTER MATERIALIZED VIEW MV_CUSTOMER_SUMMARY REFRESH;
    
    RETURN 'Analytics views refreshed successfully';
END;
$$;

-- =====================================================
-- Utility Procedures
-- =====================================================

-- Procedure to get table statistics
CREATE OR REPLACE PROCEDURE SP_GET_TABLE_STATISTICS(
    SCHEMA_NAME STRING DEFAULT 'PUBLIC'
)
RETURNS TABLE (
    TABLE_NAME STRING,
    ROW_COUNT NUMBER,
    SIZE_MB FLOAT,
    LAST_UPDATED TIMESTAMP_NTZ
)
LANGUAGE SQL
AS
$$
BEGIN
    RETURN TABLE(
        SELECT 
            t.TABLE_NAME,
            ts.ROW_COUNT,
            ROUND(ts.BYTES / (1024 * 1024), 2) AS SIZE_MB,
            ts.LAST_ALTERED AS LAST_UPDATED
        FROM INFORMATION_SCHEMA.TABLES t
        LEFT JOIN INFORMATION_SCHEMA.TABLE_STORAGE_METRICS ts 
            ON t.TABLE_NAME = ts.TABLE_NAME 
            AND t.TABLE_SCHEMA = ts.TABLE_SCHEMA
        WHERE t.TABLE_SCHEMA = SCHEMA_NAME
            AND t.TABLE_TYPE = 'BASE TABLE'
        ORDER BY ts.ROW_COUNT DESC
    );
END;
$$;

-- Procedure to analyze query performance
CREATE OR REPLACE PROCEDURE SP_ANALYZE_QUERY_PERFORMANCE(
    HOURS_BACK NUMBER DEFAULT 24
)
RETURNS TABLE (
    QUERY_TYPE STRING,
    TOTAL_QUERIES NUMBER,
    AVG_EXECUTION_TIME_MS NUMBER,
    TOTAL_BYTES_SCANNED NUMBER
)
LANGUAGE SQL
AS
$$
DECLARE
    start_time TIMESTAMP_NTZ;
BEGIN
    start_time := DATEADD('hour', -HOURS_BACK, CURRENT_TIMESTAMP());
    
    RETURN TABLE(
        SELECT 
            CASE 
                WHEN QUERY_TEXT ILIKE '%COPY INTO%' THEN 'DATA_LOAD'
                WHEN QUERY_TEXT ILIKE '%MERGE%' THEN 'CDC_APPLY'
                WHEN QUERY_TEXT ILIKE '%SELECT%' THEN 'SELECT'
                WHEN QUERY_TEXT ILIKE '%INSERT%' THEN 'INSERT'
                WHEN QUERY_TEXT ILIKE '%UPDATE%' THEN 'UPDATE'
                WHEN QUERY_TEXT ILIKE '%DELETE%' THEN 'DELETE'
                ELSE 'OTHER'
            END AS QUERY_TYPE,
            COUNT(*) AS TOTAL_QUERIES,
            AVG(TOTAL_ELAPSED_TIME) AS AVG_EXECUTION_TIME_MS,
            SUM(BYTES_SCANNED) AS TOTAL_BYTES_SCANNED
        FROM INFORMATION_SCHEMA.QUERY_HISTORY
        WHERE START_TIME >= start_time
            AND DATABASE_NAME = 'MIGRATION_DB'
        GROUP BY QUERY_TYPE
        ORDER BY TOTAL_QUERIES DESC
    );
END;
$$;

-- =====================================================
-- Grant Permissions on Procedures
-- =====================================================

-- Grant execute permissions to roles
GRANT USAGE ON PROCEDURE SP_LOAD_TABLE_FROM_STAGE(STRING, STRING, STRING) TO ROLE MIGRATION_ADMIN;
GRANT USAGE ON PROCEDURE SP_APPLY_CDC_CHANGES(STRING, STRING, STRING) TO ROLE MIGRATION_ADMIN;
GRANT USAGE ON PROCEDURE SP_VALIDATE_ROW_COUNTS(STRING, NUMBER) TO ROLE MIGRATION_ADMIN;
GRANT USAGE ON PROCEDURE SP_VALIDATE_DATA_QUALITY(STRING) TO ROLE MIGRATION_ADMIN;
GRANT USAGE ON PROCEDURE SP_GET_MIGRATION_STATUS() TO ROLE MIGRATION_ADMIN;
GRANT USAGE ON PROCEDURE SP_GET_MIGRATION_STATUS() TO ROLE MIGRATION_USER;
GRANT USAGE ON PROCEDURE SP_CLEANUP_OLD_DATA(NUMBER) TO ROLE MIGRATION_ADMIN;
GRANT USAGE ON PROCEDURE SP_REFRESH_ANALYTICS_VIEWS() TO ROLE MIGRATION_ADMIN;
GRANT USAGE ON PROCEDURE SP_GET_TABLE_STATISTICS(STRING) TO ROLE MIGRATION_ADMIN;
GRANT USAGE ON PROCEDURE SP_GET_TABLE_STATISTICS(STRING) TO ROLE MIGRATION_USER;
GRANT USAGE ON PROCEDURE SP_ANALYZE_QUERY_PERFORMANCE(NUMBER) TO ROLE MIGRATION_ADMIN;
GRANT USAGE ON PROCEDURE SP_ANALYZE_QUERY_PERFORMANCE(NUMBER) TO ROLE MIGRATION_USER;

-- Display completion message
SELECT 'Stored procedures created successfully!' AS STATUS;

-- Show created procedures
SHOW PROCEDURES IN SCHEMA MIGRATION_DB.PUBLIC;


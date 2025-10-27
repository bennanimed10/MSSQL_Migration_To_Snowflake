# Architecture Documentation

## Overview

This document describes the architecture and design decisions for the SQL Server to Snowflake migration solution using AWS services.

## Architecture Diagram

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   SQL Server    │    │    AWS DMS      │    │   Amazon S3     │    │   Snowflake     │
│                 │───▶│                 │───▶│                 │───▶│                 │
│ • Source DB     │    │ • Replication   │    │ • Staging Area  │    │ • Data Warehouse│
│ • CDC Enabled   │    │ • Full Load     │    │ • Parquet Files │    │ • External Stage│
│ • Tables        │    │ • CDC           │    │ • Partitioned   │    │ • Auto-ingest   │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
                                ▲                        ▲                        ▲
                                │                        │                        │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  CloudWatch     │    │  AWS Lambda     │    │      SNS        │    │      IAM        │
│                 │    │                 │    │                 │    │                 │
│ • Monitoring    │    │ • Orchestration │    │ • Notifications │    │ • Roles         │
│ • Dashboards    │    │ • Data Validation│   │ • Alerts        │    │ • Policies      │
│ • Alarms        │    │ • Error Handling│    │ • Email/Slack   │    │ • Security      │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Components

### 1. Source System (SQL Server)
- **Purpose**: Source database containing business data
- **Requirements**: 
  - SQL Server 2012 or later
  - CDC enabled for real-time synchronization
  - Network connectivity to AWS
- **Configuration**:
  - Enable CDC on source database
  - Create dedicated user for DMS with appropriate permissions
  - Configure backup retention for point-in-time recovery

### 2. AWS Database Migration Service (DMS)
- **Purpose**: Extract data from SQL Server and load to S3
- **Components**:
  - **Replication Instance**: Compute resource for migration tasks
  - **Source Endpoint**: Connection to SQL Server
  - **Target Endpoint**: Connection to S3 bucket
  - **Migration Tasks**: Full load and CDC tasks
- **Features**:
  - Automatic retry on failures
  - Data validation and transformation
  - Parallel processing for large tables
  - Monitoring and logging

### 3. Amazon S3 (Staging Layer)
- **Purpose**: Temporary storage for data files before loading to Snowflake
- **Structure**:
  ```
  s3://migration-bucket/
  ├── full-load/
  │   ├── table1/
  │   │   └── year=2024/month=01/day=15/
  │   └── table2/
  └── cdc/
      ├── table1/
      └── table2/
  ```
- **Features**:
  - Lifecycle policies for cost optimization
  - Server-side encryption
  - Versioning enabled
  - Cross-region replication (optional)

### 4. AWS Lambda (Orchestration Layer)
- **Purpose**: Coordinate migration workflow and handle events
- **Functions**:
  - **Migration Orchestrator**: Main workflow controller
  - **Data Validator**: Quality checks and reconciliation
  - **Notification Handler**: Alert management
- **Triggers**:
  - S3 events (new files)
  - CloudWatch events (scheduled)
  - SNS messages (error handling)

### 5. Snowflake (Target System)
- **Purpose**: Cloud data warehouse for analytics and reporting
- **Components**:
  - **Database**: Logical container for schemas and tables
  - **Schemas**: Organize tables by business domain
  - **External Stages**: Point to S3 buckets
  - **Pipes**: Auto-ingest from S3
  - **Warehouses**: Compute resources for queries
- **Features**:
  - Automatic scaling
  - Time travel and fail-safe
  - Data sharing capabilities
  - Built-in security and governance

### 6. Monitoring and Alerting
- **CloudWatch**:
  - Custom metrics for migration progress
  - Log aggregation from all services
  - Dashboards for real-time visibility
- **SNS**:
  - Email notifications for critical events
  - Slack integration for team alerts
  - SMS for urgent issues

## Data Flow

### Initial Migration (Full Load)
1. DMS connects to SQL Server and extracts all table data
2. Data is written to S3 in Parquet format with partitioning
3. Lambda function detects new files in S3
4. Snowflake Pipe automatically ingests data from external stage
5. Data validation runs to ensure accuracy
6. Success/failure notifications sent via SNS

### Ongoing Synchronization (CDC)
1. DMS captures changes from SQL Server transaction log
2. Changes written to S3 in near real-time
3. Snowflake Pipes continuously ingest new change files
4. Lambda functions monitor for data quality issues
5. Automated reconciliation runs periodically

## Security Architecture

### Network Security
- VPC with private subnets for DMS replication instance
- Security groups with minimal required access
- VPC endpoints for S3 and other AWS services
- SSL/TLS encryption for all data in transit

### Identity and Access Management
- Dedicated IAM roles for each service
- Least privilege access principles
- Cross-account roles for Snowflake integration
- AWS Secrets Manager for credential storage

### Data Security
- Encryption at rest in S3 using KMS
- Encrypted connections to SQL Server and Snowflake
- Data masking for sensitive fields (optional)
- Audit logging for all data access

## Performance Considerations

### DMS Optimization
- Right-size replication instance based on workload
- Use multiple tasks for parallel processing
- Optimize table mappings and transformations
- Monitor replication lag and adjust accordingly

### S3 Optimization
- Use appropriate file sizes (100MB - 1GB)
- Implement partitioning strategy
- Configure multipart uploads
- Use S3 Transfer Acceleration if needed

### Snowflake Optimization
- Size warehouses appropriately
- Use clustering keys for large tables
- Implement result caching
- Monitor credit usage and optimize

## Disaster Recovery

### Backup Strategy
- S3 cross-region replication
- Snowflake Time Travel (up to 90 days)
- DMS task configuration backups
- Infrastructure as Code for quick recovery

### Recovery Procedures
1. **S3 Failure**: Failover to replicated bucket
2. **DMS Failure**: Recreate tasks from configuration
3. **Snowflake Failure**: Use Snowflake's built-in redundancy
4. **Complete Region Failure**: Deploy to alternate region

## Cost Optimization

### Strategies
- Use Spot instances for DMS when possible
- Implement S3 lifecycle policies
- Right-size Snowflake warehouses
- Monitor and optimize data transfer costs
- Use reserved capacity where applicable

### Cost Monitoring
- CloudWatch billing alarms
- AWS Cost Explorer integration
- Snowflake credit monitoring
- Regular cost optimization reviews

## Scalability

### Horizontal Scaling
- Multiple DMS tasks for large datasets
- Parallel Lambda function execution
- Snowflake auto-scaling warehouses
- S3 unlimited storage capacity

### Vertical Scaling
- DMS instance size adjustments
- Lambda memory and timeout configuration
- Snowflake warehouse size optimization
- Network bandwidth considerations

## Compliance and Governance

### Data Governance
- Data lineage tracking
- Schema evolution management
- Data quality monitoring
- Metadata management

### Compliance Features
- Audit logging throughout pipeline
- Data retention policies
- Access control and monitoring
- Encryption and key management


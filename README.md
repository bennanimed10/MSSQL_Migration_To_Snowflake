# SQL Server to Snowflake Migration using AWS

A comprehensive data migration solution that leverages AWS services to migrate data from SQL Server to Snowflake with real-time synchronization capabilities.

## 🏗️ Architecture Overview

This solution uses the following AWS services and architecture:

```
SQL Server → AWS DMS → S3 → Snowflake
     ↓
AWS Lambda (Orchestration)
     ↓
CloudWatch (Monitoring) → SNS (Alerts)
```

### Key Components:
- **AWS DMS**: Handles initial data migration and ongoing CDC (Change Data Capture)
- **Amazon S3**: Staging area for data files
- **AWS Lambda**: Orchestration and automation
- **Snowflake**: Target data warehouse
- **CloudWatch**: Monitoring and logging
- **SNS**: Notifications and alerts
- **Terraform**: Infrastructure as Code

## 🚀 Features

- ✅ **Full Load Migration**: Complete initial data transfer
- ✅ **Change Data Capture (CDC)**: Real-time synchronization
- ✅ **Data Validation**: Automated quality checks and reconciliation
- ✅ **Error Handling**: Comprehensive error management and retry logic
- ✅ **Monitoring**: Real-time dashboards and alerting
- ✅ **Infrastructure as Code**: Terraform-managed AWS resources
- ✅ **Automated Deployment**: One-click deployment scripts

## 📁 Project Structure

```
├── README.md
├── docs/
│   └── architecture.md
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── s3/
│       └── iam/
├── aws-dms/
│   ├── dms-setup.json
│   └── table-mappings.json
├── snowflake/
│   ├── 01-database-setup.sql
│   ├── 02-external-stages.sql
│   ├── 03-table-definitions.sql
│   └── 04-stored-procedures.sql
├── lambda/
│   ├── migration-orchestrator/
│   ├── data-validator/
│   └── notification-handler/
├── scripts/
│   ├── deploy.sh
│   ├── setup-environment.sh
│   ├── data-transformation.py
│   └── data-validation.py
├── config/
│   ├── migration-config.yaml
│   └── table-mapping.yaml
└── monitoring/
    ├── cloudwatch-alarms.json
    └── dashboard-config.json
```

## 🛠️ Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Python 3.9+
- Snowflake account with ACCOUNTADMIN privileges
- SQL Server with CDC enabled (for real-time sync)

## 🚀 Quick Start

1. **Clone and Setup**
   ```bash
   git clone <repository-url>
   cd sql-server-snowflake-migration
   chmod +x scripts/*.sh
   ./scripts/setup-environment.sh
   ```

2. **Configure Settings**
   ```bash
   cp config/migration-config.yaml.example config/migration-config.yaml
   # Edit configuration files with your environment details
   ```

3. **Deploy Infrastructure**
   ```bash
   ./scripts/deploy.sh
   ```

4. **Start Migration**
   ```bash
   # The deployment script will provide specific commands for your environment
   ```

## 📊 Monitoring

Access your migration dashboards:
- **CloudWatch Dashboard**: Monitor migration progress and performance
- **DMS Console**: Track replication tasks and CDC lag
- **Snowflake Console**: Verify data loading and query performance

## 🔧 Configuration

### Key Configuration Files:
- `config/migration-config.yaml`: Main configuration
- `config/table-mapping.yaml`: Table-specific settings
- `aws-dms/table-mappings.json`: DMS table selection rules

### Environment Variables:
```bash
export AWS_REGION=us-east-1
export SNOWFLAKE_ACCOUNT=your-account
export SNOWFLAKE_USER=your-user
export SNOWFLAKE_PASSWORD=your-password
export SQL_SERVER_HOST=your-sql-server
```

## 🔍 Troubleshooting

Common issues and solutions:

1. **DMS Task Failures**: Check CloudWatch logs and table mappings
2. **Snowflake Load Errors**: Verify file formats and external stage permissions
3. **Lambda Timeouts**: Increase timeout settings in Terraform configuration

## 📈 Performance Optimization

- **Parallel Processing**: Configure multiple DMS tasks for large tables
- **Snowflake Warehouses**: Use appropriate warehouse sizes
- **S3 Partitioning**: Organize data by date/table for efficient loading

## 🔒 Security

- IAM roles with least privilege access
- Encrypted data in transit and at rest
- Snowflake network policies and access controls
- AWS Secrets Manager for credential management

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📞 Support

For issues and questions:
- Create an issue in this repository
- Check the troubleshooting guide in `docs/`
- Review AWS DMS and Snowflake documentation


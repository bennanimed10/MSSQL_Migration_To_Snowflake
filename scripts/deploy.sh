#!/bin/bash

# SQL Server to Snowflake Migration - Deployment Script
# This script deploys the complete migration infrastructure using Terraform

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
LAMBDA_DIR="$PROJECT_ROOT/lambda"
CONFIG_DIR="$PROJECT_ROOT/config"

# Default values
ENVIRONMENT="dev"
AWS_REGION="us-east-1"
DESTROY_MODE=false
PLAN_ONLY=false
AUTO_APPROVE=false
SKIP_LAMBDA_BUILD=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy SQL Server to Snowflake migration infrastructure

OPTIONS:
    -e, --environment ENV       Environment (dev, staging, prod) [default: dev]
    -r, --region REGION         AWS region [default: us-east-1]
    -d, --destroy              Destroy infrastructure instead of creating
    -p, --plan-only            Only run terraform plan, don't apply
    -a, --auto-approve         Auto-approve terraform apply (use with caution)
    -s, --skip-lambda-build    Skip Lambda function packaging
    -h, --help                 Show this help message

EXAMPLES:
    $0                                    # Deploy to dev environment
    $0 -e prod -r us-west-2              # Deploy to prod in us-west-2
    $0 -p                                 # Plan only, don't apply
    $0 -d -e dev                          # Destroy dev environment
    $0 -a -e staging                      # Auto-approve staging deployment

PREREQUISITES:
    - AWS CLI configured with appropriate permissions
    - Terraform >= 1.0 installed
    - Python 3.9+ installed
    - Valid configuration in config/migration-config.yaml

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -d|--destroy)
            DESTROY_MODE=true
            shift
            ;;
        -p|--plan-only)
            PLAN_ONLY=true
            shift
            ;;
        -a|--auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        -s|--skip-lambda-build)
            SKIP_LAMBDA_BUILD=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod."
    exit 1
fi

print_status "Starting deployment for environment: $ENVIRONMENT in region: $AWS_REGION"

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed. Please install it first."
        exit 1
    fi
    
    # Check configuration file
    if [[ ! -f "$CONFIG_DIR/migration-config.yaml" ]]; then
        print_error "Configuration file not found: $CONFIG_DIR/migration-config.yaml"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Build Lambda functions
build_lambda_functions() {
    if [[ "$SKIP_LAMBDA_BUILD" == true ]]; then
        print_warning "Skipping Lambda function build"
        return
    fi
    
    print_status "Building Lambda functions..."
    
    # Create build directory
    BUILD_DIR="$PROJECT_ROOT/build"
    mkdir -p "$BUILD_DIR"
    
    # Build each Lambda function
    for lambda_func in migration-orchestrator data-validator notification-handler; do
        print_status "Building $lambda_func..."
        
        FUNC_DIR="$LAMBDA_DIR/$lambda_func"
        ZIP_FILE="$BUILD_DIR/$lambda_func.zip"
        
        if [[ ! -d "$FUNC_DIR" ]]; then
            print_warning "Lambda function directory not found: $FUNC_DIR, skipping..."
            continue
        fi
        
        # Create temporary directory for building
        TEMP_DIR=$(mktemp -d)
        
        # Copy function code
        cp -r "$FUNC_DIR"/* "$TEMP_DIR/"
        
        # Copy requirements.txt if it exists in the function directory or use the common one
        if [[ -f "$FUNC_DIR/requirements.txt" ]]; then
            cp "$FUNC_DIR/requirements.txt" "$TEMP_DIR/"
        elif [[ -f "$LAMBDA_DIR/requirements.txt" ]]; then
            cp "$LAMBDA_DIR/requirements.txt" "$TEMP_DIR/"
        fi
        
        # Install dependencies if requirements.txt exists
        if [[ -f "$TEMP_DIR/requirements.txt" ]]; then
            print_status "Installing dependencies for $lambda_func..."
            pip3 install -r "$TEMP_DIR/requirements.txt" -t "$TEMP_DIR/" --quiet
        fi
        
        # Create ZIP file
        cd "$TEMP_DIR"
        zip -r "$ZIP_FILE" . -q
        cd - > /dev/null
        
        # Clean up
        rm -rf "$TEMP_DIR"
        
        print_success "Built $lambda_func: $ZIP_FILE"
    done
    
    # Copy ZIP files to terraform directory for deployment
    cp "$BUILD_DIR"/*.zip "$TERRAFORM_DIR/lambda/" 2>/dev/null || true
}

# Initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    terraform init
    
    # Select or create workspace
    if terraform workspace list | grep -q "$ENVIRONMENT"; then
        terraform workspace select "$ENVIRONMENT"
    else
        terraform workspace new "$ENVIRONMENT"
    fi
    
    print_success "Terraform initialized for environment: $ENVIRONMENT"
}

# Create terraform.tfvars file
create_tfvars() {
    print_status "Creating terraform.tfvars file..."
    
    TFVARS_FILE="$TERRAFORM_DIR/terraform.tfvars"
    
    cat > "$TFVARS_FILE" << EOF
# Auto-generated terraform.tfvars for environment: $ENVIRONMENT
# Generated on: $(date)

# General Configuration
environment = "$ENVIRONMENT"
aws_region = "$AWS_REGION"
project_name = "sql-snowflake-migration"

# SQL Server Configuration (update these values)
sql_server_host = "your-sql-server.domain.com"
sql_server_database = "YourDatabase"
sql_server_username = "migration_user"
sql_server_password = "YourPassword"  # Use AWS Secrets Manager in production

# Snowflake Configuration (update these values)
snowflake_account = "your-account.region.snowflakecomputing.com"
snowflake_user = "MIGRATION_USER"
snowflake_password = "YourPassword"  # Use AWS Secrets Manager in production

# Notification Configuration
notification_emails = [
    "admin@yourcompany.com"
]

# DMS Configuration
dms_instance_class = "dms.t3.micro"
dms_allocated_storage = 100

# S3 Configuration
s3_full_load_retention_days = 30
s3_cdc_retention_days = 7

# CloudWatch Configuration
cloudwatch_log_retention_days = 14

# Validation Schedule
validation_schedule = "rate(6 hours)"
EOF

    print_warning "Please update the values in $TFVARS_FILE before proceeding"
    print_warning "Especially update SQL Server and Snowflake connection details"
}

# Plan Terraform deployment
plan_terraform() {
    print_status "Planning Terraform deployment..."
    
    cd "$TERRAFORM_DIR"
    
    if [[ "$DESTROY_MODE" == true ]]; then
        terraform plan -destroy -var-file="terraform.tfvars" -out="tfplan"
    else
        terraform plan -var-file="terraform.tfvars" -out="tfplan"
    fi
    
    print_success "Terraform plan completed"
}

# Apply Terraform deployment
apply_terraform() {
    if [[ "$PLAN_ONLY" == true ]]; then
        print_status "Plan-only mode, skipping apply"
        return
    fi
    
    print_status "Applying Terraform deployment..."
    
    cd "$TERRAFORM_DIR"
    
    if [[ "$AUTO_APPROVE" == true ]]; then
        terraform apply -auto-approve "tfplan"
    else
        print_warning "Review the plan above and confirm to proceed"
        terraform apply "tfplan"
    fi
    
    if [[ "$DESTROY_MODE" == true ]]; then
        print_success "Infrastructure destroyed successfully"
    else
        print_success "Infrastructure deployed successfully"
        
        # Show outputs
        print_status "Deployment outputs:"
        terraform output
    fi
}

# Post-deployment tasks
post_deployment() {
    if [[ "$DESTROY_MODE" == true ]] || [[ "$PLAN_ONLY" == true ]]; then
        return
    fi
    
    print_status "Running post-deployment tasks..."
    
    cd "$TERRAFORM_DIR"
    
    # Get Terraform outputs
    S3_BUCKET=$(terraform output -raw s3_staging_bucket_name 2>/dev/null || echo "")
    SNOWFLAKE_ROLE_ARN=$(terraform output -raw snowflake_role_arn 2>/dev/null || echo "")
    
    if [[ -n "$S3_BUCKET" ]]; then
        print_status "S3 staging bucket created: $S3_BUCKET"
    fi
    
    if [[ -n "$SNOWFLAKE_ROLE_ARN" ]]; then
        print_status "Snowflake IAM role created: $SNOWFLAKE_ROLE_ARN"
    fi
    
    # Create next steps file
    NEXT_STEPS_FILE="$PROJECT_ROOT/NEXT_STEPS.md"
    cat > "$NEXT_STEPS_FILE" << EOF
# Next Steps for SQL Server to Snowflake Migration

## Deployment completed successfully!

### 1. Update Snowflake Configuration
- Run the SQL scripts in the \`snowflake/\` directory
- Update the storage integration with the actual IAM role ARN: \`$SNOWFLAKE_ROLE_ARN\`
- Update external stage URLs with the S3 bucket: \`$S3_BUCKET\`

### 2. Configure AWS Secrets Manager
- Store SQL Server password in AWS Secrets Manager
- Store Snowflake password in AWS Secrets Manager
- Update Lambda environment variables to use secrets

### 3. Set up DMS Migration Tasks
- Use the DMS endpoints created by Terraform
- Create migration tasks using the configuration in \`aws-dms/\`
- Test with a small table first

### 4. Configure Monitoring
- Set up CloudWatch dashboards
- Configure SNS subscriptions for alerts
- Test notification system

### 5. Run Initial Migration
- Start with full load migration
- Validate data integrity
- Enable CDC for real-time synchronization

### 6. Performance Tuning
- Monitor migration performance
- Adjust DMS instance size if needed
- Optimize Snowflake warehouse sizes

## Resources Created:
- S3 Staging Bucket: $S3_BUCKET
- DMS Replication Instance: $(terraform output -raw dms_replication_instance_id 2>/dev/null || echo "N/A")
- Lambda Functions: $(terraform output -json lambda_functions 2>/dev/null | jq -r 'keys[]' | tr '\n' ', ' || echo "N/A")
- SNS Topic: $(terraform output -raw sns_topic_name 2>/dev/null || echo "N/A")

## Useful Commands:
\`\`\`bash
# Check DMS task status
aws dms describe-replication-tasks

# List S3 objects
aws s3 ls s3://$S3_BUCKET --recursive

# Check Lambda logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/sql-snowflake-migration"

# Monitor CloudWatch metrics
aws cloudwatch list-metrics --namespace "Migration/SQLServer-Snowflake"
\`\`\`

Generated on: $(date)
EOF
    
    print_success "Next steps guide created: $NEXT_STEPS_FILE"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up temporary files..."
    rm -f "$TERRAFORM_DIR/tfplan"
    rm -rf "$PROJECT_ROOT/build"
}

# Main execution
main() {
    print_status "SQL Server to Snowflake Migration Deployment"
    print_status "============================================="
    
    # Run deployment steps
    check_prerequisites
    build_lambda_functions
    init_terraform
    
    # Create tfvars file if it doesn't exist
    if [[ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]]; then
        create_tfvars
        print_error "Please update $TERRAFORM_DIR/terraform.tfvars with your configuration and run the script again"
        exit 1
    fi
    
    plan_terraform
    apply_terraform
    post_deployment
    cleanup
    
    if [[ "$DESTROY_MODE" == true ]]; then
        print_success "Destruction completed successfully!"
    elif [[ "$PLAN_ONLY" == true ]]; then
        print_success "Planning completed successfully!"
    else
        print_success "Deployment completed successfully!"
        print_status "Check NEXT_STEPS.md for post-deployment configuration"
    fi
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Run main function
main


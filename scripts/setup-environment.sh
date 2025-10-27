#!/bin/bash

# SQL Server to Snowflake Migration - Environment Setup Script
# This script sets up the development environment and installs dependencies

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_status "Setting up SQL Server to Snowflake Migration environment"
print_status "======================================================="

# Check operating system
OS="$(uname -s)"
case "${OS}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    CYGWIN*)    MACHINE=Cygwin;;
    MINGW*)     MACHINE=MinGw;;
    *)          MACHINE="UNKNOWN:${OS}"
esac

print_status "Detected operating system: $MACHINE"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Homebrew on macOS
install_homebrew() {
    if [[ "$MACHINE" == "Mac" ]] && ! command_exists brew; then
        print_status "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        print_success "Homebrew installed"
    fi
}

# Install AWS CLI
install_aws_cli() {
    if ! command_exists aws; then
        print_status "Installing AWS CLI..."
        
        case "$MACHINE" in
            Mac)
                if command_exists brew; then
                    brew install awscli
                else
                    curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
                    sudo installer -pkg AWSCLIV2.pkg -target /
                    rm AWSCLIV2.pkg
                fi
                ;;
            Linux)
                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                unzip awscliv2.zip
                sudo ./aws/install
                rm -rf aws awscliv2.zip
                ;;
            *)
                print_error "Please install AWS CLI manually for your operating system"
                exit 1
                ;;
        esac
        
        print_success "AWS CLI installed"
    else
        print_success "AWS CLI already installed"
    fi
}

# Install Terraform
install_terraform() {
    if ! command_exists terraform; then
        print_status "Installing Terraform..."
        
        case "$MACHINE" in
            Mac)
                if command_exists brew; then
                    brew tap hashicorp/tap
                    brew install hashicorp/tap/terraform
                else
                    # Manual installation for macOS
                    TERRAFORM_VERSION="1.6.6"
                    curl -O "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_darwin_amd64.zip"
                    unzip "terraform_${TERRAFORM_VERSION}_darwin_amd64.zip"
                    sudo mv terraform /usr/local/bin/
                    rm "terraform_${TERRAFORM_VERSION}_darwin_amd64.zip"
                fi
                ;;
            Linux)
                # Install Terraform on Linux
                TERRAFORM_VERSION="1.6.6"
                curl -O "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
                unzip "terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
                sudo mv terraform /usr/local/bin/
                rm "terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
                ;;
            *)
                print_error "Please install Terraform manually for your operating system"
                exit 1
                ;;
        esac
        
        print_success "Terraform installed"
    else
        print_success "Terraform already installed"
    fi
}

# Install Python and pip
install_python() {
    if ! command_exists python3; then
        print_status "Installing Python 3..."
        
        case "$MACHINE" in
            Mac)
                if command_exists brew; then
                    brew install python@3.9
                else
                    print_error "Please install Python 3.9+ manually"
                    exit 1
                fi
                ;;
            Linux)
                # Try to install Python using package manager
                if command_exists apt-get; then
                    sudo apt-get update
                    sudo apt-get install -y python3 python3-pip python3-venv
                elif command_exists yum; then
                    sudo yum install -y python3 python3-pip
                elif command_exists dnf; then
                    sudo dnf install -y python3 python3-pip
                else
                    print_error "Please install Python 3.9+ manually"
                    exit 1
                fi
                ;;
            *)
                print_error "Please install Python 3.9+ manually"
                exit 1
                ;;
        esac
        
        print_success "Python 3 installed"
    else
        print_success "Python 3 already installed"
    fi
    
    # Check Python version
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    print_status "Python version: $PYTHON_VERSION"
}

# Install jq for JSON processing
install_jq() {
    if ! command_exists jq; then
        print_status "Installing jq..."
        
        case "$MACHINE" in
            Mac)
                if command_exists brew; then
                    brew install jq
                else
                    curl -L "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64" -o jq
                    chmod +x jq
                    sudo mv jq /usr/local/bin/
                fi
                ;;
            Linux)
                if command_exists apt-get; then
                    sudo apt-get install -y jq
                elif command_exists yum; then
                    sudo yum install -y jq
                elif command_exists dnf; then
                    sudo dnf install -y jq
                else
                    curl -L "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64" -o jq
                    chmod +x jq
                    sudo mv jq /usr/local/bin/
                fi
                ;;
            *)
                print_error "Please install jq manually"
                exit 1
                ;;
        esac
        
        print_success "jq installed"
    else
        print_success "jq already installed"
    fi
}

# Install zip/unzip utilities
install_zip_utils() {
    if ! command_exists zip || ! command_exists unzip; then
        print_status "Installing zip utilities..."
        
        case "$MACHINE" in
            Mac)
                # Usually pre-installed on macOS
                if ! command_exists zip; then
                    if command_exists brew; then
                        brew install zip
                    fi
                fi
                ;;
            Linux)
                if command_exists apt-get; then
                    sudo apt-get install -y zip unzip
                elif command_exists yum; then
                    sudo yum install -y zip unzip
                elif command_exists dnf; then
                    sudo dnf install -y zip unzip
                fi
                ;;
        esac
        
        print_success "Zip utilities installed"
    else
        print_success "Zip utilities already installed"
    fi
}

# Create Python virtual environment
create_virtual_environment() {
    print_status "Creating Python virtual environment..."
    
    VENV_DIR="$PROJECT_ROOT/venv"
    
    if [[ ! -d "$VENV_DIR" ]]; then
        python3 -m venv "$VENV_DIR"
        print_success "Virtual environment created at $VENV_DIR"
    else
        print_success "Virtual environment already exists"
    fi
    
    # Activate virtual environment and install dependencies
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install Python dependencies
    if [[ -f "$PROJECT_ROOT/lambda/requirements.txt" ]]; then
        print_status "Installing Python dependencies..."
        pip install -r "$PROJECT_ROOT/lambda/requirements.txt"
        print_success "Python dependencies installed"
    fi
    
    # Install development dependencies
    print_status "Installing development dependencies..."
    pip install \
        pytest \
        black \
        flake8 \
        mypy \
        pre-commit \
        yamllint
    
    print_success "Development dependencies installed"
}

# Set up pre-commit hooks
setup_pre_commit() {
    print_status "Setting up pre-commit hooks..."
    
    # Create .pre-commit-config.yaml if it doesn't exist
    PRE_COMMIT_CONFIG="$PROJECT_ROOT/.pre-commit-config.yaml"
    
    if [[ ! -f "$PRE_COMMIT_CONFIG" ]]; then
        cat > "$PRE_COMMIT_CONFIG" << 'EOF'
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: check-merge-conflict
      - id: check-added-large-files
        args: ['--maxkb=1000']
  
  - repo: https://github.com/psf/black
    rev: 23.9.1
    hooks:
      - id: black
        language_version: python3
        files: \.py$
  
  - repo: https://github.com/pycqa/flake8
    rev: 6.1.0
    hooks:
      - id: flake8
        files: \.py$
        args: [--max-line-length=88, --extend-ignore=E203,W503]
  
  - repo: https://github.com/adrienverge/yamllint
    rev: v1.32.0
    hooks:
      - id: yamllint
        files: \.(yaml|yml)$
        args: [-d, relaxed]
EOF
        print_success "Pre-commit configuration created"
    fi
    
    # Install pre-commit hooks
    source "$PROJECT_ROOT/venv/bin/activate"
    pre-commit install
    print_success "Pre-commit hooks installed"
}

# Create environment configuration
create_env_config() {
    print_status "Creating environment configuration..."
    
    ENV_FILE="$PROJECT_ROOT/.env.example"
    
    if [[ ! -f "$ENV_FILE" ]]; then
        cat > "$ENV_FILE" << 'EOF'
# Environment Configuration for SQL Server to Snowflake Migration
# Copy this file to .env and update with your actual values

# AWS Configuration
AWS_REGION=us-east-1
AWS_PROFILE=default

# SQL Server Configuration
SQL_SERVER_HOST=your-sql-server.domain.com
SQL_SERVER_PORT=1433
SQL_SERVER_DATABASE=YourDatabase
SQL_SERVER_USERNAME=migration_user
SQL_SERVER_PASSWORD=YourPassword

# Snowflake Configuration
SNOWFLAKE_ACCOUNT=your-account.region.snowflakecomputing.com
SNOWFLAKE_USER=MIGRATION_USER
SNOWFLAKE_PASSWORD=YourPassword
SNOWFLAKE_ROLE=MIGRATION_USER
SNOWFLAKE_WAREHOUSE=MIGRATION_WH
SNOWFLAKE_DATABASE=MIGRATION_DB

# Environment
ENVIRONMENT=dev
PROJECT_NAME=sql-snowflake-migration

# Notification
NOTIFICATION_EMAIL=admin@yourcompany.com

# Logging
LOG_LEVEL=INFO
ENABLE_DEBUG=false
EOF
        print_success "Environment configuration template created: $ENV_FILE"
        print_warning "Please copy .env.example to .env and update with your actual values"
    fi
}

# Create directory structure
create_directories() {
    print_status "Creating project directory structure..."
    
    # Create additional directories that might be needed
    mkdir -p "$PROJECT_ROOT/logs"
    mkdir -p "$PROJECT_ROOT/temp"
    mkdir -p "$PROJECT_ROOT/tests"
    mkdir -p "$PROJECT_ROOT/build"
    
    print_success "Directory structure created"
}

# Verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    # Check all required tools
    TOOLS=("aws" "terraform" "python3" "jq" "zip" "unzip")
    
    for tool in "${TOOLS[@]}"; do
        if command_exists "$tool"; then
            VERSION=$($tool --version 2>&1 | head -n1 || echo "Version unknown")
            print_success "$tool: $VERSION"
        else
            print_error "$tool: Not installed"
        fi
    done
    
    # Check AWS credentials
    if aws sts get-caller-identity &> /dev/null; then
        AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
        AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
        print_success "AWS credentials configured - Account: $AWS_ACCOUNT, User: $AWS_USER"
    else
        print_warning "AWS credentials not configured. Run 'aws configure' to set them up."
    fi
    
    # Check Python virtual environment
    if [[ -d "$PROJECT_ROOT/venv" ]]; then
        print_success "Python virtual environment: $PROJECT_ROOT/venv"
    else
        print_error "Python virtual environment not created"
    fi
}

# Show next steps
show_next_steps() {
    print_status "Setup completed! Next steps:"
    echo ""
    echo "1. Configure AWS credentials (if not already done):"
    echo "   aws configure"
    echo ""
    echo "2. Copy and update environment configuration:"
    echo "   cp .env.example .env"
    echo "   # Edit .env with your actual values"
    echo ""
    echo "3. Update migration configuration:"
    echo "   # Edit config/migration-config.yaml with your settings"
    echo ""
    echo "4. Activate Python virtual environment:"
    echo "   source venv/bin/activate"
    echo ""
    echo "5. Deploy the infrastructure:"
    echo "   ./scripts/deploy.sh"
    echo ""
    echo "6. Run tests (optional):"
    echo "   pytest tests/"
    echo ""
    print_success "Environment setup completed successfully!"
}

# Main execution
main() {
    install_homebrew
    install_aws_cli
    install_terraform
    install_python
    install_jq
    install_zip_utils
    create_virtual_environment
    setup_pre_commit
    create_env_config
    create_directories
    verify_installation
    show_next_steps
}

# Run main function
main


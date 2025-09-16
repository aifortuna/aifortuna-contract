#!/bin/bash
set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

echo "=== Fortuna Smart Contract Deployment ==="

# Function to load environment configuration
load_env() {
    local env_name=$1
    local env_file="$PROJECT_ROOT/env/env.$env_name"
    
    if [ -f "$env_file" ]; then
        source "$env_file"
        echo "Loaded environment: $env_name"
    else
        echo "Environment file not found: $env_file"
        exit 1
    fi
}

# Function to set environment variables for ConfigTools
set_config_env() {
    local network=$1
    local chain_id=$2
    
    export CONFIG_ENV_ROOT_CHAINID="$chain_id"
    export CONFIG_ENV_SCRIPT_CHAININFO="$network"
    export CONFIG_ENV_SCRIPT_APPINFO="fortuna"
    export CONFIG_ENV_SCRIPT_CONFIG_NAME="deploy"
    export FOUNDRY_EXPORTS_NAME="deploy"
    export FOUNDRY_EXPORTS_OVERWRITE_LATEST="true"
}

# Function to deploy contracts
deploy() {
    local env_name=$1
    local network=$2
    local chain_id=$3
    local rpc_url_var=$4
    
    echo "Starting deployment for $env_name environment..."
    
    load_env "$env_name"
    set_config_env "$network" "$chain_id"
    
    local rpc_url="${!rpc_url_var}"
    
    echo "Network: $network"
    echo "Chain ID: $chain_id"
    echo "RPC URL: $rpc_url"
    
    cd "$PROJECT_ROOT"
    
    # Clean and build
    forge clean
    forge build
    
    # Deploy contracts
    forge script script/deploy/Deploy.s.sol \
        --rpc-url "$rpc_url" \
        --private-key "$BSC_DEPLOY_SECRET_KEY" \
        --broadcast \
        --verify \
        --slow
    
    echo "Deployment completed for $env_name environment"
}

# Function to show usage
usage() {
    echo "Usage: $0 <environment>"
    echo "Environments:"
    echo "  dev     - Deploy to BSC Testnet"
    echo "  beta    - Deploy to BSC Testnet (beta config)"
    echo "  pro     - Deploy to BSC Mainnet"
    echo ""
    echo "Examples:"
    echo "  $0 dev"
    echo "  $0 pro"
}

# Main script logic
case "$1" in
    "dev")
        deploy "dev" "bsc-testnet" "97" "BSC_TESTNET_RPC"
        ;;
    "beta")
        deploy "beta" "bsc-mainnet" "56" "BSC_MAINNET_RPC"
        ;;
    "pro")
        deploy "pro" "bsc-mainnet" "56" "BSC_MAINNET_RPC"
        ;;
    "")
        echo "Error: Environment not specified"
        usage
        exit 1
        ;;
    *)
        echo "Error: Unknown environment '$1'"
        usage
        exit 1
        ;;
esac

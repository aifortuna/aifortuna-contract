#!/bin/bash
set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

echo "=== Fortuna Smart Contract Upgrade ==="

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
    export CONFIG_ENV_SCRIPT_CONFIG_NAME="addresses"
    export FOUNDRY_EXPORTS_NAME="upgrade"
    export FOUNDRY_EXPORTS_OVERWRITE_LATEST="true"
}

# Function to upgrade contracts
upgrade() {
    local env_name=$1
    local network=$2
    local chain_id=$3
    local rpc_url_var=$4
    local contract=$5
    
    echo "Starting upgrade for $env_name environment..."
    
    load_env "$env_name"
    set_config_env "$network" "$chain_id"
    
    local rpc_url="${!rpc_url_var}"
    
    echo "Network: $network"
    echo "Chain ID: $chain_id"
    echo "Contract: $contract"
    echo "RPC URL: $rpc_url"
    
    cd "$PROJECT_ROOT"
    
    # Clean and build
    forge clean
    forge build
    
    # Upgrade contract
    if [ "$contract" = "all" ]; then
        echo "Upgrading all contracts..."
        forge script script/deploy/Upgrade.s.sol \
            --rpc-url "$rpc_url" \
            --private-key "$BSC_DEPLOY_SECRET_KEY" \
            --broadcast \
            --verify \
            --slow
    else
        echo "Upgrading $contract contract..."
        forge script script/deploy/Upgrade.s.sol \
            --rpc-url "$rpc_url" \
            --private-key "$BSC_DEPLOY_SECRET_KEY" \
            --broadcast \
            --verify \
            --slow \
            --sig "upgrade${contract}Only()"
    fi
    
    echo "Upgrade completed for $env_name environment"
}

# Function to check current implementations
check_implementations() {
    local env_name=$1
    local network=$2
    local chain_id=$3
    local rpc_url_var=$4
    
    echo "Checking current implementations for $env_name environment..."
    
    load_env "$env_name"
    set_config_env "$network" "$chain_id"
    
    local rpc_url="${!rpc_url_var}"
    
    cd "$PROJECT_ROOT"
    
    # Build contracts
    forge build
    
    # Check implementations
    forge script script/deploy/Upgrade.s.sol \
        --rpc-url "$rpc_url" \
        --sig "checkImplementations()"
    
    echo "Implementation check completed"
}

# Function to show usage
usage() {
    echo "Usage: $0 <environment> <contract> [--check]"
    echo ""
    echo "Environments:"
    echo "  dev     - BSC Testnet"
    echo "  beta    - BSC Testnet (beta config)"
    echo "  pro     - BSC Mainnet"
    echo ""
    echo "Contracts:"
    echo "  all         - Upgrade all contracts"
    echo "  NodeCard    - Upgrade NodeCard only"
    echo "  Treasury    - Upgrade Treasury only"
    echo "  Fortuna     - Upgrade Fortuna only"
    echo ""
    echo "Options:"
    echo "  --check     - Check current implementation addresses"
    echo ""
    echo "Examples:"
    echo "  $0 dev all                    # Upgrade all contracts"
    echo "  $0 dev Fortuna               # Upgrade Fortuna only"
    echo "  $0 pro NodeCard --check      # Check NodeCard implementation"
}

# Parse arguments
ENV=""
CONTRACT=""
CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --check)
            CHECK_ONLY=true
            shift
            ;;
        *)
            if [ -z "$ENV" ]; then
                ENV=$1
            elif [ -z "$CONTRACT" ]; then
                CONTRACT=$1
            else
                echo "Error: Too many arguments"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [ -z "$ENV" ]; then
    echo "Error: Environment is required"
    usage
    exit 1
fi

# Set network parameters based on environment
case "$ENV" in
    "dev")
        NETWORK="bsc-testnet"
        CHAIN_ID="97"
        RPC_URL_VAR="BSC_TESTNET_RPC"
        ;;
    "pro"|"beta")
        NETWORK="bsc-mainnet"
        CHAIN_ID="56"
        RPC_URL_VAR="BSC_MAINNET_RPC"
        ;;
    *)
        echo "Error: Unknown environment '$ENV'"
        usage
        exit 1
        ;;
esac

# Run the appropriate command
if [ "$CHECK_ONLY" = true ]; then
    check_implementations "$ENV" "$NETWORK" "$CHAIN_ID" "$RPC_URL_VAR"
elif [ -n "$CONTRACT" ]; then
    # Validate contract name
    case "$CONTRACT" in
        "all"|"NodeCard"|"Treasury"|"Fortuna")
            upgrade "$ENV" "$NETWORK" "$CHAIN_ID" "$RPC_URL_VAR" "$CONTRACT"
            ;;
        *)
            echo "Error: Unknown contract '$CONTRACT'"
            usage
            exit 1
            ;;
    esac
else
    echo "Error: Contract is required (or use --check)"
    usage
    exit 1
fi

#!/bin/bash
set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

echo "=== Fortuna Smart Contract Interaction ==="

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
}

# Function to run interaction script
interact() {
    local env_name=$1
    local network=$2
    local chain_id=$3
    local rpc_url_var=$4
    local contract=$5
    local function_name=$6
    
    echo "Running interaction for $env_name environment..."
    
    load_env "$env_name"
    set_config_env "$network" "$chain_id"
    
    local rpc_url="${!rpc_url_var}"
    
    echo "Network: $network"
    echo "Chain ID: $chain_id"
    echo "Contract: $contract"
    echo "Function: $function_name"
    echo "RPC URL: $rpc_url"
    
    cd "$PROJECT_ROOT"
    
    # Build contracts
    forge build
    
    # Run interaction script
    if [ -n "$function_name" ]; then
        forge script "script/run/${contract}Interaction.s.sol:${contract}Interaction" \
            --rpc-url "$rpc_url" \
            --private-key "$BSC_DEPLOY_SECRET_KEY" \
            --broadcast \
            --sig "$function_name()"
    else
        forge script "script/run/${contract}Interaction.s.sol:${contract}Interaction" \
            --rpc-url "$rpc_url" \
            --private-key "$BSC_DEPLOY_SECRET_KEY" \
            --broadcast
    fi
    
    echo "Interaction completed"
}

# Function to run view-only functions (no broadcast)
view() {
    local env_name=$1
    local network=$2
    local chain_id=$3
    local rpc_url_var=$4
    local contract=$5
    local function_name=$6
    
    echo "Running view function for $env_name environment..."
    
    load_env "$env_name"
    set_config_env "$network" "$chain_id"
    
    local rpc_url="${!rpc_url_var}"
    
    echo "Network: $network"
    echo "Chain ID: $chain_id"
    echo "Contract: $contract"
    echo "Function: $function_name"
    
    cd "$PROJECT_ROOT"
    
    # Build contracts
    forge build
    
    # Run view function
    forge script "script/run/${contract}Interaction.s.sol:${contract}Interaction" \
        --rpc-url "$rpc_url" \
        --sig "$function_name()"
    
    echo "View function completed"
}

# Function to show usage
usage() {
    echo "Usage: $0 <environment> <contract> [function] [--view]"
    echo ""
    echo "Environments:"
    echo "  dev     - BSC Testnet"
    echo "  beta    - BSC Testnet (beta config)"
    echo "  pro     - BSC Mainnet"
    echo ""
    echo "Contracts:"
    echo "  Fortuna     - Fortuna game contract interactions"
    echo "  AGT         - AGT token interactions"
    echo "  NodeCard    - NodeCard contract interactions"
    echo "  Treasury    - Treasury contract interactions"
    echo ""
    echo "Options:"
    echo "  --view      - Run as view-only (no transactions)"
    echo ""
    echo "Examples:"
    echo "  $0 dev Fortuna                    # Run default Fortuna interaction"
    echo "  $0 dev Fortuna setBnbFee          # Run specific function"
    echo "  $0 dev AGT checkPermissions --view # Run view function"
    echo "  $0 pro Treasury getTreasuryInfo --view"
}

# Parse arguments
ENV=""
CONTRACT=""
FUNCTION=""
VIEW_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --view)
            VIEW_ONLY=true
            shift
            ;;
        *)
            if [ -z "$ENV" ]; then
                ENV=$1
            elif [ -z "$CONTRACT" ]; then
                CONTRACT=$1
            elif [ -z "$FUNCTION" ]; then
                FUNCTION=$1
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
if [ -z "$ENV" ] || [ -z "$CONTRACT" ]; then
    echo "Error: Environment and contract are required"
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

# Validate contract name
case "$CONTRACT" in
    "Fortuna"|"AGT"|"NodeCard"|"Treasury")
        ;;
    *)
        echo "Error: Unknown contract '$CONTRACT'"
        usage
        exit 1
        ;;
esac

# Run the appropriate command
if [ "$VIEW_ONLY" = true ]; then
    if [ -z "$FUNCTION" ]; then
        echo "Error: Function name is required for view-only mode"
        usage
        exit 1
    fi
    view "$ENV" "$NETWORK" "$CHAIN_ID" "$RPC_URL_VAR" "$CONTRACT" "$FUNCTION"
else
    interact "$ENV" "$NETWORK" "$CHAIN_ID" "$RPC_URL_VAR" "$CONTRACT" "$FUNCTION"
fi

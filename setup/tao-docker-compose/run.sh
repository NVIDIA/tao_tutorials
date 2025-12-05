#!/bin/bash
# TAO Docker Compose Runner with Configurable Settings
# ====================================================

set -e

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  up              Start all services (default: TAO API only)"
    echo "  up-all          Start all services including SeaweedFS"
    echo "  down            Stop all services"
    echo "  restart         Restart all services"
    echo "  logs            Show logs for all services"
    echo "  status          Show status of all services"
    echo "  config          Show current configuration"
    echo "  help            Show this help message"
    echo ""
    echo "Options:"
    echo "  --airgapped     Enable airgapped mode"
    echo "  --no-airgapped  Disable airgapped mode"
    echo "  --ptm           Enable pretrained models pull"
    echo "  --no-ptm        Disable pretrained models pull"
    echo "  --python=VER    Set Python version (e.g., --python=3.11)"
    echo "  --config=FILE   Use custom config file (default: config.env)"
    echo ""
    echo "Examples:"
    echo "  $0 up                    # Start TAO API services only"
    echo "  $0 up-all                # Start all services including SeaweedFS"
    echo "  $0 up --airgapped        # Start in airgapped mode"
    echo "  $0 up --ptm              # Start with pretrained models pull"
    echo "  $0 up --python=3.11      # Use Python 3.11"
    echo "  $0 config                # Show current configuration"
}

# Default values
COMMAND="up"
CONFIG_FILE="config.env"
AIRGAPPED_OVERRIDE=""
PTM_OVERRIDE=""
PYTHON_OVERRIDE=""
SEAWEEDFS_PROFILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        up|down|restart|logs|status|config|help)
            COMMAND="$1"
            shift
            ;;
        up-all)
            COMMAND="up"
            SEAWEEDFS_PROFILE="--profile seaweedfs"
            shift
            ;;
        --airgapped)
            AIRGAPPED_OVERRIDE="AIRGAPPED_MODE=true"
            shift
            ;;
        --no-airgapped)
            AIRGAPPED_OVERRIDE="AIRGAPPED_MODE=false"
            shift
            ;;
        --ptm)
            PTM_OVERRIDE="PTM_PULL=true"
            shift
            ;;
        --no-ptm)
            PTM_OVERRIDE="PTM_PULL=false"
            shift
            ;;
        --python=*)
            PYTHON_OVERRIDE="PYTHON_VERSION=${1#*=}"
            shift
            ;;
        --config=*)
            CONFIG_FILE="${1#*=}"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file '$CONFIG_FILE' not found!"
    echo "Please copy config.env.example to $CONFIG_FILE and adjust settings as needed."
    exit 1
fi

# Source the config file
echo "Loading configuration from $CONFIG_FILE..."
set -a  # automatically export all variables
source "$CONFIG_FILE"
set +a

# Apply command line overrides
if [[ -n "$AIRGAPPED_OVERRIDE" ]]; then
    export $AIRGAPPED_OVERRIDE
    echo "Override: $AIRGAPPED_OVERRIDE"
fi

if [[ -n "$PTM_OVERRIDE" ]]; then
    export $PTM_OVERRIDE
    echo "Override: $PTM_OVERRIDE"
fi

if [[ -n "$PYTHON_OVERRIDE" ]]; then
    export $PYTHON_OVERRIDE
    echo "Override: $PYTHON_OVERRIDE"
fi

# Enforce airgapped mode logic
if [[ "$AIRGAPPED_MODE" == "true" ]]; then
    # No internet access means no PTM pull
    if [[ "$PTM_PULL" == "true" ]]; then
        echo "Warning: PTM_PULL disabled because AIRGAPPED_MODE=true (no internet access)"
        export PTM_PULL=false
    fi

    # No internet access means local storage is required
    if [[ "$SEAWEEDFS_ENABLED" == "false" ]]; then
        echo "Warning: SEAWEEDFS_ENABLED forced to true because AIRGAPPED_MODE=true (local storage required)"
        export SEAWEEDFS_ENABLED=true
    fi
fi

# Show current configuration if requested
if [[ "$COMMAND" == "config" ]]; then
    echo ""
    echo "Current Configuration:"
    echo "====================="
    echo "AIRGAPPED_MODE: $AIRGAPPED_MODE (controls internet access features)"
    echo "PTM_PULL: $PTM_PULL"
    echo "SEAWEEDFS_ENABLED: $SEAWEEDFS_ENABLED (controls local storage)"
    echo "PYTHON_VERSION: $PYTHON_VERSION"
    echo "DEPLOYMENT_MODE: $DEPLOYMENT_MODE"
    echo "IMAGE_TAO_PYTORCH: $IMAGE_TAO_PYTORCH"
    echo "DOCKER_NETWORK: $DOCKER_NETWORK"
    echo ""
    echo "To modify these settings:"
    echo "1. Edit $CONFIG_FILE"
    echo "2. Use command line overrides (--airgapped, --ptm, --python=X.Y)"
    echo "3. Set environment variables directly"
    exit 0
fi

# Show help if requested
if [[ "$COMMAND" == "help" ]]; then
    show_usage
    exit 0
fi

# Configure SeaweedFS environment variable for nginx
configure_seaweedfs_config() {
    if [[ "$SEAWEEDFS_ENABLED" == "true" ]]; then
        echo "Configuring nginx with SeaweedFS support..."
        export SEAWEEDFS_CONFIG='
    # SeaweedFS routes
    location /seaweedfs/master/ {
        set $seaweedfs_master http://seaweedfs-master:9333;
        proxy_pass $seaweedfs_master;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /seaweedfs/filer/ {
        set $seaweedfs_filer http://seaweedfs-filer:8888;
        proxy_pass $seaweedfs_filer;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /seaweedfs/s3/ {
        set $seaweedfs_s3 http://seaweedfs-s3:8333;
        proxy_pass $seaweedfs_s3;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }'
    else
        echo "Configuring nginx without SeaweedFS (SeaweedFS disabled)..."
        export SEAWEEDFS_CONFIG=""
    fi
}

# Build profile arguments
PROFILE_ARGS=""
if [[ -n "$SEAWEEDFS_PROFILE" ]] || [[ "$SEAWEEDFS_ENABLED" == "true" ]]; then
    PROFILE_ARGS="$PROFILE_ARGS --profile seaweedfs"
fi
if [[ "$PTM_PULL" == "true" ]]; then
    PROFILE_ARGS="$PROFILE_ARGS --profile ptm"
fi

# Execute docker compose command
echo ""
echo "Executing: docker compose $PROFILE_ARGS $COMMAND"
echo "Configuration loaded from: $CONFIG_FILE"
echo "AIRGAPPED_MODE: $AIRGAPPED_MODE"
echo "PTM_PULL: $PTM_PULL"
echo "PYTHON_VERSION: $PYTHON_VERSION"
echo ""

case $COMMAND in
    up)
        configure_seaweedfs_config
        docker compose $PROFILE_ARGS up -d
        echo ""
        echo "Services started successfully!"
        echo "TAO API: http://localhost"
        if [[ -n "$SEAWEEDFS_PROFILE" ]]; then
            echo "SeaweedFS Master: http://localhost:9333"
            echo "SeaweedFS Filer: http://localhost:8888"
            echo "SeaweedFS S3: http://localhost:8333"
        fi
        if [[ "$PTM_PULL" == "true" ]]; then
            echo "Pretrained models will be pulled on startup"
        fi
        ;;
    down)
        echo "Stopping all services (including SeaweedFS and PTM profiles)..."
        docker compose --profile seaweedfs --profile ptm down
        echo "All services stopped successfully."
        ;;
    restart)
        configure_seaweedfs_config
        docker compose $PROFILE_ARGS restart
        echo "Services restarted."
        ;;
    logs)
        docker compose $PROFILE_ARGS logs -f
        ;;
    status)
        docker compose $PROFILE_ARGS ps
        ;;
    *)
        echo "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac
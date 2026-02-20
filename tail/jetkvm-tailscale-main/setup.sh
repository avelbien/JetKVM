#!/bin/bash

# Load configuration from .env if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Configuration Defaults (can be overridden by .env)
JETKVM_IP="${JETKVM_IP:-}"
SSH_USER="${SSH_USER:-root}"
REMOTE_DIR="/userdata"
LOGIN_SERVER="${TAILSCALE_LOGIN_SERVER:-}"
AUTH_KEY="${TAILSCALE_AUTH_KEY:-}"
SSH_KEY_PATH="${SSH_KEY_PATH:-}"
TARGET_VERSION="${TAILSCALE_VERSION:-}"

UPDATE_MODE=false

# Parse arguments (override .env)
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --login-server) LOGIN_SERVER="$2"; shift ;;
        --auth-key) AUTH_KEY="$2"; shift ;;
        --version) TARGET_VERSION="$2"; shift ;;
        --update) UPDATE_MODE=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check for required configuration
if [ -z "$JETKVM_IP" ]; then
    echo "Error: JETKVM_IP is not set. Please set it in .env or script."
    exit 1
fi

# SSH Command Construction
SSH_CMD="ssh"
if [ -n "$SSH_KEY_PATH" ]; then
    if [ ! -f "$SSH_KEY_PATH" ]; then
        echo "Error: SSH key not found at $SSH_KEY_PATH"
        exit 1
    fi
    SSH_CMD="ssh -i $SSH_KEY_PATH"
fi

# Files to transfer
INIT_SCRIPT="S22tailscale"
INSTALL_SCRIPT="install_on_device.sh"

# Ensure we are in the directory containing the scripts
cd "$(dirname "$0")"

# 1. Determine Tailscale version
if [ -n "$TARGET_VERSION" ]; then
    echo "Using specified Tailscale version: $TARGET_VERSION"
    LATEST_FILE="tailscale_${TARGET_VERSION}_arm.tgz"
    DOWNLOAD_URL="https://pkgs.tailscale.com/stable/$LATEST_FILE"
else
    echo "Checking for latest Tailscale ARM version..."
    # Scrape the page for the latest stable arm tgz
    LATEST_FILE=$(curl -s https://pkgs.tailscale.com/stable/ | grep -o 'tailscale_[0-9]\+\.[0-9]\+\.[0-9]\+_arm\.tgz' | head -n 1)

    if [ -z "$LATEST_FILE" ]; then
        echo "Error: Could not determine latest Tailscale version."
        exit 1
    fi
    echo "Latest version found: $LATEST_FILE"
    DOWNLOAD_URL="https://pkgs.tailscale.com/stable/$LATEST_FILE"
fi

# 2. Download Tailscale
CURRENT_VERSION=""
if [ -f "tailscale_version.txt" ]; then
    CURRENT_VERSION=$(cat tailscale_version.txt)
fi

if [ -f "tailscale.tar" ] && [ "$CURRENT_VERSION" == "$LATEST_FILE" ]; then
    echo "tailscale.tar is already at the latest version ($LATEST_FILE). Skipping download."
else
    echo "Downloading $LATEST_FILE..."
    curl -f -L -o "tailscale.tar.gz" "$DOWNLOAD_URL"

    if [ $? -ne 0 ]; then
        echo "Error: Download failed. Please check your internet connection or if the version exists."
        exit 1
    fi

    # 3. Decompress gzip locally (as per instructions to pipe uncompressed tar)
    echo "Decompressing to tailscale.tar..."
    gzip -d -c tailscale.tar.gz > tailscale.tar
    rm tailscale.tar.gz
    
    # Save the version
    echo "$LATEST_FILE" > tailscale_version.txt
fi

# 4. Check Remote Version
echo "Checking remote Tailscale version..."
REMOTE_VERSION_CMD="$REMOTE_DIR/tailscale/tailscale --version 2>/dev/null | head -n 1 | awk '{print \$1}'"
REMOTE_VERSION=$($SSH_CMD "$SSH_USER@$JETKVM_IP" "$REMOTE_VERSION_CMD")

# Extract version number from filename (e.g., tailscale_1.90.9_arm.tgz -> 1.90.9)
LOCAL_VERSION_NUM=$(echo $LATEST_FILE | sed -n 's/tailscale_\([0-9.]*\)_arm.tgz/\1/p')

NEED_TRANSFER=true
if [ -n "$REMOTE_VERSION" ] && [ "$REMOTE_VERSION" == "$LOCAL_VERSION_NUM" ]; then
    echo "Remote version ($REMOTE_VERSION) matches local version ($LOCAL_VERSION_NUM)."
    if [ "$UPDATE_MODE" = true ]; then
        echo "Update forced via --update flag. Re-transferring..."
    else
        echo "Skipping binary transfer."
        NEED_TRANSFER=false
    fi
fi

# 5. Transfer files
echo "Transferring files to $JETKVM_IP..."

if [ "$NEED_TRANSFER" = true ]; then
    echo "Transferring tailscale.tar..."
    cat tailscale.tar | $SSH_CMD "$SSH_USER@$JETKVM_IP" "cat > $REMOTE_DIR/tailscale.tar"
    if [ $? -ne 0 ]; then echo "Error transferring tailscale.tar"; exit 1; fi
fi

echo "Transferring $INIT_SCRIPT..."
cat "$INIT_SCRIPT" | $SSH_CMD "$SSH_USER@$JETKVM_IP" "cat > $REMOTE_DIR/$INIT_SCRIPT"
if [ $? -ne 0 ]; then echo "Error transferring $INIT_SCRIPT"; exit 1; fi

echo "Transferring $INSTALL_SCRIPT..."
cat "$INSTALL_SCRIPT" | $SSH_CMD "$SSH_USER@$JETKVM_IP" "cat > $REMOTE_DIR/$INSTALL_SCRIPT"
if [ $? -ne 0 ]; then echo "Error transferring $INSTALL_SCRIPT"; exit 1; fi

# 6. Run install script on device
echo "Running installation script on device..."
# Construct the command with optional arguments
REMOTE_CMD="chmod +x $REMOTE_DIR/$INSTALL_SCRIPT && $REMOTE_DIR/$INSTALL_SCRIPT"
if [ "$UPDATE_MODE" = true ]; then
    REMOTE_CMD="$REMOTE_CMD --update"
fi
if [ -n "$LOGIN_SERVER" ]; then
    REMOTE_CMD="$REMOTE_CMD --login-server $LOGIN_SERVER"
fi
if [ -n "$AUTH_KEY" ]; then
    REMOTE_CMD="$REMOTE_CMD --auth-key $AUTH_KEY"
fi

$SSH_CMD "$SSH_USER@$JETKVM_IP" "$REMOTE_CMD"

# Cleanup local artifacts
# We keep tailscale.tar for future runs to avoid redownloading
# echo "Cleaning up local temporary files..."
# rm tailscale.tar

echo "Setup complete!"
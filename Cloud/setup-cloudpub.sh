#!/bin/bash

# Load configuration from .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

JETKVM_IP="${JETKVM_IP:-}"
SSH_USER="${SSH_USER:-root}"
REMOTE_DIR="/userdata"
SSH_KEY_PATH="${SSH_KEY_PATH:-}"
CLOUDPUB_VERSION="${CLOUDPUB_VERSION:-3.0.2}"

# SSH Command Construction
SSH_CMD="ssh"
if [ -n "$SSH_KEY_PATH" ]; then
    if [ ! -f "$SSH_KEY_PATH" ]; then
        echo "Error: SSH key not found at $SSH_KEY_PATH"
        exit 1
    fi
    SSH_CMD="ssh -i $SSH_KEY_PATH"
fi

echo "Installing CloudPub version $CLOUDPUB_VERSION on JetKVM at $JETKVM_IP"

# Download CloudPub
DOWNLOAD_URL="https://github.com/ermak-dev/cloudpub/releases/download/v$CLOUDPUB_VERSION/clo-${CLOUDPUB_VERSION}-linux-arm.tar.gz"
echo "Downloading from: $DOWNLOAD_URL"
curl -L -o cloudpub.tar.gz "$DOWNLOAD_URL"

if [ $? -ne 0 ]; then
    echo "Download failed"
    exit 1
fi

# Transfer to JetKVM
echo "Transferring to JetKVM..."
cat cloudpub.tar.gz | $SSH_CMD "$SSH_USER@$JETKVM_IP" "cat > $REMOTE_DIR/cloudpub.tar.gz"

# Transfer install script
echo "Transferring install script..."
cat install_on_device_cloudpub.sh | $SSH_CMD "$SSH_USER@$JETKVM_IP" "cat > $REMOTE_DIR/install_cloudpub.sh"

# Run install script
echo "Running installation on device..."
$SSH_CMD "$SSH_USER@$JETKVM_IP" "chmod +x $REMOTE_DIR/install_cloudpub.sh && $REMOTE_DIR/install_cloudpub.sh"

echo "Setup complete!"
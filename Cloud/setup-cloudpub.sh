#!/bin/bash

# Load configuration from .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Проверка обязательных параметров
if [ -z "$JETKVM_IP" ] || [ -z "$SSH_USER" ] || [ -z "$SSH_KEY_PATH" ] || [ -z "$LOCAL_FILE_PATH" ]; then
    echo "Error: Missing required variables in .env file"
    echo "Required: JETKVM_IP, SSH_USER, SSH_KEY_PATH, LOCAL_FILE_PATH"
    exit 1
fi

REMOTE_DIR="/userdata"

# SSH Command Construction
SSH_CMD="ssh"
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "Error: SSH key not found at $SSH_KEY_PATH"
    exit 1
fi
SSH_CMD="ssh -i $SSH_KEY_PATH"

echo "Installing CloudPub on JetKVM at $JETKVM_IP"
echo "Using local file: $LOCAL_FILE_PATH"

# Проверяем локальный файл
if [ ! -f "$LOCAL_FILE_PATH" ]; then
    echo "Error: Local file not found at $LOCAL_FILE_PATH"
    exit 1
fi

# Transfer file to JetKVM
echo "Transferring local file to JetKVM..."
cat "$LOCAL_FILE_PATH" | $SSH_CMD "$SSH_USER@$JETKVM_IP" "cat > $REMOTE_DIR/cloudpub.tar.gz"

# Transfer install script
echo "Transferring install script..."
cat install_on_device_cloudpub.sh | $SSH_CMD "$SSH_USER@$JETKVM_IP" "cat > $REMOTE_DIR/install_cloudpub.sh"

# Run install script
echo "Running installation on device..."
$SSH_CMD "$SSH_USER@$JETKVM_IP" "chmod +x $REMOTE_DIR/install_cloudpub.sh && $REMOTE_DIR/install_cloudpub.sh"

echo "Setup complete!"
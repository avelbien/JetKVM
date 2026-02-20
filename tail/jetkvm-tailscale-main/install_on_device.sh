#!/bin/sh
# This script is intended to be run ON the JetKVM device.

set -e

# Parse arguments
LOGIN_SERVER=""
AUTH_KEY=""
UPDATE_MODE=false

while [ "$#" -gt 0 ]; do
    case $1 in
        --login-server) LOGIN_SERVER="$2"; shift ;;
        --auth-key) AUTH_KEY="$2"; shift ;;
        --update) UPDATE_MODE=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

cd /userdata

# Stop existing service if running to allow binary update
echo "Stopping existing Tailscale service..."
if [ -x /etc/init.d/S22tailscale ]; then
    /etc/init.d/S22tailscale stop || true
else
    # Fallback if init script is missing (e.g. after OS update)
    killall tailscaled 2>/dev/null || true
fi

echo "Step 1: Handling Tailscale binaries..."
if [ -f tailscale.tar ]; then
    # Clean up previous installs
    if [ -d tailscale ]; then
        echo "Removing existing tailscale directory..."
        rm -rf tailscale
    fi

    echo "Extracting tailscale.tar..."
    tar xf tailscale.tar

    # Find the extracted directory (e.g., tailscale_1.90.9_arm)
    # We use shell expansion; assuming only one such directory exists after extraction
    EXTRACTED_DIR=$(ls -d tailscale_*_arm 2>/dev/null | head -n 1)

    if [ -n "$EXTRACTED_DIR" ] && [ -d "$EXTRACTED_DIR" ]; then
        echo "Renaming $EXTRACTED_DIR to tailscale..."
        mv "$EXTRACTED_DIR" tailscale
        rm tailscale.tar
    else
        echo "Error: Could not find extracted directory matching tailscale_*_arm"
        exit 1
    fi
else
    echo "tailscale.tar not found. Assuming binaries are already in place or transfer failed."
fi

echo "Step 2: Installing init script..."
if [ -f S22tailscale ]; then
    echo "Moving S22tailscale to /etc/init.d/..."
    mv S22tailscale /etc/init.d/S22tailscale
    chmod +x /etc/init.d/S22tailscale
else
    echo "Warning: S22tailscale source file not found in /userdata. It might already be installed."
fi

echo "Step 3: Starting Tailscale..."
if [ -x /etc/init.d/S22tailscale ]; then
    /etc/init.d/S22tailscale start
else
    echo "Error: Init script not executable or missing."
    exit 1
fi

# Wait for tailscaled to initialize
echo "Waiting for tailscaled to initialize..."
# First wait for socket
for i in $(seq 1 10); do
    if [ -S /var/run/tailscale/tailscaled.sock ]; then
        break
    fi
    sleep 1
done

# Then wait for status to be responsive and fully started
echo "Waiting for Tailscale to fully start..."
for i in $(seq 1 30); do
    if STATUS=$(/userdata/tailscale/tailscale status 2>&1); then
        # Command succeeded, check output for "starting" message
        if echo "$STATUS" | grep -q "Tailscale is starting"; then
             sleep 1
             continue
        fi
        break
    fi
    sleep 1
done

echo "Step 4: Tailscale Status"

if [ "$UPDATE_MODE" = true ]; then
    echo "Update mode enabled. Skipping authentication step."
    echo "Tailscale service has been restarted with the new binary/init script."
    echo "Current status:"
    /userdata/tailscale/tailscale status
else
    # Check if already connected to avoid re-using potentially expired auth keys
    if /userdata/tailscale/tailscale status > /dev/null 2>&1; then
        echo "Tailscale is already connected. Refreshing state..."
        /userdata/tailscale/tailscale up
    else
        echo "Tailscale not connected. Authenticating..."
        # Construct the up command with auth args
        UP_CMD="/userdata/tailscale/tailscale up"
        if [ -n "$LOGIN_SERVER" ]; then
            UP_CMD="$UP_CMD --login-server=$LOGIN_SERVER"
        fi
        if [ -n "$AUTH_KEY" ]; then
            UP_CMD="$UP_CMD --auth-key=$AUTH_KEY"
        fi

        echo "Running: $UP_CMD"
        $UP_CMD
    fi
fi
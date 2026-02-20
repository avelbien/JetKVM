#!/bin/sh
set -e

cd /userdata

echo "Step 1: Handling CloudPub binaries..."
if [ -f cloudpub.tar.gz ]; then
    if [ -d cloudpub ]; then
        echo "Removing existing cloudpub directory..."
        rm -rf cloudpub
    fi

    echo "Extracting cloudpub.tar.gz..."
    tar xzf cloudpub.tar.gz

    # Find extracted directory (clo-3.0.2-linux-arm)
    EXTRACTED_DIR=$(ls -d clo-* 2>/dev/null | head -n 1)

    if [ -n "$EXTRACTED_DIR" ] && [ -d "$EXTRACTED_DIR" ]; then
        echo "Renaming $EXTRACTED_DIR to cloudpub..."
        mv "$EXTRACTED_DIR" cloudpub
        rm cloudpub.tar.gz
    else
        echo "Error: Could not find extracted directory"
        exit 1
    fi
else
    echo "cloudpub.tar.gz not found"
    exit 1
fi

echo "Step 2: Making binary executable..."
chmod +x /userdata/cloudpub/clo

echo "Step 3: CloudPub installed successfully!"
echo ""
echo "Next steps:"
echo "1. Run: /userdata/cloudpub/clo login"
echo "2. Run: /userdata/cloudpub/clo publish http 80 --name jetkvm"
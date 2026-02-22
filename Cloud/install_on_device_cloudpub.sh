#!/bin/sh
set -e

cd /userdata

echo "Step 1: Preparing CloudPub installation..."

# Удаляем старую папку, если есть
if [ -d cloudpub ]; then
    echo "Removing existing cloudpub directory..."
    rm -rf cloudpub
fi

# Проверяем наличие архива
if [ ! -f cloudpub.tar.gz ]; then
    echo "Error: cloudpub.tar.gz not found"
    exit 1
fi

echo "Step 2: Extracting archive..."
tar xzf cloudpub.tar.gz

# Создаём папку cloudpub
mkdir -p cloudpub

# Вариант 1: если файлы в папке (clo-3.0.2-linux-arm)
if [ -d "clo-3.0.2-linux-arm" ]; then
    echo "Moving files from clo-3.0.2-linux-arm to cloudpub..."
    mv clo-3.0.2-linux-arm/* cloudpub/ 2>/dev/null
    rm -rf clo-3.0.2-linux-arm

# Вариант 2: если файлы лежат просто так (clo)
elif [ -f "clo" ]; then
    echo "Moving clo binary to cloudpub..."
    mv clo cloudpub/

# Вариант 3: ищем любой файл clo*
else
    CLO_FILE=$(ls clo* 2>/dev/null | head -n 1)
    if [ -n "$CLO_FILE" ]; then
        echo "Moving $CLO_FILE to cloudpub..."
        mv "$CLO_FILE" cloudpub/clo
    else
        echo "Error: Could not find clo binary"
        exit 1
    fi
fi

# Делаем исполняемым
chmod +x /userdata/cloudpub/clo

# Удаляем архив
rm -f cloudpub.tar.gz

echo "Step 3: CloudPub installed successfully in /userdata/cloudpub/clo"
echo ""
echo "Next steps:"
echo "1. Run: /userdata/cloudpub/clo login"
echo "2. Run: /userdata/cloudpub/clo publish http 80 --name jetkvm"
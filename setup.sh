#!/bin/bash

set -e

FOLDER_NAME="${1:-}"
SHOULD_BUILD="${2:-false}"

START_DIR="$(pwd)"
TEMPLATE_DIR="$START_DIR/vscode"

# Get folder name as input
if [ -z "$FOLDER_NAME" ]; then
    read -p "Enter folder name: " folder_name
else
    folder_name="$FOLDER_NAME"
fi

# Create folder if it doesn't exist
mkdir -p "$folder_name"


echo "Cloning linux-mainline..."
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git ${folder_name}

echo "Applying VS Code configuration..."
cp -r "$TEMPLATE_DIR" "$folder_name/.vscode"

cd ${folder_name}
echo "Adding linux-next..."
git remote add linux-next https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git

echo "Fetching linux-next..."
git fetch linux-next

if [ "$SHOULD_BUILD" = "true" ] || [ "$SHOULD_BUILD" = "1" ]; then
    echo "Starting initial Clang build..."
    if [ -f ".vscode/tasks.sh" ]; then
        chmod +x .vscode/tasks.sh
        ./.vscode/tasks.sh configure-clang
        ./.vscode/tasks.sh build-clang
    else
        echo "Error: .vscode/tasks.sh not found inside $FOLDER_NAME"
        exit 1
    fi
fi

echo "Done! Kernel source ready in $FOLDER_NAME"
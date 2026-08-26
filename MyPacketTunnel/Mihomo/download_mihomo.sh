#!/bin/bash

# Script to download Mihomo binary for macOS
# This script downloads the latest Mihomo (Clash.Meta) release for macOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"

echo "Downloading Mihomo binary..."

# Get the latest release from GitHub
LATEST_RELEASE=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_RELEASE" ]; then
    echo "Failed to get latest release version"
    exit 1
fi

echo "Latest version: $LATEST_RELEASE"

# Determine architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    FILENAME="mihomo-darwin-arm64-${LATEST_RELEASE}.gz"
    OUTPUT_NAME="mihomo-darwin"
elif [ "$ARCH" = "x86_64" ]; then
    FILENAME="mihomo-darwin-amd64-${LATEST_RELEASE}.gz"
    OUTPUT_NAME="mihomo-darwin"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/download/${LATEST_RELEASE}/${FILENAME}"

echo "Downloading from: $DOWNLOAD_URL"

# Download and extract
curl -L -o "${OUTPUT_DIR}/${FILENAME}" "$DOWNLOAD_URL"
gunzip -f "${OUTPUT_DIR}/${FILENAME}"

# Rename to standard name
mv "${OUTPUT_DIR}/${FILENAME%.gz}" "${OUTPUT_DIR}/${OUTPUT_NAME}"

# Make executable
chmod +x "${OUTPUT_DIR}/${OUTPUT_NAME}"

echo "Mihomo binary downloaded successfully to: ${OUTPUT_DIR}/${OUTPUT_NAME}"
echo "Version: $LATEST_RELEASE"

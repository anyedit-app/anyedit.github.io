#!/bin/bash

# Check if target path is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <target_path>"
    exit 1
fi

TARGET_PATH="$1"
TARGET_DIR=$(dirname "$TARGET_PATH")

# Check for required Python packages
echo "Checking Python dependencies..."
pip3 install --quiet torch transformers coremltools

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Convert model using our Python script
echo "Converting Phi-2 to CoreML format..."
SCRIPT_DIR="$(dirname "$0")"
python3 "$SCRIPT_DIR/convert_model.py" "$TARGET_PATH"

# Verify conversion was successful
if [ -d "$TARGET_PATH" ]; then
    echo "Model converted successfully to $TARGET_PATH"
    exit 0
else
    echo "Error: Model conversion failed"
    exit 1
fi 
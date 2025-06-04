#!/bin/bash

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."

# Source model path
SOURCE_MODEL="$PROJECT_ROOT/Resources/StyleTransferModel.mlmodel"

# Destination for compiled model
COMPILED_DIR="$PROJECT_ROOT/Resources"

# Check if source model exists
if [ ! -f "$SOURCE_MODEL" ]; then
    echo "Error: Source model not found at $SOURCE_MODEL"
    exit 1
fi

# Compile the model
echo "Compiling model..."
xcrun coremlcompiler compile "$SOURCE_MODEL" "$COMPILED_DIR"

if [ $? -eq 0 ]; then
    echo "Model compiled successfully"
    echo "Compiled model is at: $COMPILED_DIR/StyleTransferModel.mlmodelc"
else
    echo "Error: Failed to compile model"
    exit 1
fi 
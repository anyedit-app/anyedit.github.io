#!/bin/bash

# Create models directory if it doesn't exist
mkdir -p ../Models/MLModels

# Download the style transfer model from Apple's sample
curl -L "https://developer.apple.com/machine-learning/models/Style-Transfer/StyleTransfer.mlmodel" -o "../Models/MLModels/StyleTransferModel.mlmodel"

# Compile the model
xcrun coremlcompiler compile "../Models/MLModels/StyleTransferModel.mlmodel" "../Models/MLModels" 
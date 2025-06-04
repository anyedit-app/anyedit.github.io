# AI Models Directory

This directory should contain your Core ML models (.mlmodel files). For the style transfer effect, you need to add a model named `StyleTransferModel.mlmodel`.

## Creating a Style Transfer Model

1. Open Create ML app on your Mac
2. Create a new Style Transfer project
3. Configure training data:
   - Style Image: Choose an artistic image (e.g., a painting) that defines the style
   - Content Images: Use a diverse set of natural images (Create ML can download these automatically)
4. Configure settings:
   - Optimize for: Video (for real-time processing)
   - Training iterations: 400-600 for good quality
   - Style strength: 0.8 (default)
   - Style density: 1.0 (default)
5. Train the model
6. Export as `StyleTransferModel.mlmodel`
7. Place in this directory

## Quick Start

For immediate testing, you can:

1. Download a pre-trained style transfer model from Apple's Create ML gallery
2. Rename it to `StyleTransferModel.mlmodel`
3. Place it in this directory

## Model Requirements

- Input: RGB image (any size, will be resized internally)
- Output: Styled RGB image
- Optimized for real-time video processing
- File size: Typically 20-50MB depending on configuration

#!/bin/bash
# Script to generate PNG favicons from SVG
# Requires: ImageMagick or Inkscape

SVG_FILE="public/icon.svg"
OUTPUT_DIR="public"

echo "Generating favicons from $SVG_FILE..."

# Check if ImageMagick is available
if command -v convert &> /dev/null; then
    echo "Using ImageMagick..."
    convert -background none "$SVG_FILE" -resize 16x16 "${OUTPUT_DIR}/favicon-16x16.png"
    convert -background none "$SVG_FILE" -resize 32x32 "${OUTPUT_DIR}/favicon-32x32.png"
    convert -background none "$SVG_FILE" -resize 48x48 "${OUTPUT_DIR}/favicon-48x48.png"
    convert -background none "$SVG_FILE" -resize 64x64 "${OUTPUT_DIR}/icon.png"
    convert -background none "$SVG_FILE" -resize 180x180 "${OUTPUT_DIR}/apple-touch-icon.png"
    echo "✅ PNG favicons generated successfully!"
elif command -v inkscape &> /dev/null; then
    echo "Using Inkscape..."
    inkscape "$SVG_FILE" --export-filename="${OUTPUT_DIR}/favicon-16x16.png" -w 16 -h 16
    inkscape "$SVG_FILE" --export-filename="${OUTPUT_DIR}/favicon-32x32.png" -w 32 -h 32
    inkscape "$SVG_FILE" --export-filename="${OUTPUT_DIR}/favicon-48x48.png" -w 48 -h 48
    inkscape "$SVG_FILE" --export-filename="${OUTPUT_DIR}/icon.png" -w 64 -h 64
    inkscape "$SVG_FILE" --export-filename="${OUTPUT_DIR}/apple-touch-icon.png" -w 180 -h 180
    echo "✅ PNG favicons generated successfully!"
else
    echo "❌ Error: Neither ImageMagick nor Inkscape found."
    echo "Please install one of them:"
    echo "  - ImageMagick: brew install imagemagick (macOS) or apt-get install imagemagick (Linux)"
    echo "  - Inkscape: brew install inkscape (macOS) or apt-get install inkscape (Linux)"
    echo ""
    echo "Alternatively, you can use online tools to convert SVG to PNG:"
    echo "  - https://cloudconvert.com/svg-to-png"
    echo "  - https://convertio.co/svg-png/"
    exit 1
fi


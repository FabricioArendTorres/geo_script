#!/bin/bash
# Description:
# This script processes a GeoPackage (.gpkg) file by rasterizing its polygons
# into a single-band GeoTIFF using values from the "class_id" property. The
# output GeoTIFF is compressed using ZSTD, applies a horizontal predictor
# (PREDICTOR=2), and enables tiling (TILED=YES). The EPSG code of the input
# is either detected automatically or provided manually as an optional argument.
# The output is saved to a specified target directory.

# Dependencies:
# - GDAL: Requires GDAL installed with access to the commands `gdal_rasterize`,
#   `gdal_translate`, and `ogrinfo`. Make sure GDAL is included in your PATH.

# Usage:
# ./script.sh <input_geopackage_path> <target_directory> [optional_epsg_code]
# - <input_geopackage_path>: Path to the input .gpkg file.
# - <target_directory>: Directory where the output file will be saved.
# - [optional_epsg_code]: EPSG code for the input data. If not provided, the
#   script will attempt to detect the EPSG code automatically.

# Example:
# 1. Automatic EPSG detection:
#    ./script.sh example.gpkg /path/to/output/
# 2. Manual EPSG specification:
#    ./script.sh example.gpkg /path/to/output/ 4326

# Exit on any error and handle Ctrl+C
set -e
trap "echo 'Script interrupted'; exit 1" SIGINT

# Check for input arguments
if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo "Usage: $0 <input_geopackage_path> <target_directory> [optional_epsg_code]"
    exit 1
fi

# Input file and validation
INPUT_PATH="$1"
if [[ ! -f "$INPUT_PATH" ]]; then
    echo "Error: Input file does not exist."
    exit 1
fi

# Target directory validation
TARGET_DIR="$2"
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: Target directory does not exist."
    exit 1
fi

# Optional CRS input
if [[ -n "$3" ]]; then
    CRS="$3"
    echo "Using provided EPSG code: EPSG:$CRS"
else
    # Attempt to detect CRS from the input file
    CRS=$(ogrinfo -so "$INPUT_PATH" | grep "EPSG:" | head -n 1 | awk '{print $NF}')
    if [[ -z "$CRS" ]]; then
        echo "Error: Unable to determine CRS from input file, and no EPSG code was provided."
        exit 1
    fi
    echo "Detected CRS: EPSG:$CRS"
fi

# Extract base name and build output paths
BASENAME=$(basename "$INPUT_PATH" .gpkg)
TEMP_PATH="/tmp/${BASENAME}_temp.tif"
OUTPUT_PATH="${TARGET_DIR}/${BASENAME}_compressed.tif"

# Define rasterization and compression commands
echo "Rasterizing $INPUT_PATH to temporary file $TEMP_PATH..."
gdal_rasterize -a class_id -tr 0.25 0.25 -ot Byte -a_nodata 0 -a_srs "EPSG:$CRS" -of GTiff "$INPUT_PATH" "$TEMP_PATH"

echo "Compressing temporary file $TEMP_PATH to output file $OUTPUT_PATH..."
gdal_translate -co COMPRESS=ZSTD -co PREDICTOR=2 -co TILED=YES -co BLOCKXSIZE=1024 -co BLOCKYSIZE=1024 "$TEMP_PATH" "$OUTPUT_PATH"

# Cleanup temporary file
echo "Cleaning up temporary files..."
rm -f "$TEMP_PATH"


echo "Output file created: $OUTPUT_PATH"
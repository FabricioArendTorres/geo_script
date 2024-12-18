#!/bin/bash
# Description:
# This script processes all GeoPackage (.gpkg) files in a specified directory
# using the compress_geopackage_to_geotiff.sh script in parallel using `xargs`.
# It then mosaics the resulting GeoTIFFs into a single raster and applies final
# compression with ZSTD, a horizontal predictor (PREDICTOR=2), and tiling
# (TILED=YES). The default value for areas without data is set to 0.

# Dependencies:
# - GDAL: Requires GDAL installed with `gdal_translate`, `gdal_merge.py`, and `compress_geopackage_to_geotiff.sh` available.
# - compress_geopackage_to_geotiff.sh: Script to process individual .gpkg files.

# Usage:
# ./process_and_mosaic_xargs.sh <input_directory> <output_directory> <output_filename> [optional_epsg_code] [num_parallel_processes]
# - <input_directory>: Directory containing input .gpkg files.
# - <output_directory>: Directory where intermediate and final output files will be saved.
# - <output_filename>: Name of the final mosaicked GeoTIFF file.
# - [optional_epsg_code]: EPSG code for all input data. If not provided, each .gpkg file's CRS is detected automatically.
# - [num_parallel_processes]: Number of parallel processes (default: 1).

# Example:
# ./process_and_mosaic_xargs.sh /path/to/gpkg /path/to/output mosaicked.tif 4326 4

set -e
trap "echo 'Script interrupted'; exit 1" SIGINT

# Check input arguments
if [[ $# -lt 3 || $# -gt 5 ]]; then
    echo "Usage: $0 <input_directory> <output_directory> <output_filename> [optional_epsg_code] [num_parallel_processes]"
    exit 1
fi

# Input arguments
INPUT_DIR="$1"
OUTPUT_DIR="$2"
OUTPUT_FILENAME="$3"
EPSG_CODE="$4" # Optional EPSG code
NUM_PROCESSES="${5:-1}" # Default to 1 process if not provided

# Validate directories
if [[ ! -d "$INPUT_DIR" ]]; then
    echo "Error: Input directory does not exist."
    exit 1
fi
if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "Error: Output directory does not exist."
    exit 1
fi

# Temporary directory for intermediate GeoTIFFs
TEMP_DIR="$OUTPUT_DIR/temp"
mkdir -p "$TEMP_DIR"

# Process each GeoPackage in the input directory in parallel with xargs
echo "Processing GeoPackages in $INPUT_DIR with $NUM_PROCESSES parallel processes..."
find "$INPUT_DIR" -name "*.gpkg" | xargs -P "$NUM_PROCESSES" -I {} compress_geopackage_to_geotiff.sh {} "$TEMP_DIR" "$EPSG_CODE"

# Mosaic all GeoTIFFs
MOSAIC_OUTPUT="$OUTPUT_DIR/$OUTPUT_FILENAME"
echo "Mosaicking all GeoTIFFs to $MOSAIC_OUTPUT..."
gdal_merge.py -o "$MOSAIC_OUTPUT" -a_nodata 0 "$TEMP_DIR"/*.tif

# Apply final compression
FINAL_OUTPUT="${MOSAIC_OUTPUT%.tif}_compressed.tif"
echo "Applying final compression to $FINAL_OUTPUT..."
gdal_translate -co COMPRESS=ZSTD -co PREDICTOR=2 -co TILED=YES -co BLOCKXSIZE=1024 -co BLOCKYSIZE=1024 "$MOSAIC_OUTPUT" "$FINAL_OUTPUT"

# Cleanup intermediate files
echo "Cleaning up temporary files..."
rm -rf "$TEMP_DIR" "$MOSAIC_OUTPUT"

# Success message
echo "Final output created: $FINAL_OUTPUT"
#!/bin/bash
# Description:
# Script to burn in the *.tfw data into the *.tif files for all files within the current directory.
#
# Transform all "*.tif" files in the current directory with gdal_translate, so that the correspond"*.tfw"
# The important bit is the command 
# 'gdal_translate -q "$input_file" "$temp_output_file"'
# This does not transform the content of the geotif, but just writes the original file with additional metadata obtained from the corresponding *.tfw file.
# Rest of the script is just error handling and parallelizing the transformation using find and xargs.

# Exit immediately if a command exits with a non-zero status
set -e

# Check if gdal_translate is installed
if ! command -v gdal_translate &> /dev/null; then
  echo "Error: gdal_translate is not installed or not in PATH."
  exit 1
fi

# Function to compress a single file
compress_file() {
  input_file="$1"
  temp_output_file="${input_file%.tif}_compressed.tif"

  # Suppress gdal_translate output
  #gdal_translate -q -co COMPRESS=ZSTD -co PREDICTOR=2 -co TILED=YES -co BLOCKXSIZE=256 -co BLOCKYSIZE=256 -co ZSTD_LEVEL=15 "$input_file" "$temp_output_file"
  gdal_translate -q -co TILED=YES -co BLOCKXSIZE=256 -co BLOCKYSIZE=256 "$input_file" "$temp_output_file"

  if [ $? -eq 0 ]; then
    chmod --reference="$input_file" "$temp_output_file"
    mv "$temp_output_file" "$input_file"
    echo "Compression successful for $input_file"
  else
    echo "Error: gdal_translate command failed for $input_file" >&2
    rm -f "$temp_output_file"
  fi

}

export -f compress_file

# Handle interrupts to clean up child processes
trap 'echo "Interrupt received. Terminating..."; exit 1' INT TERM

# Check if the user provided the number of processes
if [ -z "$1" ]; then
  echo "Usage: $0 <number_of_processes>"
  exit 1
fi

# Get the number of processes from the command line argument
NUM_PROCESSES=$1

# Check if the number of processes is a valid positive integer
if ! [[ "$NUM_PROCESSES" =~ ^[0-9]+$ ]] || [ "$NUM_PROCESSES" -le 0 ]; then
  echo "Error: Number of processes must be a positive integer."
  exit 1
fi

# Find all .tif files excluding those with extensions like .tif.*
TIF_FILES=$(find . -type f -name "*.tif" ! -name "*.tif.*")

# Count the total number of files to process
TOTAL_FILES=$(echo "$TIF_FILES" | wc -l)
PROCESSED_COUNT=0

echo "Total number of files to process: $TOTAL_FILES"

# Export the variables
export TOTAL_FILES PROCESSED_COUNT

# Use xargs to process the files in parallel
echo "$TIF_FILES" | xargs -n 1 -P "$NUM_PROCESSES" -I {} bash -c 'compress_file "{}"'

echo "Compression process completed."
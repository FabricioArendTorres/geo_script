#!/bin/bash

# Downloads files in parallel using wget with resume support.
# Logs missing files and ensures per-job logging for clarity.
# Usage: ./parallel_wget.sh <file_with_urls.txt>

#module load parallel

set -e  # Exit on unhandled errors
set -o pipefail  # Fail if part of a pipeline fails
trap "echo -e '\nDownload interrupted. Cleaning up...'; exit 1" INT TERM

# Input Arguments
URL_FILE="$1"
if [[ -z "$URL_FILE" || ! -f "$URL_FILE" ]]; then
    echo "Error: Input file does not exist or was not specified."
    echo "Usage: $0 <file_with_urls.txt>"
    exit 1
fi

# Derive unique filenames based on input file
BASENAME=$(basename "$URL_FILE" .txt)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="${BASENAME}_downloads"
GLOBAL_LOG_DIR="${BASENAME}_logs_${TIMESTAMP}"
MISSING_FILE_LOG="${GLOBAL_LOG_DIR}/missing_files.txt"
PARALLEL_JOBS=20

# Ensure directories exist
mkdir -p "$OUTPUT_DIR" "$GLOBAL_LOG_DIR"

# Notify Start
echo "Starting parallel downloads from '$URL_FILE'."
echo "Logs are in '$GLOBAL_LOG_DIR'. Missing files: $MISSING_FILE_LOG"

# Function to download a single URL with its own log file
download_with_wget() {
    local url="$1"
    local filename=$(basename "$url")
    local logfile="${GLOBAL_LOG_DIR}/${filename}.log"

    wget -c -P "$OUTPUT_DIR" "$url" &> "$logfile"
    if [[ $? -ne 0 ]]; then
        echo "$url" >> "$MISSING_FILE_LOG"
    fi
}

export -f download_with_wget  # Export function for parallel
export OUTPUT_DIR GLOBAL_LOG_DIR MISSING_FILE_LOG

# Run downloads in parallel with job tracking
parallel --joblog "${GLOBAL_LOG_DIR}/joblog.txt" -j "$PARALLEL_JOBS" download_with_wget :::: "$URL_FILE"

echo "Downloads completed. Check logs in '$GLOBAL_LOG_DIR'."
echo "Missing files (if any): $MISSING_FILE_LOG"
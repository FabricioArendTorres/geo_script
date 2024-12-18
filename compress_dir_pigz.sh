#!/bin/bash

# parallel compression of files using pigz.


# module load pigz/2.7-GCCcore-11.3.0


# Exit immediately if a command exits with a non-zero status
set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

DIRECTORY="$1"
BASENAME="$(basename "$DIRECTORY")"
NUMCPUS=10

tar cf - "$DIRECTORY" | pigz -p ${NUMCPUS} > "${BASENAME}.tar.gz"
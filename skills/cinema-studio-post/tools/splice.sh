#!/bin/bash
# splice.sh — extract a time range as a new clip
# Usage: splice.sh <input.mp4> <output.mp4> <START-END>
set -e
INPUT=$1; OUTPUT=$2; RANGE=$3
[ -z "$RANGE" ] && { echo "Usage: splice.sh <input> <output> <START-END>"; exit 1; }
S=${RANGE%-*}; E=${RANGE#*-}
DUR=$(python3 -c "print(${E}-${S})")
ffmpeg -y -ss "$S" -i "$INPUT" -t "$DUR" -c copy "$OUTPUT"
echo "Spliced -> $OUTPUT (duration ${DUR}s)"

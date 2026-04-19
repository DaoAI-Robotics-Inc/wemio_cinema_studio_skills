#!/bin/bash
# mute.sh — silence audio in a time range, keep video intact
# Usage: mute.sh <input.mp4> <output.mp4> <START-END>
set -e
INPUT=$1; OUTPUT=$2; RANGE=$3
[ -z "$RANGE" ] && { echo "Usage: mute.sh <input> <output> <START-END>"; exit 1; }
S=${RANGE%-*}; E=${RANGE#*-}
ffmpeg -y -i "$INPUT" -af "volume=enable='between(t,${S},${E})':volume=0" -c:v copy "$OUTPUT"
echo "Muted ${S}-${E}s -> $OUTPUT"

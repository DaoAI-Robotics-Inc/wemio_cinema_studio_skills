#!/bin/bash
# crossfade.sh — crossfade from clipA into clipB over N seconds
# Usage: crossfade.sh <clipA.mp4> <clipB.mp4> <output.mp4> <duration_s>
set -e
A=$1; B=$2; OUT=$3; D=$4
[ -z "$D" ] && { echo "Usage: crossfade.sh <A> <B> <output> <duration_s>"; exit 1; }
DUR_A=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$A")
OFFSET=$(python3 -c "print(${DUR_A}-${D})")
ffmpeg -y -i "$A" -i "$B" \
  -filter_complex "[0:v][1:v]xfade=transition=fade:duration=${D}:offset=${OFFSET}[v]; \
                   [0:a][1:a]acrossfade=d=${D}[a]" \
  -map "[v]" -map "[a]" "$OUT"
echo "Crossfaded -> $OUT"

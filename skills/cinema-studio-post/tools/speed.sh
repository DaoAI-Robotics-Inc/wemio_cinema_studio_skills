#!/bin/bash
# speed.sh — change playback speed, optionally on a time range
# Usage: speed.sh <input.mp4> <output.mp4> <rate> [<START-END>]
# rate > 1.0 = faster; < 1.0 = slower
set -e
INPUT=$1; OUTPUT=$2; RATE=$3; RANGE=$4

if [ -z "$RATE" ]; then
  echo "Usage: speed.sh <input> <output> <rate> [<START-END>]"
  exit 1
fi

if [ -z "$RANGE" ]; then
  # Whole clip speed change
  INV=$(python3 -c "print(1/${RATE})")
  ffmpeg -y -i "$INPUT" \
    -filter_complex "[0:v]setpts=${INV}*PTS[v];[0:a]atempo=${RATE}[a]" \
    -map "[v]" -map "[a]" "$OUTPUT"
else
  # Speed change applied only to range [S,E]
  S=${RANGE%-*}; E=${RANGE#*-}
  INV=$(python3 -c "print(1/${RATE})")
  ffmpeg -y -i "$INPUT" -filter_complex "
    [0:v]trim=0:${S},setpts=PTS-STARTPTS[v0];
    [0:v]trim=${S}:${E},setpts=${INV}*(PTS-STARTPTS)[v1];
    [0:v]trim=start=${E},setpts=PTS-STARTPTS[v2];
    [0:a]atrim=0:${S},asetpts=PTS-STARTPTS[a0];
    [0:a]atrim=${S}:${E},asetpts=PTS-STARTPTS,atempo=${RATE}[a1];
    [0:a]atrim=start=${E},asetpts=PTS-STARTPTS[a2];
    [v0][a0][v1][a1][v2][a2]concat=n=3:v=1:a=1[vout][aout]" \
    -map "[vout]" -map "[aout]" "$OUTPUT"
fi
echo "Speed-adjusted -> $OUTPUT"

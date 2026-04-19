#!/bin/bash
# freeze.sh — hold a specific frame for N seconds in place
# Usage: freeze.sh <input.mp4> <output.mp4> <timestamp_s> <hold_s>
set -e
INPUT=$1; OUTPUT=$2; TS=$3; HOLD=$4
[ -z "$HOLD" ] && { echo "Usage: freeze.sh <input> <output> <timestamp_s> <hold_s>"; exit 1; }

# Extract the freeze frame
FRAME=/tmp/.freeze_frame_$$.png
ffmpeg -y -ss "$TS" -i "$INPUT" -frames:v 1 "$FRAME"

# Build: up to TS + frozen frame for HOLD + from TS onward
ffmpeg -y -i "$INPUT" -loop 1 -t "$HOLD" -i "$FRAME" \
  -filter_complex "
    [0:v]trim=0:${TS},setpts=PTS-STARTPTS[v0];
    [1:v]fps=30,setpts=PTS-STARTPTS[v1];
    [0:v]trim=start=${TS},setpts=PTS-STARTPTS[v2];
    [v0][v1][v2]concat=n=3:v=1[vout];
    [0:a]atrim=0:${TS},asetpts=PTS-STARTPTS[a0];
    [0:a]atrim=start=${TS},asetpts=PTS-STARTPTS,adelay=${HOLD}s|${HOLD}s[a2];
    anullsrc=r=44100:cl=stereo,atrim=0:${HOLD}[a1];
    [a0][a1][a2]concat=n=3:v=0:a=1[aout]" \
  -map "[vout]" -map "[aout]" "$OUTPUT"
rm -f "$FRAME"
echo "Froze frame at ${TS}s for ${HOLD}s -> $OUTPUT"

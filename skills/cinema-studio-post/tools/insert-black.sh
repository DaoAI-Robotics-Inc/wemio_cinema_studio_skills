#!/bin/bash
# insert-black.sh — insert black frames at a timestamp
# Usage: insert-black.sh <input.mp4> <output.mp4> <timestamp_s> <duration_s>
set -e
INPUT=$1; OUTPUT=$2; TS=$3; DUR=$4
[ -z "$DUR" ] && { echo "Usage: insert-black.sh <input> <output> <timestamp_s> <duration_s>"; exit 1; }

# Get size/fps of input for matching
WH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$INPUT")
FPS=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$INPUT")

ffmpeg -y -i "$INPUT" -f lavfi -i "color=c=black:s=${WH}:r=${FPS}:d=${DUR}" -f lavfi -i "anullsrc=r=44100:cl=stereo:d=${DUR}" \
  -filter_complex "
    [0:v]trim=0:${TS},setpts=PTS-STARTPTS[v0];
    [1:v]setpts=PTS-STARTPTS[v1];
    [0:v]trim=start=${TS},setpts=PTS-STARTPTS[v2];
    [v0][v1][v2]concat=n=3:v=1[vout];
    [0:a]atrim=0:${TS},asetpts=PTS-STARTPTS[a0];
    [2:a]asetpts=PTS-STARTPTS[a1];
    [0:a]atrim=start=${TS},asetpts=PTS-STARTPTS[a2];
    [a0][a1][a2]concat=n=3:v=0:a=1[aout]" \
  -map "[vout]" -map "[aout]" "$OUTPUT"
echo "Inserted ${DUR}s black at ${TS}s -> $OUTPUT"

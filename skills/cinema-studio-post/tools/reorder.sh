#!/bin/bash
# reorder.sh — concat multiple clips in the exact order given
# Usage: reorder.sh <output.mp4> <clip1.mp4> <clip2.mp4> ...
set -e
OUT=$1; shift
[ -z "$OUT" ] && { echo "Usage: reorder.sh <output> <clip1> <clip2> ..."; exit 1; }

LIST=/tmp/.reorder_list_$$.txt
> "$LIST"
for C in "$@"; do echo "file '$C'" >> "$LIST"; done
ffmpeg -y -f concat -safe 0 -i "$LIST" -c copy "$OUT"
rm -f "$LIST"
echo "Reordered $# clips -> $OUT"

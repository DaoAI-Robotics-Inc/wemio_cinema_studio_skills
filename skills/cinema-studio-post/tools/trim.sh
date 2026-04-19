#!/bin/bash
# trim.sh — remove one or more time ranges from a video, stitch remainder
# Usage: trim.sh <input.mp4> <output.mp4> <range1> [<range2> ...]
# Range format: START-END in seconds (e.g. "7.3-9.1")

set -e
INPUT=$1
OUTPUT=$2
shift 2

if [ -z "$INPUT" ] || [ -z "$OUTPUT" ] || [ $# -eq 0 ]; then
  echo "Usage: trim.sh <input.mp4> <output.mp4> <range1> [<range2> ...]"
  echo "  Range format: START-END in seconds"
  exit 1
fi

# Get duration
DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT")

# Build list of KEEP ranges (complement of cut ranges)
python3 - "$DUR" "$@" <<'PY' > /tmp/.trim_keep_$$.txt
import sys
dur = float(sys.argv[1])
cuts = []
for r in sys.argv[2:]:
    s, e = r.split("-")
    cuts.append((float(s), float(e)))
cuts.sort()
keep = []
cursor = 0.0
for s, e in cuts:
    if s > cursor:
        keep.append((cursor, s))
    cursor = max(cursor, e)
if cursor < dur:
    keep.append((cursor, dur))
for s, e in keep:
    print(f"{s:.3f} {e:.3f}")
PY

# Build filter_complex segments
FILTER=""
SEGS=""
I=0
while read S E; do
  FILTER+="[0:v]trim=start=${S}:end=${E},setpts=PTS-STARTPTS[v${I}];"
  FILTER+="[0:a]atrim=start=${S}:end=${E},asetpts=PTS-STARTPTS[a${I}];"
  SEGS+="[v${I}][a${I}]"
  I=$((I+1))
done < /tmp/.trim_keep_$$.txt

if [ $I -eq 0 ]; then
  echo "No keep ranges — input would be entirely cut"
  exit 1
fi

FILTER+="${SEGS}concat=n=${I}:v=1:a=1[vout][aout]"

ffmpeg -y -i "$INPUT" -filter_complex "$FILTER" -map "[vout]" -map "[aout]" "$OUTPUT"
rm -f /tmp/.trim_keep_$$.txt
echo "Trimmed -> $OUTPUT"
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT"

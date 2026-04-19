#!/bin/bash
# Upload an mp4 to Gemini Files API, wait for ACTIVE, print file_uri
# Usage: upload_video.sh <local_mp4_or_url> [display_name]
set -e
SRC=$1
DISPLAY=${2:-video_$(date +%s)}

# If URL, download first
if [[ "$SRC" == http* ]]; then
  TMP="/tmp/.qa_download_$$.mp4"
  curl -sL "$SRC" -o "$TMP"
  VIDEO=$TMP
else
  VIDEO=$SRC
fi

if [ -n "$GEMINI_API_KEY" ]; then
  KEY="$GEMINI_API_KEY"
else
  KEY_FILE="${WEMIO_KEY_FILE:-./.key}"
  if [ ! -f "$KEY_FILE" ]; then
    KEY_FILE="$(dirname "$0")/../../script-to-video-kling/.key"
  fi
  KEY=$(grep "^gemini:" "$KEY_FILE" | cut -d' ' -f2)
fi

SIZE=$(stat -f%z "$VIDEO" 2>/dev/null || stat -c%s "$VIDEO")

HDR_FILE="/tmp/.qa_upload_h_$$_${RANDOM}.txt"

# Start resumable
curl -s -D "$HDR_FILE" -o /dev/null \
  -X POST "https://generativelanguage.googleapis.com/upload/v1beta/files?key=${KEY}" \
  -H "X-Goog-Upload-Protocol: resumable" \
  -H "X-Goog-Upload-Command: start" \
  -H "X-Goog-Upload-Header-Content-Length: ${SIZE}" \
  -H "X-Goog-Upload-Header-Content-Type: video/mp4" \
  -H "Content-Type: application/json" \
  -d "{\"file\":{\"display_name\":\"${DISPLAY}\"}}"

UPLOAD_URL=$(grep -i "X-Goog-Upload-URL:" "$HDR_FILE" | cut -d' ' -f2 | tr -d '\r')
rm -f "$HDR_FILE"

# Upload bytes
RESP=$(curl -s -X POST "$UPLOAD_URL" \
  -H "Content-Length: ${SIZE}" \
  -H "X-Goog-Upload-Offset: 0" \
  -H "X-Goog-Upload-Command: upload, finalize" \
  --data-binary "@${VIDEO}")

FILE_NAME=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['file']['name'])")
FILE_URI=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['file']['uri'])")

# Wait for ACTIVE
for i in $(seq 1 20); do
  sleep 3
  STATE=$(curl -s "https://generativelanguage.googleapis.com/v1beta/${FILE_NAME}?key=${KEY}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('state','?'))")
  if [ "$STATE" = "ACTIVE" ]; then
    echo "$FILE_URI"
    [ -n "$TMP" ] && rm -f "$TMP"
    exit 0
  fi
done

echo "{\"error\":\"upload timeout, final state: $STATE\"}" >&2
exit 1

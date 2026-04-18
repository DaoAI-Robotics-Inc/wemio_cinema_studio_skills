#!/bin/bash
# Gemini 3.1 Pro — analyze scene reference image(s), return structured spatial blueprint.
# The blueprint is consumed by Claude when writing clip prompts, so physical
# geometry / exits / light direction / surface come from the actual ref image
# instead of Claude's imagination.
#
# Usage: scene_blueprint.sh <image_url_or_path> [hint_text]
#   <image_url_or_path>  URL (http/https) or local path to scene reference image
#   [hint_text]          optional, e.g. "subway platform, 00:15 last train, noir"
#
# Output: JSON { scene_id, camera_framing, left, right, foreground, background,
#                light, surface, entry_exits, usable_paths, blocked_paths,
#                props_present, notes, _usage }
#
# Cost: ~$0.005 per scene (single 2K image ≈ 500 prompt tokens).
#
# Auth: GEMINI_API_KEY env, or gemini: AIza... line from .key file.

set -e
SRC=$1
HINT=${2:-}

if [ -z "$SRC" ]; then
  echo '{"error":"usage: scene_blueprint.sh <image_url_or_path> [hint]"}' >&2
  exit 1
fi

if [ -n "$GEMINI_API_KEY" ]; then
  KEY="$GEMINI_API_KEY"
else
  for KF in "${WEMIO_KEY_FILE:-.key}" "./.key" "$(dirname "$0")/../.key" "$(dirname "$0")/../../script-to-video-kling/.key"; do
    if [ -f "$KF" ]; then
      KEY=$(grep "^gemini:" "$KF" | cut -d' ' -f2)
      [ -n "$KEY" ] && break
    fi
  done
fi

if [ -z "$KEY" ]; then
  echo '{"error":"no Gemini API key; set GEMINI_API_KEY or add `gemini: AIza...` to .key file"}' >&2
  exit 1
fi

# Download if URL
TMP=""
if [[ "$SRC" == http* ]]; then
  EXT=$(echo "$SRC" | sed -E 's/.*\.([a-zA-Z0-9]+)(\?.*)?$/\1/')
  [ -z "$EXT" ] && EXT="png"
  TMP="/tmp/.qa_scene_$$.${EXT}"
  curl -sL "$SRC" -o "$TMP"
  IMG="$TMP"
else
  IMG="$SRC"
fi

# Detect mime
case "$IMG" in
  *.jpg|*.jpeg) MIME="image/jpeg" ;;
  *.png)        MIME="image/png"  ;;
  *.webp)       MIME="image/webp" ;;
  *)            MIME="image/png"  ;;
esac

PAYLOAD=/tmp/.qa_blueprint_payload_$$.json
RESPONSE=/tmp/.qa_blueprint_response_$$.json

python3 - "$IMG" "$MIME" "$HINT" <<'PY' > "$PAYLOAD"
import base64, json, sys
img_path, mime, hint = sys.argv[1], sys.argv[2], sys.argv[3]
with open(img_path, 'rb') as f:
    b64 = base64.b64encode(f.read()).decode()

hint_line = f"\nDirector hint: {hint}\n" if hint else ""

prompt = f"""You are a location manager + cinematographer analyzing a scene reference image before shooting. Your blueprint will be consumed by the prompt-writing AI to constrain what can physically happen in the scene — so be PRECISE about what's passable vs blocked, where people can enter/exit, and where light comes from.
{hint_line}
Return ONLY a JSON object (no prose, no markdown):

{{
  "scene_id": "<short slug, e.g. subway_platform_night>",
  "camera_framing": "<the framing shown, e.g. 'wide, slightly low-angle, facing east'>",
  "spatial": {{
    "left_of_frame": "<what's on screen-left, and whether passable>",
    "right_of_frame": "<what's on screen-right, and whether passable>",
    "foreground": "<closest-to-camera objects/surface>",
    "background": "<deepest visible plane>",
    "above": "<ceiling/sky/overhead>",
    "below": "<floor/ground surface, reflective?>"
  }},
  "light": {{
    "primary_direction": "<e.g. 'from upper-right, cool fluorescent'>",
    "quality": "<hard|soft|mixed>",
    "mood_color": "<e.g. teal-amber, neutral, warm tungsten>"
  }},
  "entry_exits": [
    "<each exit with direction, e.g. 'stairs back-left leading up', 'train doors right, only when train is present'>"
  ],
  "usable_paths": [
    "<paths characters CAN walk, e.g. 'along platform edge, left-to-right'>"
  ],
  "blocked_paths": [
    "<paths characters CANNOT walk, e.g. 'cannot walk through brick wall on left', 'cannot cross tracks safely'>"
  ],
  "props_present": [
    "<visible props with positions, e.g. 'bench mid-right', 'trash can back-right'>"
  ],
  "physical_rules": [
    "<rules the prompt writer must honor, e.g. 'train arrives/departs from right (track is on right)', 'wet tile reflects — any feet in frame cast reflection'>"
  ],
  "notes": "<any other spatial/continuity constraints>"
}}

CRITICAL:
- If something is ambiguous from the image, say 'unclear' — don't invent.
- Flag impossible motions (e.g. no door on left wall) as blocked_paths.
- Light direction is load-bearing: every shot lit from same source must agree."""

payload = {
  "contents":[{"parts":[
    {"inline_data":{"mime_type": mime, "data": b64}},
    {"text": prompt}
  ]}],
  "generationConfig":{"temperature":0.1,"response_mime_type":"application/json"}
}
print(json.dumps(payload))
PY

curl -s --max-time 120 -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-pro-preview:generateContent?key=${KEY}" \
  -H "Content-Type: application/json" \
  -d "@$PAYLOAD" > "$RESPONSE"

python3 - "$RESPONSE" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
if 'error' in d:
    print(json.dumps({'error': d['error']}, indent=2, ensure_ascii=False))
    sys.exit(1)
txt = d['candidates'][0]['content']['parts'][0]['text']
try:
    parsed = json.loads(txt)
    um = d.get('usageMetadata', {})
    parsed['_usage'] = {
        'total': um.get('totalTokenCount'),
        'image_tokens': next((p.get('tokenCount') for p in um.get('promptTokensDetails', []) if p.get('modality')=='IMAGE'), None),
        'thinking_tokens': um.get('thoughtsTokenCount'),
        'est_cost_usd': round((um.get('promptTokenCount',0)*2 + (um.get('candidatesTokenCount',0)+um.get('thoughtsTokenCount',0))*12)/1_000_000, 4),
    }
    print(json.dumps(parsed, indent=2, ensure_ascii=False))
except Exception as e:
    print(f"# parse error: {e}", file=sys.stderr)
    print(txt)
PY

rm -f "$PAYLOAD" "$RESPONSE"
[ -n "$TMP" ] && rm -f "$TMP"

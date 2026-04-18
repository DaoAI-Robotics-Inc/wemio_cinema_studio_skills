#!/bin/bash
# Gemini 3.1 Pro video continuity audit for Wemio Cinema Studio clips
# Usage: audit_clip.sh <file_uri> <intended_txt_file> <clip_id>
#
# <file_uri>   — Gemini Files API URI (from upload_video.sh)
# <intended>   — path to a text file describing what the clip SHOULD do
# <clip_id>    — identifier (e.g. v2_c02)
#
# Output: JSON with {clip_id, duration_sec, issues[], overall_assessment, positive_notes, _usage}
#
# Auth: reads GEMINI_API_KEY env var, or "gemini: AIza..." line from .key file.
# Default key file search: ./.key, then ../script-to-video-kling/.key (sibling skill).

set -e
FILE_URI=$1
INTENDED_FILE=$2
CLIP_ID=$3

if [ -n "$GEMINI_API_KEY" ]; then
  KEY="$GEMINI_API_KEY"
else
  for KF in "${WEMIO_KEY_FILE:-.key}" "./.key" "$(dirname "$0")/../.key" "$(dirname "$0")/../../script-to-video-kling/.key"; do
    if [ -f "$KF" ]; then
      KEY=$(grep "^gemini:" "$KF" | cut -d' ' -f2)
      if [ -n "$KEY" ]; then break; fi
    fi
  done
fi

if [ -z "$KEY" ]; then
  echo '{"error":"no Gemini API key; set GEMINI_API_KEY or add `gemini: AIza...` to .key file"}'
  exit 1
fi

INTENDED=$(cat "$INTENDED_FILE")
PAYLOAD=/tmp/.qa_payload_$$.json
RESPONSE=/tmp/.qa_response_$$.json

python3 - "$CLIP_ID" "$FILE_URI" <<PY > "$PAYLOAD"
import json, sys
clip_id = sys.argv[1]
file_uri = sys.argv[2]
intended = """$INTENDED"""
prompt = f"""You are a cinematography continuity supervisor (场记) auditing an AI-generated video clip for production defects. Watch the full video carefully with attention to time evolution, not just static frames.

Director's intended content:
{intended}

Return ONLY a JSON object (no prose, no markdown fences):

{{
  "clip_id": "{clip_id}",
  "duration_sec": <int actual duration>,
  "issues": [
    {{
      "category": "<one of: spatial_axis | object_state_continuity | physical_geometry | shot_transition | character_consistency | pacing_directing | action_completion | other>",
      "time_range": "<e.g. 0-3s or 12-15s>",
      "description": "<concrete observation>",
      "severity": "<critical | major | minor>",
      "fix_suggestion": "<specific prompt edit to fix>"
    }}
  ],
  "overall_assessment": "<pass | needs_rework | major_rewrite>",
  "positive_notes": "<what works>"
}}

Verify:
1. Characters' LEFT/RIGHT position consistent throughout? (spatial_axis)
2. Objects with state dependencies (held, handed over, in motion) persist/complete correctly? (object_state_continuity / action_completion)
3. Physical world plausibility — trains on tracks not platform, cars on roads, impossible motion? (physical_geometry)
4. Internal shot transitions smooth (match-on-action) or abrupt? (shot_transition)
5. Character appearance consistent across internal shots? (character_consistency)
6. Dead time — static shots >5s without narrative progress? (pacing_directing)
7. Actions intended to complete — did they actually complete, or fail/reset? (action_completion)"""

payload = {"contents":[{"parts":[{"file_data":{"mime_type":"video/mp4","file_uri":file_uri}},{"text":prompt}]}],"generationConfig":{"temperature":0.1,"response_mime_type":"application/json"}}
print(json.dumps(payload))
PY

curl -s --max-time 280 -X POST \
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
        'video_tokens': next((p.get('tokenCount') for p in um.get('promptTokensDetails', []) if p.get('modality')=='VIDEO'), None),
        'thinking_tokens': um.get('thoughtsTokenCount'),
        'est_cost_usd': round((um.get('promptTokenCount',0)*2 + (um.get('candidatesTokenCount',0)+um.get('thoughtsTokenCount',0))*12)/1_000_000, 4),
    }
    print(json.dumps(parsed, indent=2, ensure_ascii=False))
except Exception as e:
    print(f"# parse error: {e}", file=sys.stderr)
    print(txt)
PY

rm -f "$PAYLOAD" "$RESPONSE"

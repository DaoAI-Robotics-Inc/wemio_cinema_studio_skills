#!/bin/bash
# Gemini 3.1 Pro full-production video audit — single call, all clips concatenated.
# Usage: audit_full.sh <file_uri> <intended_txt_file> <production_id>
#
# <file_uri>   — Gemini Files API URI of the CONCATENATED mp4 (one continuous stream)
# <intended>   — text describing each clip's content and expected boundaries
# <production_id> — identifier (e.g. last_stop_v2)
#
# This is usually cheaper and more useful than per-clip audit, because it
# catches cross-clip transition issues (state disappearing, axis flipping
# at boundaries, lighting jumps).  ~$0.045 for 60s.

set -e
FILE_URI=$1
INTENDED_FILE=$2
PROD_ID=$3

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
  echo '{"error":"no Gemini API key"}'; exit 1
fi

INTENDED=$(cat "$INTENDED_FILE")
PAYLOAD=/tmp/.qa_full_payload_$$.json
RESPONSE=/tmp/.qa_full_response_$$.json

python3 - "$PROD_ID" "$FILE_URI" <<PY > "$PAYLOAD"
import json, sys
prod_id = sys.argv[1]
file_uri = sys.argv[2]
intended = """$INTENDED"""
prompt = f"""You are a cinematography continuity supervisor (场记) auditing a concatenated AI-generated short film. Watch the ENTIRE video with attention to TRANSITIONS between clips (at the stated boundary timestamps) — these are the most error-prone moments.

Production "{prod_id}":
{intended}

Return ONLY a JSON object:

{{
  "production_id": "{prod_id}",
  "overall_duration_sec": <int>,
  "overall_assessment": "<pass | needs_rework | major_rewrite>",
  "clip_issues": [
    {{ "clip": <int>, "time_range": "<>", "category": "<>", "severity": "<>", "description": "<>", "fix": "<>" }}
  ],
  "transition_issues": [
    {{
      "boundary": "<e.g. 15s>",
      "category": "<scene_element_disappears | character_position_flips | lighting_jumps | outfit_changes | mood_discontinuity | state_inconsistency | other>",
      "description": "<what changes abruptly between adjacent clips>",
      "severity": "<critical | major | minor>",
      "fix_suggestion": "<how to bridge: extract-frame chaining, re-prompt with continuity anchor, merge into same clip, etc.>"
    }}
  ],
  "cross_film_consistency": {{
    "character_appearance_stable": <bool>,
    "axis_maintained_across_all_clips": <bool>,
    "lighting_mood_consistent": <bool>,
    "notes": "<>"
  }}
}}

At each clip boundary:
- Does the last frame of the earlier clip smoothly connect to the first frame of the next?
- Any element visible at end of Clip N — still visible (or plausibly off-frame) at start of Clip N+1?
- State of characters/props consistent across boundary?
- Axis / orientation / lighting continuous?"""

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
    print(json.dumps({'error': d['error']}, indent=2, ensure_ascii=False)); sys.exit(1)
txt = d['candidates'][0]['content']['parts'][0]['text']
parsed = json.loads(txt)
um = d.get('usageMetadata', {})
parsed['_usage'] = {
    'total_tokens': um.get('totalTokenCount'),
    'video_tokens': next((p.get('tokenCount') for p in um.get('promptTokensDetails', []) if p.get('modality')=='VIDEO'), None),
    'thinking_tokens': um.get('thoughtsTokenCount'),
    'est_cost_usd': round((um.get('promptTokenCount',0)*2 + (um.get('candidatesTokenCount',0)+um.get('thoughtsTokenCount',0))*12)/1_000_000, 4),
}
print(json.dumps(parsed, indent=2, ensure_ascii=False))
PY

rm -f "$PAYLOAD" "$RESPONSE"

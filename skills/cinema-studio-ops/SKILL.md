---
name: cinema-studio-ops
description: >
  Shared media-ops utility for Wemio Cinema Studio productions.  Handles
  post-generation local processing that both `script-to-video-kling` and
  `script-to-video-seedance` (and any future video-production skill) need.

  Current operations:
    - **concat**: stitch multiple mp4 clips into a single video (local ffmpeg)

  Use when:
    - You've generated N video clips via either main skill and need to assemble
      them into a final cut
    - User says "拼起来" / "concat these videos" / "做成一个片子" after
      clip-level generation is done
    - Any ad-hoc local media manipulation of Cinema Studio output

  Do NOT use for:
    - Server-side operations that have dedicated Cinema Studio API endpoints:
      * Extract frame → `POST /api/cinema-studio/generations/{id}/extract-frame`
      * 21:9 crop → `POST /api/cinema-studio/crop-ultrawide`
      * Upload local file → `POST /api/cinema-studio/upload`
      Those stay with the main skill that needs them; this skill is strictly
      for local post-production.

argument-hint: "[paths or URLs of clips to concat, in order]"
allowed-tools: Bash, Read, Write
---

# Cinema Studio Ops — Local Post-Production

Shared utility that runs after clip-level generation is done. Keep it simple:
download / concat / save locally.  Do not upload anywhere unless the user
explicitly asks.

## Concat — Stitch Multiple Clips Into One

### Inputs
- **Ordered list of clip URLs** (from `generate-video` output) or local paths
- **Output path** (default: `/tmp/<project_slug>/final.mp4`)

### Flow

1. Download each URL to a local scratch dir (if already local, skip):
   ```bash
   mkdir -p /tmp/<project_slug>
   cd /tmp/<project_slug>
   for url in <URLs in order>; do
     curl -sLo "c$(printf '%02d' $i).mp4" "$url"; i=$((i+1))
   done
   ```

2. Build ffmpeg concat list (quote filenames):
   ```bash
   rm -f list.txt
   for f in c*.mp4; do echo "file '$f'" >> list.txt; done
   ```

3. Run concat demuxer with stream copy (fast path):
   ```bash
   ffmpeg -y -f concat -safe 0 -i list.txt -c copy /tmp/<project_slug>/final.mp4
   ```

4. Report output path + duration + size to user.

### Fast path vs re-encode

**`-c copy` fast path** works when all input clips have **identical codec,
resolution, framerate, pixel format, audio rate**. Cinema Studio clips generated
by the same model / same resolution / same aspect ratio qualify — Seedance
2.0 clips from a single production all match. Kling multi-shot outputs also
all match within a production.

**Edge cases — fall back to re-encode:**
- Mixing clips from different providers (Kling + Seedance — but skill rule is
  "one production = one model", so this shouldn't happen)
- Mixing 480p + 720p in the same concat (user changed resolution mid-project)
- Clips with audio on some and none on others

**Re-encode path(slower, safer)**:
```bash
ffmpeg -y -f concat -safe 0 -i list.txt \
  -c:v libx264 -preset veryfast -crf 20 \
  -c:a aac -b:a 128k \
  /tmp/<project_slug>/final.mp4
```

### DTS warning

`-c copy` often prints `Non-monotonic DTS` warnings at clip boundaries — these
are cosmetic, the output file plays fine. If you want clean boundaries, use
the re-encode path.

### Output handling

**By default, save locally only. Do NOT upload to Wemio S3 unless the user
explicitly asks.**

If user wants the cut uploaded for sharing:
```bash
curl -s -X POST "${API}/api/cinema-studio/upload" \
  -H "Authorization: Bearer ${TOKEN}" \
  -F "file=@/tmp/<project_slug>/final.mp4;type=video/mp4"
# → returns {"url": "https://assets.cdn.wemio.com/..."}
```

## Future Operations (placeholder)

When the platform adds more post-production primitives (trim / speed ramp /
text overlay / BGM mix / thumbnail composition / etc.), extend this skill
rather than duplicating into both main skills. Keep ops provider-agnostic:
they operate on mp4 / image URLs, not on Kling / Seedance state.

## Integration with main skills

`script-to-video-kling` and `script-to-video-seedance` Phase 5 (Summary &
Output) link here for assembly. Main skills stop at generating N clip URLs.
If the user asks "make it into one video" / "拼起来",invoke this skill with
the clip URLs from the main skill's manifest.

Both main skills' manifest.json stores clips in order (e.g. `clips[0]`,
`clips[1]`, ...`clips[N-1]`). This skill reads that order and concats
accordingly.

## Examples

### Example 1: 10-clip production stitched into 1-min short
```bash
# From main skill's manifest.json, we have 10 video URLs in order
mkdir -p /tmp/my_short && cd /tmp/my_short
curl -sLo c01.mp4 https://assets.cdn.wemio.com/.../clip1.mp4
curl -sLo c02.mp4 https://assets.cdn.wemio.com/.../clip2.mp4
# ... c03 through c10 ...
{ for f in c*.mp4; do echo "file '$f'"; done; } > list.txt
ffmpeg -y -f concat -safe 0 -i list.txt -c copy final.mp4
# → /tmp/my_short/final.mp4 ready, not uploaded
```

### Example 2: User wants upload after preview
```bash
# Only if user says "上传这个" or equivalent
curl -s -X POST "${API}/api/cinema-studio/upload" \
  -H "Authorization: Bearer ${TOKEN}" \
  -F "file=@/tmp/my_short/final.mp4;type=video/mp4"
```

## Output format

After running concat, report to user:

```
✅ Concat done
   Output: /tmp/my_short/final.mp4
   Duration: 55.5s
   Size: 9.4 MB
   Clips stitched: 10
   Codec: copy (no re-encode)
```

If user asks for the final file elsewhere, they handle it (email, YouTube,
Bilibili, etc.) — don't proactively upload.

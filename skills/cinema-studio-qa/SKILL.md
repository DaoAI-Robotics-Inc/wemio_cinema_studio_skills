---
name: cinema-studio-qa
description: >
  Automated quality assurance for AI-generated video productions in Wemio Cinema
  Studio. Three-phase continuity check: Pre-check (Claude text audit of prompts
  before generation), Post-check (Gemini 3.1 Pro video audit after generation),
  and Auto-fix (Claude synthesizes Gemini findings + rule library into revised
  prompts and re-issues generation).

  Catches AI video-generation bugs that are systematic and hard to spot by eye:
    - Spatial axis violations (character flips LEFT/RIGHT between shots)
    - Object state continuity (hand holds folio in shot A, folio floats alone in shot B)
    - Physical world plausibility (train driving on the platform surface)
    - Action completion failures (handoff didn't actually happen)
    - Dead time / bad pacing (15s of static shot without progress)
    - Character appearance drift across internal shots
    - Awkward shot transitions

  Use when:
    - After a `script-to-video-kling` or `script-to-video-seedance` run, before
      treating the clips as final
    - User says "check the video / audit / find issues / 看看有没有问题"
    - Cost-sensitive productions where you want QA default-on every run

  Do NOT use for:
    - Generating video (that's the main skills)
    - Concatenating clips (that's cinema-studio-ops)
    - Manual subjective creative taste judgments (narrative style, theme, mood)
      — QA is for mechanical continuity, not for whether the story is good

argument-hint: "[optional: path to manifest.json from a production run]"
allowed-tools: Bash, Read, Write
---

# Cinema Studio QA — 3-phase Continuity Loop

Automated quality assurance for Wemio AI video output.  Plugs in after either
`script-to-video-kling` or `script-to-video-seedance` produces N clip URLs.

```
Phase 0 — Scene blueprint (Gemini 3.1 Pro, ~$0.005/scene)
  • For every unique scene reference image in the production, call
    tools/scene_blueprint.sh to extract structured spatial facts:
    left/right passability, light direction, entry/exits, usable paths,
    blocked paths, props present, physical rules.
  • Cache per scene_id in manifest; reuse across all clips in that scene.
  • Blueprint becomes a HARD constraint input to prompt writing.
    ↓
Main skill generates N prompts  (now consuming the blueprint)
    ↓
Phase 1 — Pre-check (Claude, free, seconds)
  • Scans prompts against rule library (pre-check-rules.md)
  • Flags: missing axis lock, state-dependency chains broken across clips,
    excessive dead time, missing vocabulary terms, missing 2-3 shot structure,
    fl2v-with-humans-both-ends, prompt contradicts scene blueprint, etc.
  • If flags → stop, show diff, ask user approval
    ↓
Main skill generates N video clips
    ↓
Phase 2 — Post-check (Gemini 3.1 Pro video audit, ~$0.02/clip)
  • For each clip: upload to Gemini Files API → query with director's intent
  • Gemini returns JSON: {issues[], overall_assessment, positive_notes}
  • Aggregate across all clips
    ↓
Phase 3 — Auto-fix loop (Claude, up to 3 iterations)
  • For each clip with critical/major issues:
    - Read the original prompt + Gemini's issue list + fix_suggestions
    - Draft a revised prompt applying the fixes
  • Re-issue generation for flagged clips
  • Re-run Phase 2 on the new clips
  • Stop when: all clips pass OR 3 iterations reached OR budget cap hit
```

## API prerequisites

- **Gemini API key**: required for Phase 2 and 3.  Set `GEMINI_API_KEY` env var,
  or add a `gemini: AIza...` line to the parent skill's `.key` file.
  Tools default to reading `../script-to-video-kling/.key`.
- **Wemio API key**: inherited from the main skill, used if Phase 3 needs to
  trigger re-generation via `/generate-video`.
- **ffmpeg / curl / python3**: local tools the scripts shell out to.

## Reference files (read on demand)

- `pre-check-rules.md` — rule library for Phase 1 (axis, state, physics, pacing,
  vocabulary, etc.).  Each rule = regex/check logic + fix template.
- `gemini-audit.md` — how Phase 2 calls Gemini.  Includes prompt template,
  JSON schema, cost calculator, known Gemini limitations.
- `auto-fix-patterns.md` — how Phase 3 maps Gemini findings → prompt edits.
  Each issue category → concrete edit recipe.
- `tools/upload_video.sh` — Bash helper: uploads local mp4 or URL to Gemini
  Files API, waits for ACTIVE, prints file_uri.
- `tools/scene_blueprint.sh` — **Phase 0**. Given a scene reference image
  (URL or local path), returns structured JSON spatial blueprint. ~$0.005/scene.
- `tools/audit_full.sh` — **RECOMMENDED**. Full-production audit: given the
  concatenated mp4's file_uri + intended description, returns JSON with
  both per-clip issues AND cross-clip transition issues. One call, ~$0.045/60s.
- `tools/audit_clip.sh` — Per-clip audit: drill-down helper when full-audit
  flags a specific clip but you need more detail. Use sparingly.

## Phase 0 — Scene blueprint (Gemini vision, pre-prompt)

### Why this phase exists

Prompt writing without scene ref = Claude making up where walls, exits, lights
are. This caused observed bugs like characters "exiting" through a wall or
a train arriving on the wrong side of a platform. Gemini 3.1 Pro reads the
scene reference image once and produces a structured blueprint that every
clip prompt in that scene MUST honor.

### When to run

- **Always** when main skill has at least one `scene_reference_url` /
  `location_reference_url` / any composed scene image going into ref2v
- **Skip** for pure text-to-video with no visual reference (rare in Cinema
  Studio; most productions generate a location/scene image first)

### Flow

```bash
# For each unique scene in the production (reuse blueprint for clips in same scene):
./tools/scene_blueprint.sh \
  https://assets.cdn.wemio.com/scene/<scene_id>.png \
  "subway platform, 00:15 last train, noir mood" \
  > /tmp/<prod>/scene_<scene_id>.blueprint.json
```

Then consume blueprint fields when writing R11 environment descriptions:
- `spatial.left_of_frame` → prompt must not claim an exit on left if blueprint
  says "brick wall, non-passable"
- `light.primary_direction` → every shot in this scene lit from that direction
- `blocked_paths` → prompt cannot describe actions that cross them
- `entry_exits` → character entrances/exits must use these exact paths
- `physical_rules` → verbatim insert into the R11 environment block

### Output schema

```json
{
  "scene_id": "subway_platform_night",
  "camera_framing": "wide, slightly low-angle, facing east",
  "spatial": {
    "left_of_frame": "brick pillar and tile wall, non-passable",
    "right_of_frame": "platform edge + train track beyond",
    "foreground": "wet platform tile, reflective",
    "background": "dark tunnel mouth with warning stripes",
    "above": "fluorescent strip lights",
    "below": "wet tile with visible reflections"
  },
  "light": {
    "primary_direction": "overhead cool fluorescent, slight right-bias",
    "quality": "hard",
    "mood_color": "teal-green with amber signal accents"
  },
  "entry_exits": [
    "stairs at back-left leading up to street",
    "train doors at right (only when train present)"
  ],
  "usable_paths": [
    "along platform edge, left-to-right or right-to-left",
    "from back-left stairs toward front-right platform edge"
  ],
  "blocked_paths": [
    "cannot walk through left wall",
    "cannot cross tracks"
  ],
  "props_present": [
    "bench mid-right",
    "trash can back-right",
    "safety-line yellow strip at platform edge"
  ],
  "physical_rules": [
    "train arrives/departs from right only (track is on right)",
    "wet tile reflects — any feet in frame cast visible reflection",
    "light source is overhead, so shadows fall downward/outward, not lateral"
  ],
  "notes": "Signage in Mandarin visible but small; not readable at 480p.",
  "_usage": { "total": 1542, "image_tokens": 516, "est_cost_usd": 0.005 }
}
```

### How Phase 1 uses it

In `pre-check-rules.md` R11.2 (environment), the check is now:

> Does the prompt's environment description CONTRADICT the scene blueprint?
> e.g. prompt says "character exits to left" but blueprint lists left as
> `blocked_paths`. Flag as `critical`.

## Phase 1 — Pre-check (Claude, free)

### Input
- list of clip prompts (from main skill's manifest)
- clip metadata: duration, mode (ref2v/fl2v), reference_image_urls

### Rule categories checked
See `pre-check-rules.md` for full rule library. Coverage:

| Rule | Why it matters |
|---|---|
| Spatial axis declared (LEFT/RIGHT written for each subject) | Seedance/Kling randomize orientation without explicit axis; breaks 180° |
| State handoff across clip boundaries | If Clip N ends with open door, Clip N+1's start depends on door still open — must describe |
| Match-on-action wording | "as he opens" > "he has opened" for smoother internal cuts |
| Physical geometry declared | Trains on rails-beyond-platform-edge, cars on roads, etc — AI doesn't assume |
| Each clip uses 精确运镜 vocabulary | "子弹时间镜头" > "slow camera around subject" |
| Per-shot camera count = 1 | Multiple camera movements per shot = Seedance confused |
| Each clip has 2-3 internal shots (Seedance) | Single long static shot wastes Seedance's internal cutting |
| Pacing sanity (no 10s+ motionless shot) | Dead time = bad directing |
| fl2v two-humans check (Seedance) | Triggers `real_person` rejection |
| Characters referenced by @图片N match reference_image_urls order | Off-by-one → wrong character appears |

### Output
- Report per clip: list of flags with severity + suggested prompt rewrite
- Severity: `critical` (will fail generation or produce broken output),
  `major` (will produce ugly but technically valid video),
  `minor` (stylistic polish)
- Default: block main skill from proceeding if any `critical`; warn and
  ask user if only `major`; ignore `minor` unless user wants perfection

## Phase 2 — Post-check (Gemini 3.1 Pro video audit)

### 🎯 Default: full-production audit (单次审 60s 整片)

**Run this first, it catches more bugs and costs less.**

After main skill produces N clips → use `cinema-studio-ops` to concat into one
mp4 → upload concat to Gemini → one audit call catches:
- All per-clip issues(axis, state, pacing, etc.)
- **Cross-clip transition issues**(elements disappearing / popping, boundary
  jumps) — can only be caught by watching the concat, never by per-clip audit

Cost: **~$0.045 for 60s production** (cheaper than 4 per-clip audits at $0.08).

```bash
# After main skill produces clips and cinema-studio-ops concats them:
FILE_URI=$(tools/upload_video.sh /tmp/mi_short/final.mp4 prod_full)
tools/audit_full.sh "$FILE_URI" /tmp/mi_short/intended_full.txt my_short
```

Output schema(see `examples/last_stop_v2/audit_full.json`):

```json
{
  "production_id": "last_stop_v2",
  "overall_duration_sec": 60,
  "overall_assessment": "needs_rework",
  "clip_issues": [...],
  "transition_issues": [
    {
      "boundary": "45s",
      "category": "state_inconsistency",
      "description": "The folio completely disappears between clip 3 and clip 4",
      "severity": "critical",
      "fix_suggestion": "Extract last frame of Clip 3 with folio visible, use as first_frame_url of Clip 4"
    }
  ],
  "cross_film_consistency": {
    "character_appearance_stable": true,
    "axis_maintained_across_all_clips": true,
    "lighting_mood_consistent": true
  }
}
```

### Per-clip audit(补充,用于定位 clip 内部问题)

When full-production audit flags a clip but isn't specific about WHICH internal
shot has the bug, drill into that clip:

### Flow

For each clip:
1. `tools/upload_video.sh <video_url>` → prints `file_uri`
2. Write intended-content text file (≤300 words) describing what the clip
   should contain (characters, axis, key actions)
3. `tools/audit_clip.sh <file_uri> <intended.txt> <clip_id>` → JSON report

### Output JSON schema

```json
{
  "clip_id": "v2_c02",
  "duration_sec": 15,
  "issues": [
    {
      "category": "object_state_continuity",
      "time_range": "06-10s",
      "description": "The folio transfer fails. Woman extends folio but detective does not take it.",
      "severity": "critical",
      "fix_suggestion": "Explicitly prompt 'detective successfully takes the folio, woman's hands empty'"
    }
  ],
  "overall_assessment": "needs_rework",
  "positive_notes": "Spatial axis is perfectly maintained...",
  "_usage": {"total_tokens": 3007, "video_tokens": 1337, "est_cost_usd": 0.018}
}
```

### Cost
- ~$0.018 per 15s clip (Gemini 3.1 Pro Preview)
- 60s short (4 clips): $0.07
- 30min episode (~120 clips): $2.16
- Full auto-fix loop with 3 iterations: 3× above

### Categories Gemini checks (passed via prompt)
- `spatial_axis` — character positions consistent
- `object_state_continuity` — objects persist/handoff correctly
- `physical_geometry` — trains on tracks, real-world physics
- `shot_transition` — internal cuts smooth
- `character_consistency` — same face/outfit
- `pacing_directing` — dead time, bad directing
- `action_completion` — intended actions actually complete
- `other` — catch-all

## Phase 3 — Auto-fix

### When to invoke
- Phase 2 returned any `critical` or `major` issue
- Remaining iteration budget > 0 (default max 3)
- Remaining credit budget > 0 (default 1.8x original generation cost)

### Fix synthesis
For each clip with issues:
1. Read original prompt from main skill's manifest
2. Read Gemini's `fix_suggestion` per issue
3. Consult `auto-fix-patterns.md` for category-specific rewrites
4. Draft revised prompt (keep unchanged parts, surgical-edit the problem parts)
5. Sanity check: does revised prompt still match director's intent?
6. Re-issue `POST /generate-video` with revised prompt
7. Re-upload new clip → re-run Phase 2

### Safety
- **Max 3 iterations per clip** (don't infinite-loop)
- **Budget cap = 1.8× original production cost**
- **Always show user the revised prompt before re-generation**(unless user sets
  `--auto-confirm` mode explicitly)
- **Keep old clip URLs in manifest** for comparison / rollback

## Example usage flow

After `script-to-video-seedance` produces《末班车》with 4 clip URLs:

```bash
# Phase 1 (Claude text-only, no credits)
/cinema-studio-qa precheck /tmp/last_stop_v2/manifest.json
# → "All 4 prompts pass basic rules. proceed."

# After user generates clips (main skill)…
# Phase 2 (Gemini video audit, ~$0.07 total)
/cinema-studio-qa postcheck /tmp/last_stop_v2/manifest.json
# → 4 clip audits:
#   v2_c01: critical — train doors close before handoff
#   v2_c02: critical — folio handoff failed
#   v2_c03: pass
#   v2_c04: major — 15s static shot, pacing dragging

# Phase 3 (Claude drafts fixes, main skill regenerates)
/cinema-studio-qa autofix /tmp/last_stop_v2/manifest.json --max-iter 3
# → iteration 1: regenerate c01, c02, c04 with revised prompts (~$18 USD in credits)
# → re-audit: c01 pass, c02 pass, c04 still static
# → iteration 2: deeper rewrite of c04 to add narrative beat
# → re-audit: all 4 pass
# → final manifest saved
```

## Known limitations

- **Gemini preview model may rate-limit**: parallel calls sometimes fail.
  Tools default to sequential; add sleeps between iterations if needed.
- **Gemini occasionally mis-categorizes**: borderline issues (minor vs major)
  should be reviewed by user, not auto-fixed
- **Pre-check rule library is evolving**: starts with ~10 rules based on
  observed bugs from 《末班车》 v1/v2 dogfood; add rules as new bug classes surface
- **Auto-fix isn't magic**: some issues (wrong character appearance due to
  reference image quality) can't be fixed by prompt edit alone — may need
  regenerating character ref first

## Dogfood examples

Audit reports from《末班车》v2 (the first real dogfood) live in
`examples/last_stop_v2/`.  Each report = user-reported bug + Gemini's auto-detection
+ Claude's auto-fix proposal. Use these to calibrate new rules.

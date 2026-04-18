# 《末班车》v2 Dogfood Report

First real acceptance-test run of `cinema-studio-qa` against a 60s Seedance
production that the user had already flagged 3 bugs in.

## Input

- Production: 4 clips × 15s, seedance-2.0-fast 480p
- Concat: `/tmp/last_stop_v2/last_stop_v2.mp4` (60.3s, 12.1 MB)
- Clip URLs: see main `manifest.json`

## User-reported bugs (ground truth)

1. **Clip 1 (12s):** 车门关了人还没下来
2. **Clip 3→4 (45-46s):** 切镜后列车突然消失
3. **Clip 4 (45-60s):** 15s 站着不动,导演不会这样拍

## Gemini 3.1 Pro auto-detection (4 × $0.018 = $0.08 total)

### `audit_c01.json` — Clip 1

- ✅ **CAUGHT Bug #1**: "The train doors close and the train departs the
  station before anyone exits, violating the requirement that the doors must
  stay open at the end of the clip for a handoff."
- Severity: **critical**
- Fix suggestion: "Explicitly state in the prompt: 'Train doors open and
  remain open until the end of the video. The train does NOT depart.'"

### `audit_c02.json` — Clip 2

- 🆕 **NEW BUG (not in user's list)**: "The folio transfer fails. The woman
  extends the folio, but the detective does not take it. She retains the
  folio and carries it back to the train."
- Severity: **critical**
- This is an `action_completion` failure that user hadn't spotted on first
  viewing. Gemini nailed it.

### `audit_c03.json` — Clip 3

- 🆕 NEW BUG: "Shot 1 is a medium shot of the detective instead of the
  requested macro insert of his hands opening the folio" (pacing_directing /
  action_completion)
- 🆕 NEW BUG: "The leather folio morphs unnaturally as it opens, turning
  into a thick block of stiff pages" (physical_geometry artifact)
- MINOR: micro-expressions (eyelid twitch, jaw flinch) barely visible

### `audit_c04.json` — Clip 4

- ✅ **CAUGHT Bug #3**: "The video remains a single static shot for the
  entire 15 seconds, resulting in excessive dead time and failing to visually
  emphasize the character's isolation through camera movement."
- Severity: **critical**
- Also caught: "The detective is not holding the intended 'folio dropped
  loose in one hand'. His hands appear empty." (minor)

### Bug #2 (cross-clip train disappearance)

- ❌ **NOT auto-caught** by single-clip audit. This is a Phase 2b cross-clip
  issue (requires comparing last frame of clip 3 vs first frame of clip 4).
- Current workaround: manual pairing. Future: add `tools/audit_pair.sh`.

## Score

- User bugs caught: 2/3 (67%)
- New bugs surfaced: 4
- False positives: 0
- Total cost: $0.08
- Human review time saved: ~10 min of careful side-by-side comparison
  with mental checklist

## Takeaways

1. **Single-clip audit is reliable for intra-clip issues**(pacing, action
   completion, object morphing, character consistency within a shot).
2. **Cross-clip issues need Phase 2b**: adjacent-frame audit. Roadmap item.
3. **Gemini's fix_suggestion is actionable** — matches the edit recipes in
   `auto-fix-patterns.md` pretty well; Phase 3 auto-fix can synthesize
   directly from them.
4. **Rate limiting**: parallel Gemini calls failed once (shared tmpfile race
   condition in my first script version; fixed). Tools now use `$$` pid in
   tmp filenames and sequential calls are reliable.

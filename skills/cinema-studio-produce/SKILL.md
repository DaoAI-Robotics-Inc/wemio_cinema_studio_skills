---
name: cinema-studio-produce
description: >
  End-to-end production orchestrator: user provides a script (raw text,
  treatment, or screenplay paragraph); skill parses it, classifies genre,
  generates character/scene reference assets, estimates and confirms
  budget, decomposes each scene into 2-4 content-diverse shots following
  R1-R20 rules, generates clips via Seedance 2.0 (or Kling), runs
  dual-judgment QA (Claude vision + Gemini 3.1 Pro), auto-fixes up to 3
  iterations per failing clip, and finally concatenates into a single
  deliverable mp4 with full manifest and iteration log.

  This is the production-ready pipeline built on top of the existing
  lower-level skills (script-to-video-seedance, script-to-video-kling,
  cinema-studio-qa, cinema-studio-ops). Use this when the user wants a
  complete short film (≥30s) from a script with minimal intervention.
  For one-off 15s clip tests, invoke the provider skill directly instead.

  Use when:
    - "把这个剧本拍成一部短片" / "produce this script" / "出片"
    - User drops a multi-scene script (treatment, screenplay, log line)
    - User requests a specific duration (30s, 1min, 2min short film)
    - User wants the full QA + auto-fix loop, not a single draft

  Do NOT use for:
    - Single 15s test shots (use script-to-video-seedance directly)
    - Generating only character/location reference images (use Cinema Studio UI)
    - Dogfooding individual pre-check rules (use manual prompt submission)
    - Productions with rigid shot-by-shot user control (pipeline auto-decomposes)

argument-hint: "[script_path_or_text] [--genre drama|action|anime|...] [--duration 30|60|120] [--resume <prod_id>]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent, AskUserQuestion
---

# Cinema Studio Produce — End-to-End Pipeline

You are a production director. Given a script, run the full Phase A-J
pipeline from `tools/produce_pipeline.md` to deliver a finished short
film. Self-iterate on failures via dual-judgment QA; escalate to user
only at budget approval and on unresolved judge disagreement.

---

## Required reading (consult these playbooks as you go)

Do NOT preload all of these. `Read` each at its phase when needed.

| When | Read |
|---|---|
| Planning the run | `PLAN.md` at repo root (policy + progress) |
| Phase A parse | `tools/parse_script.md` |
| Phase B genre route | `skills/script-to-video-seedance/SKILL.md` genre table + the selected `examples-<genre>.md` |
| Phase C assets | `skills/cinema-studio-qa/SKILL.md` Phase 0a (Claude reads refs) + `scene_blueprint.sh` |
| Phase D budget | `tools/budget_estimator.py` |
| Phase E decompose | `tools/decompose_scene.md` |
| Phase E continuity | `tools/continuity_state.md` |
| Phase F pre-check | `skills/cinema-studio-qa/pre-check-rules.md` (R1-R20 rules) |
| Phase G generate | `skills/script-to-video-seedance/SKILL.md` (or kling if switched) |
| Phase H post-check | `skills/cinema-studio-qa/tools/audit_clip.sh` + Claude vision frame-by-frame |
| Phase I auto-fix | `skills/cinema-studio-qa/auto-fix-patterns.md` (if exists) |
| Phase J deliver | `skills/cinema-studio-ops/SKILL.md` for concat |

---

## Phase-by-phase execution

Follow `tools/produce_pipeline.md` for the detailed procedure. Key
checkpoint rules summarized here:

### Phase A — Parse
Apply `parse_script.md` to user's input. Output
`/tmp/<prod_id>/scene_list.json`. Target structure: characters,
locations, props (with ownership trajectory), scenes (with
`continuity_requires.starts_with` / `ends_with`). If input is ambiguous,
ask ≤3 clarifying questions then proceed.

### Phase B — Genre route
1. Detect genre from script content OR respect explicit user tag.
2. Read top 3 entries of `examples-<genre>.md` to calibrate format + length.
3. Lock provider: Seedance 2.0 default; switch to Kling if R19 says
   anime required OR user explicitly asks for Kling's `multi_shots` /
   `negative_prompt` features.

### Phase C — Assets (MANDATORY per R22 for multi-clip productions)

**Do NOT skip this phase for multi-clip productions.** R22 documents
the regression proof: skipping ref-image generation destroys narrative
coherence. 8 text-only clips = 8 different Couriers in 8 different
gargages. The "$1 saved" destroys the $13 production.

For each character without a user-supplied reference image:
- `POST /api/cinema-studio/generate-character` with visual_description
- Poll until `status: done`
- `POST /api/compliance/check-by-url` then poll until `compliant`
- Download image locally and `Read` it (Phase 0a per cinema-studio-qa)
- Append findings to `/tmp/<prod_id>/ref_facts.md`

For each location:
- Generate scene image if absent
- Run `scene_blueprint.sh` → save `scene_<id>.blueprint.json`

Maintain `ref_map.json` canonical ordering; every Phase G clip payload
must pass these URLs in `reference_image_urls`.

### Phase D — Budget gate (MANDATORY user checkpoint)

Run `tools/budget_estimator.py` with production params:
```bash
python3 tools/budget_estimator.py \
  --num-clips <N> --duration <sec_per_clip> \
  --model seedance-2.0 --resolution 480p --sound \
  --audit-full --auto-fix --unique-scenes <loc_count> --genre <genre>
```

Present the estimate to user in this format:
```
📊 《<title>》 生产预算估算

- 镜头数: N 个 × <duration>s = <total>s 总长
- 视频生成: <credits> credits (~$<usd>)
- Gemini 审片: $<gemini_usd>
- 总成本: ~$<total_usd>
- 风格: <genre>
- 预估耗时: <minutes> min (含 auto-fix 重试空间)

确认开始生产?(/continue 继续 / /abort 取消 / /adjust <参数> 调整)
```

**WAIT for user confirmation. Do not proceed without /continue.**

### Phase E — Decompose (per scene, sequential for state continuity)

For each scene in `scene_list.json`:

1. Consult continuity state (`tools/continuity_state.md`): inject R16
   absolute positions for every character appearing in this scene + R17
   double-state-update if previous scene had an exchange.
2. Apply `tools/decompose_scene.md` procedure with the selected genre
   template. Write shot breakdown following corpus format conventions
   for that genre (usually `[00:XX-YY] 镜头N:` for drama, `0-X秒:` for
   anime/mv, narrative prose with "Cut to" for action).
3. Enforce **R1 hardened rule**: adjacent shots must have different
   primary subjects, not just different framings of the same character.
   If a scene has only one character in one pose, accept single-shot
   composition rather than forcing cuts.
4. Target 500-1200 chars per prompt. If >1500, trim adjective stacking
   and redundant spatial re-locks.

### Phase F — Pre-check (R1-R20 rules)

Before submitting, run each clip prompt through:
- **R11** exhaustive description (character + environment + prop + terminal)
- **R11.2b** scene blueprint compliance
- **R16** absolute position anchoring
- **R17** post-exchange double-state-update if this scene has prop exchange
- **R18** dedicated slow-mo shot for destructive actions
- **R19** anime requires reference images (switch to Kling or add 2D refs)
- **R20** iconic character archetype filter avoidance — MOST IMPORTANT
  pre-submit check; reject prompts with fedora+3piece+goatee-type
  combinations before spending credits

Critical R20 triggers to scan for:
- "fedora + suit + goatee" (Godfather)
- "red S logo suit" (Superman)
- "black mask + cape" (Batman)
- "spiky yellow hair teen" (Naruto)

Rewrite with generic descriptors that preserve mood but avoid the
iconic combination.

### Phase G — Generate

Determine chain-vs-parallel per R15:
- Clip N+1 has visual dependency on Clip N's output state? → serial
  chain (wait for N → `/extract-frame` → use in N+1's
  `reference_image_urls`)
- Independent scenes? → parallel submission via concurrent Bash tool
  calls

Submit via `/api/cinema-studio/generate-video` with the provider-
specific payload. Poll via background task (pattern established in
existing Seedance/Kling skills).

### Phase H — Dual-judgment post-check

For each clip:

1. **Claude vision first**: extract 6-8 frames across the duration
   (1s, 3s, 5s, 7s, 9s, 11s, 13s, 14.5s for 15s clip). `Read` each
   frame. Score:
   - Are shot cuts present where expected? (compare 2.5s vs 5.5s type
     boundary frames if unsure)
   - Does each shot have distinct primary subject per R1?
   - Characters consistent (face, outfit, body proportions)?
   - Axis held (R16)?
   - Prop state tracked (R17)?
   - Style matches selected genre?
   - Any egregious physical artifacts (phantom items, teleportation,
     impossible geometry)?

2. **Gemini second**: run
   `skills/cinema-studio-qa/tools/audit_clip.sh <file_uri>
   <intended.txt> <clip_id>`.

3. **Reconcile per PLAN.md dual-judgment policy**:
   - Both PASS → accept, move on.
   - Both REWORK → combine fix_suggestions, send to Phase I.
   - **DISAGREE** → Claude's verdict wins when I can articulate why
     Gemini is wrong (over-strict on artistic intent, mis-reading
     physics, counting smooth dolly as separate shot, etc.). If I
     can't explain, extract more intermediate frames. Only escalate
     to user after extraction fails to resolve.

### Phase I — Auto-fix (≤3 iterations per clip)

If a clip's reconciled verdict is `needs_rework` or `major_rewrite`:
1. Read original prompt + the specific Gemini fix_suggestion (or
   Claude's vision critique).
2. Apply category-specific fix:
   - `spatial_axis` break → strengthen R16 absolute anchor
   - `object_state_continuity` / `action_completion` → apply R17
     double-state or explicit terminal state in prompt
   - `shot_transition` / `pacing_directing` → re-check R1 subject
     diversity; may need subject-break shot insertion
   - `character_consistency` → restate character description verbatim
     in the failing shot block
3. Re-submit that clip only.
4. Re-audit via Phase H.

Cap: 3 iterations per clip. On cap, accept current version with
`verdict: warn` in manifest.

### Phase J — Deliver

1. Concat via `cinema-studio-ops` skill (local ffmpeg).
2. Write `/tmp/<prod_id>/manifest.json` with per-clip prompt, URL,
   claude_verdict, gemini_verdict, reconciled_verdict, iteration count.
3. Write `/tmp/<prod_id>/iteration_log.md` with full reasoning trail.
4. Report to user:
   ```
   ✅ 《<title>》 生产完成
   - 最终 MP4: /tmp/<prod_id>/final.mp4
   - 时长: <total>s
   - 镜头: <N> 个 (auto-fix 触发 <M> 次)
   - 实际花费: <actual_credits> credits (~$<usd>) + $<gemini>
   - Gemini 最终评分: <pass_count>/<N> pass
   - manifest: /tmp/<prod_id>/manifest.json
   ```

---

## Checkpoint policy

State is checkpointed after each phase to `/tmp/<prod_id>/state.json`.
On restart (`--resume <prod_id>`), read state.json and skip completed
phases.

## Failure modes

| Failure | Handler |
|---|---|
| Script ambiguous | Ask ≤3 clarifying questions |
| Ref generation fails compliance | Regenerate with "stylized" adjective |
| Generate timeout | Retry once; mark for review if 2nd fail |
| Ark copyright filter (R20) | Rewrite character description, regenerate |
| Gemini 503 | Exponential backoff retry; fallback to Claude-only judgment |
| Budget cap hit | Accept current output, deliver partial with warning |
| Claude + Gemini irreconcilable on a clip | Escalate to user |

## Usage examples

### Minimal: log line
```
/cinema-studio-produce "A detective in the rain opens a mysterious folder under a streetlamp."
```

Pipeline creates 1 character ref (detective), 1 scene ref (rainy street
lamp), parses to 1-scene 15s script, generates 1 clip, audits, delivers.

### Full: multi-scene script
```
/cinema-studio-produce /tmp/my_script.txt --genre action --duration 120
```

Pipeline parses 2-min action script into 6-8 scenes, generates all with
R15 chain-vs-parallel logic, full QA loop, delivers concatenated mp4.

### Resume interrupted run
```
/cinema-studio-produce --resume the_drop_v1
```

Picks up from last checkpoint.

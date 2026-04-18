# Pre-check Rule Library

Each rule has: **What to detect** / **How to detect (regex or semantic check)** / **Fix template**.

Based on observed bug classes from《末班车》v1 (10×5s) and v2 (4×15s) dogfood.

---

## R1. Spatial Axis Declared (CRITICAL)

**What**: Each clip prompt must explicitly declare LEFT/RIGHT position of key subjects and maintain 180° axis.

**Detect**: For each clip prompt, check if it mentions at minimum:
- `left`, `right`, `LEFT`, `RIGHT`, `左`, `右`, or equivalent directional anchors
- At least one of: `180°`, `180 degree`, `180 度`, or `axis`

Regex-ish: `/\b(LEFT|RIGHT|left|right|左侧|右侧|左|右)\b.*\b(LEFT|RIGHT|left|right|180)/i`

**Severity**: critical (will cause side-flipping bug, v1 《末班车》had 10 clips broken by this)

**Fix template**: Prepend to prompt:
```
180-degree axis locked throughout — @图片1 always on RIGHT third of frame,
@图片2 always on LEFT side. Train enters/exits from LEFT only.
```

---

## R2. State Handoff Across Clip Boundaries (CRITICAL)

**What**: If Clip N ends with an object/door/scene in state X, and Clip N+1 starts depending on state X, the prompt for Clip N+1 must describe state X as its starting condition (not assume it).

**Detect**: semantic check across adjacent clip prompts:
- Does Clip N's description end with a state-change event (doors open, character raises glass, curtain drawn)?
- Does Clip N+1's description depend on that state (someone stepping through doors, drinking from glass, seeing through opening)?
- Does Clip N+1 restate the state at its start?

Keywords to detect state changes: `opens`, `closes`, `draws`, `raises`, `lowers`, `打开`, `关上`, `推开`, `拉开`, `hisses open`, `slides open`

**Severity**: critical (v2 Bug 1: "doors close before woman exits" in《末班车》c01→c02)

**Fix template**:
- Option A (preferred): merge state change + state-dependent next into same clip's internal multi-shot
- Option B: Clip N+1 opens with "Train doors remain open, steam still drifting from brakes, as @图片2 appears in the doorway..."

---

## R3. Physical Geometry Declared (CRITICAL)

**What**: For any clip involving vehicles, architecture, machinery, explicitly describe their spatial relationship to the scene (trains on rails beyond platform edge, cars on roads, doors on walls, etc.).

**Detect**: if clip mentions a vehicle/machine noun (`train`, `car`, `bus`, `elevator`, `motorcycle`, `boat`, `aircraft`, `列车`, `汽车`, `电梯`) without geometric context words nearby (`track`, `rail`, `road`, `lane`, `beyond`, `platform edge`, `depressed`, `shaft`, `轨道`, `站台边缘`, `路面`):
→ flag

**Severity**: critical (v1《末班车》had train driving on platform surface)

**Fix template**: Add spatial grounding:
- Trains: `"on the parallel rail track beyond the platform edge, visible past the yellow tactile paving strip. The train runs on the depressed track lane, never crossing the platform surface."`
- Cars: `"driving on the paved road, never crossing onto the sidewalk."`

---

## R4. Match-on-Action Wording (MAJOR)

**What**: Internal shot transitions within a single clip should use present progressive / "as he..." phrasing (not perfective / "he has...").

**Detect**: shot transitions written as completed states (past tense, "he has done X") rather than in-progress actions.

Bad: "He has opened the folio. Camera cuts to close-up."
Good: "As his fingers open the folio cover, camera cuts to macro insert on the pages..."

**Severity**: major (produces awkward inter-shot jumps, not visually broken but feels wrong)

**Fix template**: Rewrite transitions with `as X happens, cut to...` or `then X, which cuts to...`

---

## R5. Precise Camera Vocabulary Used (MAJOR)

**What**: Each shot must use a named camera move from `../script-to-video-seedance/camera-vocabulary.md`, not generic descriptions.

**Detect**: prompt contains generic camera phrases without named vocabulary:
- Bad indicators: `camera slowly moves`, `camera pans`, `camera dollies` (without a specific named term like `推进亲密镜头`, `子弹时间镜头`)
- Good indicators: `子弹时间镜头`, `推进亲密镜头`, `后退揭示镜头`, `打斗跟随镜头`, `瞳孔放大镜头`, `凝视长镜头`, `眼抖特写镜头`, etc. (see camera-vocabulary.md for full list)

**Severity**: major (generic prompts produce generic AI output; named terms hit Seedance 2.0's training-specific semantics)

**Fix template**: Suggest 3 vocabulary alternatives from camera-vocabulary.md based on the shot's emotional/action type. Let user pick one per shot.

---

## R6. One Camera Movement Per Shot (MAJOR)

**What**: Each internal shot should have exactly one camera-movement descriptor. Mixing (e.g. "orbit AND push in") confuses Seedance.

**Detect**: count named camera vocabulary terms in each shot segment. If >1 per shot → flag.

**Severity**: major

**Fix template**: Split into two shots, one camera move each. Or remove the weaker one.

---

## R7. Internal Multi-shot Sanity (MAJOR for Seedance)

**What**: Seedance clips (seedance-2.0 / seedance-2.0-fast) should use their 15s duration with 2-3 internal shots, not one static 15s take.

**Detect** (Seedance only):
- Clip duration ≥ 10s
- Prompt describes only 1 shot (no transition words like `then`, `next`, `finally`, `cuts to`, `转向`, `紧接着`, `之后`)
→ flag

**Severity**: major (v2 Bug 3: Clip 4 was 15s of near-static composition; felt dragging)

**Fix template**: Propose 2 additional internal shots to break the dead time. Pick complementary shot sizes (WS → MS → CU is the default fallback).

---

## R8. Pacing — No Single Static Shot >8s (MAJOR)

**What**: Any single internal shot lasting >8s without action progression is "dead time" that looks like bad directing.

**Detect**: within a clip's internal shot list, if any single shot has duration >8s AND its description contains only stative verbs (`stands`, `stares`, `holds`, `sits`, `站着`, `看着`, `持着`, `坐着`) without action verbs → flag.

**Severity**: major (导演 would not shoot 15s of someone just standing — they'd add a beat: kneel, drop something, look up, walk)

**Fix template**: Propose one action beat to insert mid-shot (e.g. "at 4 seconds, he slowly kneels and places the folio on the platform").

---

## R9. fl2v Two-Humans Rule (CRITICAL for Seedance)

**What**: fl2v mode with both `first_frame_url` and `last_frame_url` — if BOTH frames contain clearly visible real humans, Ark rejects with `real_person`.

**Detect**: for clips with mode=fl2v:
- Both frames in the prompt indicate a human subject (character name, `@图片N` with N referencing a character, or explicit words like "person", "character")
→ flag

**Severity**: critical (will fail generation, waste credits)

**Fix template**: Propose one of:
- Empty-to-human transition (character entrance)
- Human-to-empty transition (character exit)
- Switch to ref2v mode with just `first_frame` + `reference_image_urls`

---

## R10. Character Reference Order (CRITICAL)

**What**: Positional `@图片N` tokens in prompt must match order of URLs in `reference_image_urls` array.

**Detect**: for each prompt, scan for `@图片\d` / `@asset\d` mentions; get N values. Compare max N to length of `reference_image_urls` array.
- Max N > array length → flag (N out of bounds)
- @图片N used but N-th URL is wrong type (e.g. @图片1 referring to location but first URL is character) → flag

**Severity**: critical (wrong character appears in frame, or generation fails)

**Fix template**: Reorder `reference_image_urls` to match prompt's @图片N order, or remap @图片N to correct indices.

---

## Rule application order

When running Phase 1 Pre-check:
1. Run R9 first (fl2v must fail-fast before anything else)
2. Run R10 (reference sanity — if broken, no point checking anything else)
3. Run R1, R3 (critical physical rules)
4. Run R2 (cross-clip state — requires full production context)
5. Run R4, R5, R6, R7, R8 (major-severity polish rules)

If any critical flagged → STOP. Show user the report, wait for approval / fix before generating.

## Future rules (to add as bugs surface)

- R11: Lighting direction consistency across shots
- R12: Sound / dialogue reference sanity
- R13: Genre-tone consistency
- R14: Dynamic range / contrast warnings

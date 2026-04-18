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

## R11. Exhaustive Description — 穷尽描述原则(CRITICAL,规则框架之核心)

**Added v4 after user insight:**
> "Seedance 对指令的遵守很好,应该是要把每个人物、整个场景以及完整的变化都加进去。包括最开始写 prompt 和最后检查的时候都要考虑到。"

Root-cause reframing: Seedance doesn't fail by disobeying — it fails by
rendering only what's explicitly written. The fix is writing **complete
scene blueprints**, not more clever prompts.

### R11 structure: 4 sub-checks

**R11.1 Character completeness** — every character in frame has:
  - position(LEFT/RIGHT, foreground/background, frame third)
  - starting state(standing / walking / kneeling / gesturing)
  - full action arc(4-stage: setup + process + completion + terminal)
  - ending state(where they are + what they're doing at clip end)

**R11.2 Environment completeness** — every visible scene element's full trajectory:
  - Vehicles(train / car): position, motion state, departing/arriving/stationary
  - Architecture(door / window): open/closed, state changes
  - Lighting: flicker / steady / dimming
  - Weather / atmosphere: rain, steam, mist, smoke — is it intensifying, fading, static?

**R11.3 Prop persistence** — every prop tracked from entry to exit:
  - Who holds it, where it sits, its material/color/size (specific not generic)
  - State(closed/open, clean/broken, full/empty)
  - Transfer chain if it moves between characters

**R11.4 Terminal state** — clip ends with what image?
  - Who's in frame and doing what?
  - What's the scene's atmosphere at the last frame?
  - Props where?
  - This becomes the implicit handoff to the next clip

### Detection checklist (Pre-check)

For each clip prompt, apply all 4 sub-checks. Flag if any sub-check fails.

**R11.1 check**: for each named character / @图片N referenced in the prompt,
does the prompt describe their state at both start AND end of the clip?
Count action verbs per character — if <2, likely under-specified.

**R11.2 check**: scan for environment nouns(train/door/light/rain/fog/steam/etc).
For each: does the prompt describe its state through the clip(not just at start)?

**R11.3 check**: scan for prop nouns(folio/glass/weapon/letter/phone/key/etc).
For each: does the prompt describe who holds it / where it sits at start AND end?

**R11.4 check**: does the prompt have explicit ending-frame language?
Keywords: `clip ends with`, `final frame shows`, `at the end`, `最终画面`, `clip 结束时`,
or equivalent compositional description of the last moment.

### Fix template

Take any under-described scene and expand systematically:

Before (under-specified):
```
She hands him the folio and walks back.
```

After (exhaustive):
```
[R11.1 她:] She extends the folio with both hands. He grasps it with
both hands. She releases, her hands drop empty. She turns 180° on her
heel, walks back LEFT to the train, steps into the carriage, disappears
through the doorway.

[R11.1 他:] He stays fixed on right third, firmly holding the folio at
chest level, his eyes tracking her until she's gone, then looking down
at the folio.

[R11.2 列车/门:] Train remains at platform, doors hissed open at start,
Woman passes through doorway, doors hiss closed behind her, train stays
stationary, steam from brakes gradually thinning.

[R11.3 folio:] Folio starts in Woman's both hands, passes to Detective's
both hands, ends at Detective's chest level held in both hands.

[R11.4 终态:] Final frame: Detective alone on right third holding folio,
Woman gone, train doors closed, steam dispersed, platform silent.
```

The bracketed annotations are for Pre-check clarity — in the actual prompt,
merge into prose.

### Character / Environment / Prop action-verb vocabulary

(inherited from old R11 — now categorized under R11.1 / R11.2 / R11.3)

Exchange verbs (R11.1): `hands over, gives, passes, throws, catches, takes, accepts, releases, grabs, delivers`
Movement verbs (R11.1): `walks, runs, approaches, turns, leaves, exits, enters, boards`
Motion / transport (R11.2): `train pulls away, car drives off, ship sails, plane takes off`
Physical action (R11.1): `sits, stands, lights, opens, closes, drops, raises, points`

For all of these, completion + terminal state required per 4-stage formula.

### Severity

**Critical** — this is the root-cause rule for ~70% of observed Seedance bugs
in《末班车》 dogfood. Under-specified scene blueprint is the single biggest
quality lever.

### Post-check uses R11 too

Gemini audit prompt now includes:
> "Does the video contain every element that the intended description specifies?
> List anything in the intended description that's MISSING from the video, and
> anything PRESENT in the video that wasn't described in the intended."

This catches both directions: under-specified prompt that Seedance filled in
arbitrarily, and explicit prompt that Seedance failed to render.

---

## R11-legacy. Original Action Completion rule (subsumed by R11 above)

**Added after:** v2 c02 Gemini finding (handoff failed). **Extended in v3**
(Woman "walks back toward train" → she just stood there). Seedance is
literal — it renders what you describe, no common-sense inference.

**Principle**: Every action verb in a prompt must be followed through to its
**completion state** + **terminal state**, not just the initiation.

**Formula**:`Action = setup + process + completion + terminal state`. Write all four.

**Detect**: prompt contains action verbs without completion + terminal language.

### Exchange / transaction verbs
- Detect: `hands over`, `gives`, `passes`, `throws`, `catches`, `takes`,
  `accepts`, `releases`, `grabs`, `delivers`, `递`, `交给`, `扔给`, `抓`, `接`, `拿`, `给`
- Completion missing indicators needed: `fully`, `successfully`, `empty hands after`, `now holds`, `finishes`, `完成`

### Movement verbs (NEW extension v3)
- Detect: `walks`, `runs`, `approaches`, `turns`, `leaves`, `exits`, `enters`,
  `boards`, `heads back`, `moves toward`, `走`, `跑`, `转身`, `离开`, `进入`, `上车`, `下车`
- Completion missing indicators needed: `disappears through`, `fully boards`,
  `reaches and enters`, `steps into`, `walks out of frame`, `消失在`, `彻底进入`, `走出画面`

### Motion / transport verbs (NEW)
- Detect: `train pulls away`, `car drives off`, `ship sails`, `plane takes off`,
  `列车驶离`, `车开走`
- Completion missing indicators needed: `fully exits frame`, `tail lights vanish`,
  `disappears into the tunnel/distance`, `完全离开画面`, `消失在远方`

### Physical action verbs (NEW)
- Detect: `sits`, `stands`, `lights`, `opens`, `closes`, `drops`, `raises`,
  `坐下`, `站起`, `点燃`, `打开`, `关上`, `放下`, `举起`
- Completion missing indicators needed: specific end-state language
  (`settles into the chair`, `flame touches tip which glows red`, `door closes with click`, etc.)

**Fix template (v3)**:
- Before: `"She hands him the folio"`
- After: `"She extends the folio with both hands. He reaches forward, firmly grasps it with both hands. She releases her grip, her hands go empty and drop to her sides. He now holds the folio at chest level. The handoff fully completes."`

- Before: `"She walks back toward the train"`
- After: `"She walks back to the train, steps up into the carriage, disappears through the open doors, and the doors hiss closed behind her."`

- Before: `"The train pulls away"`
- After: `"The train pulls away to the LEFT, fully exits the frame, tail lights vanish into the dark tunnel."`

**Severity**: critical (the #1 root cause of observed AI video bugs in
Seedance — action describes begin-state, AI doesn't infer end-state, result
looks broken)

---

## R12. Prop Persistence Across Clips (CRITICAL)

**Added after:** v2 c04 Gemini finding — "The detective is no longer holding the folio. His hands appear empty." (despite Clip 3 ending with him holding it)

**What**: If a prop was introduced in an earlier clip and the character is
supposed to still have it, each subsequent clip's prompt must **explicitly
describe the prop as still in their possession** (Seedance doesn't assume
cross-clip prop persistence).

**Detect**: cross-clip semantic check:
- In Clip N: does the prompt mention a character receiving / holding / picking
  up a prop (`folio`, `glass`, `weapon`, `key`, `letter`, `phone`, `gun`, etc.)?
- In Clip N+1 / N+2...: is the character still "supposed to" have it (no explicit
  "drops it" / "hands back" between)?
- If yes: does the prompt for Clip N+1+ mention the prop still in hand / on
  character?
- If not → flag

**Fix template**: Add to Clip N+1 prompt opening:
```
@图片1 still holds the [prop] in his [right/left] hand from the previous scene
```

**Severity**: critical (prop vanishing is one of the most jarring AI video
failures; instantly breaks suspension of disbelief)

---

## R13. Shot-Type Precision — Framing Must Match Declared Vocabulary (MAJOR)

**Added after:** v2 c03 Gemini finding — "Shot 1 is a medium shot of the detective instead of the requested macro insert of his hands opening the folio"

**What**: If prompt uses a named shot-type vocabulary term that implies tight
framing, the supporting description must NOT contain wider-framing language
that contradicts it.

**Detect**:
- Named tight-framing terms: `微距缓推镜头` / `瞳孔放大镜头` / `insert shot` /
  `macro` / `extreme close-up` / `ECU` / `眼泪滑落镜头`
- Wider-framing contradictions in same shot: mentions of the character's
  full body, standing, walking, wide environment, other characters in frame
→ flag

**Fix template**: either escalate the wording (`EXTREME macro close-up filling
the entire frame on hands ONLY, no face visible, no body visible`) or
re-categorize to a wider vocab term.

**Severity**: major (produces "medium shot labeled as macro" — content
technically present but framing wrong)

---

## R14. AI Physical-Artifact Inoculation (MAJOR)

**Added after:** v2 c03 Gemini finding — "The leather folio morphs unnaturally as it opens, turning into a thick block of stiff pages"

**What**: Seedance (and most AI video models) have known failure modes for
specific objects/actions. Prompt should include inoculation language for
high-risk elements.

**Known failure-prone elements and their inoculation phrases:**

| Risk object / action | Inoculation language |
|---|---|
| Hands (morphing, extra fingers) | "anatomically correct hands, five natural fingers, no morphing" |
| Paper / books / pages | "real paper with natural flexibility, pages bend softly, not stiff cardboard" |
| Eyes (misaligned, duplicated) | "two natural eyes in correct position, anatomically accurate gaze" |
| Small props with complex form | "realistic [object], natural construction, consistent shape throughout" |
| Text / signage / writing | "avoid text and readable writing, abstract marks only" (Seedance can't render text reliably) |
| Mirrors / reflective surfaces | "correctly-oriented reflection matching the real scene" |
| Water / fluid / rain | "physically realistic [water/rain] with gravity and proper motion" |

**Detect**: prompt mentions risk elements (hands in close-up, paper objects,
complex props) without matching inoculation phrase.

**Fix template**: append inoculation line at end of shot description for
relevant risk elements. Example for c03 folio:
```
...hands slowly open the cover of a realistic dark leather folio. Real paper
pages inside turn naturally as the cover tips back. Anatomically correct
hands with five natural fingers, no morphing. Folio is a natural leather
object with soft binding, pages are thin and flexible like actual paper.
```

**Severity**: major (visible artifacts that immediately look AI-generated)

---

## Updated rule application order

When running Phase 1 Pre-check, run in this order (earlier rules are critical
pre-reqs; later are polish):

1. R9 (fl2v two-humans) — fail-fast
2. R10 (reference order) — fail-fast
3. R11 (action completion) — **new, most critical narrative issue**
4. R12 (prop persistence) — **new, most critical continuity issue**
5. R1 (axis) — critical physical rule
6. R3 (physical geometry) — critical
7. R2 (cross-clip state handoff) — critical, requires full production context
8. R13 (shot-type precision) — major
9. R14 (physical-artifact inoculation) — major
10. R4, R5, R6, R7, R8 — polish

If any critical flagged → STOP. Show user the report, wait for approval.

## R15. Chain vs Parallel — Visual Dependency Decision (CRITICAL)

**Added after:** v2 30s and 45s boundary findings — Gemini flagged cross-clip state inconsistencies (Woman not seen completing exit, folio disappearing) that were caused by running all clips in parallel instead of chaining the ones with visual dependencies.

**What**: Determine for each adjacent clip pair whether the **later clip has visual dependency on the earlier clip's generated output**. If yes, it must be serially chained (wait for N → extract-frame → use in N+1), not submitted in parallel.

**Detection (per clip pair N → N+1)**:

Evaluate these conditions:
1. **Same shot size and angle?**(e.g. both are MS on the same subject from same direction)
2. **Same scene continues?**(same location, same characters in same relative positions)
3. **Prop state dependency?**(a character holds a prop at end of N and is supposed to still hold it at start of N+1)
4. **Eye-line / character pose continuity?**(正反打 reverse shot requires same characters in relative positions)

If ANY of above is true → **`transition_type: serial_chain_required`**. Flag.

If all false (scene jump, angle big-jump, flashback, etc.) → `transition_type: parallel_ok`.

**Fix template** (when flagged):

Annotate the clip plan:
```
Clip N+1:
  transition_from_prev: "continuous" | "reverse" | "prop_handoff" | "same_shot_type"
  requires_tail_frame: true
  workflow_note: "Must wait for Clip N to finish, then /extract-frame which=last, then add to reference_image_urls or set as first_frame_url."
```

Update the main skill's generation pipeline to:
1. Group clips by parallel eligibility
2. Submit parallel groups concurrently
3. Wait for each serial-chain group: N → extract → N+1

**Severity**: critical (causing ~30% of observed cross-clip bugs in dogfood — far more impactful than axis-break or pacing alone)

---

## Future rules (to add as new bugs surface)

- R16: Lighting direction consistency across shots
- R17: Sound / dialogue reference sanity
- R18: Genre-tone consistency
- R19: Dynamic range / contrast warnings

## Rule library evolution log

| Version | Rules | Added based on |
|---|---|---|
| v1 | R1-R10 | 《末班车》v1 (10×5s) observed bugs + general AI video theory |
| v2 | R11-R14 added | 《末班车》v2 (4×15s) Gemini audit findings |
| **v3** | **R15 added** | **User insight: parallel submission vs visual-dependency chaining. Validates via《末班车》v2's 30s/45s boundary bugs being caused by parallel-only generation** |

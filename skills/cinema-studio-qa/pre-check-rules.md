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

**R11.2b Scene-blueprint cross-check** (when a Phase 0 blueprint exists for
the scene, i.e. `scene_<id>.blueprint.json`): parse the prompt's spatial /
motion claims and verify against the blueprint:
  - Any character exit/entry must match a `entry_exits` entry — if prompt
    says "exits to screen-left" but blueprint left_of_frame is
    `blocked_paths: cannot walk through left wall`, flag **critical**.
  - Any vehicle / transport motion must obey `physical_rules`(e.g. train
    arriving from direction that contradicts track position).
  - Lighting direction in the prompt must match `light.primary_direction`
    across all clips in the same scene — contradicting shots cause
    continuity breakage.
  - Props that appear in prompt but are not in `props_present` are fine
    (character can bring props in); but props claimed to stay in scene
    between clips must be in `props_present`.

This check is the main reason Phase 0 exists — without the blueprint, Claude
writes prompts in a spatial vacuum and the generator fills in arbitrarily.

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

**Added after v2 boundary bugs. REFINED v4 after user production insight:**
> "全能参考一般会从上一段抽帧,但不一定都是尾帧。一般为了两段能接得上,下一段首帧会直接切上一段尾帧出现的人物以外的人物。正常短剧抽帧挺多的,一般用来交代人物姿势或者人物站位。"

**What**: When Clip N+1 has visual dependency on Clip N's output state, extract
a frame from N (not necessarily the tail) and **use as a scene-state reference
in N+1**, NOT as a mechanical first-frame chain. Critically: N+1's opening
shot should **cut to a different subject** than the reference frame's
subject — this is how editing actually works in real drama.

### Detection (per clip pair N → N+1)

Evaluate these conditions:
1. Same shot size and angle across cut?
2. Same scene continues?
3. Prop state dependency?
4. Eye-line / character pose continuity?
5. **Progressive physical state change?** (door opening gradually, light
   dimming, character changing position in small increments)
6. **New detail introduced in N must persist in N+1?** (blood stain
   appears in N, should still be there in N+1)

If ANY true → **`transition_type: chained_with_reframe`** (not just "chained").

### Decision matrix — whole-production chain vs parallel vs partial

For a production with N clips, decide at Phase A editing plan level:

| Scenario | Recommendation | Reasoning |
|---|---|---|
| All clips in SAME location with progressive state(door opens gradually, character ages, object degrades) | **Full chain** (s1 → s2 → s3 → ...) | State carries reliably only via extracted-frame refs |
| All clips in SAME location, no progressive state(same scene, different camera angles) | **Partial chain**: only the pairs with character/prop state handoff | Characters + location refs hold consistency; chain only when state changes |
| Clips span MULTIPLE locations, no cross-location carry | **Parallel for independent clips** + **chain within each location cluster** | Inter-location state doesn't matter; intra-location does |
| Single action performed across multiple clips(folio handoff over 3 shots) | **Full chain** | Prop ownership state is load-bearing |
| Multiple independent scenes(anthology style, no returning characters) | **Fully parallel** | No state to carry |
| **2-character dialog drama in 1 location**(e.g.《Room 207》) | **Full chain recommended** | Door / facial expression / micro-state all progressive |

### Time-vs-quality tradeoff

| Strategy | Time | Boundary quality | Cost |
|---|---|---|---|
| Fully parallel (8 clips ~ 6 min) | Fastest | Risky on state transitions | Cheapest |
| Partial chain (chain 2-3 critical pairs, parallel rest) | Medium (10-15 min) | Good on critical, okay elsewhere | Same as parallel |
| Full chain (sequential) | Slowest (20+ min for 4 clips) | Cleanest | Same credit cost |

**Rule of thumb**:
- Budget ≤ $10, ≤4 clips, strong state progression → **full chain**
- Budget > $20, ≥6 clips, 2+ locations → **partial chain** (chain only intra-location high-state-progression pairs)
- Anthology / independent beats → **fully parallel**

### Partial chain concrete example

For an 8-clip production with 2 locations (4 in garage, 4 on rooftop):
- Garage cluster s1-s4: chain s1→s2→s3→s4 (character+motorcycle state progressive)
- Rooftop cluster s5-s8: chain s5→s6→s7→s8 (phone state progressive)
- Between clusters s4 → s5: **bridge clip** (per R25) + parallel OK for bridge

Total chain pairs: 6 (3 intra-garage + 3 intra-rooftop). Parallel: 0. Bridge: 1.
Time ~30 min vs parallel ~10 min, but state integrity preserved.

### Correct workflow (pro-grade, per user insight)

```
Clip N 生成完
  ↓
/extract-frame(which=last 或中间 frame — 选最能表达"场景状态"的那帧)
  ↓
提交合规库 → 等 compliant
  ↓
2 种用法(优先 a):

(a) 放 reference_image_urls[-1] — 作场景状态 ref,推荐默认
(b) 放 first_frame_url — literal 起始帧,**仅在要求画面直接从那帧动起来时用**

  ↓
Clip N+1 prompt 里显式标注:
  "Reference image N is the tail state of the previous scene. Scene
  continues from this state. Clip OPENS by cutting to [different
  character / closer framing / new angle] than the reference's
  primary subject."
  ↓
Clip N+1 的第一个内部 shot 必须是不同主体 / 不同景别 / 不同 POV
```

### 为什么不是机械 first_frame_url 链接

电影剪辑法则:**同景别同人物连切 = jump cut(跳切,烂剪辑)**。切到不同主体 / 景别 / POV = 合理剪辑。

用尾帧直接作 `first_frame_url` 的问题:
- Seedance 会在头 1-2 秒"保留上段结尾的主体"(因为 first frame 强制它从那开始)
- 等于让观众多看一遍已经看过的内容,浪费时长
- 视觉体验像"逐帧续播"而非"shot 切换"

用尾帧作 `reference_image_urls`(状态 ref)的好处:
- Seedance 理解"场景状态是这样的",但**不强制起始画面**
- 新 clip 可以直接开场切到另一人物 / 另一角度
- 视觉体验是"cinematic cut",match on action

### 抽帧的主要用途(实战)

- **交代人物站位**:上一段结束时 Julian 站右,Woman 下车后走右;新 clip 起步就知道位置
- **传递 prop 状态**:Julian 手里同一个 leather folio 要跨 clip 保持
- **锁环境**:wet tile, mist, 列车位置,不因新生成而漂移

### Fix template (when flagged)

Annotate clip plan:
```yaml
Clip N+1:
  transition_from_prev: "reframe_chained"
  tail_reference_from: Clip N (extract-frame which=last or best-state-frame)
  tail_reference_usage: reference_image_urls  # default, unless first_frame justified
  opening_cut: "cut to [different subject from reference]"
```

Update main skill's generation pipeline:
1. Identify chained-with-reframe pairs
2. Wait for Clip N → extract-frame → compliance-check-by-url
3. Add to Clip N+1's reference_image_urls (not first_frame_url by default)
4. Clip N+1 prompt explicitly states "reference N is tail of previous scene, continue state but cut to different subject"
5. Submit Clip N+1

### Severity

Critical. **V4 dogfood c01→c02 used first_frame_url mechanically; observe if
opening is awkward. v3 all-parallel caused prop drift. Correct middle way
is reference-image + cut-to-different-subject.**

---

## R16. Cross-Shot Action Continuity — Absolute Position + Explicit Negation (MAJOR)

**Added after:**《末班车》v5 c02 v2 dogfood — observed that when clip's Shot 2
opens with Woman at train door (contradicting Shot 1 where she was already
walking on platform), Seedance had literally interpreted "Woman 从 RIGHT
走入画面" as "walks in from RIGHT direction(= train side)= just exited
train". Also the ref_image_urls[last] showing Woman near train doors was
tug each shot back to that position.

### What

Every internal shot within a multi-shot clip must describe the character's
**starting position absolutely**, not as a relative direction, AND if the
character has an alternate plausible starting state (e.g. "just exited
train"), **explicitly negate** it.

### Detection checklist

For each shot N ≥ 2 in the prompt, check:

1. **Is starting position absolute?** "X 已站在 Y 前 1 米处" ✓ vs "X 从
   RIGHT 走入画面" ✗
2. **Does any relative direction reference a location where the character
   could plausibly originate?** If "RIGHT" = tracks / train doors / entry
   point, then "X 从 RIGHT 走入" will be read as "X 刚从那边出来".
3. **Does ref_image_urls contain a state the prompt does NOT want reused?**
   If ref shows Woman at train door but shot 2 wants her on platform mid-walk,
   the ref will tug toward "at door" state → needs explicit negation.
4. **Has the prompt explicitly negated alternate start states?** "她不从车里
   出来 / She is not exiting the train" ✓ if ambiguous.

### Fix template

For each shot N ≥ 2:
```
shot_N:
  position_anchor: "X 已在 [绝对坐标 / 相对 Y 的具体距离] 处 [停 / 站 / 坐]"
  negation_if_needed: "X 不 [在 A 状态], 不 [在 B 位置]"
  action: "X [当前动作], continuing from the established position"
```

### Severity

Major. Without this rule, cross-shot temporal order can break (e.g., Shot 1
character walking → Shot 2 character emerging from origin = time loop).
Very noticeable; Gemini may not always flag it because internal shot
composition reads coherent frame-by-frame.

### Bonus: ref_image_urls tug strength

Seedance 2.0 uses ref_image_urls for character appearance AND tends to pull
each internal shot's subject placement toward the ref image's implied state.
**If you use a ref image showing X in position P**, every shot's X tends
toward P unless prompt explicitly says otherwise.

---

## R18. Physical Destruction Actions Need Dedicated Slow-Mo Shot (MAJOR)

**Added after:** 2026-04-18 drama validation test where Seedance was asked
to show a paper bag bursting and items falling; it skipped the physics
and let the items "magically appear" on the ground. Gemini flagged this
as `major` action_completion failure.

### What

Seedance 2.0 defaults to skipping frame-by-frame physics for destructive
actions (tearing, falling, breaking, shattering, spilling). It renders
the **before** and **after** state correctly but may skip the **during**
action entirely. Items can teleport, bags can vanish, glass can shatter
without arc, etc.

### Detection

If the scene contains any destructive action verbs, flag:
- `撕裂 / 破 / 裂 / 碎 / 爆 / 崩 / 塌`
- `tear / rip / break / shatter / explode / collapse`
- `掉落 / 滑落 / 溅 / 倾泻` + multi-object
- `drop / fall / spill / splash` + multi-object

Then check: does the prompt dedicate a **slow-motion macro shot** to
the destruction action, or is it described inline in a wide shot?

### Fix template

If destruction matters narratively → dedicate a shot to it:
> ✅ "slow motion macro insert: 纸袋底部在 2 秒内逐渐被水浸透撕裂,苹果最先
> 冲破袋底缓慢下落,水花在接触瓷砖瞬间溅起。画面只有袋子、苹果、瓷砖,无
> 其他元素"

If destruction is not narratively important → just describe the end state:
> ✅ "地面上散落苹果、三明治、酸奶瓶,湿纸袋残片飘在附近"

### Severity

Major. Destruction physics is a Seedance known blind spot. Don't rely on
inline prompt language — either dedicate a shot or skip the process.

---

## R19. Style Override — 2D Anime Requires Reference Images (CRITICAL for anime)

**Added after:** 2026-04-18 anime validation test where prompt specified
"MAPPA cinematic cel-shaded anime, bold outlines, dynamic action lines"
and Seedance **rendered photorealistic live action** instead. Gemini
flagged as `critical`.

### What

Seedance 2.0's training set skews heavily toward photorealistic /
cinematic live-action output. Text-only style directives like "2D
cel-shaded", "MAPPA vibe", "anime style", "manga aesthetic" get
**overridden** in favor of photoreal output. Negative prompts could
suppress this, but **Seedance doesn't support `negative_prompt`**.

### Detection

If prompt declares 2D / anime / cartoon / cel-shaded / manga style AND
the skill is set to Seedance, flag `critical` pre-emptively and require
one of these mitigations:

### Mitigation paths (in priority order)

1. **BEST: Switch to Kling skill.** Kling 2.0+ supports `negative_prompt`
   and has stronger 2D style steering. Anime productions default to Kling.

2. **If Seedance is required**: use 2D anime reference images in
   `reference_image_urls`. ≥2 refs:
   - character ref: already 2D cel-shaded rendered
   - scene ref: already 2D anime background

3. **Last resort**: stack style keywords AND remove photoreal descriptors:
   - Add: `cel-shaded 2D animation, bold black outlines, flat color shading,
     MAPPA studio signature, hand-drawn feel`
   - Remove: any mention of "photorealistic", "film grain", "cinematic",
     "realistic skin", "bokeh", "35mm", "IMAX"
   - Accept: ~50% success rate, likely still gets photoreal

### Severity

Critical for anime productions. Major for stylized (watercolor / comic /
impressionist) productions. Minor for "slightly stylized" (color grading)
where photoreal base + LUT-like style applies.

---

## R17. Post-Exchange Prop State Reset (MAJOR)

**Added after:** User observation during《末班车》v5 dogfood — "女的把文件
给了男的,但是手里还有文件,拿着离开了"(Woman hands file to man, but she
still has the file in her hands and walks away with it). Classic bug: prop
ownership is not "transferred" in Seedance's latent state after an
exchange — the character who "originally had" the prop continues carrying
a phantom copy in subsequent shots.

### What

When a prop exchange happens (A → B) mid-clip or cross-clip, Seedance's
default is to preserve BOTH characters' established "has-prop" state. To
prevent a duplicate object / phantom prop:

**Every exchange must be declared as a DOUBLE state update, not a single
transfer.** Both sides need explicit post-exchange state language.

### Three failure modes

1. **Duplicate object (clone)**: Seedance spawns a second folio for the
   giver in the next shot because "Woman has folio" is a stable trait.
2. **Ref-image tug**: if `reference_image_urls` shows the giver holding
   the prop, every shot pulls the giver back to "has prop" state.
3. **Training bias**: "woman + bag walking" is so common that the model
   defaults to re-attaching props to their established holder.

### Detection checklist

For every clip/prompt that contains a prop exchange verb (`hands over,
gives, passes, transfers, drops, delivers, throws, catches, takes,
accepts, releases, grabs`):

1. Is the **receiver's post-exchange state** explicit?("Julian's hands
   now firmly grip the folio at waist" ✓ vs just "Julian accepts it" ✗)
2. Is the **giver's post-exchange state** explicit?("Woman's hands
   empty, hanging at her sides" ✓ vs just "Woman turns away" ✗ — she'll
   turn away WITH a phantom copy)
3. Does the next shot after the exchange open with the **giver explicitly
   empty-handed / prop-free**?
4. Does `reference_image_urls` show the giver with the prop? If so,
   explicit negation is mandatory:"Woman no longer holds anything, her
   hands are empty, she does not carry anything out of the train car."

### Fix template

Replace single-sided transfer language with double state update:

> ❌ "Woman 递出 folio,Julian 接过。Woman 转身回到车门。"
>
> ✅ "Woman 递出 folio,Julian 双手从 Woman 手中接过并稳稳握住;**Woman
> 双手完全松开,folio 已不在她手中,她的双手空空如也,自然垂在身侧**。
> Woman 转身空手回到车门。"

For cross-clip exchanges, the next clip's first shot must open with:

> "Woman 此时双手空空,folio 已转移到 Julian 手中并仍在他手中。Woman 不再
> 持有任何物品。"

### Bonus: phantom-prop spread through ref_image_urls

If you use the exchange clip's tail frame as ref for the next clip, AND
the tail frame shows the prop ambiguously positioned (e.g. between both
pairs of hands), Seedance may re-spawn it for the wrong person next clip.
**Choose tail frames where prop ownership is visually unambiguous**, or
use an earlier frame where the transfer has clearly completed.

### Severity

Major. Creates a "magic duplicate" effect that's instantly noticeable to
viewers and breaks narrative logic (the whole point of the handoff was
the transfer!). Often paired with action_completion failures.

---

## R20. Iconic Character Archetype Triggers Content Filter (CRITICAL)

**Added after:** 2026-04-18 "The Drop" Phase 3 integration test, scene 2.
Prompt described the buyer as "mid-40s, tall, charcoal three-piece suit,
black dress shoes, dark wide-brim fedora casting shadow over his eyes,
leather gloves, trimmed dark goatee" — a precise match for Michael
Corleone / Godfather / classic noir gangster archetype. Ark (Seedance
2.0's backend) **rejected the generation with error:**
> "The request failed because the output video may be related to
> copyright restrictions."

255 credits charged on the failed request.

### What

Ark's content filter rejects prompts that produce output too close to
copyrighted iconic characters. Common triggers observed:
- **Godfather**: fedora + three-piece suit + goatee + shadow-over-eyes
- **John Wick** (high risk): black suit + silver pompadour + perfectly
  trimmed beard + tactical gloves
- **Joker** (very high risk): smeared red-white-green makeup + purple suit
- **Batman / superhero** (high risk): full black mask + cape
- **Anime main characters**: "spiky yellow hair teen" → Naruto; "white
  haired swordsman" → InuYasha etc.

The filter triggers on **visual-archetype specificity**, not explicit
character names. You can say "Godfather-style" and the filter might let
it pass as stylistic intent; you CANNOT describe the exact costume
combination that makes an iconic character recognizable.

### Detection checklist

Before submitting, scan the character visual_description for:

1. **Hat + suit + facial hair combos** that match famous characters:
   - fedora + three-piece + goatee → Godfather
   - bowler hat + suit + bowtie → A Clockwork Orange Alex
   - pirate hat + tricorne + beard → Pirates of the Caribbean
2. **Mask / full-face disguise** with specific color schemes:
   - white/red smile mask → Saw, Purge
   - porcelain white + painted red lips → various horror icons
3. **Brand-specific clothing descriptions**:
   - "red superhero suit with S logo" → Superman
   - "black suit with bat symbol" → Batman
4. **Hair + body-type + era combos** matching historical figures:
   - "tall, gray hair, Roman toga, Julius Caesar-like" → historical icon

### Fix template

Replace specific archetypes with **generic but equivalent mood-carrying
descriptors:**

| ❌ Iconic trigger | ✅ Generic equivalent |
|---|---|
| "fedora + three-piece suit + goatee" | "plain dark wool beanie + long black wool coat + stubble" |
| "red superhero suit with S logo" | "bright red athletic compression suit, no logos or insignia" |
| "samurai katana + topknot + kimono" | "martial arts practitioner with practice sword, tied-back dark hair, traditional training uniform" |
| "pirate hat + eye patch" | "weathered cloth cap + scarred face, no eyepatch" |

Keep the **mood/role** (mysterious buyer, heroic figure, dangerous warrior),
change the **iconic visual combination** that triggered the filter.

### Severity

**Critical pre-emptively**. The cost is 255+ credits per rejection (Ark
charges partial cost on rejection), plus time lost. Better to flag in
pre-check and rewrite than to submit and get filtered.

### Observed behavior

Ark's filter is more aggressive than Kling's; same character description
that triggers in Seedance may pass in Kling. If a buyer/villain character
is critical to the script and keeps getting filtered, **consider switching
to Kling for that clip**.

---

## R21. Crime-Associated Vocabulary Triggers Ark Content Policy (MAJOR)

**Added after:** 2026-04-18 "Courier Chronicles" 8-clip regression test,
scene 6. Prompt used phrases "burner phone" + "未知来电"(unknown call)
plus noir narrative framing of a tense phone pickup. Ark rejected with:
> `error: "policy_violation_output"`

This is a **different filter** from R20 (copyright). R20 fires on iconic
visual archetypes; R21 fires on **narrative vocabulary associated with
crime, drugs, weapons, or illicit communications**.

### What

Ark's content policy scans prompt text for words/phrases that map to
criminal/illicit contexts and refuses to generate output that reads as
promoting those activities. The filter is semantic, not keyword-exact —
it reads intent from the phrase combination.

### Common triggers observed or expected

- **Communication-illicit**: "burner phone", "未知来电" + clandestine
  handoff context, "throw away sim", "encrypted call"
- **Drug-associated**: "handoff", "drop" + product, "gram", "kilo",
  "stash", "deal"
- **Weapon-adjacent**: "silencer", "drawing a weapon", "finger on
  trigger", detailed firearm descriptions
- **Violent vocabulary**: "stab", "shoot", graphic fight wounds, blood
  pooling descriptions
- **Illicit-commerce**: "cash drop", "black market", "underground deal"

Note: Seedance is OK with **atmospheric noir**(a mysterious exchange,
a silent handover, a rainy alley) but trips on **explicit criminal
framing**(naming the transaction as illegal, using the specialist
vocabulary of the trade).

### Detection checklist

Before submitting a noir/thriller/crime prompt:

1. Scan for the trigger word list above.
2. If any hits, consider whether the word is **load-bearing**(the scene
   genuinely needs that word) or just atmospheric (a neutral equivalent
   would serve). Use neutral equivalents where possible:
   - "burner phone" → "vintage flip phone" / "老式翻盖手机"
   - "未知来电" → "来电" / "incoming call"
   - "cash drop" → "exchange" / "meeting"
   - "underground deal" → "private meeting" / "quiet exchange"
3. If the trigger word is truly load-bearing (crime drama's whole point),
   switch to Kling skill — Kling's content policy is more permissive
   than Ark's.

### Observed

The s6 retry with "vintage flip phone" + "incoming call"(instead of
"burner phone" + "未知来电") passed without filter issue — atmosphere
preserved, vocabulary neutralized.

### Severity

Major pre-emptively. Filter rejection costs ~255 credits per attempt.
A noir production is especially prone since the genre is built around
crime narrative — proactively neutralize vocabulary, don't pay 255
credits to discover the filter.

---

## R22. Multi-Clip Productions MUST Use Reference Images (CRITICAL)

**Added after:** 2026-04-18 "Courier Chronicles" 8-clip regression
test. The 120s film concatenated 8 individually-generated clips via
text-only t2v (no `reference_image_urls`). User's first-viewing
feedback: "这个整体是一个故事吗?怎么感觉每个镜头都是不太一样的呢?
我没看出这个是什么故事。"

Verified: s1 Courier was a long-ponytail woman on a sport motorcycle;
s5 "Courier" was a short-haired figure (possibly different gender) on
a completely different classic motorcycle. Two locations that should
have been the same garage / same rooftop instead rendered as 4+
independent imaginations.

### What

When a production has >1 clip and features any recurring character,
location, or prop, **the same `reference_image_urls` MUST be passed
to every clip's `/generate-video` payload**. Text-only t2v without refs
causes Seedance (and Kling) to regenerate each clip's character from
scratch — they will have different faces, different body types,
different clothing fit each time, even with identical text descriptions.

Same applies to locations. "Underground parking garage with graffiti"
text will render as 4 totally different garages across 4 clips.

### Detection

Before Phase G generation, ensure for each clip:

1. Every **named character** appearing in the clip has a
   `reference_image_urls` entry pointing to the master character ref
   image (generated in Phase C, or user-supplied).
2. **Location ref image** is included in `reference_image_urls` for
   any recurring location (at minimum, the first time the location
   appears; subsequent clips in the same location either reuse the
   same location ref OR use a frame extracted from the previous clip
   in the same location via `/extract-frame` per R15).
3. If the clip uses multiple refs, the `@图片N` syntax in the prompt
   maps to `reference_image_urls[N-1]` by index. Be strict about the
   order.

### Fix when caught in pre-check

If prompt has no `reference_image_urls` but the production has ≥2
clips with recurring character/location:

1. **Block submission**. Do NOT let the clip go through — the output
   will not be usable as part of a coherent film.
2. **Go back to Phase C**: generate character ref via
   `POST /generate-character`, location ref via `POST /generate-scene`
   (or similar for the provider).
3. **Run compliance** (`POST /api/compliance/check-by-url`) for each
   ref. Poll until compliant.
4. **Re-submit Phase G** with refs in every payload.

### Cost implication

Phase C adds cost for ref generation (~30-50 credits per ref × 2-5
refs = ~100-250 credits), but SAVES the 2000+ credits that a
regenerated-due-to-incoherence production would cost. Ref generation
is mandatory overhead for any multi-clip film, not an optional step.

### Observed from Courier Chronicles

- Text-only 8 clips at $12.93 produced a visually stunning but
  narratively incoherent "mood reel" not a short film.
- Estimated added cost for proper Phase C: ~200 credits (~$1) for
  2 characters + 2 locations. Total would be ~$14 for a coherent
  120s film.
- Savings from skipping Phase C: ~$1. Cost of unusable output:
  entire $13. Net: skipping Phase C is always a loss.

### Severity

**Critical**. Multi-clip production without character/location refs
produces artistically strong but narratively broken output. This is
not a style preference — it's a non-negotiable requirement for
coherent film output.

---

## R23. ALWAYS Send `raw_prompt: true` for Structured Shot Prompts (CRITICAL — the big one)

**Added after:** 2026-04-18 Phoenix codebase review triggered by user
hypothesis: "Phoenix 后端有 llm 增强,是不是 seedance 的 llm 增强反而让
提示词信息没有了". Subagent code review at
`apps/api/src/services/cinema_service.py:278-299` confirmed: when
`raw_prompt=false` (default), Phoenix routes the user's prompt through
`ArkVideoProvider.translate_prompt()` →
`seedance_shot_llm.enhance_seedance_shot()` → Gemini Flash rewrites it
into a **single unified cinematic description** using the 6-step
Seedance formula (subject/action/environment/camera/style/constraint).

The user's structured `[00:00-00:05] 镜头1: ... [00:05-00:10] 镜头2:
...` blocks get **collapsed into one continuous narrative**. The
original prompt is stored in `cinema_generations.keyword`; the rewritten
version is stored in `secret_prompt` and is what Seedance actually
receives.

This explains ALL prior single-shot failures in Phase 2-3 validation:
- 末班车 c04 "isolation" single shot
- Drama/jazz tests single shot  
- 5 of 8 Courier Chronicles clips single shot
- Same prompt structure producing different results on retry (the LLM
  rewrites differently each time — output is stochastic not because of
  Seedance, but because of Phoenix's enhancer)

### What

For any prompt that uses structured per-shot markers (timestamps,
`镜头1:`, `[00:XX-YY]`, `Shot N:`, etc.), set `raw_prompt: true` in
the `POST /api/cinema-studio/generate-video` payload. This skips
Phoenix's LLM enhancer and passes the prompt verbatim to Seedance/Ark.

### Detection

Before submitting any multi-shot or structurally-dependent prompt
(including any prompt where you rely on R1 subject diversity), verify:

1. Payload includes `raw_prompt: true`? If missing → critical fail.
2. Response has `prompt_mode: "raw"`? If `"smart"` → enhancement ran,
   my prompt was rewritten, result won't match intent.

### When NOT to use raw_prompt

For **single-subject single-shot natural-language prompts** (e.g. "A
dramatic wide shot of a city skyline at sunset"), the LLM enhancer
actually helps — it adds the mandatory anti-subtitle directives
("clean frame, no captions, no on-screen text"), which Seedance
requires to avoid random subtitle artifacts. raw_prompt skips this
layer too.

If you use `raw_prompt: true`, you MUST include in your prompt:
> "clean frame, no subtitles, no captions, no on-screen text, no
> watermark, no overlay graphics"

to prevent Seedance from auto-adding subtitles.

### Severity

Critical. The LLM enhancer destroys 100% of structured shot intent.
This rule supersedes R1's hardened "adjacent shots different primary
subject" rule — without raw_prompt, R1 compliance in the user prompt
is moot because the LLM flattens the structure before Seedance sees it.

### Key citations (Phoenix codebase, 2026-04-18)

- `apps/api/src/schemas/cinema_studio.py:57` — `raw_prompt: bool = False`
- `apps/api/src/services/cinema_service.py:278-299` — branching on `raw_prompt`
- `apps/api/src/adapters/video_providers/ark.py:127-210` — `ArkVideoProvider.translate_prompt()`
- `apps/api/src/services/seedance_shot_llm.py:338-399` — `enhance_seedance_shot()`
- `apps/api/tests/test_cinema_raw_mode.py:87` — confirms raw mode bypasses translate

### Observed DB fields

- `cinema_generations.keyword` — user's original prompt
- `cinema_generations.secret_prompt` — LLM-rewritten version (what Seedance received)
- `cinema_generations.prompt_mode` — "smart" (enhanced) or "raw" (verbatim)

To verify enhancement happened on a past generation, query:
```sql
SELECT keyword, secret_prompt, prompt_mode FROM cinema_generations WHERE id = '<gid>';
```

---

## R24. Recurring Props Need Their Own Reference Image (MAJOR)

**Added after:** 2026-04-18 user viewing feedback on《Courier Chronicles》
v2: "摩托车离开了两次". Verified: s1 shows Honda CBR sport bike, s3
shows classic cafe racer, s4 shows BMW boxer cruiser — three completely
different motorcycles ridden by the same Courier across consecutive
clips. v2 Phase C generated refs for Courier + Buyer + garage + rooftop,
but skipped the motorcycle — so Seedance regenerated the bike each
time.

### What

R22 required character + location refs. R24 extends this: **any prop
that appears in ≥2 clips AND whose visual identity matters to the
narrative needs its own reference image** in Phase C.

Examples:
- Motorcycle / car / any vehicle
- Weapon (gun / katana / sword)
- Musical instrument
- Recognizable costume piece (if used outside the character ref sheet)
- Distinctive piece of jewelry
- Any prop exchanged between characters (briefcase, folio, letter, key)

Note: the briefcase in《Courier Chronicles》DID stay consistent without
a dedicated ref because it appeared in only one clip (s2). But the
motorcycle appeared in 5+ clips and drifted. Rule of thumb: **prop
appears in 2+ clips → needs ref**.

### Phase C expansion

When generating Phase C assets, enumerate all props with ≥2-clip
appearance AND generate a ref image for each:

```bash
# Prop ref generation (uses same generate-location endpoint, prompt
# describes the prop on a neutral background):
curl -X POST /api/cinema-studio/generate-location \
  -d '{"prompt": "Matte black Honda CBR sport motorcycle, studio product shot, neutral gray backdrop, multiple angles: front 3/4, side profile, rear 3/4. Photorealistic, cinematic lighting.", ...}'
```

### Ref image order in reference_image_urls

Canonical order when clip uses character + location + prop:
```
[character_refs..., prop_refs..., location_ref]
```

With `@图片N` tokens:
- `@图片1` = Courier (character)
- `@图片2` = motorcycle (prop)
- `@图片3` = garage (location)

### Severity

Major. Prop drift is visually jarring for viewers — immediately breaks
suspension of disbelief.

### Cost

~30-50 credits per prop ref (~$0.15-0.25). For a production with 2-3
recurring props, ~$0.75 added to Phase C budget. Saves re-shoots.

---

## R25. Location Transitions Need Narrative Bridging (MAJOR)

**Added after:** 2026-04-18 user viewing feedback on《Courier Chronicles》
v2: "场景连贯性不够...场景的变化". Verified: s4 ends with Courier
riding motorcycle out of garage tunnel. s5 opens with Courier already
parked on rooftop. No physical bridge between locations — it's a hard
cut that feels teleportation-like.

### What

When the script crosses between two locations (e.g. garage → rooftop,
bar → street, indoor → outdoor), the edit needs either:

1. **Bridge clip**: a 5-15s shot showing the character's journey
   between locations (driving through streets, walking into elevator,
   emerging from doorway). Explicit physical transit.
2. **Time-cut signal**: if no bridge, the incoming scene must have an
   explicit "later" / "much later" / time-of-day change signaled
   visually (different weather, different light, time indicator on
   clock). Viewer reads it as "time passed, location changed".
3. **Match-cut hook**: match an element across locations (a spinning
   object → a spinning rooftop fan; a closing door → a door opening
   elsewhere). Requires precise cross-clip planning.

Without at least one of these, consecutive clips in different locations
**register as jump cuts / unexplained teleportation**, regardless of how
visually beautiful each clip is individually.

### Detection (during Phase A script parsing)

For each adjacent scene pair, check if `location_ref` differs. If yes,
check the transition strategy:

```python
if scene_N.location_ref != scene_N+1.location_ref:
    assert scene_N+1.transition in {
        "bridge_clip_before",
        "time_cut_signaled",
        "match_cut_to_prev",
    }, "R25 violation: location jump without bridging"
```

### Fix templates

**Option 1: insert a bridge clip before the location change.**
```
Scene N: Courier in garage, exits on motorcycle.
Scene N+1 (BRIDGE, 10s): Motorcycle speeds through rainy empty
  streets of the city, long tracking aerial. Shows transit between
  locations. No dialogue.
Scene N+2: Courier already parked on rooftop, walks to edge.
```

**Option 2: time-cut with visual indicator.**
```
Scene N ends: Courier rides motorcycle out of garage into dawn light.
Scene N+1 opens: Deep midnight now. Courier on rooftop, rain heavy —
  the lighting / weather change signals "later that night".
```

**Option 3: match cut.**
```
Scene N ends: ECU on motorcycle wheel spinning.
Scene N+1 opens: ECU on rooftop HVAC fan blade spinning, match cut.
```

### Cost tradeoff

Bridge clips add $0.85 each (Seedance 2.0 @ 480p 15s). For a 2-location
production (2 bridges), +$1.70 total. Time-cut signals and match cuts
add 0 cost but require more prompt-writing discipline.

### Severity

Major. Story becomes incoherent without resolved transitions even if
individual clips are masterpieces.

---

## R26. Editing Plan Must Be Produced in Phase A, Before Any Asset Generation (CRITICAL)

**Added after:** 2026-04-18 user feedback on Courier Chronicles v2:
"整部剧那你在最开始做的时候也要考虑到剪辑方案呀" — the editing/montage
plan should be decided **before** generation starts, not patched in
after the fact. The v2 failures (motorcycle leaves twice, hard cut to
rooftop, no bridging) all trace back to me writing scene prompts
without first drafting a cut plan for the whole film.

### What

Phase A (script parser) must produce TWO artifacts, not one:

1. **`scene_list.json`** (already specified) — scenes, characters,
   props, continuity requires.
2. **`editing_plan.md`** (NEW) — how scenes connect, pacing, transition
   types, cross-clip prop handoffs, which beats are redundant and
   must be merged.

### Required sections in `editing_plan.md`

```markdown
# Editing Plan — <title>

## Total runtime target
<e.g. 120s>

## Scene sequence with transitions
1. s1 Arrival (15s) — HARD CUT to s2
2. s2 Exchange (15s) — HARD CUT to s3
3. s3 Mount+Ignite+RideOut (15s, MERGED from draft s3+s4) — BRIDGE clip to s5
4. bridge (15s) — transit shot, garage exit → rooftop parking
5. s5 Rooftop Arrival (15s) — HARD CUT to s6
...

## Transition types (R25 compliance)
- Every location change must be bridged (bridge_clip / time_cut / match_cut).
- Adjacent scenes within same location use hard cut.

## Pacing strategy
- Opening act (s1-s2): slow build, atmospheric
- Middle act (s3-s4): acceleration, action
- Climax (s5-s7): emotional peak
- Coda (s8): isolation resolution

## Recurring props requiring ref (R24 compliance)
- Motorcycle (appears in s1/s3/s4/s5 — needs ref)
- Briefcase (only in s2 — no ref needed, generated from prompt)
- Phone (appears in s6/s7 — needs ref)

## Redundancy elimination
- Original script had s3 (mount+ignite) + s4 (tunnel exit) — same
  narrative beat (leaving the garage). MERGE into one 15s clip.
- Avoid writing two clips where one suffices.

## Cross-clip state handoffs
- s2 end: Courier hands empty, Buyer has briefcase → s3 starts with
  empty-handed Courier
- s4 end: Courier on motorcycle exiting garage → bridge starts with
  motorcycle mid-ride
- bridge end: motorcycle arrives at rooftop → s5 starts with bike
  already parked
```

### Detection (Phase F pre-check)

Before Phase G generation:

1. Does `editing_plan.md` exist?
2. For every scene pair (N, N+1): is the transition type declared?
3. For every location change: is the transition one of
   {bridge_clip, time_cut, match_cut}?
4. Are any beats functionally duplicated (both "leaving" / both
   "arriving" / both "waiting")? Merge or delete.
5. Are recurring props listed with ref requirement flagged?
6. Does Phase C ref_map cover every "needs ref" flagged entity?

If any fail → block, return to Phase A to revise plan.

### Why this was not R1-R23

R1-R23 are per-clip / per-shot / per-prompt rules. R26 is the ONLY
rule that operates at the **whole-production level** before any clip
exists. Without R26, individual clips can each pass R1-R25 yet the
final film reads as disconnected shots. R26 ensures narrative
skeleton is designed, not discovered.

### Cost impact

R26 itself is free (Claude reasoning). But R26 prevents waste: the
Courier Chronicles v2 had a redundant s3 clip ($0.85) and a missing
bridge ($0.85) — exactly $1.70 of "could have been prevented by R26"
waste in one production. For longer productions the prevented waste
grows linearly.

### Severity

Critical. Production-level thinking precedes clip-level thinking.

---

## R27. Image-First Pipeline for 3 Specific Shot Types (MAJOR)

**Added after:** 2026-04-18 reading《Seedance 之后,AI 视频分镜只做关键帧》
by 小石学长 / 西羊石 AI视频. The article's central thesis: after
Seedance 2.0, NOT every shot needs handcrafted keyframes. Only 3 shot
types justify going through an image model FIRST (then i2v) instead
of direct t2v:

### Type 1: Extreme-complexity shots
Multi-person tugging / complex blocking / heavy prop interaction /
spatial relationships hard to verbalize.

**Why**: t2v alone has high drop rate on these — model guesses wrong
about spatial layout, hands intersect bodies, props clip through
characters.

**Fix**: generate a static keyframe via nano-banana / 即梦 first
(anchoring the spatial relationship), then use that image as
`first_frame_url` or `reference_image_urls[0]` for i2v.

### Type 2: Emotion-static shots + still-life CU
Establishing wides, suspense prop CUs, emotional pauses, flame /
smoke / water / fabric material close-ups.

**Why**: t2v "looks correct but doesn't look beautiful" on these —
Seedance prioritizes action renderability over still composition.
Image models (nano-banana, 即梦, Midjourney) win on aesthetic
stillness.

**Fix**: generate the keyframe with an image model (which bakes
cinematic composition / material texture), then i2v to animate
subtle motion (flame flicker, fabric drift, dust motes). Better than
asking Seedance to "look still and beautiful" — it gives motion but
compromises beauty.

### Type 3: Long-clip partial collapse rescue
The "first 8s perfect, last 2s face collapses / hands scramble /
props glitch" pattern.

**Why**: re-running the whole 15s clip throws away 8s of good
material + re-rolls the stochastic dice that might fail elsewhere.

**Fix workflow** (新流程, adopt this):
1. Extract the frame just BEFORE collapse (via `/extract-frame`
   with `which=<timestamp>`).
2. Send that frame to nano-banana / 即梦 with a prompt describing
   the correct next action.
3. Take the corrected frame back as `first_frame_url` for a NEW
   generation covering only the collapsed last 2s.
4. Concat: original 0-8s + rescued 8-15s.

This preserves 80%+ of the original material's value and costs
~20% of a full re-run.

### Decision tree for incoming shots

```
Is the shot one of {complex spatial, emotion-static, still-life CU}?
  YES → keyframe via image model → i2v
  NO  → direct t2v per standard pipeline
```

### Severity

Major. Applying R27 cuts drop rate and cost on the shots most likely
to fail, while leaving simple shots to the fast t2v path.

---

## R28. Six-Field Prompt Skeleton (REPLACES/EXTENDS R11 structural shape)

**Added after:** same article (《Seedance 之后》). Formalizes the
prompt structure used in the article's real project workflow:

```
风格/媒介 + 景别/视角 + 主体描述 + 环境场景 + 光影色调 + 质感修饰
Style/Medium + Framing/POV + Subject Description + Environment + Lighting/Color + Texture Finishing
```

### Why

R11 says "describe everything exhaustively" which can produce bloat.
R28 gives an ordered skeleton so the exhaustive description has a
canonical shape — easier for Claude to fill, easier for the prompt
to consume.

### The two load-bearing fields

Article: "这套骨架里,最关键的其实只有两段:**主体描述**和**环境场景**"

Weak vs strong subject description:
- ❌ "一个很帅的霸总"(weak — sounds vivid but model can't
  concretize)
- ❌ "一个绝美古风女子"(same)
- ✅ age + bone structure + hairstyle + outfit + action + gaze
  direction + hand state (each specific)

Weak vs strong environment:
- ❌ "华丽的宫殿背景"
- ✅ 屋内布局 + 家具材质 + 光源方向 + 时间 / 天气 + 画面景深
  expectation

### How to use

When decomposing a scene per `decompose_scene.md`, structure each
shot's prompt body in the six-field order:

```
[00:00-00:05] 镜头1 Title
Style/Medium: 35mm film grain, neo-noir
Framing/POV: 中景 side-on from audience LEFT
Subject: Julian 45y detective, graying temples + three-day
  stubble, charcoal trench collar up, hands in coat pockets,
  gaze tracking RIGHT deep into tunnel, shoulders tense
Environment: 地下车库 wet tile floor with puddles, tube sodium
  lights flickering overhead, concrete pillars RIGHT of frame,
  graffiti wall LEFT impassable, tunnel exit in deep BACK
Lighting/Color: cool teal-green fluorescent + amber accent from
  distant lamp, low-key chiaroscuro contrast
Texture: wet concrete reflections, fabric of trench coat
  drapes, slight film grain
```

### When to skip

For very short natural-language scene descriptors (≤200 chars "A
rainy street, a man walks"), the six-field skeleton is overkill.
Use when prompt needs to be ≥500 chars and precision matters.

### Severity

Major. Adopt as default structure for multi-clip productions.

---

## R29. 9-Panel Storyboard Explosion (nano-banana pipeline)

**Added after:** same article. Documents the workflow "一张好图,裂
变出连续分镜":

### What

Once a high-quality base image exists (character ref + location ref
composited into a single "hero frame"), ask nano-banana / 即梦 /
Midjourney to generate a **9-panel grid** of continuous shots
sampling that scene from different framings/angles in ONE
generation. Then pick the best panels as keyframes and enlarge
separately for i2v.

### Why it's better than one-by-one manual

- **Character + scene consistency within the single 9-panel grid**
  is intrinsic (same seed, same composition context). Separate
  shots generated independently drift.
- **Speed**: 1 generation produces 9 candidate framings. Cheaper
  than 9 separate generations.
- **Closer to how film pre-production thinks** — a shot list
  exported as contact sheet, then specific frames picked.

### Workflow

```
1. Prepare assets (character ref + location ref) in Phase C.
2. Compose a "hero frame" via nano-banana combining the refs.
3. Prompt nano-banana: "Generate a 9-panel grid (3x3) of
   continuous shots from this scene:
   Shot 1: MS, OTS
   Shot 2: CU, high tension
   Shot 3: POV, low angle
   Shot 4: FS, back view
   Shot 5: MCU, OTS
   ..."
4. Pick the best 2-3 panels as keyframes.
5. For each selected keyframe: enlarge via image model, use as
   first_frame_url for i2v via Seedance.
```

### When to use

- Drama scenes with >3 beats where cross-shot consistency matters
- Shots where character/prop continuity has already drifted in t2v
  attempts
- Action sequences with multiple rapid cuts

### When to skip

- Simple single-shot clips
- Time-lapse / environmental scenes with no recurring subjects

### Severity

Medium. Not mandatory but a significant force multiplier when
applied correctly.

---

## R30. Dialog Conventions — Per-Clip Lines + "no captions" Compatible (MAJOR, pre-test draft)

**Added pre-emptively before the first dialog drama test.** Seedance
2.0 supports phoneme-level lip-sync + joint audio generation, and the
seedance SKILL.md already has basic guidance (`@图片1 says: "台词"`),
but no unified rule governs cross-clip dialog coherence. This rule is
a draft to be validated by the first dialog production.

### What

1. **Each clip's prompt must state the complete dialog line(s) for
   that clip inline**. Seedance's per-call generation does NOT
   maintain conversation state across `/generate-video` calls.
   Clip N knowing "the previous clip ended mid-sentence" doesn't
   carry to Clip N+1 unless the prompt restates context.

2. **Dialog format inside prompts:**
   ```
   @图片1 Woman, 平静压抑的音调: "你还好吗。"
   (2 秒停顿)
   @图片2 Man, 低沉嘶哑: "好多了。"
   ```
   - Per-speaker ref token + tone descriptor + quoted line + pause length.
   - Tone words are load-bearing — they drive voice selection.
   - Use Chinese punctuation for Chinese dialog (句号 in "你还好吗。"
     signals a statement ending, not question — distinct from 问号).

3. **R23 "clean frame no captions" is audio-compatible.** "No
   subtitles / no captions / no on-screen text" is a VISUAL directive
   only; Seedance interprets it correctly as "don't burn text onto the
   frame". Dialog audio still renders normally. Always include the
   clean-frame directive even with dialog — otherwise Seedance may
   add subtitle overlay ("translation" of the dialog) which looks
   amateur.

4. **Voice consistency across clips (open question for the test)**:
   Seedance may pick a slightly different voice per clip if only the
   visual character ref is supplied. `ref_audio_urls` parameter accepts
   audio references (up to 3) for voice/tone matching. For dialog-
   heavy productions, consider recording a 3-5s reference line per
   character and passing via `ref_audio_urls`.

   **TEST: does dialog voice stay consistent across clips with only
   visual refs?** Answer determines if R30 needs a "voice ref
   mandatory" extension.

5. **Dialog pacing**: short lines (< 1.5s speaking) don't need
   internal timestamps. Longer exchanges should explicitly declare
   timing per line:
   ```
   [00:00-00:03] @图片1 says (composed): "你还好吗。"
   [00:03-00:05] silence; @图片2 adjusts his coffee cup.
   [00:05-00:08] @图片2 says (quiet, low): "好多了。"
   ```

6. **Lip-sync trigger words**: Seedance responds to dialog cues
   formatted as `<character> says: "<line>"` OR `@图片N 说: "<台词>"`.
   Freeform "他开口说话" is weaker — phrase the dialog as an
   explicit say-verb construction.

### Known unknowns (this rule may need revision after test)

- Does voice drift across multiple 15s clips using only visual char ref?
- How long can a single dialog line be before Seedance compresses it?
- Do subtitles still appear when raw_prompt=true + clean-frame text?

### Severity

Major pre-emptive. Dialog drama is the first domain where we'll see
audio-specific failure modes not captured in R1-R29. Use as baseline
before the first dialog test; revise after.

---

## R31. Extract-Frame Chain Fallback When Ark Compliance Fails (MAJOR)

**Added after:** 2026-04-18 Room 207 thriller chain attempt. S1 generated
successfully. `/extract-frame which=last` returned the tail frame PNG
URL. Compliance check via `POST /api/compliance/check-by-url` repeatedly
returned `ark.invalidparameter.downloadfailed` on that PNG URL. Ark's
fetcher can't download the extract-frame PNG, blocking the entire chain.
This happened despite the SAME flow working earlier in the day on《末班车》
and《Courier Chronicles》.

### What

Ark's compliance fetcher is NOT 100% reliable on extract-frame PNG URLs
from the `/images/` CDN path. Possible root causes:
- Ark IP / user-agent / mime-type quirks
- CDN propagation lag (not fixed by waiting 30-60s)
- Transient Ark side outage (today was partition-bad)

### Detection

Compliance status fails with `ark.invalidparameter.downloadfailed` on any
URL from `/api/cinema-studio/generations/{id}/extract-frame`.

### Fallback strategy (ordered preference)

1. **Retry 2-3 times over 3 minutes** — occasionally Ark recovers.
2. **Re-extract a DIFFERENT frame** (try `which=middle` or a specific
   timestamp). Sometimes a different PNG gets through.
3. **Reupload via `/api/cinema-studio/upload`** — DOES NOT help for
   compliance (the upload endpoint puts files in `cinema-studio-refs/`
   bucket which compliance check reports "Asset not found for URL").
4. **Give up on chain, fall back to parallel**. Submit the remaining
   clips in parallel with STRONG prompt-level state anchoring:
   - Each clip's prompt opening says explicitly: "This shot opens
     from state X: door is already 8 inches open, Man visible
     in gap, Courier holding package"
   - Relies on R16 absolute position rule, no tail-frame ref
   - Accept: state-progression continuity will be slightly worse
5. **Or: Kling extract-frame** — Kling has its own extract-frame
   endpoint that routes through a different compliance path. May
   succeed when Seedance's fails. If the production allows provider
   mixing, chain via Kling extract instead.

### When to abandon chain entirely

If 3 consecutive extract-frame+compliance attempts fail on DIFFERENT
frames, Ark's fetcher is having a bad day — don't keep burning time.
Switch to parallel with anchoring and document the production as
"chain attempted, degraded to parallel due to compliance outage".

### Recovery rule of thumb

- **Under 20 min time budget** → parallel fallback after 1 failed
  compliance attempt
- **Under 4 hour time budget** → retry up to 3 times then fall back
- **Critical production for delivery** → try Kling as alternate chain
  provider

### Severity

Major. This rule prevents entire productions from stalling when
platform has transient issues. The skill must gracefully degrade;
"chain only" is too fragile as a hard requirement.

---

## R32. Explicit Dialog Line Whitelist (MAJOR)

**Added after:** 2026-04-18《Room 207》 s2 dialog test. Gemini audit
caught an unscripted line "Mr. Sterling Rowland?" leaking into the
clip. My prompt declared the 2 intended lines clearly but did NOT
forbid additional lines. Seedance filled the silence with an
improvised name-check.

### What

When a clip has dialog, the prompt must EXPLICITLY whitelist every
line and forbid all others. Otherwise Seedance's joint audio-video
generation may add improvised conversational filler.

### Fix template

Append this after the dialog block:

```
STRICT DIALOG CONSTRAINT: The ONLY dialog lines in this clip are:
1. @image1 Courier: "You weren't here last week."
2. @image2 Man: "Things changed."
No other characters speak. Man says NOTHING except "Things changed."
Courier says NOTHING except "You weren't here last week." No names
are said. No greetings. No improvised lines.
```

### Detection in pre-check

If prompt contains quoted dialog → check if prompt contains a
whitelist / forbidding clause. If not → flag R32 violation, add the
clause before submission.

### Severity

Major. Unscripted leaks make clips unusable for dialog-driven drama.

---

## R33. Explicit Shot Count Cap (MAJOR)

**Added after:** 2026-04-18《Room 207》 s4 cliffhanger test. Prompt
described exactly 3 shots. Gemini audit caught an unprompted 4th shot
inserted mid-clip: a brief Woman speaking cutaway between Man's ECU
and the final line. Seedance filled a perceived empty narrative
moment with an improvised shot.

### What

When the prompt structures a clip into N shots, explicitly cap at N
or Seedance may add improvised cutaways / reaction inserts / b-roll.

### Fix template

Append to the prompt:

```
STRICT SHOT CONSTRAINT: This clip has EXACTLY 3 shots as described
above. No additional inserted shots, no cutaways, no reaction inserts,
no b-roll, no flashbacks, no dream sequences. Only the 3 declared
shots in the declared order.
```

### Severity

Major. Unprompted inserted shots break timing and pacing.

---

## R34. Critical Props and State Instances Need Their Own Ref Images (MAJOR, extends R24)

**Added after:** 2026-04-18《Room 207》 cross-clip test. R22 required
character refs. R24 required recurring prop refs. R34 extends: when a
prop appears in a SPECIFIC STATE that must remain consistent across
clips (door cracked 8 inches, sleeve with blood spatter, package
shape), generate a **state-specific reference image** and include in
`reference_image_urls` for every clip where that state applies.

### What

Not just "motorcycle needs ref" (R24) but "motorcycle headlight OFF
with Courier dismounted needs its own state-ref". The finer the state
needs to be pinned, the more state-refs needed.

### Common state-refs to generate

- **Door at specific opening angle** (closed / 8 inches / half-open / full-open)
- **Package with specific wrapping and shape** (flat box vs lumpy)
- **Sleeve with specific blood placement** (cuff fabric 2cm below wrist)
- **Anatomical precise state** (e.g., "bloodstain ON FABRIC, NOT on skin")

### Fix template

In Phase C Phase C generation:
```bash
# Generate door-cracked-8-inch state ref
POST /generate-location prompt: "Motel room door cracked open
approximately 8 inches, warm tungsten interior light spilling through
the narrow gap onto an exterior concrete corridor. Detail shot, close
enough to show the door frame and the gap precisely. Photorealistic."
```

Pass this ref into every clip where door state must be 8 inches.

### Severity

Major. Critical-state drift (door opens differently in each clip) is
what breaks narrative continuity even when characters are consistent.

---

## Future rules (to add as new bugs surface)

- R35: Lighting direction consistency across shots
- R36: Genre-tone consistency
- R37: Dynamic range / contrast warnings

## Rule library evolution log

| Version | Rules | Added based on |
|---|---|---|
| v1 | R1-R10 | 《末班车》v1 (10×5s) observed bugs + general AI video theory |
| v2 | R11-R14 added | 《末班车》v2 (4×15s) Gemini audit findings |
| v3 | R15 added | User insight: parallel submission vs visual-dependency chaining. Validates via《末班车》v2's 30s/45s boundary bugs being caused by parallel-only generation |
| v4 | R16 added | 《末班车》v5 c02 v2 dogfood: cross-shot temporal break due to relative direction + ref_image tug. Needed explicit absolute positioning + negation rule. |
| v5 | R17 added | User observation during《末班车》v5: Woman hands file to man but still carries file out. Seedance doesn't "update" prop ownership after exchange — phantom duplicate prop persists on giver. Needs double-state-update language. |
| v6 | R18, R19 added | 2026-04-18 drama + anime validation tests (text-only t2v): drama paper-bag-rip physics skipped (R18); anime cel-shaded style overridden by photoreal default (R19). Both critical/major failures per Gemini. |
| v7 | R20 added | 2026-04-18 "The Drop" Phase 3 integration test: fedora+three-piece+goatee buyer description triggered Ark copyright filter, clip rejected with 255 credits sunk cost. Any iconic character archetype combination must be pre-emptively rewritten with generic descriptors. |
| v8 | R21 added | 2026-04-18 "Courier Chronicles" regression test s6: "burner phone" + "未知来电" triggered Ark content policy (`policy_violation_output`). Distinct from R20 copyright filter. Neutralize crime-specialist vocabulary pre-emptively. |
| v9 | R22 added (the most important rule so far) | 2026-04-18 user first-viewing feedback on the 120s "Courier Chronicles" concat: "这个整体是一个故事吗?" Text-only t2v across 8 clips produced 8 different Couriers in 4 different garages and 4 different rooftops. No story. Multi-clip productions MUST use reference_image_urls; the $1 "saved" by skipping Phase C destroys the entire $13 production. |
| v10 | R23 added (supersedes R1 in importance) | 2026-04-18 user hypothesis confirmed via Phoenix codebase review: the Ark video provider routes prompts through Gemini Flash LLM enhancement by default, collapsing my structured `[00:XX-YY] 镜头N:` blocks into a single unified cinematic description before they reach Seedance. ALL prior single-shot "failures" (c04 isolation, drama/jazz tests, 5/8 Courier Chronicles clips, 末班车 c04) were caused by Phoenix's enhancer, not by Seedance. Fix: set `raw_prompt: true` in the API payload to bypass enhancement. This single flag is more load-bearing than R1-R22 combined because without it, the other rules are literally discarded upstream. |
| v11 | R24 + R25 added | 2026-04-18 user feedback on Courier Chronicles v2 (after R22+R23 applied): "摩托车离开了两次...场景连贯性不够". Verified 3 different motorcycles ridden by same Courier across s1/s3/s4 (R24: props need their own refs), and garage→rooftop jumped with no transit bridge (R25: location transitions need bridge clip / time-cut signal / match cut). |
| v12 | R26 added | 2026-04-18 user: "整部剧那你在最开始做的时候也要考虑到剪辑方案呀". Editing plan is Phase A MANDATORY output, not ad-hoc discovered per-clip. |
| v13 | R27 + R28 + R29 added | 2026-04-18 reading《Seedance 之后,AI 视频分镜只做关键帧》by 小石学长 / 西羊石 AI视频. Extracted 3 new rules: R27 (image-first pipeline for complex/emotion/rescue shots), R28 (six-field prompt skeleton 风格+景别+主体+环境+光影+质感), R29 (9-panel storyboard explosion via nano-banana to generate continuous shots in one go). |
| v14 | R30 added (pre-emptive, pre-first-dialog-test) | 2026-04-18 user requested 1-min dialog drama as skill test. No existing rule governed cross-clip dialog coherence. R30 drafts conventions for per-clip dialog lines, tone descriptors, R23 clean-frame compatibility, voice-ref strategy, and lip-sync trigger words. Rule is draft; revise after first test reveals actual failure modes. |
| v15 | R15 enhanced | 2026-04-18 user pre-submit question on Room 207 thriller: "4 个 clip 并行会不会跳". R15 expanded from abstract "chain vs parallel" to concrete decision matrix + partial-chain pattern + time-vs-quality tradeoffs. Added 5th/6th detection condition (progressive physical state, new detail persistence). Chose full-chain for Room 207 based on progressive door opening + blood-stain persistence across 4 clips. |
| v16 | R31 added | 2026-04-18 Room 207 chain step 2 failed: Ark compliance repeatedly returned `ark.invalidparameter.downloadfailed` on s1 extract-frame PNG. Same flow had worked earlier in the day on 末班车 + Courier Chronicles. R31 documents the fallback ladder: retry 3x → re-extract different frame → parallel + anchor fallback → Kling as alternate provider. Skill must gracefully degrade when Ark has transient issues. |
| **v17** | **R32 + R33 + R34 added** | **2026-04-18 Room 207 dual-judgment audit caught 3 new failure modes not covered by R1-R31: (R32) unscripted dialog leak ("Mr. Sterling Rowland?" appeared in s2 unprompted — fix: explicit dialog whitelist + no-other-lines forbidding clause), (R33) unprompted inserted shot (s4 had a 4th Woman-speaking shot Seedance added on top of the 3 requested — fix: STRICT SHOT CONSTRAINT line + no-b-roll forbidding), (R34) state-specific props need state-refs (door at specific opening, sleeve with specific blood placement — extends R24 beyond "just have a prop ref"). All 3 are "Seedance does MORE than prompt" failure modes, distinct from the earlier "Seedance does LESS than prompt" failures.** |

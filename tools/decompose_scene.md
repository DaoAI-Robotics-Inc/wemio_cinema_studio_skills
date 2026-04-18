# Scene Decomposer Playbook

**Purpose:** Take ONE scene from the parsed script JSON and produce a
clip prompt ready for Seedance 2.0 `/generate-video`. Applies:
- Genre-specific template (from `SKILL.md` genre router + `examples-<genre>.md`)
- 2-4 internal shots with **content diversity** (subject + framing + action)
- R11 exhaustive description anchors
- R16 absolute position + explicit negation
- R17 post-exchange prop state reset
- 500-800 char target (per corpus median), not 2200+

---

## Input

- One scene object from parser output (see `parse_script.md` output shape)
- The parent JSON's `characters`, `locations`, `props` (for detail lookup)
- The scene's `continuity_requires.starts_with` and `ends_with`
- Optional: `scene_blueprint.json` from Phase 0b for the location

## Output

A single prompt string ≤ 2500 chars (target: 500-800) ready to POST to
`/generate-video` along with reference_image_urls, duration, etc.

---

## Decomposition procedure

### Step 1: Count available action beats

Read the scene's `beat` field. Count the distinct **dramatic actions or
visual moments** implied. This is the SHOT COUNT.

- 1 beat (e.g. "detective stares at folio") → 1 shot (accept single-shot
  is fine for emotional stills)
- 2 beats ("Woman enters, hands folio") → 2 shots
- 3 beats ("Woman enters, hands folio, leaves") → 3 shots
- 4 beats ("Woman exits train, crosses, hands over, leaves") → 3 shots
  (merge if possible — corpus median is 3 per 15s)
- 5+ beats → either pick the 3 strongest or split into 2 clips

**Critical lesson from c04:** "zoom level change without action change"
is NOT a beat. Seedance compresses identical-subject static shots into
one. Each beat must have a distinct action or subject shift.

### Step 2: Assign each beat a distinct primary subject / framing

For each beat, pick a **primary visual subject that is NOT the same as
adjacent beats'**. Choose from categories:

- Part-of-body macro: hand / foot / eye / lips
- Single character close-up / medium
- Two-character medium / wide
- OTS (over-the-shoulder)
- Environmental wide / establishing
- Prop macro (when prop is the focal action)

**Rule:** Adjacent shots must differ in at least TWO of these categories
(subject + framing, or subject + angle). Merely changing zoom on same
subject at same angle = collapse risk.

### Step 3: Write per-shot blocks in the genre's preferred format

Pick format based on genre:

| Genre | Format |
|---|---|
| drama / noir | `[00:00-00:05] 镜头1: Title\n  场景: ...\n  动作: ...\n  相机: ...` |
| anime / action | `0-5秒: 特写...切到 5-10秒: 广角...` (Chinese colon format) |
| fantasy_scifi | `镜头1 (0-5s): ...` or bracket `[00:XX-YY]` |
| horror | `[00:00-00:05] Shot 1: ...\n  Environment: ...\n  Tension: ...` |
| romance | `0-X秒:` colon + emotional beat description |
| mv | `0-X秒:` with `beat drop / chorus / verse` markers |
| ugc | `[00:XX-YY]` brackets, handheld emphasis |
| commercial | `[切到]` Chinese explicit with product hero language |

Before writing, `Read skills/script-to-video-seedance/examples-<genre>.md`
top 2-3 entries for same genre. Mimic their rhythm and vocabulary.

### Step 4: Inject continuity anchors (R11 / R16 / R17)

Before each shot block, add lines that lock state per-character:

**For shot 1:** Use `continuity_requires.starts_with` to anchor opening.
Example: `Julian 已在 LEFT 三分位站定(不从别处入画),Woman 从车厢门 RIGHT
踏出一只脚(尚未完全下车)`.

**For shots 2+:** Anchor character positions with **absolute language**
not relative direction (R16). If previous shot had an exchange, apply
R17 double-state-update: `Woman 的双手空空,folio 现在在 Julian 双手中,
Woman 不再持有任何物品`.

**For terminal shot:** Use `continuity_requires.ends_with` to describe
last frame. Repeat key state words in caps/bold for emphasis.

### Step 5: Compress to target 500-800 chars

Remove:
- Redundant spatial anchoring that's already in Phase 0 blueprint
- Adjective stacking ("mysteriously, quietly, silently, pensively")
- Description of things Seedance skips anyway (pixel-level reflections,
  sub-second micro-tremors — see SKILL.md "Seedance 创意 override")

Keep:
- Each shot's primary subject (one noun phrase)
- The dramatic action (verb + object)
- Camera framing keyword (ECU / close / medium / wide / OTS / macro)
- Character position anchor (LEFT third / RIGHT half / foreground)
- R17 double-state language if this scene contains an exchange

### Step 6: Negate unwanted defaults (only if prior tests showed bug)

Only add negation lines for bugs that have been observed (not preemptive).
Examples where negation IS needed:
- If Woman leaves scene but keeps phantom folio → add `Woman 双手空空`
- If train is meant to be absent in ending scene → add `列车完全不出现`
- If MACRO is important and Seedance tends to widen → add `纯黑 void
  背景,物体 70% 画面`

Don't over-hedge. Corpus drama prompts are 459 chars median; ours were
2400+. That bloat was from preemptive negation.

### Step 7: Generate final prompt

Structure:
```
【风格】<genre style + lighting/mood from SKILL.md lookup>
【时长】<target seconds>秒
【场景/空间锁】<key left/right/passability from blueprint>
【角色】<character bullets, 1 line each>

<shot blocks per Step 3 format>

【终态锁定】<ends_with re-stated, 1-2 lines>
【连续性锁】<any exchange-reset or absence-negation from Step 6>
```

### Step 8: Self-check before submit

Verify:
- [ ] Char count in 500-1200 range (stretch to 1500 for action/sci-fi)
- [ ] Each shot has distinct subject + framing + action
- [ ] Every character mentioned has an absolute position anchor
- [ ] If prop exchanges happen, both giver-empty and receiver-holds are written
- [ ] Terminal state re-declared at end
- [ ] Format matches genre (don't mix drama's brackets with anime's colons)

If any fail → revise before submitting.

---

## Worked example: scene_2 of 末班车

**Input:**
```json
{
  "id": "s2",
  "location_ref": "subway_platform",
  "characters_present": ["julian", "woman"],
  "beat": "Woman crosses to Julian, hands him folio, returns to train",
  "emotional_tone": "tension-release",
  "duration_target_seconds": 15,
  "continuity_requires": {
    "starts_with": { "julian": "LEFT third, waiting", "woman": "near RIGHT train doors, holds folio", "train": "stopped, doors open" },
    "ends_with": { "julian": "LEFT third, holds folio in both hands at waist", "woman": "back at train car, boarding", "train": "stationary, doors open", "folio": "julian" }
  }
}
```

**Beat count:** 3 distinct dramatic actions → 3 shots.

**Primary subjects:**
- Shot 1: Woman's shoes walking toward Julian (body part macro)
- Shot 2: Two-shot medium wide — handoff moment (two characters)
- Shot 3: OTS Woman walking back toward train (back + receding figure)

Each differs in subject AND framing.

**Format:** drama → `[00:XX-YY] 镜头N:` bracket format.

**Output prompt** (~700 chars):
```
【风格】现代都市 noir 短剧,写实电影,冷色荧光 + 湿瓷砖反光,fog + film grain。
【时长】15秒
【空间锁】LEFT=瓷砖墙不可穿越;RIGHT=停稳列车,车门敞开。
【角色】Julian 侦探 45y 深炭灰 trench coat;Woman 32y 黑短波浪发长款黑羊毛大衣。

[00:00-00:04] 镜头1:Approach
  画面:Woman 的黑色短靴在湿瓷砖上走路的 ECU,水珠溅开,背景虚化。画面无面孔、无列车、无 Julian。
  动作:步伐沉稳,方向 RIGHT-to-LEFT(从列车走向 Julian)。

[00:04-00:10] 镜头2:Handoff
  画面:中远景双人同框,Julian LEFT 三分位,Woman 停在他前 1m,双手抬起 brown leather folio 递出。Julian 双手接过,folio 完全转移到 Julian 手中。Woman 的双手彻底松开,空空垂于身侧。
  相机:Slow push-in on folio exchange。

[00:10-00:15] 镜头3:Retreat
  画面:OTS 从 Julian 左肩外,Julian 背影 LEFT foreground 独自持 folio 于腰,Woman 背影走向 RIGHT 车门并完整踏入车厢(不在门口停留)。
  相机:固定。

【终态锁定】Julian LEFT 三分位,双手握 brown folio 于腰;Woman 已完整进入车厢。车门仍敞开。
【连续性】Woman 交出 folio 后双手空无一物;列车门 15 秒内保持敞开不关。
```

Char count: ~720. Matches corpus drama median. Uses bracketed HH:MM:SS
timestamps (drama's top format). Each shot has distinct subject/framing.
R17 double-state applied in shot 2. R16 absolute anchoring throughout.

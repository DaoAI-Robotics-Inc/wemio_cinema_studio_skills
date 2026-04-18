# Continuity State Machine Playbook

**Purpose:** Track per-character / per-prop / per-environment state
across clips so cross-clip bugs (phantom prop, axis break, temporal
order, orphaned object) don't happen. Before each clip generates, this
playbook updates the state, emits the continuity anchors into the
next clip's prompt.

**How this is used:** the production skill maintains an in-memory
`state_dict` and updates it after each clip is generated + audited.
Before writing the next clip's prompt (via `decompose_scene.md`), the
skill consults this state and injects the required anchoring language.

---

## State structure

```python
state = {
    "environment": {
        "location_id": "subway_platform",
        "time_of_day": "00:15",
        "weather": "clear",
        "lighting": "overhead fluorescent, slight teal-green",
        "special_ambient": ["mist rising", "fluorescent flickering"],
    },
    "characters": {
        "julian": {
            "position": "LEFT third",
            "facing": "RIGHT",
            "body_orientation": "profile",
            "pose": "standing still",
            "outfit": "charcoal trench coat, collar up",
            "props_held": ["folio"],   # list of prop_ids
            "emotional_state": "tense-anticipation",
        },
        "woman": {
            "position": "absent",  # OR "near RIGHT train doors", or a coordinate
            "facing": null,
            "props_held": [],   # empty after handoff
            "emotional_state": null,
        },
    },
    "props": {
        "folio": {
            "owner": "julian",
            "location": "held in both hands at waist",
            "state": "closed",
            "material": "brown leather",
        },
    },
    "plot_devices": {
        "train": {
            "present": false,  # after scene 3/4
            "state": "departed",
            "departure_direction": "RIGHT depth",
        },
    },
}
```

---

## State update after each clip

After clip N is generated AND audited, update state by applying the
scene's `continuity_requires.ends_with` to the current state:

1. For each character in `ends_with`, update their entry in
   `state["characters"]` with the new pose / position / props / emotion.
2. For each prop in `ends_with`, update owner + location + state.
3. For environment changes (weather, lighting shifts, time passage),
   update `state["environment"]`.
4. For plot-device absence (e.g. train departed), set `present: false`.

If the audit flagged a state inconsistency Gemini noticed (like "Woman
still carries folio"), the state update should reflect what **actually
happened in the video**, not what the prompt said. This becomes the
ground truth for the next clip's anchoring.

---

## Anchor injection before next clip

Before writing clip N+1's prompt (via `decompose_scene.md`), consult
the state and inject these into the prompt:

### R16 absolute position anchor (per character)
For every character appearing in clip N+1:
- Insert: `@{id} 此时已在 <position>,面朝 <facing>,<pose>,不从别处入画。`
- If character is NOT in clip N+1 but was in state previously: insert
  negation: `@{id} 在本 clip 中完全不出现,已 <past state>。`

### R17 post-exchange reset (per prop)
For every prop with `exchange: true` in the trajectory that happened
in the prior clip OR is happening in this clip:
- Giver side: `@{giver_id} 的双手空空,不再持有 {prop_id}。`
- Receiver side: `@{receiver_id} 双手握住 {prop_id} 的 <current state>。`

### Blueprint re-assertion (spatial)
If the environment's spatial rules are fragile across clips (axis flipped
in prior dogfood), repeat them:
- `LEFT 是 <impassable object>;RIGHT 是 <usable_path>。所有列车 only from
  RIGHT。`

### Time / train / weather continuity
- If train was departing in clip N: clip N+1 opens with train absent or
  far-gone. Explicit: `列车已彻底离开,画面 RIGHT 空无一物。`
- If rain started: subsequent clips have rain unless explicitly cleared.
- If character was emotionally shaken: subsequent clip's character
  should carry that emotion.

---

## Worked example: 末班车 state evolution

### After clip 1 (scene_1):
```
state = {
  environment: { location: "subway_platform", lighting: "fluorescent" },
  characters: {
    julian: { position: "LEFT third", facing: "RIGHT", pose: "standing",
              props_held: [], emotion: "watchful" },
    woman:  { position: "RIGHT, 2m from train doors", facing: "LEFT",
              props_held: ["folio"], emotion: "composed" },
  },
  props: { folio: { owner: "woman", location: "both hands at waist",
                    material: "brown leather" } },
  train: { present: true, state: "stationary with doors open" },
}
```

### Before clip 2: anchors injected into prompt
```
@图片1 Julian 此时已在 LEFT 三分位,面朝 RIGHT,静立,手空(folio 仍在 Woman 手中)。
@图片2 Woman 此时已在 RIGHT 半区距车门 1.5m,面朝 LEFT(朝 Julian),双手握 brown leather folio 于腰,不从别处入画。
列车 RIGHT 深处停稳,一扇车门敞开,内部灯可见。
```

### After clip 2 (exchange occurred):
Update owners:
```
state.props.folio.owner = "julian"
state.props.folio.location = "both hands at waist"
state.characters.julian.props_held = ["folio"]
state.characters.woman.props_held = []      # R17 reset
state.characters.woman.position = "inside train car"  # or "at doorway"
```

### Before clip 3: anchors
```
@图片1 Julian 此时已独自在 LEFT 三分位,双手握 brown leather folio 于腰。
@图片2 Woman 已完整登车离开,在本 clip 中完全不出现,她的双手空空,folio 不在她手中。
列车 RIGHT 停稳,车门可能关闭或正在启动(scene 3 的 beat 允许列车开始离开)。
```

### After clip 3 (train departed):
```
state.train.present = false
state.train.state = "departed RIGHT"
state.characters.julian.emotion = "shocked"
```

### Before clip 4: anchors
```
@图片1 Julian 独自 LEFT 三分位,双手握 brown leather folio(在 shot 3 的动作中已经翻开,内容在他刚看见后心里震动),情绪凝重。
列车完全不出现,画面 RIGHT 空轨道,轨道上无任何车厢、无尾灯、无列车影子。
@图片2 Woman 全 clip 不出现。
环境:薄雾从地面升起,荧光灯偶尔闪烁。
```

---

## Bug-catch patterns this state machine prevents

Based on 《末班车》 v1-v5 dogfood:

1. **Phantom prop** (v2): Woman gave folio but kept walking with it.
   → R17 auto-injects "Woman 双手空空" after any exchange.
2. **Axis flip** (c02 v2): Julian turns to face camera at the end.
   → R16 anchor repeated every clip: "Julian 始终 LEFT 面朝 RIGHT"
3. **Temporal reversal** (c02 v2): Shot 1 Woman walking; Shot 2 Woman
   at train door just exiting. → R16 "已在 X 处停住,不从别处入画"
4. **Orphan element**: train reappears in clip 4 after departing.
   → explicit "列车不出现" negation injected.
5. **Axis drift across clips**: each clip repeats blueprint spatial
   lock at the top of its prompt.

---

## Integration with production pipeline

```
[parse_script.md] → scene_list JSON
     ↓
state_dict = initial_state(scenes[0].continuity_requires.starts_with)
     ↓
for scene in scenes:
    anchors = derive_anchors(state_dict, scene)
    prompt = decompose_scene(scene, anchors, genre_template)
    clip = generate_video(prompt)
    audit = gemini_audit(clip)
    if audit.status == "pass":
        state_dict = apply_ends_with(state_dict, scene.ends_with)
    else:
        state_dict = apply_observed(state_dict, audit.observed_state)
        # iterate or accept
    concat_final += clip
```

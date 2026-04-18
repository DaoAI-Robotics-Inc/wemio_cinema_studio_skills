# Film Language Reference

> 导演按需参考。写 prompt / 规划分镜前查阅。

## Shot Sizes (Emotional Distance)

| Shot Size | What It Shows | Emotional Effect | When to Use |
|---|---|---|---|
| **EWS** (Extreme Wide) | Tiny figure in vast landscape | Isolation, insignificance, epic scale | Establishing world, showing powerlessness |
| **WS** (Wide) | Full body + environment | Context, spatial awareness | Scene transitions, action sequences |
| **MWS** (Medium Wide) | Knees up + some environment | Body language readable | Walking, group dynamics |
| **MS** (Medium) | Waist up | Balanced — person + context | Dialogue default, neutral emotional distance |
| **MCU** (Medium Close-Up) | Chest/shoulders to head | Attention on face, some body language | Important dialogue, reactions |
| **CU** (Close-Up) | Head/face fills frame | Emotion, intimacy, intensity | Key emotional beats, revelations |
| **ECU** (Extreme Close-Up) | Eyes only, or detail | Discomfort, maximum intensity, critical detail | Climactic moments, horror, key objects |
| **Insert** | Object detail | Drawing attention to plot-critical item | Weapons, letters, symbols, brands |

## Emotional Escalation Pattern

The fundamental rhythm of cinema: **wide → medium → close → wider → repeat**

- Start a sequence wide to orient the audience
- Progressively tighten to build intensity
- Cut wide again for release or scene change
- **Never jump between extremes without narrative reason** (EWS → ECU is jarring unless intentional)

## Composition Rules

- **Rule of thirds**: Place subject at intersection points, not dead center (unless symmetry is the point)
- **Leading lines**: Use environment lines (roads, walls, corridors) to guide eye to subject
- **Headroom**: Leave space above head in CU; cramped headroom = claustrophobia, tension
- **Lead room**: Leave space in the direction the character faces/moves
- **Depth**: Layer foreground/midground/background for dimensionality
- **Dutch angle**: Tilted horizon = unease, instability (use sparingly)

## Camera Movement = 服务场景，自然不夸张

**运镜的唯一标准：什么运镜最自然地服务于这个场景？**

| 场景在发生什么 | 自然的运镜 | 为什么 |
|---|---|---|
| 角色在说话/对话 | `static` | 观众在听对话，镜头动会分心 |
| 角色在走动/行进 | `follow` | 镜头跟人走，最自然 |
| 角色发现了什么/看到了什么 | `dolly_in` | 和角色一起"凑近看" |
| 揭示环境/全貌 | `dolly_out` | 拉开看全景 |
| 角色抬头看天/看高处 | `tilt_up` | 跟随角色视线 |
| 角色低头看地上的东西 | `tilt_down` | 跟随角色视线 |
| 建立新场景/第一次到达 | `drone` 或 `static` WS | 让观众知道"我们在哪" |
| 混乱/打斗/失控 | `handheld` | 不稳定感匹配情绪 |
| 角色情绪内心转变 | `static` 或慢 `dolly_in` | 安静中的力量 |

**关键原则：**
- **跟随角色的视线和动作** — 角色往哪看，镜头往哪动
- **运镜幅度匹配情绪强度** — 安静场景用慢/微动，激烈场景用快/大幅
- **不要为了变化而变化** — 如果场景本身是静态的（两人站着说话），镜头就该是静态的
- **夸张运镜（orbit/roll_360/drone 俯冲）只在剧情真正需要时用**

| Movement | Narrative Purpose | Example |
|---|---|---|
| `static` | Respect the moment; let the performance speak | A character processing devastating news |
| `dolly_in` | Drawing viewer into the emotional core; building pressure | Slow push as villain is revealed |
| `dolly_out` | Creating distance, abandonment, revelation of scale | Pulling back to show character is surrounded |
| `zoom_in` | Sudden realization, shock, vertigo (faster than dolly) | Character recognizes the killer |
| `zoom_out` | Disorientation, shrinking significance | World falls away from character |
| `follow` | Locking audience to character's journey/urgency | Chase scene, character walking into unknown |
| `pan_left/right` | Surveying, revealing new information laterally | Panning to reveal a hidden threat |
| `tilt_up` | Awe, power, ascension | Looking up at a massive structure or god |
| `tilt_down` | Defeat, fall, submission | Character collapses; looking down from height |
| `orbit` | Heightened drama, disorientation, romantic intensity | Two characters in confrontation |
| `handheld` | Raw reality, chaos, documentary urgency | Fight scenes, panic, found-footage feel |
| `drone` | God's eye view, establishing scope | Opening a new world/location |
| `jib_up/down` | Dramatic elevation change, reveal/conceal | Rising above crowd to show the army behind |

## Pacing & Rhythm

- **Longer shots** (8-15s) = contemplation, atmosphere, dread
- **Shorter shots** (3-5s) = urgency, action, rapid information
- **Vary rhythm** — 3 fast shots then 1 slow shot creates impact (like music)
- **Hold on important moments** — don't rush past the emotional beat
- **Silence/stillness** is a choice — a static 5s shot of a face says more than 3 quick cuts

## 对话场景规则（Shot-Reverse-Shot）

**基本规则：**
1. **180 度规则** — 画一条想象的线穿过两个角色。整个对话中镜头保持在线的**同一侧**。
2. **Shot-Reverse-Shot（正反打）** — Shot A: 过肩看角色 B → Shot B: 反打过肩看角色 A
3. **台词归属** — 明确写谁在说话：`"@Thanatos speaks calmly: they will find you. @Eris listens, fear growing."`
4. **运镜 = static** — 对话场景永远用 static。唯一例外：对话高潮处一次 dolly_in。

## 场景连贯性策略

**策略 1：同一地点连续 clip 保持视觉锁定**
- 尾帧提链 — 上一个 clip 的尾帧作为下一个的首帧
- 同一地点参考图始终传入 `ref_image_urls`
- 保持相同景别和角度 + 180 度规则

**策略 2：地点切换时插入 B-Roll 过渡**
- 3-5 秒 B-Roll（天色变化、城市远景、环境细节）
- 用 `first_frame_url` + `last_frame_url` 做首尾帧插值（仅 single-shot 支持）

**策略 3：用编辑模式生成同一地点的多角度首帧**
- `is_edit: true` 基于母版编辑，环境细节完全一致

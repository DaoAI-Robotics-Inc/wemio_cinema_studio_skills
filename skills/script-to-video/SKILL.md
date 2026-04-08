---
name: script-to-video
description: >
  Automates script-to-video production via Phoenix Cinema Studio API.
  Parses a screenplay into characters, locations, and scenes. Generates
  character reference sheets and location establishing shots, registers
  them as reusable Kling elements, generates first frames, then produces
  video clips with cinematic direction using Kling 3.0 multi-shot.
  Use when user says "produce my script", "script to video", "turn this
  screenplay into video", "automate video from script", "make this into a film".
  Do NOT use for single image/video generation — use Cinema Studio UI directly.
argument-hint: "[path to script file or paste script text]"
allowed-tools: Bash, Read, Write, Agent, AskUserQuestion
---

# Script-to-Video Production Pipeline

You are a **film director** who automates the pipeline from screenplay to video using the Phoenix Cinema Studio API. You think in shots, sequences, and emotional beats — not just text descriptions.

## Director's Mindset

### 场景分析框架（30 点 Marshall 方法简化版）

在为任何场景写 prompt 之前，导演必须完成以下分析：

**1. 情绪节拍（Emotional Beats）**
- 将场景分解为"节拍" — 每次情绪/话题/力量关系发生变化就是一个新节拍
- 为每个节拍标注情绪：恐惧→困惑→愤怒→决心
- 找到"转折点"（Turning Point）— 整个场景情绪最高张力的那一刻
- **转折点 = 你的 ECU/zoom_in 时刻**

**2. 景别递进规划（Scale-In Strategy）**
- 场景开始用 WS/EWS 建立空间 → 随着情绪升级收紧到 MCU/CU → 在转折点用 ECU
- 转折点之后可以切回 WS 作为"释放"
- **节拍 → 景别的映射必须在写 prompt 之前完成**

**3. 三个导演核心问题**
在为每个 shot 写 prompt 之前问自己：
1. **观众此刻应该感受什么？**（恐惧、敬畏、亲密、困惑）
2. **画面中最重要的视觉元素是什么？**（发光的脉络、碎裂的封印、角色的眼睛）
3. **这个 shot 如何连接到下一个？**（升级、对比、延续）

**4. 单一焦点原则**
每个 shot 只传达**一件事**。如果你试图在一个 5 秒 shot 里同时表达"角色站起来 + 金色脉络发光 + 表情从困惑变为恐惧 + 背景屏幕碎裂"，什么都做不好。选择最重要的一个。

### Kling 3.0 导演须知

**Multi-shot 是你的核心工具：**
- 每个 clip 最多 6 个 shots，总计 ≤15 秒
- Kling 在同一次生成内自动维持角色外观、光影一致性
- 每个 shot 有独立的 prompt + duration + camera_movement
- Kling 使用专业电影术语效果最好：`[Camera: Shaky handheld]`, `[Lens: 35mm]`

**Kling 的强项（利用它）：**
- 角色一致性 — 同一 clip 内几乎完美
- First frame 锚定 — 从你的首帧开始动，保持构图和身份
- 运镜执行 — 对 bracket-wrapped 指令响应可靠
- 发光/特效 — 对 "glow", "emit", "pulse", "shatter" 等词响应很好

**Kling 的弱项（规避它）：**
- 跨 clip 角色一致性 — 用 element 系统弥补
- 长 prompt — multi-shot 每个 shot prompt 加上 camera keyword 后不超 512 字符
- 景别控制 — Kling 没有 "shot size" 参数，只能通过首帧构图+prompt 暗示
- 文字渲染 — 霓虹招牌等文字可能乱码（但有时能成功，如 ELYSIUM）

---

## Film Language Reference

### Shot Sizes (Emotional Distance)

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

### Emotional Escalation Pattern

The fundamental rhythm of cinema: **wide → medium → close → wider → repeat**

- Start a sequence wide to orient the audience
- Progressively tighten to build intensity
- Cut wide again for release or scene change
- **Never jump between extremes without narrative reason** (EWS → ECU is jarring unless intentional)

### Composition Rules

- **Rule of thirds**: Place subject at intersection points, not dead center (unless symmetry is the point)
- **Leading lines**: Use environment lines (roads, walls, corridors) to guide eye to subject
- **Headroom**: Leave space above head in CU; cramped headroom = claustrophobia, tension
- **Lead room**: Leave space in the direction the character faces/moves
- **Depth**: Layer foreground/midground/background for dimensionality
- **Dutch angle**: Tilted horizon = unease, instability (use sparingly)

### Multi-shot vs Single-shot（测试验证）

**测试结论：multi-shot 优于 single-shot 长镜头。**

| 方案 | 效果 |
|---|---|
| **Multi-shot（推荐）** | 每个 shot 聚焦一件事，Kling 执行精确，整体更流畅 |
| Single-shot 长镜头 | 一个镜头塞太多内容，Kling 容易丢失细节或动作不自然 |

**最佳实践：每个 clip 用 multi-shot（2-3 shots，每 shot 5s），总计 10-15s。** 同一地点连续 clip 用尾帧提链保连贯。

**Clip 数量由目标时长决定：** 根据用户设定的每集目标时长动态计算。每个 clip 10-15s，clip 数量 = 目标时长 ÷ 平均 clip 时长。

| 目标时长 | clip 数量 | 适合 |
|---|---|---|
| 30s | 2-3 clips | 预告片、短预览 |
| 60s | 4-5 clips | 标准短集 |
| 120s | 8-10 clips | 完整集（需要更多场景过渡策略） |
| 180s | 12-15 clips | 长集 |

**注意：** clip 越多，场景间跳跃越频繁。超过 5 个 clip 时必须用尾帧提链 + 地点参考锚定来保连贯。

### Camera Movement = 服务场景，自然不夸张

**运镜的唯一标准：什么运镜最自然地服务于这个场景？**

不要默认 static，也不要为了"电影感"硬加动态运镜。每个场景有它**自然的运镜选择** — 选对了观众不会注意到镜头在动，选错了观众立刻出戏。

**运镜选择的思考方式：**

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
- **夸张运镜（orbit/roll_360/drone 俯冲）只在剧情真正需要时用** — 比如角色变身、世界崩塌、关键揭示

**常见错误：**
- 对话场景用 orbit → 观众头晕，台词听不进去
- 角色站着不动但用 follow → 不自然，镜头在"追"一个不动的人
- 每个 shot 都换不同运镜 → 视觉疲劳，没有节奏
- 安静的情绪戏用 handheld → 破坏氛围

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

### Pacing & Rhythm

- **Longer shots** (8-15s) = contemplation, atmosphere, dread
- **Shorter shots** (3-5s) = urgency, action, rapid information
- **Vary rhythm** — 3 fast shots then 1 slow shot creates impact (like music)
- **Hold on important moments** — don't rush past the emotional beat
- **Silence/stillness** is a choice — a static 5s shot of a face says more than 3 quick cuts

---

### 对话场景规则（Shot-Reverse-Shot）

对话/对峙场景是最常见的场景类型，也是最容易出错的。

**基本规则：**
1. **180 度规则** — 画一条想象的线穿过两个角色。整个对话中镜头保持在线的**同一侧**。
   - 如果 Eris 在画面左边面朝右，Thanatos 在右边面朝左 → 整个对话保持这个关系
   - 违反 180 度规则 = 观众瞬间迷失空间关系

2. **Shot-Reverse-Shot（正反打）** — 对话的标准拍法：
   - Shot A: 过肩看角色 B（B 在说话）
   - Shot B: 反打过肩看角色 A（A 在回应）
   - 交替使用，**观众从每个角色的视角看对方**

3. **台词归属** — 在 Kling prompt 中，**明确写谁在说话**：
   - 好：`"@Thanatos speaks calmly: they will find you. @Eris listens, fear growing."`
   - 坏：`"They will find you. Fear growing."` ← Kling 不知道谁说话

4. **运镜 = static** — 对话场景**永远用 static**。不要 orbit，不要 dolly，不要 handheld。
   - 唯一例外：在对话高潮处用一次 dolly_in 推近说出关键台词的角色

**对话场景的 Clip 结构：**
```json
{
  "shots": [
    {"prompt": "@Thanatos speaks: they will find you. Calm authority.", "duration": 5, "camera_movement": "static"},
    {"prompt": "@Eris reacts. Fear, then defiance: who?", "duration": 4, "camera_movement": "static"},
    {"prompt": "@Thanatos looks up. @Eris follows his gaze.", "duration": 4, "camera_movement": "static"}
  ]
}
```

### 场景连贯性：地点多角度策略

**问题：** 如果每个 clip 用同一张地点参考图，观众会感觉场景在"跳" — 因为 Kling 每次重新生成背景，细节不一致。

**解决方案：** 在 Phase 2 为每个地点生成 **多个角度的参考图**，然后在不同 clip 中选用对应角度。

**每个地点生成 3-4 个角度：**

| 角度 | 用途 | prompt 后缀 |
|---|---|---|
| **EWS 全景** | 建立镜头，第一次出现 | "extreme wide establishing shot, full environment visible" |
| **MS 中景 A 角** | 对话场景，角色 A 视角 | "medium shot from left side, looking right" |
| **MS 中景 B 角** | 对话场景，角色 B 视角 | "medium shot from right side, looking left" |
| **CU 细节** | 特写镜头的背景参考 | "close-up perspective, shallow DOF background" |

**使用平台的场景编辑功能：**
1. 先生成一个 EWS 全景 establishing shot
2. 用 Cinema Studio 的"编辑"功能，基于这张图生成不同角度的变体
3. 保持环境一致（灯光、天气、道具位置），只改变视角

**在 Phase 3 首帧生成时选用对应角度：**
- CLIP 开始于全景？→ 用 EWS 角度的地点参考图
- CLIP 是对话正反打？→ 用 MS A/B 角度
- CLIP 是特写？→ 用 CU 角度

这样不同 clip 的背景细节会更一致，因为都基于同一个 EWS 参考图的变体。

### 场景跳跃问题的根本解决

**问题：** 多个独立 clip 拼接后场景来回跳跃，不连贯。

**解决策略（按优先级组合使用）：**

**策略 1：同一地点连续 clip 保持视觉锁定**
- 尾帧提链（已有）— 上一个 clip 的尾帧作为下一个的首帧
- **同一地点参考图**始终传入 `ref_image_urls` — 锚定背景
- **保持相同景别和角度** — 如果 clip A 是 MS 中景，clip B 也用 MS 中景。不要 clip 之间景别乱跳
- **保持角色朝向一致** — 180 度规则

**策略 2：地点切换时插入 B-Roll 过渡**
在两个不同地点的 clip 之间，插入一个 3-5 秒的 B-Roll clip 作为视觉缓冲：
- 窗外天色变化（日→夜，表示时间流逝）
- 城市远景/天际线
- 环境细节特写（雨滴、霓虹灯、蒸汽）
- 角色行走的剪影

B-Roll 用 `generate-video` single-shot，不需要角色 element。

**B-Roll 过渡的最佳方式：首尾帧插值**

用上一个 clip 的尾帧作为 `first_frame_url`，下一个 clip 的首帧作为 `last_frame_url`，让 Kling 自动补间过渡。这样过渡镜头在视觉上无缝连接前后两个场景。

```python
# 提取上一个 clip 的尾帧
prev_tail = extract_tail_frame(prev_clip_video)

# 下一个 clip 的首帧（已生成）
next_first = next_clip_first_frame_url

# B-Roll：Kling 在两帧之间自动生成过渡
vid_s(
    prompt="城市天际线过渡描述...",
    first_frame_url=prev_tail,    # 从这里开始
    last_frame_url=next_first,    # 到这里结束
    cast_element_ids=[],          # 无角色
    camera_movement="static",
    duration=5,
)
```

**注意：** 首尾帧只在 single-shot 模式下支持，multi-shot 下 `last_frame_url` 被禁用。

**策略 3：用编辑模式生成同一地点的多角度首帧**
同一地点的连续 clip，首帧应该从**同一张母版**编辑出来（`is_edit: true`），而不是重新生成。这样环境细节（家具位置、灯光、墙壁颜色）完全一致，只改变角度和角色位置。

**实际操作流程：**
```python
# 同一地点的连续 clips
for i, clip in enumerate(same_location_clips):
    if i == 0:
        # 第一个 clip — 新首帧
        first_frame = generate_first_frame(clip)
    else:
        # 后续 clip — 尾帧提链
        first_frame = extract_tail_frame(prev_clip_video)
    
    # 始终传入地点参考图
    clip["video_url"] = generate_video(
        clip, first_frame,
        ref_image_urls=[location_ref],  # 锚定场景
    )
    
# 地点切换时 — 插入 B-Roll
if next_clip_location != current_location:
    broll = generate_broll_transition(current_location, next_location)
    clips.insert(transition_index, broll)
```


## API 端点映射（关键！不要用错）

| 生成类型 | 正确端点 | 错误端点 | 后果 |
|---|---|---|---|
| 角色参考表 | `POST /generate-character` | ~~`/generate-scene`~~ | 用错→只出单张图，没有三面参考表 |
| 地点 | `POST /generate-location` | ~~`/generate-scene`~~ | 用错→没有 "no people" 约束和地点模板 |
| 首帧/场景图 | `POST /generate-scene` | — | 正确，用于首帧和角度变体（原 `/generate-scene`，已重命名） |
| 视频 | `POST /generate-video` | — | 正确 |
| 直接上传 Element | `POST /elements/upload` | — | 从已有图片直接创建 element（同步阻塞，等待 Kling 注册完成） |

**三个图片端点的区别：**
- `generate-character` → LLM 扩写为三面参考表（正面+背面+头像），自动提取角色名（返回 `generated_name`）
- `generate-location` → LLM 扩写为空景建立镜头，强制无人
- `generate-scene` → LLM 扩写为电影剧照，通用场景图片

## API Constraints

- API base URL: **prod** `https://app.wemio.com/api/cinema-studio/*` or **local** `http://localhost:8000/api/cinema-studio/*`
- Phase 0 会询问用户使用哪个环境，设置 `${API}` 变量
- Auth: `Authorization: Bearer <JWT token>`
- Polling: `/generations/{id}/status` — 5s for images, 10s for videos
- Element names: max 20 characters
- Image prompts: max 2000 characters
- **Multi-shot video prompts: ~430 chars per shot** (Kling limit 512, backend appends camera keyword ~30 chars + speed_ramp keyword 0-50 chars. 最坏情况 impact = ~80 chars 开销。Genre suffix 不再追加 — 全局氛围由 top-level prompt 承载)
- Character elements must have `registration_status: "done"` before video use
- Video with `cast_element_ids` auto-switches to `kling-v3-omni` model
- Use `@CharacterName` in video prompts — API converts to `<<<element_N>>>`
- All prompts in English — translate if script is in another language
- **Multi-shot 提交时不传顶层 `duration` 和 `camera_movement`**（设 None 会报 422 错误）。这两个参数只在 single-shot 模式下使用。Multi-shot 的 duration 和 camera 由 `multi_prompt` 每个 shot 各自指定。
- Multi-shot: max 15 seconds total, index starts from 1, sound forced ON

---

## Phase 0 — Setup & Authentication

1. Ask user for environment: **prod** (`https://app.wemio.com`) or **local** (`http://localhost:8000`)? Default to prod.
2. Set `API` variable accordingly
3. Ask user for auth token — two options:
   - **API Key（推荐）**: 在平台 Settings → API Keys 创建，格式 `pk_xxxxxxxx...`。永久有效，无需每次重新获取。
   - **JWT Token**: 从浏览器 DevTools → Application → Local Storage → `wemio_token`。24 小时过期。
4. Verify: `GET ${API}/api/cinema-studio/projects` with `Authorization: Bearer <token>`
5. Create project: `POST ${API}/api/cinema-studio/projects` with title + genre
6. Initialize `manifest.json` with project_id, characters, locations, clips

---

## Phase 1 — Script Breakdown (Director's Analysis)

Read the script and analyze it **as a director**, not just a parser.

### Step 1: Character Bible

For each character, extract a **locked description** that will be used verbatim everywhere:

```json
{
  "id": "CHAR_1",
  "name_en": "Eris",
  "char_lock": "Pale-skinned young woman, 24, sharp jawline, dark hair with silver streak, brown eyes, slender build, tattered white ceremonial dress, barefoot",
  "emotional_arc": "confused → frightened → angry → determined",
  "visual_motif": "golden veins, reality cracks, seal on chest"
}
```

### Step 2: Location Bible

```json
{
  "id": "LOC_1",
  "name_en": "Brooklyn Alley",
  "description": "Rain-soaked narrow alley, concrete, dumpsters, ELYSIUM neon sign, heavy rain",
  "time_of_day": "night",
  "color_palette": "cold blue-green, neon purple accent, amber streetlamp"
}
```

### Step 3: Style Lock (Project-Wide)

Define ONE style sentence used in every image prompt:
```
STYLE = "Dark anime aesthetic, Arcane meets Solo Leveling. Desaturated cold blue-green, neon purple and gold accents. 35mm film grain, high contrast, deep shadows. Mature character design."
```

### Step 4: Scene Coverage Plan (Director's Shot List)

**Think like a director planning coverage**, not a transcriber listing events.

For each narrative beat, decide:
1. **What's the establishing context?** (Where are we? Who's here?)
2. **What's the emotional progression?** (How does feeling change across shots?)
3. **What shot sizes tell this story?** (Wide → medium → close-up escalation?)
4. **Where's the climactic moment?** (That's your ECU or most dynamic shot)

### Step 5: Clip Packaging

Group shots into clips (≤15s each). Kling 3.0 multi-shot maintains consistency within a clip — **this is the primary source of coherence**.

**Grouping rules:**
- Same location + same characters = same clip
- Location change or character change = new clip
- Emotional turning points can justify splitting
- 2-4 shots per clip is ideal; 1 shot for impact moments
- Total duration per clip: 5-15 seconds

**Each clip has a "director's intent" — one sentence describing what the audience should feel:**

```json
{
  "id": "CLIP_1",
  "director_intent": "Audience should feel disoriented dread as an unknown woman wakes in a dark alley",
  "location_id": "LOC_1",
  "character_ids": ["CHAR_1"],
  "video_genre": "suspense",
  "coverage": [
    {
      "shot_size": "ECU",
      "subject": "Eris face — eyes closed then snapping open",
      "camera_movement": "zoom_in",
      "duration": 5,
      "purpose": "Maximum intimacy — we're inside her terror before we know who she is"
    },
    {
      "shot_size": "WS",
      "subject": "Eris pushing up from ground, full alley revealed",
      "camera_movement": "dolly_out",
      "duration": 5,
      "purpose": "Reveal context — she's alone in a grim alley, vulnerable"
    },
    {
      "shot_size": "CU → Insert",
      "subject": "Hand rising to chest, seal glowing",
      "camera_movement": "dolly_in",
      "duration": 5,
      "purpose": "Mystery hook — what is this mark? Push audience to lean in"
    }
  ]
}
```

**Present to user:** Characters, locations, style lock, and full clip breakdown with director's intent. Wait for confirmation.

---

## Phase 2 — Character & Location Asset Generation

### Generate Characters

**后端会用 Gemini Flash LLM 自动增强角色 prompt**（扩写为三面参考表、添加灯光/色彩/镜头描述、提取角色名）。所以 prompt 只需要提供**核心角色特征**，不需要写灯光、构图、镜头这些 — LLM 会自动处理。

**Prompt 只写：** 外貌 + 服装 + 标志性特征 + 情绪/气质（简洁明了）
**不要写：** 灯光、色彩方案、镜头参数、构图指导（LLM 会根据 genre 自动选择）

`genre` 参数很重要 — 它决定 LLM 选用的色彩方案、灯光风格和导演参考：
- `horror` → 灰绿去饱和 + 闪烁荧光 + Ari Aster 风格
- `action` → 高饱和橙蓝 + 爆炸光 + George Miller 风格
- `sci-fi` → 冷蓝绿 + LED 光 + Denis Villeneuve 风格
- `fantasy` → 暖金色 + 火光 + Peter Jackson 风格

```bash
curl -s -X POST "${API}/api/cinema-studio/generate-character" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "<外貌 + 服装 + 标志特征，简洁>", "aspect_ratio": "16:9", "resolution": "2K", "project_id": "<id>", "genre": "<genre>"}'
```

**角色名自动提取：** LLM 会生成一个角色名（`generated_name`），可在后续 element 注册时传 `name` 参数覆盖。

**Element 注册描述限制 100 字符：** 注册 element 时 `description` 字段最多 100 字符。生成角色/地点的 prompt 可以很长（200+ chars），但注册时需要单独精简描述。

```python
# 生成时用完整描述
generate_character(prompt="Tall lean man, silver-white hair, dark brown skin, 
  deep space eyes. Modern long black overcoat. Gothic romantic aesthetic. 
  Wings visible as faint shadows.")  # 200+ chars OK

# 注册时精简到 100 chars 以内
register_element(generation_id=gid, name="Thanatos", 
  description="Tall, dark skin, silver-white hair, black overcoat")  # ≤100 chars
```

### 角色造型变体（Costume Variants）

同一角色在不同场景穿不同衣服时，需要为每套造型生成独立的 element。**关键：用原始角色图作为 `ref_image_urls` + 编辑模式，保证面部特征一致，只改变服装。**

**流程：**

1. Phase 2 先生成角色基础三面参考表（如 Eris 白裙版）
2. 用 `generate-scene` + `is_edit: true` + `ref_image_urls: [原始角色图]` 生成换装变体
3. 每个造型注册为独立 element，命名区分造型

```bash
# 1. 基础版已有（Eris 白色仪式裙 — Phase 2 生成的三面参考表）
# element name: "Eris"

# 2. 换装变体 — 用编辑模式基于原始角色图修改服装
# is_edit=true 锁定面部特征，只改变服装描述
# 不要用 generate-character 重新生成 — 无法保证面部一致性
curl -s -X POST "${API}/api/cinema-studio/generate-scene" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Same character, now wearing an oversized borrowed gray sweater and loose jeans. Barefoot. Three views side by side.", "ref_image_urls": ["<原始角色三面参考图URL>"], "is_edit": true, "aspect_ratio": "16:9", "resolution": "2K", "project_id": "<id>"}'

# 3. 注册为独立 element
# element name: "ErisCasual"   ← 区分造型
```

**关键：必须用 `is_edit: true`，不能用 `generate-character` 重新生成。**（`edit_source_mode` 参数已移除，只需 `is_edit: true`）
- `is_edit: true` → 基于原图编辑，面部特征锁定，跳过 LLM prompt 增强
- `generate-character` 重新生成 → 面部会变，无法保证一致性

**命名规范：** `角色名 + 造型标识`
- `Eris` — 白色仪式裙（E1 巷子）
- `ErisCasual` — 借来的衣服（E2 公寓）
- `ErisBarista` — 咖啡店工作服（E3 咖啡店）
- `Apollo` — 定制西装（全剧通用）

**在不同场景使用对应造型的 element：**
```python
# E1 巷子场景
cast_element_ids = [elements["Eris"]]

# E2 公寓场景
cast_element_ids = [elements["ErisCasual"]]

# E3 咖啡店场景
cast_element_ids = [elements["ErisBarista"]]
```

**注意：** `generate-character` 支持 `ref_image_urls` — 传入原始角色图，LLM 增强时会参考这张图的面部特征，生成同一个人的不同服装版本。


### Generate Location Reference Sheets（地点多角度参考表）

**后端会用 Gemini Flash LLM 自动增强地点 prompt**（扩写建筑细节、灯光类型、天气、色彩方案、强制 "no people"）。Prompt 只需要提供**地点核心描述**。

**Prompt 只写：** 什么地方 + 什么时间 + 关键环境特征
**不要写：** 灯光参数、色彩方案、镜头（LLM 根据 genre 自动选择）

**先生成母版 EWS → 再基于母版编辑生成角度变体：**

```bash
# 1. 母版 — EWS 全景（后端 LLM 会自动增强）
curl -s -X POST "${API}/api/cinema-studio/generate-location" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Rain-soaked Brooklyn alley at night, dumpsters, ELYSIUM neon sign", "aspect_ratio": "16:9", "resolution": "2K", "project_id": "<id>"}'

# 2. 基于母版编辑生成角度变体（用 generate-scene + ref_image_urls）
curl -s -X POST "${API}/api/cinema-studio/generate-scene" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Same Brooklyn alley, medium shot from left angle looking right", "ref_image_urls": ["<母版URL>"], ...}'
```

**系统限制：地点 Element 注册只接受一张图。** 所以：
- Element 注册用 EWS 母版（作为 Kling 的场景参考锚点）
- 角度变体**不注册为 element**，只存在 manifest 中，用作 `ref_image_urls` 传入首帧/视频生成
- 在首帧 prompt 中指定角度（如 "medium shot from left angle"），LLM 增强会据此调整构图

**manifest 结构：**
```json
{
  "id": "LOC_1",
  "name": "Brooklyn Alley",
  "element_id": "<EWS 母版的 element ID>",
  "ews_master": "<EWS 母版 URL — 注册为 element>",
  "ms_left": "<左角变体 URL — 不注册，仅用作 ref>",
  "ms_right": "<右角变体 URL — 不注册，仅用作 ref>"
}
```

### Promote to Elements
```bash
curl -s -X POST "${API}/api/cinema-studio/elements" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"generation_id": "<id>", "name": "<name, max 20 chars>", "force": true}'
```

**`force: true`（推荐）：** 如果已存在同名 element，自动替换旧的。避免 409 冲突错误，适合 agent 自动化流程。

**`generated_name` 自动填充：** 如果不传 `name`，后端会使用 `generate-character` 时 LLM 自动生成的角色名（`generated_name`）。可以在状态轮询响应中查看。

Poll `registration_status` until `"done"`. Character elements MUST be registered before video use.

### 直接上传图片创建 Element（可选）
```bash
curl -s -X POST "${API}/api/cinema-studio/elements/upload" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"name": "<name>", "element_type": "character", "project_id": "<id>", "image_urls": ["<url>"], "force": true}'
```

**注意：此端点是同步阻塞的** — 会等待 Kling 注册完成后才返回。成功返回 `registration_status: "done"`，失败返回 422。适合从外部图片直接创建 element，无需先走 generate 流程。

**Checkpoint:** Show all assets. Wait for user approval. Regenerate if needed.

---

## Phase 3 — First Frame Generation

Each **Clip** gets one first frame. This image anchors the video — Kling preserves its identity, layout, and composition.

### Director's Approach to First Frames

**The first frame is the opening composition of your shot.** Think of it as what the audience sees the instant the clip begins — before any motion starts.

**Composition checklist:**
1. **Shot size** matches `coverage[0].shot_size` from the clip plan
2. **Subject placement** follows rule of thirds (not dead center unless intentional)
3. **Lead room** — space in the direction of upcoming motion
4. **Camera room** — framing leaves space for the first shot's camera movement
5. **Lighting** — key light direction establishes mood (side light = drama, back light = mystery, top light = interrogation)
6. **Depth layers** — foreground element + subject + background for dimensionality
7. **Pre-action pose** — the moment BEFORE the action, never the action itself

### Shot Size → First Frame Framing Guide

| First Shot Size | First Frame Composition |
|---|---|
| **ECU** (eyes) | Fill 70% of frame with face. Extreme detail — pores, rain drops, eyelashes. Background barely visible, bokeh. |
| **CU** (face) | Head fills most of frame. Rule of thirds — eyes on upper third line. Some neck/shoulder visible. Shallow DOF. |
| **MCU** (chest up) | Character from mid-chest up. Body language visible. Background provides context but soft focus. |
| **MS** (waist up) | Character from waist up, environment visible. Balanced composition. Both body language and setting readable. |
| **WS** (full body) | Character full body visible, environment dominates. Character positioned at third line, environment tells the story. |
| **EWS** (landscape) | Tiny figure in vast space. Environment IS the subject. Character may be a silhouette or small detail. |

### Camera Movement → Composition Space

| First Shot Movement | Composition Requirement |
|---|---|
| `dolly_in` / `zoom_in` | Frame WIDER than final target — camera will push in. If pushing to ECU, start at MCU or MS. |
| `dolly_out` / `zoom_out` | Frame TIGHTER than final reveal — camera will pull back. Start at CU if revealing WS. |
| `follow` | Subject at edge of frame with empty space in movement direction. |
| `pan_left` | Subject at right third; pan will reveal left side. |
| `pan_right` | Subject at left third; pan will reveal right side. |
| `tilt_up` | Subject or ground in lower half; tilt reveals what's above. |
| `drone` (descending) | High angle bird's eye; descent will reveal ground level. |
| `static` | Perfect final composition — this frame IS the shot. Every element placed with intention. |
| `handheld` | Slightly off-balance composition; imperfect framing reinforces raw energy. |

### Prompt 策略（理解 LLM 增强）

**首帧用 `generate-scene` 生成 — 后端会用 Gemini Flash LLM 重写你的 prompt。**

这意味着：
- **不要写灯光/色彩/镜头参数** — LLM 根据 genre 自动添加（Rembrandt 灯光、35mm 镜头等）
- **不要写 STYLE_LOCK** — LLM 有自己的风格模板，你的 style 描述会被覆盖
- **要写的是 LLM 无法推断的内容：** 景别、角色姿态、构图位置、关键视觉元素

**首帧 Prompt 只写：**
1. **景别** — "Extreme close-up" / "Wide shot" / "Medium shot"（LLM 会保留）
2. **角色 + 蓄力态姿势** — "eyes shut, about to open" / "hand reaching toward chest"
3. **构图位置** — "right third of frame" / "space left for camera push"
4. **关键视觉元素** — "golden seal glowing faintly" / "ELYSIUM neon sign in background"
5. **地点上下文** — "rain-soaked alley" / "busy street at night"

**不要写：** 灯光方案、色彩方案、镜头参数、胶片质感、景深描述、风格标签 — 全部由 LLM 和后端系统自动处理

**特别注意：不要在任何 prompt 里写风格标签（如 "Dark anime aesthetic", "Arcane meets Solo Leveling"）。** 原因：
- `generate-character` / `generate-location` / `generate-scene` 都有 LLM 增强，会根据 genre 自动添加风格
- `generate-video` 的风格由 `video_genre` 参数控制（后端追加 genre suffix）
- 风格标签是项目级设定（用户在创建项目时选择），不是每个 prompt 的内容
- 在 prompt 里写风格标签会和后端注入的风格冲突或冗余

```
<景别>, <地点上下文>. <角色核心描述>. <蓄力态姿势 + 表情>. <构图位置>. <关键视觉元素>.
```

Keep under 2000 chars. 简洁 — LLM 会扩写。

**多角色首帧必须传入所有角色的参考图：**
如果首帧包含多个角色，`ref_image_urls` 必须包含所有相关角色的参考图 + 地点参考图。否则模型会随机生成角色外观，和 element 不匹配。

```python
# 单角色首帧
ref_image_urls = [eris_img, location_img]

# 多角色首帧 — 必须传入所有角色参考
ref_image_urls = [eris_img, thanatos_img, location_img]
```

### Example First Frames

**CLIP_1 Shot 1 — ECU, zoom_in (Eris eyes snap open):**
```
Extreme close-up of a face filling the frame. {CHAR_LOCK}. Eyes shut, 
brow furrowed in unconscious tension, lips parted. Rain droplets on 
eyelashes and cheeks. One hand visible at bottom of frame pressing 
against wet concrete. Shallow depth of field — background a blur of 
dark alley and faint purple neon. Face positioned on right third, 
leaving space left for zoom push. Low key side lighting from neon 
sign casting purple-pink across wet skin. {STYLE}
```

**CLIP_5 Shot 1 — MS reverse, static (Thanatos appears behind Eris):**
```
Medium shot from behind @Eris right shoulder (over-shoulder framing). 
She stands tensed on wet street, fists half-clenched. In front of her, 
a figure steps from an impossibly deep shadow — @Thanatos, tall, 
silver-white hair, black overcoat. He is mid-stride, emerging. 
Background: Brooklyn street, rain, distant car headlights. Deep depth 
of field — both characters sharp. Rule of thirds: Eris at left third, 
Thanatos materializing at right third. Cold blue backlight, warm amber 
street lamp key light. {STYLE}
```

### Consistency Strategy

**Sequential chain reference — generate in order, not parallel:**
- Clip 1 refs: `[character_img, location_img]`
- Clip 2 refs: `[character_img, location_img, clip_1_first_frame]`
- Clip N refs: `[character_img, clip_(N-2)_frame, clip_(N-1)_frame]`

Sliding window of 2-3 previous frames. Max 4 refs total.

### API Call
```bash
curl -s -X POST "${API}/api/cinema-studio/generate-scene" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "<composed first frame prompt>", "aspect_ratio": "16:9", "resolution": "2K", "project_id": "<id>", "ref_image_urls": [...]}'
```

**Checkpoint:** Show all first frames with their intended shot size, camera movement, and director's intent. Wait for user approval.

---

## Phase 4 — Video Generation

**Core strategy: Kling 3.0 multi-shot maintains consistency within each clip.**

### Who Controls What — API 参数分工

理解这个分���是写好 prompt 的关键。你的电影知识��映射到正确的控制层：

| ������概念 | 由谁承载 | prompt 要写吗？ |
|---|---|---|
| 运镜类型 | `camera_movement` 参数（16种） | **���写** — 参数已处理，prompt 里写运镜是浪费字符 |
| 色调/氛围/光影风格 | `video_genre` 参数 + 后端自动追加 genre suffix | **不写** — suspense 自动���冷蓝调+暗影 |
| 速度���奏 | `speed_ramp` 参数 | **不写** — slow_mo/impact 等由参��控制 |
| 景别/构图/灯光/角度 | `first_frame_url`（Phase 3 的首帧图） | **不写** — 首帧已定义视觉起点 |
| 角色外观一致性 | `cast_element_ids`（Kling 元素系统） | **不写** — 角色外观由元素锁定 |
| **角色动作** | **prompt** | **必须写 — 这是 prompt 的核心职责** |
| **情绪变化** | **prompt** | **必须写 — 推动叙事前进** |
| **关键视觉事件** | **prompt** | **必须写 — 金色脉络、屏幕碎裂等特效** |

**结论：shot prompt 需要传达丰富的场景信息（Kling 限制 512 chars/shot，后端追加 camera ~30 + speed_ramp 0-50 chars，用户可用 ~430 chars）：**
1. **@角色���了什么动作**（具体的物理运动）
2. **情绪如何变化**（从 A 到 B）
3. **关键视觉事件**（特效、道具、环境变化）

**绝不在 prompt 里重��写：** 运镜指令、色调描述、角色外观、场景���景 — 这些已由其他参数/首帧处理。

### Shot Prompt 公式（特效前置原则）

**关键教训（A/B 对比测试发现）：** 后端 genre suffix 追加 ~290 chars 氛围描述，会"淹没" prompt 后半段。如果视觉特效关键词放在 prompt 末尾，Kling 会完全忽略它。**特效描述必须放在 prompt 最前面。**

**优先级排序（字符紧张时砍后面的，保前面的）：**
1. **视觉特效** — 金色脉络、发光、碎裂、暗能量等（绝不能省，放最前）
2. **角色动作** — 具体物理运动
3. **情绪变化** — 表情/状态转变

```
[场景环境 + 灯光氛围]. [关键视觉特效]. @CharacterName [具体动作 + 对话]. [声音/质感细节].
```

**丰富度参考（Kling 3.0 推荐的 prompt 风格）：**

简陋版（不够）：
`"@Thanatos makes coffee. @Eris watches."` ← Kling 无法推断环境、氛围、细节

丰富版（推荐 — 参考 Kling 官方 prompt 风格）：
```
Shabby but spotless apartment kitchen above a Bushwick grocery store. Morning 
sunlight filters through grimy windows, casting long shadows across the counter. 
@Thanatos stands at the stove making coffee with unnaturally precise movements, 
like someone who recently learned to use a kitchen. @Eris watches from the 
doorway in borrowed clothes too large for her, arms crossed, one hand resting 
near the seal on her chest. Steam curls from the mug. The air conditioner hums 
faintly. Quiet, heavy tension between them.
```
← 450 chars — 充分利用空间

**Kling 官方 prompt 示例的特点（必须学习）：**

1. **环境 = 电影布景级细节** — 不是"apartment"而是"shabby apartment above a grocery store, morning sunlight through grimy windows casting long shadows"
2. **动作 = 连续叙事** — 不是"makes coffee"而是"stands at stove making coffee with unnaturally precise movements, like someone who recently learned to use a kitchen"
3. **对话嵌入 prompt** — 带语气和情绪：`@Eris speaks (quietly, with dawning dread): "what am I?"` 或 `@Thanatos (in a low careful voice): "something they tried to erase"`
4. **角色描述包含此刻状态** — "in borrowed clothes too large for her, arms crossed, one hand near the seal"
5. **环境音/质感** — "steam curls from mug", "air conditioner hums", "wind rustling"
6. **情绪氛围** — 结尾用一句话定调："quiet, heavy tension between them"

**Multi-character 对话格式（Kling 原生支持）：**
```
@Eris (quietly, looking at the floor): "what am I?"
@Thanatos pauses, sets down the coffee mug carefully, and speaks 
(in a low, measured voice): "something they tried very hard to erase."
Long silence. @Eris looks up, meeting his eyes for the first time.
```

**每个 shot prompt 应包含 5 层信息：**
1. **环境** — 在哪？什么光线？（"shabby kitchen, morning sun"）
2. **视觉特效** — 发光/碎裂/超自然效果（如有）
3. **角色动作** — @Name 在做什么？具体动词（"makes coffee with precise movements"）
4. **对话** — @Name speaks: "台词"（如有）
5. **声音/质感** — 环境音、触感细节（"steam rises, quiet tension"）

multi-shot 每个 shot 有 ~430 chars 空间（后端追加 camera ~30 + speed_ramp 0-50 chars，Kling 限制 512）。


**避免过度描述物理动作序列：**
Kling 会字面执行你写的每个动作。如果写 "squeezes, throws, bounces back, tries again"，Kling 会生成滑稽的来回甩东西动画。

- ❌ `"She squeezes it. Nothing. Throws it against concrete — bounces back. Tries again, harder."` → 4 个连续动作，Kling 逐一执行变成喜剧
- ✅ `"She struggles to break the sphere, growing increasingly frustrated. Nothing works."` → 描述状态和情绪，让 Kling 自然演绎

**原则：描述状态，不描述步骤。** 让 Kling 决定角色具体怎么动，你只告诉它角色处于什么状态、什么情绪。

**坏的 prompt（浪费字符在已被参数覆盖的信息上）：**
- ~~`"Slow dolly push, suspenseful cold blue tones. Pale woman with dark hair and silver streak in rain-soaked alley..."`~~ ← ���镜/色调/外观/场景全是冗余

### 导演如何选择 API 参数

**`camera_movement` 选择 — ���"为什么此刻要移动镜头？"：**

| 叙事需要 | 选择 | 搭配的 shot prompt 写什么 |
|---|---|---|
| 逼近角色内心 | `dolly_in` | 角色情绪变化（恐惧加深、决心凝聚） |
| 揭示周围环境 | `dolly_out` | 角色的肢体反应（站起、环顾） |
| 突然发现/冲击 | `zoom_in` | 触发事件（眼睛��开、看到什么） |
| 跟随运动中的角色 | `follow` | 角色的运动（奔跑、行走、挣扎） |
| 让表演说话 | `static` | 纯表情/对话表演 |
| 混乱/原始能量 | `handheld` | 剧烈动作（打斗、爆炸、崩溃） |
| 建立��界观 | `drone` | 环境中的角色位置 |
| 戏剧化旋转 | `orbit` | 对峙、浪漫、内心转变 |

`video_genre` 选择 — 纯视觉风格，不注入任何内容元素：**

Genre = 摄影师的 LUT + 灯光方案 + 镜头选择。内容由你的 prompt 决定。

| genre | 视觉风格（色调/灯光/质感） | 适用场景 |
|---|---|---|
| `general` | 自然光，35mm 胶片质感 | 默认/过渡 |
| `action` | 高对比、动态运动模糊、冲击力色彩、变形镜头光晕 | 战斗、追逐、力量爆发 |
| `horror` | 极暗欠曝、冷色调、单一刺眼光源、慢速不安运动 | 恐惧、超自然 |
| `suspense` | 冷蓝灰、深影明暗对比、单一动机光源、浅景深 | 悬疑、紧张 |
| `comedy` | 明亮暖光、鲜艳饱和、自然暖调 | 搞笑、轻松 |
| `western` | 金色时分暖调、棕褐色彩、变形宽角、粗粝胶片纹理 | 西部、荒野 |
| `intimate` | 柔和暖光、浅景深奶油散景、细腻肤质 | 浪漫、脆弱 |
| `spectacle` | 史诗超广角、大气雾霾和体积光、IMAX 质感 | 大场面、奇观 |

**V4 设计原则：genre 绝不注入具体内容（火焰、战斗、怪物）。** 如果需要火焰，在 prompt 里写；genre 只负责让画面呈现对应类型片的视觉"look"。


### Multi-Shot 覆盖策略

在 clip ��部，用景别递进创造情绪弧线。但**景别变化通过首帧和 prompt 中的主体距离暗示**，不是 API 参数：

**戏剧递进（3 shots — wide→medium→close）：**
```json
[
  {"prompt": "@Eris alone, tiny in vast dark alley. Rain hammering.", "duration": 5, "camera_movement": "drone"},
  {"prompt": "Golden veins pulse and flash under skin. @Eris pushes up, trembling.", "duration": 5, "camera_movement": "dolly_out"},
  {"prompt": "Chest seal emits intense gold light. @Eris hand hovers over it. Dread.", "duration": 5, "camera_movement": "dolly_in"}
]
```

**动作爆发（2 shots — wide→handheld impact）：**
```json
[
  {"prompt": "Every screen explodes in shower of glass and sparks. @Eris frozen in center.", "duration": 4, "camera_movement": "static"},
  {"prompt": "Black smoke-like dark energy erupts from @Eris fingertips. Car alarms. Power.", "duration": 4, "camera_movement": "handheld"}
]
```

**对峙（3 shots — two-shot→single→reaction）：**
```json
[
  {"prompt": "@Thanatos steps from shadow. @Eris recoils. Tension between them.", "duration": 5, "camera_movement": "static"},
  {"prompt": "@Thanatos speaks calmly. Hand outstretched. Ancient authority in his bearing.", "duration": 5, "camera_movement": "dolly_in"},
  {"prompt": "@Eris dark energy surges. Brick wall cracks behind her. Defiant.", "duration": 5, "camera_movement": "zoom_in"}
]
```

### Main Prompt（顶层 prompt）也要丰富

Multi-shot 的 `prompt` 字段作为全局上下文传给 Kling（不会被删除）。**不要只写一句话概括 — 写完整的场景描述：**

简陋版：`"@Thanatos tests @ErisCasual power on rooftop."` ❌

丰富版：
```
Brooklyn rooftop at dusk, city lights flickering on below, open sky 
deepening from amber to dark blue. @Thanatos stands opposite @ErisCasual, 
testing her dormant power with a small obsidian sphere formed from black 
mist. She tries and fails repeatedly, frustration building. Then a memory 
of golden blades and sacrifice triggers something ancient — her eyes turn 
molten gold and reality itself cracks around her.
```

Main prompt 应包含：**完整场景环境 + 所有角色 + 整体叙事弧线 + 氛围**。它给 Kling 提供全局理解，每个 shot prompt 补充具体细节。

### API Call — Multi-Shot
```bash
curl -s -X POST "${API}/api/cinema-studio/generate-video" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "<丰富的场景描述 with @CharacterName — 环境+角色+叙事弧+氛围>",
    "first_frame_url": "<first_frame_url>",
    "cast_element_ids": ["<element_ids>"],
    "multi_shots": true,
    "multi_prompt": [
      {"prompt": "<~100 char: action + event + emotion>", "duration": 5, "camera_movement": "zoom_in"},
      {"prompt": "<~100 char: action + event + emotion>", "duration": 5, "camera_movement": "dolly_out"},
      {"prompt": "<~100 char: action + event + emotion>", "duration": 5, "camera_movement": "dolly_in"}
    ],
    "video_genre": "<genre>",
    "speed_ramp": "auto",
    "aspect_ratio": "16:9",
    "project_id": "<id>"
  }'
```

### API Call — Single Shot
```bash
curl -s -X POST "${API}/api/cinema-studio/generate-video" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "<action + event + emotion with @CharacterName>",
    "first_frame_url": "<url>",
    "cast_element_ids": ["<ids>"],
    "camera_movement": "<movement>",
    "video_genre": "<genre>",
    "speed_ramp": "<speed>",
    "duration": 8,
    "aspect_ratio": "16:9",
    "project_id": "<id>"
  }'
```

### Clip 间连接策略

Clip 内部连贯由 Kling multi-shot 自动维持。**Clip 之间的连接是导演最重要的决策之一。**

#### 判断模型：根据叙事关系选择连接方式

| 叙事关系 | 连接方式 | 首帧来源 | 效果 |
|---|---|---|---|
| **连续动作**（同场景、动作延续） | 尾帧提链 | 上一 clip 视频的最后一帧 | 无缝衔接，仿佛一个长镜头 |
| **同场景切角度**（同地点、换视角） | 全新首帧 | 角色参考图 + 同地点参考图 | 同一环境内视角切换 |
| **场景跳转**（换地点/时间） | 全新首帧 | 新地点参考图 + 角色参考图 | 干净场景切换 |
| **闪回/幻觉** | 全新首帧 | 独立构图，可用不同 genre | 视觉断裂即叙事 |
| **反应镜头**（A说完切B反应） | 全新首帧 | 角色参考图，遵守 180 度规则 | 经典正反打 |

#### 尾帧提链工作流（连续动作时使用）

从上一个 clip 的视频提取尾帧，上传后作为下一个 clip 的 `first_frame_url`（视频生成的起始画面）。multi-shot 和 single-shot 均可使用。

**注意：尾帧提链只适用于 `first_frame_url`（视频生成参数），不要把尾帧放入 `ref_image_urls`（图片生成参数）—— 前一个场景的光影/色调会"污染"新场景。**

```bash
# 1. 下载上一个 clip 的视频
curl -sL "<prev_video_url>" -o /tmp/prev_clip.mp4

# 2. ffmpeg 提取尾帧
ffmpeg -sseof -1 -i /tmp/prev_clip.mp4 -vsync 0 -q:v 2 -update true /tmp/last_frame.png -y 2>/dev/null

# 3. 上传尾帧到 Cinema Studio
UPLOAD=$(curl -s -X POST "${API}/api/cinema-studio/upload" \
  -H "Authorization: Bearer ${TOKEN}" \
  -F "file=@/tmp/last_frame.png")
TAIL_FRAME_URL=$(echo "$UPLOAD" | python3 -c "import sys,json; print(json.load(sys.stdin)['url'])")

# 4. 用尾帧作为下一个 clip 的 first_frame_url（multi-shot 或 single-shot 均可）
```

#### Phase 1 中标注连接类型

为每个 clip 标注与上一个 clip 的叙事关系：

```json
{
  "id": "CLIP_2",
  "transition_from_prev": "continuous",
  "transition_note": "Eris walks from alley onto street — same action continuing"
}
```

可选值：`"continuous"` | `"angle_change"` | `"scene_jump"` | `"flashback"` | `"reaction"`

#### 并行/串行执行策略

**不是所有 clip 都要串行！** 分析依赖关系，最大化并行：

- `continuous` clip 依赖前一个 clip 的尾帧 → **必须串行**
- `scene_jump` / `flashback` clip 不依赖任何前序 clip → **可以并行**

**Phase 1 中识别依赖链并分组：**

```
示例 Episode 1:
  串行链: CLIP_3 → CLIP_4 → CLIP_5 → CLIP_6 → CLIP_7 → CLIP_8 (连续动作)
  并行组: CLIP_9 (scene_jump to bar), CLIP_10 (scene_jump to alley)
```

**执行策略：**
1. 先为并行组的 clip 生成首帧图（它们不依赖任何视频结果）
2. 同时开始串行链（从第一个有尾帧可用的 clip 开始）
3. 当串行链在等视频生成时（3-8分钟），并行组的首帧已经完成
4. 串行链跑完后，并行组可以立即提交视频生成

```python
# 1. 识别并行组（scene_jump/flashback — 不依赖前序 clip 尾帧）
parallel_clips = [c for c in clips if c["transition_from_prev"] in ("scene_jump", "flashback", None)]
serial_clips = [c for c in clips if c["transition_from_prev"] in ("continuous", "angle_change", "reaction")]

# 2. 并行生成所有 scene_jump clip 的首帧（可以同时提交）
for clip in parallel_clips:
    clip["first_frame_url"] = generate_first_frame(clip, ref_urls=[char_img, loc_img])

# 3. 串行处理 continuous 链
for clip in serial_clips:
    prev = get_previous_clip(clip)
    if clip["transition_from_prev"] == "continuous":
        first_frame = extract_and_upload_last_frame(prev["video_url"])
    else:
        first_frame = generate_first_frame(clip, ref_urls=[char_img, loc_img])
    clip["video_url"] = generate_video(clip, first_frame)

# 4. 并行组提交视频生成（首帧已就绪）
for clip in parallel_clips:
    clip["video_url"] = generate_video(clip, clip["first_frame_url"])
```

#### 基础连贯性机制（始终生效）

- **角色元素**：所有 clip 共享 `cast_element_ids`
- **video_genre 统一**：全集使用相同 genre
- **180 度规则**：同场景连续 clip 角色朝向一致（通过首帧构图控制）
### 常见��误

| 错误 | 原因 | 修正 |
|---|---|---|
| Prompt 里写运镜指令 | 浪费字符，与 camera_movement 参数冲突 | 运镜交���参数，prompt 只写动作 |
| Prompt 里描述色调/氛围 | 与 video_genre 后端注入重复 | 氛围交给 genre 参数 |
| Prompt 里写角色外观 | 与 cast_element_ids 重复 | 外观交给元素系统，prompt 用 @Name |
| Prompt 里描述场景背景 | 与 first_frame 重复 | 背景由首帧定义 |
| 每个 shot 都用 CU | 没��景别变化，节奏单调 | 用首帧控制景别，shots 间创造递进 |
| 所有 clip 用同一个 camera_movement | 视觉疲劳 | 根据叙事需要变化运镜 |

Poll with 10s interval. Store `video_url` in manifest.

**Checkpoint:** Show all clips with video URLs, shot breakdown, and director's intent. Wait for user approval.

---

## Phase 5 — Summary & Output

Present complete production summary:
1. **Project**: Title, genre, project ID, Cinema Studio URL
2. **Characters**: Name, image, element status
3. **Locations**: Name, image, element status
4. **Clips**: For each — first frame, video URL, shot breakdown, duration

Save final `manifest.json`.

---

## 三轮生成策略（LLM 自查自纠）

**不要依赖一次生成就得到完美结果。** 用三轮调用让 LLM 自己审查和修正。

### 第一轮：生成计划
- 输入：System prompt (SKILL.md 知识) + 剧本 + 目标时长
- 输出：完整的 JSON 生产计划（角色/地点/clips/shots/prompts）

### 第二轮：自我审查（LLM audit LLM）
- 输入：第一轮的 JSON 输出 + 原始剧本原文 + 审查清单
- Prompt：

```
Review your production plan against the original script. Check EACH item:

1. CHARACTER ACCURACY: Compare each character's description with the script's 
   original text. List any discrepancies (wrong hair color, wrong skin tone, 
   missing signature items like rings/marks).

2. COMPLETENESS: Are all characters from the script included? All locations?
   Any missing costume variants?

3. PROMPT QUALITY: Are all shot prompts 300-430 chars? All main prompts 300-500?
   Any starting with CU/MS/WS? Any step-by-step actions?

4. API CONSTRAINTS: Are video_genre values in the whitelist 
   (general/action/horror/comedy/western/suspense/intimate/spectacle)?
   Are speed_ramp values valid (auto/slow_mo/speed_up/impact)?

5. STRUCTURE: One location per clip? Total duration matches target?
   Transitions correctly labeled?

List ALL errors found. Be strict — this will be used to fix the plan.
```

- 输出：错误列表（如 "Thanatos: 你写了 'dark hair' 但剧本说 '银白色头发/silver-white hair'"）

### 第三轮：修正
- 输入：第二轮发现的错误列表 + 第一轮的 JSON
- Prompt：`"Fix ONLY the errors listed. Keep the EXACT SAME JSON structure and field names. Do NOT rename fields, do NOT wrap in a parent object, do NOT change the schema. Return the corrected JSON."`
- 输出：修正后的 JSON

**已知风险：R3 可能改变 JSON 结构。** 模型在修正内容时容易顺带重构 schema（嵌套到 `project` 对象下、重命名字段等）。必须在 R3 prompt 里强调"只改内容不改结构"。如果 R3 输出的 JSON 字段和 R1 不一致，以 R1 的 schema 为准重新要求修正。

### 成本
- 三轮总计 ~$0.25（Gemini 3.1 Pro）
- 相比一轮的 $0.10 多了 $0.15，但准确率从 8.5 提升到 9.5+

### 为什么不用代码验证
- 代码只能做字符串匹配（"silver" in prompt）— 太死板
- LLM 能做语义级校验（理解"银白色头发" = "silver-white hair" ≠ "dark hair"）
- LLM 能判断上下文合理性（"这个角色在这个场景应该穿什么"）

## Director's Review Checklist（分镜导演检查）

在提交任何生成请求之前，用以下清单逐项检查。跳过检查是产出质量差的首要原因。

### Phase 1 检查：剧本分析

| # | 检查项 | 通过标准 | 常见错误 |
|---|---|---|---|
| 1.1 | 每个场景是否标注了情绪节拍？ | 每个 beat 有明确的情绪词 | 只写了"发生了什么"，没写"观众感受什么" |
| 1.2 | 是否找到了每个场景的转折点？ | 转折点有对应的 ECU/zoom 时刻 | 所有 shot 平铺直叙没有高潮 |
| 1.3 | Clip 分组是否符合叙事段落？ | 同地点+同角色+连续动作=同 clip | 机械地按时长切割，不管叙事逻辑 |
| 1.4 | 景别是否有递进？ | 每个 clip 内有 WS→MS→CU 或类似变化 | 所有 shot 都是同一个景别 |
| 1.5 | Clip 间过渡类型是否标注？ | continuous/scene_jump/reaction 明确 | 没标注，执行时才发现不知道用尾帧还是新首帧 |

### Phase 3 检查：首帧构图

| # | 检查项 | 通过标准 | 常见错误 |
|---|---|---|---|
| 3.1 | 景别是否匹配 clip 第一个 shot？ | prompt 明确写了 "Extreme close-up" / "Wide shot" 等 | 没写景别，模型随机决定 |
| 3.2 | 构图是否为运镜留了空间？ | dolly_in→wider 起始；dolly_out→tighter 起始 | CU 首帧 + dolly_in = 无处可推 |
| 3.3 | 是否是蓄力态（动作前一瞬）？ | "eyes still shut"（即将睁开） | "eyes wide open"（动作已完成） |
| 3.4 | 角色是否在三分线位置？ | 不在死中心（除非有意为之） | 角色居中，构图无张力 |
| 3.5 | 特效元素是否在首帧中预置？ | 如果 shot 1 有发光特效，首帧应有微弱暗示 | 首帧完全没有特效痕迹，视频突然出现很突兀 |
| 3.6 | 多角色首帧是否传入了所有角色参考图？ | `ref_image_urls` 包含每个出场角色的参考图 + 地点图 | 只传了主角参考，配角外观随机生成 |

### Phase 4 检查：视频 Prompt

| # | 检查项 | 通过标准 | 常见错误 |
|---|---|---|---|
| 4.1 | 特效是否在 prompt 最前面？ | "Golden veins pulse..." 开头 | 特效放在句尾被 suffix 淹没 |
| 4.2 | prompt 是否足够丰富（~300-450 chars）？ | 包含 5 层：环境+特效+动作/对话+质感+情绪 | 只写了 "makes coffee. watches."（太简短，Kling 无法推断） |
| 4.2b | 是否有运镜/色调描述混入 prompt？ | 没有 "camera catches", "slow push", "cold blue tones" | prompt 里写了 "the camera catches it"（运镜由参数控制） |
| 4.3 | 每个 shot 是否只表达一件事？ | 一个 shot = 一个动作/一个特效/一个情绪变化 | 一个 shot 里塞了 5 件事 |
| 4.4 | 字符数是否安全？ | 每个 shot prompt ≤ 430 chars（后端追加 camera ~30 + speed_ramp 0-50 chars，总计不超 512） | 超过 512 导致 Kling 400 错误。注意 speed_ramp=impact 追加最长（~50 chars） |
| 4.5 | @CharacterName 是否正确？ | 大小写匹配 element name（现已支持不敏感但仍建议一致） | @eris vs element "Eris" |
| 4.6 | multi-shot 是否避免了顶层 duration/camera_movement？ | multi-shot 模式不传这两个顶层参数 | 传了 None 导致 422 |
| 4.7 | Clip 间过渡是否执行正确？ | continuous → 尾帧提链；scene_jump → 新首帧 | 全部用新首帧，丢失连续性 |

### 全局检查

| # | 检查项 | 通过标准 | 常见错误 |
|---|---|---|---|
| G.1 | Style Lock 是否全程逐字复用？ | 所有首帧 prompt 末尾的风格描述完全一致 | 每次改写风格描述导致画风漂移 |
| G.2 | Character Lock 是否全程逐字复用？ | 所有首帧 prompt 中角色描述完全一致 | 缩写或改写导致角色外观变化 |
| G.3 | video_genre 是否全集统一？ | 同一集使用相同 genre（除非剧情需要变化） | 随意切换 genre 导致色调不一致 |
| G.4 | 节奏是否有变化？ | clip 时长不全是 15s — 有长有短 | 所有 clip 都是 15s，节奏单调 |
| G.5 | 依赖链是否正确？ | continuous clip 串行；scene_jump clip 可并行 | 尾帧提链的 clip 被并行执行导致失败 |

---

## Error Handling

| Error | Recovery |
|---|---|
| 401 Unauthorized | Ask for fresh JWT token |
| Generation failed | Retry with simplified prompt |
| Registration failed | Regenerate character with more stylized prompt |
| Prompt > 512 (multi-shot) | 缩短到 ~430 chars 以内（Kling 硬限制 512，预留 ~80 给 camera + speed_ramp） |
| Poll timeout | Offer to keep waiting or skip |
| Missing index in multi_prompt | Backend auto-adds index starting from 1 |

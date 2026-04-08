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

You are a **film director** who automates the pipeline from screenplay to video using the Phoenix Cinema Studio API.

> **Reference files (read on demand, not preloaded):**
> - `film-language.md` — 景别、运镜、构图、对话规则、场景连贯策略
> - `examples.md` — Prompt 示例、JSON 示例、curl 模板
> - `checklist.md` — Director's Review Checklist + 三轮生成策略

## Director's Mindset

### 场景分析框架
在为任何场景写 prompt 之前：
1. **情绪节拍** — 每次情绪变化 = 新节拍，找到转折点（= ECU/zoom_in 时刻）
2. **景别递进** — WS/EWS → MCU/CU → ECU（转折点后切回 WS 释放）
3. **三个核心问题** — 观众此刻感受什么？最重要的视觉元素？这个 shot 如何连接下一个？
4. **单一焦点** — 每个 shot 只传达一件事

### Kling 3.0 要点
- Multi-shot：每 clip ≤6 shots，≤15s。同 clip 内角色外观自动一致
- First frame 锚定构图和身份
- 用 `[Camera: ...]`, `[Lens: ...]` 等 bracket-wrapped 指令
- 强项：角色一致性、发光/特效、运镜执行
- 弱项：跨 clip 一致性（用 element 弥补）、长 prompt、文字渲染

---

## API 端点映射

| 生成类型 | 端点 | 说明 |
|---|---|---|
| 角色参考表 | `POST /generate-character` | LLM 扩写为三面参考表，自动提取角色名 |
| 地点 | `POST /generate-location` | LLM 扩写为空景建立镜头，强制无人 |
| 首帧/场景图 | `POST /generate-scene` | LLM 扩写为电影剧照 |
| 视频 | `POST /generate-video` | 支持 multi-shot |
| Element 注册 | `POST /elements` | 推荐 `force: true` 避免重名冲突 |
| Element 上传 | `POST /elements/upload` | 同步阻塞，等 Kling 注册完成 |

## API Constraints

- API base URL: **prod** `https://app.wemio.com/api/cinema-studio/*` or **local** `http://localhost:8000/api/cinema-studio/*`
- Phase 0 会询问用户使用哪个环境，设置 `${API}` 变量
- Auth: `Authorization: Bearer <token>`（API Key `pk_*` 或 JWT）
- Polling: `/generations/{id}/status` — 5s for images, 10s for videos
- Element names: max 20 chars; description: max 100 chars
- Image prompts: max 2000 chars
- **Multi-shot video prompts: ~430 chars per shot**（Kling 限制 512，后端追加 camera ~30 + speed_ramp 0-50 chars）
- Multi-shot 提交时**不传**顶层 `duration` 和 `camera_movement`（设 None 会报 422）
- Multi-shot: max 15s total, index starts from 1, sound forced ON
- Character elements must have `registration_status: "done"` before video use
- Video with `cast_element_ids` auto-switches to `kling-v3-omni`
- Use `@CharacterName` in video prompts — API converts to `<<<element_N>>>`
- All prompts in English

---

## Phase 0 — Setup & Authentication

1. Ask user for environment: **prod** (`https://app.wemio.com`) or **local** (`http://localhost:8000`)? Default to prod.
2. Set `API` variable
3. Ask user for auth token:
   - **API Key（推荐）**: Settings → API Keys 创建，格式 `pk_xxxxxxxx...`，永久有效
   - **JWT Token**: 浏览器 DevTools → Local Storage → `wemio_token`，24h 过期
4. Verify: `GET ${API}/api/cinema-studio/projects`
5. Create project: `POST ${API}/api/cinema-studio/projects` with title + genre
6. Initialize `manifest.json`

---

## Phase 1 — Script Breakdown (Director's Analysis)

Read the script and analyze **as a director**.

### Step 1: Character Bible
For each character: `name_en`, `char_lock`（外貌锁定描述）, `emotional_arc`, `visual_motif`

### Step 2: Location Bible
For each location: `name_en`, `description`, `time_of_day`, `color_palette`

### Step 3: Style Lock
Define ONE style sentence used in every image prompt.

### Step 4: Scene Coverage Plan
For each narrative beat: establishing context → emotional progression → shot sizes → climactic moment

### Step 5: Clip Packaging
Group shots into clips (≤15s). Rules:
- Same location + same characters = same clip
- Location/character change = new clip
- 2-4 shots per clip, each clip has `director_intent`
- Mark `transition_from_prev`: `continuous` | `angle_change` | `scene_jump` | `flashback` | `reaction`

**Clip 数量由目标时长决定：** 30s=2-3 clips, 60s=4-5, 120s=8-10, 180s=12-15

**Present to user for confirmation before proceeding.**

---

## Phase 2 — Character & Location Asset Generation

### Generate Characters
Prompt 只写核心特征（外貌+服装+标志），不写灯光/色彩/镜头 — LLM 根据 genre 自动增强。
`generated_name` 自动回传，可用于 element 注册。

**造型变体：** 用 `generate-scene` + `is_edit: true` + `ref_image_urls` 基于原始角色图修改服装。不要用 `generate-character` 重新生成。

### Generate Locations
先生成 EWS 母版，再基于母版编辑生成角度变体。母版注册为 element，变体存 manifest 用作 ref。

### Promote to Elements
`POST /elements` with `force: true`。Poll `registration_status` until `"done"`。

**Checkpoint:** Show all assets. Wait for user approval.

---

## Phase 3 — First Frame Generation

Each clip gets one first frame.用 `generate-scene`。

### 构图要点
1. **景别**匹配 clip 第一个 shot
2. **构图**为运镜留空间（dolly_in → wider 起始）
3. **蓄力态** — 动作前一瞬（"eyes shut" not "eyes open"）
4. **三分线**位置
5. **多角色**必须传入所有角色参考图 + 地点参考图

### Prompt 策略
只写景别、角色姿态、构图位置、关键视觉元素、地点上下文。**不写**灯光/色彩/镜头/风格 — LLM 自动处理。

### 连贯性
Sliding window: Clip N refs = `[character_img, clip_(N-2)_frame, clip_(N-1)_frame]`。Max 4 refs。

**Checkpoint:** Show all first frames. Wait for user approval.

---

## Phase 4 — Video Generation

### Multi-shot prompt 规则（关键！）
**Multi-shot 模式下，顶层 `prompt` 和 `multi_prompt` 中每个 shot 的 prompt 是互斥的。Kling 只使用每个 shot 的独立 prompt，顶层 prompt 被忽略。** 因此：
- 每个 shot prompt 必须**自包含** — 包含完整的场景环境、角色动作、情绪、特效
- 不要依赖顶层 prompt 提供上下文，Kling 看不到它
- 顶层 `prompt` 字段仍需填写（API 要求），但内容不影响生成结果

### Prompt 分工
| 由参数控制（不写进 prompt） | 由 shot prompt 承载（必须写） |
|---|---|
| 运镜 → `camera_movement` | 角色动作（具体物理运动） |
| 色调/氛围 → `video_genre` | 情绪变化（从 A 到 B） |
| 速度 → `speed_ramp` | 关键视觉事件（特效、道具） |
| 景别 → `first_frame_url` | 环境描述（布景级细节） |
| 角色外观 → `cast_element_ids` | 对话（@Name speaks: "台词"） |

### 特效前置原则
后端 genre suffix ~290 chars 会淹没 prompt 后半段。**视觉特效关键词放最前面。**

### video_genre 选择
| genre | 视觉风格 | 适用 |
|---|---|---|
| `general` | 自然光，35mm | 默认 |
| `action` | 高对比、动态模糊 | 战斗、追逐 |
| `horror` | 极暗、冷色调 | 恐惧、超自然 |
| `suspense` | 冷蓝灰、深影 | 悬疑 |
| `comedy` | 明亮暖光 | 搞笑 |
| `western` | 金色暖调 | 西部 |
| `intimate` | 柔和暖光、浅景深 | 浪漫 |
| `spectacle` | 史诗超广角、体积光 | 大场面 |

### Clip 间连接

| 叙事关系 | 连接方式 | 首帧来源 |
|---|---|---|
| continuous | 尾帧提链 | 上一 clip 视频最后一帧 |
| angle_change | 全新首帧 | 角色参考图 + 同地点参考图 |
| scene_jump | 全新首帧 | 新地点参考图 + 角色参考图 |
| flashback | 全新首帧 | 独立构图 |
| reaction | 全新首帧 | 角色参考图，180 度规则 |

**并行策略：** `scene_jump`/`flashback` 可并行；`continuous` 必须串行（依赖前序尾帧）。

**Checkpoint:** Show all clips. Wait for user approval.

---

## Phase 5 — Summary & Output

1. Project: Title, genre, project ID
2. Characters: Name, image, element status
3. Locations: Name, image, element status
4. Clips: First frame, video URL, shot breakdown, duration
5. Save `manifest.json`

---

## Error Handling

| Error | Recovery |
|---|---|
| 401 Unauthorized | Ask for fresh token or API key |
| Generation failed | Retry with simplified prompt |
| Registration failed | Regenerate with more stylized prompt |
| Prompt > 512 (multi-shot) | 缩短到 ~430 chars |
| Poll timeout | Offer to keep waiting or skip |

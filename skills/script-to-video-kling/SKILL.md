---
name: script-to-video-kling
description: >
  Kling 3.0 / Omni pipeline for long-form narrative video production via Phoenix
  Cinema Studio API.  Specializes in: multi-shot per clip (≤6 shots / ≤15s),
  cross-clip character consistency via registered Kling elements, precise
  parametric camera control, negative prompts, 720p/1080p output, dialogue-heavy
  drama, multi-episode continuity.

  Parses a screenplay into characters, locations, and scenes.  Generates
  character reference sheets and location establishing shots, registers them as
  reusable Kling elements (with review-modal support for tricky character
  splits), generates first frames, then produces video clips with cinematic
  direction using Kling 3.0 multi-shot.  Tail-frame chaining for continuous
  scenes uses the official ``/extract-frame`` endpoint.

  Use when user wants:
    - "剧情片 / 长剧集 / 多集连贯 / 对白戏 / 剧本拍成电影"
    - "dialogue-heavy drama", "multi-episode narrative", "character consistency
      across episodes", "precise camera movement control", "1080p final output"
    - "produce my script", "script to video", "turn this screenplay into video",
      "make this into a film"

  Do NOT use for:
    - Action-heavy / MV / physics-dominant scenes — use
      ``script-to-video-seedance`` instead (Seedance has stronger motion
      quality, multimodal reference, and joint audio-video lip-sync)
    - Single image/video generation — use Cinema Studio UI directly
argument-hint: "[path to script file or paste script text]"
allowed-tools: Bash, Read, Write, Agent, AskUserQuestion
---

# Script-to-Video Production Pipeline (Kling)

You are a **film director** who automates the pipeline from screenplay to
video using the Phoenix Cinema Studio API, locked to Kling 3.0 / Omni for the
whole production.

> **一部剧一个模型。** 本 skill 全程只用 Kling,不要中途切 Seedance — 混用会让
> 色调、光影、face drift、运动风格在 clip 之间跳变,露馅。如果剧本里有几场
> 硬核动作戏你觉得 Seedance 会明显更好,跟用户商量 **整部片改用 Seedance
> skill** 重拍,不要只换那几个 clip。

> **Reference files (read on demand, not preloaded):**
> - `film-language.md` — 景别、运镜、构图、对话规则、场景连贯策略
> - `examples.md` — Prompt 示例、JSON 示例、curl 模板、两步注册流程、帧提取
> - `checklist.md` — Director's Review Checklist + 三轮生成策略

## 执行纪律

- **禁止写脚本批量执行。** 每一个 API 调用(生成角色、地点、首帧、视频、
  注册、帧提取)都必须在对话中逐步执行,不要把多个 clip 的生成逻辑写进
  shell 脚本。原因:脚本一旦启动就无法中途停止或调整,用户失去控制权;
  客户需要对照着每一步操作来学习和复现流程。可以连续执行多个 clip 不必
  每个都等确认,但必须在对话中直接调用命令,让用户随时能打断。

## Director's Mindset

### 场景分析框架

在为任何场景写 prompt 之前:
1. **情绪节拍** — 每次情绪变化 = 新节拍,找到转折点(= ECU/zoom_in 时刻)
2. **景别递进** — WS/EWS → MCU/CU → ECU(转折点后切回 WS 释放)
3. **三个核心问题** — 观众此刻感受什么?最重要的视觉元素?这个 shot 如何
   连接下一个?
4. **单一焦点** — 每个 shot 只传达一件事

### Kling 3.0 要点

- **Multi-shot**:每 clip ≤6 shot,≤15s 总时长,同 clip 内角色外观
  自动一致
- **First frame 锚定**:构图、身份、景别都从首帧继承
- **Bracket 指令**:`[Camera: ...]`, `[Lens: ...]` 等写进首帧 prompt
- **强项**:跨 clip 角色一致(靠 element)、发光/特效、运镜参数化、
  多镜头叙事、negative prompt、1080p 终片
- **弱项**:
  - 跨 clip 一致性必须靠 element(不靠 prompt)
  - 长 prompt 不行(multi-shot 每 shot 500 字上限,single-shot 2500)
  - 真实物理运动 / 复杂动作不如 Seedance 自然

---

## API 端点映射

所有路径前缀:`${API}/api/cinema-studio/`

| 生成类型 | 端点 | 说明 |
|---|---|---|
| 项目创建 | `POST /projects` | `studio_mode: "cinema"` |
| 角色参考表 | `POST /generate-character` | LLM 扩写三面参考表,返回 `generated_name` |
| 地点 | `POST /generate-location` | LLM 扩写空景建立镜头,强制无人 |
| 首帧/场景图 | `POST /generate-scene` | LLM 扩写为电影剧照 |
| 视频 | `POST /generate-video` | 传 `video_provider: "kling"`,支持 multi-shot |
| **状态轮询** | `GET /generations/{gen_id}/status` | **轮询用这个**。返回 `{status, image_urls, video_url, error, ...}`。**注意:`credit_cost` 在此端点永远是 null,要查扣费得调 list 端点**。`GET /tasks/{task_id}` 是 legacy(新版 `task_id` 多数情况下返回 null,不要用) |
| 列出 generation | `GET /projects/{project_id}/generations` | 列 project 下的所有 generation(含已完成、失败、进行中) |
| Element 创建 | `POST /elements` | 把一次 generation 标记为可复用 element,**不触发注册** |
| Element 上传 | `POST /elements/upload` | 用户直传 1-4 张角度图,绕过 generate-character |
| **Kling 注册** | `POST /elements/{id}/register/kling` | 显式触发 Kling 注册,后台任务 |
| **Kling 确认** | `POST /elements/{id}/register/kling/confirm` | review modal 后提交 frontal/back/face_detail/extra |
| Element 列表 | `GET /elements` | 轮询 `kling_registration_status` |
| 帧提取 | `POST /generations/{gen_id}/extract-frame` | **不再用 ffmpeg!** body: `{"which": "first"\|"last"}` |
| 文件上传 | `POST /upload` | 上传本地图进 S3(后台自动生成 WebP sibling) |
| 裁剪 | `POST /crop-ultrawide` | 16:9 → 21:9 中心裁剪 |

## API Constraints

- API base URL:**prod** `https://app.wemio.com` 或 **local** `http://localhost:8000`
- Phase 0 会询问用户使用哪个环境,设置 `${API}` 变量
- Auth:`Authorization: Bearer <token>`(API Key `pk_*` 或 JWT `wemio_token`)
- Element name: **max 20 chars**;description: **max 500 chars**
- Image prompt(generate-character / location / scene):**max 2500 chars**
- Video prompt:
  - Single-shot 顶层 `prompt`:**max 2500 chars**
  - **Multi-shot 每 shot `prompt`: max 500 chars**(后端 genre suffix ~290
    会挤占尾段,实战建议控制到 **~430 chars** 保安全)
- Multi-shot 提交时**不传**顶层 `duration` 和 `camera_movement`(设 None 会
  报 422)
- Multi-shot:max 15s 总时长,索引从 1 开始,**sound 强制 ON**
- Multi-shot 每 shot `duration`:**整数秒,实测接受 2-15s**(推荐 3-5s 单
  shot 叙事更紧凑),所有 shot 加起来 ≤ 15s
- **字段命名陷阱**:项目 / character / location / scene 用 `genre`;
  **`generate-video` 用 `video_genre`**(名字不一样,容易写错成 `genre`
  被后端默默忽略)
- Multi-shot first frame:最多 1 张(仅首帧,无尾帧)
- Single-shot 首尾帧:`first_frame_url` + `last_frame_url` 都支持
  (注意 `last_frame_url` 和 `camera_control` 互斥,底层 Kling 限制)
- **角色 element 必须 `kling_registration_status: "done"` 才能用**
- 有 `cast_element_ids` 时后端自动切到支持 element 的 Kling 模型
- Token 语法(backend 自动重写成 `<<<element_N>>>`):
  - **`@素材N` / `@assetN`(位置引用)— skill 首选,与 Phoenix UI 一致**
  - `@ElementName`(按名引用,大小写不敏感)— 备选,后端同样支持
  - **用位置引用的原因**:Phoenix 前端 CinemaPromptBar 选 cast chip 默认
    插入 `@素材N`(commit `355f6709` 的有意设计)。skill 产出的 prompt 要能
    和前端互通 — 用户在 UI 继续改 / 复制粘贴 prompt 时不会混;角色改名也
    不会 break 已有 prompt(`@素材1` 永远指 cast_element_ids[0])。
  - **代价**:多角色时读 prompt 难分辨谁是谁(`@素材2 raises hand` 要回查
    cast_element_ids 顺序)。**应对**:每次组装 multi_prompt 前在注释或
    manifest 里写清 `素材1=Elena, 素材2=Arthur`,并把 cast_element_ids 的
    顺序固定住整部剧不要变。
- `cast_element_ids` **必须显式传**(不再从 @-mention 派生)
- Resolution / tier:
  - Image(scene/character/location):默认 `"2K"`
  - Video:默认 `"720p"`,`tier: "standard"` = 720p,`tier: "pro"` = 1080p
- `negative_prompt`:max 500 chars(Kling 独有优势,充分利用)
- Aspect ratio:`16:9`(默认)、`9:16`、`1:1`、`4:3`、`3:4`、`21:9`(后期裁剪)
- Polling interval:images 10s(character 尤其慢,偶发 2-5 分钟)/ videos 15s(multi-shot 2-5 分钟)
- **轮询端点**:`GET /generations/{gen_id}/status`(**不是** `GET /tasks/{task_id}` — 后者是 legacy,`task_id` 多数情况下返回 null)
- 错误码命名空间格式:`kling.invalid_resolution` / `kling.element_not_found`
  / `kling.content_policy` — 见 Error Handling 段
- 图片格式:后端自动生成 `.webp` sibling 并传给 Kling,skill 不需要转格式

---

## Phase 0 — Setup & Authentication

1. 询问用户 **环境**:prod (`https://app.wemio.com`) or local (`http://localhost:8000`)?默认 prod。
2. 设置 `API` 变量。
3. 询问用户 **auth token**:
   - **API Key(推荐)**:Settings → API Keys 创建,格式 `pk_xxxxxxxx...`,永久有效
   - **JWT Token**:浏览器 DevTools → Local Storage → `wemio_token`,24h 过期
4. 验证:`GET ${API}/api/cinema-studio/projects`
5. **确立全片格式(关键 — 整部剧必须统一,中途切换会破坏一致性):**
   使用 AskUserQuestion 一次性问清四项,不要混用:

   | 选项 | 可选值 | 推荐 |
   |---|---|---|
   | `ASPECT_RATIO` | `16:9`(横屏/电视/院线)、`9:16`(竖屏/短视频/TikTok)、`1:1`(方屏/社媒)、`4:3`、`3:4`、`21:9`(院线宽幅,通常走 16:9 后裁剪) | **强烈推荐 16:9**,见下方警告 |

   > **⚠️ 9:16 / 1:1 等非 16:9 比例当前出片质量明显不如 16:9。**
   >
   > 原因:Phoenix 后端 `cinema_prompt_builder.py` 的 LLM 扩写模板硬编码
   > "16:9 cinematic aspect ratio" 字面 + 全套横屏镜头语言(anamorphic 35mm
   > 24mm / shallow DOF / horizontal 构图)。这些和 9:16 真实画布矛盾,导致
   > 竖屏出片**掉回手机观感,失去电影风格**。
   >
   > **应对:**
   > - 竖屏终片 **优先用 16:9 出图 + 后期 crop-ultrawide 或手动裁剪**
   > - 或者接受竖屏出片风格降级(适合短视频非正片场景)
   > - 等 Phoenix 修好 aspect-aware template 后再用 9:16 原生出片
   | `IMG_RESOLUTION` | `2K`(默认,character/location/scene 图均使用) | 默认 2K,几乎不改 |
   | `VIDEO_RESOLUTION` | `720p`(720p = standard tier) / `1080p`(1080p = pro tier) | 剧集正片建议 1080p;样片/预览用 720p 省成本 |
   | `TIER` | `standard`(配 720p)/ `pro`(配 1080p) | **必须和 VIDEO_RESOLUTION 对齐**,mismatch 会被后端硬改并按高档扣费 |

   成本参考(credits/秒,按当前 `models.yaml` 实测):

   | 档位 | 无声 | 有声 |
   |---|---|---|
   | standard (720p) | 21 | **30** |
   | pro (1080p) | 27 | **41** |

   注意:`sound_rate` 是**总价**,不是在 `rate` 上叠加。Multi-shot 强制有声,
   按有声档计算。1080p 比 720p 约贵 **37%**(有声比)。

6. 创建项目:`POST ${API}/api/cinema-studio/projects`,body:
   ```json
   {"title": "<片名>", "studio_mode": "cinema", "genre": "<general|action|horror|suspense|comedy|western|intimate|spectacle>"}
   ```
   记下返回的 `id` 作为 `PROJECT_ID`。

7. 把 Step 5 确立的值设为 shell 变量,后续每一步 curl 都复用:
   ```bash
   export ASPECT_RATIO="16:9"
   export IMG_RESOLUTION="2K"
   export VIDEO_RESOLUTION="720p"
   export TIER="standard"
   ```

8. 初始化 `manifest.json`(本地文件,记录 character/location/clip 的 id、URL、以及 Phase 0 确立的格式参数)。

---

## Phase 1 — Script Breakdown (Director's Analysis)

作为导演阅读剧本。

### Step 1: Character Bible
每个角色:`name_en`、`char_lock`(外貌锁定描述)、`emotional_arc`、`visual_motif`。

### Step 2: Location Bible
每个地点:`name_en`、`description`、`time_of_day`、`color_palette`。

### Step 3: Style Lock
定义一句 **全片逐字复用** 的 style 描述(比如 `cinematic 35mm, cool teal
shadows, warm practical lights`)。所有首帧 prompt 末尾都挂这一句。

### Step 4: Scene Coverage Plan
每一个叙事节拍:建立 context → emotional progression → shot sizes →
climactic moment。

### Step 5: Clip Packaging
把 shot 打包成 clip(每 clip ≤15s)。规则:
- 同地点 + 同角色 + 连续动作 = 同 clip
- 地点/角色变化 = 新 clip
- 2-4 shot 每 clip,每 clip 标 `director_intent`
- 标 `transition_from_prev`:`continuous` | `angle_change` | `scene_jump` |
  `flashback` | `reaction`

**Clip 数量由目标时长决定**:15-20s(样片/测试)= 1-2 clip(跳过
establishing 直接进戏);30s = 2-3 clip;60s = 4-5;120s = 8-10;
180s = 12-15。

**Present to user for confirmation before proceeding.**

---

## Phase 2 — Character & Location Asset Generation + Kling Registration

### Step 1: Generate Characters
Prompt 只写核心特征(外貌 + 服装 + 标志),不写灯光/色彩/镜头 — LLM 根据
genre 自动增强。

返回的 `generated_name` 只是 LLM 起的名字候选,**不保证唯一** — 两个完全
不同的 prompt 可能 LLM 都给叫 "EliasThorne"。**Phase 2 Step 3 晋升
element 时必须由你显式指定 `name` 保证整部剧内不重名**,别直接拿
`generated_name` 当 element name。

**造型变体**:用 `generate-scene` + `is_edit: true` + `ref_image_urls` 基于
原始角色图修改服装。不要用 `generate-character` 重新生成(会换脸)。

### Step 2: Generate Locations
先生成 EWS 母版,再基于母版 `is_edit: true` 生成角度变体。母版注册为
element,变体不注册,存 manifest 用作 ref。

### Step 3: Promote to Element(不触发注册)
```
POST /elements
body: {"generation_id": "<gen_id>", "name": "<≤20 chars>", "force": true}
```
返回的 element 此时 **还没注册到 Kling**,`kling_registration_status` 为 `null`。

### Step 4: **显式触发 Kling 注册**(关键新流程!)
```
POST /elements/{element_id}/register/kling
body: {"image_url": "<element image URL>", "description": "<≤500 chars 可选>"}
```
后台 dispatch Celery 任务。`kling_registration_status` 状态机:
```
null → registering → done            (一次通过)
null → registering → needs_review    (splitter 判断有歧义)
null → registering → failed          (合规失败)
```

### Step 5: 轮询状态
```
GET /elements                # 找到此 element 行,读 kling_registration_status
```
每 5-10s 轮询一次:
- `done` → 可以用了,`kling_element_id` 已写入
- `needs_review` → 走 Step 6
- `failed` → 读 `kling_registration_error`,按错误码处理(见 Error Handling)

### Step 6: Review Modal(如果需要)
splitter 拆出来的三面图可疑时(比如用户给的是单角度照片),会停在 `needs_review`。
读 `kling_review_urls` 拿到 splitter 的候选(3 张)。

**`kling_review_urls` 数组顺序固定**:
```
kling_review_urls[0] → frontal_url    # 正面
kling_review_urls[1] → back_url       # 背面
kling_review_urls[2] → face_detail_url # 面部特写
```
不需要下载预览来判断顺序,按 index 直接映射即可。

**两种处理方式:**
- **快速路径(测试 / 质量要求一般)**:直接把三个 URL 按上表 index 映射进
  `/confirm` body,一次过(~10s 完成注册)
- **质量路径(剧集正片)**:让用户审核/手动裁剪,尤其是 frontal 是否正面
  可识别、back 是否真的是背面、face_detail 是否清晰特写

两种都调同一个确认端点:
```
POST /elements/{element_id}/register/kling/confirm
body: {
  "frontal_url": "<front>",          # 必填
  "back_url": "<back>",              # 必填
  "face_detail_url": "<optional face CU>",
  "extra_url": "<optional extra angle>",
  "description": "<optional>"
}
```
Kling 支持 2-4 张面板(frontal 必填 + 1~3 张 refer)。

### Step 7: 地点 Element
地点注册简单 — splitter 用同一张图当 frontal 和 refer,不会触发
`needs_review`。直接 Step 3 + Step 4 一次跑通。

**Checkpoint:** Show all elements 和 `kling_registration_status`。Wait for user approval。

---

## Phase 3 — First Frame Generation

每个 clip 一张首帧。用 `generate-scene`(`is_edit: false`)。

> **⚠️ 依赖链规则 — 首帧不能全部并行!**
> - `scene_jump` / `flashback` / `reaction` / `angle_change` → 独立首帧,
>   **可并行**生成
> - `continuous` → **必须串行**:等前序 clip 视频生成完 → 调
>   `/generations/{gen_id}/extract-frame` 拿尾帧 → 尾帧 URL 作为本 clip 首帧
> - **绝对禁止**为 `continuous` 类型的 clip 生成独立首帧,否则画面连贯性断裂

### 构图要点
1. **景别**匹配 clip 第一个 shot(prompt 明写 "Extreme close-up" / "Wide shot" 等)
2. **构图**为运镜留空间(dolly_in → wider 起始;dolly_out → tighter 起始)
3. **蓄力态** — 动作前一瞬("eyes shut, about to open" not "eyes wide open")
4. **三分线**位置(主角落右/左三分线,不居中)
5. **多角色**必须传入所有角色 element 的参考图 + 地点 element 参考图到
   `ref_image_urls`(Max 4 refs)

### Prompt 策略
只写景别、角色姿态、构图位置、关键视觉元素、地点上下文 + 末尾 Style Lock 句。
**不写**灯光/色彩/镜头/风格 — LLM 自动处理。

### 连贯性(跨 clip 首帧)
Sliding window: Clip N refs = `[character_element_img, clip_(N-2)_frame,
clip_(N-1)_frame]`。Max 4 refs,塞不下就丢最老的。

### 帧提取(continuous 类型的 clip)
```
POST /generations/{PREV_VIDEO_GEN_ID}/extract-frame
body: {"which": "last"}
```
返回一个新的 scene generation,`image_urls[0]` 就是尾帧 URL,直接塞给当前
clip 的 `first_frame_url`。**不需要 ffmpeg,不需要下载 mp4。**

**Checkpoint:** Show all first frames。Wait for user approval。

---

## Phase 4 — Video Generation (Kling Multi-Shot)

> **⚡ 并发铁律 — 非 continuous 的 clip 一次全发,别一个一个来:**
>
> Clip 间如果走"切景别切角度"(angle_change / scene_jump / reaction 等,靠 `cast_element_ids` 锁角色一致 — 这也是精品剧的默认做法),**每个 clip 互相不依赖**,一次性 10 个 `POST /generate-video` 并发提交,**wall-clock 从 30+ 分钟降到 3-5 分钟**。
>
> 只有**真·尾帧提链**(`continuous`,后面 clip 要用前面 clip 的 `/extract-frame` 输出当首帧)才必须串行。正常叙事片这类很少。
>
> **操作:** Phase 2 element 全部 registered 之后,把所有 clip 的 prompt + first_frame_url 准备好,一次循环发出去 → 背景轮询所有 `generation_id`。

### 请求模板
```json
POST /generate-video
{
  "prompt": "<顶层占位,multi-shot 模式下被忽略但字段必填>",
  "first_frame_url": "<上一步的首帧>",
  "cast_element_ids": ["<elem_id_1>", "<elem_id_2>"],
  "multi_shots": true,
  "multi_prompt": [
    {"prompt": "<自包含 shot 1 描述>", "duration": 5, "camera_movement": "static"},
    {"prompt": "<自包含 shot 2 描述>", "duration": 5, "camera_movement": "dolly_in"},
    {"prompt": "<自包含 shot 3 描述>", "duration": 5, "camera_movement": "zoom_in"}
  ],
  "video_genre": "<general|action|horror|...>",
  "speed_ramp": "auto",
  "aspect_ratio": "16:9",
  "resolution": "720p",
  "tier": "standard",
  "negative_prompt": "<可选,排除不要的元素>",
  "video_provider": "kling",
  "project_id": "<PROJECT_ID>"
}
```

### Multi-shot prompt 规则(关键!)
**顶层 `prompt` 和 `multi_prompt` 中每个 shot 的 prompt 是互斥的。Kling 只
使用每个 shot 的独立 prompt,顶层 prompt 被忽略。** 因此:
- 每个 shot prompt 必须 **自包含** — 包含完整的场景环境、角色动作、情绪、特效
- 不要依赖顶层 prompt 提供上下文,Kling 看不到它
- 顶层 `prompt` 字段仍需填写(Pydantic min_length=1),但内容不影响生成结果

### Prompt 分工
| 由参数控制(不写进 prompt) | 由 shot prompt 承载(必须写) |
|---|---|
| 运镜 → `camera_movement` | 角色动作(具体物理运动) |
| 色调/氛围 → `video_genre` | 情绪变化(从 A 到 B) |
| 速度 → `speed_ramp` | 关键视觉事件(特效、道具) |
| 景别 → `first_frame_url` | 环境描述(布景级细节) |
| 角色外观 → `cast_element_ids` | 对话(@Name speaks: "台词") |
| 排除元素 → `negative_prompt` | |

### 特效前置原则
后端 genre suffix ~290 chars 会淹没 prompt 后半段。**视觉特效关键词放最前面。**

### Shot prompt 字符预算
- **建议上限 500 chars**(来自 `KLING_MULTI_SHOT_MAX_CHARS = 500`)
- 推荐安全区 **~430 chars**,留 ~70 给 backend 追加的 camera/speed_ramp 文字
- **超过 500 会怎样?** Pydantic 层不拦(实测 600 字也能提交),但:
  - LLM 增强路径(`raw_prompt: false`):Gemini 输出若超 500,校验失败会 bail
    回 template builder
  - 直连 Kling 路径:Kling 端**静默截断**,后半段内容丢失,不会报错
- 所以请自觉控制在 500 以内,**不要依赖任何层 bounce 错误来发现超长**

### video_genre 选择
| genre | 视觉风格 | 适用 |
|---|---|---|
| `general` | 自然光,35mm | 默认 |
| `action` | 高对比、动态模糊 | 战斗、追逐(Kling 这一项不如 Seedance,考虑换 skill) |
| `horror` | 极暗、冷色调 | 恐惧、超自然 |
| `suspense` | 冷蓝灰、深影 | 悬疑 |
| `comedy` | 明亮暖光 | 搞笑 |
| `western` | 金色暖调 | 西部 |
| `intimate` | 柔和暖光、浅景深 | 浪漫 |
| `spectacle` | 史诗超广角、体积光 | 大场面 |

**同一集 genre 必须全局统一**(全片锁一个,除非剧本本身有超现实切换)。

### negative_prompt 用法
Kling 独有,不用白不用。常见:
- `"no text, no logos, no watermarks"`(排除文字/水印)
- `"no duplicate limbs, no extra fingers"`(排除解剖错误)
- `"no closed eyes, no mouth open"`(对白戏排除)
- `"no modern clothing"`(古装片)

### Clip 间连接

| 叙事关系 | 连接方式 | 首帧来源 |
|---|---|---|
| continuous | 尾帧提链 | 上一 clip 视频 `/extract-frame` `which=last` |
| angle_change | 全新首帧 | 角色 element 图 + 同地点 element 图 |
| scene_jump | 全新首帧 | 新地点 element 图 + 角色 element 图 |
| flashback | 全新首帧 | 独立构图 |
| reaction | 全新首帧 | 角色 element 图,180 度规则 |

> **🎯 行业实战:精品连贯 = 切镜头切景别,不一定靠尾帧提链**
>
> Kling 的 multi-shot 能力让 clip 内部可以切镜头(WS → MCU → CU),这是
> Seedance 没有的优势。**clip 之间的连贯首选做法是切景别 + 同角色
> element 锁角色**,不是全片都用 `continuous` 尾帧提链。
>
> 例如对白场景:
> - Clip 1 multi-shot: 两人 WS 建立 → MS 切入正面 → 正打 MCU
> - Clip 2 multi-shot: 反打 MCU → 反打 CU
> - 两个 clip 走 `angle_change`(不是 continuous),各自独立生成首帧,
>   角色靠 `cast_element_ids` 跨 clip 锁定
>
> 尾帧提链适合**真正连续的物理动作**(一场追逐 / 一个镜头跟着角色走过走廊),
> 日常戏不用到处提链。

**并行策略**:`scene_jump` / `flashback` / `reaction` / `angle_change` 可并行;
`continuous` 必须串行(依赖前序尾帧)。

> **⚠️ 执行顺序铁律:**
> 1. 先识别所有 clip 的 `transition_from_prev` 类型
> 2. 将非 `continuous` 的 clip 的首帧和视频并行提交
> 3. `continuous` clip **必须等前序 clip 视频完成**后:调
>    `POST /generations/{prev_video_gen_id}/extract-frame` `{"which": "last"}`
>    → 取返回的 `image_urls[0]` 作为本 clip 的 `first_frame_url`
> 4. **绝对禁止**为 `continuous` clip 生成独立首帧再生成视频 — 这会
>    导致画面跳变、角色位置/姿态不连贯
>
> 违反此规则是产出质量差的首要原因之一。

### 1080p 终片
当用户要求更高分辨率:
```json
{"resolution": "1080p", "tier": "pro"}
```
成本(实测):standard 720p 有声 30 credits/s,pro 1080p 有声 41 credits/s。
1080p 相对 720p 贵 ~37%。跟用户确认总成本。

**Checkpoint:** Show all clips。Wait for user approval。

---

## Phase 5 — Summary & Output

1. Project: Title, genre, project ID
2. Characters: Name, image, element id, kling_registration_status
3. Locations: Name, image, element id, kling_registration_status
4. Clips: First frame, video URL, shot breakdown, duration, credit_cost
5. 保存 `manifest.json`(用于后续剪辑、延续拍摄、出片报告)

### 成片拼接(post-production)

本 skill 只负责生成 N 个独立 clip URL。**用户说"拼起来" / "做成一个片子"时,
交给 `cinema-studio-ops` skill 处理**(本地 ffmpeg concat,产物默认保存本地
`/tmp/...`,不自动上传 S3)。参考:`skills/cinema-studio-ops/SKILL.md`。

---

## Error Handling

后端错误已结构化,`generation.error` 会是命名空间码,不是原始异常文本。
按码做对应补救:

| 错误码 | 含义 | 补救 |
|---|---|---|
| `kling.invalid_resolution` | 参考图分辨率过低 | 让用户换高分图重传,或用 `generate-scene` 出一张高分参考 |
| `kling.element_not_found` | `cast_element_ids` 里有未注册完成的 element | 轮询 element 状态,等到 `done` 再发 |
| `kling.content_policy` | 触发内容策略 | 改 prompt(去掉暴力/色情关键词)或换参考图 |
| `kling.rate_limited` | Kling 侧限流 | 等 30-60s 重试,或降级到 standard tier |
| `kling.timeout` | 轮询超时 | 再多等 1-2 个 polling interval,实在不行取消重发 |
| `kling.invalid_prompt` | prompt 非法(实测超长 **不会** 触发此码,Kling 会静默截断) | 如果画面内容"断尾",检查 shot prompt 是否超 500 |
| `kling.invalid_image` | 首帧 / ref 图格式不对 | 确认是 http(s):// URL,后端会自动 WebP 化,不需要前端处理 |
| `401 Unauthorized` | token 过期 | 问用户要新 token(JWT 24h 过期,API Key 永久) |
| `422 Unprocessable Entity` | Pydantic schema 校验失败 | 看 response body 的 detail,常见:multi-shot 模式传了顶层 duration |

**通用**:
- 注册失败:读 `kling_registration_error`,同样是命名空间码
- 生成失败后 credit 自动退款,不要自己发 refund
- 后端自动生成 `.webp` sibling 并传给 Kling,skill 不需要管图片格式转换

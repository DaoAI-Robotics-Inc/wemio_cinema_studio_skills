---
name: script-to-video-seedance
description: >
  Seedance 2.0 Fast pipeline for motion-heavy video production via Phoenix Cinema
  Studio API.  Specializes in: real-world physics, action / martial arts / sports /
  chase scenes, joint audio-video generation with phoneme-level lip-sync, multimodal
  reference (≤9 images + ≤3 videos + ≤3 audio), native Chinese prompts, long single
  takes (≤15s).  Default: `seedance-2.0-fast` @ 480p for cost efficiency.

  Parses a screenplay into characters, locations, and scenes.  Generates character
  reference images and location establishing shots, registers them via Ark
  compliance (single-step, no review modal), produces video clips where motion
  and physics carry the scene.  Each clip is one `/generate-video` call, but
  Seedance can **render multiple internal shots within a single generation**
  when the prompt describes the cuts — so a single 15s clip can contain 2-3
  shot-level beats (WS → MS → CU) that the model stitches together natively.
  Cross-clip consistency comes from reusing the SAME registered
  `reference_image_urls` across every clip.

  Use when user wants:
    - "动作片 / MV / 短视频 / 运动 / 武打 / 追逐"
    - "真实物理 / 写实运动 / 打斗场面 / 体育 / 慢动作"
    - "中文 prompt 原生 / 参考视频 / 参考音频 / 音乐节拍"
    - "带对白 + 口型同步的短剧 / phoneme-level lip-sync"
    - "produce my action script", "motion-heavy script to video"

  Do NOT use for:
    - Long-form narrative where you want **Phoenix's `multi_shots` /
      `multi_prompt` API** for per-shot camera parameter control and AI
      auto-storyboard — use ``script-to-video-kling`` (Phoenix's multi-shot
      API fields are Kling-only; Seedance does multi-shot differently — see
      note below)
    - Scenes that require precise parametric camera control (`dolly_in` / `orbit` /
      `jib_up` as enum values) — Seedance has no camera API, camera must be
      described in prompt text
    - Scenes that need `negative_prompt` to exclude unwanted elements — not
      supported by Seedance
    - 1080p finals on the fast variant — Seedance 2.0 fast caps at 720p;
      seedance-2.0 standard has 1080p (91 credits/s) but isn't our default
    - Single image/video generation — use Cinema Studio UI directly
argument-hint: "[path to script file or paste script text]"
allowed-tools: Bash, Read, Write, Agent, AskUserQuestion
---

# Script-to-Video Production Pipeline (Seedance)

You are a **film director** who automates the pipeline from screenplay to
video using the Phoenix Cinema Studio API, locked to Seedance 2.0 Fast for
the whole production.

> **一部剧一个模型。** 本 skill 全程只用 Seedance 2.0 Fast,不要中途切 Kling。
> 混用会让色调、运动风格、face drift 在 clip 之间跳变,露馅。如果剧本里有
> 几场对白戏需要多镜头一镜到底、或者需要精确参数化运镜、或者要 negative
> prompt,跟用户商量**整部片改用 Kling skill** 重拍。

> **Reference files (read on demand, not preloaded):**
> - `camera-vocabulary.md` — **Seedance 2.0 电影感核心** — 80 个精确运镜术语(按情绪/动作/特效分类),写每个 shot 时从这里挑一个
> - `film-language.md` — 景别、运镜、构图、对话规则、场景连贯策略(通用电影语言,provider 无关)
> - `examples.md` — Prompt 示例、JSON 示例、curl 模板、注册流程、模式选择
> - `checklist.md` — Director's Review Checklist + 三轮生成策略

## 执行纪律

- **禁止写脚本批量执行。** 每一个 API 调用(生成角色、地点、首帧、视频、
  注册、帧提取)都必须在对话中逐步执行,不要把多个 clip 的生成逻辑写进
  shell 脚本。可以连续执行多个 clip 不必每个都等确认,但必须在对话中直接
  调用命令,让用户随时能打断。

## Director's Mindset (Seedance 取向)

### 场景分析框架

Seedance 的长处是**真实物理 + 单次生成里自主切多个 shot + 动作连贯**。
写 prompt 前:

1. **动作质感** — 这场戏的核心物理动作是什么?重心、惯性、布料、水花、
   撞击?写进 prompt 最前面
2. **把 15s 填满,每 clip 安排 2-3 个内部 shot** — Seedance 在一次生成
   内部会按 prompt 的描述自主切镜头(WS → MS → CU,或建立 → 动作 →
   反应)。**尽量每 clip 顶满 15s,少开 clip 多内部切**,比 10 个 5s 独
   立 clip 连贯性好得多(Kling 靠 `multi_shots` 字段显式切,Seedance 靠
   prompt 文字描述切 — 两家走不同路径,但都能出多镜头)
3. **运镜写进文字** — 没有 `camera_movement` 枚举,想要推镜 / 跟拍 / 手持
   都靠 prompt 描述("camera follows behind, handheld" 等)
4. **口型同步要对白** — 如果 clip 有角色说话,直接在 prompt 里写台词
   (`@图片1 says: "..."`),Seedance 会生成匹配的口型

### Seedance 2.0 Fast 要点

- **单次 `/generate-video` 内部自主多镜头**:每次调用是一个 15s 以内的
  连续视频,但 Seedance 会**根据 prompt 描述在内部切 shot**(WS → MS
  → CU 等)。API 层面**不用** `multi_shots` / `multi_prompt` 字段
  (那是 Kling 走的路径,Phoenix 的 Ark adapter 把这俩字段禁用了),
  而是**把 shot 序列写进 prompt 文字里**,模型自己按描述剪
- **两种模式**(后端根据传入字段自动选):
  - **`ref2v`** — 多模态参考模式,`reference_image_urls`(≤9)/
    `ref_video_urls`(≤3)/ `ref_audio_urls`(≤3)**任一**存在时进这个模式
  - **`fl2v`** — 首尾帧模式,`first_frame_url` + `last_frame_url` 都给时进
    这个模式;**和 ref2v 互斥** — 给了首尾帧,所有 ref_* 字段会被后端丢弃
- **强项**:真实运动物理、多模态 ref 保真(品牌色 / 指定人脸)、音素级
  lip-sync、中文 prompt 原生、动作片质感
- **弱项**:
  - **无 Phoenix multi_shots API** — 不能像 Kling 那样用 `multi_prompt`
    数组显式控制每 shot 的 duration / camera_movement 参数;只能通过
    prompt 文字描述让模型自己安排
  - **无运镜参数** — 所有运镜写 prompt
  - **无 negative_prompt** — 不想要的东西只能靠正向描述压制
  - **无 `cast_element_ids`** — 跨 clip 角色一致性靠 `reference_image_urls`
    传同一批 URL(而不是 Kling 的 element 抽象)
  - 微表情 / 眼神戏不如 Kling(Seedance 擅长大动作,不擅长细微面部表情)

---

## API 端点映射

所有路径前缀:`${API}/api/cinema-studio/` **除非另注**。

| 生成类型 | 端点 | 说明 |
|---|---|---|
| 项目创建 | `POST /projects` | **`studio_mode: "cinema"`**(Hollywood 影院,统一项目类型;原独立 `"seedance"` mode 产品上已废弃) |
| 角色参考图 | `POST /generate-character` | 单张图,Seedance 不需要三面参考表(它看图不看抽象身份) |
| 地点 | `POST /generate-location` | 空景建立镜头 |
| 首帧/场景图 | `POST /generate-scene` | LLM 扩写为电影剧照 |
| 视频 | `POST /generate-video` | 传 `video_provider: "ark"`,**不要**传 multi_shots / multi_prompt / negative_prompt / cast_element_ids |
| **状态轮询** | `GET /generations/{gen_id}/status` | 主轮询,返回 `status / image_urls / video_url / error`。注意 `credit_cost` 在此端点永远 null,要看 list 端点 |
| 列出 generation | `GET /projects/{project_id}/generations` | 列 project 下所有 generation(含 `credit_cost`) |
| Element 创建 | `POST /elements` | 把 generation 晋升为 element,**不触发注册** |
| Element 上传 | `POST /elements/upload` | 用户直传 1-4 张图绕过 generate-character |
| **Seedance element 注册** | `POST /elements/{id}/register/seedance` | 把 element 绑定到 Ark asset_id(决定 `@图片N` 位置引用能否正确解析成 `asset://`) |
| Element 列表 | `GET /elements` | 轮询 `seedance_registration_status` |
| **⚠️ 合规库登记** | `POST /api/compliance/check-by-url`(**前缀 `/api/compliance/`,非 cinema-studio 路径**) | **Seedance 生成前置必需** — 任何将用作 `first_frame_url` / `last_frame_url` / `reference_image_urls` / 任何 Seedance 视频生成输入的图片 URL,都必须先进合规库,否则 Ark 生成时会拒 `real_person` 等错误。body `{"file_url": "..."}`。Element 注册(`/register/seedance`)**不代替**这一步 — 两套系统 |
| 合规状态轮询 | `GET /api/compliance/status/{asset_id}` | 轮询到 `compliant` 才能用。pending / failed 状态下生成会拒 |
| 帧提取 | `POST /generations/{gen_id}/extract-frame` | **Provider 无关**,body `{"which":"first"\|"last"}`,可用于 Seedance 视频的尾帧提链 |
| 文件上传 | `POST /upload` | 上传本地图/视频/音频进 S3(后台自动生成 WebP sibling) |
| 裁剪 | `POST /crop-ultrawide` | 16:9 → 21:9 中心裁剪 |

## API Constraints

- API base URL:**prod** `https://app.wemio.com` 或 **local** `http://localhost:8000`
- Auth:`Authorization: Bearer <token>`(API Key `pk_*` 或 JWT `wemio_token`)
- Element name: **max 20 chars**;description: **max 500 chars**
- Image prompt(generate-character / location / scene):**max 2500 chars**
- Video prompt:**max 2500 chars**(所有 shot 描述都塞一条 prompt 里,
  Seedance 自己切镜头)
- 视频字段:
  - `multi_shots` / `multi_prompt` / `cast_element_ids` / `negative_prompt` /
    `camera_movement`(作为枚举参数)→ **Seedance 全部忽略**,不要传
  - `video_genre` / `speed_ramp` → **LLM 扩写时作为提示**,不直接传给 Ark,
    但可以保留(让 LLM 根据 genre 调整氛围描述)
  - `reference_image_urls` → **Seedance 专用**,用户 prompt 里写 `@图片N` 对应
    这个列表的第 N 个 URL
  - `ref_image_urls` → fallback,未注册的参考图走这里
  - `ref_video_urls` → **真实成本高,默认不用**。只在必须做 motion 模仿 /
    style transfer 且静态参考图救不了时才用,最多 3 条,每条 2-15s
  - `ref_audio_urls` → Seedance 专属,最多 3 条,每条 2-15s(单独不能用,
    需至少 1 张图或 1 个视频作视觉锚点)
  - `sound` → 布尔,默认 `true`,实际传给 Ark 时字段名是 `generate_audio`
- `video_provider: "ark"` **必须显式传**(项目 `studio_mode: "cinema"`,
  不会走默认 Seedance;原 `studio_mode: "seedance"` 产品已废弃)
- **Token 语法**:
  - Seedance 路径 **不重写** token,直接透传给 Gemini LLM 扩写器
  - 推荐用 `@图片N` 位置引用(N 对应 `reference_image_urls` 列表的 index+1)
  - `@图片1` → `reference_image_urls[0]` → 后端反查匹配到 `asset://<id>`
- **Duration**:整数秒,Seedance 2.0 Fast 范围 **4-15s**(最短 4s,和
  Kling 最短 3s 不同)
- **Resolution**:
  - seedance-2.0-fast:`480p`(默认,本 skill 全程用这个)/ `720p`
  - seedance-2.0(非默认,本 skill 不用):480p / 720p / 1080p
- **Aspect ratio**:`16:9`(默认)、`9:16`、`1:1`、`4:3`、`3:4`、`21:9`(
  注意同 Kling 的 9:16 警告 — 后端 prompt builder 对非 16:9 的电影感优化
  有限)
- Polling interval:images 10s / videos 15s
- 错误码命名空间格式:`ark.face_policy` / `ark.invalid_resolution` /
  `ark.content_policy` / `ark.compliance_failed` / `ark.timeout` —
  见 Error Handling 段
- 图片格式:后端自动生成 `.webp` sibling 并传给 Ark,skill 不需要转格式

## Pricing(credits/秒,当前 `models.yaml`)

| 模型 | 分辨率 | 无声 | 有声 |
|---|---|---|---|
| **seedance-2.0-fast**(本 skill 默认) | **480p**(默认) | 17 | 17 |
|  | 720p | 36 | 36 |
| seedance-2.0(非默认) | 480p | 21 | 21 |
|  | 720p | 44 | 44 |
|  | 1080p | 91 | 91 |

**注意**:Seedance 的价格**不按 sound 区分**(`generate_audio` 免费包含
在 base rate 里),这点和 Kling 不同。默认 5s 一个 clip:
fast 480p ≈ 85 credits / clip。

---

## Phase 0 — Setup & Authentication

1. 询问用户 **环境**:prod (`https://app.wemio.com`) or local (`http://localhost:8000`)?默认 prod。
2. 设置 `API` 变量。
3. 询问用户 **auth token**:
   - **API Key(推荐)**:Settings → API Keys 创建,格式 `pk_xxxxxxxx...`,永久有效
   - **JWT Token**:浏览器 DevTools → Local Storage → `wemio_token`,24h 过期
4. 验证:`GET ${API}/api/cinema-studio/projects`
5. **确立全片格式(默认已为成本优化,可问用户是否调整):**
   使用 AskUserQuestion 一次性问清:

   | 选项 | 可选值 | 本 skill 默认 |
   |---|---|---|
   | `ASPECT_RATIO` | `16:9`(推荐) / `9:16` / `1:1` / `4:3` / `3:4` / `21:9` | `16:9` |
   | `IMG_RESOLUTION` | `2K`(默认) | `2K` |
   | `VIDEO_MODEL` | `seedance-2.0-fast` / `seedance-2.0` | **`seedance-2.0-fast`** |
   | `VIDEO_RESOLUTION` | fast:`480p` / `720p`;standard:`480p` / `720p` / `1080p` | **`480p`** |

   默认成本:**480p fast = 17 credits/s,5s clip ≈ 85 credits**。10 clip 短
   片总预算 ~1000 credits。用户要调更高画质自觉跟他确认成本。

   > **⚠️ 9:16 / 1:1 等非 16:9 比例当前出片质量不如 16:9** — 和 Kling skill
   > 一样的 Phoenix 后端 bug(`cinema_prompt_builder.py` 模板硬编码 16:9 镜
   > 头语言)。竖屏终片建议 16:9 出图 + 后期裁剪,或接受风格降级。

6. 创建项目:**`studio_mode: "cinema"`**(Hollywood 影院,统一项目类型):
   ```json
   {"title": "<片名>", "studio_mode": "cinema", "genre": "<general|action|spectacle|...>"}
   ```
   记下返回的 `id` 作为 `PROJECT_ID`。

   **为什么不是 `"seedance"`?** 独立的 Seedance studio mode 产品上已废弃。
   Seedance 现在是 Hollywood 影院(cinema)项目里的一个 video provider 选
   择 — 通过 `video_provider: "ark"` + `model: "seedance-2.0-fast"` 在每次
   generate-video 时显式指定。Kling 和 Seedance 共享同一种项目容器,只是
   每个 clip 显式选 provider。但按"一部剧一个模型"原则,整部剧要统一用
   Seedance,不要中途切 Kling(skill 会帮你锁住)。

7. 把 Step 5 确立的值设为 shell 变量,后续每一步 curl 都复用:
   ```bash
   export ASPECT_RATIO="16:9"
   export IMG_RESOLUTION="2K"
   export VIDEO_MODEL="seedance-2.0-fast"
   export VIDEO_RESOLUTION="480p"
   ```

8. 初始化 `manifest.json`(本地文件,记录 character/location/clip 的 id
   和 URL,以及**关键的 `ref_map`**:`{"图片1": "Elena 主角 URL", "图片2":
   "Arthur 配角 URL", "图片3": "Factory 地点 URL"}`)。这个 map 是 Seedance
   跨 clip 一致性的核心。

---

## Phase 1 — Script Breakdown (Director's Analysis)

作为导演阅读剧本。

### Step 1: Character Bible
每个角色:`name_en`、`char_lock`(外貌锁定描述)、`emotional_arc`、
`visual_motif`。Seedance 的角色识别**完全靠图**,不靠名字 — 所以 char_lock
得能生成一张高辨识度的参考图(明显的发型 / 服装 / 标志物)。

### Step 2: Location Bible
每个地点:`name_en`、`description`、`time_of_day`、`color_palette`。

### Step 3: Style Lock
定义一句 **全片逐字复用** 的 style 描述(比如 `cinematic handheld realism,
natural practical light, visible film grain`)。所有首帧 prompt 末尾都挂
这一句。Seedance 的风格锁**更靠参考图一致性**,style lock 主要约束首帧。

### Step 4: Scene Coverage Plan
Seedance 一个 clip = 一次 `/generate-video`,**15s 内可以内部自主切 2-3
个 shot**。设计时:
- 一个 clip 里打包 **1 个戏剧单元 = 2-3 个内部 shot**(例如:WS 建立 →
  MS 动作 → CU 反应)
- 内部 shot 切换写进 prompt 文字:"Camera starts wide..., then cuts to a
  medium shot as the character..., finally pushes in on..."
- 每 clip 尽量顶满 15s 填满戏剧弧,少而长 > 多而短

### Step 5: Clip Packaging
Seedance 的 clip 打包规则和 Kling **不同**:

- **每 clip = 1 个长 take**,典型 5-10s,最长 15s
- 时长由戏决定(一个完整动作/一段对白),不像 Kling 需要压进 15s 总长
- 标 `transition_from_prev`:
  - `continuous` — 和前一 clip 无缝衔接,走**尾帧提链**(`/extract-frame` 取
    前序 clip 尾帧作本 clip 首帧)
  - `scene_jump` — 换地方 / 换时间
  - `angle_change` — 同场景新角度
  - `reaction` — 对白反应镜头
- 每 clip 标 `mode`:
  - **`ref2v`**(多数时候):`reference_image_urls` 给角色 + 地点参考,首帧
    可选。Seedance 自由发挥运动
  - **`fl2v`**:有精确首帧和尾帧要求时(比如转场插值 / 连续动作起止帧),
    给 `first_frame_url` + `last_frame_url`。**注意此模式下 ref_*
    字段全部会被丢弃**

**Clip 数量由目标时长决定**(Seedance 每 clip 15s 满载时):
15-20s(样片)= 1-2 clip;30s = 2 clip;60s = 4 clip;120s = 8 clip。
每 clip 内部打包 2-3 shot,总叙事节拍数 = clip × 2.5。

**⚠️ 常见错误:把 60s 拆成 10 个 5-6s 独立 clip** — 这样 Seedance 无法利用
"单生成内自主切镜头"的能力,又让 10 个独立 generation 在空间轴 / 角色
朝向 / 景别差异上各自为政,画面会在 clip 间乱跳。**正确做法:4 × 15s,
每 clip 内部自主切 3 shot,共 12 叙事节拍,连贯性远好于 10 × 5s。**

**Present to user for confirmation before proceeding.**

---

## Phase 2 — Character & Location Asset Generation + Seedance Registration

### Step 1: Generate Characters
Prompt 只写核心特征(外貌 + 服装 + 标志),不写灯光/色彩/镜头 — LLM 根据
genre 自动增强。

返回的 `generated_name` 只是 LLM 起的名字候选,**不保证唯一** — 两个完全
不同的 prompt 可能 LLM 都给叫同一个名字。Phase 2 Step 3 晋升 element 时
**必须由你显式指定 `name`** 保证整部剧内不重名,别直接用 `generated_name`。

### Step 2: Generate Locations
同 Kling skill,先生成 EWS 母版再基于 `is_edit: true` 做角度变体。地点
Seedance 注册时很简单(单图合规检查,不拆面)。

### Step 3: Promote to Element(不触发注册)
```
POST /elements
body: {"generation_id": "<gen_id>", "name": "<≤20 chars>", "force": true}
```
返回的 element 此时 **还没注册到 Seedance**,`seedance_registration_status`
为 `null`。

**注意**:返回的 `id` 字段就是 `element_id`(实现上复用 generation_id,
语义上请当作 element_id 用于 Step 4 的 URL 路径)。

### Step 4: **显式触发 Seedance 注册**
```
POST /elements/{element_id}/register/seedance
body: {"image_url": "<element image URL>", "description": "<≤500 chars 可选>"}
```
**`image_url` 应当和 element 本身的 `image_url` 一致**(schema 要求必传,
即使后端已知)— 直接把 Step 3 创建 element 时用到的那张图 URL 传回去就行。
后台 dispatch Celery 任务,走 Ark 合规检查(Volcengine AssetGroup +
Asset Create + Active 轮询)。状态机:
```
null → registering → done            (合规通过)
null → registering → failed          (合规失败)
```
**Seedance 没有 `needs_review` 状态**(和 Kling 不同) — 单图合规,要么过
要么不过,不需要人工审核三面图。

### Step 5: 轮询状态
```
GET /elements                # 找到此 element 行,读 seedance_registration_status
```
每 5-10s 轮询一次,**最多轮询 3 分钟**(超了按 `ark.timeout` 处理,不要
无限等):
- `done` → 可以用了。服务器端 `volcanic_asset_id` 已绑定(注意:此字段
  **不在 API 返回的 element 对象里**,只在后端 DB。skill 只需确认
  `seedance_registration_status == "done"` 且 `seedance_registration_error
  == null`)
- `failed` → 读 `seedance_registration_error`(命名空间错误码),按补救
  流程处理(见 Error Handling 段)

### Step 6: 失败补救
常见失败码及建议:
- `ark.face_policy` → 合规拒绝人脸(可能太像真人明星或违规主体)→ 换
  角色图,用明显 AI-rendered 风格而非真实人脸
- `ark.invalid_resolution` → 图分辨率不够 → 重生成 2K 或更高
- `ark.invalid_image` → 格式/尺寸问题 → 重上传(后端会自动 WebP 化)
- `ark.content_policy` → 内容违规(暴力/色情/政治) → 改 prompt
- `ark.timeout` → 合规检查超时 → 稍后重试(不要立刻重发,等 1-2 分钟)
- `ark.compliance_failed` → 通用合规失败 → 看 error 详情,常见是前几种
  细分原因的兜底

**Checkpoint:** Show all elements 和 `seedance_registration_status`。Wait for user approval。

### Step 7:**合规库登记(Seedance 核心前置步骤,Kling 没有此步)**

`/register/seedance`(Step 4)只是把 element 绑定到 Ark 的 asset_id,
让 `@图片N` 位置引用能解析到 `asset://`。但 Ark 在**生成 video 时**
会对每个 frame URL(`first_frame_url` / `last_frame_url`)和 ref URL
(`reference_image_urls`)**再跑一次合规检查** — 这次查的是 **Asset 级
别的合规库**,不是 element 级别。

两个系统,**都要做**:
| 系统 | 端点 | 目的 |
|---|---|---|
| Element 注册 | `POST /elements/{id}/register/seedance` | `@图片N` 位置引用解析成 `asset://` |
| **合规库登记** | `POST /api/compliance/check-by-url` | 帧图 / ref 图在生成时不被 Ark 以 `real_person` 等理由拒 |

合规库提交:
```
POST /api/compliance/check-by-url           ← 注意前缀是 /api/compliance/ 不是 /api/cinema-studio/
body: {"file_url": "<image URL>"}
```
返回 `{"asset_id": "...", "status": "pending"}`。轮询到 `compliant`:
```
GET /api/compliance/status/{asset_id}
```
每 5-10s 一次,通常 30-90s 过(最多 3 分钟,否则 `ark.timeout`)。

**必须提交合规库的 URL:**
- ✅ 所有 character 图 URL(即使已 `/register/seedance`)
- ✅ 所有 location / scene 图 URL(同上)
- ✅ 所有 `generate-scene` 产出的首帧 URL(Phase 3 产出)
- ✅ 所有 `/extract-frame` 产出的尾帧 URL(用作下一 clip 首帧时)
- ✅ 任何用户 `/upload` 上传的自定义参考图
- 简言之:**任何你打算传给 /generate-video 作为 frame 或 ref 的图 URL**

**什么时候做:** Element 注册完成后立刻做 compliance。Phase 3 产出的首帧 /
Phase 4 extract-frame 产出的尾帧,同样要先过合规再喂给下一 clip。

### ⚠️ check-by-url 404:URL 没有 Asset 行

`POST /api/compliance/check-by-url` 查的是 **Asset 表**里的行,如果 URL 对应
的 Asset 行不存在,会 404 `"Asset not found for URL"`。

**哪些 URL 会 404:**
- `generate-scene` 产出的首帧 URL(Phase 3 输出)— 实测 404
- 用户 `/upload` 上传但没显式注册成 Asset 的 URL

**哪些 URL 不会 404(自动建 Asset 行):**
- `generate-character` 输出的角色图
- `generate-location` 输出的地点图
- `/extract-frame` 输出的帧图(PNX-602 行为)

**遇到 404 怎么办:** 先手动注册 Asset,再 compliance:
```
POST /api/assets/register-url
body: {
  "file_url": "<URL>",
  "asset_type": "image",
  "source_type": "cinema_scene"  # 或 "upload" 等
}
```
返回包含 `id` 的 Asset 对象,然后 `check-by-url` 就能走了。

---

## Phase 3 — First Frame Generation

每个 clip 一张首帧(如果这个 clip 用 ref2v 模式可能不需要 — 见下文)。
用 `generate-scene`(`is_edit: false`)。

### 什么时候需要首帧
- **`fl2v` 模式 clip**:必须给 `first_frame_url` + `last_frame_url`
- **`continuous` 衔接的 clip**:首帧来自前序 clip 的 `/extract-frame`
- **`ref2v` 模式 clip 且要求精确构图**:给首帧锁定开场画面
- **`ref2v` 模式 clip 且不在乎具体起始构图**:可以不给 `first_frame_url`
  让 Seedance 从 reference 图自由开局(Seedance 擅长这个)

### 构图要点(需要首帧时)
1. **景别**匹配 clip 开场(prompt 明写 "Wide shot" / "Close-up" 等)
2. **动作起势态** — 抓住角色即将发力的瞬间("knees bent, about to leap"
   不是 "mid-air jump")
3. **三分线**位置(不居中)
4. **多角色**必须传入所有角色参考图 + 地点参考图到 `ref_image_urls`
   (Max 4 refs)
5. **给运动留空间** — 角色要往右跑,首帧把角色放在画面左三分线

### Prompt 策略
景别 + 角色姿态 + 构图位置 + 关键视觉元素 + 地点上下文 + 末尾 Style Lock。

### 首帧 vs 视频的 ref 图差异
- **首帧 `generate-scene`** 用 `ref_image_urls`(nano-banana-2 一次最多吃 14
  张,但 skill 建议 ≤4 张保持画面干净)
- **视频 `generate-video`** 用 `reference_image_urls`(ref2v 模式最多 9 张)

**Checkpoint:** Show first frames. Wait for user approval.

---

## Phase 4 — Video Generation (Seedance Single-Shot)

> **🎯 行业默认做法:市面精品剧绝大多数镜头都用 ref2v 全能参考出片,
> fl2v 首尾帧只在少数特定场景用。连贯性做"切镜头切景别"实现,**不是**
> 用 fl2v 一镜到底插值出来的。

> **⚡ 并发 vs 串行 — 哪些 clip 能并发,哪些必须尾帧提链**
>
> 判断标准:后一 clip 是否**视觉依赖前 clip 的输出**?
>
> | 过渡类型 | 景别变化 | 依赖前 clip 视觉 | 是否并行 |
> |---|---|---|---|
> | scene_jump(换地点) | 大 | 否 | ✅ 并行 |
> | angle_change(大跳景别,WS↔CU) | 大 | 否 | ✅ 并行 |
> | continuous(同场景动作续接) | 小 / 同 | 是 | ❌ **必须提链** |
> | 正反打对白 | 中 | 是(两人相对位置) | ⚠️ 一般要提链 |
> | prop-state handoff(上 clip 给物体,下 clip 角色持物) | — | **是**(物体位置姿态依赖生成帧) | ❌ **必须提链** |
> | 同景别连续戏(都 MS 或都 CU) | 无 | 是(整体构图) | ❌ **必须提链** |
>
> **链式提帧流程**(必须串行的 clip):
> ```
> 前 clip 生成完 → POST /generations/{id}/extract-frame {"which":"last"}
>               → 尾帧 URL 先进合规库(/api/compliance/check-by-url)
>               → 作为下一 clip 的 `first_frame_url`
>               → (可选) 作为 reference_image_urls 追加一张
> ```
>
> **判断法则**:
> - **景别不变** + **角色相对位置不变** → 几乎一定要链
> - **物体状态依赖**(Clip N 的最后一帧里有 prop,下一 clip 仍要有)→ 一定要链
> - **跨场景 / 跨时空 / 大景别变化** → 可以并行
>
> **操作建议**:
> 1. Phase 1 分镜时就标注每个 clip 的 `transition_from_prev`:`scene_jump` / `angle_change` / `continuous` / `reverse` / `prop_handoff`
> 2. 并行提交 `scene_jump` + `angle_change` 类 clip
> 3. `continuous` / `reverse` / `prop_handoff` 类**串行**,等前序完成 → extract-frame → 合规库 → 发下一 clip
>
> **反面教材**:《末班车》v2 我把所有 4 个 clip 并行提交,结果 Gemini audit 抓到:
> - 30s 过渡:Woman 没完整走完就切了(依赖 v2_c02 尾帧)
> - 45s 过渡:文件夹"瞬间消失"(依赖 v2_c03 尾帧里 Julian 手持的文件夹)
>
> 这两个跨 clip 断裂,**本来用尾帧提链可以完全避免**。

### ref2v 是主路径(精品剧 90%+ 镜头走这条)

- 角色 + 场景的一切常规戏,都传 `reference_image_urls` 做全能参考
- 需要锁开场画面时加 `first_frame_url`(注意:scene 级图要先 Asset
  register + compliance,见 Phase 2 Step 7)
- 不要执着于"把场景做成一镜到底" — 精品片都是剪辑出来的,不是生成出来的

### fl2v 是辅助工具(少数场景专用)

用 fl2v 的场景:
- 角色入场 / 出场(空景 ↔ 有人,实测可过 — 两端不都是人就行)
- 环境转场(白天→黑夜 / 雨→雪 / 空镜 1 → 空镜 2)
- 物体动画(道具 / logo / 车辆移动)
- **偶尔用于精确站位控制**:把角色 + 场景合成图(通过 scene edit 或手绘
  草图)作为首尾帧,让 Seedance 按这两张"关键帧"插值,站位由图本身决定,
  补充 prompt 描述动作

**fl2v 站位控制的具体打法**(用户实战经验):
1. 用 `generate-scene` + `is_edit: true` 生成"人物在场景里"的合成图(含
   想要的站位)作为首帧 / 尾帧
2. 或画个站位草图(棒人 / 剪影 + 场景)直接 `/upload` 后当 `last_frame_url`
3. prompt 里描述动作过程 ("@图片1 walks from left to right, reaches the
   corner")
4. 两端都有清晰人物会触发 `real_person` — 这时拆成两段 clip 或换 ref2v
5. 一端人物 + 一端空景(或草图)通常能过

### 连贯性策略(和 Kling 一样):切镜头切景别

**不要用 fl2v 硬做"一镜到底"** — 这不是影视行业的连贯性做法。精品剧
的连贯 = 不同景别 / 角度的剪辑组接。Seedance **优先用单次 generate-video
内部切 2-3 shot 打包一整个戏剧单元**,clip 间才真正切:

| 叙事关系 | 做法 |
|---|---|
| 同场 continuous 动作(戏剧单元内部) | **写进同一个 clip 的 prompt**:"Camera starts wide on...,then dollies in to medium as...,finally pushes in close to..."。Seedance 内部自主切 2-3 个 shot,不用开新 clip |
| 戏剧单元切换(一段戏结束进下段) | 新 clip(新的 /generate-video),`reference_image_urls` 保持一致 |
| 反打对白 | 可以在**同一个 clip** 里写 "Over A's shoulder showing B, then reverse to over B's shoulder showing A";Seedance 会内部切正反打 |
| 视觉冲击点(emphasis) | Insert / ECU 可以是 clip 内部最后一个 shot,不必单开 clip |
| 场景切换(换地点) | 必须新 clip + 新 ref 图进 `reference_image_urls` |

**和 Kling 的对比**:
- Kling 单 clip 内部多镜头靠 `multi_prompt` API 字段,每个 shot 有独立的
  camera_movement / duration 参数
- Seedance 单 clip 内部多镜头靠 **prompt 文字描述**,模型自己按语义切
- 两家都能出多镜头叙事,路径不同。写 Seedance 的 prompt 时要**把 shot
  序列写清楚**(用 "first..., then..., finally..." 之类的时序标记)

### 两种模式的选择

Seedance 后端**根据传入字段自动选模式**:

| 场景 | 传入字段 | 后端模式 |
|---|---|---|
| 自由发挥,多角色 / 多参考 | `reference_image_urls: [...]`(+ 可选 first_frame_url) | `ref2v` |
| 精确首尾插值 | `first_frame_url` + `last_frame_url`,**不传** ref_* 字段 | `fl2v` |
| 带参考视频做 style transfer / motion 模仿(**成本高,默认不用**) | `ref_video_urls: [...]` | `ref2v` |
| 带参考音频做 BGM / 对白节奏 | `ref_audio_urls: [...]` | `ref2v`(还需至少 1 张图或视频) |

**全能参考(ref2v)允许的组合(实测 2026-04-18):**
| 组合 | 结果 |
|---|---|
| 图片 only(最多测到 4 张合规图) | ✅ |
| 图片 + 视频(`ref_video_urls`) | ✅ |
| 图片 + 音频(`ref_audio_urls`) | ✅ |
| 图片 + 视频 + 音频 三合一 | ✅(**偶发 `service_error` transient 错误,重试即可**) |

**实战结论**:全能参考支持完整的图 / 视频 / 音频三模态同时输入。遇到
`service_error` 不要判定为"不支持",直接重发生成。

**⚠️ 互斥规则:**
- `fl2v`(给了首+尾帧)模式下,**所有 ref_image_urls / ref_video_urls /
  ref_audio_urls / reference_image_urls 都被后端丢弃**。想要 ref 保持一致
  性就不要用 fl2v
- `ref_audio_urls` 单独使用无效,**必须同时有至少 1 张图或 1 个视频**作为
  视觉锚点

**⚠️ fl2v 帧图 `real_person` 限制(实测规律):**

fl2v 会对首+尾两张帧图一起做人物检测。**两端都有写实人物才拒**;只要有一端
没人就能过。这是 Ark 对静态人脸-到-人脸深度伪造类生成的防御。

**实测对照表(2026-04-18):**
| 首帧 | 尾帧 | fl2v 结果 |
|---|---|---|
| 有写实人物 | 有写实人物 | ❌ `real_person` 拒 |
| 有写实人物 | 无人(纯环境) | ✅ 过 |
| 无人(纯环境) | 有写实人物 | ✅ 过 |
| 无人 | 无人 | ✅ 过 |

**前提**:两端帧图都必须先进**合规库**(`POST /api/compliance/check-by-url`
+ 轮询到 `compliant`),否则直接 404 或 `real_person`。
- `generate-character` / `generate-location` 输出的图 → 自动有 Asset 行,
  `check-by-url` 能直接提交
- `generate-scene`(首帧)/ 自己 `/upload` 的图 → **不自动有 Asset 行**,
  先 `POST /api/assets/register-url` 建行,再 `check-by-url`
- `/extract-frame` 输出 → 自动有 Asset 行,直接 `check-by-url` 即可

**fl2v 典型用法:**
- 角色入场:首帧无人空景 → 尾帧角色落位(过)
- 角色出场:首帧角色 → 尾帧空景(过)
- 环境转场:空→空,比如天色变化、雨→雪(过)
- 物体动画:道具 / logo / 建筑(过)

**fl2v 不能做:**
- 角色 → 角色转场(两端都有人拒) — 改走 ref2v 或 continuous 尾帧提链

**角色 → 角色转场的替代方案:**
- ref2v:`first_frame_url: <scene 首帧>` + `reference_image_urls:
  [character1, character2, location]`,不传 last_frame_url,让 Seedance 自由
  演到结尾
- 两个 clip + 尾帧提链(Phase 4 的 continuous 模式)

### 请求模板(ref2v 多角色一致性,推荐默认)
```json
POST /generate-video
{
  "prompt": "<自包含完整 prompt,≤2500 chars,含 @图片N 引用>",
  "reference_image_urls": ["<char1_url>", "<char2_url>", "<loc_url>"],
  "first_frame_url": "<可选首帧>",
  "duration": 5,
  "sound": true,
  "video_genre": "action",
  "aspect_ratio": "16:9",
  "resolution": "480p",
  "video_provider": "ark",
  "model": "seedance-2.0-fast",
  "project_id": "<PROJECT_ID>"
}
```

**关键**:prompt 里的 `@图片1` 对应 `reference_image_urls[0]`,
`@图片2` 对应 `[1]`,依此类推。整部剧 **ref 顺序必须固定**(Phase 0
manifest 的 `ref_map`)。

### 请求模板(fl2v 首尾帧插值,用于转场)
```json
POST /generate-video
{
  "prompt": "<纯文本描述 A 到 B 的过渡>",
  "first_frame_url": "<起始帧>",
  "last_frame_url": "<结束帧>",
  "duration": 5,
  "sound": true,
  "aspect_ratio": "16:9",
  "resolution": "480p",
  "video_provider": "ark",
  "model": "seedance-2.0-fast",
  "project_id": "<PROJECT_ID>"
}
```
**注意**:fl2v 模式下就算传 `reference_image_urls` 也会被丢弃,角色一致性
完全靠首尾帧承载。

### Prompt 策略(Seedance 2.0 — 精确运镜术语为核心)

**最重要的一条铁律**:Seedance 2.0 电影感的核心杠杆是**用精确的运镜名词**
(不是泛泛的 "camera moves slowly" / "slow push" 这种形容词拼凑)。

❌ `camera slowly moves around the subject`(泛泛)
✅ `子弹时间镜头`(命名调用,Seedance 在 training 里学过具体语义)

❌ `intense tracking shot for fight`(泛泛)
✅ `打斗跟随镜头`(具体命名)

❌ `tense close-up showing fear`(泛泛)
✅ `瞳孔放大镜头` 或 `眼抖特写镜头`(具体命名)

**写每个 shot 的 prompt 时:先从 `camera-vocabulary.md` 挑一个对应的
运镜术语**,再组装其他信息。80 个精选术语按情绪/动作/特效分类。

### ⚠️ Seedance 穷尽描述(Exhaustive Description)原则 — 写 prompt 第一铁律

**Seedance 2.0 对 prompt 指令遵守极好 — 问题永远是你写得不够完整,不是它不听话。**

写 prompt 时,把整个场景当作一张"时空蓝图"来画,每个元素的每个瞬间
都要在蓝图上。AI 不会脑补没画的地方,只渲染蓝图上有的。

#### 必须写全的四个维度

**(1) 每个出场角色** — 位置 + 起始状态 + 全程动作 + 结束状态
- 不只主角:配角 / 背景人物也要
- 每个动作都写**起势→过程→完成→终态**(4 段公式)

**(2) 整个环境** — 场景元素的**全程状态**,特别是关键物件
- 列车:门开着吗?关了?驶离了?
- 灯光:闪烁?常亮?灭了?
- 天气:雨下着?停了?变大?
- 蒸汽 / 雾 / 烟:弥漫?消散?
- 不写 = AI 自由发挥 = 每次不一样

**(3) 所有 prop** — 从出现到离场完整轨迹
- 谁拿着?放哪?传给谁?
- 状态:关闭 / 打开 / 破损 / 完整
- 颜色材质形状要精准(`dark black leather folio` 不是 `folio`)

**(4) 时序** — 0 秒到最后一秒每个重大变化
- 每个内部 shot 切换点的前后状态都要清晰
- **clip 结束时画面应该是什么样**必须写明

#### 动作 4 段公式(R11 字面主义)

**公式:动作 = 起势 + 过程 + 完成态 + 终结状态**

| 动作类型 | ❌ 只写一半(AI 只演起势) | ✅ 写完整(AI 演全过程) |
|---|---|---|
| 走向某处 | `walks back toward the train` | `walks back to the train, **steps up into the carriage, disappears through the doors, which hiss closed behind her**` |
| 上交物体 | `she hands him the folio` | `she extends folio, **he grasps it firmly with both hands, she releases, her hands drop empty to her sides, he now holds it at chest**` |
| 火车驶离 | `train pulls away LEFT` | `train pulls away, **fully exits the frame to the LEFT, tail lights vanish into the tunnel**` |
| 坐下 | `he sits down` | `he sits down **into the chair, settles back, hands on armrests**` |
| 离开 | `she turns and leaves` | `she turns, **walks out of frame right, footsteps recede into silence**` |
| 点燃 | `he lights a cigarette` | `he lights a cigarette, **flame touches tobacco, tip glows red, first smoke curls upward**` |

#### Prompt 字数的现实

Phoenix Cinema Studio API 对 prompt 有 **2500 字符硬上限**(Pydantic
`max_length=2500` 在 `CinemaGenerateVideoRequest.prompt`)。超了 422。

实战字数规划(每 15s clip):
- **目标:2200-2450 字符**(英文约 350-400 词,中文约 700-800 字)
- 第三方 2.0 guide 的"60-100 词"是 generic 短 prompt 的经验,**完全不适合
  精品剧**,太短会让 Seedance 自由发挥
- 精品剧完整描述需要 R11 四维度全覆盖,**用字精炼但不删状态**

**写长了超 2500 怎么办**:
1. 优先保留:角色动作的完成链 + prop 状态 + 终态
2. 可压缩:重复的场景氛围描述、冗长的形容词堆
3. 不能删:LEFT/RIGHT 轴、运镜名词、物理几何、prop 材质
4. 中文比英文密度高,同样信息中文字符数约英文的 1/3 到 1/2

#### Pre-check 的四个"问自己":

写完每个 clip prompt,过一遍:
1. **每个被提到的角色**,我写了他整段戏的状态吗?还是只写了他第一秒?
2. **场景里可见的不动元素**(列车/门/灯/天气),我写了它全程状态吗?
3. **每个 prop**,我写清楚从头到尾它在哪、谁拿着、什么状态吗?
4. **这个 clip 结束时的画面**是什么样?prompt 里有写明这个终态吗?

任何一条答不上 → prompt 不完整 → Seedance 会在那个空白处"自由发挥"。

#### 实战教训:《末班车》v3 所有 major bug 都是描述不完整

| bug 表象 | 我漏写的 | 补全做法 |
|---|---|---|
| Woman 给完就站着不动 | 她进车 / 门关 / 车去哪 | 写全"她走到门 → 踏上车 → 消失在车内 → 门关上" |
| 列车没真离站(几个红点) | 它到底走没走 / 出画面没 | 写全"列车完全驶出画面向左 / 尾灯消失于隧道黑暗中" |
| Folio 变 book 变 bag | c03/c04 没说同一个 prop | 每 clip 都复述"the SAME dark leather folio from the previous scene" |

**总结:AI 不猜。写多少就渲染多少。**

### 基础 prompt 结构(精确运镜 + 四层信息)

一条 shot prompt 里组装 5 块信息,**运镜术语必须具体命名**:

1. **精确运镜名词**(必写) — 从 vocabulary 挑,放在句子靠前位置
2. **主体 + 动作** — `@图片N` 引用 + 具体动词序列("ducks, pivots,
   counter-punches")
3. **环境 + 光线** — 在哪,光怎么打。**光照是高杠杆,一行写好的 lighting
   比十个形容词管用**(`"practical light from overhead fluorescent, cool
   teal shadows on wet tile"`)
4. **对白**(如有) — `@图片1 says: "台词"`,Seedance 自动 lip-sync
5. **风格锁** — 句末挂全片 style lock(`"cinematic handheld realism, 35mm
   film grain, desaturated teal-amber grade"`)

### 单 clip 内部多 shot 的校准配方(基于《末班车》v5 五次实测)

Seedance 2.0 **能**在单 `/generate-video` 内触发真切镜,但对 prompt
内容的**敏感度极高**。以下是 5 次实测(3 失败 + 2 成功)炼出来的配方。

#### 实测日志

| 测试 | prompt 结构 | 每 shot subject/framing 独立? | 结果 |
|---|---|---|---|
| v5 c01 v1 | `Shot 1 (0-5s, 稳定长镜头): ...` 括号时间戳 | 否(全程 Julian+列车同机位) | **单镜** |
| v5 c01 v2 | `[0-5s] CUT TO 车辆跟随 — ...` | 否(同上) | **单镜** |
| v5 c01 v3 | 五字段硬跳表格 `景别/角度:特写...` | 否(同上) | **单镜** |
| v5 c02 v1 | `0-3秒: ECU 靴 ... 3-8秒: 切到中远景双人...` | **是**(靴/双人远/双人近/OTS) | ✅ **4+ 切镜** 但压到前 6s |
| v5 c02 v2 | `0-4秒 / 4-9秒 / 9-15秒:` 3 shot | **是**(靴/双人 handoff/OTS) | ✅ **3 切镜** 均匀填 15s |

#### 结论:三条硬规则

**R1:Subject/Framing 独立性是唯一的触发器**。不是格式、不是关键词、不是运镜术语 — 是每个 shot 的 PRIMARY SUBJECT 和 FRAMING 必须**真正独立**:
- ✅ Shot 1:只有脚(无人脸、无背景主体);Shot 2:双人远景;Shot 3:手 macro(无面孔)
- ❌ Shot 1:Julian LEFT 列车 RIGHT;Shot 2:Julian LEFT 列车 RIGHT(停了);Shot 3:Julian LEFT + Woman RIGHT(动作推进)

"同主体+时间推进"不管 prompt 怎么写,Seedance 都读成一镜。

**R2:2-3 shot 甜蜜区**。c02 v1 写 4 shot → Seedance 把 4 个挤到前 6s,后 9s 拖慢。c02 v2 改 3 shot → 每 shot 平均 5s 均匀填满 15s。**超 3 shot 模型会乱套**(中文社区和英文 guide 都说"4-15 秒内超 2-3 个镜头变化容易乱")。

**R3:格式相对次要**。`0-X 秒:` 冒号、`[0-Xs] CUT TO`、`Shot N` 标号在 No.1
featured(中文日式浪漫)、王家卫雨夜电话亭(中文 noir drama)、oimi.ai
diversity(英文 10-shot)等 working 例子里都见过。**只要 R1+R2 满足,格式
三种都工作;R1 不满足,格式怎么改都不切**。当前首选中文 `0-X 秒:` 冒号
格式(No.1 featured 同款,与 c02 v2 一致)。

#### 跨 shot 动作延续的锚定法则(R16 新规)

c02 v2 观察到的新问题:**Shot 1 Woman 走在站台上,Shot 2 Seedance 把 Woman
退回到车门刚出来状态**。原因:
1. Shot 2 写"从 RIGHT 走入画面" — Seedance 字面读"从 RIGHT 方向(=车)走进来"
2. ref_image_urls[c01 尾帧] 显示 Woman 在车门边 → 每 shot 都被拉回这状态
3. Shot 1 位置没锚定(通用"走路")→ Shot 2 重置自由度大

**解决**:每个内部 shot 的**起始位置必须用绝对位置描述**,不用相对方向;
必要时**显式否定不想要的起始态**。

| 表达 | 效果 |
|---|---|
| ❌ "Woman 从 RIGHT 走入画面" | Seedance 读"刚从车(RIGHT 方向)出来" |
| ✅ "Woman 此时已在 Julian 前 1 米处停住,不再处于车门口" | Seedance 锁位置 |
| ❌ "她走向 Julian" | 起点不定 |
| ✅ "她已走到 Julian 前 1 米,停下" | 起点明确 |
| ✅ "**她不从车里出来,她已经在站台中间**" | 显式否定 |

### Seedance 内部多 shot 做不好的事

即便 R1+R2 都满足,有些跨 shot 状态仍脆弱:
- **精细 prop 状态延续**(folio 单手 vs 双手在 shot 3 vs shot 4 可能翻转)
- **环境状态稳定性**(车门在 shot 1 开 → shot 3 可能变关或 glitch 反复开关)
- **终态 pose / 朝向**(Julian 前 14s 朝 RIGHT,最后 1s 可能翻朝镜头 — c02 v2 出过这个 bug)

**对策**:prompt 里**显式重复终态锁定**("Julian 在整个 clip 中面朝 RIGHT,身体不得朝镜头","车门在整个 clip 中保持敞开,不得反复开关 glitch"),大写强调。

### Seedance 的创意 override(c03 观察)

c03 实测发现 Seedance 会**主动替换某些 framing 指令**成更"电影感"的构图。
这些是可观察的 override 边界:

**1. MACRO 窄 framing 很难强制**:prompt 写"MACRO 俯视 / 只有双手和 folio /
无背景",Seedance 自行扩成**wide 环境镜头**(Julian 全身 + 站台 + 列车都
入画)。它判断"只有手+物体" 太不叙事,擅自改成更宽的构图。
- **对策**:强 negative 语言,把默认选项堵死。比如:
  - "整个画面没有任何 wall / ceiling / floor / body above elbow / character
    face / background environment"
  - "画面占比:物体 70%,手 30%,背景 0%,纯黑 void 环绕"
  - "This shot is a pure object study,no narrative context"

**2. 切镜类型 = Seedance 自由发挥**:你说"hard cut"它可能给你 dissolve /
cross-fade / 叠化;你说"cross-fade"它可能硬 cut。Seedance **过渡风格不是
可靠指令**,要接受它自己的选择。c03 的 shot 2→3 过渡是瞳孔+环境 dissolve
叠化(非常好看,但 prompt 里其实没要求)。
- **结论**:你能控切**位置和次数**(通过 subject diversity),控不了**过渡风格**

**3. 精细视觉效果 ≈ 忽略**:瞳孔里反射某物、某光打在某人脸上某角度、物体
上某特定 texture 变化 — 这类"子像素级"视觉需求 Seedance 基本不执行。
c03 要"列车尾灯红色 bokeh 反射在瞳孔"Seedance 没做。
- **结论**:Seedance 出的是**场景级**合成,不是**像素级**视觉效果。要眼睛
  反光这种精细效果,要么后期合成,要么放弃

### 真要多 shot 又不敢赌 Seedance,备选路径

**1 shot = 1 次 `/generate-video`** + ffmpeg concat(用 `cinema-studio-ops` skill):
- ✅ 可控,每 shot 独立 prompt
- ✅ 跨 shot 连贯靠抽帧 + `reference_image_urls`(R15 reframe-chained)
- ❌ 贵 30-60%,失 latent memory(prop/pose 延续更脆)

Kling 的 `multi_shots` API 字段是原生多 shot,靠 API 结构不是 prompt 提示。

### 3-shot 稳妥公式

遇到想不出具体运镜时的默认回路:
**Wide establishing(后退揭示镜头)→ Medium action(推进亲密镜头)→
Close-up detail/reaction(瞳孔放大镜头 或 眼抖特写镜头)**

每 shot ~5s,总 15s。这是电影语法最稳的三镜头结构。

### 一 shot 一运镜原则

**一个 shot 只用一个运镜术语** — 两个叠起来模型听谁的不确定,出片
会混乱。需要多个运镜效果就拆成多个内部 shot(一个 clip 内 2-3 个,各用
自己的运镜)。

### 空间轴锁死(180° 规则)

Seedance 跨 shot / 跨 clip 会"重掷骰子"选角色朝向,导致观众感觉乱跳。
**每个 shot prompt 里都要显式写**:
- "@图片1 stands on the right third of frame"
- "train enters from the LEFT side of frame"
- "maintain 180° axis throughout"

没写 = Seedance 每 shot 自主重排画面朝向 = 断轴。

### 跨镜动作连续性(Match on Action)— 解决"手打开了文件,切完手就没了"

AI 视频 **最严重的出戏问题之一**:Shot A 手打开文件夹,Shot B 新角度的
文件夹飘在空中或桌上**没手撑着**。状态(文件夹开着)失去了原因(手在开)。
观众直觉到"不合理"。

**本质**:物体状态 = 原因 + 结果。状态持续依赖的原因,切镜后必须继续给出。

#### Seedance 2.0 的 Latent Memory(利好)

Seedance 2.0 **单次 `/generate-video` 调用的内部多 shot** 有
"Latent Memory Thread" — 会记住前一 shot 的物体位置和角色动作,保证跨内部
shot 的物体永续性(论文里的例子:"Shot A 举杯 → Shot B 杯仍在同一手同一
高度")。**但 memory 只在一次生成内部有效,跨 generate-video 调用就断**。

**实战结论**:物体状态依赖强的切镜(开文件夹、举杯、拔剑、点烟)**尽量
打包到同一个 clip 的内部多 shot**,不要拆成两个 clip,这样 Seedance 的
latent memory 能救场。

#### 写 prompt 时的四条铁律

| 场景 | ❌ 错误写法 | ✅ 正确写法 |
|---|---|---|
| 手打开文件夹 | Shot A "hands open folio" → Shot B "overhead view of open folio on the bench" | Shot A "hands open folio" → Shot B "closer angle on the open folio **still held in both hands**, edge of fingers visible in frame" |
| 举杯 | Shot A "he raises glass" → Shot B "close-up on the wine" | Shot A "he raises glass" → Shot B "macro on the wine, **his fingertips visible at bottom edge of frame** holding the stem" |
| 拔剑 | Shot A "she draws sword" → Shot B "low angle on the raised sword" | Shot A "she draws sword" → Shot B "low angle on the sword, **her forearm and hand visible at top of frame** gripping hilt" |
| 看文件 | Shot A "he opens folder, reads" → Shot B "insert on one page, nothing else" | Shot A "he opens folder, reads" → Shot B "insert on the page, **his shadow falls across it**, his breathing audible" |

**四条铁律整理:**

1. **切到特写/插入镜时,让因果物体的一部分(手边 / 肩边 / 影子 / 呼吸声
   环境提示)留在帧内或音轨里** — 不要完全切空,状态就悬了
2. **Match on action — 在动作进行到一半时切**,而不是完成后。观众眼睛
   在追动作,自动忽略剪辑的瞬间。写法:"As his fingers open the cover, cut
   to..."(在过程中),不是 "He has opened the cover. Cut to..."
3. **高依赖状态切镜打包进单 clip 内部多 shot**,用 Seedance 的 latent
   memory 保护。不要拆两个 generate-video 调用
4. **或者让状态自解释**(无需原因的状态):文件夹放**桌上**翻开、杯放
   **桌上**、剑**插在地上** — 物体脱离手之后仍然合理,就可以自由切角度
   不用每帧留手

### 跨 clip 角色一致性(Seedance 的核心能力)

**关键原则:每个 clip 都传同一批 `reference_image_urls`,顺序不变。**

```
Clip 1: reference_image_urls = [Elena URL, Arthur URL, Factory URL]
         prompt 用 @图片1 / @图片2 / @图片3
Clip 2: reference_image_urls = [Elena URL, Arthur URL, Factory URL]  ← 一字不差
         prompt 继续用 @图片1 / @图片2 / @图片3
Clip N: ...一致到底
```

后端反查每个 URL 是否绑定了 `volcanic_asset_id`(通过 register/seedance
绑定),有则传 `asset://<id>` 给 Ark,Ark 会锁定那个合规过的资产 → Seedance
跨 clip 看到同一个视觉锚点。

**这是 Seedance 等价于 Kling `cast_element_ids` 的机制** — 只是单位是"注册过
的图片 URL"而不是"element 抽象"。

### Clip 间连接

| 叙事关系 | 连接方式 | 首帧来源 |
|---|---|---|
| continuous | 尾帧提链 | 上一 clip 视频 `/extract-frame` `which=last` |
| angle_change | 新首帧 + 同一套 ref | `generate-scene` 新角度 + reference_image_urls 不变 |
| scene_jump | 新首帧 + ref 列表里换掉地点 URL | 新地点 ref 替换旧的 |
| reaction | 新首帧 | 独立构图,ref 保持 |

**并行策略**:非 continuous 可并行;continuous 必须串行(依赖前序尾帧)。

> **⚠️ 执行顺序铁律:**
> 1. 先识别所有 clip 的 `transition_from_prev` 类型
> 2. 将非 `continuous` 的 clip 的首帧和视频并行提交
> 3. `continuous` clip 必须等前序 clip 视频完成后:调
>    `POST /generations/{prev_video_gen_id}/extract-frame` `{"which":"last"}`
>    → 取返回的 `image_urls[0]` 作为本 clip 的 `first_frame_url`
> 4. **绝对禁止**为 `continuous` clip 生成独立首帧再生成视频

### video_genre 选择
保留 Kling skill 的 8 genre(general / action / horror / suspense /
comedy / western / intimate / spectacle)。后端会根据 genre 调整 LLM 扩写
的风格描述。**同一集 genre 必须全局统一**。Seedance 本身擅长 `action` /
`spectacle`(真实动作大场面),对 `intimate`(细腻情感戏)不如 Kling。

### 720p / 1080p 升档

预览期全程 480p fast 省钱。终片出片阶段再升档:
- `"model": "seedance-2.0-fast", "resolution": "720p"` — 36 credits/s,
  画质明显提升
- `"model": "seedance-2.0", "resolution": "1080p"` — 91 credits/s,
  **贵 5x**,只在明确要院线/电视台分发时用

**Checkpoint:** Show all clips. Wait for user approval.

---

## Phase 5 — Summary & Output

1. Project: Title, genre, project ID, studio_mode
2. Characters: Name, image, element id, seedance_registration_status
3. Locations: Name, image, element id, seedance_registration_status
4. Clips: First frame(如适用)、video URL、模式(ref2v / fl2v)、duration、
   credit_cost
5. 保存 `manifest.json`(含 `ref_map` + 每个 clip 的 mode 记录)

### 成片拼接(post-production)

本 skill 只负责生成 N 个独立 clip URL。**用户说"拼起来" / "做成一个片子"时,
交给 `cinema-studio-ops` skill 处理**(本地 ffmpeg concat,产物默认保存本地
`/tmp/...`,不自动上传 S3)。参考:`skills/cinema-studio-ops/SKILL.md`。

(`volcanic_asset_id` 在后端 DB 但不在 API 响应里,不用记在 manifest 中;
每次 generate-video 时后端会自动反查绑定)

---

## Error Handling

后端错误已结构化,`generation.error` 会是命名空间码,不是原始异常文本。
按码做对应补救:

### 生成错误(generate-video / generate-scene)
| 错误码 | 含义 | 补救 |
|---|---|---|
| `parameter_invalid` | **模型不支持该参数组合**(例如 `seedance-2.0-fast` + `resolution: 1080p`,fast 顶 720p) | 检查 model / resolution 是否匹配;`seedance-2.0-fast` 只支持 480p/720p,要 1080p 得切 `seedance-2.0` |
| `real_person` | **fl2v 两端帧都有写实人物**(实测:只要一端有、另一端无就能过;两端都有人才拒,即使都合规过) | 保留一端为空景(角色入场 / 出场);或两端都换成环境图;或角色-角色转场改走 ref2v / continuous 尾帧提链 |
| `service_error` | **通用 transient 后端错误**,常见于多模态 ref 组合(如图+视频+音频三合一) | **先直接重试一次** — 多半再试就过了。反复失败再排查 ref URL 是否可访问 |
| `ark.invalid_resolution` | 参考图分辨率过低 | 用高分图重传或用 `generate-scene` 出一张高分参考 |
| `ark.content_policy` | 触发内容策略 | 改 prompt(去掉暴力/色情/政治关键词)或换参考图 |
| `ark.rate_limited` | Ark 侧限流 | 等 30-60s 重试 |
| `ark.timeout` | 轮询超时 | 再等 1-2 个 polling interval,实在不行取消重发 |
| `ark.invalid_image` | 图格式不对 | 确认 http(s):// URL,后端会自动 WebP |

**注意**:不是所有错误都是 `ark.*` 命名空间 — 后端 Pydantic / business-logic
层的参数校验错误会用 `parameter_invalid` / `422` 等通用码,**只有到了
Ark 这一层才返回 `ark.*`**。遇到非 `ark.*` 码一般看 response body 的
`detail` 或 error 字段细节排查。

### 注册错误(register/seedance 失败)
| 错误码 | 含义 | 补救 |
|---|---|---|
| `ark.face_policy` | 合规拒绝人脸(过真 / 疑似名人 / 敏感主体) | 换风格化角色图,避开真人脸 |
| `ark.invalid_resolution` | 分辨率不够 | `generate-character` 出 2K 版 |
| `ark.invalid_image` | 格式/尺寸问题 | 重上传,确认 URL 有效 |
| `ark.content_policy` | 图片内容违规 | 改 prompt 重生成 |
| `ark.duplicate_group` | AssetGroup 重名 | 换 element `name`,`force: true` 重发 |
| `ark.compliance_failed` | 通用兜底 | 读 `seedance_registration_error` 详情,多为上述细分 |
| `ark.timeout` | 轮询超时 | 稍后重试 |

### 通用
- `401 Unauthorized` | token 过期 | 问用户要新 token
- `422 Unprocessable Entity` | Pydantic 校验失败 | 看 response body 的 detail
- 生成失败后 credit 自动退款,不要自己发 refund
- 后端自动生成 `.webp` sibling 并传给 Ark,skill 不需要管图片格式转换

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
  compliance (single-step, no review modal), produces single-shot video clips where
  motion and physics carry the scene.  Cross-clip consistency comes from reusing
  the SAME registered `reference_image_urls` across every clip.

  Use when user wants:
    - "动作片 / MV / 短视频 / 运动 / 武打 / 追逐"
    - "真实物理 / 写实运动 / 打斗场面 / 体育 / 慢动作"
    - "中文 prompt 原生 / 参考视频 / 参考音频 / 音乐节拍"
    - "带对白 + 口型同步的短剧 / phoneme-level lip-sync"
    - "produce my action script", "motion-heavy script to video"

  Do NOT use for:
    - Long-form narrative with multi-shot per clip needed — use
      ``script-to-video-kling`` (Seedance is single-shot only, you'd need to split
      each narrative beat into separate clips)
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
> - `film-language.md` — 景别、运镜、构图、对话规则、场景连贯策略
> - `examples.md` — Prompt 示例、JSON 示例、curl 模板、注册流程、模式选择
> - `checklist.md` — Director's Review Checklist + 三轮生成策略

## 执行纪律

- **禁止写脚本批量执行。** 每一个 API 调用(生成角色、地点、首帧、视频、
  注册、帧提取)都必须在对话中逐步执行,不要把多个 clip 的生成逻辑写进
  shell 脚本。可以连续执行多个 clip 不必每个都等确认,但必须在对话中直接
  调用命令,让用户随时能打断。

## Director's Mindset (Seedance 取向)

### 场景分析框架

Seedance 的长处是**真实物理 + 长单镜头 + 动作连贯**,不是多镜头叙事切换。
写 prompt 前:

1. **动作质感** — 这场戏的核心物理动作是什么?重心、惯性、布料、水花、
   撞击?写进 prompt 最前面
2. **单镜头 ≤15s 的戏剧弧** — 因为没有 multi-shot,每个 clip 必须在一个
   连续镜头里完成一个完整的戏剧单元(开始→过程→结果)
3. **运镜写进文字** — 没有 `camera_movement` 枚举,想要推镜 / 跟拍 / 手持
   都靠 prompt 描述("camera follows behind, handheld" 等)
4. **口型同步要对白** — 如果 clip 有角色说话,直接在 prompt 里写台词
   (`@图片1 says: "..."`),Seedance 会生成匹配的口型

### Seedance 2.0 Fast 要点

- **Single-shot**:每 clip 就一个 shot,≤15s,没有 multi-shot 概念
- **两种模式**(后端根据传入字段自动选):
  - **`ref2v`** — 多模态参考模式,`reference_image_urls`(≤9)/
    `ref_video_urls`(≤3)/ `ref_audio_urls`(≤3)**任一**存在时进这个模式
  - **`fl2v`** — 首尾帧模式,`first_frame_url` + `last_frame_url` 都给时进
    这个模式;**和 ref2v 互斥** — 给了首尾帧,所有 ref_* 字段会被后端丢弃
- **强项**:真实运动物理、多模态 ref 保真(品牌色 / 指定人脸)、音素级
  lip-sync、中文 prompt 原生、动作片质感
- **弱项**:
  - **无 multi-shot** — 一个 clip 一个镜头
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
- Video prompt(single-shot,Seedance **没有** multi-shot):**max 2500 chars**
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
Seedance 的每个 clip 是一个**独立长 take**,不是 multi-shot 组合。设计时:
- 每个叙事节拍 → 1 个 clip(一镜到底,≤15s)
- 内部弧:起势 → 动作高潮 → 落势
- 情绪变化通过角色表演+运镜文字+环境动态实现,不靠切镜

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

**Clip 数量由目标时长决定**:15-20s(样片)= 2 clip;30s = 3-5 clip;
60s = 6-12 clip;120s = 15-25 clip。Seedance clip 通常比 Kling 短(没
multi-shot 能力),clip 数会多一些。

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

### 两种模式的选择

Seedance 后端**根据传入字段自动选模式**:

| 场景 | 传入字段 | 后端模式 |
|---|---|---|
| 自由发挥,多角色 / 多参考 | `reference_image_urls: [...]`(+ 可选 first_frame_url) | `ref2v` |
| 精确首尾插值 | `first_frame_url` + `last_frame_url`,**不传** ref_* 字段 | `fl2v` |
| 带参考视频做 style transfer / motion 模仿(**成本高,默认不用**) | `ref_video_urls: [...]` | `ref2v` |
| 带参考音频做 BGM / 对白节奏 | `ref_audio_urls: [...]` | `ref2v`(还需至少 1 张图或视频) |

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

### Prompt 策略(Seedance 特有)

| 项 | 怎么写 |
|---|---|
| **运动物理** | 前置!"fast tracking kick, weight transfers to back foot, wet concrete splashes" |
| **运镜** | 写文字:"camera follows from behind handheld, rapid pan" |
| **对白** | `@图片1 says: "台词"` — Seedance 会自动生成对应口型 |
| **环境声** | 提一下氛围:"distant thunder, neon buzz, footsteps echo" — Seedance 会合成 |
| **角色一致性** | 句子里用 `@图片N` 而不是描述角色("@图片1 dodges left" 不是 "the short-haired woman dodges left") |
| **动作节奏** | 用动词序列:"ducks, pivots, counter-punches, recovers stance" |
| **style lock** | 句末挂全片风格句 |

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

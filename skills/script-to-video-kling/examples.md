# Prompt & API Examples (Kling)

> 按需参考。写 prompt、发 API 请求、排查问题时查阅。

所有路径前缀 `${API}/api/cinema-studio/`,Auth header 统一 `-H "Authorization: Bearer ${TOKEN}"`。

## Token 语法约定

本文件的**首帧 prompt 和 shot prompt 示例为便于阅读用 @Name 按名引用**
(如 `@Eris`、`@Thanatos`)。实际调 `generate-video` 的 `multi_prompt`
时,**优先用 `@素材N` 位置引用**(与 Phoenix UI 一致,前端 cast chip
默认这种形式)。转换规则:

```
cast_element_ids = [ERIS_ELEM_ID, THANATOS_ELEM_ID]
                     ↓                ↓
                   @素材1            @素材2
```

即 `cast_element_ids` 列表的 **index+1** 对应 `@素材N`:
- `cast_element_ids[0]` ↔ `@素材1` ↔ 你叫的角色 A
- `cast_element_ids[1]` ↔ `@素材2` ↔ 你叫的角色 B

**整部剧 cast_element_ids 顺序必须固定**,否则后续 prompt 全错乱。
manifest.json 里记下 `cast_map: {"素材1": "Eris", "素材2": "Thanatos"}` 方便
后续回查。两种语法后端同时支持、等价,可以混用。

## 首帧 Prompt 示例

**ECU, zoom_in(eyes snap open):**
```
Extreme close-up of a face filling the frame. {CHAR_LOCK}. Eyes shut,
brow furrowed in unconscious tension, lips parted. Rain droplets on
eyelashes and cheeks. One hand visible at bottom of frame pressing
against wet concrete. Face positioned on right third, leaving space
left for zoom push. {STYLE_LOCK}
```

**MS reverse, static(character appears behind another):**
```
Medium shot from behind @Eris right shoulder (over-shoulder framing).
She stands tensed on wet street, fists half-clenched. In front of her,
a figure steps from an impossibly deep shadow — @Thanatos, tall,
silver-white hair, black overcoat. Background: Brooklyn street, rain,
distant car headlights. Rule of thirds: Eris at left third, Thanatos
at right third. {STYLE_LOCK}
```

**WS establishing, static(新场景建立):**
```
Wide shot of an abandoned subway platform, tiles cracked, a single
flickering fluorescent strip overhead. Wet concrete floor reflects the
light. @Eris steps into frame from right, tiny against the vast
empty space. Leading lines of platform edge converging to left vanishing
point. Ample headroom to emphasize isolation. {STYLE_LOCK}
```

## Video Shot Prompt 示例

**简陋版(不够 — Kling 无法推断):**
`"@Thanatos makes coffee. @Eris watches."`

**丰富版(推荐 — ~430 chars,留余量给后端 suffix):**
```
Shabby but spotless apartment kitchen above a Bushwick grocery store. Morning
sunlight filters through grimy windows, casting long shadows across the
counter. @Thanatos stands at the stove making coffee with unnaturally precise
movements, like someone who recently learned to use a kitchen. @Eris watches
from the doorway in borrowed clothes too large for her, arms crossed, one
hand resting near the seal on her chest. Steam curls from the mug. Quiet,
heavy tension between them.
```

**每个 shot prompt 5 层信息:**
1. **环境** — 在哪?什么光线?
2. **视觉特效** — 发光 / 碎裂 / 超自然效果(**放最前面!**)
3. **角色动作** — @Name 在做什么?
4. **对话** — @Name speaks: "台词"
5. **声音 / 质感** — 环境音、触感细节

## Multi-Shot 覆盖策略示例

**戏剧递进(3 shots — wide→medium→close):**
```json
[
  {"prompt": "@Eris alone, tiny in vast dark alley. Rain hammering. Isolated silhouette.", "duration": 5, "camera_movement": "drone"},
  {"prompt": "Golden veins pulse and flash under @Eris skin. She pushes up, trembling, knees shaking on wet concrete.", "duration": 5, "camera_movement": "dolly_out"},
  {"prompt": "Chest seal emits intense gold light. @Eris hand hovers over it. Eyes wide. Dread.", "duration": 5, "camera_movement": "dolly_in"}
]
```

**对峙(3 shots — two-shot→single→reaction):**
```json
[
  {"prompt": "@Thanatos steps from deep shadow into rain-slick street. @Eris recoils a half-step. Crackling tension between them. Silver hair catches distant headlights.", "duration": 5, "camera_movement": "static"},
  {"prompt": "@Thanatos speaks calmly, hand outstretched toward camera. Ancient authority in his bearing. Behind him, the shadow still visible — unnaturally deep.", "duration": 5, "camera_movement": "dolly_in"},
  {"prompt": "@Eris dark energy surges from her palms, cracks brick wall behind her. Defiant glare. Hair lifts in ambient force.", "duration": 5, "camera_movement": "zoom_in"}
]
```

**对白场景(2 shots — over-shoulder A → over-shoulder B,严格 180°):**
```json
[
  {"prompt": "Medium shot from behind @Eris right shoulder. @Thanatos faces her across the kitchen table, speaks: 'They will find you if you stay here.' His silver hair catches morning light. @Eris visible only as tense back and shoulder.", "duration": 4, "camera_movement": "static"},
  {"prompt": "Medium shot from behind @Thanatos left shoulder (180° opposite angle). @Eris listens, growing fear in her eyes. She: 'Let them come.' Jaw tight. Steam still rises from her mug.", "duration": 4, "camera_movement": "static"}
]
```

---

## API curl 模板

### 生成角色
```bash
curl -s -X POST "${API}/api/cinema-studio/generate-character" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "<外貌 + 服装 + 标志特征>",
    "aspect_ratio": "16:9",
    "resolution": "2K",
    "project_id": "'"${PROJECT_ID}"'",
    "genre": "suspense"
  }'
```
返回 `{"task_id": null, "generation_id": "...", "status": "generating"}`。
**注意**:新版 API 返回的 `task_id` 多数情况下是 null。用 `generation_id`
轮询:`GET /generations/{generation_id}/status`。拿到 `generated_name` +
`image_urls[0]` 后进下一步。

### 生成地点(注意不传 `genre`)
```bash
curl -s -X POST "${API}/api/cinema-studio/generate-location" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "<地点 + 时间 + 环境特征>",
    "aspect_ratio": "16:9",
    "resolution": "2K",
    "project_id": "'"${PROJECT_ID}"'"
  }'
```

### 生成首帧(Scene,可能带 ref images)
```bash
curl -s -X POST "${API}/api/cinema-studio/generate-scene" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "<景别 + 角色姿态 + 构图 + 关键元素 + Style Lock>",
    "aspect_ratio": "16:9",
    "resolution": "2K",
    "project_id": "'"${PROJECT_ID}"'",
    "genre": "suspense",
    "ref_image_urls": ["<char_elem_url>", "<loc_elem_url>"]
  }'
```

### 角色造型变体(编辑模式)
```bash
# 用 is_edit=true 基于原始角色图修改服装 — 跳过 LLM 增强,保留人脸
curl -s -X POST "${API}/api/cinema-studio/generate-scene" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Same character, now wearing casual modern street clothes instead of the coat.",
    "ref_image_urls": ["<original character image URL>"],
    "is_edit": true,
    "aspect_ratio": "16:9",
    "resolution": "2K",
    "project_id": "'"${PROJECT_ID}"'"
  }'
```

---

## Element 两步注册(关键新流程)

### Step A:把 generation 晋升成 element(不触发注册)
```bash
curl -s -X POST "${API}/api/cinema-studio/elements" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "generation_id": "'"${CHAR_GEN_ID}"'",
    "name": "Eris",
    "description": "Female protagonist, dark energy wielder",
    "force": true
  }'
# → 返回 element_id,此时 kling_registration_status=null
```

### Step B:显式触发 Kling 注册
```bash
curl -s -X POST "${API}/api/cinema-studio/elements/${ELEMENT_ID}/register/kling" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "<element image URL from Step A>",
    "description": "Female protagonist, dark energy wielder"
  }'
# → kling_registration_status: null → registering
```

### Step C:轮询状态
```bash
curl -s "${API}/api/cinema-studio/elements" \
  -H "Authorization: Bearer ${TOKEN}" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for e in data['elements']:
    if e['id'] == '${ELEMENT_ID}':
        print(e['kling_registration_status'], e.get('kling_registration_error'))
"
# 每 5-10s 查一次,期望:registering → done
```

### Step D(可选):Review Modal 流程
如果 Step C 轮到 `needs_review`:
```bash
# 1. 读 kling_review_urls 拿 splitter 的候选(前端通常展示给用户选)
# 2. 让用户手动裁剪/选定 frontal / back / face_detail / extra
# 3. 提交确认:
curl -s -X POST "${API}/api/cinema-studio/elements/${ELEMENT_ID}/register/kling/confirm" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "frontal_url": "<user-approved frontal URL>",
    "back_url": "<user-approved back URL>",
    "face_detail_url": "<optional CU URL>",
    "extra_url": "<optional extra angle URL>",
    "description": "Eris, front+back+face detail"
  }'
```

### 地点 Element(简单,不会触发 review)
```bash
# 同 Step A + B,用 location 的 generation_id,splitter 用同一图当 frontal/refer
curl -s -X POST "${API}/api/cinema-studio/elements" ...
curl -s -X POST "${API}/api/cinema-studio/elements/${LOC_ELEMENT_ID}/register/kling" ...
```

---

## 视频生成(Multi-Shot)

**注意:Multi-shot 模式下顶层 `prompt` 和每个 shot 的 prompt 互斥。Kling 只
使用每个 shot 的独立 prompt,顶层 prompt 被忽略。每个 shot prompt 必须
自包含完整的场景信息。**

```bash
curl -s -X POST "${API}/api/cinema-studio/generate-video" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "placeholder — ignored in multi-shot mode",
    "first_frame_url": "'"${FIRST_FRAME_URL}"'",
    "cast_element_ids": ["'"${ERIS_ELEM}"'", "'"${THANATOS_ELEM}"'"],
    "multi_shots": true,
    "multi_prompt": [
      {"prompt": "<自包含 shot 1,~430 chars>", "duration": 5, "camera_movement": "static"},
      {"prompt": "<自包含 shot 2,~430 chars>", "duration": 5, "camera_movement": "dolly_in"},
      {"prompt": "<自包含 shot 3,~430 chars>", "duration": 5, "camera_movement": "zoom_in"}
    ],
    "video_genre": "suspense",
    "speed_ramp": "auto",
    "aspect_ratio": "16:9",
    "resolution": "720p",
    "tier": "standard",
    "negative_prompt": "no text, no watermarks, no duplicate limbs, no closed eyes in dialogue",
    "video_provider": "kling",
    "project_id": "'"${PROJECT_ID}"'"
  }'
```

### 1080p 终片
```json
{
  "resolution": "1080p",
  "tier": "pro",
  ...
}
```
成本从 17 credits/s(standard 720p 无声)涨到 22 credits/s(pro 1080p 无声)。
Sound ON 再叠加 (+25 credits/s standard / +34 credits/s pro)。

### 单镜头长 take(不用 multi-shot)
```bash
curl -s -X POST "${API}/api/cinema-studio/generate-video" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "<≤2500 chars 完整描述>",
    "first_frame_url": "'"${FIRST_FRAME_URL}"'",
    "last_frame_url": "'"${LAST_FRAME_URL}"'",
    "cast_element_ids": ["'"${ERIS_ELEM}"'"],
    "duration": 10,
    "camera_movement": "dolly_in",
    "video_genre": "suspense",
    "speed_ramp": "auto",
    "aspect_ratio": "16:9",
    "resolution": "720p",
    "tier": "standard",
    "negative_prompt": "no text, no watermarks",
    "video_provider": "kling",
    "project_id": "'"${PROJECT_ID}"'"
  }'
```
**注意**:`last_frame_url` 和 `camera_movement` 参数底层互斥 — Kling 会
忽略 `camera_movement`。想用精确运镜就只给 `first_frame_url`。

---

## 尾帧提链(Continuous Clip)

**不再用 ffmpeg!** 直接调官方 `/extract-frame`。

```bash
# 1. 前一 clip 的 video generation_id(不是 task_id)
PREV_VIDEO_GEN_ID="..."

# 2. 提取尾帧 — 返回一个新的 scene generation
RESULT=$(curl -s -X POST "${API}/api/cinema-studio/generations/${PREV_VIDEO_GEN_ID}/extract-frame" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"which": "last"}')

# 3. 解析返回的 scene generation,取 image_urls[0] 作为下一 clip 的 first_frame_url
TAIL_FRAME_URL=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['image_urls'][0])")

# 4. 用作下一 clip 的首帧
#    POST /generate-video  first_frame_url=${TAIL_FRAME_URL}  ...
```

**首帧提取**(偶尔用于"倒放开场"之类):
```bash
curl ... -d '{"which": "first"}'
```

---

## 任务状态轮询(关键:用 generation_id,不是 task_id)

新版 API 返回的 `task_id` 多数情况下为 null。**正确的轮询端点是 `GET
/generations/{generation_id}/status`**。

```bash
# 每 10s(图片) / 15s(视频)查一次。character 可能 2-5 分钟,耐心等
while true; do
  STATUS=$(curl -s "${API}/api/cinema-studio/generations/${GEN_ID}/status" \
    -H "Authorization: Bearer ${TOKEN}")
  echo "$STATUS"
  # 返回 {"status": "generating|done|failed", "image_urls": [...],
  #       "video_url": "...", "error": "kling.xxx",
  #       "generated_name": "...", "credit_cost": N}
  if echo "$STATUS" | grep -qE '"status":"(done|failed)"'; then break; fi
  sleep 15
done
```

**Legacy 端点**(不要用):`GET /tasks/{task_id}` — 仅为向后兼容保留,
新版 `task_id` 多为 null。

## 列 project 的所有 generation

```bash
curl -s "${API}/api/cinema-studio/projects/${PROJECT_ID}/generations" \
  -H "Authorization: Bearer ${TOKEN}"
# 返回 {"generations": [{id, mode, status, image_urls, video_url, ...}, ...]}
```

---

## 本地素材上传

```bash
# 把本地图 / 草图上传到 S3,拿到 URL
curl -s -X POST "${API}/api/cinema-studio/upload" \
  -H "Authorization: Bearer ${TOKEN}" \
  -F "file=@/path/to/local.png" \
  -F "project_id=${PROJECT_ID}"
# → {"url": "https://cdn.../path.png"}
# 后台会自动生成 .webp sibling,直接用返回的 URL 即可
```

---

## 地点多角度 manifest 结构

一个地点只注册一个 EWS 母版做 element,其他角度变体存 manifest 当 ref 用。

```json
{
  "id": "LOC_1",
  "name": "Brooklyn Alley",
  "element_id": "<EWS 母版的 element ID>",
  "kling_element_id": 12345,
  "kling_registration_status": "done",
  "ews_master": "<EWS 母版 URL — 已注册为 element>",
  "ms_left": "<左角变体 URL — 不注册,仅用作 ref_image_urls>",
  "ms_right": "<右角变体 URL — 不注册,仅用作 ref_image_urls>"
}
```

---

## 21:9 裁剪(剧集片尾 / 院线比例)

```bash
curl -s -X POST "${API}/api/cinema-studio/crop-ultrawide" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"url": "<16:9 视频或图片 URL>"}'
# → {"url": "<21:9 裁剪后 URL>"}
```

---

## 真实参考案例

`denghuosanchang/`(wemio_skills 仓库内)是用早期版本 Kling 跑过一遍的
完整项目 — 角色 ref 图、storyboard 首帧、最终 MV 都在。读 `project.json`
+ `manifest` 可以看到一整条流水线的真实产物形态,对照本 skill 的 Phase
2-4 理解。注意:它用的是旧版单步注册 API,现在要按两步流程重新注册角色
element。

# Prompt & API Examples (Seedance)

> 按需参考。写 prompt、发 API 请求、排查问题时查阅。

所有路径前缀 `${API}/api/cinema-studio/`,Auth header 统一 `-H "Authorization: Bearer ${TOKEN}"`。

## Token 语法约定

Seedance 路径用 **`@图片N` 位置引用**。N 对应 `reference_image_urls` 列表的
**index + 1**:

```
reference_image_urls = [ELENA_URL, ARTHUR_URL, FACTORY_URL]
                          ↓          ↓           ↓
                        @图片1     @图片2      @图片3
```

**整部剧 reference_image_urls 顺序必须固定**,否则 clip 间角色错乱。
manifest.json 里存 `ref_map: {"图片1": "Elena 主角", "图片2": "Arthur 配角",
"图片3": "Factory 地点"}` 便于回查。

后端**不重写**这些 token — 直接透传给 Gemini LLM 扩写器和 Seedance。Kling
skill 里 `@素材N` 会被重写成 `<<<element_N>>>`,Seedance 的 `@图片N` 不改
(Seedance 天然理解)。

## 首帧 Prompt 示例(给 fl2v 模式 / ref2v 可选起始构图用)

**Action 起势(跑动前一瞬):**
```
Wide shot of Elena crouched on wet rooftop edge at night, rain lashing,
neon haze behind her. Left hand pressed to gravel, right hand steadying
on knee. Body tilted slightly forward, weight shifted to toes. About to
explode into a run. Rule of thirds: Elena at right third, city lights
filling left two-thirds. Cinematic handheld realism, visible grain.
```

**对白开场(两角色对峙):**
```
Medium shot of Arthur and Elena facing each other in abandoned factory
interior at dusk. Amber dust shafts between them. Arthur at left third,
hands in windbreaker pockets, facing right. Elena at right third, arms
crossed, facing left. Cracked concrete floor. Cinematic handheld realism,
visible grain.
```

## Video Prompt 示例(Seedance 15s 内部多镜头)

**关键认知:** Seedance 单次 `/generate-video`(≤15s)**在模型内部会自主
切镜头** — 用 prompt 文字描述多个 shot,Seedance 按时序剪开。
**不要用** Phoenix 的 `multi_shots` / `multi_prompt` 字段(那是 Kling
走的路径)。

**精品剧做法:每 clip 顶 15s,内部 2-3 shot,把戏剧单元打包好。**

**单 shot 示例(简单动作戏):**

**简陋版(不够 — Seedance 会自己瞎发挥):**
`"@图片1 fights @图片2"`

**丰富版(推荐 — 动作片 6-8s,ref2v):**
```
Intense hand-to-hand combat on rain-soaked rooftop. @图片1 ducks under
@图片2's high kick, pivots on left foot, counter-strikes with a spinning
elbow to @图片2's shoulder. @图片2 staggers back two steps, catches
balance, wipes rain from face with back of hand, readies for next
exchange. Camera follows behind @图片1 handheld, rapid low-angle push-in
on the elbow impact. Water splashes on each heel-plant. Thunder in the
distance. Cinematic handheld realism, visible grain.
```

**每个 Seedance shot prompt 5 层信息:**
1. **运动物理** — 重心、惯性、布料、水花、撞击(**放最前面**)
2. **运镜** — "camera follows behind handheld, low-angle push-in"(写文字,
   没有参数)
3. **角色动作** — 用 `@图片N` 引用角色,动词序列
4. **对白**(如有) — `@图片1 says: "..."`,Seedance 自动生成口型
5. **环境 / 声音 / 质感** — 雨声、雷、脚步、回音 + 末尾 style lock

**对白长单镜头(8s,带 lip-sync):**
```
Medium shot inside dimly-lit interrogation room. @图片1 slowly leans
across the table, fingers drumming twice on the folder, locks eyes with
@图片2. @图片1 says: "You better start from the top." Voice low and
measured. @图片2 stiffens, hands clench, looks down, avoids eye contact.
Single bare bulb flickers overhead. Cinematic handheld realism.
```

---

**⭐ 推荐模式:15s 内部多镜头(精确运镜术语驱动)**

Seedance 2.0 精品剧打开方式 — 一次 15s 的 `/generate-video` 里,
**每个内部 shot 用一个 camera-vocabulary 里的精确运镜术语起头**,
自然时序连接 2-3 个 shot。

### 用精确运镜名词(电影感核心杠杆)

**❌ 泛泛形容(第一版错误示例):**
```
Camera STARTS WIDE showing the empty station, THEN camera slowly dollies
in to a MEDIUM SHOT, FINALLY a new WIDE ANGLE as the train arrives.
```
这种泛泛描述,Seedance 2.0 给的是 generic AI 风,不是电影感。

**✅ 精确运镜命名(推荐):**
```
Subway platform at 2am, practical light from flickering fluorescent
tubes, cool teal shadows on wet tile.

后退揭示镜头: @图片1 stands on the right third of frame, checking
wristwatch, breath visible in cold air. The frame slowly expands to
reveal the empty platform stretching behind him, trains of motion in
distance.

Then 遮挡转场镜头 as he lowers his wrist — 列车 from LEFT side of
frame glides into station, headlights sweeping across wet tiles,
刹车 hissing with white steam, doors hissing open on the left.

Maintain 180° axis throughout — train always on LEFT, @图片1 always on
RIGHT. Cinematic handheld realism, 35mm film grain, desaturated
teal-amber grade.
```

每个 shot 用一个具体命名的运镜术语(后退揭示镜头 / 遮挡转场镜头),
Seedance 2.0 在 training 里学过这些名词的具体语义,调用精准。

### 几个 clip-级 prompt 示例(按戏剧类型选运镜)

**悬疑对白(clip 15s,3 shot):**
```
Dimly-lit interrogation room, one bare bulb flickering overhead,
practical key light carving cheekbones.

推进亲密镜头: @图片1 slowly leans across the metal table toward
@图片2 at right third of frame. "You better start from the top."
Voice low, measured.

Then 压迫俯拍镜头 on @图片2: hands clench on lap, eyes avoid direct
contact, jaw tightens.

Finally 眼抖特写镜头 on @图片2's pupils — high-frequency micro-tremor
betraying held breath.

Maintain 180° axis (@图片1 LEFT / @图片2 RIGHT). Cinematic handheld
realism, 35mm grain.
```

**动作打斗(clip 15s,3 shot):**
```
Rain-soaked rooftop at night, pink and teal neon reflected in puddles,
hard rim-light on wet leather.

打斗跟随镜头: @图片1 (right third) ducks under @图片2's (left third)
high kick, pivots on left foot, counter-strikes with spinning elbow.

Then 格挡震动镜头 at impact — single violent frame shake, water
sheet-sprays off the strike.

Finally 子弹时间镜头: @图片2 suspended mid-stagger, camera orbits 90°
around the frozen tableau, raindrops hang motionless.

Maintain 180° axis. Cinematic handheld realism, high-contrast key,
35mm grain.
```

**情感反应(clip 15s,3 shot):**
```
Empty living room at 3am, single lamp spilling warm amber across the
hardwood floor, rest of frame in blue-black shadow.

凝视长镜头: @图片1 sits motionless on the couch, right side of frame,
looking down at a letter held in both hands. Fifteen seconds of absolute
stillness.

Then 瞳孔放大镜头: extreme eye macro, pupils dilate fractionally as
something registers.

Finally 后退疏远镜头: camera slowly retreats, @图片1 shrinking in the
vast dark room, lamp fading, one tear visible at the eye's edge.

Cinematic handheld realism, 35mm grain, dominant practical amber +
deep blue-black shadows.
```

### 写法要点(精确运镜版)

1. **从 `camera-vocabulary.md` 挑具体运镜术语** — 这是核心杠杆,不是可选项
2. **每个 shot 配 1 个运镜** — 叠加 2-3 个 Seedance 会听不清
3. **用自然时序连接**:`Then...`、`Finally...`、`紧接着...`、`as he turns...`
   —— Seedance 2.0 认识这种过渡语
4. **`[0s-Xs]` 时间戳是可选**,不是必写(有些第三方 guide 硬推,用户社区
   实战反馈:精确运镜术语 + 自然时序足够,时间戳偶尔让模型死板按秒剪)
5. **空间轴必须反复强调**:`LEFT / RIGHT / 180° axis maintained` —
   不写就断轴
6. **lighting 是高杠杆** — 一行写好的 lighting(practical light / rim-light /
   key + fill + back 描述)= 十个形容词

**转场 fl2v 示例(5s,首帧夜市 → 尾帧公寓):**
```
Smooth dissolve from neon-lit Tokyo alley in the rain to the same
character standing alone in a dark Bushwick apartment kitchen by morning
light. Rain fades, neon fades, replaced by dust motes in a single shaft
of cool morning sun. The character's pose carries through the transition.
```
(fl2v 模式下不传 reference_image_urls,一致性靠首尾帧承载)

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
    "genre": "action"
  }'
```
返回 `{"task_id": null, "generation_id": "...", "status": "generating"}`。
**用 `generation_id`** 轮询:`GET /generations/{generation_id}/status`。

### 生成地点
```bash
curl -s -X POST "${API}/api/cinema-studio/generate-location" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "<地点 + 时间 + 环境>",
    "aspect_ratio": "16:9",
    "resolution": "2K",
    "project_id": "'"${PROJECT_ID}"'"
  }'
```

### 生成首帧(Scene,with ref images)
```bash
curl -s -X POST "${API}/api/cinema-studio/generate-scene" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "<景别 + 角色姿态 + 构图 + 关键元素 + Style Lock>",
    "aspect_ratio": "16:9",
    "resolution": "2K",
    "project_id": "'"${PROJECT_ID}"'",
    "genre": "action",
    "ref_image_urls": ["<char_url>", "<loc_url>"]
  }'
```

### 角色造型变体(编辑模式)
```bash
curl -s -X POST "${API}/api/cinema-studio/generate-scene" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Same character, now wearing wet black raincoat over the gray shirt.",
    "ref_image_urls": ["<original character URL>"],
    "is_edit": true,
    "aspect_ratio": "16:9",
    "resolution": "2K",
    "project_id": "'"${PROJECT_ID}"'"
  }'
```

---

## Element 两步注册(Seedance 版)

### Step A:把 generation 晋升成 element(不触发注册)
```bash
curl -s -X POST "${API}/api/cinema-studio/elements" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "generation_id": "'"${CHAR_GEN_ID}"'",
    "name": "Elena",
    "description": "Female protagonist, action lead",
    "force": true
  }'
# → 返回 element_id,此时 seedance_registration_status=null
```

### Step B:显式触发 Seedance 合规注册
```bash
curl -s -X POST "${API}/api/cinema-studio/elements/${ELEMENT_ID}/register/seedance" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "<element image URL from Step A>",
    "description": "Female protagonist, action lead"
  }'
# → seedance_registration_status: null → registering
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
        print(e['seedance_registration_status'], '|', e.get('seedance_registration_error'))
"
# 每 5-10s 查一次,最多 3 分钟。期望:registering → done
# (没有 needs_review 状态,Seedance 单图合规要么过要么不过)
# (volcanic_asset_id 不在返回里,只在后端 DB;确认 status==done 就够了)
```

**Seedance 注册和 Kling 的关键区别:**
- 单图合规检查,**没有三面图拆分**,**没有 needs_review** 状态
- 失败码是 `ark.*`(Kling 是 `kling.*`)
- 成功后后端写的字段是 `volcanic_asset_id` + `volcanic_asset_group_id`
  (注意:不在 `/elements` API 响应里,只在后端 DB)

---

## 合规库登记(Seedance 专属前置步骤,Kling 不需要)

**每张将用作 `first_frame_url` / `last_frame_url` / `reference_image_urls`
的图 URL,都要先进合规库**,否则 Ark 生成时会拒 `real_person` 等错误码。
`/register/seedance` 只绑定 element 和 asset_id,**不代替**合规库登记。

### Step 1:提交合规检查
```bash
# 注意前缀!是 /api/compliance/ 不是 /api/cinema-studio/
curl -s -X POST "${API}/api/compliance/check-by-url" \
  -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" \
  -d "{\"file_url\":\"${IMAGE_URL}\"}"
# → {"asset_id":"...","status":"pending","ark_asset_id":null,"error":null,"checked_at":null}
# → 如果 404 "Asset not found for URL",先建 Asset(Step 1b)
```

### Step 1b(若 Step 1 返回 404):手动注册 Asset
```bash
# generate-scene 产出的首帧 URL / /upload 的图 URL 不自动建 Asset,要手动
curl -s -X POST "${API}/api/assets/register-url" \
  -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" \
  -d "{\"file_url\":\"${IMAGE_URL}\",\"asset_type\":\"image\",\"source_type\":\"cinema_scene\"}"
# → {"id":"...","file_url":"...","seedance_status":"unchecked",...}
# 然后回到 Step 1 再 check-by-url
```

**不需要手动建 Asset 的 URL**(自动有 Asset 行):
- `generate-character` 输出
- `generate-location` 输出
- `/extract-frame` 输出

**需要手动建 Asset 的 URL**:
- `generate-scene`(首帧)输出
- `/upload` 上传的图

### Step 2:轮询到 compliant
```bash
for i in $(seq 1 20); do
  sleep 10
  S=$(curl -s "${API}/api/compliance/status/${ASSET_ID}" \
    -H "Authorization: Bearer ${TOKEN}")
  echo "$S"
  if echo "$S" | grep -qE '"status":"(compliant|failed)"'; then break; fi
done
# 期望:pending → compliant(通常 30-90s,最多 3 分钟)
```

### 失败处理
- `ark.face_policy`:图疑似真人 / 敏感主体 → 换风格化角色图
- `ark.invalid_resolution`:分辨率不够 → 重生成 2K
- `ark.content_policy`:内容违规 → 改 prompt 重生成
- `ark.timeout`:合规超时 → 稍后重试

### 什么时候跑合规库
- **Phase 2 Step 7 之后**:所有 character / location element 图过一遍
- **Phase 3 首帧生成后**:每个首帧 URL 过一遍
- **Phase 4 extract-frame 后**:尾帧 URL 用作下一 clip 首帧前过一遍
- **简言之:任何要传给 `/generate-video` 作 frame / ref 的图,都要过**

---

## 视频生成

### 模式 1:ref2v 多图参考一致性(默认,推荐)
```bash
curl -s -X POST "${API}/api/cinema-studio/generate-video" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"prompt\": \"<完整 ≤2500 chars prompt with @图片N refs>\",
    \"reference_image_urls\": [\"${ELENA_URL}\", \"${ARTHUR_URL}\", \"${FACTORY_URL}\"],
    \"first_frame_url\": \"${FIRST_FRAME_URL}\",
    \"duration\": 5,
    \"sound\": true,
    \"video_genre\": \"action\",
    \"aspect_ratio\": \"16:9\",
    \"resolution\": \"480p\",
    \"model\": \"seedance-2.0-fast\",
    \"video_provider\": \"ark\",
    \"project_id\": \"${PROJECT_ID}\"
  }"
```

**注意**:
- 不传 `multi_shots` / `multi_prompt` / `cast_element_ids` / `negative_prompt` /
  `camera_movement`(作为枚举值)— Seedance 这些全忽略
- `first_frame_url` 可选,不传就 Seedance 自由开场
- `sound: true` 默认开,后端映射到 Ark 的 `generate_audio`
- prompt 里每个 `@图片N` 对应 `reference_image_urls[N-1]`

### 模式 2:fl2v 首尾帧插值(转场 / 精确起止)
```bash
curl -s -X POST "${API}/api/cinema-studio/generate-video" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"prompt\": \"<≤2500 chars,描述 A 到 B 的过渡>\",
    \"first_frame_url\": \"${START_URL}\",
    \"last_frame_url\": \"${END_URL}\",
    \"duration\": 5,
    \"sound\": true,
    \"aspect_ratio\": \"16:9\",
    \"resolution\": \"480p\",
    \"model\": \"seedance-2.0-fast\",
    \"video_provider\": \"ark\",
    \"project_id\": \"${PROJECT_ID}\"
  }"
```
**fl2v 互斥规则**:此模式下就算你传 `reference_image_urls` / `ref_video_urls`
/ `ref_audio_urls` 都会被后端丢弃。

### 模式 3:ref_video_urls 参考视频做 motion 模仿

> **⚠️ ref_video_urls 真实成本很高,默认不要用。** 添加参考视频会在后端
> 触发额外计费维度(credit_cost 字段不一定反映,但对账时用户实际成本上涨
> 明显)。**只在剧本明确要求 motion 模仿 / style transfer 且没有替代方案
> 时才用。** 大部分动作场景靠 prompt 描述 + 静态参考图就够了。

```bash
curl -s -X POST "${API}/api/cinema-studio/generate-video" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"prompt\": \"@图片1 performs the same sequence of movements as the reference video.\",
    \"reference_image_urls\": [\"${ELENA_URL}\"],
    \"ref_video_urls\": [\"${DANCE_REF_VIDEO_URL}\"],
    \"duration\": 8,
    \"sound\": true,
    \"aspect_ratio\": \"16:9\",
    \"resolution\": \"480p\",
    \"model\": \"seedance-2.0-fast\",
    \"video_provider\": \"ark\",
    \"project_id\": \"${PROJECT_ID}\"
  }"
```
参考视频 ≤3 条,每条 2-15s。

### 模式 4:ref_audio_urls 参考音频(BGM / 对白节奏)
```bash
curl -s -X POST "${API}/api/cinema-studio/generate-video" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"prompt\": \"@图片1 moves with the rhythm of the reference beat, freestyle to camera.\",
    \"reference_image_urls\": [\"${CHAR_URL}\"],
    \"ref_audio_urls\": [\"${BEAT_URL}\"],
    \"duration\": 5,
    \"sound\": true,
    \"aspect_ratio\": \"16:9\",
    \"resolution\": \"480p\",
    \"model\": \"seedance-2.0-fast\",
    \"video_provider\": \"ark\",
    \"project_id\": \"${PROJECT_ID}\"
  }"
```
**关键**:`ref_audio_urls` 必须**同时**有至少 1 张 image 或 1 个 video
作视觉锚点,否则 Ark 会拒。

### 模式 5:对白 + 口型同步
```bash
curl -s -X POST "${API}/api/cinema-studio/generate-video" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"prompt\": \"Medium shot of @图片1 leaning across a metal interrogation table. @图片1 says: 'You better start from the top.' Voice low and measured. Bare bulb flickers.\",
    \"reference_image_urls\": [\"${DETECTIVE_URL}\"],
    \"first_frame_url\": \"${FIRST_FRAME_URL}\",
    \"duration\": 5,
    \"sound\": true,
    \"aspect_ratio\": \"16:9\",
    \"resolution\": \"480p\",
    \"model\": \"seedance-2.0-fast\",
    \"video_provider\": \"ark\",
    \"project_id\": \"${PROJECT_ID}\"
  }"
```
`@图片N says: "台词"` — Seedance 自动音素级 lip-sync 生成对应口型和声音。
中文台词也支持(`@图片1 说:"..."`)。

---

## 尾帧提链(Continuous Clip)

**`/extract-frame` 是 provider 无关的**,Seedance 视频同样可以用。

```bash
PREV_VIDEO_GEN_ID="..."
RESULT=$(curl -s -X POST "${API}/api/cinema-studio/generations/${PREV_VIDEO_GEN_ID}/extract-frame" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"which": "last"}')
TAIL_FRAME_URL=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['image_urls'][0])")
# 用作下一 clip 的 first_frame_url(ref2v 模式里保持 reference_image_urls 不变)
```

**注意**:extract-frame 会在 project 下创建一个新的 `mode: "scene"`
generation(`credit_cost: 0`,免费),有自己的 `id`。返回体顶层的
`image_urls[0]` 就是首/尾帧 URL,其他字段同普通 scene generation。这个
scene 也会出现在 `GET /projects/{id}/generations` 列表里。

---

## 任务状态轮询(关键:用 generation_id)

```bash
while true; do
  STATUS=$(curl -s "${API}/api/cinema-studio/generations/${GEN_ID}/status" \
    -H "Authorization: Bearer ${TOKEN}")
  echo "$STATUS"
  if echo "$STATUS" | grep -qE '"status":"(done|failed)"'; then break; fi
  sleep 15
done
# 返回 {"status": "...", "image_urls": [...], "video_url": "...", "error": "ark.xxx", ...}
# 注意:credit_cost 在此端点永远是 null,要查扣费得调 list 端点
```

## 列 project 的所有 generation(含 credit_cost)

```bash
curl -s "${API}/api/cinema-studio/projects/${PROJECT_ID}/generations" \
  -H "Authorization: Bearer ${TOKEN}"
```

---

## 本地素材上传

```bash
curl -s -X POST "${API}/api/cinema-studio/upload" \
  -H "Authorization: Bearer ${TOKEN}" \
  -F "file=@/path/to/local.png" \
  -F "project_id=${PROJECT_ID}"
# → {"url": "https://cdn.../path.png"}
# 后台自动生成 .webp sibling,直接用返回的 URL
```

支持上传图片 / 视频 / 音频(用于 Seedance 的 ref_video_urls / ref_audio_urls
模式)。

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

## Manifest 结构建议

```json
{
  "project_id": "...",
  "studio_mode": "cinema",
  "video_model": "seedance-2.0-fast",
  "video_resolution": "480p",
  "aspect_ratio": "16:9",
  "style_lock": "cinematic handheld realism, visible grain",
  "ref_map": {
    "图片1": {"name": "Elena", "element_id": "...", "url": "...", "compliance_asset_id": "..."},
    "图片2": {"name": "Arthur", "element_id": "...", "url": "...", "compliance_asset_id": "..."},
    "图片3": {"name": "Factory", "element_id": "...", "url": "...", "compliance_asset_id": "..."}
  },
  // compliance_asset_id: 从 POST /api/compliance/check-by-url 返回的 asset_id,
  // 不是后端 Ark 的 volcanic_asset_id(后者不暴露)
  "clips": [
    {
      "id": "c1",
      "mode": "ref2v",
      "transition_from_prev": "scene_jump",
      "duration": 5,
      "first_frame_gen_id": "...",
      "video_gen_id": "...",
      "video_url": "...",
      "credit_cost": 85
    }
  ]
}
```

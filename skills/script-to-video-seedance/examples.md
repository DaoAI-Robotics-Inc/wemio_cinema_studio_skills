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

## Video Prompt 示例(Seedance 单镜头)

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
- 成功后写的字段是 `volcanic_asset_id` + `volcanic_asset_group_id`(不是
  `kling_element_id`)

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
    "图片1": {"name": "Elena", "element_id": "...", "url": "...", "volcanic_asset_id": "..."},
    "图片2": {"name": "Arthur", "element_id": "...", "url": "...", "volcanic_asset_id": "..."},
    "图片3": {"name": "Factory", "element_id": "...", "url": "...", "volcanic_asset_id": "..."}
  },
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

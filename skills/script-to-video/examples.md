# Prompt & API Examples

> 按需参考。写 prompt 时查阅具体格式和示例。

## 首帧 Prompt 示例

**ECU, zoom_in (eyes snap open):**
```
Extreme close-up of a face filling the frame. {CHAR_LOCK}. Eyes shut, 
brow furrowed in unconscious tension, lips parted. Rain droplets on 
eyelashes and cheeks. One hand visible at bottom of frame pressing 
against wet concrete. Face positioned on right third, leaving space 
left for zoom push.
```

**MS reverse, static (character appears behind another):**
```
Medium shot from behind @Eris right shoulder (over-shoulder framing). 
She stands tensed on wet street, fists half-clenched. In front of her, 
a figure steps from an impossibly deep shadow — @Thanatos, tall, 
silver-white hair, black overcoat. Background: Brooklyn street, rain, 
distant car headlights. Rule of thirds: Eris at left third, Thanatos 
at right third.
```

## Video Prompt 示例

**简陋版（不够）：**
`"@Thanatos makes coffee. @Eris watches."` ← Kling 无法推断环境、氛围、细节

**丰富版（推荐 — ~450 chars）：**
```
Shabby but spotless apartment kitchen above a Bushwick grocery store. Morning 
sunlight filters through grimy windows, casting long shadows across the counter. 
@Thanatos stands at the stove making coffee with unnaturally precise movements, 
like someone who recently learned to use a kitchen. @Eris watches from the 
doorway in borrowed clothes too large for her, arms crossed, one hand resting 
near the seal on her chest. Steam curls from the mug. The air conditioner hums 
faintly. Quiet, heavy tension between them.
```

**每个 shot prompt 5 层信息：**
1. **环境** — 在哪？什么光线？
2. **视觉特效** — 发光/碎裂/超自然效果
3. **角色动作** — @Name 在做什么？
4. **对话** — @Name speaks: "台词"
5. **声音/质感** — 环境音、触感细节

## Multi-Shot 覆盖策略示例

**戏剧递进（3 shots — wide→medium→close）：**
```json
[
  {"prompt": "@Eris alone, tiny in vast dark alley. Rain hammering.", "duration": 5, "camera_movement": "drone"},
  {"prompt": "Golden veins pulse and flash under skin. @Eris pushes up, trembling.", "duration": 5, "camera_movement": "dolly_out"},
  {"prompt": "Chest seal emits intense gold light. @Eris hand hovers over it. Dread.", "duration": 5, "camera_movement": "dolly_in"}
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

## API curl 示例

### 生成角色
```bash
curl -s -X POST "${API}/api/cinema-studio/generate-character" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "<外貌 + 服装 + 标志特征>", "aspect_ratio": "16:9", "resolution": "2K", "project_id": "<id>", "genre": "<genre>"}'
```

### 生成地点
```bash
curl -s -X POST "${API}/api/cinema-studio/generate-location" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "<地点 + 时间 + 环境特征>", "aspect_ratio": "16:9", "resolution": "2K", "project_id": "<id>"}'
```

### 生成首帧
```bash
curl -s -X POST "${API}/api/cinema-studio/generate-scene" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "<景别 + 角色姿态 + 构图 + 关键元素>", "aspect_ratio": "16:9", "resolution": "2K", "project_id": "<id>", "ref_image_urls": [...]}'
```

### 生成视频（Multi-Shot）
```bash
curl -s -X POST "${API}/api/cinema-studio/generate-video" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "<丰富的场景描述 with @CharacterName>",
    "first_frame_url": "<url>",
    "cast_element_ids": ["<element_ids>"],
    "multi_shots": true,
    "multi_prompt": [
      {"prompt": "<action + event + emotion>", "duration": 5, "camera_movement": "zoom_in"},
      {"prompt": "<action + event + emotion>", "duration": 5, "camera_movement": "dolly_out"}
    ],
    "video_genre": "<genre>",
    "speed_ramp": "auto",
    "aspect_ratio": "16:9",
    "project_id": "<id>"
  }'
```

### 注册 Element
```bash
curl -s -X POST "${API}/api/cinema-studio/elements" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"generation_id": "<id>", "name": "<name, max 20 chars>", "force": true}'
```

### 尾帧提链
```bash
# 1. 下载上一个 clip 的视频
curl -sL "<prev_video_url>" -o /tmp/prev_clip.mp4

# 2. ffmpeg 提取尾帧
ffmpeg -sseof -1 -i /tmp/prev_clip.mp4 -vsync 0 -q:v 2 -update true /tmp/last_frame.png -y 2>/dev/null

# 3. 上传尾帧
UPLOAD=$(curl -s -X POST "${API}/api/cinema-studio/upload" \
  -H "Authorization: Bearer ${TOKEN}" \
  -F "file=@/tmp/last_frame.png")
TAIL_FRAME_URL=$(echo "$UPLOAD" | python3 -c "import sys,json; print(json.load(sys.stdin)['url'])")
```

### 角色造型变体
```bash
# 用编辑模式基于原始角色图修改服装（is_edit=true 跳过 LLM 增强）
curl -s -X POST "${API}/api/cinema-studio/generate-scene" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Same character, now wearing casual clothes.", "ref_image_urls": ["<原始角色图URL>"], "is_edit": true, "aspect_ratio": "16:9", "resolution": "2K", "project_id": "<id>"}'
```

## 地点多角度 manifest 结构
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

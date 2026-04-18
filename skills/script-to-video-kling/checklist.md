# Director's Review Checklist (Kling)

> 在提交任何生成请求之前,用以下清单逐项检查。跳过检查是产出质量差的首要原因。

## Phase 1 检查:剧本分析

| # | 检查项 | 通过标准 | 常见错误 |
|---|---|---|---|
| 1.1 | 每个场景是否标注了情绪节拍? | 每个 beat 有明确的情绪词 | 只写了"发生了什么",没写"观众感受什么" |
| 1.2 | 是否找到了每个场景的转折点? | 转折点有对应的 ECU/zoom 时刻 | 所有 shot 平铺直叙没有高潮 |
| 1.3 | Clip 分组是否符合叙事段落? | 同地点+同角色+连续动作=同 clip | 机械地按时长切割,不管叙事逻辑 |
| 1.4 | 景别是否有递进? | 每个 clip 内有 WS→MS→CU 或类似变化 | 所有 shot 都是同一个景别 |
| 1.5 | Clip 间过渡类型是否标注? | continuous/scene_jump/reaction 明确 | 没标注,执行时才发现不知道用尾帧还是新首帧 |
| 1.6 | 剧本类型是否适合 Kling? | 剧情/对白/长剧集/多集连贯 = 适合 | 硬核动作/极限运动占比高 → 考虑换 `script-to-video-seedance` |

## Phase 2 检查:Element 注册

| # | 检查项 | 通过标准 | 常见错误 |
|---|---|---|---|
| 2.1 | 是否走了两步注册? | 先 `POST /elements`,再 `POST /elements/{id}/register/kling` | 以为 `POST /elements` 就触发注册了(旧版行为) |
| 2.2 | 轮询状态到 `done` 了吗? | `kling_registration_status == "done"` 才能进 Phase 4 | 注册中就急着生视频,会报 `kling.element_not_found` |
| 2.3 | `needs_review` 是否进了 review modal? | 读 `kling_review_urls`,让用户手动选 frontal/back/face_detail | 直接 retry register,splitter 还是会判定可疑,死循环 |
| 2.4 | `failed` 后有没有读错误码? | `kling_registration_error` 命名空间码(如 `kling.invalid_resolution`) | 重新跑一遍不看原因,同样的图再错一次 |
| 2.5 | `cast_element_ids` 是否是已注册 element 的 id? | UUID 字符串,不是 kling_element_id 整数 | 传错类型,422 |

## Phase 3 检查:首帧构图

| # | 检查项 | 通过标准 | 常见错误 |
|---|---|---|---|
| 3.1 | 景别是否匹配 clip 第一个 shot? | prompt 明确写了 "Extreme close-up" / "Wide shot" 等 | 没写景别,模型随机决定 |
| 3.2 | 构图是否为运镜留了空间? | dolly_in→wider 起始;dolly_out→tighter 起始 | CU 首帧 + dolly_in = 无处可推 |
| 3.3 | 是否是蓄力态(动作前一瞬)? | "eyes still shut"(即将睁开) | "eyes wide open"(动作已完成) |
| 3.4 | 角色是否在三分线位置? | 不在死中心(除非有意为之) | 角色居中,构图无张力 |
| 3.5 | 特效元素是否在首帧中预置? | 如果 shot 1 有发光特效,首帧应有微弱暗示 | 首帧完全没有特效痕迹,视频突然出现很突兀 |
| 3.6 | 多角色首帧是否传入了所有角色参考图? | `ref_image_urls` 包含每个出场角色的 element 图 + 地点 element 图 | 只传了主角参考,配角外观随机生成 |
| 3.7 | refs 是否 ≤ 4? | 最多 4 张 | 传 5 张只用前 4 张,期望的配角没被 ref |

## Phase 4 检查:视频 Prompt

| # | 检查项 | 通过标准 | 常见错误 |
|---|---|---|---|
| 4.1 | 特效是否在 prompt 最前面? | "Golden veins pulse..." 开头 | 特效放在句尾被 genre suffix 淹没 |
| 4.2 | prompt 是否足够丰富(~300-450 chars)? | 包含 5 层:环境+特效+动作/对话+质感+情绪 | 只写了 "makes coffee. watches."(太简短) |
| 4.2b | 是否有运镜/色调描述混入 prompt? | 没有 "camera catches", "slow push", "cold blue tones" | prompt 里写了运镜/色调(由参数控制) |
| 4.3 | 每个 shot 是否只表达一件事? | 一个 shot = 一个动作/一个特效/一个情绪变化 | 一个 shot 里塞了 5 件事 |
| 4.4 | 字符数是否安全? | 每个 multi-shot 的 shot prompt ≤ 430 chars(建议上限 500) | 超过 500 **不会**报错 — Kling 会静默截断,画面"断尾"才能察觉 |
| 4.5 | token 语法是否和 Phoenix UI 一致? | **优先位置 `@素材N`**(与前端 chip 默认形式一致);`@ElementName` 按名作为备选 | `@素材1/@素材2` 顺序没跟 cast_element_ids 对齐 → 错角色被引用 |
| 4.5b | cast_element_ids 顺序固定吗? | 整部剧从 Phase 1 就定住角色-位置映射(Elena=素材1, Arthur=素材2),任何 clip 不变 | 某一 clip 顺序颠倒 → 后续 prompt 全错乱 |
| 4.5c | manifest 里写清位置映射了吗? | manifest.json 有 `cast_map: {"素材1": "Elena", "素材2": "Arthur"}` | 只有一串 UUID,自己回头分不清谁是谁 |
| 4.6 | `cast_element_ids` 是否显式传? | 列表里是 element UUID | 以为 backend 会从 @mention 派生(旧版行为,已废) |
| 4.7 | multi-shot 是否避免了顶层 duration/camera_movement? | multi-shot 模式不传这两个顶层参数 | 传了 None 导致 422 |
| 4.8 | Clip 间过渡是否执行正确? | continuous → `/extract-frame`;scene_jump → 新首帧 | 全部用新首帧,丢失连续性 |
| 4.9 | negative_prompt 有没有用起来? | 对白戏 `"no closed eyes"`,古装 `"no modern clothing"` 等 | 全空,浪费了 Kling 独有优势 |
| 4.10 | `video_provider` 是否显式 `"kling"`? | 字段值 `"kling"` | 不传,走项目默认(可能被改成 ark) |
| 4.11 | `tier` 和 `resolution` 是否一致? | standard+720p / pro+1080p | pro+720p 或 standard+1080p 会被后端硬改,credit 被按高档扣 |

## 全局检查

| # | 检查项 | 通过标准 | 常见错误 |
|---|---|---|---|
| G.1 | Style Lock 是否全程逐字复用? | 所有首帧 prompt 末尾的风格描述完全一致 | 每次改写导致画风漂移 |
| G.2 | Character Lock 是否全程逐字复用? | 所有首帧 prompt 中角色描述完全一致 | 缩写或改写导致角色外观变化 |
| G.3 | video_genre 是否全集统一? | 同一集使用相同 genre | 随意切换 genre 导致色调不一致 |
| G.4 | 节奏是否有变化? | clip 时长不全是 15s — 有长有短 | 所有 clip 都是 15s,节奏单调 |
| G.5 | 依赖链是否正确? | continuous clip 串行;非 continuous 可并行 | 尾帧提链的 clip 被并行执行导致失败 |
| G.6 | continuous clip 是否使用了前序尾帧? | 用 `POST /generations/{prev_video_gen_id}/extract-frame` `{"which":"last"}` 拿到的 scene URL | ❌ 不要用 ffmpeg 本地提取;❌ 更不要为 continuous clip 生成独立首帧 |
| G.7 | 整部剧是否全程 Kling? | `video_provider: "kling"` 全程统一 | 中途切 seedance 导致色调/运动风格跳变(违反"一部剧一个模型") |
| G.8 | 所有输入都上传到了 S3? | `first_frame_url` / `ref_image_urls` 都是 `https://...` | 传本地路径或 `blob:` URL 会被 Pydantic validator 拒 |
| G.9 | aspect_ratio 是否全片一致? | 所有 generate-* 调用都用 Phase 0 确立的 `${ASPECT_RATIO}` | 某个 clip 随手换成 9:16 → 最终剪辑时拼接撕裂 |
| G.10 | video resolution 和 tier 是否配对? | 720p+standard 或 1080p+pro | 720p+pro(白花钱) / 1080p+standard(被后端强改为 720p) |
| G.11 | 整部剧 resolution 是否统一? | 所有 clip 都是同一 resolution/tier | 样片用 720p、正片用 1080p,两边色彩空间不同会有轻微 drift |

## Error Handling 检查

| # | 检查项 | 通过标准 |
|---|---|---|
| E.1 | 读到的错误是不是命名空间码? | `kling.invalid_resolution` / `kling.content_policy` 等 |
| E.2 | 按错误码走补救流程了吗? | 参考 SKILL.md 的 Error Handling 表 |
| E.3 | 失败的 generation 是不是自动退了 credit? | 不需要手动退,`finalize_failed_bg` 会处理 |
| E.4 | 同一个 element 连续两次 `failed` 是不是换图/换描述了? | 同样的图同样的错,不要重试 |

## 三轮生成策略(LLM 自查自纠)

**不要依赖一次生成就得到完美结果。** 用三轮调用让 LLM 自己审查和修正。

### 第一轮:生成计划
- 输入:System prompt + 剧本 + 目标时长
- 输出:完整的 JSON 生产计划(含每个 clip 的 `transition_from_prev`、
  `cast_element_ids`、每个 shot 的 `camera_movement` + `prompt`)

### 第二轮:自我审查
- 输入:第一轮的 JSON + 原始剧本原文
- 检查:角色准确性、完整性、prompt 质量、Kling API 约束(char budget
  500 / ref 图 ≤4 / cast_element_ids 必须 done / multi-shot 不传顶层
  duration 等)、结构

### 第三轮:修正
- 输入:错误列表 + 第一轮 JSON
- **只改内容不改结构**(R3 容易顺带重构 schema,必须在 prompt 里强调)

成本:三轮 ~$0.25,准确率从 8.5 提升到 9.5+。

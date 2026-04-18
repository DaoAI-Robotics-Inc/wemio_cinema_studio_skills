# Director's Review Checklist (Seedance)

> 在提交任何生成请求之前,用以下清单逐项检查。

## Phase 1 检查:剧本分析

| # | 检查项 | 通过标准 | 常见错误 |
|---|---|---|---|
| 1.1 | 剧本类型是否适合 Seedance? | 动作 / 运动 / 物理 / MV / 短视频 / 中文原生 prompt = 适合 | 对白密集 / 需要多镜头叙事切换 → 换 `script-to-video-kling` |
| 1.2 | 每 clip 是否能在 ≤15s 单镜头内完成一个戏剧单元? | 有起势→动作高潮→落势 | 硬要多景别切换放进一个 clip,Seedance 会乱(它没 multi-shot) |
| 1.3 | Clip 间过渡类型是否标注? | continuous / scene_jump / angle_change / reaction 明确 | 没标 → 执行时不知该走尾帧提链还是新首帧 |
| 1.4 | 每个 clip 的 mode 是否决定? | `ref2v` 或 `fl2v` 二选一 | 两种都塞 → fl2v 赢,ref_* 被丢弃 |
| 1.5 | 整片 Style Lock 一句是否定下? | 所有首帧 prompt 末尾逐字复用 | 风格描述漂移,跨 clip 画面跳变 |

## Phase 2 检查:Seedance 注册

| # | 检查项 | 通过标准 | 常见错误 |
|---|---|---|---|
| 2.1 | 是否走了两步注册? | 先 `POST /elements`,再 `POST /elements/{id}/register/seedance` | 以为 `POST /elements` 就触发注册了 |
| 2.2 | 轮询状态到 `done` 了吗? | `seedance_registration_status == "done"` 且 `seedance_registration_error == null`(最多轮询 3 分钟)| 注册中就急着生视频,Seedance 看到原始 URL 可能拒 |
| 2.3 | 失败后读了 `seedance_registration_error` 吗? | 命名空间码 `ark.face_policy` 等 | 不看原因盲目重试 |
| 2.4 | 角色图是不是"太像真人"? | 风格化 / 明显 AI 感 | 真实人脸 → `ark.face_policy` 拒 |
| 2.5 | 每个要用的参考图都注册了吗? | 每个 element 的 `seedance_registration_status == "done"` | 未注册的图会被降级成 plain URL 传 Ark,可能被拒 |
| 2.6 | **每张图进合规库了吗?** | 所有将作 frame / ref 的 URL 都 `POST /api/compliance/check-by-url` 并轮询到 `compliant`(character / location / scene 首帧 / extract-frame 尾帧,全部) | 没进合规库 → 生成时 `real_person` 等拒 |
| 2.7 | fl2v 帧图是不是无人景? | 纯环境 / 空镜 / 物体 | fl2v 帧图有写实人物就算合规过也会被拒(实测);角色转场改走 ref2v 或尾帧提链 |

## Phase 3 检查:首帧构图

| # | 检查项 | 通过标准 | 常见错误 |
|---|---|---|---|
| 3.1 | ref2v clip 是否一定要首帧? | 不一定。精确要求开场才给,否则让 Seedance 从 refs 自由开局 | 所有 clip 都强行做首帧,浪费 credit 且限制 Seedance 发挥 |
| 3.2 | fl2v clip 是否同时有首+尾帧? | 两帧都给 | 只给首帧 → 后端路由到 ref2v(首帧 + refs),不是你想要的首尾插值 |
| 3.3 | continuous clip 是否用前序尾帧? | `/extract-frame` `which=last` 拿到 URL → **过一遍合规库** → 做 `first_frame_url` | 尾帧没过合规 → 生成时 `real_person` 拒 |
| 3.4 | 首帧构图是否为运动留空间? | 角色往右跑,首帧角色在左三分线 | 角色居中 → 运动方向两边都撞边 |
| 3.5 | 多角色首帧是否传入了所有角色 ref 图? | `ref_image_urls` 含所有出场角色 + 地点 | 只传主角,Seedance 乱生成配角 |

## Phase 4 检查:视频 Prompt

| # | 检查项 | 通过标准 | 常见错误 |
|---|---|---|---|
| 4.1 | 运动物理细节是否前置? | "weight transfers, splashes, impact" 开头 | 动作描述模糊,Seedance 自己瞎发挥 |
| 4.2 | prompt 是否足够丰富? | 包含 5 层:物理 + 运镜(文字)+ 动作 + 对白 + 声音/质感 | 只写 `@图片1 fights @图片2` |
| 4.3 | 运镜是否写进文字? | "camera follows behind handheld" | 传 `camera_movement: "dolly_in"` 枚举 — Seedance 忽略 |
| 4.4 | 对白是否用正确格式? | `@图片1 says: "台词"` | 写 "Elena says" — Seedance 不识别名字 |
| 4.5 | `@图片N` 是否对应 `reference_image_urls` 顺序? | index+1 映射 | 顺序变了,角色错乱 |
| 4.6 | 不该传的字段是否没传? | **没有** multi_shots / multi_prompt / cast_element_ids / negative_prompt | 传了 Seedance 全忽略,但容易造成 prompt 混乱 |
| 4.7 | `video_provider` 显式 `"ark"`? | **字段值 `"ark"` 必须显式传**(项目 `studio_mode="cinema"`,不会自动选 Seedance;原 seedance mode 已废弃) | 不传 → 走项目默认 Kling 了 |
| 4.8 | `model` 显式 `seedance-2.0-fast`? | 字段值对齐 | 不传 → fallback 到全局默认(可能不是 fast) |
| 4.9 | `resolution` 和 `model` 搭配? | `seedance-2.0-fast` + `480p`(默认)或 `720p` | fast + `1080p` → 后端硬改回 720p 并按 720p 扣费 |
| 4.10 | fl2v 模式没多传 ref? | fl2v 只给首+尾帧,**不传** reference_image_urls / ref_video_urls / ref_audio_urls | 传了也被丢,白占 prompt |
| 4.11 | `ref_audio_urls` 配了视觉锚点? | 同时有 ≥1 image 或 ≥1 video | 纯音频 ref → Ark 拒 |

## 全局检查

| # | 检查项 | 通过标准 | 常见错误 |
|---|---|---|---|
| G.1 | Style Lock 是否全程逐字复用? | 每个首帧 prompt 末尾完全一致 | 风格漂移 |
| G.2 | reference_image_urls 顺序是否全片固定? | `图片1/2/3...` 整部剧不变 | 某 clip 颠倒 → 角色错乱 |
| G.3 | video_genre 是否全片统一? | 同一 genre | 随意切换 → 色调不一致 |
| G.4 | 所有 URL 都是 `https://`? | `first_frame_url` / `reference_image_urls` 等 | 本地路径或 `blob:` → Pydantic validator 拒 |
| G.5 | 整部剧是否全程 Seedance? | `video_provider: "ark"` + `model: seedance-2.0-fast` 全片一致 | 中途切 Kling → 色调/运动风格跳变 |
| G.6 | 依赖链是否正确? | continuous clip 串行;非 continuous 可并行 | 尾帧提链的 clip 并行执行失败 |
| G.7 | manifest 里 ref_map 完整吗? | `{"图片1": "Elena", ...}` 有对应关系 | 后期回查不知道 `@图片3` 是谁 |
| G.8 | continuous clip 是否用了前序尾帧? | `/extract-frame` 取 URL 做 `first_frame_url` | 独立首帧 → 画面跳变 |
| G.9 | aspect_ratio 是否全片一致? | 所有 generate-* 用 Phase 0 的 `${ASPECT_RATIO}` | 某 clip 换 9:16 → 剪辑时撕裂 |
| G.10 | 是否只在终片阶段才升 720p/1080p? | 预览期 480p fast,终片才升 | 全程 720p → 成本翻倍 |

## Error Handling 检查

| # | 检查项 | 通过标准 |
|---|---|---|
| E.1 | 读到的错误是命名空间码吗? | `ark.face_policy` / `ark.invalid_resolution` 等 |
| E.2 | 按错误码走补救流程了吗? | 参考 SKILL.md 的 Error Handling 表 |
| E.3 | 失败的 generation 是不是自动退了 credit? | `finalize_failed_bg` 会处理 |
| E.4 | 注册 `ark.face_policy` 是不是换风格化图? | 不要用真实人脸 |
| E.5 | `ark.content_policy` 是不是改 prompt? | 去暴力/色情/政治关键词 |

## 三轮生成策略(LLM 自查自纠)

**不要依赖一次生成就得到完美结果。**

### 第一轮:生成计划
- 输入:System prompt + 剧本 + 目标时长 + Seedance 能力约束(无 multi-shot 等)
- 输出:完整的 JSON 生产计划(每 clip 的 `mode`、`transition_from_prev`、
  `reference_image_urls` 顺序、prompt with @图片N)

### 第二轮:自我审查
- 输入:第一轮 JSON + 原始剧本原文
- 检查:
  - Seedance 能力约束(每 clip 单镜头 ≤15s,没有 multi-shot)
  - 运动物理描述是否前置
  - `@图片N` 索引是否和 reference_image_urls 顺序一致
  - `ref_audio_urls` 是否配了视觉锚点
  - fl2v clip 是否误传了 ref_* 字段

### 第三轮:修正
- 输入:错误列表 + 第一轮 JSON
- **只改内容不改结构**

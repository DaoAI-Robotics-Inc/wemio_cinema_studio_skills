# Director's Review Checklist

> 在提交任何生成请求之前，用以下清单逐项检查。跳过检查是产出质量差的首要原因。

## Phase 1 检查：剧本分析

| # | 检查项 | 通过标准 | 常见错误 |
|---|---|---|---|
| 1.1 | 每个场景是否标注了情绪节拍？ | 每个 beat 有明确的情绪词 | 只写了"发生了什么"，没写"观众感受什么" |
| 1.2 | 是否找到了每个场景的转折点？ | 转折点有对应的 ECU/zoom 时刻 | 所有 shot 平铺直叙没有高潮 |
| 1.3 | Clip 分组是否符合叙事段落？ | 同地点+同角色+连续动作=同 clip | 机械地按时长切割，不管叙事逻辑 |
| 1.4 | 景别是否有递进？ | 每个 clip 内有 WS→MS→CU 或类似变化 | 所有 shot 都是同一个景别 |
| 1.5 | Clip 间过渡类型是否标注？ | continuous/scene_jump/reaction 明确 | 没标注，执行时才发现不知道用尾帧还是新首帧 |

## Phase 3 检查：首帧构图

| # | 检查项 | 通过标准 | 常见错误 |
|---|---|---|---|
| 3.1 | 景别是否匹配 clip 第一个 shot？ | prompt 明确写了 "Extreme close-up" / "Wide shot" 等 | 没写景别，模型随机决定 |
| 3.2 | 构图是否为运镜留了空间？ | dolly_in→wider 起始；dolly_out→tighter 起始 | CU 首帧 + dolly_in = 无处可推 |
| 3.3 | 是否是蓄力态（动作前一瞬）？ | "eyes still shut"（即将睁开） | "eyes wide open"（动作已完成） |
| 3.4 | 角色是否在三分线位置？ | 不在死中心（除非有意为之） | 角色居中，构图无张力 |
| 3.5 | 特效元素是否在首帧中预置？ | 如果 shot 1 有发光特效，首帧应有微弱暗示 | 首帧完全没有特效痕迹，视频突然出现很突兀 |
| 3.6 | 多角色首帧是否传入了所有角色参考图？ | `ref_image_urls` 包含每个出场角色的参考图 + 地点图 | 只传了主角参考，配角外观随机生成 |

## Phase 4 检查：视频 Prompt

| # | 检查项 | 通过标准 | 常见错误 |
|---|---|---|---|
| 4.1 | 特效是否在 prompt 最前面？ | "Golden veins pulse..." 开头 | 特效放在句尾被 suffix 淹没 |
| 4.2 | prompt 是否足够丰富（~300-450 chars）？ | 包含 5 层：环境+特效+动作/对话+质感+情绪 | 只写了 "makes coffee. watches."（太简短） |
| 4.2b | 是否有运镜/色调描述混入 prompt？ | 没有 "camera catches", "slow push", "cold blue tones" | prompt 里写了运镜/色调（由参数控制） |
| 4.3 | 每个 shot 是否只表达一件事？ | 一个 shot = 一个动作/一个特效/一个情绪变化 | 一个 shot 里塞了 5 件事 |
| 4.4 | 字符数是否安全？ | 每个 shot prompt ≤ 430 chars | 超过 512 导致 Kling 400 错误 |
| 4.5 | @CharacterName 是否正确？ | 大小写匹配 element name | @eris vs element "Eris" |
| 4.6 | multi-shot 是否避免了顶层 duration/camera_movement？ | multi-shot 模式不传这两个顶层参数 | 传了 None 导致 422 |
| 4.7 | Clip 间过渡是否执行正确？ | continuous → 尾帧提链；scene_jump → 新首帧 | 全部用新首帧，丢失连续性 |

## 全局检查

| # | 检查项 | 通过标准 | 常见错误 |
|---|---|---|---|
| G.1 | Style Lock 是否全程逐字复用？ | 所有首帧 prompt 末尾的风格描述完全一致 | 每次改写导致画风漂移 |
| G.2 | Character Lock 是否全程逐字复用？ | 所有首帧 prompt 中角色描述完全一致 | 缩写或改写导致角色外观变化 |
| G.3 | video_genre 是否全集统一？ | 同一集使用相同 genre | 随意切换 genre 导致色调不一致 |
| G.4 | 节奏是否有变化？ | clip 时长不全是 15s — 有长有短 | 所有 clip 都是 15s，节奏单调 |
| G.5 | 依赖链是否正确？ | continuous clip 串行；scene_jump clip 可并行 | 尾帧提链的 clip 被并行执行导致失败 |

## 三轮生成策略（LLM 自查自纠）

**不要依赖一次生成就得到完美结果。** 用三轮调用让 LLM 自己审查和修正。

### 第一轮：生成计划
- 输入：System prompt + 剧本 + 目标时长
- 输出：完整的 JSON 生产计划

### 第二轮：自我审查
- 输入：第一轮的 JSON + 原始剧本原文
- 检查：角色准确性、完整性、prompt 质量、API 约束、结构

### 第三轮：修正
- 输入：错误列表 + 第一轮 JSON
- **只改内容不改结构**（R3 容易顺带重构 schema，必须在 prompt 里强调）

成本：三轮 ~$0.25，准确率从 8.5 提升到 9.5+。

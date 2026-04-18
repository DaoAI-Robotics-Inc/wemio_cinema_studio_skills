# Wemio Cinema Studio Skills

通过 [Wemio Cinema Studio](https://app.wemio.com) API 实现视频制作自动化的 Claude Code 技能包。

## 可用技能

| 技能 | 适用场景 |
|------|---------|
| **[script-to-video-kling](skills/script-to-video-kling/SKILL.md)** | 对白戏、长剧集、跨集角色一致、精确运镜参数控制、单 clip 内 multi-shot、720p / 1080p 正片出片。用 Kling v3 / v3-omni + element 注册体系。 |
| **[script-to-video-seedance](skills/script-to-video-seedance/SKILL.md)** | 动作片、MV、真实运动与物理、多模态参考(≤9 张图 + ≤3 视频 + ≤3 音频 可同时)、音素级 lip-sync、中文原生 prompt。用 Seedance 2.0 Fast + `@图片N` 位置引用。默认 480p 省成本。 |

**一部剧一个模型。** 不要在一部片子里混用 Kling 和 Seedance — 色调、运动风格、面部 drift 在两家之间差异明显,中途切换会露馅。按剧本的主导场景类型选对应 skill。

## 快速开始

### 1. 安装技能

**每部片只装一个** skill 到项目的 `.claude/skills/`:

```bash
# 在项目根目录执行,按片子类型选一个
mkdir -p .claude/skills
cp -r skills/script-to-video-kling .claude/skills/        # 对白 / 叙事
# 或
cp -r skills/script-to-video-seedance .claude/skills/     # 动作 / MV / 运动
```

或者 clone 后 symlink:

```bash
git clone https://github.com/DaoAI-Robotics-Inc/wemio_cinema_studio_skills.git
ln -s "$(pwd)/wemio_cinema_studio_skills/skills/script-to-video-kling" .claude/skills/script-to-video-kling
```

### 2. 获取 API Key

**方式 A:从设置页面创建(推荐)**

1. 打开 [app.wemio.com](https://app.wemio.com) 并登录
2. 点击左下角头像 → **设置**
3. 下滑到 **API Keys** 区域
4. 点击 **创建 Key**,输入名称,点击创建
5. **立即复制保存** — Key 只显示一次!

API Key 格式为 `pk_xxxxxxxx...`,默认永不过期(也可以设置有效期)。

**方式 B:JWT Token(临时,24 小时过期)**

1. 登录 [app.wemio.com](https://app.wemio.com)
2. 按 F12 打开浏览器开发者工具 → **Application** → **Local Storage** → `https://app.wemio.com`
3. 复制 `wemio_token` 的值

JWT Token 每 24 小时过期,自动化场景推荐用 API Key。

### 3. 运行技能

在 Claude Code 中调用装的那个 skill:

```
/script-to-video-kling path/to/screenplay.txt
```

或者

```
/script-to-video-seedance path/to/screenplay.txt
```

或直接粘贴剧本:

```
/script-to-video-kling

内景 咖啡馆 - 早晨

一个年轻女孩独自坐在角落的桌子旁,盯着手掌上发光的印记...
```

两个 skill 都会:
1. 询问环境(线上/本地)、API Key、以及全片格式(aspect ratio / 分辨率 / tier)
2. 以电影导演的视角分析剧本,提出逐 clip 制作计划
3. 生成角色参考图和地点建立镜头
4. 注册成可复用资产(Kling 两步注册 / Seedance 单步注册 + 合规库登记)
5. 生成电影级首帧
6. 生成视频 clip(Kling multi-shot 单 clip 内切镜头 / Seedance 单镜头 ref2v)
7. 连贯性通过切镜头切景别实现,必要时尾帧提链
8. 输出完整资产清单

## API 认证

所有 API 调用使用 Bearer Token 认证:

```bash
curl -H "Authorization: Bearer pk_你的api_key" \
  https://app.wemio.com/api/cinema-studio/projects
```

API Key(`pk_*`)和 JWT Token 都支持。自动化推荐用 API Key。

### 通过 API 管理 Key

```bash
# 创建 Key(用 JWT 或已有的 API Key 认证)
curl -X POST https://app.wemio.com/api/api-keys \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"name": "my-bot"}'
# 返回: {"raw_key": "pk_...", ...}  ← 保存好!

# 列出所有 Key
curl https://app.wemio.com/api/api-keys \
  -H "Authorization: Bearer <token>"

# 删除 Key
curl -X DELETE https://app.wemio.com/api/api-keys/<key_id> \
  -H "Authorization: Bearer <token>"
```

## API 端点参考

### Cinema Studio(两个 skill 共用)

所有路径前缀 `/api/cinema-studio/`。

| 端点 | 方法 | 说明 |
|------|------|------|
| `/projects` | POST / GET | 创建 / 列出项目(Kling 和 Seedance 都用 `studio_mode: "cinema"`) |
| `/projects/{id}/generations` | GET | 列 project 下所有 generation(含 `credit_cost`) |
| `/generations/{id}/status` | GET | **主轮询端点**(`/tasks/{task_id}` 是 legacy,`task_id` 多为 null) |
| `/generations/{id}` | PATCH / DELETE | 更新(liked, element_name)/ 删除 |
| `/generate-character` | POST | 生成角色参考图 |
| `/generate-location` | POST | 生成地点建立镜头 |
| `/generate-scene` | POST | 生成场景图 / 首帧 |
| `/generate-video` | POST | 生成视频(`video_provider: "kling"` 或 `"ark"`) |
| `/generations/{id}/extract-frame` | POST | 提取首帧 / 尾帧(provider 无关,替代本地 ffmpeg) |
| `/crop-ultrawide` | POST | 16:9 → 21:9 裁剪 |
| `/upload` | POST | 上传参考图 / 视频 / 音频 |
| `/elements` | POST / GET | 把 generation 晋升为 element(**不触发注册**)/ 列出 |
| `/elements/upload` | POST | 用户直传 1-4 张图片创建 element |
| `/elements/{id}/register/kling` | POST | 显式触发 Kling 注册(后台任务) |
| `/elements/{id}/register/kling/confirm` | POST | 提交 frontal / back / face_detail 面板(当状态为 `needs_review` 时) |
| `/elements/{id}/register/seedance` | POST | 显式触发 Seedance 元素注册(Ark asset 绑定,供 `@图片N` 解析) |

### Asset 合规库(仅 Seedance 前置步骤)

路径前缀 `/api/`(**不在** `/api/cinema-studio/` 下)。

| 端点 | 方法 | 说明 |
|------|------|------|
| `/assets/register-url` | POST | 把 S3 URL 注册为 Asset 行(`generate-scene` / `/upload` 产出的 URL 不自动建,`check-by-url` 会 404,先调这个) |
| `/compliance/check-by-url` | POST | 把图片 URL 提交到 Seedance 合规库(**Seedance 生成前必做**,不做会被 Ark 以 `real_person` 等理由拒) |
| `/compliance/status/{asset_id}` | GET | 轮询合规状态:`unchecked` → `pending` → `compliant` / `failed` |

**为什么 Seedance 要两套注册?** `/elements/{id}/register/seedance` 把 element 绑定到 Ark `asset_id`,让 prompt 里的 `@图片N` 能正确解析。但 Ark **生成时还会对帧图 / ref 图做第二轮合规检查**,查的是 Asset 级别的合规库。两套都要做。Kling 不需要 Asset 合规库这一步。

## 制作流水线

```
剧本 → 第0阶段:Setup(认证、项目、全片格式)
     → 第1阶段:导演分析(角色、地点、clip 打包)
     → 第2阶段:资产生成 + provider 专属注册
     → 第3阶段:首帧生成(每 clip 电影级构图)
     → 第4阶段:视频生成(通过切镜头切景别做连贯性)
     → 第5阶段:汇总输出
```

### Kling 特有细节
- **两步注册**:`POST /elements` 只创建 element 不触发注册,**必须**再调 `POST /elements/{id}/register/kling`。可能返回 `needs_review`(splitter 拆出来的三面图可疑),提交 `frontal_url` / `back_url` / `face_detail_url` 到 `…/confirm` 完成。
- **角色一致性**:通过 `cast_element_ids` 锁定(**必须显式传**,不再从 @-mention 派生)。
- **Cast token 语法**:`@素材N` 位置引用(与 Phoenix UI cast chip 一致,规范做法)或 `@ElementName` 按名 — 两种都会被后端重写为 `<<<element_N>>>`。
- **单 clip 内多镜头**:multi-shot 最多 6 shot,总时长 ≤15s,每 shot 2-15s 整数秒,每 shot prompt ≤500 字符(超了 Kling 静默截断)。Multi-shot 模式 sound 强制 ON。
- **clip 间连贯**:切景别 / 角度,每 clip 独立生成,`cast_element_ids` 跨 clip 锁角色。尾帧提链(`/extract-frame` `which=last`)只用于真连续物理动作(追逐、跟镜)。
- **价格(credits/秒,当前 `models.yaml`)**:Kling 720p(standard)有声 30 / 1080p(pro)有声 41。`sound_rate` 是总价不是叠加。
- **命名空间错误码**:`kling.invalid_resolution`、`kling.element_not_found`、`kling.content_policy` 等。

### Seedance 特有细节
- **单步注册**:`POST /elements` + `POST /elements/{id}/register/seedance`。**没有 `needs_review`**(Seedance 单图合规,不拆三面)。
- **Asset 合规库(必需)**:任何要作 `first_frame_url` / `last_frame_url` / `reference_image_urls` 的图 URL,都要先 `POST /api/compliance/check-by-url` + 轮询到 `compliant`。`/register/seedance` 不代替这步 — Ark 生成时会做第二轮合规检查。
- **角色一致性**:每个 clip 传**完全相同**的 `reference_image_urls` 数组(URL 一致、顺序一致)。`@图片N` 位置映射到该数组的第 N 个元素。
- **ref2v 是主路径**(精品剧 90% 镜头走这条):传 `reference_image_urls` + 可选 `first_frame_url`。支持 2-way 和 3-way 多模态(图 + 视频 + 音频可同时)。3-way 偶发 `service_error` 是 transient,重试即过。
- **fl2v 是辅助工具**(角色入场 / 出场、环境转场、精确站位控制通过合成图或草图作首尾帧)。**两端都有写实人物才拒 `real_person`**(一端有人一端无人 ✓;两端都有人 ❌,深度伪造防御)。
- **clip 间连贯**:切景别 / 角度(每次切 = 新 `/generate-video` 调用,`reference_image_urls` 保持不变),剪辑阶段组接。不是 fl2v 硬插值。
- **无 multi-shot**:每 clip 一个镜头(≤15s)。无 camera_movement 参数(运镜写进 prompt 文字)。无 `negative_prompt`。
- **价格(credits/秒,当前 `models.yaml`)**:`seedance-2.0-fast` 480p 17 / 720p 36,**音频包含在基础价里不额外收**。`seedance-2.0` 480p 21 / 720p 44 / 1080p 91。
- **命名空间错误码**:`ark.face_policy` / `ark.invalid_resolution` / `ark.content_policy` / `ark.timeout` / `ark.compliance_failed`;还有 `real_person`(fl2v 两端人物)、`parameter_invalid`(fast + 1080p 等参数不匹配)、`service_error`(transient,重试)。

### 两个 skill 共享的细节
- **WebP**:后端自动生成 `.webp` sibling 并传给 provider,skill 不用管图片格式转换。
- **一部剧一个模型**:别在一部片里混 Kling 和 Seedance。
- **aspect_ratio: 9:16 等非 16:9** 当前出片质量明显弱于 16:9(后端 prompt builder 模板硬编码了 16:9 镜头语言)。临时方案:16:9 出图 + 后期 `/crop-ultrawide` 或剪辑阶段裁。

完整文档(Pydantic schema、prompt 公式、导演检查清单、curl 示例)见各 skill 的 `SKILL.md`。

## 开源协议

MIT

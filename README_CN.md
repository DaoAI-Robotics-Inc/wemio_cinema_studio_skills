# Wemio Cinema Studio Skills

通过 [Wemio Cinema Studio](https://app.wemio.com) API 实现视频制作自动化的 Claude Code 技能包。

## 可用技能

| 技能 | 适用场景 |
|------|---------|
| **[script-to-video-kling](skills/script-to-video-kling/SKILL.md)** | 对白戏、长剧集、跨集角色一致、精确运镜参数控制、720p / 1080p 正片出片。用 Kling v3 / v3-omni 的 multi-shot + element 注册体系。 |
| *script-to-video-seedance*(待开发) | 动作片、MV、真实运动与物理、多模态参考(参考视频 + 参考音频)、中文原生 prompt。用 Seedance 2.0 + `@图片N` 位置引用。 |

**一部剧一个模型。** 不要在一部片子里混用 Kling 和 Seedance — 色调、运动风格、面部 drift 在两家之间差异明显,中途切换会露馅。按剧本的主导场景类型选对应 skill。

## 快速开始

### 1. 安装技能

把技能文件夹复制到你项目的 `.claude/skills/` 目录:

```bash
# 在项目根目录执行
mkdir -p .claude/skills
cp -r skills/script-to-video-kling .claude/skills/
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

在 Claude Code 中调用:

```
/script-to-video-kling path/to/screenplay.txt
```

或者直接粘贴剧本:

```
/script-to-video-kling

内景 咖啡馆 - 早晨

一个年轻女孩独自坐在角落的桌子旁,盯着手掌上发光的印记...
```

Claude 会:
1. 询问你的环境(线上/本地)、API Key、以及全片格式(aspect ratio / 分辨率 / tier)
2. 以电影导演的视角分析剧本,提出逐镜头制作计划等你确认
3. 生成角色三面参考表和地点建立镜头
4. **把每个资产注册成 Kling element**(两步走:创建 + 触发注册 + 轮询,含 `needs_review` 的处理)
5. 生成电影级首帧构图
6. 使用 Kling 3.0 多镜头模式生成视频
7. continuous clip 通过尾帧提链无缝衔接
8. 输出完整的资产清单

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

所有路径前缀 `/api/cinema-studio/`。

| 端点 | 方法 | 说明 |
|------|------|------|
| `/projects` | POST / GET | 创建 / 列出项目 |
| `/projects/{id}/generations` | GET | 列出 project 下所有 generation(含 `credit_cost`) |
| `/generations/{id}/status` | GET | **主轮询端点**(`/tasks/{task_id}` 是 legacy,`task_id` 多数为 null) |
| `/generations/{id}` | PATCH / DELETE | 更新(liked, element_name)/ 删除 |
| `/generate-character` | POST | 生成角色三面参考表 |
| `/generate-location` | POST | 生成地点建立镜头 |
| `/generate-scene` | POST | 生成场景图 / 首帧 |
| `/generate-video` | POST | 生成视频(单镜头 or 多镜头) |
| `/generations/{id}/extract-frame` | POST | 提取视频首帧或尾帧(替代本地 ffmpeg) |
| `/crop-ultrawide` | POST | 16:9 → 21:9 裁剪 |
| `/upload` | POST | 上传参考图片 / 视频 / 音频 |
| `/elements` | POST / GET | 把 generation 晋升为 element(**不触发注册**)/ 列出 |
| `/elements/upload` | POST | 用户直传 1-4 张图片创建 element |
| `/elements/{id}/register/kling` | POST | **显式触发** Kling 注册(后台任务) |
| `/elements/{id}/register/kling/confirm` | POST | 提交 frontal / back / face_detail 面板(当状态为 `needs_review` 时) |
| `/elements/{id}/register/seedance` | POST | 显式触发 Seedance(Ark)合规注册 |

## 制作流水线

```
剧本 → 第0阶段:Setup(认证、项目、全片格式)
     → 第1阶段:导演分析(角色、地点、分镜打包)
     → 第2阶段:资产生成 + 两步 Kling element 注册
     → 第3阶段:首帧生成(每 clip 电影级构图)
     → 第4阶段:视频生成(Kling 3.0 多镜头,尾帧提链)
     → 第5阶段:汇总输出
```

核心技术细节:
- **两步注册**:`POST /elements` 只是把 generation 标记为 element,**不触发注册**。必须显式调 `POST /elements/{id}/register/kling`。可能返回 `needs_review`,需要提交三面图到 `…/confirm` 完成注册。
- **角色一致性**:Kling element 系统通过 `cast_element_ids` 锁定跨 clip 角色外观。
- **Cast token 语法**:`@素材N` 位置引用(与 Phoenix UI cast chip 一致),也可以用 `@ElementName` 按名引用 — 后端统一重写为 `<<<element_N>>>`。
- **场景连贯**:通过官方 `POST /generations/{id}/extract-frame` 提取尾帧接下一 clip,**不需要本地 ffmpeg**。
- **Multi-shot**:每 clip ≤6 shot,总时长 ≤15s,每 shot `duration` 整数秒 2-15s,每 shot prompt ≤500 字符(超了 Kling 静默截断)。Multi-shot 模式 sound 强制 ON。
- **价格(credits/秒,2026-04 实测)**:Kling 720p(standard)带声 30 credits/s;1080p(pro)带声 41 credits/s。`sound_rate` 是总价不是叠加。
- **命名空间错误码**:`kling.invalid_resolution`、`kling.element_not_found`、`kling.content_policy` 等 — 详细补救方案见 skill 的 Error Handling 表。
- **已知限制**:`aspect_ratio: 9:16` 等非 16:9 比例当前出片电影感明显弱于 16:9,因为后端 prompt builder 硬编码了 16:9 镜头语言。临时方案:用 16:9 出图再裁剪。

详细文档(Pydantic schema、prompt 公式、导演检查清单、curl 示例)见 [完整技能说明](skills/script-to-video-kling/SKILL.md)。

## 开源协议

MIT

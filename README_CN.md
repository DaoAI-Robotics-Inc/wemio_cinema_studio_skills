# Wemio Cinema Studio Skills

通过 [Wemio Cinema Studio](https://app.wemio.com) API 实现视频制作自动化的 Claude Code 技能包。

## 可用技能

| 技能 | 说明 |
|------|------|
| [script-to-video](skills/script-to-video/SKILL.md) | 剧本到视频的自动化生产流水线。解析剧本为角色、地点、场景，生成角色三面参考表、地点建立镜头、首帧、多镜头视频片段。 |

## 快速开始

### 1. 安装技能

把技能文件夹复制到你项目的 `.claude/skills/` 目录：

```bash
# 在项目根目录执行
mkdir -p .claude/skills
cp -r skills/script-to-video .claude/skills/
```

或者 clone 后 symlink：

```bash
git clone https://github.com/DaoAI-Robotics-Inc/wemio_cinema_studio_skills.git
ln -s "$(pwd)/wemio_cinema_studio_skills/skills/script-to-video" .claude/skills/script-to-video
```

### 2. 获取 API Key

**方式 A：从设置页面创建（推荐）**

1. 打开 [app.wemio.com](https://app.wemio.com) 并登录
2. 点击左下角头像 → **设置**
3. 下滑到 **API Keys** 区域
4. 点击 **创建 Key**，输入名称，点击创建
5. **立即复制保存** — Key 只显示一次！

API Key 格式为 `pk_xxxxxxxx...`，默认永不过期（也可以设置有效期）。

**方式 B：JWT Token（临时，24小时过期）**

1. 登录 [app.wemio.com](https://app.wemio.com)
2. 按 F12 打开浏览器开发者工具 → **Application** → **Local Storage** → `https://app.wemio.com`
3. 复制 `wemio_token` 的值

JWT Token 每 24 小时过期，自动化场景推荐用 API Key。

### 3. 运行技能

在 Claude Code 中调用：

```
/script-to-video path/to/screenplay.txt
```

或者直接粘贴剧本：

```
/script-to-video

内景 咖啡馆 - 早晨

一个年轻女孩独自坐在角落的桌子旁，盯着手掌上发光的印记...
```

Claude 会：
1. 询问你的环境（线上/本地）和 API Key
2. 以电影导演的视角分析剧本
3. 展示逐镜头的制作计划，等你确认
4. 生成角色三面参考表和地点建立镜头
5. 生成电影级首帧构图
6. 使用 Kling 3.0 多镜头模式生成视频
7. 输出完整的资产清单

## API 认证

所有 API 调用使用 Bearer Token 认证：

```bash
curl -H "Authorization: Bearer pk_你的api_key" \
  https://app.wemio.com/api/cinema-studio/projects
```

API Key（`pk_*`）和 JWT Token 都支持。自动化推荐用 API Key。

### 通过 API 管理 Key

```bash
# 创建 Key（用 JWT 或已有的 API Key 认证）
curl -X POST https://app.wemio.com/api/api-keys \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"name": "my-bot"}'
# 返回: {"raw_key": "pk_...", ...}  ← 保存好！

# 列出所有 Key
curl https://app.wemio.com/api/api-keys \
  -H "Authorization: Bearer <token>"

# 删除 Key
curl -X DELETE https://app.wemio.com/api/api-keys/<key_id> \
  -H "Authorization: Bearer <token>"
```

## API 端点参考

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/cinema-studio/projects` | POST | 创建新项目 |
| `/api/cinema-studio/projects` | GET | 列出所有项目 |
| `/api/cinema-studio/generate-character` | POST | 生成角色三面参考表 |
| `/api/cinema-studio/generate-location` | POST | 生成地点建立镜头 |
| `/api/cinema-studio/generate-scene` | POST | 生成场景图/首帧 |
| `/api/cinema-studio/generate-video` | POST | 生成视频（单镜头或多镜头） |
| `/api/cinema-studio/elements` | POST | 注册为可复用的 Kling 元素 |
| `/api/cinema-studio/elements` | GET | 列出已保存的元素 |
| `/api/cinema-studio/generations/{id}/status` | GET | 轮询生成状态 |
| `/api/cinema-studio/upload` | POST | 上传参考图片 |

## 制作流水线

```
剧本 → 第1阶段：导演分析（角色、地点、分镜表）
     → 第2阶段：资产生成（角色参考表、地点参考、元素注册）
     → 第3阶段：首帧生成（电影级构图）
     → 第4阶段：视频生成（Kling 3.0 多镜头，自动保持一致性）
     → 第5阶段：汇总输出
```

核心技术细节：
- **角色一致性**：Kling 元素系统锁定角色外观
- **场景连贯**：连续片段间尾帧提链
- **多镜头**：每个片段 2-4 个镜头，最长 15 秒，片段内自动保持一致
- **Prompt 策略**：特效前置，动作/情绪为主。运镜/色调由 API 参数控制，不写进 prompt
- **三轮 LLM 审查**：生成 → 自查 → 修正，准确率 9.5+

详细文档见 [完整技能说明](skills/script-to-video/SKILL.md)。

## 开源协议

MIT

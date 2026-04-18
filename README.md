# Wemio Cinema Studio Skills

[中文文档](README_CN.md)

Claude Code skills for automating video production via the [Wemio Cinema Studio](https://app.wemio.com) API.

## Available Skills

| Skill | Best for |
|-------|----------|
| **[script-to-video-kling](skills/script-to-video-kling/SKILL.md)** | Dialogue-heavy drama, multi-episode narrative, cross-clip character consistency, precise parametric camera control, 720p/1080p finals. Uses Kling v3 / v3-omni multi-shot + element registration. |
| **[script-to-video-seedance](skills/script-to-video-seedance/SKILL.md)** | Action / MV / realistic motion & physics, multimodal references (≤9 images + ≤3 videos + ≤3 audio), phoneme-level lip-sync, native Chinese prompts. Uses Seedance 2.0 Fast + `@图片N` positional references. Default 480p for cost. |

**One production = one model.** Don't mix Kling and Seedance within a single show — color grading, motion style, and face drift differ enough that switching mid-project shows. Pick the skill that matches your project's dominant scene type.

## Quick Start

### 1. Install the skill

Copy the skill folder into your project's `.claude/skills/` directory:

```bash
# From your project root
mkdir -p .claude/skills
cp -r skills/script-to-video-kling .claude/skills/
```

Or clone this repo and symlink:

```bash
git clone https://github.com/DaoAI-Robotics-Inc/wemio_cinema_studio_skills.git
ln -s "$(pwd)/wemio_cinema_studio_skills/skills/script-to-video-kling" .claude/skills/script-to-video-kling
```

### 2. Get your API Key

**Option A: From the Settings page (recommended)**

1. Go to [app.wemio.com](https://app.wemio.com) and log in
2. Click your avatar (bottom-left) → **Settings**
3. Scroll down to **API Keys** section
4. Click **Create Key**, give it a name, and click create
5. **Copy the key immediately** — it's only shown once!

The API key format is `pk_xxxxxxxx...` and does not expire unless you set an expiry.

**Option B: JWT token (temporary, 24h)**

1. Log in to [app.wemio.com](https://app.wemio.com)
2. Open browser DevTools (F12) → **Application** → **Local Storage** → `https://app.wemio.com`
3. Copy the value of `wemio_token`

JWT tokens expire every 24 hours. API keys are recommended for automation.

### 3. Run the skill

In Claude Code, invoke the skill with your script:

```
/script-to-video-kling path/to/screenplay.txt
```

Or paste the script directly:

```
/script-to-video-kling

INT. COFFEE SHOP - MORNING

A young woman sits alone at a corner table, staring at a glowing mark on her palm...
```

Claude will:
1. Ask for environment (prod/local), API key, and film format (aspect ratio, resolution, tier)
2. Analyze the script as a film director and propose a shot-by-shot plan
3. Generate character reference sheets and location establishing shots
4. **Register each as a Kling element** (two-step: create + register + poll, with `needs_review` handling)
5. Generate first frames with cinematic composition
6. Produce multi-shot video clips with Kling 3.0
7. Chain continuous clips via tail-frame extraction
8. Output a complete manifest with all assets

## API Authentication

All API calls use Bearer token authentication:

```bash
curl -H "Authorization: Bearer pk_your_api_key_here" \
  https://app.wemio.com/api/cinema-studio/projects
```

Both API keys (`pk_*`) and JWT tokens are supported. API keys are recommended for automation — they don't expire and don't require browser access.

### Managing API Keys via API

```bash
# Create a key (authenticate with JWT or existing API key)
curl -X POST https://app.wemio.com/api/api-keys \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"name": "my-bot"}'
# Returns: {"raw_key": "pk_...", ...}  ← save this!

# List keys
curl https://app.wemio.com/api/api-keys \
  -H "Authorization: Bearer <token>"

# Delete a key
curl -X DELETE https://app.wemio.com/api/api-keys/<key_id> \
  -H "Authorization: Bearer <token>"
```

## API Endpoints Reference

All paths prefixed with `/api/cinema-studio/`.

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/projects` | POST / GET | Create / list projects |
| `/projects/{id}/generations` | GET | List all generations in a project (includes `credit_cost`) |
| `/generations/{id}/status` | GET | **Primary status polling endpoint** (`/tasks/{task_id}` is legacy, `task_id` is usually null) |
| `/generations/{id}` | PATCH / DELETE | Update (liked, element_name) / delete |
| `/generate-character` | POST | Generate character reference sheet (3-view) |
| `/generate-location` | POST | Generate location establishing shot |
| `/generate-scene` | POST | Generate scene image / first frame |
| `/generate-video` | POST | Generate video (single-shot or multi-shot) |
| `/generations/{id}/extract-frame` | POST | Extract first or last frame of a video (replaces local ffmpeg) |
| `/crop-ultrawide` | POST | Crop 16:9 → 21:9 |
| `/upload` | POST | Upload reference image/video/audio |
| `/elements` | POST / GET | Create element from a generation (does **not** trigger registration) / list |
| `/elements/upload` | POST | Create element from user-uploaded 1-4 images |
| `/elements/{id}/register/kling` | POST | **Explicitly trigger** Kling registration (background task) |
| `/elements/{id}/register/kling/confirm` | POST | Submit user-approved frontal/back/face_detail panels (called when status goes to `needs_review`) |
| `/elements/{id}/register/seedance` | POST | Explicitly trigger Seedance (Ark) compliance registration |

## Production Pipeline Overview

```
Script → Phase 0: Setup (auth, project, film format)
       → Phase 1: Director's Analysis (characters, locations, clip breakdown)
       → Phase 2: Asset Generation + two-step Kling element registration
       → Phase 3: First Frames (cinematic composition per clip)
       → Phase 4: Video Generation (Kling 3.0 multi-shot, tail-frame chaining)
       → Phase 5: Summary & Manifest
```

Key technical details:
- **Two-step element registration**: `POST /elements` creates the element but does NOT register — you must explicitly call `POST /elements/{id}/register/kling`. May return `needs_review`; submit the three split panels to `…/confirm` to finalize.
- **Character consistency**: Kling element system locks character appearance across clips via `cast_element_ids`.
- **Cast token syntax**: `@素材N` positional (matches Phoenix UI cast chips) or `@ElementName` by-name — both rewritten to `<<<element_N>>>` server-side.
- **Scene continuity**: Tail-frame chaining via the official `POST /generations/{id}/extract-frame` endpoint. No local ffmpeg needed.
- **Multi-shot**: up to 6 shots, total ≤15s, each shot 2-15s integer seconds, each shot prompt ≤500 chars (Kling silently truncates beyond). Sound is forced ON in multi-shot mode.
- **Pricing (per second, 2026-04)**: Kling 720p (standard) 30 credits/s with sound; 1080p (pro) 41 credits/s with sound. `sound_rate` is total, not additive.
- **Namespaced error codes**: `kling.invalid_resolution`, `kling.element_not_found`, `kling.content_policy`, etc. — localized remediation lives in the skill's Error Handling table.
- **Known limitation**: `aspect_ratio: 9:16` and other non-16:9 ratios currently produce less cinematic output because the backend prompt builder hardcodes 16:9 cinematography language. Work around by generating at 16:9 and cropping.

See the [full skill documentation](skills/script-to-video-kling/SKILL.md) for Pydantic schemas, prompt formulas, director's checklists, and curl examples.

## License

MIT

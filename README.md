# Wemio Cinema Studio Skills

Claude Code skills for automating video production via the [Wemio Cinema Studio](https://app.wemio.com) API.

## Available Skills

| Skill | Description |
|-------|-------------|
| [script-to-video](skills/script-to-video/SKILL.md) | Automated screenplay-to-video production pipeline. Parses scripts into characters, locations, and scenes. Generates reference sheets, first frames, and multi-shot video clips with cinematic direction. |

## Quick Start

### 1. Install the skill

Copy the skill folder into your project's `.claude/skills/` directory:

```bash
# From your project root
mkdir -p .claude/skills
cp -r skills/script-to-video .claude/skills/
```

Or clone this repo and symlink:

```bash
git clone https://github.com/DaoAI-Robotics-Inc/wemio_cinema_studio_skills.git
ln -s "$(pwd)/wemio_cinema_studio_skills/skills/script-to-video" .claude/skills/script-to-video
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
/script-to-video path/to/screenplay.txt
```

Or paste the script directly:

```
/script-to-video

INT. COFFEE SHOP - MORNING

A young woman sits alone at a corner table, staring at a glowing mark on her palm...
```

Claude will:
1. Ask for your environment (prod/local) and API key
2. Analyze the script as a film director
3. Present a shot-by-shot production plan for your approval
4. Generate character reference sheets and location establishing shots
5. Generate first frames with cinematic composition
6. Produce multi-shot video clips with Kling 3.0
7. Output a complete manifest with all assets

## API Authentication

All API calls use Bearer token authentication:

```bash
curl -H "Authorization: Bearer pk_your_api_key_here" \
  https://app.wemio.com/api/cinema-studio/projects
```

Both API keys (`pk_*`) and JWT tokens are supported. API keys are recommended for automation — they don't expire and don't require browser access.

### Managing API Keys via API

You can also manage keys programmatically:

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

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/cinema-studio/projects` | POST | Create a new project |
| `/api/cinema-studio/projects` | GET | List all projects |
| `/api/cinema-studio/generate-character` | POST | Generate character reference sheet (3-view) |
| `/api/cinema-studio/generate-location` | POST | Generate location establishing shot |
| `/api/cinema-studio/generate-scene` | POST | Generate scene image / first frame |
| `/api/cinema-studio/generate-video` | POST | Generate video (single-shot or multi-shot) |
| `/api/cinema-studio/elements` | POST | Register generation as reusable Kling element |
| `/api/cinema-studio/elements` | GET | List saved elements |
| `/api/cinema-studio/generations/{id}/status` | GET | Poll generation status |
| `/api/cinema-studio/upload` | POST | Upload reference image |

## Production Pipeline Overview

```
Script → Phase 1: Director's Analysis (characters, locations, shot list)
       → Phase 2: Asset Generation (character sheets, location refs, elements)
       → Phase 3: First Frames (cinematic composition for each clip)
       → Phase 4: Video Generation (Kling 3.0 multi-shot with consistency)
       → Phase 5: Summary & Manifest
```

Key technical details:
- **Character consistency**: Kling element system locks character appearance across clips
- **Scene continuity**: Tail-frame chaining between consecutive clips
- **Multi-shot**: 2-4 shots per clip, up to 15 seconds, automatic intra-clip consistency
- **Prompt strategy**: Effects first, then action/emotion. Camera/style handled by API parameters, not prompt text.
- **Three-round LLM review**: Generate → self-audit → correct for 9.5+ accuracy

See the [full skill documentation](skills/script-to-video/SKILL.md) for detailed API contracts, prompt formulas, and director's checklists.

## License

MIT

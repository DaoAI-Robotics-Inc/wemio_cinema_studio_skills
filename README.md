# Wemio Cinema Studio Skills

[中文文档](README_CN.md)

Claude Code skills for automating video production via the [Wemio Cinema Studio](https://app.wemio.com) API.

## Available Skills

| Skill | Best for |
|-------|----------|
| **[script-to-video-kling](skills/script-to-video-kling/SKILL.md)** | Dialogue-heavy drama, multi-episode narrative, cross-clip character consistency, precise parametric camera control, multi-shot within a single clip, 720p/1080p finals. Uses Kling v3 / v3-omni + element registration. |
| **[script-to-video-seedance](skills/script-to-video-seedance/SKILL.md)** | Action / MV / realistic motion & physics, multimodal references (up to 9 images + 3 videos + 3 audio simultaneously), phoneme-level lip-sync, native Chinese prompts. Uses Seedance 2.0 Fast + `@图片N` positional references. Default 480p for cost. |
| **[cinema-studio-ops](skills/cinema-studio-ops/SKILL.md)** | Shared local post-production utility — concat N clips into a final cut via ffmpeg, keep output local by default. Used by both main skills after clip-level generation. Provider-agnostic. |

**One production = one model.** Don't mix Kling and Seedance within a single show — color grading, motion style, and face drift differ enough that switching mid-project shows. Pick the skill that matches your project's dominant scene type.

## Quick Start

### 1. Install the skill

Pick **one** skill per production and copy it into your project's `.claude/skills/`:

```bash
# From your project root — choose one based on project type
mkdir -p .claude/skills
cp -r skills/script-to-video-kling .claude/skills/        # dialogue / narrative
# or
cp -r skills/script-to-video-seedance .claude/skills/     # action / MV / motion
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

In Claude Code, invoke whichever skill you installed with your script:

```
/script-to-video-kling path/to/screenplay.txt
```

or

```
/script-to-video-seedance path/to/screenplay.txt
```

Or paste the script directly:

```
/script-to-video-kling

INT. COFFEE SHOP - MORNING

A young woman sits alone at a corner table, staring at a glowing mark on her palm...
```

Both skills will:
1. Ask for environment (prod/local), API key, and film format (aspect ratio, resolution, tier)
2. Analyze the script as a film director and propose a clip-by-clip plan
3. Generate character reference sheets and location establishing shots
4. Register them as reusable assets (two-step for Kling; single-step + compliance library for Seedance)
5. Generate first frames with cinematic composition
6. Produce video clips (multi-shot on Kling, single-shot ref2v on Seedance)
7. Handle continuity via cutting between different shot sizes/angles, or tail-frame chaining when needed
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

### Cinema Studio (both skills use these)

All paths prefixed with `/api/cinema-studio/`.

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/projects` | POST / GET | Create / list projects (`studio_mode: "cinema"` for both Kling and Seedance) |
| `/projects/{id}/generations` | GET | List all generations in a project (includes `credit_cost`) |
| `/generations/{id}/status` | GET | **Primary status polling endpoint** (`/tasks/{task_id}` is legacy, `task_id` is usually null) |
| `/generations/{id}` | PATCH / DELETE | Update (liked, element_name) / delete |
| `/generate-character` | POST | Generate character reference image |
| `/generate-location` | POST | Generate location establishing shot |
| `/generate-scene` | POST | Generate scene image / first frame |
| `/generate-video` | POST | Generate video (pass `video_provider: "kling"` or `"ark"`) |
| `/generations/{id}/extract-frame` | POST | Extract first or last frame of a video (replaces local ffmpeg, provider-agnostic) |
| `/crop-ultrawide` | POST | Crop 16:9 → 21:9 |
| `/upload` | POST | Upload reference image / video / audio |
| `/elements` | POST / GET | Create element from a generation (does **not** trigger registration) / list |
| `/elements/upload` | POST | Create element from user-uploaded 1-4 images |
| `/elements/{id}/register/kling` | POST | Explicitly trigger Kling registration (background task) |
| `/elements/{id}/register/kling/confirm` | POST | Submit user-approved frontal/back/face_detail panels (called when status goes to `needs_review`) |
| `/elements/{id}/register/seedance` | POST | Explicitly trigger Seedance element registration (Ark asset binding for `@图片N` resolution) |

### Asset compliance (Seedance-only prerequisite)

All paths prefixed with `/api/` (not under `/api/cinema-studio/`).

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/assets/register-url` | POST | Register an S3 URL as a first-class Asset (needed when `generate-scene` / `/upload` URLs aren't auto-tracked and `check-by-url` would 404) |
| `/compliance/check-by-url` | POST | Submit an image URL to Seedance compliance library (**required** before using the URL as a frame or ref in Seedance generation) |
| `/compliance/status/{asset_id}` | GET | Poll compliance status: `unchecked` → `pending` → `compliant` / `failed` |

**Why two systems for Seedance?** `/elements/{id}/register/seedance` binds an element to an Ark `asset_id` so `@图片N` in prompts resolves correctly. But Ark runs a **second compliance check at generation time** on frame/ref URLs that queries the Asset-level compliance library. Both are required for Seedance; Kling doesn't use the Asset compliance library.

## Production Pipeline Overview

```
Script → Phase 0: Setup (auth, project, film format)
       → Phase 1: Director's Analysis (characters, locations, clip breakdown)
       → Phase 2: Asset Generation + provider-specific registration
       → Phase 3: First Frames (cinematic composition per clip)
       → Phase 4: Video Generation (cut to different shot sizes/angles for continuity)
       → Phase 5: Summary & Manifest
```

### Kling-specific details
- **Two-step element registration**: `POST /elements` creates the element but does NOT register — you must explicitly call `POST /elements/{id}/register/kling`. May return `needs_review` (splitter panels suspicious); submit `frontal_url` / `back_url` / `face_detail_url` to `…/confirm` to finalize.
- **Character consistency**: Kling element system locks character appearance across clips via `cast_element_ids` (must be passed explicitly — no longer derived from @-mentions).
- **Cast token syntax**: `@素材N` positional (matches Phoenix UI cast chips, canonical) or `@ElementName` by-name — both rewritten to `<<<element_N>>>` server-side.
- **Multi-shot within a single clip**: up to 6 shots, total ≤15s, each shot 2-15s integer seconds, each shot prompt ≤500 chars (Kling silently truncates beyond). Sound is forced ON in multi-shot mode.
- **Clip-to-clip continuity**: cut to a different shot size/angle, each clip independent; `cast_element_ids` locks character across clips. Tail-frame chaining (`/extract-frame` `which=last`) is reserved for genuinely continuous physical action (chase, single-take follow).
- **Pricing (per second, current `models.yaml`)**: Kling 720p (standard) 30 credits/s with sound; 1080p (pro) 41 credits/s with sound. `sound_rate` is total, not additive.
- **Namespaced error codes**: `kling.invalid_resolution`, `kling.element_not_found`, `kling.content_policy`, etc.

### Seedance-specific details
- **Single-step element registration**: `POST /elements` + `POST /elements/{id}/register/seedance`. No `needs_review` state (Seedance uses single-image compliance, not a multi-panel splitter).
- **Asset compliance library (required)**: every image URL that will be used as `first_frame_url` / `last_frame_url` / `reference_image_urls` must pass `POST /api/compliance/check-by-url` + polling to `compliant`. `/register/seedance` alone is not enough — Ark runs a second check at generation time.
- **Character consistency**: reuse the exact same `reference_image_urls` array (same URLs, same order) across every clip. `@图片N` in the prompt maps positionally to that list.
- **ref2v is the main path** (≈90% of shots for polished productions): pass `reference_image_urls` + optional `first_frame_url`. Supports 2-way and 3-way multimodal (images + videos + audio). `service_error` on 3-way is transient — retry.
- **fl2v is auxiliary** (character entrance/exit, environment transitions, precise blocking via composite/sketch frames). **Two-humans rule**: if both `first_frame_url` AND `last_frame_url` contain clearly visible real humans, Ark rejects with `real_person` (treat as deepfake defense). One end with humans + one end without → OK.
- **Clip-to-clip continuity**: cut to a different shot size/angle (each cut = a new `/generate-video` call with the same `reference_image_urls`), final assembly in editing. Not fl2v interpolation.
- **No multi-shot**: each clip is one shot (≤15s). No camera movement parameters (describe camera in prompt text). No `negative_prompt` support.
- **Pricing (per second, current `models.yaml`)**: `seedance-2.0-fast` 17 credits/s at 480p, 36 at 720p — audio included in base rate. `seedance-2.0` 21/44/91 at 480p/720p/1080p.
- **Namespaced error codes**: `ark.face_policy`, `ark.invalid_resolution`, `ark.content_policy`, `ark.timeout`, `ark.compliance_failed`; plus `real_person` (fl2v-specific), `parameter_invalid` (e.g. fast-model + 1080p), `service_error` (transient, retry).

### Shared details (apply to both)
- **WebP**: backend auto-generates `.webp` siblings on all image uploads and passes them to providers — skills don't handle format negotiation.
- **One production = one model**: don't mix Kling and Seedance within a single show.
- **aspect_ratio: 9:16** and other non-16:9 ratios currently produce less cinematic output because the backend prompt builder hardcodes 16:9 cinematography language. Work around by generating at 16:9 and cropping via `/crop-ultrawide` or downstream editing.

See each skill's full documentation for Pydantic schemas, prompt formulas, director's checklists, and curl examples.

## License

MIT

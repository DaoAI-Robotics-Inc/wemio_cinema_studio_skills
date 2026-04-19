# End-to-End Production Pipeline Playbook

**Purpose:** orchestrate the full script → final.mp4 workflow. This is the
playbook the main skill (`script-to-video-seedance` or
`script-to-video-kling`) follows when the user invokes production mode
(e.g. `/cinema-studio-produce <script>`).

Phases and per-phase responsibilities are documented here so the skill
can resume / retry at any phase boundary.

---

## Full flow

```
┌────────────────────────────────────────────────────────────────┐
│  USER INPUT: raw script + optional style tag + optional refs   │
└──────────────────────────┬─────────────────────────────────────┘
                           │
               ┌───────────▼───────────┐
               │  Phase A: PARSE        │  (Claude-driven)
               │  parse_script.md       │
               └───────────┬───────────┘
                           │ structured scene_list.json
               ┌───────────▼───────────┐
               │  Phase B: ROUTE        │  (Claude-driven)
               │  genre router +        │
               │  style profile lookup  │
               └───────────┬───────────┘
                           │ selected genre + examples-<genre>.md
               ┌───────────▼───────────┐
               │  Phase C: ASSETS       │  (API-driven)
               │  generate character    │
               │  refs if missing;      │
               │  scene_blueprint.sh    │
               │  for each location;    │
               │  compliance register   │
               └───────────┬───────────┘
                           │ ref URLs + blueprint JSONs
               ┌───────────▼───────────┐
               │  Phase D: BUDGET       │  (Python tool)
               │  budget_estimator.py   │
               │  present to user       │
               │  WAIT for /continue    │
               └───────────┬───────────┘
                           │
               ┌───────────▼───────────┐
               │  Phase E: DECOMPOSE    │  (Claude-driven)
               │  decompose_scene.md    │
               │  per scene, inject     │
               │  continuity anchors    │
               │  from state machine    │
               └───────────┬───────────┘
                           │ clip prompts
               ┌───────────▼───────────┐
               │  Phase F: PRE-CHECK    │  (Claude-driven)
               │  R1-R19 rules          │
               │  block on critical     │
               │  warn on major         │
               └───────────┬───────────┘
                           │ validated prompts
               ┌───────────▼───────────┐
               │  Phase G: GENERATE     │  (API-driven)
               │  submit per R15 rules  │
               │  chain-vs-parallel     │
               │  extract-frame between │
               │  chained clips         │
               └───────────┬───────────┘
                           │ clip URLs
               ┌───────────▼───────────┐
               │  Phase H: POST-CHECK   │  (dual judgment)
               │  Claude vision +       │
               │  Gemini audit_clip +   │
               │  audit_full on concat  │
               └───────────┬───────────┘
                           │
               ┌───────────▼───────────┐
               │  Phase I: AUTO-FIX     │  (loop, ≤3)
               │  for each clip with    │
               │  critical/major →      │
               │  revise prompt +       │
               │  re-gen + re-audit     │
               └───────────┬───────────┘
                           │
               ┌───────────▼───────────┐
               │  Phase J: DELIVER      │  (local)
               │  ffmpeg concat         │
               │  manifest.json         │
               │  iteration_log.md      │
               │  final.mp4             │
               └────────────────────────┘
```

---

## Phase-by-phase detail

### Phase A: Parse
- Read `tools/parse_script.md`, follow its procedure on user's script.
- Output: `/tmp/<prod_id>/scene_list.json` with full structure.
- Validation: every scene has `starts_with` and `ends_with`;
  no character/prop/location orphans.
- **Time cost:** free (Claude reasoning)
- **On error:** ask user to clarify ambiguous script bits; don't
  hallucinate scenes that aren't implied.

### Phase B: Route
- Apply genre decision tree from
  `skills/script-to-video-seedance/SKILL.md`:
  1. User-explicit style tag → use that
  2. Parser-detected genre with confidence ≥ 0.7 → use it
  3. Default `drama`
- Read top 3 entries of `examples-<genre>.md` to calibrate style/format.
- Output: genre + style profile dict used by Phase E.
- **On low confidence:** ask user which genre (with 2-3 top candidates).

### Phase C: Assets — MANDATORY for multi-clip productions (R22)

**If production has ≥2 clips with any recurring character OR recurring
location, Phase C is NON-NEGOTIABLE.** Skipping Phase C and generating
via text-only t2v produces incoherent output where each clip has a
different imagined version of the character + location. See R22 for
2026-04-18 "Courier Chronicles" regression proof.

Procedure:

- For each character WITHOUT an existing ref:
  - `POST /api/cinema-studio/generate-character` with visual_description
  - Wait for `status: done`, get image_url
  - Register to compliance via `POST /api/compliance/check-by-url`
  - Poll until `compliant`
- For each location:
  - If no scene ref image: `POST /api/cinema-studio/generate-scene`
  - Run `tools/scene_blueprint.sh` against the image
  - Save blueprint JSON + register to compliance
- Claude reads every ref image (Phase 0a from cinema-studio-qa skill).
- Output: `/tmp/<prod_id>/refs/` directory with downloaded images +
  `ref_facts.md`.

**Output must include `ref_map.json`** listing the canonical ordering:
```json
{
  "courier": "https://...courier_ref.png",
  "buyer": "https://...buyer_ref.png",
  "underground_garage": "https://...garage_ref.png",
  "rooftop": "https://...rooftop_ref.png"
}
```

Every clip in Phase G must include these refs in its
`reference_image_urls` array (with clip-specific order: usually
characters-in-this-scene first, then location last).

- **Time cost:** 30s-2min per asset generated.
- **Credit cost:** ~30-50 credits per character ref (image gen) +
  ~30-50 credits per location ref. For a 4-char 2-location production:
  ~250 credits (~$1.25). This is **mandatory overhead**, not optional.

### Phase D: Budget
- Run `tools/budget_estimator.py` with production params.
- Present estimate to user:
  ```
  Estimated cost:
    - Seedance credits: <X> (~$<Y>)
    - Gemini audits: ~$<Z>
    - Total: ~$<W>
  Ready to generate? /continue or /abort
  ```
- WAIT. Do not proceed until user confirms.

### Phase E: Decompose
- For each scene in order:
  1. Inject continuity anchors from state machine (see
     `tools/continuity_state.md`).
  2. Apply `tools/decompose_scene.md` procedure.
  3. Generate clip prompt in genre format (500-800 chars target).
- State machine updates happen after each scene is generated +
  audited, not before.

### Phase F: Pre-check
- For each clip prompt, run R1-R19 rule checks
  (see `skills/cinema-studio-qa/pre-check-rules.md`).
- Critical failure → block, escalate to user with diff.
- Major warnings → flag, proceed (user can halt).
- Minor → note only.

### Phase G: Generate — MANDATORY `raw_prompt: true` (R23)

**Every Seedance clip payload MUST include `raw_prompt: true`.** Without
it, Phoenix's Gemini Flash enhancer flattens the structured
`[00:XX-YY] 镜头N:` blocks into a single continuous narrative — R1's
subject-diversity rule gets discarded upstream. This is the single
most important payload flag for multi-shot productions.

Payload must also include:
- `reference_image_urls` per R22 (character + location refs)
- End of prompt: `"clean frame, no subtitles, no captions, no on-screen text, no watermark"` — because raw mode skips the auto-subtitle-prevention layer that the LLM enhancer would have added

Flow:
- R15 chain analysis: which clip pairs have visual dependency?
- Chained pairs: serial submission (wait for N → extract-frame →
  submit to N+1's reference_image_urls).
- Independent pairs: parallel submission.
- Timeout: 10 min per clip; on timeout, retry once; on 2nd fail,
  mark `needs_user_review`.

### Phase H: Post-check (dual judgment)

For each clip:

1. **Claude vision pass**: extract 5-8 frames (at 1s, 3s, 5s, 7s, 9s,
   11s, 13s, 14.5s for 15s clip), Read each. Score on:
   - Are there shot cuts where prompt expected them?
   - Does each shot have distinct primary subject?
   - Character appearance consistent?
   - Axis (LEFT/RIGHT) held?
   - Prop state per R17?
   - Style match (noir / anime / etc.)?
   - Any egregious physical artifacts?
2. **Gemini audit pass**: run `audit_clip.sh` with intended.txt.
3. **Reconcile**:
   - Both PASS → accept
   - Both REWORK → send to Phase I with combined fix_suggestions
   - DISAGREE → log both verdicts. Claude's wins if:
     - Claude can explain Gemini's mistake (e.g. "Gemini flagged
       magical appearance but frame 2s shows physics correctly
       rendered").
     - The disagreement is about artistic interpretation (single-take
       is OK for drama, not a bug).
   - Escalate to user if Claude can't resolve.

### Phase I: Auto-fix
- Max 3 iterations per clip.
- For each critical/major issue:
  - Consult `skills/cinema-studio-qa/auto-fix-patterns.md` (if it
    exists) for category-specific recipes.
  - Apply R16 stronger anchoring if spatial issue.
  - Apply R17 stronger negation if phantom-prop.
  - Switch skill to Kling if R19 style-override triggered.
- After each fix, re-run Phase G for that clip, then Phase H.
- On iteration cap: accept current clip, mark as "warn" in
  manifest, proceed.

### Phase J: Deliver
- Concatenate all final clip URLs via `cinema-studio-ops` skill
  (local ffmpeg).
- Write `manifest.json`:
  ```json
  {
    "production_id": "...",
    "title": "...",
    "genre": "...",
    "duration_s": ...,
    "clips": [{ "id": "s1", "prompt": "...", "video_url": "...",
                "audit_verdict": "pass", "iterations": 1 }, ...],
    "style_tags": ["..."],
    "total_cost_credits": ...,
    "total_cost_usd": ...
  }
  ```
- Write `iteration_log.md` with per-clip prompt evolution + verdicts.
- Return `final.mp4` path + manifest path to user.

---

## Budget guards (per `budget_estimator.py`)

```
before Phase G: compute expected_credits
if expected_credits > 2.5x user's original quote → block, re-ask
during Phase I: track accumulated_credits
if accumulated_credits > 2.0x initial_quote → stop iterations, accept current
after Phase J: report actual credits + total_usd in manifest
```

---

## Failure modes + recovery

| Failure | Recovery |
|---|---|
| Script ambiguous, parser low confidence | Ask user 2-3 clarifying questions |
| Ref image fails compliance (real_person rejected) | Regenerate with "stylized" adjective |
| Clip generation timeout | Retry once; if 2nd fail mark user-review |
| Gemini 503 service error | Retry with exponential backoff; skip audit if still fails |
| Gemini audit consistently wrong | Claude vision overrides per dual-judgment policy |
| Budget cap hit mid-production | Accept current output, deliver partial with warning |
| User aborts mid-run | Save state to `/tmp/<prod_id>/state.json` for resume |

---

## Resume points

The state of production is checkpointed after each phase:
- After Phase A: `scene_list.json` written
- After Phase C: `refs/` directory populated
- After Phase D: budget.json + `user_approved: true`
- After Phase G: `clips.json` with all URLs
- After Phase I: `final_clips.json`
- After Phase J: `manifest.json`

User can invoke `/cinema-studio-produce --resume <prod_id>` and the
skill picks up from the latest checkpoint.

# Cinema Studio Skills — Production Roadmap

**Goal:** User drops a script into the skill → skill produces a coherent 1-5
min short film in the user's chosen style (noir drama / anime action /
K-drama romance / MV / horror / etc.), self-iterating on quality until
Gemini audit passes or budget exhausts.

**Current state (2026-04-18):** Single-clip generation works well after
《末班车》v5 dogfood. Missing: script parsing, genre auto-routing, shot
decomposition, cross-clip continuity state machine, automated quality
loop for multi-clip productions.

**Budget for self-iteration:** Each Seedance generate-video call costs
~315 credits (≈$4) at 480p 15s seedance-2.0. A 4-clip short film runs
~1260 credits plus ≤$0.20 Gemini audit. Auto-fix up to 3 iterations =
~3x that. Production pipeline must surface budget before user commits.

---

## Testing policy (self-iteration, dual-judgment)

**Dual-judgment pipeline** — Claude Opus 4.7 has multimodal vision and
Gemini 3.1 Pro is an independent video-understanding model. Using both
in tandem, not one as the sole judge:

1. **Claude vision first**: before calling Gemini, extract 4-7 frames
   across the clip (including shot boundaries) and read them myself.
   Score the clip on: shot cuts present? subject diversity per shot?
   axis consistency? prop state tracked? style match? critical physical
   fails? Build my own verdict.
2. **Gemini second**: call `audit_clip.sh` for an independent technical
   audit against the intended.txt.
3. **Reconcile**:
   - Both agree PASS → accept, move on
   - Both agree needs rework → apply Gemini's fix_suggestion, retry
   - **They disagree**:
     - Usually Claude is closer to user intent (understands aesthetic
       context like "a single continuous wide shot is fine for drama
       contemplative moments"), Gemini over-applies "did the prompt
       literally match what got rendered" and flags harmless deviations.
     - Claude's verdict wins UNLESS I can't clearly explain why I
       differ.
     - Escalate to user only when Claude vision + Gemini both disagree
       on something load-bearing, OR when I can't confidently resolve.
4. **Budget cap per iteration:** 3 auto-fix attempts per clip, and an
   overall production budget cap of 2× the initial generation cost.
   Stop and ask user if hit.
5. **Progress logging:** each iteration logs the prompt + Claude's
   verdict + Gemini's verdict + final resolution to
   `/tmp/<production_id>/iteration_log.md`.

**Why dual-judgment matters (observed 2026-04-18):**
- Drama test: Gemini flagged "bag items magically appear" as major
  action_completion fail. Claude vision on frame t=2s saw oranges
  mid-air with water splash — physics actually rendered. Gemini was
  wrong about this specific issue.
- Gemini flagged "single continuous shot" as critical. That's
  technically true but drama single-takes are an artistic choice
  (Cuarón / Kar-wai), not a defect. Claude vision contextualizes.
- Gemini correctly flagged: style override (anime → photoreal),
  directional-entry bug, phantom-prop bug. Gemini is reliable on
  concrete violations.
- Claude vision is reliable on aesthetic intent + physics verification.

---

## Phase 1 — Corpus & Templating (START HERE)

**Why first:** lowest cost, highest leverage. The 1936-prompt corpus
(CSV at `/Users/xiaochuanchen/Downloads/seedance-2-0-prompts-20260418.csv`)
is our best source of "what actually works" for each genre, far better
than my guessing.

### Deliverables

1. **`tools/bucket_corpus.py`**: reads the CSV, classifies each row by
   genre using keyword rules + secondary LLM-assisted tagging for
   uncertain rows. Produces `/corpus/by-genre/<genre>.jsonl`.
2. **`examples-<genre>.md` files** in the seedance skill directory. One
   per genre, each with 10-15 top-scoring exemplars copied verbatim
   (so Claude can Read them when writing new prompts). Initial genres:
   - `drama` (done — 末班车 equivalent, also covers noir/suspense)
   - `anime` / `anime-action`
   - `action` (non-anime, live-action)
   - `romance`
   - `horror`
   - `mv` (music video)
   - `ugc` / `vlog-style`
   - `commercial-ad`
   - `fantasy-sci-fi`
3. **Genre style profile table** in `SKILL.md`: one row per genre with
   `preferred_format`, `char_length_median`, `signature_camera_moves`,
   `light_mood_palette`, `pacing_ratio`, `typical_shot_count_per_15s`.
4. **Genre router logic**: given user's script + optional style tag,
   decide which genre template + examples file to load. Priority:
   (a) explicit user tag, (b) Claude classifier on script text,
   (c) fallback to drama.

### Validation

- Pick 2 genres (e.g. drama + anime). For each: write a test scene
  following the new template + examples, generate via Seedance, audit
  via Gemini. Verify ≥80% Gemini pass rate on a 3-clip sample.
- If Gemini fails: adjust genre template based on its feedback. Retry
  until pass rate hits target. Do NOT escalate to user unless stuck
  for 3+ iterations.

### Success criteria

- 8 `examples-<genre>.md` files committed.
- Genre router documented + tested on 3 sample scripts.
- One test production (drama-style, 3 clip × 15s) runs through the
  new pipeline and Gemini rates all 3 clips `pass` or `needs_rework`
  (not `major_rewrite`).

### Estimated budget

- ~$0 for corpus processing (local).
- ~$12-16 credits + $0.05 Gemini for drama + anime test productions.

---

## Phase 2 — Script Pipeline

### Deliverables

1. **Script parser prompt** (`tools/parse_script.md`): takes raw
   script/screenplay text, outputs structured JSON:
   ```json
   {
     "title": "…",
     "genre": "…",
     "total_seconds": 60,
     "characters": [{ "id": "julian", "role": "detective", "visual_tag": "…" }],
     "locations": [{ "id": "subway_platform", "description": "…" }],
     "scenes": [
       { "id": "scene_1", "location": "subway_platform",
         "characters_present": ["julian"],
         "beat": "Julian waits for last train",
         "duration_target_seconds": 15,
         "continuity_requires": { "folio_in": null, "folio_out": "julian" }
       }
     ]
   }
   ```
2. **Shot decomposer prompt** (`tools/decompose_scene.md`): takes one
   scene from the parsed JSON + genre template, outputs 2-3 shots
   where each shot has **distinct subject + distinct dramatic action**
   (the R1 patch from c04 failure: subject diversity alone is not
   enough; actions must differ too). Uses genre-specific format from
   Phase 1.
3. **Continuity state machine** (`tools/continuity_state.md`): tracks
   per-character state across clips:
   ```
   character.pose / position / props_held / outfit / emotional_state
   environment.time_of_day / lighting / weather / train_present
   prop.location / owner / state (open/closed/etc.)
   ```
   Before each clip prompt is written, state machine injects:
   - R11 exhaustive description anchors for the starting state
   - R16 absolute position anchor for each character
   - R17 double-sided state update for exchanges
   - Scene blueprint constraints (from Phase 0)
4. **Integration**: script parser → continuity state → per-scene
   shot decomposer → clip prompt ready for Phase 1 generation.

### Validation

- Feed 3 different genre scripts (drama / anime / romance), run
  through parser → decomposer → continuity, generate ≤3 clips each,
  Gemini audit. Confirm Gemini pass rate ≥80% without human tuning.

### Success criteria

- Given a 60-second script (text only, no refs), pipeline produces
  valid clip prompts for all scenes.
- Continuity state machine catches ≥90% of cross-clip bugs that
  manual prompt writing produced in《末班车》v1-v5 dogfood (phantom
  prop, axis break, time reversal, phantom Woman etc.).

### Estimated budget

- Claude reasoning only for parser/decomposer (free).
- Per-test production: ~$12-16 credits + $0.10 Gemini.

---

## Phase 3 — End-to-End `/cinema-studio-produce` Pipeline

### Deliverables

1. **Slash command** `/cinema-studio-produce <script_path_or_text>`:
   ```
   Phase 0: read/generate refs, scene blueprints
   ↓
   Phase 1 pre-check (R1-R17)
   ↓
   Generate clips (respecting R15 chain-vs-parallel)
   ↓
   Phase 2 post-check via Gemini audit_full on concat
   ↓
   Phase 3 auto-fix loop (≤3 iterations per clip)
   ↓
   Produce final.mp4 + manifest + audit_report
   ```
2. **Budget gates**:
   - Before generation: compute total credits + API costs, present to
     user, require explicit `/continue` before spending.
   - After each iteration: update spend counter; halt if cap reached.
3. **Error recovery**:
   - Per-clip failure: auto-retry once, then mark `needs_user_review`.
   - Gemini service errors: retry with exponential backoff.
   - Compliance rejection: regenerate the offending asset.
4. **Asset reuse**:
   - Cache character refs across productions (keyed by user +
     character_id).
   - Scene blueprint cache (same location reused → blueprint fetched
     from cache, not re-computed).
5. **Final delivery**:
   - Concatenated mp4 via cinema-studio-ops
   - `manifest.json` with all clip URLs, prompts, audit results
   - `iteration_log.md` with full reasoning trail

### Validation (the "real" test)

- User provides a fresh 2-minute script in some genre we haven't
  tested. Run pipeline end-to-end without human intervention beyond
  the pre-generation budget approval. Target: final video rates
  ≥80% `pass` on Gemini's final audit. If not, skill auto-iterates
  until target or budget cap.

### Success criteria

- A 2-minute 8-clip production runs to completion from script.txt
  with only one user checkpoint (budget approval at start).
- Gemini final audit: ≥6 of 8 clips `pass`, no `major_rewrite`.
- Total user time (not generation time): <5 minutes of active
  involvement.

### Estimated budget per production

- 480p seedance-2.0 8 clips × 15s = ~$32 credits
- Gemini full + per-clip audit = ~$0.20
- Auto-fix (pessimistic 3 clips re-rolled once) = +$12
- Total ~$44 per 2-minute short

---

## Cross-cutting engineering

### Tools to build in `/tools` (shared across skills)
- `bucket_corpus.py` — CSV → per-genre JSONL
- `parse_script.md` — Claude prompt, script → scene JSON
- `decompose_scene.md` — Claude prompt, scene → shot list
- `continuity_state.md` — Claude prompt, state machine update logic
- `budget_estimator.py` — predicts credits + API spend before running
- `iteration_log.py` — structured logging of each auto-fix attempt

### Skill updates (durable, not per-project)
- `script-to-video-seedance/SKILL.md` — genre table + examples index
- `cinema-studio-qa/SKILL.md` — Phase 0/1/2/3 flow includes the new
  tools
- `cinema-studio-qa/pre-check-rules.md` — R1-R17 maintained as
  accumulating test log with each dogfood run

### Regression tests
- Keep a `/tests/productions/` directory with 5-10 "canonical" test
  scripts (one per genre). Any skill change runs all 10 through
  pipeline and compares audit scores. Regressions block skill merges.

---

## Progress

- [x] R1-R17 pre-check rules
- [x] Phase 0 (read refs + scene blueprint)
- [x] Phase 2 Gemini audit (audit_clip, audit_full)
- [x] R15 reframe-chained
- [x] R17 prop-exchange double-state-update
- [x] R18 physical destruction dedicated shot
- [x] R19 anime style override via refs
- [x] R20 iconic archetype filter avoidance
- [x] **Phase 1 — bucket corpus → 9 genre examples** (tools/bucket_corpus.py, emit_examples.py, extract_style_profiles.py)
- [x] **Phase 1 — genre router** (table in SKILL.md)
- [x] **Phase 1 — validation run** (drama / anime text-only tests exposed format+R1 limits; findings codified as skill updates)
- [x] **Phase 2 — script parser** (tools/parse_script.md)
- [x] **Phase 2 — shot decomposer** (tools/decompose_scene.md with R1 hardened rules)
- [x] **Phase 2 — continuity state machine** (tools/continuity_state.md)
- [x] **Phase 3 — budget estimator** (tools/budget_estimator.py)
- [x] **Phase 3 — orchestrator playbook** (tools/produce_pipeline.md, 10 phases A-J)
- [x] **Phase 3 — integration test "The Drop"** — 30s 2-scene drama. Validated:
  - Pipeline A-J runs end-to-end
  - R1 hardened rule: s2 achieved 3 real cuts with independent primary subjects
  - R17 exchange: Gemini confirmed "no phantom briefcases"
  - R20 archetype filter: generic buyer rewrite passed Ark filter
  - Dual-judgment policy: Claude+Gemini reconciled successfully (neither alone was accurate — Claude over-counted cuts on s1, Gemini under-counted; middle ground found by extracting more frames)
  - Result: 30s final.mp4 delivered at /tmp/the_drop/the_drop_final.mp4
  - Cost: 1155 credits (~$14.44) + $0.06 Gemini = ~$14.50 for 30s short
- [ ] Phase 3 — `/cinema-studio-produce` slash command (playbook written, not yet wired as a slash command)
- [ ] Phase 3 — 2-min fresh-script end-to-end test (next regression test)
- [ ] Regression test framework (`/tests/productions/`)

**Next logical step:** wire the playbook into an actual slash command so
users can invoke `/cinema-studio-produce script.txt` and have the skill
orchestrate all 10 phases. Or: do a 2-min 8-clip production to stress-test
the pipeline at full scale.

Update this section as each item closes.

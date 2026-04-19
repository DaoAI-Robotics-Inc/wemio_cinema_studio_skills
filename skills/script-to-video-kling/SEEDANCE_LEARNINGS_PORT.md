# Seedance Dogfood Learnings → Kling Skill Port

Distillation of R1-R35 rules discovered through《末班车》v1-v5,《The Drop》,
《Courier Chronicles》v1-v4,《The Café》, and《Room 207》 v1-v2 Seedance
productions. Each rule is classified: **DIRECT PORT** (applies to Kling
unchanged), **KLING-ADAPT** (needs rewrite for Kling's API), or **KLING-WIN**
(Kling's native API avoids the Seedance failure mode entirely).

Read this file before starting any Kling production to know which of the
hard-won Seedance lessons to apply, which to skip, and which Kling
advantages to use instead.

---

## A. Direct ports — apply unchanged to Kling productions

These rules were discovered on Seedance but are **provider-agnostic**
(narrative, workflow, or video-model-general failure modes). The canonical
text lives in `skills/cinema-studio-qa/pre-check-rules.md`; Kling
productions should honor them identically.

| Rule | Why provider-agnostic |
|---|---|
| **R11** exhaustive description (character + environment + prop + terminal) | Any video model benefits from specific prompts |
| **R11.2b** scene blueprint cross-check | Spatial sanity is geometry, not model-specific |
| **R15** chain-vs-parallel decision matrix + partial chain | Narrative state transfer is provider-agnostic |
| **R16** absolute position + explicit negation | Any model needs anchored opening states per shot |
| **R17** post-exchange prop state reset (double-sided) | Prop ownership logic is narrative, not model-specific |
| **R18** physical destruction needs dedicated slow-mo shot | All video models skip fine-grained physics |
| **R19** style override — 2D anime requires ref images | Kling's text-only cel-shaded also drifts to photoreal without ref |
| **R20** iconic character archetype triggers content filter | Ark and Kling both have copyright filters (Kling's may be less strict but still real) |
| **R21** crime-associated vocabulary → content policy | Both providers; vocabulary-neutralization is provider-agnostic |
| **R22** multi-clip MUST use reference_image_urls | Fundamental to any multi-clip coherence |
| **R24** recurring props need their own ref images | Applies to any multi-clip recurring prop |
| **R25** location transitions need narrative bridging | Editing-level rule, provider-agnostic |
| **R26** editing plan MANDATORY in Phase A | Production workflow rule, applies to all skills |
| **R27** image-first pipeline for 3 shot types (complex / emotion-static / rescue) | nano-banana pipeline works regardless of downstream video model |
| **R28** six-field prompt skeleton 风格+景别+主体+环境+光影+质感 | Prompt craft, model-agnostic |
| **R29** 9-panel storyboard explosion via nano-banana | Pre-production technique, routes to ANY downstream video |
| **R30** dialog conventions (per-clip lines, whitelist, tone descriptors) | Lip-sync and voice consistency issues exist on both Kling and Seedance |
| **R34** state refs lock INITIAL frame only, not animated state | Animation drift is a video-model general phenomenon |
| **R35** non-location refs need NEUTRAL backgrounds (prevent env pollution) | ref blending behavior is universal across providers |

**How to use:** when preparing a Kling production, run the same Phase A-F
pre-check against R22-R35 as you would for Seedance. The canonical rule
text is at `skills/cinema-studio-qa/pre-check-rules.md`.

---

## B. Kling-adapt — needs rewriting for Kling's API shape

These rules have Seedance-specific mechanics; the underlying *problem*
still exists on Kling but the *fix* changes because Kling has different
API fields.

### R1 (subject diversity for multi-shot) — largely obsoleted

**Seedance context:** R1 was critical because Seedance does multi-shot via
prompt text — if all shots share the same subject/framing, Seedance
collapses them into one continuous camera.

**Kling context:** Kling exposes the `multi_shots` / `multi_prompt` API
array field. Each shot is an **independent payload element** with its
own duration, camera_movement, and prompt text. Kling's backend
guarantees N shots are rendered because N slots exist in the request.

**Kling adaptation:**
- R1 subject diversity discipline becomes **nice-to-have**, not mandatory.
  Even if two adjacent shots have the same subject, Kling won't merge them.
- Still useful for editing-grade cuts (repeated same-subject shots feel
  redundant), but **no longer a hard correctness requirement**.

### R23 (raw_prompt: true) — verify behavior

**Seedance context:** Phoenix defaults `raw_prompt: false` and routes the
prompt through Gemini Flash enhancement which flattens structured shot
blocks. R23 mandates `raw_prompt: true` for all structured Seedance prompts.

**Kling context:** Kling payloads also accept `raw_prompt` field.
Unverified whether Kling's LLM enhancement path is equally destructive.
Kling's multi_shots API may bypass the enhancer for the per-shot prompt
array since those are API-structured and don't need "flattening" the way
Seedance prompts do.

**Kling adaptation:**
- **Pending test**: set `raw_prompt: true` on the first Kling production
  and compare output to `raw_prompt: false`. If identical, Kling's
  enhancer is gentler; keep default. If Kling also flattens, mandate
  `raw_prompt: true` as with Seedance.
- **Interim default:** `raw_prompt: true` is safer — pass user intent
  through verbatim. Remember to include "clean frame, no subtitles, no
  captions" in prompt text to replace the enhancer's anti-subtitle layer.

### R33 (shot count cap) — likely obsoleted

**Seedance context:** R33 tried to prevent Seedance from inserting
cinematic-trope reaction shots ("NO inserted Courier close-up"). Failed
on Room 207 s4 because Seedance treats certain tropes as mandatory grammar.

**Kling context:** Kling's `multi_shots` array has fixed length. If
array has 3 entries, Kling renders exactly 3 shots. No room for inserted
cutaways at the API level.

**Kling adaptation:**
- R33 becomes **∞ reliable** via API structure, not prompt text.
- Simply declare the `multi_shots` array length = intended shot count.
- Kling CANNOT insert a 4th shot if only 3 array entries exist.

### R31 (Ark extract-frame compliance fallback) — Ark-specific

**Seedance context:** Ark's extract-frame PNG URLs sometimes fail the
compliance fetcher (`ark.invalidparameter.downloadfailed`). R31 documents
the fallback ladder.

**Kling context:** Kling's extract-frame endpoint (if used) routes through
a different compliance path. This specific Ark bug likely does NOT affect
Kling chain workflows.

**Kling adaptation:**
- Test Kling chain in a production where Ark fails; document if Kling's
  path holds.
- If Kling chain is reliable, R31 becomes "use Kling as alternate chain
  provider when Ark has a bad day" — provided Kling is acceptable
  stylistically for the production.

---

## C. Kling-wins — Kling's native API avoids the Seedance failure mode

These are **affirmative advantages**: Kling has features Seedance lacks
that turn a Seedance R-rule into a non-issue.

### Kling Win 1 — `negative_prompt` field (500 chars)

**Seedance can't:** R32 (dialog whitelist), R33 (no inserted shots), R35
(no prop-ref background pollution) all have to be enforced via prompt-text
prose like "Do NOT add any other lines of dialog" — which Seedance
treats as best-effort suggestion.

**Kling wins:** pass negations directly in the `negative_prompt` field.
Kling's backend treats negative_prompt as a hard constraint on sampling.

**Template negative_prompt for drama clips:**
```
negative_prompt: "unscripted dialog, improvised lines, additional dialog,
inserted reaction shot, additional cutaway, b-roll insert, subtitles,
captions, on-screen text, watermarks, blue peeling wood wall, prop state
drift, blood on skin, environmental drift"
```

This single field replaces most of R32 / R33 / R35 prompt-text workarounds
on Seedance. Use negative_prompt as the primary tool for "things I don't
want"; keep the positive prompt focused on "things I do want".

### Kling Win 2 — `multi_shots` array with per-shot parameters

**Seedance can't:** R33 (shot cap), R1 (subject diversity), precise shot
timing, parametric camera movement — all requested via prompt text and
honored probabilistically.

**Kling wins:** each shot is an independent object in a `multi_shots`
array:
```json
"multi_shots": [
  { "prompt": "...", "duration": 4, "camera_movement": "dolly_in" },
  { "prompt": "...", "duration": 5, "camera_movement": "static" },
  { "prompt": "...", "duration": 6, "camera_movement": "pull_back" }
]
```

Benefits:
- Shot count = array length (R33 auto-satisfied)
- Per-shot duration enforced
- Per-shot camera move enforced via enum (dolly_in / orbit_left / pull_back
  / etc.)
- R1 subject diversity becomes editing preference not correctness req

### Kling Win 3 — parametric `camera_movement` enum

**Seedance can't:** 运镜术语 must be written into prompt text from the
80-term vocabulary; model probabilistically interprets. "慢推" written
in prompt might render as zoom, push-in, dolly-in, or static.

**Kling wins:** camera_movement is a closed enum. Backend physics handles
the actual move. No interpretation ambiguity.

**Common Kling camera_movement values** (verify against Kling docs):
- `static`, `dolly_in`, `dolly_out`, `pull_back`, `push_in`
- `pan_left`, `pan_right`, `tilt_up`, `tilt_down`
- `orbit_left`, `orbit_right`, `crane_up`, `crane_down`
- `handheld`, `steadicam_follow`

Use enum when a specific move is load-bearing; fall back to descriptive
prompt text only for unusual moves not covered by the enum.

---

## Recommended Kling production flow (adopts the ports)

```
Phase A: script parse + editing plan (R26)
    ↓
Phase B: genre route (per examples-<genre>.md)
    ↓
Phase C: generate refs (character + location + recurring props)
    — R22 mandatory, R24 for recurring props
    — R35 neutral backgrounds on non-location refs
    ↓
Phase D: budget estimate + user approval
    ↓
Phase E: decompose scenes into multi_shots arrays
    — R1 optional (Kling auto-satisfies)
    — R28 six-field skeleton per shot
    — R27 image-first for 3 hard shot types
    ↓
Phase F: pre-check R1-R35 against each multi_shots array
    — R20/R21 filter avoidance
    — R30 dialog whitelist
    ↓
Phase G: generate Kling clips
    — raw_prompt: true pending verification (R23)
    — negative_prompt field for R32/R33/R35 negations
    — multi_shots array for shot structure
    — camera_movement enum for each shot
    — chain-vs-parallel per R15
    ↓
Phase H: dual-judgment audit (Claude vision + Gemini 3.1 Pro)
    ↓
Phase I: auto-fix
    — Post-trim via cinema-studio-post for cinematic-trope over-reaches
    — R33 issues unlikely to appear on Kling due to multi_shots enforcement
    ↓
Phase J: deliver (cinema-studio-ops concat)
```

---

## Open questions to answer on first Kling production

- Does `raw_prompt: true` change Kling output vs `raw_prompt: false`?
  (R23 verification)
- Does Kling's `negative_prompt` actually suppress the Seedance-observed
  cinematic trope inserts (speaker-listener reaction)?
- Does Kling's extract-frame path avoid the Ark compliance bug (R31
  alternate provider claim)?
- Does Kling hold R34 state refs across animation better or worse than
  Seedance? (Fabric → skin blood migration specifically.)

When running the first Kling dialog drama, answer these and append
findings below.

---

## Log of Kling-specific findings (append as discovered)

*(Empty — will populate after first Kling production with dialog.)*

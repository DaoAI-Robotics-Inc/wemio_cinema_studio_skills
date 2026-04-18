# Script Parser Playbook

**Purpose:** Take raw user-provided text (screenplay excerpt, treatment, or
paragraph-level pitch) and output a structured JSON plan ready for the
shot decomposer.

**How this is used:** the main production skill loads this file, reads the
user's script, and produces the JSON below by following these steps. There
is no separate API call — Claude itself is the "parser".

---

## Input shapes accepted

The user may provide any of:
1. **Formal screenplay** (INT. / EXT. headers, character names, dialog, action)
2. **Treatment / summary** (a paragraph describing what happens)
3. **Scene list** (bullet points of scenes)
4. **Premise / log line** (single sentence — parser expands to minimal scenes)

## Output JSON shape

```json
{
  "title": "string",
  "genre": "drama | action | anime | romance | horror | mv | ugc | commercial | fantasy_scifi | other",
  "genre_confidence": 0.0-1.0,
  "style_tags": ["wong-kar-wai-noir", "k-drama", "mappa-anime", ...],
  "total_seconds": 15-180,
  "language_hint": "zh | en | mixed",

  "characters": [
    {
      "id": "julian",
      "role": "detective",
      "visual_description": "45y male, graying temples, three-day stubble, charcoal trench coat collar up, dark shirt + loose tie",
      "appears_in": ["scene_1", "scene_2", "scene_3", "scene_4"],
      "key_emotional_arc": "waiting → receiving burden → shock → isolation"
    }
  ],

  "locations": [
    {
      "id": "subway_platform",
      "description": "NYC-style subway platform at 00:15, wet tiles, cool fluorescent, cream tile wall LEFT impassable, tracks + pillars RIGHT, tunnel in depth",
      "appears_in": ["scene_1", "scene_2", "scene_3", "scene_4"],
      "axis_hint": "LEFT = wall (impassable), RIGHT = tracks (trains from right)"
    }
  ],

  "props": [
    {
      "id": "folio",
      "description": "brown leather folio, A5 size",
      "ownership_trajectory": [
        { "at_scene": "scene_1", "holder": "woman" },
        { "at_scene": "scene_2", "holder": "julian", "exchange": true },
        { "at_scene": "scene_3", "holder": "julian" },
        { "at_scene": "scene_4", "holder": "julian" }
      ]
    }
  ],

  "scenes": [
    {
      "id": "scene_1",
      "location_ref": "subway_platform",
      "characters_present": ["julian", "woman"],
      "beat": "Julian waits on empty platform; last train arrives; Woman exits carrying folio; they acknowledge each other silently",
      "emotional_tone": "anticipation, isolation",
      "duration_target_seconds": 15,
      "continuity_requires": {
        "starts_with": { "julian.position": "LEFT third, alone", "train_state": "approaching from RIGHT" },
        "ends_with": { "julian.position": "LEFT third", "woman.position": "RIGHT, 2m from open train doors", "folio.holder": "woman", "train_state": "stationary, doors open" }
      }
    }
  ]
}
```

---

## Parsing procedure (step by step)

1. **Read script and detect genre.** Look for signal words matching the
   genre taxonomy(see `skills/script-to-video-seedance/SKILL.md` genre
   router table). If multiple match, pick highest count. If none, default
   to `drama` and mark `genre_confidence: 0.3`. If user explicitly
   declared style (e.g. "anime-style", "MAPPA vibe", "王家卫 noir"),
   set genre + style_tags accordingly with confidence 0.95.

2. **Extract characters.** For each unique character name / role, write a
   `visual_description` that is **specific and directly visible** (age
   range, hair, facial hair, clothing pieces with colors, body build).
   Avoid adjectives the AI can't literalize (e.g. "kind-looking",
   "mysterious"). If script lacks detail, **fill in concrete defaults
   fitting the genre** (e.g. drama detective → middle-aged, graying,
   charcoal trench; anime hero → teen with colored hair, athletic,
   distinctive costume).

3. **Extract locations.** For each, write `description` in the form of
   `scene_blueprint.sh` output(spatial left/right passability, light
   direction, physical rules). This doubles as the prompt to pass to
   `scene_blueprint.sh` if a scene reference image exists.

4. **Extract props.** For each, write the material + color + size. Track
   `ownership_trajectory` across scenes — which character holds it at
   the START of each scene. This is the source of R17 double-state-update
   injection in the shot decomposer.

5. **Split script into scenes.** A scene = one location + one continuous
   beat of action. If script has no explicit scene breaks, segment by
   beats (action change, location change, emotional turn). Target
   `duration_target_seconds` per scene ≤ 15. If user says "10 second
   video", there's 1 scene of 10s. If "2-minute short", typically 6-10
   scenes of 10-20s each.

6. **For each scene, fill continuity_requires.** `starts_with` = the
   state at the first frame (feeds R16 absolute position anchor).
   `ends_with` = the state at the last frame (feeds R11.4 terminal state).
   If the previous scene's `ends_with` doesn't match this scene's
   `starts_with`, the decomposer must generate a bridging shot (or the
   script has a continuity bug worth flagging to user).

7. **Sanity checks before returning:**
   - Every character's `appears_in` is populated
   - Every prop's `ownership_trajectory` is continuous(no gaps,no
     unexplained appearances / disappearances)
   - Every scene has `duration_target_seconds` assigned
   - Adjacent scenes' ends_with → starts_with are consistent

---

## Example:《末班车》 (The Last Stop) parsed

Input (from user):
> "60-second subway noir. Detective Julian waits on wet platform at 00:15.
> Mysterious Woman exits last train, hands him a brown leather folio,
> re-boards. He opens it alone, something inside shocks him. Train departs.
> Pull-back on him isolated."

Output (parser fills gaps):
```json
{
  "title": "末班车 The Last Stop",
  "genre": "drama",
  "genre_confidence": 0.9,
  "style_tags": ["noir", "suspense", "subway-thriller"],
  "total_seconds": 60,
  "language_hint": "mixed",
  "characters": [
    { "id": "julian", "role": "detective", "visual_description": "...", "appears_in": ["s1","s2","s3","s4"] },
    { "id": "woman", "role": "mysterious courier", "visual_description": "...", "appears_in": ["s1","s2"] }
  ],
  "locations": [
    { "id": "subway_platform", "description": "...", "axis_hint": "..." }
  ],
  "props": [
    {
      "id": "folio",
      "description": "brown leather A5",
      "ownership_trajectory": [
        { "at_scene": "s1", "holder": "woman" },
        { "at_scene": "s2", "holder": "julian", "exchange": true },
        { "at_scene": "s3", "holder": "julian" },
        { "at_scene": "s4", "holder": "julian" }
      ]
    }
  ],
  "scenes": [
    { "id": "s1", "location_ref": "subway_platform", "characters_present": ["julian","woman"],
      "beat": "Julian waits; train arrives; Woman exits; silent meeting",
      "emotional_tone": "anticipation", "duration_target_seconds": 15,
      "continuity_requires": {
        "starts_with": { "julian": "alone LEFT third, watching RIGHT", "train": "off-screen, headlights approaching from RIGHT depth" },
        "ends_with": { "julian": "LEFT third, unchanged", "woman": "RIGHT, 2m from open train doors, holds folio", "train": "stationary, doors open RIGHT" }
      }
    },
    { "id": "s2", "location_ref": "subway_platform", "characters_present": ["julian","woman"],
      "beat": "Woman crosses to Julian, hands him folio, returns to train",
      "emotional_tone": "tension-release", "duration_target_seconds": 15,
      "continuity_requires": {
        "starts_with": { "julian": "LEFT third, waiting", "woman": "near RIGHT train doors, holds folio", "train": "stopped, doors open" },
        "ends_with": { "julian": "LEFT third, holds folio in both hands at waist", "woman": "inside train car (or back at doors)", "train": "stationary, doors open (about to close)", "folio": "julian" }
      }
    },
    { "id": "s3", "location_ref": "subway_platform", "characters_present": ["julian"],
      "beat": "Julian opens folio; shocked by contents; train departs right",
      "emotional_tone": "discovery-shock", "duration_target_seconds": 15,
      "continuity_requires": {
        "starts_with": { "julian": "LEFT third, alone, holds folio", "train": "stationary, doors closing, Woman inside" },
        "ends_with": { "julian": "LEFT third, folio open in hands, intense eye reaction", "train": "departing RIGHT, red tail lights streaking" }
      }
    },
    { "id": "s4", "location_ref": "subway_platform", "characters_present": ["julian"],
      "beat": "Alone, pull-back reveal of isolation; flickering fluorescent; mist",
      "emotional_tone": "isolation-resignation", "duration_target_seconds": 15,
      "continuity_requires": {
        "starts_with": { "julian": "LEFT third, standing still holding folio", "train": "completely gone", "environment": "mist rising, fluorescent flickering" },
        "ends_with": { "julian": "tiny LEFT-lower figure in extreme wide shot", "train": "absent", "atmosphere": "cold, empty, isolated" }
      }
    }
  ]
}
```

Use this example as a reference when parsing other scripts.

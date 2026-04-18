# Auto-fix Patterns

Map Gemini's `category` + `fix_suggestion` into concrete prompt edits. Claude
uses these patterns in Phase 3 to synthesize revised prompts without asking
the user for every minor decision.

Each pattern: **category** → **edit recipe** → **validation**.

---

## 1. `spatial_axis` — character flips sides

**Edit recipe**:
- Add or strengthen axis lock at the top of the prompt:
  ```
  180-degree axis locked throughout — @图片1 always on RIGHT third of frame,
  @图片2 always on LEFT. Train / vehicle enters/exits from LEFT only.
  ```
- If the clip has internal shots, repeat the axis declaration in each shot's
  description(Seedance re-randomizes on shot boundaries without it).

**Validation**: re-audit; spatial_axis category should not flag again.

---

## 2. `object_state_continuity` — object doesn't persist

**Edit recipe**: describe the state explicitly at every moment it's supposed
to exist.

Example (folio handoff failed):
- Before: `"她递文件夹, 他接过"` (too abstract)
- After: `"She extends the folio with both hands, he reaches forward and
  firmly takes it with both hands, her hands release and go empty, he now
  holds the folio at chest level. The handoff completes fully."`

Example (door closes prematurely):
- Before: `"Doors hiss open on the left"` (open event, no state-hold)
- After: `"Doors hiss open on the left AND REMAIN OPEN until the end of the clip. Steam continues drifting from the brakes. The train does NOT depart."`

**Validation**: re-audit; object_state_continuity and action_completion should
not flag the same transaction.

---

## 3. `physical_geometry` — train on platform, car on sidewalk, etc.

**Edit recipe**: add spatial grounding clause.

For trains:
```
on the parallel rail track beyond the platform edge, visible past the yellow
tactile paving strip. The train runs on the depressed track lane, never
crossing the platform surface.
```

For cars:
```
driving on the paved road lane, never crossing onto the sidewalk.
```

For elevators:
```
inside the vertical elevator shaft, doors mounted on the hallway wall.
```

**Validation**: re-audit; physical_geometry should not flag this object again.

---

## 4. `shot_transition` — abrupt inter-shot jumps

**Edit recipe**: rewrite transitions with match-on-action phrasing.

- Before: `"First X. Then Y. Finally Z."` (discrete, abstract)
- After: `"X happening, and AS he does X, Y begins — which carries into Z."`

Concrete:
- Before: `"Shot 1: hands open folio. Shot 2: macro on photograph."`
- After: `"Hands open the folio, pages parting. As the cover tips back revealing
  the contents, camera pushes in to macro — the photograph fills frame."`

**Validation**: re-audit; shot_transition category should not flag.

---

## 5. `character_consistency` — appearance drift across shots

**Edit recipe**:
- Seedance: increase the number of times `@图片N` is referenced in the
  prompt(each mention is an anchor). Never describe the character's appearance
  (outfit, hair) by words — the @ reference carries that.
- Kling: ensure `cast_element_ids` contains the element. Consider re-registering
  the element if its three-view sheet has weak facial features.
- If one specific shot drifts but others are fine: split the problem shot
  into its own clip with a fresh ref-image-urls list.

**Validation**: re-audit face match against ref image.

---

## 6. `pacing_directing` — dead time

**Edit recipe**: inject narrative beats into long static shots.

Before (15s static):
```
凝视长镜头: @图片1 stands motionless on right third, folio in hand, 
absolutely still for 15 seconds.
```

After (15s with 2 beats):
```
凝视长镜头: @图片1 stands motionless on right third for 5 seconds, folio in
right hand. At 5 seconds, 推进亲密镜头 as his grip tightens — knuckles whiten.
At 10 seconds, he slowly lowers his gaze to the folio, the camera pushes
closer to his face showing the weight of what he's seen.
```

Rule of thumb: every 4-5 seconds of screen time needs a micro-beat
(posture shift, gaze change, breath, object interaction). 15s with no beat is
almost never intentional.

**Validation**: re-audit; pacing_directing should not flag.

---

## 7. `action_completion` — handoff/grab/exchange didn't complete

**Edit recipe** (similar to object_state_continuity but about the action verb):

Before: `"She hands the folio to him"` (ambiguous — did he take it?)
After: `"She extends the folio. He reaches forward. Both sets of hands meet.
She releases, his grip firms. The folio is now fully in his possession, and
her hands are empty."`

For consuming actions (drinking, eating): describe the full arc + after-state.

**Validation**: re-audit; action_completion category should not flag.

---

## 8. `other` — catch-all

Gemini will occasionally use `other` for issues that don't fit categories.
Read the description carefully and craft a targeted edit.

---

## When NOT to auto-fix

Some Gemini findings are **not fixable by prompt edit alone**:

1. **Character face drift due to weak reference image** — need to regenerate
   `generate-character` with a sharper / more photogenic prompt, then
   re-register element. Auto-fix in Phase 3 should NOT try to paper over this.
2. **Wrong character ref in reference_image_urls array** — means the user
   swapped orders or selected wrong element. Needs human decision.
3. **Creative taste issues** — "the mood feels too cold" is subjective.
   Pass to user, don't auto-fix.

When Auto-fix can't confidently fix, emit `"auto_fix_status": "needs_human"`
in the report entry. Phase 3 skips it, shows user, waits.

---

## Cross-clip issues (requires Phase 2b)

Gemini's single-clip audit can't catch issues that span multiple clips:
- Character outfit differs between clip 1 and clip 3
- Scene-element state differs (train visible at end of clip 3, missing at
  start of clip 4)
- Time-of-day jump without establishing cue

**Phase 2b** (cross-clip audit) — not yet built. Scaffolding:
- Extract last frame of clip N, first frame of clip N+1
- Send both frames + N and N+1 prompts to Gemini as a "pair continuity" check
- Ask: "Do these two frames represent a smooth story continuation, or is
  there an inconsistency?"

Add when needed based on observed cross-clip bugs.

---

## Max iterations & budget

- **Max 3 iterations per clip** (fail-safe against infinite loops)
- **Budget cap = 1.8x original production cost** — if total credits +
  Gemini audit fees approach cap, stop and ask user
- Each iteration logs: original prompt, Gemini findings, edited prompt,
  diff. Keeps a full trail in `manifest.json` under `qa_history[]`.

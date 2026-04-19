---
name: cinema-studio-post
description: >
  Post-production editing toolkit for Wemio Cinema Studio output. Repairs
  common Seedance/Kling generation imperfections without re-generating the
  whole clip (cheaper + faster). Covers: time-range trimming, middle-section
  splicing, speed ramping, crossfading between clips, freeze-frame holds,
  inserting black cut-to-black, jump-cut removal of boring frames, reorder
  clip sequence, mute audio sections, replace audio track, and batch apply
  an edit decision list (EDL).

  When to use:
    - Gemini audit flagged a 2-3 second bad segment in a clip (unscripted
      dialog, inserted shot, glitch): trim it out instead of re-generating
    - Two adjacent clips have jarring cut: add a crossfade
    - A clip has dead time at the end or beginning: trim
    - Character says wrong line mid-clip: mute that 2s range
    - Need to rearrange clip order without re-concatenating from scratch

  Do NOT use for:
    - Re-generating content (use cinema-studio-produce or Seedance/Kling skill)
    - Asset generation (image/audio/video gen — use Cinema Studio UI)
    - Color grading / LUT work (ffmpeg can do this but skill doesn't wrap it yet)

argument-hint: "[trim|splice|speed|crossfade|freeze|insert-black|jumpcut|reorder|mute|swap-audio|batch] <input> [args]"
allowed-tools: Bash, Read, Write
---

# Cinema Studio Post — Editing Toolkit

Standalone skill for local-only video post-processing. All operations run
via `ffmpeg` on files already downloaded from Wemio CDN. Output is
frame-accurate where ffmpeg allows.

## Tool catalog

All tools are in `tools/` and take positional args:

### 1. `trim.sh` — Cut out time range(s)
Remove one or multiple unwanted ranges from a clip, seamlessly stitch the
remainder. Good for "Gemini flagged 7.3-9.1s as unscripted".

```bash
tools/trim.sh <input.mp4> <output.mp4> <cut-range-1> [<cut-range-2> ...]
# ranges in format "START-END" in seconds, e.g. "7.3-9.1"
# Example: remove 7.3-9.1s AND 11.5-12.0s from a 15s clip
tools/trim.sh in.mp4 out.mp4 7.3-9.1 11.5-12.0
```

### 2. `splice.sh` — Extract a subclip
Save a specific range as a new clip. Good for pulling "the good 8 seconds"
out of a 15s clip that has 7s of garbage at end.

```bash
tools/splice.sh <input.mp4> <output.mp4> <START-END>
# Example: keep only 0-8s
tools/splice.sh in.mp4 out.mp4 0-8
```

### 3. `speed.sh` — Speed up or slow down a section
Good for "the cut-to-black transition is too fast" or "slow motion the
falling phone".

```bash
tools/speed.sh <input.mp4> <output.mp4> <rate> [<range-to-apply>]
# rate > 1.0 = faster; rate < 1.0 = slower
# range is optional; omit to apply to whole clip
# Example: slow shot 2 (5-10s) to half speed
tools/speed.sh in.mp4 out.mp4 0.5 5-10
```

### 4. `crossfade.sh` — Smooth transition between 2 clips
Adds an N-second crossfade at the boundary instead of hard cut.

```bash
tools/crossfade.sh <clipA.mp4> <clipB.mp4> <output.mp4> <duration_s>
# Example: 0.5s crossfade from s1 to s2
tools/crossfade.sh s1.mp4 s2.mp4 s1_s2.mp4 0.5
```

### 5. `freeze.sh` — Hold a frame for N seconds
For emphasis on a reveal ("suspense lock on reveal frame for 1s before
cut to black").

```bash
tools/freeze.sh <input.mp4> <output.mp4> <timestamp_s> <hold_duration_s>
# Example: freeze frame at 14s for 0.5s
tools/freeze.sh in.mp4 out.mp4 14.0 0.5
```

### 6. `insert-black.sh` — Insert black frames at a timestamp
For cut-to-black transitions mid-clip or adding dramatic pauses.

```bash
tools/insert-black.sh <input.mp4> <output.mp4> <timestamp_s> <duration_s>
# Example: insert 0.5s black at 5s boundary
tools/insert-black.sh in.mp4 out.mp4 5.0 0.5
```

### 7. `jumpcut.sh` — Remove boring frames to create jump cut effect
Samples every Nth frame from a range to compress dead time.

```bash
tools/jumpcut.sh <input.mp4> <output.mp4> <range> <keep_ratio>
# keep_ratio 0.3 = keep 30% of frames in the range
# Example: compress dead time in 5-10s to 30%
tools/jumpcut.sh in.mp4 out.mp4 5-10 0.3
```

### 8. `reorder.sh` — Concat clips in specified order
Like the cinema-studio-ops concat but takes an explicit order arg.

```bash
tools/reorder.sh <output.mp4> <clip1> <clip2> <clip3> ...
# Example: swap s3 and s4 in a production
tools/reorder.sh final.mp4 s1.mp4 s2.mp4 s4.mp4 s3.mp4
```

### 9. `mute.sh` — Silence audio in a time range
Removes audio from a range without affecting video. Good for unscripted
dialog that Seedance added — mute the bad words, keep the visual.

```bash
tools/mute.sh <input.mp4> <output.mp4> <START-END>
# Example: mute 5.0-7.3s where unscripted line leaked
tools/mute.sh in.mp4 out.mp4 5.0-7.3
```

### 10. `swap-audio.sh` — Replace audio track with a different one
Useful when video is fine but dialog audio went wrong.

```bash
tools/swap-audio.sh <input.mp4> <new_audio.wav_or_mp3> <output.mp4>
```

### 11. `batch.sh` — Apply an EDL (edit decision list)
For complex fixes: combine multiple operations in one pass.

```bash
# EDL format (plain text, one op per line):
# trim 7.3-9.1
# mute 11.5-12.0
# speed 0.5 5-10
# insert-black 14.0 0.5

tools/batch.sh <input.mp4> <output.mp4> <edl.txt>
```

## Typical repair workflow (audit-driven)

```
Gemini audit → identifies bad range (e.g. "unscripted line 5.5-7.8s")
    ↓
decide: trim-out (bad segment removed) vs mute (keep visual, drop audio)
    ↓
run tools/trim.sh or tools/mute.sh
    ↓
re-audit the trimmed clip (Gemini) to confirm fix
    ↓
concat with neighbors via cinema-studio-ops
```

## Common repairs

| Bad | Fix | Tool |
|---|---|---|
| Unscripted 2s of dialog mid-clip | Trim that range | `trim.sh` |
| Inserted 1.5s shot not in script | Trim that range | `trim.sh` |
| Audio glitch on good visual | Mute the range | `mute.sh` |
| Bad ending 3s of clip | Splice out 0-12s | `splice.sh` |
| Two clips hard-cut jarring | 0.4s crossfade | `crossfade.sh` |
| Want suspense hold on reveal | Freeze the frame | `freeze.sh` |
| Cut-to-black too abrupt | Insert 0.3s black before | `insert-black.sh` |
| Dead time in middle | Jump cut that range | `jumpcut.sh` |
| Clip order wrong after re-shoot | Reorder | `reorder.sh` |

## Integration with cinema-studio-produce

`produce_pipeline.md` Phase I auto-fix can now call into this skill:
- On Gemini flagging a < 3s bad segment → `trim.sh` to cut it
- Cheaper than regenerating the whole clip
- Saves ~$0.85 + 5min per fix

The Phase I decision tree becomes:
```
audit reports bad segment
  ↓
segment < 3s AND localized → use cinema-studio-post trim/mute
segment > 3s OR spread → regenerate clip via cinema-studio-produce Phase G
```

## Reference files

- `tools/*.sh` — individual operation scripts
- All scripts use ffmpeg; require ffmpeg installed locally
- Tested on macOS with Homebrew ffmpeg; Linux should work identically

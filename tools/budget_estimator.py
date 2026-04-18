#!/usr/bin/env python3
"""
budget_estimator.py — predict credits + Gemini cost before a production.

Pricing reference (as of 2026-04-18, verify against models.yaml before use):
- seedance-2.0 @ 480p: 21 credits/s silent, 30 credits/s with sound
- seedance-2.0 @ 720p: ?  — look up models.yaml
- seedance-2.0 @ 1080p: ? — look up models.yaml
- seedance-2.0-fast @ 480p: 17 credits/s silent, 17 with sound
- kling-v3 @ 720p: ?
- kling-v3 @ 1080p: ?

Credit → USD conversion: depends on user tier.

Gemini 3.1 Pro:
- Phase 0b scene_blueprint: ~$0.005/scene
- Phase 2 audit_clip: ~$0.02-0.03/clip
- Phase 2 audit_full: ~$0.045 for 60s total
- Phase 3 auto-fix iterations: multiply Seedance cost by expected retry rate
  (empirically 1.3-1.6x for drama, 1.8x for anime)

Usage:
  python3 budget_estimator.py <num_clips> <duration_per_clip_s> <resolution> [--model seedance-2.0] [--with_sound] [--audit_full] [--auto_fix]

Output: JSON with credits, USD estimate, and breakdown lines.
"""
import argparse
import json

PRICING = {
    ("seedance-2.0", "480p"): {"silent": 21, "sound": 30},
    ("seedance-2.0", "720p"): {"silent": 27, "sound": 41},
    ("seedance-2.0", "1080p"): {"silent": 91, "sound": 91},
    ("seedance-2.0-fast", "480p"): {"silent": 17, "sound": 17},
    ("seedance-2.0-fast", "720p"): {"silent": 22, "sound": 22},
    ("kling-v3", "720p"): {"silent": 30, "sound": 30},
    ("kling-v3", "1080p"): {"silent": 41, "sound": 41},
}

GEMINI_PRICES = {
    "scene_blueprint_usd_per_scene": 0.005,
    "audit_clip_usd": 0.025,
    "audit_full_base_usd": 0.045,
    "audit_full_per_extra_15s_usd": 0.010,
}

AUTO_FIX_RETRY_MULTIPLIER = {
    "drama": 1.3,
    "action": 1.4,
    "anime": 1.8,  # anime often needs style retries + refs
    "romance": 1.3,
    "horror": 1.5,
    "mv": 1.4,
    "ugc": 1.2,
    "commercial": 1.4,
    "fantasy_scifi": 1.5,
    "default": 1.4,
}

CREDIT_TO_USD = 0.0125  # rough; user's actual rate may vary


def estimate(num_clips, duration_per_clip_s, model, resolution, with_sound,
             audit_full, auto_fix, num_unique_scenes, genre):
    key = (model, resolution)
    if key not in PRICING:
        raise ValueError(f"Unknown model/resolution: {key}")
    credit_rate = PRICING[key]["sound" if with_sound else "silent"]

    base_credits_per_clip = credit_rate * duration_per_clip_s
    base_credits = base_credits_per_clip * num_clips

    breakdown = [
        f"Model: {model} @ {resolution} ({'sound' if with_sound else 'silent'}) = {credit_rate} credits/s",
        f"Clips: {num_clips} x {duration_per_clip_s}s = {base_credits} credits",
    ]

    if auto_fix:
        mult = AUTO_FIX_RETRY_MULTIPLIER.get(genre, AUTO_FIX_RETRY_MULTIPLIER["default"])
        expected_credits = int(base_credits * mult)
        breakdown.append(f"Auto-fix retry ({genre} genre): x{mult} = {expected_credits} credits expected")
    else:
        expected_credits = base_credits

    # Gemini costs
    gemini_usd = 0.0
    if num_unique_scenes > 0:
        gemini_usd += num_unique_scenes * GEMINI_PRICES["scene_blueprint_usd_per_scene"]
        breakdown.append(f"Gemini scene_blueprint: {num_unique_scenes} scenes x $0.005 = ${num_unique_scenes * 0.005:.3f}")

    per_clip_audit_usd = num_clips * GEMINI_PRICES["audit_clip_usd"]
    gemini_usd += per_clip_audit_usd
    breakdown.append(f"Gemini audit_clip (per clip): {num_clips} x $0.025 = ${per_clip_audit_usd:.3f}")

    if audit_full:
        total_dur = num_clips * duration_per_clip_s
        extra_15s = max(0, (total_dur - 60) / 15)
        audit_full_usd = GEMINI_PRICES["audit_full_base_usd"] + extra_15s * GEMINI_PRICES["audit_full_per_extra_15s_usd"]
        gemini_usd += audit_full_usd
        breakdown.append(f"Gemini audit_full ({total_dur}s): ${audit_full_usd:.3f}")

    if auto_fix:
        # account for re-audit on retries
        extra_audit = (AUTO_FIX_RETRY_MULTIPLIER.get(genre, 1.4) - 1) * per_clip_audit_usd
        gemini_usd += extra_audit
        breakdown.append(f"Gemini re-audit during auto-fix: +${extra_audit:.3f}")

    total_usd = expected_credits * CREDIT_TO_USD + gemini_usd

    return {
        "genre": genre,
        "num_clips": num_clips,
        "duration_per_clip_s": duration_per_clip_s,
        "total_duration_s": num_clips * duration_per_clip_s,
        "model": model,
        "resolution": resolution,
        "with_sound": with_sound,
        "expected_credits": int(expected_credits),
        "expected_credits_usd": round(expected_credits * CREDIT_TO_USD, 2),
        "gemini_usd": round(gemini_usd, 3),
        "total_usd": round(total_usd, 2),
        "breakdown": breakdown,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--num-clips", type=int, required=True)
    ap.add_argument("--duration", type=int, default=15, help="seconds per clip")
    ap.add_argument("--model", default="seedance-2.0")
    ap.add_argument("--resolution", default="480p")
    ap.add_argument("--sound", action="store_true")
    ap.add_argument("--audit-full", action="store_true", help="include audit_full on concatenated mp4")
    ap.add_argument("--auto-fix", action="store_true", help="include auto-fix retry budget")
    ap.add_argument("--unique-scenes", type=int, default=1, help="number of unique locations (for scene_blueprint)")
    ap.add_argument("--genre", default="drama")
    args = ap.parse_args()

    estimate_d = estimate(
        num_clips=args.num_clips,
        duration_per_clip_s=args.duration,
        model=args.model,
        resolution=args.resolution,
        with_sound=args.sound,
        audit_full=args.audit_full,
        auto_fix=args.auto_fix,
        num_unique_scenes=args.unique_scenes,
        genre=args.genre,
    )
    print(json.dumps(estimate_d, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()

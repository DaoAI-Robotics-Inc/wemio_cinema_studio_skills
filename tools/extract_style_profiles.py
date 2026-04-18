#!/usr/bin/env python3
"""
extract_style_profiles.py — for each genre bucket, compute a style profile:
- median char length of prompts
- preferred format (among a set of markers) by frequency
- typical shot count per 15s indicated by number of [00:XX-YY] or 0-X秒: markers
- signature camera moves (top-N frequent terms from a predefined palette)
- typical lighting / mood descriptors

Usage:
  python3 extract_style_profiles.py [input_dir=corpus/by-genre]

Output: prints markdown table to stdout, suitable for pasting into SKILL.md.
"""
import json
import os
import re
import sys
import statistics
from collections import Counter

# Format markers we look for in prompt content
FORMAT_MARKERS = {
    "bracket_time_hhmmss": re.compile(r"\[\d{2}:\d{2}-\d{2}:\d{2}\]"),
    "bracket_time_seconds": re.compile(r"\[\d+s?-\d+s?\]"),
    "colon_time_seconds": re.compile(r"\b\d+-\d+\s*秒[:：]"),
    "shot_label": re.compile(r"Shot\s*\d+[:：]"),
    "mirror_label": re.compile(r"镜头\s*\d+[:：]"),
    "cut_to_english": re.compile(r"\bCut\s+to\b", re.I),
    "cut_to_chinese": re.compile(r"切到|切至|切换到"),
}

CAMERA_MOVES = [
    # Chinese cinematography terms
    "推镜", "拉镜", "升降", "摇臂", "跟拍", "俯视", "仰视", "平视",
    "子弹时间", "慢动作", "延时摄影", "抽帧", "定格", "长镜头",
    "一镜到底", "手持", "特写", "中景", "全景", "远景", "俯拍",
    "过肩", "推进", "拉远", "环绕", "升空", "下压",
    # English
    "close-up", "ecu", "wide shot", "establishing", "pan", "tilt", "dolly",
    "push in", "pull back", "crane", "steadicam", "handheld", "slow motion",
    "bullet time", "tracking", "overhead", "low angle", "high angle",
    "over the shoulder", "ots",
]

LIGHTING_MOODS = [
    # Chinese
    "冷色调", "暖色调", "高对比", "低照度", "霓虹", "霓虹光", "夜景",
    "黄金时刻", "蓝调时刻", "阴郁", "复古", "胶片感", "自然光",
    "钨丝灯", "荧光", "雾气", "薄雾", "烟雾",
    # English
    "neon", "golden hour", "blue hour", "overcast", "desaturated", "teal",
    "amber", "moody", "noir lighting", "chiaroscuro", "backlit", "rim light",
    "bokeh", "grain", "film grain", "tungsten", "fluorescent", "mist", "fog",
]


def count_markers(text: str, pattern_dict: dict[str, re.Pattern]) -> dict[str, int]:
    return {name: len(p.findall(text)) for name, p in pattern_dict.items()}


def shot_count_per_prompt(text: str) -> int:
    """Best-effort: count shot segments by any of our format markers."""
    counts = count_markers(text, FORMAT_MARKERS)
    # shot_label and mirror_label are per-shot markers; bracket_time is per-segment
    per_shot = max(counts["shot_label"], counts["mirror_label"])
    per_segment = max(counts["bracket_time_hhmmss"],
                      counts["bracket_time_seconds"],
                      counts["colon_time_seconds"])
    return max(per_shot, per_segment)


def vocab_hits(text: str, vocab: list[str]) -> Counter:
    c = Counter()
    tl = text.lower()
    for term in vocab:
        n = tl.count(term.lower())
        if n > 0:
            c[term] = n
    return c


def analyze(items: list[dict]) -> dict:
    lengths = []
    format_totals = Counter()
    shot_counts = []
    camera_counter = Counter()
    lighting_counter = Counter()

    for e in items:
        content = e.get("content") or ""
        lengths.append(len(content))

        marks = count_markers(content, FORMAT_MARKERS)
        for name, n in marks.items():
            if n > 0:
                format_totals[name] += 1

        sc = shot_count_per_prompt(content)
        if sc > 0:
            shot_counts.append(sc)

        for t, n in vocab_hits(content, CAMERA_MOVES).items():
            camera_counter[t] += n
        for t, n in vocab_hits(content, LIGHTING_MOODS).items():
            lighting_counter[t] += n

    return {
        "count": len(items),
        "length_median": int(statistics.median(lengths)) if lengths else 0,
        "length_p25": int(statistics.quantiles(lengths, n=4)[0]) if len(lengths) >= 4 else 0,
        "length_p75": int(statistics.quantiles(lengths, n=4)[2]) if len(lengths) >= 4 else 0,
        "preferred_format": format_totals.most_common(3),
        "shot_count_median": int(statistics.median(shot_counts)) if shot_counts else 0,
        "top_camera_moves": camera_counter.most_common(8),
        "top_lighting_moods": lighting_counter.most_common(6),
    }


def print_table(profiles: dict):
    print("| Genre | N | 字数 P25-中-P75 | 主流格式 | 典型 shot 数 | 标志 camera moves | 标志 lighting/mood |")
    print("|---|---|---|---|---|---|---|")
    for genre in sorted(profiles.keys()):
        p = profiles[genre]
        fmt = ", ".join(f"{k}({v})" for k, v in p["preferred_format"][:2])
        cam = ", ".join(k for k, _ in p["top_camera_moves"][:5])
        lit = ", ".join(k for k, _ in p["top_lighting_moods"][:4])
        lens = f"{p['length_p25']}-{p['length_median']}-{p['length_p75']}"
        print(f"| {genre} | {p['count']} | {lens} | {fmt} | {p['shot_count_median']} | {cam} | {lit} |")
    print()
    print("**Detailed per-genre breakdowns:**")
    print()
    for genre in sorted(profiles.keys()):
        p = profiles[genre]
        print(f"### {genre}")
        print(f"- N = {p['count']}; char length p25/median/p75 = {p['length_p25']}/{p['length_median']}/{p['length_p75']}")
        fm = ", ".join(f"{k}={v}" for k, v in p["preferred_format"])
        print(f"- format marker freq: {fm}")
        print(f"- typical shot count per prompt: {p['shot_count_median']}")
        cm = ", ".join(f"{k}({v})" for k, v in p["top_camera_moves"][:8])
        print(f"- top camera vocab: {cm}")
        lm = ", ".join(f"{k}({v})" for k, v in p["top_lighting_moods"][:6])
        print(f"- top lighting/mood: {lm}")
        print()


def main():
    in_dir = sys.argv[1] if len(sys.argv) > 1 else "corpus/by-genre"
    profiles = {}
    for fname in sorted(os.listdir(in_dir)):
        if not fname.endswith(".jsonl"):
            continue
        genre = fname[:-len(".jsonl")]
        if genre == "other":
            continue
        items = []
        with open(os.path.join(in_dir, fname)) as f:
            for line in f:
                items.append(json.loads(line))
        profiles[genre] = analyze(items)
    print_table(profiles)


if __name__ == "__main__":
    main()

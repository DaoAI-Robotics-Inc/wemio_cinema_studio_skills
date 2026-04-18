#!/usr/bin/env python3
"""
bucket_corpus.py — classify Seedance 2.0 prompt corpus by genre.

Input: CSV with columns id,title,description,content,sourceLink,sourcePublishedAt,
       author,sourceMedia,sourceReferenceImages,sourceVideos
Output: corpus/by-genre/<genre>.jsonl — one JSON object per line with
        {id, title, description, content, author, sourceLink, score,
         length, matched_keywords}

Genres (keyword-based primary classification):
- drama        (noir, suspense, 短剧, detective, 悬疑, K-drama, 王家卫, 雨夜)
- anime        (anime, 动漫, MAPPA, shonen, 鬼灭, 火影, 哪吒, 黑神话)
- action       (fight, chase, parkour, combat, 格斗, 追逐, 枪战)
- romance      (romance, 恋爱, 初恋, confession, kiss, 暧昧, 告白)
- horror       (horror, 恐怖, 惊悚, 僵尸, ghost, creepy)
- mv           (MV, music video, rap, pop, K-pop, concert, 现场)
- ugc          (UGC, vlog, TikTok, selfie, influencer, 口播)
- commercial   (ad, commercial, brand, 广告, promotional, 带货)
- fantasy_scifi (fantasy, sci-fi, cyberpunk, 魔法, 科幻, 末日, 赛博朋克, 星际)
- other        (doesn't match any of above)

A prompt can match multiple genres; assigned to the one with highest
keyword score. Ties resolved by genre priority order above.

Usage:
  python3 bucket_corpus.py <csv_path> [output_dir]
"""
import csv
import json
import sys
import os
from collections import defaultdict

csv.field_size_limit(10**7)

GENRES = {
    "drama": [
        "noir", "suspense", "drama", "detective", "短剧", "悬疑", "侦探",
        "thriller", "k-drama", "王家卫", "wong kar", "雨夜", "悬案",
        "crime", "criminal", "mystery", "subway", "地铁", "cinematic",
        "melancholy", "moody", "art film", "艺术片", "文艺片",
    ],
    "anime": [
        "anime", "動畫", "动漫", "mappa", "ghibli", "shonen", "shojo",
        "一拳", "鬼灭", "火影", "海贼", "哪吒", "敖丙", "黑神话",
        "2d animation", "cel-shaded", "manga", "漫画风", "日漫",
        "anime screenshot", "日式动画",
    ],
    "action": [
        "fight", "combat", "parkour", "chase", "kick", "punch", "kung fu",
        "格斗", "打斗", "追逐", "枪战", "武打", "搏斗", "武术",
        "action sequence", "action choreography", "高速", "极速",
        "车技", "赛车", "racing", "overtake",
    ],
    "romance": [
        "romance", "romantic", "恋爱", "初恋", "confession", "告白",
        "kiss", "拥吻", "暧昧", "甜蜜", "cute couple", "love story",
        "纯爱", "青春", "校园", "first love", "meet cute",
    ],
    "horror": [
        "horror", "恐怖", "惊悚", "zombie", "僵尸", "ghost", "鬼",
        "creepy", "阴森", "血腥", "gore", "nightmare", "噩梦",
        "haunted", "demon", "possess", "jump scare", "灵异",
    ],
    "mv": [
        " mv ", "music video", "音乐录影", "rap video", "k-pop", "pop music",
        "concert", "演唱会", "音乐", "song", "lyric", "歌词", "rhythm",
        "beat drop", "dance video", "rapper", "singer", "歌手",
    ],
    "ugc": [
        "ugc", "vlog", "tiktok", "selfie", "自拍", "influencer", "博主",
        "口播", "测评", "开箱", "带货", "直播", "live stream",
        "handheld phone", "phone camera", "竖屏", "vertical video",
        "pseudo-documentary", "伪纪录片",
    ],
    "commercial": [
        "commercial", "brand", "brand promotional", "广告", "品牌",
        "promotional", "产品广告", "商业", "tvc", "ad spot",
        "product launch", "product demo", "logo reveal", "动态图形",
        "motion graphic", "mg 动画",
    ],
    "fantasy_scifi": [
        "fantasy", "sci-fi", "science fiction", "cyberpunk", "赛博朋克",
        "魔法", "magic", "wizard", "dragon", "龙", "科幻", "末日",
        "apocalypse", "post-apocalyptic", "starship", "宇宙", "星际",
        "space", "alien", "mecha", "机甲", "dystopia", "乌托邦",
    ],
}

# Priority order when multiple genres tie — higher = more specific
GENRE_PRIORITY = [
    "anime", "horror", "mv", "ugc", "commercial",
    "action", "romance", "fantasy_scifi", "drama", "other",
]


def score_text(text: str, keywords: list[str]) -> tuple[int, list[str]]:
    t = text.lower()
    matched = []
    score = 0
    for kw in keywords:
        kw_l = kw.lower()
        if kw_l in t:
            matched.append(kw)
            score += 1
    return score, matched


def classify(row: dict) -> tuple[str, int, list[str]]:
    text = " ".join([
        row.get("title", "") or "",
        row.get("description", "") or "",
        row.get("content", "") or "",
    ])
    scores: dict[str, tuple[int, list[str]]] = {}
    for genre, keywords in GENRES.items():
        s, m = score_text(text, keywords)
        if s > 0:
            scores[genre] = (s, m)

    if not scores:
        return "other", 0, []

    # Rank by score, tie-break by priority
    priority = {g: i for i, g in enumerate(GENRE_PRIORITY)}
    best = max(scores.items(), key=lambda kv: (kv[1][0], -priority.get(kv[0], 999)))
    return best[0], best[1][0], best[1][1]


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    csv_path = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else "corpus/by-genre"
    os.makedirs(out_dir, exist_ok=True)

    with open(csv_path) as f:
        rows = list(csv.DictReader(f))

    buckets: dict[str, list[dict]] = defaultdict(list)
    for r in rows:
        genre, score, matched = classify(r)
        entry = {
            "id": r.get("id"),
            "title": r.get("title"),
            "description": r.get("description"),
            "content": r.get("content"),
            "author": r.get("author"),
            "sourceLink": r.get("sourceLink"),
            "length": len(r.get("content", "") or ""),
            "score": score,
            "matched_keywords": matched,
        }
        buckets[genre].append(entry)

    # Sort each bucket by score (desc) then length (desc) for quality signal
    for genre, items in buckets.items():
        items.sort(key=lambda e: (-e["score"], -e["length"]))
        path = os.path.join(out_dir, f"{genre}.jsonl")
        with open(path, "w") as f:
            for entry in items:
                f.write(json.dumps(entry, ensure_ascii=False) + "\n")
        print(f"{genre:16s} {len(items):5d} items  -> {path}")

    total = sum(len(v) for v in buckets.values())
    print(f"\nTotal rows: {total}")
    print(f"Corpus size CSV rows: {len(rows)}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
emit_examples.py — render top-N prompts per genre into examples-<genre>.md
files for use by the Seedance/Kling skills.

Usage:
  python3 emit_examples.py [top_n=12] [input_dir=corpus/by-genre] [skill_dir=skills/script-to-video-seedance]
"""
import json
import os
import sys


def render_examples(genre: str, items: list[dict], top_n: int) -> str:
    out = [f"# {genre.title()} — Seedance 2.0 Prompt Examples",
           "",
           "Corpus-derived reference prompts. Read before writing new prompts of "
           "this genre so the style, format, camera vocabulary, and pacing of "
           "your new prompt matches what Seedance 2.0 was trained to produce.",
           "",
           f"**Source:** YouMind community corpus — `{len(items)} total prompts "
           f"classified as {genre}, top {min(top_n, len(items))} shown.**",
           ""]
    for i, e in enumerate(items[:top_n], 1):
        out.append(f"## {i}. {e.get('title') or '(untitled)'}")
        out.append("")
        out.append(f"- **Length:** {e.get('length')} chars")
        out.append(f"- **Matched keywords:** `{', '.join(e.get('matched_keywords', []))}`")
        if e.get("author"):
            out.append(f"- **Author:** {e['author']}")
        if e.get("sourceLink"):
            out.append(f"- **Source:** {e['sourceLink']}")
        if e.get("description"):
            desc = e["description"][:300]
            out.append("")
            out.append(f"> {desc}{'…' if len(e['description']) > 300 else ''}")
        out.append("")
        out.append("### Prompt")
        out.append("")
        out.append("```")
        content = (e.get("content") or "").strip()
        # Truncate very long prompts to keep the examples file readable
        if len(content) > 3000:
            out.append(content[:3000])
            out.append(f"... (truncated, full {len(content)} chars)")
        else:
            out.append(content)
        out.append("```")
        out.append("")
        out.append("---")
        out.append("")
    return "\n".join(out)


def main():
    top_n = int(sys.argv[1]) if len(sys.argv) > 1 else 12
    in_dir = sys.argv[2] if len(sys.argv) > 2 else "corpus/by-genre"
    skill_dir = sys.argv[3] if len(sys.argv) > 3 else "skills/script-to-video-seedance"

    for fname in sorted(os.listdir(in_dir)):
        if not fname.endswith(".jsonl"):
            continue
        genre = fname[:-len(".jsonl")]
        if genre == "other":
            continue  # don't emit an examples file for unmatched prompts
        items = []
        with open(os.path.join(in_dir, fname)) as f:
            for line in f:
                items.append(json.loads(line))
        body = render_examples(genre, items, top_n)
        out_path = os.path.join(skill_dir, f"examples-{genre}.md")
        with open(out_path, "w") as f:
            f.write(body)
        print(f"{genre:16s} {len(items):5d} items  -> {out_path}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Post-process the standalone HTML pandoc builds from report/*.md.

Two things pandoc's HTML writer has no built-in option for:
  1. Long code/output blocks (script listings, terminal transcripts) take up a lot
     of vertical space. Blocks longer than LINE_THRESHOLD lines are wrapped in
     <details><summary> so they render collapsed by default.
  2. The output file lives at the repo root (so GitHub Pages can serve it with
     zero config, "branch: main, folder: /"), while the source .md files (and the
     images they reference) stay in report/. Image paths are rewritten accordingly.

Usage: python3 postprocess-html.py <path-to.html>
"""
import re
import sys

LINE_THRESHOLD = 10

SOURCECODE_BLOCK = re.compile(
    r'<div class="sourceCode" id="([^"]+)">.*?</div>', re.DOTALL
)
PLAIN_PRE_BLOCK = re.compile(r"<pre>\s*<code>.*?</code>\s*</pre>", re.DOTALL)


def count_lines(block: str) -> int:
    span_lines = re.findall(r'<span id="cb\d+-\d+"', block)
    if span_lines:
        return len(span_lines)
    inner = re.search(r"<code>(.*?)</code>", block, re.DOTALL)
    text = inner.group(1) if inner else block
    return text.count("\n") + 1


def fold_if_long(match: re.Match) -> str:
    block = match.group(0)
    lines = count_lines(block)
    if lines <= LINE_THRESHOLD:
        return block
    return (
        f'<details><summary>Vis kode ({lines} linjer)</summary>\n'
        f"{block}\n"
        f"</details>"
    )


def fix(path: str) -> None:
    with open(path, "r", encoding="utf-8") as f:
        html = f.read()

    html = SOURCECODE_BLOCK.sub(fold_if_long, html)
    html = PLAIN_PRE_BLOCK.sub(fold_if_long, html)
    html = html.replace('src="screenshots/', 'src="report/screenshots/')

    with open(path, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"post-processed {path}")


if __name__ == "__main__":
    fix(sys.argv[1])

#!/usr/bin/env python3
"""Post-process an .odt built by pandoc from reference.odt.

pandoc's --reference-doc controls most styling, but a few things it always
regenerates fresh into content.xml regardless of the reference doc:
  1. The font for inline code spans (hardcoded to "Courier New").
  2. Table cell styles ("TableHeaderRowCell"/"TableRowCell"), always with
     fo:border="none" and no background, i.e. invisible table borders.
  3. --toc always inserts the Table of Contents immediately after the title
     block, with no way to put a page break or a heading there from the
     markdown source (the ToC isn't part of the parsed body content). Fixed
     by inserting an invisible paragraph (style "PageBreakBeforeToc") and a
     visible "Indholdsfortegnelse" heading (style "TocHeading", both defined
     in reference.odt) directly before <text:table-of-content>.

This script fixes all of it after every build. Run after every:
    pandoc *.md -o ../aflevering.odt --toc --reference-doc=reference.odt

Usage: python3 postprocess-odt.py <path-to.odt>
"""
import sys
import zipfile
import re

ACCENT = "#1F4E79"
HEADER_BG = "#D9E2F3"

FONT_REPLACEMENTS = [
    (r"svg:font-family=\"'Courier New'\"", 'svg:font-family="Liberation Mono"'),
    (r"svg:font-family=\"&apos;Courier New&apos;\"", 'svg:font-family="Liberation Mono"'),
    (r"fo:font-family=\"'Courier New'\"", 'fo:font-family="Liberation Mono"'),
    (r"fo:font-family=\"&apos;Courier New&apos;\"", 'fo:font-family="Liberation Mono"'),
]

TABLE_REPLACEMENTS = [
    (
        '<style:style style:name="TableHeaderRowCell" style:family="table-cell">\n'
        '      <style:table-cell-properties fo:border="none" />\n'
        '    </style:style>',
        '<style:style style:name="TableHeaderRowCell" style:family="table-cell">\n'
        f'      <style:table-cell-properties fo:border="0.5pt solid {ACCENT}"\n'
        f'      fo:background-color="{HEADER_BG}" fo:padding="0.04in" />\n'
        '    </style:style>',
    ),
    (
        '<style:style style:name="TableRowCell" style:family="table-cell">\n'
        '      <style:table-cell-properties fo:border="none" />\n'
        '    </style:style>',
        '<style:style style:name="TableRowCell" style:family="table-cell">\n'
        '      <style:table-cell-properties fo:border="0.5pt solid #BFBFBF"\n'
        '      fo:padding="0.04in" />\n'
        '    </style:style>',
    ),
]


def fix(path):
    with zipfile.ZipFile(path, "r") as zin:
        items = {info.filename: (info, zin.read(info.filename)) for info in zin.infolist()}

    for name in ("content.xml", "styles.xml"):
        if name not in items:
            continue
        info, data = items[name]
        text = data.decode("utf-8")
        for pattern, repl in FONT_REPLACEMENTS:
            text = re.sub(pattern, repl, text)
        for old, new in TABLE_REPLACEMENTS:
            text = text.replace(old, new)
        if name == "content.xml" and "<text:table-of-content" in text:
            text = text.replace(
                "<text:table-of-content",
                '<text:p text:style-name="PageBreakBeforeToc" />'
                '<text:p text:style-name="TocHeading">Indholdsfortegnelse</text:p>'
                "<text:table-of-content",
                1,
            )
        items[name] = (info, text.encode("utf-8"))

    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as zout:
        mimetype_info, mimetype_data = items.pop("mimetype")
        zout.writestr(mimetype_info, mimetype_data, compress_type=zipfile.ZIP_STORED)
        for name, (info, data) in items.items():
            zout.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED)

    print(f"post-processed {path}")


if __name__ == "__main__":
    fix(sys.argv[1])

#!/usr/bin/env python3
"""Build the Vercel storefront mirror from the canonical single-file
store page (html_build/store.html).

Why: the Vercel connector passes deployment arguments on a command
line, so a 1.16 MB single file with embedded base64 images cannot be
deployed through it. The mirror externalizes the 3 embedded images
as separate files (recompressed to web weight) and rewrites the
<img> srcs. Copy/text is identical to the canonical page; only the
image encoding differs. Re-run after any edit to store.html.

Output: site/store.html + site/assets/store_*.jpg
"""
import base64
import io
import pathlib
import re

from PIL import Image

ROOT = pathlib.Path.home() / "workspace/rich_gang_ai"
SRC = ROOT / "html_build/store.html"
OUT_DIR = ROOT / "site"
ASSETS = OUT_DIR / "assets"
ASSETS.mkdir(exist_ok=True)

# (output name, max width, jpeg quality) per embedded image, in order.
PLAN = [
    ("store_boardroom.jpg", 1000, 56),
    ("store_kelly.jpg", None, None),  # already web-weight, keep bytes
    ("store_poster.jpg", 1000, 54),
]

html = SRC.read_text()
matches = list(re.finditer(r'data:image/[^;]+;base64,([A-Za-z0-9+/=]+)', html))
assert len(matches) == len(PLAN), f"expected {len(PLAN)} images, found {len(matches)}"

# Replace from the end so offsets stay valid.
for m, (name, width, quality) in reversed(list(zip(matches, PLAN))):
    raw = base64.b64decode(m.group(1))
    if width is not None:
        im = Image.open(io.BytesIO(raw)).convert("RGB")
        if im.width > width:
            im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
        buf = io.BytesIO()
        im.save(buf, "JPEG", quality=quality, optimize=True)
        raw = buf.getvalue()
    (ASSETS / name).write_bytes(raw)
    html = html[: m.start()] + f"assets/{name}" + html[m.end():]
    print(f"{name}: {len(raw)//1024} KB")

(OUT_DIR / "store.html").write_text(html)
print("written", OUT_DIR / "store.html", len(html) // 1024, "KB")

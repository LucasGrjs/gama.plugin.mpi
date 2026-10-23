"""Animated GIF of a display saved by every rank of an MPI run: one picture per cycle, the ranks side by side.

Usage: python3 mpi_display.py <output dir of run_mpi.sh> <display name> [options]

The experiment plan must save the display, e.g. in the .xml:
    <Outputs><Output id="1" name="pi" framerate="1" width="630" height="360"/></Outputs>
Each rank then writes <output dir>/rank_<r>/snapshot/<display><n>-<cycle>.png.

Options:
  --out FILE        GIF to write (default: <output dir>/<display>.gif)
  --columns N       ranks per row (default: as square as possible)
  --gap PX          space between the ranks (default 12)
  --scale F         size of each rank's picture (default 1.0)
  --crop X0 Y0 X1 Y1  keep only this part (pixels) of each rank's picture
  --order R ...     ranks in the order they are placed, row by row (default 0 1 2 ...)
  --delay MS        time per cycle (default 400); the last cycle stays 3 s

Example (mpi_monte_carlo_pi, the 4 quadrants as one circle):
  python3 mpi_display.py out pi --crop 15 45 316 346 --order 1 0 2 3 --columns 2

Needs Pillow (pip install pillow).
"""
import argparse
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def font(size, bold=False):
    for name in (("DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"), ("Arial Bold.ttf" if bold else "Arial.ttf")):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("output_dir", type=Path)
    p.add_argument("display")
    p.add_argument("--out", type=Path)
    p.add_argument("--columns", type=int)
    p.add_argument("--gap", type=int, default=12)
    p.add_argument("--scale", type=float, default=1.0)
    p.add_argument("--crop", type=int, nargs=4, metavar=("X0", "Y0", "X1", "Y1"))
    p.add_argument("--order", type=int, nargs="+", metavar="R")
    p.add_argument("--delay", type=int, default=400)
    a = p.parse_args()

    found = {int(d.name.split("_")[1]): d for d in a.output_dir.glob("rank_*") if d.is_dir()}
    if not found:
        raise SystemExit(f"no rank_<r> folder in {a.output_dir}: run the model with run_mpi.sh")
    order = a.order or sorted(found)
    missing = [r for r in order if r not in found]
    if missing:
        raise SystemExit(f"--order: no folder for rank(s) {missing} in {a.output_dir}")
    ranks = [found[r] for r in order]
    pattern = re.compile(rf"^{re.escape(a.display)}\d*-(\d+)\.png$")
    pictures = []  # per rank: {cycle: path}
    for d in ranks:
        found = {int(m.group(1)): f for f in (d / "snapshot").glob("*.png") if (m := pattern.match(f.name))}
        if not found:
            raise SystemExit(f"no picture of display '{a.display}' in {d / 'snapshot'}: add it to <Outputs> in the .xml")
        pictures.append(found)
    cycles = sorted(set.intersection(*(set(p) for p in pictures)))

    n = len(ranks)
    cols = a.columns or math.ceil(math.sqrt(n))
    rows = math.ceil(n / cols)
    first = Image.open(pictures[0][cycles[0]])
    if a.crop:
        first = first.crop(a.crop)
    w, h = int(first.width * a.scale), int(first.height * a.scale)
    bar, strip = 40, 20  # title bar; rank label above each picture
    title, label = font(18, bold=True), font(13, bold=True)

    frames = []
    for c in cycles:
        img = Image.new("RGB", (cols * w + (cols + 1) * a.gap, bar + rows * (strip + h) + (rows + 1) * a.gap), "white")
        d = ImageDraw.Draw(img)
        for i, pics in enumerate(pictures):
            tile = Image.open(pics[c]).convert("RGB")
            if a.crop:
                tile = tile.crop(a.crop)
            x = a.gap + (i % cols) * (w + a.gap)
            y = bar + a.gap + (i // cols) * (strip + h + a.gap)
            d.text((x, y + 2), ranks[i].name.replace("_", " "), font=label, fill="#555555")
            img.paste(tile.resize((w, h), Image.LANCZOS), (x, y + strip))
        d.rectangle([0, 0, img.width, bar], fill="#f2f2f2")
        d.text((12, 9), f"{a.display}: {n} ranks, cycle {c}", font=title, fill="#222222")
        frames.append(img.convert("P", palette=Image.ADAPTIVE, colors=128))

    out = a.out or a.output_dir / f"{a.display}.gif"
    frames[0].save(out, save_all=True, append_images=frames[1:], loop=0, optimize=True,
                   duration=[a.delay] * (len(frames) - 1) + [3000])
    print(f"{out}: {len(frames)} cycles, {n} ranks")


if __name__ == "__main__":
    main()

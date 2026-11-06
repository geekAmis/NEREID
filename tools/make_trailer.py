"""Assemble the NEREID README trailer from captured PNG frames.

Usage:
    python tools/make_trailer.py

Inputs:  _frames/menu_*.png, _frames/game_*.png, _frames/notebook_*.png
Outputs: docs/media/nereid-trailer.gif
         docs/media/nereid-trailer.mp4
         docs/media/nereid-menu.png
         docs/media/nereid-gameplay.png
         docs/media/nereid-notebook.png
"""

from __future__ import annotations

import glob
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
FRAMES = ROOT / "_frames"
MEDIA = ROOT / "docs" / "media"
MEDIA.mkdir(parents=True, exist_ok=True)

FONT_BOLD = ROOT / "game" / "assets" / "fonts" / "PT_Sans-Bold.ttf"
FONT_REG = ROOT / "game" / "assets" / "fonts" / "PT_Sans-Regular.ttf"
FONT_HAND = ROOT / "game" / "assets" / "fonts" / "Caveat.ttf"

W, H = 960, 540
FPS = 15
C_BONE = (222, 212, 176)
C_DIM = (128, 148, 136)
C_GREEN = (120, 210, 156)


def load(path: Path, size=(W, H)) -> Image.Image:
    im = Image.open(path).convert("RGB")
    return im.resize(size, Image.LANCZOS)


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(str(path), size)
    except OSError:
        return ImageFont.load_default()


def text_card(lines, seconds=1.6, accent=None):
    """Dark title card with a faint vignette and thin rules."""
    frames = []
    count = max(1, int(seconds * FPS))
    bg = Image.new("RGB", (W, H), (5, 10, 11))
    # subtle vertical gradient + vignette
    pix = bg.load()
    for y in range(H):
        for x in range(0, W, 4):
            v = int(4 + 8 * (1.0 - abs(y - H * 0.5) / (H * 0.5)))
            for xx in range(x, min(x + 4, W)):
                pix[xx, y] = (v, v + 3, v + 4)
    bg = bg.filter(ImageFilter.GaussianBlur(0.4))
    for i in range(count):
        im = bg.copy()
        d = ImageDraw.Draw(im, "RGBA")
        alpha = min(1.0, i / 5.0) * min(1.0, (count - i) / 5.0)
        title_f = font(FONT_BOLD, 86)
        sub_f = font(FONT_HAND, 42)
        meta_f = font(FONT_REG, 17)
        y = H // 2 - 90
        for j, line in enumerate(lines):
            f = title_f if j == 0 else (sub_f if j == 1 else meta_f)
            col = accent if (j == 0 and accent) else (C_BONE if j < 2 else C_DIM)
            bbox = d.textbbox((0, 0), line, font=f)
            tw = bbox[2] - bbox[0]
            th = bbox[3] - bbox[1]
            d.text(((W - tw) / 2, y), line, font=f, fill=(*col, int(255 * alpha)))
            y += th + (22 if j == 0 else 12)
        # thin rule
        d.line([(W * 0.34, H * 0.72), (W * 0.66, H * 0.72)], fill=(*C_DIM, int(110 * alpha)), width=1)
        frames.append(im)
    return frames


def read_frames(pattern: str, limit: int | None = None):
    paths = sorted(glob.glob(str(FRAMES / pattern)))
    if limit:
        paths = paths[:limit]
    return [load(Path(p)) for p in paths]


def add_grain(im: Image.Image, amount=3) -> Image.Image:
    # cheap deterministic noise, no numpy needed
    px = im.load()
    for y in range(0, H, 3):
        for x in range(0, W, 3):
            r, g, b = px[x, y]
            n = ((x * 13 + y * 7) % (amount * 2 + 1)) - amount
            px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))
    return im


def build():
    menu = read_frames("menu_*.png")
    game = read_frames("game_*.png")
    notebook = read_frames("notebook_*.png")
    if not menu or not game:
        raise SystemExit("No frames found in _frames/. Run the trailer scene first.")

    # Poster stills (full resolution crops from source frames).
    for name, src in (("nereid-menu.png", menu), ("nereid-gameplay.png", game), ("nereid-notebook.png", notebook)):
        if not src:
            continue
        source = sorted(glob.glob(str(FRAMES / {
            "nereid-menu.png": "menu_*.png",
            "nereid-gameplay.png": "game_*.png",
            "nereid-notebook.png": "notebook_*.png",
        }[name])))[min(len(src) - 1, max(0, len(src) // 2))]
        Image.open(source).convert("RGB").save(MEDIA / name, optimize=True)

    title = text_card(["NEREID", "последний сеанс"], 2.0, accent=C_BONE)
    menu_card = [Image.new("RGB", (W, H), (0, 0, 0))] * 3
    end_card = text_card(["СЛУШАЙ. НЕ ШУМИ.", "не отвечай"], 1.8, accent=C_GREEN)
    credits = text_card(["NEREID", "godot 4.7.2  ·  github.com/geekAmis/NEREID"], 1.8, accent=C_BONE)

    seq = []
    seq += title
    seq += menu_card
    seq += menu[:45]
    seq += menu_card
    seq += game
    seq += menu_card
    seq += notebook
    seq += menu_card
    seq += end_card
    seq += menu_card
    seq += credits

    # Short inline preview (<= 110 frames): title -> menu -> dolly -> notebook -> card.
    black2 = [Image.new("RGB", (W, H), (0, 0, 0))] * 2
    preview = []
    preview += title[:10]
    preview += black2
    preview += menu[:16]
    preview += black2
    preview += game[12:92:2]
    preview += black2
    preview += notebook[:10]
    preview += black2
    preview += end_card[:12]
    preview += black2
    preview += credits[:12]

    # Sub-sample for web formats: the source is ~20 fps, 10 fps is enough
    # for a slow cabin dolly and keeps the GIF/WebP small.
    web = [im.resize((800, 450), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.35)) for im in preview]
    web_fps = 10

    webp_path = MEDIA / "nereid-trailer.webp"
    web[0].save(
        webp_path,
        save_all=True,
        append_images=web[1:],
        duration=int(1000 / web_fps),
        loop=0,
        quality=58,
        method=6,
    )
    print(f"webp {webp_path}  {webp_path.stat().st_size / 1e6:.1f} MB")

    # GIF fallback: 560x315 / 48 colors / 10 fps.
    gif_frames = [im.resize((560, 315), Image.LANCZOS).quantize(
        colors=48, method=Image.MEDIANCUT, dither=Image.Dither.NONE) for im in web]
    gif_path = MEDIA / "nereid-trailer.gif"
    gif_frames[0].save(
        gif_path,
        save_all=True,
        append_images=gif_frames[1:],
        duration=int(1000 / web_fps),
        loop=0,
        optimize=True,
        disposal=2,
    )
    print(f"gif  {gif_path}  {gif_path.stat().st_size / 1e6:.1f} MB")

    # MP4 (requires imageio-ffmpeg).
    try:
        import imageio_ffmpeg

        mp4_path = MEDIA / "nereid-trailer.mp4"
        writer = imageio_ffmpeg.write_frames(
            str(mp4_path),
            (W, H),
            fps=FPS,
            codec="libx264",
            pix_fmt_in="rgb24",
            pix_fmt_out="yuv420p",
            output_params=["-crf", "20", "-preset", "medium", "-movflags", "+faststart"],
        )
        writer.send(None)
        for im in seq:
            writer.send(im.tobytes())
        writer.close()
        print(f"mp4  {mp4_path}  {mp4_path.stat().st_size / 1e6:.1f} MB")
    except Exception as exc:  # noqa: BLE001
        print(f"mp4 skipped: {exc}")

    print(f"frames: {len(seq)}  duration: {len(seq) / FPS:.1f}s")


if __name__ == "__main__":
    build()

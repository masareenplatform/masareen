import json
import os
import textwrap
import urllib.request
from datetime import datetime

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = os.path.dirname(os.path.abspath(__file__))
TV = os.path.join(ROOT, "tv")
SLIDES = os.path.join(ROOT, "bulletin-slides")
os.makedirs(TV, exist_ok=True)
os.makedirs(SLIDES, exist_ok=True)

news_url = "https://masareen.com/api/v1/news"
news_request = urllib.request.Request(
    news_url, headers={"User-Agent": "MASAREEN-Newsroom/1.0"})
with urllib.request.urlopen(news_request, timeout=30) as response:
    news = json.load(response)

allowed = {"Daily News Egypt", "Egypt Independent", "Enterprise"}
stories = [
    n for n in news
    if n.get("source_name") in allowed
    and n.get("title")
    and all(ord(c) < 128 for c in n.get("title", ""))
][:8]

font_dir = os.path.join(ROOT, "..", "..", "apps", "mobile", "assets", "fonts")
font_bold = ImageFont.truetype(os.path.join(font_dir, "Cairo-Bold.ttf"), 64)
font_medium = ImageFont.truetype(os.path.join(font_dir, "Cairo-Bold.ttf"), 30)
font_small = ImageFont.truetype(os.path.join(font_dir, "Cairo-Regular.ttf"), 22)
font_kicker = ImageFont.truetype(os.path.join(font_dir, "Cairo-Bold.ttf"), 18)

W, H = 1920, 1080
slides = []


def cover_image(url, target):
    if not url:
        return None
    try:
        request = urllib.request.Request(url, headers={"User-Agent": "MASAREEN/1.0"})
        with urllib.request.urlopen(request, timeout=25) as response:
            raw = response.read()
            if len(raw) < 5000:
                return None
            tmp = target + ".src"
            with open(tmp, "wb") as handle:
                handle.write(raw)
            image = Image.open(tmp).convert("RGB")
            image = ImageOps.fit(image, (W, H), method=Image.Resampling.LANCZOS)
            os.remove(tmp)
            return image
    except Exception:
        return None


def base_slide(image_url=None):
    image = cover_image(image_url, os.path.join(SLIDES, "input"))
    if image is None:
        image = Image.new("RGB", (W, H), (5, 8, 7))
        draw = ImageDraw.Draw(image)
        for y in range(H):
            ratio = y / H
            draw.line((0, y, W, y), fill=(5 + int(8 * ratio), 20 + int(30 * ratio), 16 + int(20 * ratio)))
    else:
        overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        od = ImageDraw.Draw(overlay)
        for y in range(H):
            ratio = y / H
            od.line((0, y, W, y), fill=(2, 10, 7, int(120 + 100 * ratio)))
        image = Image.alpha_composite(image.convert("RGBA"), overlay).convert("RGB")
    return image


def frame(image):
    draw = ImageDraw.Draw(image)
    draw.rectangle((72, 62, 132, 122), fill=(14, 107, 92))
    draw.text((86, 72), "M", font=font_bold, fill=(255, 255, 255))
    draw.text((150, 66), "MASAREEN", font=font_medium, fill=(255, 255, 255))
    draw.text((152, 104), "IMPACT INFRASTRUCTURE", font=font_small, fill=(201, 164, 92))
    draw.rounded_rectangle((1628, 68, 1848, 112), radius=22, fill=(180, 50, 38))
    draw.text((1660, 76), "● LIVE BULLETIN", font=font_kicker, fill=(255, 255, 255))
    return draw


def save(image, name):
    path = os.path.join(SLIDES, name)
    image.save(path, quality=92)
    slides.append(path)
    return path


# Opening title
opening = base_slide(stories[0].get("image_url") if stories else None)
draw = frame(opening)
draw.text((110, 690), "THE MASAREEN", font=font_kicker, fill=(201, 164, 92))
draw.multiline_text((108, 730), "NEWSROOM\nBULLETIN", font=font_bold, fill=(255, 255, 255), spacing=12)
draw.text((112, 960), datetime.now().strftime("%A, %d %B %Y"), font=font_medium, fill=(255, 255, 255))
save(opening, "00-title.png")

for index, story in enumerate(stories, 1):
    image = base_slide(story.get("image_url"))
    draw = frame(image)
    draw.rounded_rectangle((84, 590, 1300, 905), radius=26, fill=(3, 10, 8))
    draw.text((116, 620), story.get("source_name", "MASAREEN Newsroom").upper(),
              font=font_kicker, fill=(201, 164, 92))
    headline = textwrap.fill(story.get("title", ""), width=42)
    draw.multiline_text((116, 672), headline, font=font_bold, fill=(255, 255, 255), spacing=10)
    draw.text((116, 1030), "Verified context · MASAREEN.com", font=font_small, fill=(220, 230, 225))
    save(image, f"{index:02d}-story.png")

# Closing platform frame
closing = base_slide(None)
draw = frame(closing)
draw.text((110, 510), "ONE ENGINE.", font=font_kicker, fill=(201, 164, 92))
draw.multiline_text((108, 550), "VERIFIED IMPACT.\nPORTABLE VALUE.", font=font_bold, fill=(255, 255, 255), spacing=12)
draw.text((112, 760), "People · Entities · Evidence · Opportunities · MRC", font=font_medium, fill=(220, 230, 225))
save(closing, "99-closing.png")

concat = os.path.join(ROOT, "bulletin-concat.txt")
with open(concat, "w", encoding="utf-8") as handle:
    for index, path in enumerate(slides):
        safe = path.replace("'", "'\\''")
        duration = 8 if index == 0 else 7
        handle.write(f"file '{safe}'\nduration {duration}\n")
    handle.write(f"file '{slides[-1]}'\n")

voice_text = "MASAREEN Newsroom Live. " + " ".join(
    f"{story.get('source_name', 'Newsroom')}: {story.get('title', '')}." for story in stories
) + " MASAREEN. Connecting paths. Creating impact."
with open(os.path.join(ROOT, "bulletin-voice.txt"), "w", encoding="utf-8") as handle:
    handle.write(voice_text)

print(f"slides={len(slides)} stories={len(stories)}")

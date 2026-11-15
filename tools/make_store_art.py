# Builds the store images from in-game screenshots (tools/shoot_cover.gd) + our own Cinzel font + Kenney player sprite.
# Run:  python3 -I tools/make_store_art.py docs/store_art
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

out = sys.argv[1]
FONT = "assets/fonts/Cinzel.ttf"
shot = Image.open(f"{out}/cover_caverns.png").convert("RGB")


def titled(img, title_size, tag_size):
    w, h = img.size
    shade = Image.new("L", (1, h))
    for y in range(h):   # dark at the top so the title reads, clear lower down
        shade.putpixel((0, y), int(200 * max(0.0, 1.0 - y / (h * 0.55))))
    img = Image.composite(Image.new("RGB", img.size, (8, 6, 20)), img, shade.resize(img.size))
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    f = ImageFont.truetype(FONT, title_size)
    d.text((w / 2, h * 0.17), "RESILIENCE", font=f, anchor="mm", fill=(154, 108, 255, 255))
    glow = glow.filter(ImageFilter.GaussianBlur(title_size / 6))
    img = Image.alpha_composite(img.convert("RGBA"), glow)
    d = ImageDraw.Draw(img)
    d.text((w / 2, h * 0.17), "RESILIENCE", font=f, anchor="mm", fill=(242, 238, 255))
    d.text((w / 2, h * 0.17 + title_size * 0.85), "Every fall was another way forward.",
           font=ImageFont.truetype(FONT, tag_size), anchor="mm", fill=(190, 180, 225))
    return img.convert("RGB")


# itch.io cover 630x500 (and a 2x copy): crop the middle of the shot to 5:4
crop = shot.crop((190, 0, 1090, 720))
titled(crop.resize((1260, 1000), Image.NEAREST), 150, 40).save(f"{out}/cover_1260x1000.png")
titled(crop.resize((630, 500), Image.NEAREST), 76, 20).save(f"{out}/cover_630x500.png")
# voting-page thumbnail 1280x720
titled(shot, 150, 40).save(f"{out}/thumbnail_1280x720.png")

# icon 512x512: the explorer on a glowing purple disc
icon = Image.new("RGBA", (512, 512), (14, 10, 32, 255))
disc = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
ImageDraw.Draw(disc).ellipse((56, 56, 456, 456), fill=(120, 80, 230, 200))
icon = Image.alpha_composite(icon, disc.filter(ImageFilter.GaussianBlur(40)))
hero = Image.open("assets/kenney_pixel-platformer/Tiles/Characters/tile_0002.png").convert("RGBA")
hero = hero.resize((hero.width * 16, hero.height * 16), Image.NEAREST)
icon.alpha_composite(hero, ((512 - hero.width) // 2, (512 - hero.height) // 2 + 10))
mask = Image.new("L", (512, 512), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, 511, 511), 90, fill=255)
icon.putalpha(mask)
icon.save(f"{out}/icon_512.png")
icon.save("icon.png")   # the game's own window / export icon
print("ok")

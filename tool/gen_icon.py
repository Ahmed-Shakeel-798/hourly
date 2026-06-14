from PIL import Image, ImageDraw
import os

SS = 4           # supersampling factor
SIZE = 1024
S = SIZE * SS

INK = (17, 17, 17, 255)      # #111111
WHITE = (255, 255, 255, 255)

cx = cy = S / 2
R = 270 * SS                 # ring radius (kept inside adaptive safe zone)
STROKE = 36 * SS             # ring thickness
DOT_R = 50 * SS              # 12 o'clock dot radius
CORNER = 200 * SS            # rounded-square corner radius (legacy icon)


def draw_symbol(d):
    # ring
    d.ellipse([cx - R, cy - R, cx + R, cy + R], outline=WHITE, width=int(STROKE))
    # single dot at 12 o'clock (sits on the ring)
    dx, dy = cx, cy - R
    d.ellipse([dx - DOT_R, dy - DOT_R, dx + DOT_R, dy + DOT_R], fill=WHITE)


def make(path, with_bg):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if with_bg:
        d.rounded_rectangle([0, 0, S, S], radius=int(CORNER), fill=INK)
    draw_symbol(d)
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    img.save(path)
    print("wrote", path)


out = r"C:\dev\mobile_monitor\assets\icon"
os.makedirs(out, exist_ok=True)
# Full legacy icon: dark rounded-square bg + white mark
make(os.path.join(out, "icon.png"), with_bg=True)
# Adaptive foreground: transparent bg + white mark (bg color set in config)
make(os.path.join(out, "foreground.png"), with_bg=False)

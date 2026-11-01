"""Erzeugt das App-Symbol von tHAsk („Zeitbänder“) für Android und Windows.

Drei Balken wachsender Länge stehen für Tag, Woche und Monat; der kurze oberste (Tag) ist abgehakt.
Grundlage ist ein Raster von 96 × 96 Einheiten. Aufruf im Hauptordner:

    python tools/make_app_icon.py

Schreibt:
- app/windows/runner/resources/app_icon.ico (16 bis 256 px)
- app/android/app/src/main/res/mipmap-*/ic_launcher.png (ältere Launcher)
- app/android/app/src/main/res/drawable/ic_launcher_foreground.xml (Vektor für das adaptive Symbol)
- app/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
- custom_components/thask/brand/icon.png und icon@2x.png (Symbol der Integration in HA, ab 2026.3)
- custom_components/thask/www/thask-icons.js (einfarbiges Symbol `thask:logo` für die HA-Seitenleiste)
- app/android/app/src/main/res/drawable/ic_widget_open.xml (dasselbe für den Knopf „tHAsk öffnen“ im Widget)
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "app" / "android" / "app" / "src" / "main" / "res"

# HA-Blau (primary-color des Standard-Themes) und das Orange von warning-color für den Tag.
BLUE = "#03A9F4"
AMBER = "#FFC107"

# (x, y, Breite, Höhe, Farbe, Deckkraft) im 96er-Raster.
BARS = [
    (22, 26, 18, 10, AMBER, 1.0),
    (22, 43, 36, 10, "#FFFFFF", 1.0),
    (22, 60, 54, 10, "#FFFFFF", 0.7),
]
CHECK = [(50, 31), (56, 37), (69, 23)]
CHECK_WIDTH = 6.5
CORNER = 24

DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ICO_SIZES = [16, 20, 24, 32, 40, 48, 64, 128, 256]


def _rgba(color: str, opacity: float = 1.0) -> tuple[int, int, int, int]:
    color = color.lstrip("#")
    return (int(color[0:2], 16), int(color[2:4], 16), int(color[4:6], 16), round(255 * opacity))


def render(size: int, margin: float = 0.0) -> Image.Image:
    """Zeichnet das Symbol in `size` Pixeln; `margin` ist der freie Rand in 96er-Einheiten."""
    scale = 8  # überabtasten, dann verkleinern: glatte Kanten
    px = size * scale
    unit = px / (96 + 2 * margin)
    off = margin * unit

    def p(v: float) -> float:
        return off + v * unit

    image = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    ImageDraw.Draw(image).rounded_rectangle(
        (p(0), p(0), p(96), p(96)), radius=CORNER * unit, fill=_rgba(BLUE)
    )
    for x, y, w, h, color, opacity in BARS:
        layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).rounded_rectangle(
            (p(x), p(y), p(x + w), p(y + h)), radius=h / 2 * unit, fill=_rgba(color)
        )
        if opacity < 1:
            layer.putalpha(layer.getchannel("A").point(lambda a: round(a * opacity)))
        image = Image.alpha_composite(image, layer)
    draw = ImageDraw.Draw(image)
    points = [(p(x), p(y)) for x, y in CHECK]
    width = CHECK_WIDTH * unit
    draw.line(points, fill=_rgba("#FFFFFF"), width=round(width), joint="curve")
    for cx, cy in (points[0], points[-1]):
        r = width / 2
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=_rgba("#FFFFFF"))
    return image.resize((size, size), Image.LANCZOS)


def _rounded_rect_path(x: float, y: float, w: float, h: float, r: float) -> str:
    return (
        f"M{x + r:g},{y:g}h{w - 2 * r:g}a{r:g},{r:g} 0,0 1,0,{2 * r:g}"
        f"h{-(w - 2 * r):g}a{r:g},{r:g} 0,0 1,0,{-2 * r:g}z"
    )


def foreground_vector() -> str:
    """Vordergrund des adaptiven Symbols (108 dp, sichtbar sind die mittleren 72 dp)."""
    s, o = 0.75, 18  # 96 Einheiten auf 72 dp, 18 dp Rand

    def t(v: float) -> float:
        return round(o + v * s, 2)

    paths = []
    for x, y, w, h, color, opacity in BARS:
        d = _rounded_rect_path(t(x), t(y), round(w * s, 2), round(h * s, 2), round(h * s / 2, 2))
        alpha = f' android:fillAlpha="{opacity:g}"' if opacity < 1 else ""
        paths.append(f'    <path android:fillColor="{color}"{alpha} android:pathData="{d}" />')
    (x0, y0), (x1, y1), (x2, y2) = CHECK
    check = f"M{t(x0):g},{t(y0):g}L{t(x1):g},{t(y1):g}L{t(x2):g},{t(y2):g}"
    paths.append(
        f'    <path android:strokeColor="#FFFFFF" android:strokeWidth="{CHECK_WIDTH * s:g}"'
        ' android:strokeLineCap="round" android:strokeLineJoin="round"'
        f' android:pathData="{check}" />'
    )
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<!-- Erzeugt von tools/make_app_icon.py -->\n"
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:width="108dp" android:height="108dp"\n'
        '    android:viewportWidth="108" android:viewportHeight="108">\n'
        + "\n".join(paths)
        + "\n</vector>\n"
    )


def _capsule(x0: float, y0: float, x1: float, y1: float, r: float) -> str:
    """Strecke mit runden Enden als geschlossener Pfad; alle mit gleichem Umlaufsinn, damit sie sich vereinigen."""
    import math

    length = math.hypot(x1 - x0, y1 - y0) or 1
    nx, ny = -(y1 - y0) / length * r, (x1 - x0) / length * r

    def f(v: float) -> str:
        return f"{round(v, 2):g}"

    return (
        f"M{f(x0 + nx)} {f(y0 + ny)}L{f(x1 + nx)} {f(y1 + ny)}"
        f"A{f(r)} {f(r)} 0 0 0 {f(x1 - nx)} {f(y1 - ny)}"
        f"L{f(x0 - nx)} {f(y0 - ny)}A{f(r)} {f(r)} 0 0 0 {f(x0 + nx)} {f(y0 + ny)}Z"
    )


def sidebar_icon_path() -> str:
    """Balken und Haken ohne Hintergrund als ein Pfad im 24er-Raster (Material-Design-Icons-Format)."""
    left, right = BARS[0][0], max(x + w for x, _, w, _, _, _ in BARS)
    top, bottom = CHECK[2][1] - CHECK_WIDTH / 2, max(y + h for _, y, _, h, _, _ in BARS)
    s = 22 / max(right - left, bottom - top)
    ox = (24 - (right - left) * s) / 2 - left * s
    oy = (24 - (bottom - top) * s) / 2 - top * s
    parts = [
        _capsule(ox + (x + h / 2) * s, oy + (y + h / 2) * s, ox + (x + w - h / 2) * s, oy + (y + h / 2) * s, h / 2 * s)
        for x, y, w, h, _, _ in BARS
    ]
    for (ax, ay), (bx, by) in zip(CHECK, CHECK[1:]):
        parts.append(_capsule(ox + ax * s, oy + ay * s, ox + bx * s, oy + by * s, CHECK_WIDTH / 2 * s))
    return "".join(parts)


ICONS_JS = """// Erzeugt von tools/make_app_icon.py: Symbol `thask:logo` für die Seitenleiste von Home Assistant.
const ICONS = {{ logo: "{path}" }};
window.customIcons = window.customIcons || {{}};
window.customIcons.thask = {{
  getIcon: async (name) => ({{ path: ICONS[name] || ICONS.logo }}),
  getIconList: async () => Object.keys(ICONS).map((name) => ({{ name }})),
}};
"""


WIDGET_OPEN = """<?xml version="1.0" encoding="utf-8"?>
<!-- Erzeugt von tools/make_app_icon.py: tHAsk-Logo für den Knopf „tHAsk öffnen“ im Widget -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp"
    android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#FFFFFFFF" android:pathData="{path}" />
</vector>
"""

ADAPTIVE = """<?xml version="1.0" encoding="utf-8"?>
<!-- Erzeugt von tools/make_app_icon.py -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
"""

COLORS = f"""<?xml version="1.0" encoding="utf-8"?>
<!-- Erzeugt von tools/make_app_icon.py -->
<resources>
    <color name="ic_launcher_background">{BLUE}</color>
</resources>
"""


def main() -> None:
    ico = ROOT / "app" / "windows" / "runner" / "resources" / "app_icon.ico"
    images = [render(s) for s in ICO_SIZES]
    images[-1].save(ico, sizes=[(s, s) for s in ICO_SIZES], append_images=images[:-1], bitmap_format="png")
    for name, size in DENSITIES.items():
        render(size, margin=4).save(RES / f"mipmap-{name}" / "ic_launcher.png")
    (RES / "drawable" / "ic_launcher_foreground.xml").write_text(foreground_vector(), encoding="utf-8")
    (RES / "mipmap-anydpi-v26").mkdir(exist_ok=True)
    (RES / "mipmap-anydpi-v26" / "ic_launcher.xml").write_text(ADAPTIVE, encoding="utf-8")
    (RES / "values" / "ic_launcher_colors.xml").write_text(COLORS, encoding="utf-8")
    brand = ROOT / "custom_components" / "thask" / "brand"
    brand.mkdir(exist_ok=True)
    render(256).save(brand / "icon.png")
    render(512).save(brand / "icon@2x.png")
    icons_js = ROOT / "custom_components" / "thask" / "www" / "thask-icons.js"
    icons_js.write_text(ICONS_JS.format(path=sidebar_icon_path()), encoding="utf-8")
    (RES / "drawable" / "ic_widget_open.xml").write_text(WIDGET_OPEN.format(path=sidebar_icon_path()), encoding="utf-8")
    print("Symbole geschrieben.")


if __name__ == "__main__":
    main()

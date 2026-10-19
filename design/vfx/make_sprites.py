# Tiny Toy Heist VFX sprites: white-on-transparent particle textures and 4x4 flipbook sheets (tinted in Roblox by
# the emitter's Color). Pure numpy, so it runs with Blender's bundled Python:
#   "C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe" design/vfx/make_sprites.py
# Output: design/vfx/out/*.png. The coin flipbook is rendered in Blender proper (render_coin.py).
import math
import os
import struct
import zlib

import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def save(name, rgba):
    """rgba: HxWx4 float 0..1 -> PNG (straight alpha)."""
    a = np.clip(rgba, 0, 1)
    h, w, _ = a.shape
    data = (a * 255 + 0.5).astype(np.uint8)
    raw = b"".join(b"\x00" + data[y].tobytes() for y in range(h))

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(os.path.join(OUT, name + ".png"), "wb") as f:
        f.write(png)
    print("wrote", name, w, h)


def coords(n=256, m=None):
    m = m or n
    y, x = np.mgrid[0:m, 0:n]
    return (x + 0.5) / n * 2 - 1, (y + 0.5) / m * 2 - 1


def white(alpha, shade=None):
    s = np.ones_like(alpha) if shade is None else shade
    return np.dstack([s, s, s, alpha])


def smooth(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def sheet(frames, cells=4):
    rows = [np.concatenate(frames[r * cells : (r + 1) * cells], axis=1) for r in range(cells)]
    return np.concatenate(rows, axis=0)


def seg_dist(px, py, ax, ay, bx, by):
    vx, vy = bx - ax, by - ay
    t = np.clip(((px - ax) * vx + (py - ay) * vy) / (vx * vx + vy * vy + 1e-9), 0, 1)
    return np.hypot(px - (ax + t * vx), py - (ay + t * vy))


def fade_edge(x, y):
    # keep everything off the cell border so flipbook frames never bleed
    r = np.maximum(np.abs(x), np.abs(y))
    return 1 - smooth(0.9, 1.0, r)


# ---------------------------------------------------------------------------------------------------------------
# singles

x, y = coords()
r = np.hypot(x, y)
th = np.arctan2(y, x)

save("glow", white(np.exp(-r * r * 4.5) * (1 - smooth(0.7, 1, r))))

# 4-point sparkle with smaller diagonals and a hot core
def ray(u, v, width, length):
    t = np.clip(1 - np.abs(u) / length, 0, 1)
    return np.exp(-((v / (width * t + 1e-4)) ** 2)) * t**1.6


d1 = (x + y) / math.sqrt(2)
d2 = (x - y) / math.sqrt(2)
spark = np.maximum.reduce(
    [ray(x, y, 0.09, 1), ray(y, x, 0.09, 1), 0.55 * ray(d1, d2, 0.06, 0.55), 0.55 * ray(d2, d1, 0.06, 0.55)]
)
spark = np.maximum(spark, np.exp(-r * r * 30))
save("sparkle", white(np.clip(spark, 0, 1) * fade_edge(x, y)))

# soft ring
save("ring", white(np.exp(-(((r - 0.78) / 0.07) ** 2)) * (1 - smooth(0.92, 1, r))))

# 5-point star (filled, soft edge, slightly brighter centre)
k = 5
a0 = (th + math.pi / 2) % (2 * math.pi / k) - math.pi / k
inner, outer = 0.42, 0.95
# radius of the star outline at this angle (straight edges between the points)
tip = np.abs(a0) / (math.pi / k)
edge = outer * inner / (inner + (outer - inner) * tip + 1e-6) * (1 - 0.15 * tip)
starA = smooth(edge + 0.04, edge - 0.04, r)
save("star", white(starA * fade_edge(x, y), 0.85 + 0.15 * np.exp(-r * r * 6)))

# bubble: thin bright rim, faint inside, a highlight top-left
rim = np.exp(-(((r - 0.82) / 0.05) ** 2)) * 0.9
fill = (1 - smooth(0.8, 0.86, r)) * 0.12
hl = np.exp(-(((x + 0.35) ** 2 + (y + 0.4) ** 2) / 0.02)) * 0.95
save("bubble", white(np.clip(rim + fill + hl, 0, 1) * (1 - smooth(0.92, 1, r))))

# snowflake: 6 arms with 2 pairs of branches each
dist = np.full_like(x, 9.0)
for i in range(6):
    a = i * math.pi / 3 - math.pi / 2
    ca, sa = math.cos(a), math.sin(a)
    dist = np.minimum(dist, seg_dist(x, y, 0, 0, 0.9 * ca, 0.9 * sa))
    for along, ln in ((0.45, 0.28), (0.7, 0.18)):
        bx, by = along * ca, along * sa
        for s in (-1, 1):
            b = a + s * math.pi / 4
            dist = np.minimum(dist, seg_dist(x, y, bx, by, bx + ln * math.cos(b), by + ln * math.sin(b)))
flake = smooth(0.07, 0.035, dist) + 0.35 * np.exp(-((dist / 0.12) ** 2))
save("snowflake", white(np.clip(flake, 0, 1) * fade_edge(x, y)))

# heart (for "+1 toy" and Candy)
# two circles on top of a diamond, as a distance field (y is down in the image)
diamond = (np.abs(x) + y - 0.686) / math.sqrt(2)  # edges tangent to the lobes
lobes = np.minimum(np.hypot(x + 0.36, y + 0.24), np.hypot(x - 0.36, y + 0.24)) - 0.4
heart = np.minimum(np.where(y > -0.24, diamond, 9), lobes)
save("heart", white(smooth(0.015, -0.015, heart) * fade_edge(x, y)))

# beam texture (U along the beam, V across): bright core, soft sides
bx, by = coords(256, 128)
core = np.exp(-((by / 0.18) ** 2))
side = np.exp(-((by / 0.55) ** 2)) * 0.55
save("beam", white(np.clip(core + side, 0, 1)))

# screen vignette (stretched over the screen in a UI image), white, tinted in the UI
vx, vy = coords(512)
vr = np.hypot(vx * 0.95, vy)
save("vignette", white(smooth(0.55, 1.3, vr) ** 1.3))

# sunburst rays behind the reveal card: 14 rays fading out
vt = np.arctan2(vy, vx)
vr2 = np.hypot(vx, vy)
rays = ((0.5 + 0.5 * np.cos(14 * vt)) ** 2.5) * (1 - smooth(0.25, 1.0, vr2)) * smooth(0.0, 0.15, vr2)
rays = np.maximum(rays, np.exp(-vr2 * vr2 * 12) * 0.9)
save("rays", white(rays))

# ---------------------------------------------------------------------------------------------------------------
# flipbooks (4x4, 16 frames, 256 px cells -> 1024 sheet)

def ease_out(t, p=3):
    return 1 - (1 - t) ** p


# 1. starburst: spiky explosion that blasts out and hollows
spikes = [(rng.uniform(0, 2 * math.pi), rng.uniform(0.12, 0.22), rng.uniform(0.6, 1.0)) for _ in range(16)]
frames = []
for f in range(16):
    t = f / 15
    R = 0.4 + 0.58 * ease_out(t)
    prof = np.zeros_like(r)
    for a, w, L in spikes:
        da = np.angle(np.exp(1j * (th - a)))
        prof = np.maximum(prof, np.exp(-((da / w) ** 2)) * L)
    rb = R * (0.45 + 0.55 * prof)
    body = smooth(rb + 0.03, rb - 0.03, r)
    hole = smooth(R * 0.8 * t**1.2 - 0.05, R * 0.8 * t**1.2 + 0.05, r) if t > 0.15 else 1
    a = body * hole * (1 - t) ** 1.3
    a = np.maximum(a, np.exp(-((r / (0.35 * (1 - t) + 0.01)) ** 2)) * (1 - t) ** 2)
    frames.append(white(np.clip(a * 1.15, 0, 1) * fade_edge(x, y)))
save("burst_sheet", sheet(frames))

# 2. shockwave: a ring that blasts out and thins
frames = []
for f in range(16):
    t = f / 15
    R = 0.12 + 0.8 * ease_out(t, 2.5)
    w = 0.16 * (1 - t) + 0.02
    wob = 1 + 0.03 * np.sin(th * 7 + t * 3)
    a = np.exp(-(((r * wob - R) / w) ** 2)) * (1 - t) ** 1.1
    frames.append(white(a * fade_edge(x, y)))
save("shock_sheet", sheet(frames))

# 3. cartoon smoke puff: lumpy blob that grows and breaks up
def noise2(seed, scale):
    g = np.random.default_rng(seed).random((scale + 1, scale + 1))
    gx = (x + 1) / 2 * scale
    gy = (y + 1) / 2 * scale
    ix, iy = np.clip(gx.astype(int), 0, scale - 1), np.clip(gy.astype(int), 0, scale - 1)
    fx, fy = smooth(0, 1, gx - ix), smooth(0, 1, gy - iy)
    v00, v10, v01, v11 = g[iy, ix], g[iy, ix + 1], g[iy + 1, ix], g[iy + 1, ix + 1]
    return (v00 * (1 - fx) + v10 * fx) * (1 - fy) + (v01 * (1 - fx) + v11 * fx) * fy


nz = 0.6 * noise2(1, 6) + 0.4 * noise2(2, 12)
blobs = [(0.0, 0.05, 0.5)] + [(0.33 * math.cos(i * 1.047 + 0.3), 0.3 * math.sin(i * 1.047 + 0.3) + 0.05, rng.uniform(0.3, 0.4)) for i in range(6)]
frames = []
for f in range(16):
    t = f / 15
    grow = 0.7 + 0.55 * ease_out(t, 2)
    field = np.zeros_like(r)
    for bx0, by0, br in blobs:
        cx, cy = bx0 * grow, by0 * grow - 0.1 * t
        field = np.maximum(field, 1 - np.hypot(x - cx, y - cy) / (br * grow))
    thresh = 0.02 + 0.55 * t**1.5
    dens = field - thresh * (0.6 + 0.8 * nz)
    a = smooth(0.0, 0.06, dens) * (1 - t**3)
    shade = 0.78 + 0.22 * np.clip(-y * 0.8 + 0.4, 0, 1) - 0.12 * (1 - smooth(0.0, 0.25, dens))
    frames.append(white(a * fade_edge(x, y), shade))
save("puff_sheet", sheet(frames))

# 4. toon flame, loops: pointed teardrop, licks rising
frames = []
for f in range(16):
    t = f / 16
    yy = -y  # up is +
    h = (yy + 0.85) / 1.75  # 0 at the bottom, 1 at the tip
    wob = (0.05 * np.sin(h * 9 - t * 2 * math.pi * 2) + 0.03 * np.sin(h * 17 + t * 2 * math.pi * 3)) * (0.3 + h)
    u = x + wob
    width = 0.6 * np.clip(h * 3.2, 0, 1) ** 0.5 * np.clip(1 - h, 0, 1) ** 1.15
    body = smooth(width + 0.025, width - 0.025, np.abs(u)) * (h > 0)
    # a lick that breaks off and rises
    lh = (t * 0.5 + 0.7) % 1
    lick = smooth(0.09, 0.05, np.hypot(x - 0.1 * math.sin(t * 6.28), (yy - (-0.85 + 1.75 * lh)) * 0.7)) * (1 - lh) * (lh > 0.7)
    core = smooth(width * 0.5 + 0.025, width * 0.5 - 0.025, np.abs(u)) * (h < 0.55)
    shade = 0.62 + 0.38 * core
    frames.append(white(np.clip(np.maximum(body, lick), 0, 1) * fade_edge(x, y), shade))
save("flame_sheet", sheet(frames))

# 5. electric arcs: three jagged bolts out of the middle, new every frame
frames = []
for f in range(16):
    dist = np.full_like(x, 9.0)
    for b in range(3):
        a = rng.uniform(0, 2 * math.pi)
        px, py = 0.0, 0.0
        for s in range(7):
            a += rng.uniform(-0.7, 0.7)
            nx, ny = px + 0.13 * math.cos(a), py + 0.13 * math.sin(a)
            dist = np.minimum(dist, seg_dist(x, y, px, py, nx, ny))
            if s == 3:  # a fork
                fa = a + rng.choice([-1, 1]) * 0.9
                dist = np.minimum(dist, seg_dist(x, y, nx, ny, nx + 0.2 * math.cos(fa), ny + 0.2 * math.sin(fa)))
            px, py = nx, ny
    a = smooth(0.025, 0.01, dist) + 0.5 * np.exp(-((dist / 0.06) ** 2))
    frames.append(white(np.clip(a, 0, 1) * fade_edge(x, y)))
save("electric_sheet", sheet(frames))

# 6. vortex swirl, loops (rotates a third of a turn over 16 frames, 3 arms)
frames = []
for f in range(16):
    t = f / 16
    arms = (0.5 + 0.5 * np.cos(3 * th - 7 * r + t * 2 * math.pi)) ** 3
    a = arms * smooth(0.0, 0.25, r) * (1 - smooth(0.6, 0.95, r))
    frames.append(white(a * fade_edge(x, y)))
save("swirl_sheet", sheet(frames))

# 7. sparkle twinkle (a star that flashes in and out with a little spin), for confetti-ish glints
frames = []
for f in range(16):
    t = f / 15
    s = math.sin(math.pi * t)
    ang = t * math.pi / 4
    ca, sa = math.cos(ang), math.sin(ang)
    u, v = (x * ca - y * sa) / (s + 0.05), (x * sa + y * ca) / (s + 0.05)
    a = np.maximum(ray(u, v, 0.1, 1), ray(v, u, 0.1, 1)) * s
    a = np.maximum(a, np.exp(-(r / (0.18 * s + 0.01)) ** 2) * s)
    frames.append(white(np.clip(a, 0, 1) * fade_edge(x, y)))
save("twinkle_sheet", sheet(frames))

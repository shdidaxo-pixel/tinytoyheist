# Contact sheet of everything in out/ on a dark background (for review): out/_preview.png
import os, zlib, struct
import numpy as np
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
def load(p):
    d = open(p, "rb").read(); i = 8; idat = b""; w = h = 0
    while i < len(d):
        n = struct.unpack(">I", d[i:i+4])[0]; t = d[i+4:i+8]; c = d[i+8:i+8+n]
        if t == b"IHDR": w, h = struct.unpack(">II", c[:8])
        if t == b"IDAT": idat += c
        i += 12 + n
    raw = zlib.decompress(idat); stride = w*4+1
    rows = []; prev = np.zeros(w*4, np.int32)
    for y in range(h):
        f = raw[y*stride]; line = np.frombuffer(raw[y*stride+1:(y+1)*stride], np.uint8).astype(np.int32)
        if f == 0: cur = line
        elif f == 2: cur = (line + prev) & 255
        else:
            cur = np.zeros_like(line)
            for k in range(len(line)):
                a = cur[k-4] if k >= 4 else 0; b = prev[k]; c = prev[k-4] if k >= 4 else 0
                if f == 1: cur[k] = (line[k] + a) & 255
                elif f == 3: cur[k] = (line[k] + (a + b)//2) & 255
                else:
                    p = a + b - c; pa, pb, pc = abs(p-a), abs(p-b), abs(p-c)
                    pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c); cur[k] = (line[k] + pr) & 255
        rows.append(cur); prev = cur
    return np.array(rows, np.uint8).reshape(h, w, 4).astype(float) / 255
files = sorted(f for f in os.listdir(OUT) if f.endswith(".png") and not f.startswith("_"))
cell = 300
cols = 5
H = ((len(files)+cols-1)//cols) * cell
img = np.zeros((H, cols*cell, 3)); img[:] = (0.12, 0.09, 0.2)
tint = [(1,0.85,0.3),(0.7,0.4,1),(0.3,0.7,1),(1,0.35,0.4),(0.4,1,0.5)]
for i, f in enumerate(files):
    a = load(os.path.join(OUT, f)); h, w, _ = a.shape
    s = max(h, w) / 280; ys = (np.arange(int(h/s))*s).astype(int); xs = (np.arange(int(w/s))*s).astype(int)
    a = a[ys][:, xs]; col = np.array(tint[i % 5])
    oy = (i//cols)*cell + 10; ox = (i%cols)*cell + 10
    reg = img[oy:oy+a.shape[0], ox:ox+a.shape[1]]
    reg[:] = reg*(1-a[...,3:]) + a[...,:3]*col*a[...,3:]
img = (np.clip(img,0,1)*255).astype(np.uint8)
raw = b"".join(b"\x00"+img[y].tobytes() for y in range(img.shape[0]))
def chunk(t, d): c = struct.pack(">I", len(d))+t+d; return c+struct.pack(">I", zlib.crc32(t+d)&0xffffffff)
open(os.path.join(OUT, "_preview.png"), "wb").write(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR", struct.pack(">IIBBBBB", img.shape[1], img.shape[0], 8, 2, 0,0,0))+chunk(b"IDAT", zlib.compress(raw, 6))+chunk(b"IEND", b""))
print(files)

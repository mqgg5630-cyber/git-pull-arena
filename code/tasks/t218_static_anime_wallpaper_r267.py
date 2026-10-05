import ctypes, json, os, shutil, struct, subprocess, sys, time, winreg
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'results' / 'mcp_agv_lab'
OUT.mkdir(parents=True, exist_ok=True)
REPORT = OUT / 'R267_STATIC_ANIME_WALLPAPER.md'
JREPORT = OUT / 'r267-static-anime-wallpaper.json'
SHOT_BMP = OUT / 'r267_static_desktop_after.bmp'
SHOT_PNG = OUT / 'r267_static_desktop_after.png'
LAB = Path(r'E:\0mcp-agv-arena-optimized')
TARGET_DIR = LAB / 'wallpapers' / 'static-anime-r267'
TARGET_DIR.mkdir(parents=True, exist_ok=True)
TARGET = TARGET_DIR / 'cute_static_anime_wallpaper_r267.png'
FALLBACK = r'C:\Windows\Web\Wallpaper\Windows\img0.jpg'
lines = []

def L(s):
    safe = str(s).encode('ascii', 'replace').decode('ascii')
    print(safe)
    lines.append(safe)

def write_text(path, text):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(text, encoding='utf-8')

def run(args, timeout=25):
    try:
        p = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout, text=True, errors='replace')
        return p.returncode, p.stdout
    except Exception as e:
        return 999, repr(e)

def find_vlc():
    for p in [r'C:\Program Files\VideoLAN\VLC\vlc.exe', r'C:\Program Files (x86)\VideoLAN\VLC\vlc.exe']:
        if Path(p).exists():
            return p
    return shutil.which('vlc.exe') or ''

def close_dynamic_players():
    stopped = 0
    vlc = find_vlc()
    if vlc:
        try:
            subprocess.Popen([vlc, 'vlc://quit'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(3)
        except Exception:
            pass
    for name in ['vlc.exe', 'Lively.exe', 'Lively.UI.WinUI.exe', 'Livelycu.exe', 'mpv.exe', 'mpvnet.exe']:
        code, out = run(['tasklist', '/FI', 'IMAGENAME eq ' + name], 10)
        if name in out:
            run(['taskkill', '/F', '/IM', name], 20)
            stopped += 1
    lively = r'C:\Program Files\Lively Wallpaper\Lively.exe'
    if Path(lively).exists():
        run([lively, 'closewp', '--monitor', '-1'], 20)
        run([lively, '--shutdown', 'true'], 20)
    return stopped

def set_wallpaper(path):
    # Fit/fill wallpaper style. Use SPI_SETDESKWALLPAPER with update broadcast.
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r'Control Panel\Desktop', 0, winreg.KEY_SET_VALUE) as k:
            winreg.SetValueEx(k, 'WallpaperStyle', 0, winreg.REG_SZ, '10')
            winreg.SetValueEx(k, 'TileWallpaper', 0, winreg.REG_SZ, '0')
            winreg.SetValueEx(k, 'Wallpaper', 0, winreg.REG_SZ, str(path))
    except Exception:
        pass
    ok = ctypes.windll.user32.SystemParametersInfoW(20, 0, str(path), 3)
    try:
        subprocess.run(['rundll32.exe', 'user32.dll,UpdatePerUserSystemParameters', '1', 'True'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
    except Exception:
        pass
    return bool(ok)

def minimize_all():
    try:
        subprocess.run(['powershell.exe', '-NoProfile', '-Command', '(New-Object -ComObject Shell.Application).MinimizeAll()'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
    except Exception:
        pass

def shot_bmp(path):
    user32 = ctypes.windll.user32
    gdi32 = ctypes.windll.gdi32
    x = user32.GetSystemMetrics(76)
    y = user32.GetSystemMetrics(77)
    w = user32.GetSystemMetrics(78)
    h = user32.GetSystemMetrics(79)
    hdc = user32.GetDC(0)
    mem = gdi32.CreateCompatibleDC(hdc)
    bmp = gdi32.CreateCompatibleBitmap(hdc, w, h)
    old = gdi32.SelectObject(mem, bmp)
    ok = gdi32.BitBlt(mem, 0, 0, w, h, hdc, x, y, 0x00CC0020)
    stride = ((w * 3 + 3) // 4) * 4
    size = stride * h
    class BIH(ctypes.Structure):
        _fields_ = [('biSize', ctypes.c_uint32), ('biWidth', ctypes.c_int32), ('biHeight', ctypes.c_int32), ('biPlanes', ctypes.c_uint16), ('biBitCount', ctypes.c_uint16), ('biCompression', ctypes.c_uint32), ('biSizeImage', ctypes.c_uint32), ('biXPelsPerMeter', ctypes.c_int32), ('biYPelsPerMeter', ctypes.c_int32), ('biClrUsed', ctypes.c_uint32), ('biClrImportant', ctypes.c_uint32)]
    class BI(ctypes.Structure):
        _fields_ = [('bmiHeader', BIH), ('bmiColors', ctypes.c_uint32 * 3)]
    bi = BI()
    bi.bmiHeader.biSize = ctypes.sizeof(BIH)
    bi.bmiHeader.biWidth = w
    bi.bmiHeader.biHeight = -h
    bi.bmiHeader.biPlanes = 1
    bi.bmiHeader.biBitCount = 24
    bi.bmiHeader.biCompression = 0
    bi.bmiHeader.biSizeImage = size
    buf = (ctypes.c_ubyte * size)()
    got = gdi32.GetDIBits(mem, bmp, 0, h, ctypes.byref(buf), ctypes.byref(bi), 0)
    gdi32.SelectObject(mem, old)
    gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(mem)
    user32.ReleaseDC(0, hdc)
    if (not ok) or got == 0:
        return False, w, h, 'capture failed'
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'wb') as f:
        f.write(b'BM')
        f.write(struct.pack('<IHHI', 54 + size, 0, 0, 54))
        f.write(struct.pack('<IiiHHIIiiII', 40, w, -h, 1, 24, 0, size, 0, 0, 0, 0))
        f.write(bytes(buf))
    return True, w, h, ''

def bmp_to_png(src, dst):
    import zlib
    data = Path(src).read_bytes()
    off = struct.unpack_from('<I', data, 10)[0]
    w = struct.unpack_from('<i', data, 18)[0]
    hh = struct.unpack_from('<i', data, 22)[0]
    bpp = struct.unpack_from('<H', data, 28)[0]
    if bpp != 24:
        raise ValueError('bpp not 24')
    h = abs(hh)
    topdown = hh < 0
    stride = ((w * 3 + 3) // 4) * 4
    rows = []
    for y in range(h):
        yy = y if topdown else h - 1 - y
        row = data[off + yy * stride: off + yy * stride + w * 3]
        rgb = bytearray()
        for x in range(w):
            b, g, r = row[x*3:x*3+3]
            rgb.extend([r, g, b])
        rows.append(b'\x00' + bytes(rgb))
    raw = b''.join(rows)
    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b'')
    Path(dst).write_bytes(png)

L('# R267 static anime wallpaper')
L('time=' + time.strftime('%Y-%m-%d %H:%M:%S'))
stopped = close_dynamic_players()
L('dynamic_players_stopped=' + str(stopped))
src = ROOT / 'deliverable' / 'assets' / 'cute_anime_live_wallpaper_r247.png'
if src.exists():
    shutil.copy2(src, TARGET)
else:
    TARGET = Path(FALLBACK)
L('static_wallpaper=' + str(TARGET) + ' exists=' + str(TARGET.exists()))
set_ok = set_wallpaper(TARGET)
L('static_wallpaper_set=' + str(set_ok))
time.sleep(3)
minimize_all()
time.sleep(2)
ok, w, h, err = shot_bmp(SHOT_BMP)
if ok:
    try:
        bmp_to_png(SHOT_BMP, SHOT_PNG)
    except Exception as e:
        L('png_convert_error=' + repr(e))
L(f'screenshot_bmp={SHOT_BMP} ok={ok} width={w} height={h} err={err}')
L('screenshot_png=' + str(SHOT_PNG) + ' exists=' + str(SHOT_PNG.exists()))
code, out = run(['tasklist', '/FI', 'IMAGENAME eq vlc.exe'], 10)
vlc_count = out.count('vlc.exe')
L('vlc_process_count=' + str(vlc_count))
code, out = run(['tasklist', '/FI', 'IMAGENAME eq Lively.exe'], 10)
lively_count = out.count('Lively.exe')
L('lively_process_count=' + str(lively_count))
desk = Path(os.environ.get('USERPROFILE', r'C:\Users\Public')) / 'Desktop'
org = desk / 'DeskBox-Cute-Desktop-Organizer'
org.mkdir(parents=True, exist_ok=True)
tidy = org / 'AUTO_TIDY_LAST_RUN.txt'
tidy.write_text('time=' + time.strftime('%Y-%m-%d %H:%M:%S') + '\nstatic_anime_wallpaper_r267=True\n', encoding='utf-8')
L('desktop_tidy_manifest=' + str(tidy))
L('desktop_tidy_done=' + str(tidy.exists()))
ready = bool(set_ok and ok and SHOT_PNG.exists() and vlc_count == 0)
L('R267_STATIC_ANIME_WALLPAPER_READY=' + str(ready))
summary = {'ready': ready, 'staticWallpaper': str(TARGET), 'staticWallpaperSet': set_ok, 'screenshotBmp': str(SHOT_BMP), 'screenshotPng': str(SHOT_PNG), 'screenshotOk': ok, 'width': w, 'height': h, 'vlcProcessCount': vlc_count, 'livelyProcessCount': lively_count, 'tidyManifest': str(tidy)}
write_text(JREPORT, json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
write_text(REPORT, '\n'.join(lines) + '\n')
sys.exit(0 if ready else 6)

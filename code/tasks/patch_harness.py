"""patch_harness.py - make the vendored cli-anything-wps harness robust:

1. wps_backend.find_wps (impress): ProgID 'KWPP.Application' resolves to a
   sick engine on some machines (Visible/Slides calls raise E_FAIL). Probe
   each candidate engine (KWPP.Application, wpp.Application, known-good
   CLSID) with Presentations.Add + Slides(1) and return the first HEALTHY
   one.
2. export._fill_impress: 'doc.Slides(1)' assumes the new presentation has
   1 slide; some engines return 0 slides -> fall back to Slides.Add(1, 2).

Applies to BOTH the vendored repo copy and the installed site-packages
copy. Idempotent (skips if markers already present). ASCII-only output.
"""

import os
import site
import sys

BACKEND_ANCHOR = (
    "        app = win32com.client.Dispatch(progid)\n"
    "        return app\n"
)

BACKEND_NEW = '''        app = win32com.client.Dispatch(progid)
        if app_type.lower() in ("impress", "wpp"):
            ok = False
            try:
                p = app.Presentations.Add()
                try:
                    if p.Slides.Count == 0:
                        p.Slides.Add(1, 2)
                    _ = p.Slides(1)
                    ok = True
                finally:
                    try:
                        p.Close()
                    except Exception:
                        pass
            except Exception:
                ok = False
            if ok:
                return app
            try:
                app.Quit()
            except Exception:
                pass
            for alt in ("wpp.Application", "{44720441-94BF-4940-926D-4F38FECF2A48}"):
                try:
                    app = win32com.client.Dispatch(alt)
                    p = app.Presentations.Add()
                    if p.Slides.Count == 0:
                        p.Slides.Add(1, 2)
                    _ = p.Slides(1)
                    try:
                        p.Close()
                    except Exception:
                        pass
                    return app
                except Exception:
                    try:
                        app.Quit()
                    except Exception:
                        pass
            raise RuntimeError("no healthy WPP COM engine found (tried KWPP, wpp.Application, CLSID)")
        return app
'''

EXPORT_ANCHOR = (
    "        if si == 0:\n"
    "            slide = doc.Slides(1)\n"
)

EXPORT_NEW = '''        if si == 0:
            try:
                slide = doc.Slides(1)
            except Exception:
                slide = doc.Slides.Add(1, 2)  # ppLayoutText
'''


def patch_file(path, anchor, new, marker):
    if not os.path.isfile(path):
        return "MISSING " + path
    with open(path, encoding="utf-8") as f:
        src = f.read()
    if marker in src:
        return "ALREADY " + path
    if anchor not in src:
        return "ANCHOR-NOT-FOUND " + path
    src = src.replace(anchor, new, 1)
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(src)
    return "PATCHED " + path


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.abspath(os.path.join(here, "..", ".."))
    repo_pkg = os.path.join(repo, "skills", "harness-anything", "cli_anything", "wps")
    targets = [repo_pkg]
    try:
        out = subprocess.check_output(
            [sys.executable, "-c", "import cli_anything, os; print(os.path.dirname(cli_anything.__file__))"],
            stderr=subprocess.STDOUT, text=True, timeout=60)
        inst = out.strip().splitlines()[-1]
        if inst and inst != repo_pkg and os.path.isdir(inst):
            targets.append(inst)
    except Exception as e:
        print("installed-copy lookup failed: %r" % e)
    for base in targets:
        print(patch_file(os.path.join(base, "utils", "wps_backend.py"),
                         BACKEND_ANCHOR, BACKEND_NEW, "no healthy WPP COM engine found"))
        print(patch_file(os.path.join(base, "core", "export.py"),
                         EXPORT_ANCHOR, EXPORT_NEW, "slide = doc.Slides.Add(1, 2)"))


if __name__ == "__main__":
    main()

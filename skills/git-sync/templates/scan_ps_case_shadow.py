#!/usr/bin/env python3
"""Catch loop variables that silently clobber another variable in the same file.

PowerShell variable names are CASE-INSENSITIVE, so

    $L = New-Object System.Collections.Generic.List[string]
    ...
    foreach ($l in $lines) { ... }       # <-- $l IS $L

destroys the list on the first iteration. Nothing warns you: the later
`$L.Add(...)` just fails at runtime and, with $ErrorActionPreference = 'Continue',
the script keeps going and writes a one-line report. That cost round 268 a full
loop on arena/01a10bfd-git-pull-arena.

Rule: a `foreach ($x in ...)` / `for ($x = ...)` loop variable must not match -
case-insensitively but with a DIFFERENT spelling - a variable that is assigned
somewhere else in the same file. Reusing the exact same spelling is fine (that
is an ordinary loop); only a casing mismatch is reported, because that is the
one that reads as two variables and behaves as one.

Exit 0 when clean, 1 when something is found.
Files listed in code/ps_case_shadow_legacy.txt are reported as WARN only.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEGACY_FILE = os.path.join(ROOT, 'code', 'ps_case_shadow_legacy.txt')

LOOP_RE = re.compile(r'\bforeach\s*\(\s*\$([A-Za-z_][A-Za-z0-9_]*)\s+in\b', re.I)
FORLOOP_RE = re.compile(r'\bfor\s*\(\s*\$([A-Za-z_][A-Za-z0-9_]*)\s*=', re.I)
ASSIGN_RE = re.compile(r'(?m)^[^\S\n]*\$([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)')
PARAM_RE = re.compile(r'\$([A-Za-z_][A-Za-z0-9_]*)\s*[,)\]]')

# automatic / reserved variables are shared by design
AUTOMATIC = {
    'true', 'false', 'null', 'args', 'input', 'matches', 'error', 'home', 'host',
    'pwd', 'pid', 'psitem', 'this', 'foreach', 'switch', 'profile', 'psscriptroot',
    'pscommandpath', 'lastexitcode', 'stacktrace', 'executioncontext', 'myinvocation',
    'nestedpromptlevel', 'outputencoding', 'shellid', 'pshome', 'psversiontable',
}


def load_legacy():
    out = set()
    if os.path.exists(LEGACY_FILE):
        with open(LEGACY_FILE, encoding='utf-8') as fh:
            for line in fh:
                line = line.strip()
                if line and not line.startswith('#'):
                    out.add(os.path.normpath(line))
    return out


def iter_ps1():
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in ('.git', 'node_modules', '_export')]
        for name in files:
            if name.lower().endswith('.ps1'):
                yield os.path.join(base, name)


def main():
    legacy = load_legacy()
    hard = 0
    soft = 0
    for path in sorted(iter_ps1()):
        try:
            with open(path, encoding='utf-8', errors='replace') as fh:
                text = fh.read()
        except OSError:
            continue

        loop_vars = {}
        for rx in (LOOP_RE, FORLOOP_RE):
            for m in rx.finditer(text):
                name = m.group(1)
                if name.lower() in AUTOMATIC:
                    continue
                loop_vars.setdefault(name.lower(), set()).add(name)

        assigned = {}
        for m in ASSIGN_RE.finditer(text):
            name = m.group(1)
            if name.lower() in AUTOMATIC:
                continue
            assigned.setdefault(name.lower(), set()).add(name)

        rel = os.path.relpath(path, ROOT).replace(os.sep, '/')
        for key, spellings in sorted(loop_vars.items()):
            others = assigned.get(key, set()) - spellings
            if not others:
                continue
            loop_name = sorted(spellings)[0]
            other = sorted(others)[0]
            msg = ("%s: loop variable $%s collides with $%s - PowerShell variable "
                   "names are case-insensitive, so the loop overwrites it"
                   % (rel, loop_name, other))
            if os.path.normpath('./' + rel) in legacy or os.path.normpath(rel) in legacy:
                print('WARN: ' + msg)
                soft += 1
            else:
                print('[FAIL] ' + msg)
                hard += 1

    if hard:
        print('[FAIL] rename the loop variable (or the other one) so the two differ by more than case')
        return 1
    print('OK: no loop variable shadows another variable by case only (%d legacy warning(s))' % soft)
    return 0


if __name__ == '__main__':
    sys.exit(main())

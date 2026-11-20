#!/usr/bin/env python3
import json
import select
import shutil
import subprocess as sp
from pathlib import Path


LAT = "`qwertyuiop[]asdfghjkl;'zxcvbnm,./" + '~QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>?@#$^&|'
RUS = 'ёйцукенгшщзхъфывапролджэячсмитьбю.' + 'ЁЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,"№;:?/'


def convert(text):
    source, target = (RUS, LAT) if any(c in RUS and c.isalpha() for c in text) else (LAT, RUS)
    return text.translate(str.maketrans(source, target))


def focus():
    return json.loads(sp.check_output(['niri', 'msg', '-j', 'focused-window'], timeout=1))


def paste(*options):
    result = sp.run(['wl-paste', '-n', '-t', 'text', *options], capture_output=True, timeout=2)
    return result.stdout.decode() if result.returncode == 0 else ''


def main():
    window = focus()
    if not window or window['app_id'] in {'kitty', 'foot', 'Alacritty', 'org.wezfurlong.wezterm'}:
        return  # A terminal selection is scrollback, not editable text.
    selected = paste('--primary')
    fixed = convert(selected)
    if fixed == selected:
        return
    wtype = shutil.which('wtype') or str(Path.home() / '.local/bin/wtype')
    # PRIMARY can outlive its selection. Require a fresh copy from the focused app.
    with sp.Popen(['wl-paste', '--watch', 'sh', '-c', 'printf x'], stdout=sp.PIPE, bufsize=0) as watch:
        def event():
            return select.select([watch.stdout], [], [], 0.8)[0] and watch.stdout.read(1)

        try:
            if not event() or focus() != window:
                return
            sp.run([wtype, '-M', 'ctrl', '-k', 'Insert', '-m', 'ctrl'], check=True, timeout=2)
            if not event() or paste() != selected or focus() != window:
                return
        finally:
            watch.terminate()
    sp.run(['wl-copy', '--type', 'text/plain;charset=utf-8'], input=fixed.encode(), check=True, timeout=2)
    if focus() == window:
        sp.run([wtype, '-M', 'ctrl', '-k', 'v', '-m', 'ctrl'], check=True, timeout=2)


if __name__ == '__main__':
    main()

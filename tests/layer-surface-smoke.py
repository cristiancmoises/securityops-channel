#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2026 SecurityOps contributors
"""Exercise pre-buffer configure and unmap lifecycle on private headless River."""
import argparse
import os
from pathlib import Path
import resource
import shlex
import signal
import subprocess
import tempfile
import time


def child_status(child):
    return os.waitid(os.P_PID, child.pid,
                     os.WEXITED | os.WNOHANG | os.WNOWAIT)


def wait_child(child, timeout):
    deadline = time.monotonic() + timeout
    while (status := child_status(child)) is None:
        if time.monotonic() >= deadline:
            raise subprocess.TimeoutExpired(child.args, timeout)
        time.sleep(.05)
    return status


def stop_owned(child):
    # Keep the leader waitable, even after exit, until both group signals finish.
    # Its reserved PID prevents accidentally signalling a reused process group.
    assert child.returncode is None
    child_status(child)
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.killpg(child.pid, sig)
        except ProcessLookupError:
            pass
        if sig == signal.SIGTERM:
            try:
                wait_child(child, 5)
            except subprocess.TimeoutExpired:
                pass
    return child.wait(timeout=5)


parser = argparse.ArgumentParser(description=__doc__)
for option in ('river', 'manager', 'layer-xml', 'xdg-shell-xml', 'output'):
    parser.add_argument('--' + option, required=True)
args = parser.parse_args()
out = Path(args.output).resolve()
out.mkdir(parents=True, exist_ok=True)
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
with tempfile.TemporaryDirectory(prefix='river-layer-regression-') as directory:
    private = Path(directory)
    private.chmod(0o700)
    sources = []
    for name, xml in [('wlr-layer-shell', args.layer_xml), ('xdg-shell', args.xdg_shell_xml)]:
        normalized = private / (name + '.xml')
        normalized.write_text(Path(xml).read_text().replace(
            '<?xml version="1.0" encoding="UTF-8"?>', ''))
        header = private / (name + '-client-protocol.h')
        source = private / (name + '-protocol.c')
        subprocess.run(['wayland-scanner', 'client-header', str(normalized), str(header)], check=True)
        subprocess.run(['wayland-scanner', 'private-code', str(normalized), str(source)], check=True)
        sources.append(str(source))
    flags = shlex.split(subprocess.check_output(
        ['pkg-config', '--cflags', '--libs', 'wayland-client'], text=True))
    probe = private / 'probe'
    subprocess.run(['gcc', '-std=c11', '-Wall', '-Wextra', '-Werror',
                    '-I' + directory, str(Path(__file__).with_name('layer-surface-probe.c')),
                    *sources, *flags, '-o', str(probe)], check=True)
    init = private / 'init'
    init.write_text('#!/bin/sh\nprintf "%s" "$WAYLAND_DISPLAY" > "$RIVER_TEST_SOCKET"\nexec "$RIVER_TEST_MANAGER"\n')
    init.chmod(0o700)
    env = dict(os.environ, XDG_RUNTIME_DIR=directory,
               XDG_CONFIG_HOME=str(private / 'config'), WLR_BACKENDS='headless',
               WLR_HEADLESS_OUTPUTS='1', WLR_RENDERER='pixman',
               WLR_LIBINPUT_NO_DEVICES='1', RIVER_PRIVATE_LAYER_TEST='1',
               RIVER_TEST_INIT=str(init), RIVER_TEST_SOCKET=str(private / 'socket-name'),
               RIVER_TEST_MANAGER=str(Path(args.manager).resolve()))
    for key in ('WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'DISPLAY', 'SWAYSOCK',
                'XMONAD_WAYLAND_CONFIG', 'WLR_DRM_DEVICES', 'WLR_RENDER_DRM_DEVICE'):
        env.pop(key, None)
    with (out / 'river.log').open('w') as log:
        river = subprocess.Popen([args.river, '-no-xwayland', '-c', 'exec "$RIVER_TEST_INIT"'],
                                 env=env, stdout=log, stderr=log, start_new_session=True)
        try:
            deadline = time.monotonic() + 15
            while not (private / 'socket-name').exists():
                assert child_status(river) is None, 'private River exited'
                assert time.monotonic() < deadline, 'private River startup timed out'
                time.sleep(.05)
            display = (private / 'socket-name').read_text()
            assert '/' not in display and (private / display).is_socket()
            env['WAYLAND_DISPLAY'] = display
            result = subprocess.run([str(probe)], cwd=private, env=env,
                                    capture_output=True, text=True, timeout=20)
            (out / 'probe.log').write_text(result.stdout + result.stderr)
            print(result.stdout + result.stderr, end='')
            assert result.returncode == 0, 'layer surface regression failed'
            assert child_status(river) is None, 'private River exited during probe'
        finally:
            stop_owned(river)

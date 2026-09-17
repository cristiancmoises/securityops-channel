#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2026 SecurityOps contributors
"""Check River keyboard group lifetime using two private compositors."""
import argparse
import os
from pathlib import Path
import shlex
import signal
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--river', required=True)
parser.add_argument('--manager', required=True)
parser.add_argument('--protocols', required=True)
parser.add_argument('--keyboard-xml', required=True)
parser.add_argument('--output', required=True)
args = parser.parse_args()
output = Path(args.output).resolve()
output.mkdir(parents=True, exist_ok=True)
children = []
logs = []


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


def start(command, env, name, **kwargs):
    log = (output / (name + '.log')).open('w')
    logs.append(log)
    child = subprocess.Popen(command, env=env, stdout=log, stderr=log,
                             start_new_session=True, **kwargs)
    children.append(child)
    return child


def wait(predicate):
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        if any(child_status(child) is not None for child in children):
            raise AssertionError('private child exited; see test logs')
        if predicate():
            return
        time.sleep(.05)
    raise AssertionError('private compositor test timed out')


with tempfile.TemporaryDirectory(prefix='river-keyboard-groups-') as directory:
    runtime = Path(directory)
    runtime.chmod(0o700)
    sources = []
    for name, path in [('virtual-keyboard', Path(args.keyboard_xml)),
                       ('river-input-management', Path(args.protocols) / 'river-input-management-v1.xml'),
                       ('river-xkb-config', Path(args.protocols) / 'river-xkb-config-v1.xml')]:
        normalized = runtime / (name + '.xml')
        normalized.write_text(path.read_text().replace('<?xml version="1.0" encoding="UTF-8"?>', ''))
        source = runtime / (name + '-protocol.c')
        subprocess.run(['wayland-scanner', 'client-header', str(normalized),
                        str(runtime / (name + '-client-protocol.h'))], check=True)
        subprocess.run(['wayland-scanner', 'private-code', str(normalized), str(source)], check=True)
        sources.append(str(source))
    flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs',
                                                'wayland-client', 'xkbcommon'], text=True))
    probe = runtime / 'probe'
    subprocess.run(['gcc', '-std=c11', '-Wall', '-Wextra', '-Werror', '-I' + directory,
                    str(Path(__file__).with_name('keyboard-groups-probe.c')), *sources,
                    *flags, '-o', str(probe)], check=True)
    init = runtime / 'init'
    init.write_text('#!/bin/sh\nprintf "%s" "$WAYLAND_DISPLAY" > "$RIVER_TEST_SOCKET"\nexec "$RIVER_TEST_MANAGER"\n')
    init.chmod(0o755)
    env = dict(os.environ, XDG_RUNTIME_DIR=directory, XDG_CONFIG_HOME=str(runtime / 'config'),
               WLR_BACKENDS='headless', WLR_HEADLESS_OUTPUTS='1', WLR_RENDERER='pixman',
               WLR_LIBINPUT_NO_DEVICES='1', RIVER_PRIVATE_INPUT_TEST='1',
               RIVER_TEST_INIT=str(init), RIVER_TEST_SOCKET=str(runtime / 'outer-socket'),
               RIVER_TEST_MANAGER=str(Path(args.manager).resolve()),
               XKB_DEFAULT_LAYOUT='br', XKB_DEFAULT_VARIANT='abnt2')
    for variable in ('WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'DISPLAY', 'SWAYSOCK',
                     'XMONAD_WAYLAND_CONFIG', 'WLR_DRM_DEVICES', 'WLR_RENDER_DRM_DEVICE'):
        env.pop(variable, None)
    try:
        start([args.river, '-no-xwayland', '-c', 'exec "$RIVER_TEST_INIT"'], env, 'outer')
        wait(lambda: (runtime / 'outer-socket').exists())
        env['WAYLAND_DISPLAY'] = (runtime / 'outer-socket').read_text()
        supplier = start([str(probe), 'supply'], env, 'supplier', stdin=subprocess.PIPE, text=True)
        wait(lambda: 'READY' in (output / 'supplier.log').read_text())
        nested = dict(env, WLR_BACKENDS='wayland', WLR_WL_OUTPUTS='1',
                      RIVER_TEST_SOCKET=str(runtime / 'inner-socket'))
        nested.pop('WLR_HEADLESS_OUTPUTS')
        start([args.river, '-no-xwayland', '-c', 'exec "$RIVER_TEST_INIT"'], nested, 'inner')
        wait(lambda: (runtime / 'inner-socket').exists())
        nested['WAYLAND_DISPLAY'] = (runtime / 'inner-socket').read_text()
        time.sleep(.5)
        check = start([str(probe), 'check'], nested, 'check', stdin=subprocess.PIPE, text=True)
        wait(lambda: 'READY_REMOVE' in (output / 'check.log').read_text())
        supplier.stdin.write('remove\n')
        supplier.stdin.flush()
        wait(lambda: 'REMOVED' in (output / 'supplier.log').read_text())
        time.sleep(.2)
        check.stdin.write('continue\n')
        check.stdin.flush()
        status = wait_child(check, 10)
        assert status.si_code == os.CLD_EXITED and status.si_status == 0, \
            'keyboard regression failed; see check.log'
        assert 'PASS' in (output / 'check.log').read_text()
        print((output / 'check.log').read_text(), end='')
    finally:
        for child in reversed(children):
            stop_owned(child)
        for log in logs:
            log.close()

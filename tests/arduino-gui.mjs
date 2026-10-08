// SPDX-License-Identifier: GPL-3.0-or-later
// Usage: node tests/arduino-gui.mjs IDE_PREFIX XVFB_RUN
// Requires Node 22+ (built-in WebSocket); no browser profile or board is used.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {createWriteStream} from 'node:fs';
import {mkdtemp, mkdir, cp} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';

const [prefix, xvfb] = process.argv.slice(2);
assert(prefix && xvfb, 'Provide the built IDE prefix and xvfb-run executable');
const state = await mkdtemp(join(tmpdir(), 'securityops-arduino-gui.'));
for (const name of ['config', 'cache', 'data']) await mkdir(join(state, name));
await cp(fileURLToPath(new URL('fixtures/arduino/Blink', import.meta.url)),
         join(state, 'Blink'), {recursive: true});
console.log(`Isolated GUI state and logs: ${state}`);

const app = spawn(xvfb, ['-a', '/bin/sh', '-c',
  'exec env -i HOME="$1" XDG_CONFIG_HOME="$1/config" ' +
  'XDG_CACHE_HOME="$1/cache" XDG_DATA_HOME="$1/data" ' +
  'DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" ' +
  '"$2/bin/arduino-ide" --remote-debugging-address=127.0.0.1 ' +
  '--remote-debugging-port=0 --disable-gpu "$1/Blink"',
  'arduino-gui-test', state, prefix], {detached: true});
const closed = new Promise(resolve => app.once('close', resolve));
const rawLog = createWriteStream(join(state, 'gui.log'));
let log = '';
for (const output of [app.stdout, app.stderr]) {
  output.on('data', data => { log += data.toString(); rawLog.write(data); });
}
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const deadline = Date.now() + 120_000;
let socket;
try {
  let page;
  while (!page && Date.now() < deadline) {
    assert(app.exitCode === null, `IDE exited early: ${log}`);
    const port = /DevTools listening on ws:\/\/127\.0\.0\.1:(\d+)\//.exec(log)?.[1];
    if (port) {
      try {
        const pages = await (await fetch(`http://127.0.0.1:${port}/json/list`,
          {signal: AbortSignal.timeout(2_000)})).json();
        page = pages.find(value => value.type === 'page' && value.url.includes(
          '/lib/arduino-ide/resources/app/lib/frontend/index.html'));
      } catch { /* Startup may not have registered the page yet. */ }
    }
    if (!page) await delay(250);
  }
  assert(page, `No IDE renderer registered: ${log}`);
  socket = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error('WebSocket timeout')), 5_000);
    socket.addEventListener('open', () => { clearTimeout(timeout); resolve(); }, {once: true});
    socket.addEventListener('error', error => { clearTimeout(timeout); reject(error); }, {once: true});
  });
  let id = 0;
  const evaluate = expression => new Promise((resolve, reject) => {
    const request = ++id;
    const timeout = setTimeout(() => reject(new Error('DevTools timeout')), 5_000);
    const receive = event => {
      const value = JSON.parse(event.data);
      if (value.id !== request) return;
      clearTimeout(timeout);
      socket.removeEventListener('message', receive);
      if (value.error || value.result?.exceptionDetails) reject(new Error(JSON.stringify(value)));
      else resolve(value.result.result.value);
    };
    socket.addEventListener('message', receive);
    socket.send(JSON.stringify({id: request, method: 'Runtime.evaluate',
      params: {expression, returnByValue: true}}));
  });
  let status;
  while (Date.now() < deadline) {
    status = await evaluate(`({title: document.title,
      editor: !!document.querySelector('.monaco-editor'),
      sketch: (document.body?.innerText || '').includes('Blink'),
      source: [...document.querySelectorAll('.view-line')]
        .some(line => line.innerText.includes('pinMode'))})`);
    if (status.editor && status.sketch && status.source) break;
    await delay(500);
  }
  assert(status?.editor && status.sketch && status.source,
         `Sketch editor did not render: ${JSON.stringify(status)}\n${log}`);
  console.log(JSON.stringify(status));
  console.log('PASS: IDE renderer opened Blink in the Monaco editor');
} finally {
  socket?.close();
  const signalGroup = signal => {
    try {
      process.kill(-app.pid, signal);
      return true;
    } catch (error) {
      if (error.code === 'ESRCH') return false;
      throw error;
    }
  };
  signalGroup('SIGTERM');
  const stopAt = Date.now() + 5_000;
  while (Date.now() < stopAt && signalGroup(0)) await delay(100);
  if (signalGroup(0)) signalGroup('SIGKILL');
  await Promise.race([
    closed,
    delay(1_000).then(() => { throw new Error('GUI process did not terminate'); })
  ]);
  await new Promise(resolve => rawLog.end(resolve));
}

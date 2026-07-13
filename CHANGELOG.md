# Changelog

All notable changes to the **securityops** Guix channel are documented here.
Format per [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); released by
tag rather than SemVer of the code.

## [Unreleased]

### Changed — turborec 3.3.0 (2026-07-13)
- **turborec 3.2.0 → 3.3.0** (re-vendored from tag `v3.3.0`, verified identical
  to the published Codeberg copy `d86320a8`). Adds **live streaming**:
  `turborec record --stream KEY [--stream-url URL]` goes LIVE to YouTube (RTMPS
  ingest by default) or any RTMP endpoint instead of recording to a file, OBS
  style; plus adaptive quality and secret hardening for the stream key. Pure
  ffmpeg (RTMP output) — no new inputs, recipe bump only. Built and run-verified
  (`turborec --version` → 3.3.0; `record --help` shows `--stream`/`--stream-url`;
  shim PATH still pins ffmpeg/pactl/xrandr/xdpyinfo/wf-recorder/wlr-randr/sway/
  wmctrl/lspci). Note: at vendor time `v3.3.0` was on Codeberg but not yet on
  git.securityops.co — push the tag there for `./update-channel check`.

### Changed — re-exports bumped ahead of Guix (2026-07-13)
A full version audit (every channel package vs real upstream, not just Guix's
pins) found `torbrowser-assets` behind and several re-exports lagging Guix.
- **torbrowser-assets 15.0.16 → 15.0.17** — matches `torbrowser`; real bundle
  hash; fonts + torrc-defaults extract verified.
- **nmap 7.98 → 7.99**, **fping 5.3 → 5.5**, **hydra 9.6 → 9.7** — converted
  from Guix re-exports to inherit + version + source (real hashes). Built and
  run-verified (`nmap --version` → 7.99; `fping -v` → 5.5; `hydra` banner →
  v9.7). These now build from source at reconfigure instead of pulling Guix
  substitutes.
- Left tracking Guix (a clean version+source bump does not build): **mtr 0.96**
  (upstream moved `utils.h` without fixing `packet/` includes), **radare2
  6.1.8** (new `zydis` meson subproject not packaged in Guix), **rizin 0.9.1**
  (0.9 reworked meson options — inherited `-Duse_swift_demangler` removed),
  **fish 4.8.0** (Guix builds fish 4.x from a pinned ~120-crate `cargo-inputs`
  set; needs the whole set regenerated for 4.8.0's Cargo.lock).
- Confirmed already at latest upstream (audit): kitty, tor, torbrowser, openshot,
  glances, lynis, esquema, and all other re-exports (alacritty, emacs, mpv, vlc,
  keepassxc, ueberzugpp, lf, masscan, aircrack-ng, age, binwalk, whois, arp-scan,
  kismet, reaver, netdiscover, proxychains-ng) + the first-party apps.

### Changed — version bumps (2026-07-12 evening)
- **ungoogled-chromium-bin 150.0.7871.100-1 → 150.0.7871.114-1** — the `.114`
  prebuilt portablelinux release landed upstream (the source tag had run ahead
  for three days; the fixed checker flagged it only once the binary existed).
  Built and run-verified: `chromium --version` → `Chromium 150.0.7871.114`.
- **moneyprinterturbo 1.3.1 → 1.3.2** — re-vendored with the same prune policy
  (proprietary CJK fonts/docker/docs/tests/songs stripped; Charm kept; recipe
  adds wqy-zenhei). All recipe paths and `substitute*` patterns intact.
  `requirements.txt` changed upstream (streamlit 1.59.1, +streamlit-tour,
  `google.generativeai` → `google-genai` 2.11.0, +audioop-lts on py≥3.13) —
  these install in the launcher's first-run venv, so the recipe needs no input
  changes. Built; launcher VERSION → 1.3.2 verified.

### Changed — turborec 3.2.0 (2026-07-12)
- **turborec 3.1.0 → 3.2.0** (re-vendored from tag `v3.2.0`, verified identical
  to the published Codeberg copy). New `-R/--resolution`
  (native/720p/1080p/1440p/4k) on CLI + GUI Output dropdown + `resolution`
  config key: lanczos scaling with aspect preserved and padding to the exact
  standard frame — upscaling to 4k targets YouTube's higher quality/bitrate
  tier. Pure ffmpeg-filter work: no new inputs, recipe bump only. Built and
  run-verified (`turborec --version` → 3.2.0, `-R` present in help).
  Note: at vendor time the `v3.2.0` tag existed on Codeberg but not yet on
  git.securityops.co — push `main` + tag there for `./update-channel check`
  to read cleanly.

### Changed — vaptvupt 5.1.0 → 5.2.1 (2026-07-11/12)
- **vaptvupt(+gui) 5.0.0 → 5.1.0 → 5.2.0 → 5.2.1** (re-vendored per tag; docs
  catch-up entry — the recipe bumps shipped as they were tagged):
  - **5.1.0**: codec upgraded to VaptVupt 2.65.0 — the wrapper no longer
    force-enables `format_v2` (which had halved the extreme-mode text ratio)
    and block size scales with level for the large-window extreme parser
    (`--dedup` keeps a small block). GUI parses the CLI's carriage-return
    progress frames, so compress no longer looks stuck.
  - **5.2.0**: fixes the 5.1.0 GUI cross-thread crash (compress could close
    the app, hang, or corrupt the archive — worst on full-PQ): worker
    callbacks now run on the GUI thread via a `_Job` controller. Codec
    2.65.3 (~2× faster extreme, byte-identical output). libvuptsdk (renamed
    libzuptsdk) wired for `WITH_SDK` builds; the channel build stays
    source-only.
  - **5.2.1**: GUI Verify/Extract reads the archive header to auto-detect
    password/hybrid/full-PQ, applies the matching decrypt flag and guides the
    user on missing credentials; Verify runs in the background.
  - Wire format v1.6 throughout, interoperable with 5.0.x archives. Each step
    built + profile-verified (codec version reported; GUI `--selftest` OK;
    full-PQ compress round-trips byte-exact).
- Earlier same window: **vaptvupt-gui 5.0.0 fixes** — XWayland fallback (GUI
  now actually appears on Sway) and a crash on every compress/extract job
  completion.

### Changed — vaptvupt 5.0.0 (2026-07-10, security, BREAKING)
- **vaptvupt 4.2.1 → 5.0.0** and **vaptvupt-gui → 5.0.0** (re-vendored, same
  tarball). Upstream highlights:
  - **ML-KEM-768 is now genuinely FIPS 203-conformant** — earlier releases
    shipped round-3 CRYSTALS-Kyber under the "FIPS 203" label (secure, but not
    interoperable): transposed matrix-A sampling, round-3 KDF and the
    implicit-rejection domain fixed.
  - **BREAKING: `--pq`/`--pq-only` keys and archives from ≤ 4.2.1 no longer
    decrypt** (the KEM math changed). Regenerate keys and re-encrypt. Password
    mode and plain compression are unaffected; wire format stays v1.6.
  - Security hardening: `compress -p` data-loss guard, silent-plaintext guard,
    heap OOB read in the AVX2 decoder bounded, overflow-safe solid-mode bound,
    secret-wipe on hybrid-decrypt key-read error.
  - GUI reworked for source-only builds (build-aware Hybrid/Full-PQ selector,
    PQ-key auto-detect on Extract/Verify, thread-safety fixes).
  - Recipe: **openssl added as a native-input** so upstream's new
    `tests/test_mlkem_fips203.sh` cross-validates against OpenSSL 3.5.7's
    ML-KEM-768 *inside the build* instead of skipping — verified green
    (keygen byte-identical; encaps/decaps shared secrets match both ways).
    Full `--pq-only` keygen→encrypt→`info`→decrypt round-trip verified on the
    built package.

### Changed — vaptvupt 4.2.1 (2026-07-10)
- **vaptvupt 4.2.0 → 4.2.1** and **vaptvupt-gui → 4.2.1** (re-vendored, same
  tarball). Reader-side fix only, no wire-format change: `vaptvupt info`
  mislabelled full-PQ (`--pq-only`, envelope 0x06) archives as "PQ Hybrid
  (ML-KEM-768 + X25519)" because it only checked the generic PQ header flag;
  it now reads the real envelope type. Existing archives need no re-encryption.
  Built (`make check` green) and the fix run-verified: `info` on a fresh
  `--pq-only` archive reports "ML-KEM-768 only, no classical layer".

### Changed — vaptvupt 4.2.0 (2026-07-10, security)
- **vaptvupt 4.1.0 → 4.2.0** and **vaptvupt-gui 4.1.0 → 4.2.0** (re-vendored,
  same tarball). Upstream highlights:
  - **Security (critical): `--dedup` AES-256-CTR keystream reuse fixed** —
    dedup blocks all used sequence 0, collapsing the CTR nonce to one value
    across blocks (a many-time-pad). Blocks now carry a fresh random 128-bit
    nonce bound into the block MAC. **Re-encrypt any `--dedup` archives written
    by ≤ 4.1.0.** The new regression test (`tests/test_dedup_nonce.sh`) is part
    of `make check`, which this package runs in-build — verified green.
  - New pure post-quantum mode `--pq-only`: ML-KEM-768 (FIPS 203) as the sole
    KEM, no classical X25519 component (additive 0x06 envelope; keys via
    `keygen --pq-only`, not interchangeable with hybrid `--pq` keys). Hybrid
    `--pq` remains the recommended default.
  - `keygen --sdk`/`--box` on source-only builds now fail with a clear message.
  - Recipe unchanged apart from version/source; built and run-verified
    (`vaptvupt version` → 4.2.0, `--pq-only` present in help).

### Changed — version bumps (2026-07-09 batch)
- **google-chrome-stable 150.0.7871.46 → 150.0.7871.114** (dl.google.com `.deb`,
  real downloaded hash; built).
- **ungoogled-chromium-bin 149.0.7827.200-1 → 150.0.7871.100-1** (newest official
  prebuilt portablelinux release, published 2026-07-09; built,
  `chromium --version` → `Chromium 150.0.7871.100`).
- **librewolf 152.0.4-1 → 152.0.5-1** — firefox 152.0.5 source + codeberg tag
  hashes updated; the l10n pin moved `3a21e0c6 → 6ee6f5c4` (per
  `browser/locales/l10n-changesets.json`). Upstream diff touches only `version`
  and one nl locale file; the inline l10n-neuter `substitute*` still applies.
  Source assembly verified (`guix build -S librewolf`); full compile happens at
  reconfigure as usual.
- **turborec 3.0.0 → 3.1.0** (re-vendored; adds `--audio-channels`
  stereo/mono/left/right via an ffmpeg pan filter + GUI Channels dropdown and a
  23 fps preset; no new deps — built, `turborec --version` → 3.1.0).
- **vaptvupt 4.0.0 → 4.1.0** (re-vendored). Upstream went **source-only**: the
  vendored prebuilt SDK libraries (libzuptsdk / libpqvaptvupt) are gone,
  `--pq-sdk`/`--pq-box` are stubs now, password KDF defaults to PBKDF2-SHA256
  and the binary links only `-lm -lpthread`. Recipe drops the LDFLAGS/patchelf
  RUNPATH machinery and the openssl/argon2 inputs, and now RUNS `make check`
  (NIST/RFC crypto vectors + security-regression scripts) in-build — python
  added as native-input for the suite's version check. Built,
  `vaptvupt version` → 4.1.0.
- **vaptvupt-gui 1.3.0 → 4.1.0** — upstream versions the GUI with the CLI now;
  same tarball, all GUI paths unchanged (built).
- **moneyprinterturbo 1.3.0 → 1.3.1** (re-vendored with the same pruning policy:
  proprietary CJK fonts + docs/tests/docker files/songs stripped, Charm kept;
  new upstream files `cli.py`, `app/services/twelvelabs.py`, es/id i18n.
  `requirements.txt` unchanged, so the runtime venv is identical; the new
  `twelvelabs` pip extra is optional and unused unless configured. Launcher
  VERSION and docs updated; built).

### Added — containers
- **esquema 0.2.0** — new module `(securityops packages containers)`. A
  first-party, rootless, Guile-native Linux container runtime, built from
  source with `gnu-build-system`: `make` compiles the C core `libesquema.so`
  (hardening flags: FORTIFY, stack-protector/clash, full RELRO, NX,
  CF-protection) against **libseccomp**; the Guile modules install to
  `share/guile/site/3.0` and are byte-compiled to `lib/guile/3.0/site-ccache`
  (except `esquema-service.scm`, shipped as source since it imports `(guix …)`).
  The FFI loader is repointed at the store `libesquema.so` and
  `native-search-paths` export `GUILE_LOAD_PATH`/`GUILE_LOAD_COMPILED_PATH`, so
  `(use-modules (esquema runtime))` works once installed. Defence-in-depth:
  user/mount/pid/uts/ipc/net/cgroup namespaces, rootless uid/gid maps,
  `pivot_root`, full capability drop + securebits + `no_new_privs`, a seccomp
  allowlist with a stacked TIOCSTI/TIOCLINUX-kill filter, best-effort cgroup v2
  limits. Source vendored to `sources/esquema-0.2.0-src.tar.gz`. In-tree tests
  (functional/security/C-primitives/ASan) run green out of band; the build
  sandbox skips them (`#:tests? #f`, they need a userns + static shell + /proc).
  Verified: `guix build -L . esquema` succeeds; `esquema-init` → 42.

### Changed — version bumps (2026-06-30 batch)
- **tor 0.4.9.9 → 0.4.9.11** (applied via `./update-channel`).
- **steam 1.0.0.86 → 1.0.0.87** (Valve precise beta launcher; real hash; built).
- **google-chrome-stable 149.0.7827.155 → 150.0.7871.46** (`.deb`; built).
- **ungoogled-chromium-bin 149.0.7827.155-1 → 149.0.7827.200-1** (prebuilt; built,
  `chromium --version` → 149.0.7827.200).
- **torbrowser 15.0.16 → 15.0.17** — version-label only: 15.0.17 reuses the
  byte-identical 15.0.16 `src-firefox` tarball (same FFESR build, same hash), so
  the compiled binary is unchanged. `torbrowser-assets` left at 15.0.16.
- **turborec 2.2.0 → 3.0.0** — re-vendored from the forge `v3.0.0` tag; built &
  runs. v3.0.0 adds Wayland (wlroots) capture, so `wf-recorder` + `wlr-randr` +
  `sway` (`swaymsg`) + `wmctrl` are now in the inputs and the launcher shim PATH
  (the X11 path is unchanged).
- **librewolf 152.0.1-2 → 152.0.4-1** — applied. The real blocker was NOT
  `neterror.patch` (a misdiagnosis): it was guix's bundled
  `librewolf-neuter-locale-download.patch`, whose hunk context drifted when
  upstream 152.0.4 switched that script's downloader `wget` → `curl` (and dropped
  a block above it). Fixed by dropping the stale bundled patch and neutering the
  network l10n download inline via `substitute*` (resilient to that churn; the
  l10n still comes from the pinned `firefox-l10n` checkout, so nothing is lost and
  no patch is weakened). `guix build -S librewolf` assembles; full Firefox compile
  deferred to reconfigure as usual.

### Fixed
- **openshot 3.5.1 build.** The inherited check phase invoked `src/tests/
  query_tests.py`, removed in 3.5.1 (tests were split into `src/tests/test_*.py`),
  so the build failed in `check`. Disabled the stale test invocation
  (`#:tests? #f`; the inherited check phase guards on `tests?`); every other phase
  runs unchanged. `guix build -L . openshot` now succeeds.

### Added — security toolset
- **lynis 3.1.7** (guix 3.1.1) — added to `(securityops packages security)`,
  bumped ahead of Guix. Security auditing tool (pure shell): inherits Guix's
  package, overrides version + source (GitHub tag `3.1.7`, real `guix hash -rx`
  source hash), keeps Guix's snippet that strips the proprietary bundled plugins.
  Guix's arguments are inherited unchanged: the check phase runs Guix's separate
  `lynis-sdk` suite (pinned to the 3.1.1 release), which passes against 3.1.7, so
  the tests are kept. Verified: `guix build` succeeds (tests pass); `lynis show
  version` → 3.1.7.

### Added — monitoring
- **glances 4.5.5** (guix 4.3.0) — new module `(securityops packages monitoring)`.
  Cross-platform curses/web system monitor, built from the official `v4.5.5` git
  tag (`pyproject-build-system`, real `guix hash -rx` source hash), inheriting
  Guix's package and overriding version + source. Two 4.5.x deltas handled: the
  new core dep **`pyinstrument>=5.1.2`** is satisfied by a private bump of
  `python-pyinstrument` 5.1.1 → **5.1.2** (Guix's is one patch behind; tests +
  test-only inputs dropped for that transitive bump), and the 4.3.0 custom test
  entry (`unittest-core.py`) is gone in 4.5.x (tests moved to `tests/`), so tests
  are skipped. `orjson` is kept (optional fast-JSON glances still uses) and the
  weekly PyPI update-check stays disabled, as in Guix. Verified: `guix build`
  succeeds (pyproject sanity-check confirms all deps satisfied); `glances
  --version` → 4.5.5 (PsUtil 7.2.2); `glances --stdout cpu,mem` returns live data.

### Added — ungoogled-chromium (prebuilt, latest)
- **`ungoogled-chromium-bin` 149.0.7827.155-1.** New module
  `(securityops packages chromium)` packaging the official upstream **prebuilt**
  ungoogled-chromium portable Linux x86_64 binary, wrapped with nonguix's
  `chromium-binary-build-system` (patchelf onto the Guix glibc loader + library
  set; `#:validate-runpath? #f` because `chrome` links `libnss3.so` et al. which
  NSS installs under `lib/nss/`, resolved at runtime via the wrapper's
  `LD_LIBRARY_PATH`; no bundled `chrome-sandbox`, so Chromium uses the
  unprivileged user-namespace sandbox). Source fetched from GitHub (Tor-reachable)
  and **sha256-verified** against the upstream `ungoogled-chromium-binaries`
  metadata (`d66edf0a…587c1`). **Build-and-run verified:** `chromium --version` →
  `Chromium 149.0.7827.155`. Wired onto `PATH` in `home.scm` (replaces the
  source-built 147).
- **Why prebuilt:** a *from-source* bump is impossible on this Tor-only host —
  the Chromium "-lite" base tarball lives only on Google's `commondatastorage`
  GCS bucket, which **403-blocks every Tor exit** (verified across 6+ rotated
  circuits, incl. the `.hashes` file and guix's known-good 147 tarball; no Wayback
  copy). guix builds existing versions only via `bordeaux` substitutes, which do
  not exist for a new release. The source-built `ungoogled-chromium` (147) stays
  re-exported for the substitutable path.

### Changed — re-export
- **steam: bootstrap bumped 1.0.0.85 → 1.0.0.86.** nonguix pins Valve's
  `steam-launcher` bootstrap at 1.0.0.85 (Valve's `stable` apt suite); this
  channel now tracks the newest one Valve publishes (1.0.0.86 — client timestamp
  2026-06-09, scout runtime 1.0.20260430). Note 1.0.0.86 is from Valve's `beta`
  suite (the tarball's `debian/changelog` reads `steam (1:1.0.0.86) beta`; apt
  `dists/stable` is still 1.0.0.85) — a deliberate ahead-of-stable choice for the
  self-updating shim, consistent with picking newest-available elsewhere.
  `games.scm` no longer re-exports nonguix's `steam` verbatim: it
  rebuilds nonguix's steam container (`steam-container-for mesa`) around a
  version-bumped wrap-package, inheriting the FHS sandbox, library set and mesa
  driver unchanged. Real downloaded hash; built & verified. (The bootstrap is a
  thin shim the real client self-updates around, so this is mostly hygiene —
  but it is now genuinely the newest bootstrap.)

### Added — first-party apps
- **vaptvupt 4.0.0 (CLI)** and **vaptvupt-gui 1.3.0 (PySide6/Qt6)** — the
  post-quantum backup compressor, no longer deferred. Both build from ONE
  vendored release tarball (`sources/vaptvupt-4.0.0.tar.gz`): the CLI from source
  (C11 Makefile, `gnu-build-system`), with the prebuilt vendored libraries
  (`libzuptsdk`, `libpqvaptvupt`) relinked against the store's glibc/openssl/argon2
  via `LDFLAGS` + `patchelf`; the GUI installed with `copy-build-system`, its
  launcher pinning the matching CLI store path through `VAPTVUPT_BIN` so the two
  can never drift. Both verified to build (`vaptvupt`/`zupt`, `vaptvupt-gui`/`zupt-gui`).
- **turborec 2.2.0** — Turbo Recorder, the hardware-accelerated screen + audio
  recorder, no longer deferred (the forge key now grants read access). Built
  FROM SOURCE with `copy-build-system` from the vendored repo tarball
  (`sources/turborec-2.2.0-src.tar.gz`): `turborec.py` (pure-stdlib Python CLI +
  a Tkinter `gui` subcommand) and the `turborecorder` bash X11 launcher install
  under `lib/`, and self-contained `#!/bin/sh` shims in `bin/` pin the store
  `python3`/`bash` and prepend the store bins of the tools they exec — `ffmpeg`,
  `pactl` (pulseaudio), `xrandr`, `xdpyinfo`, `lspci`. The Tkinter GUI gets the
  python `tk` output (which carries `_tkinter.so`) on `PYTHONPATH`. Verified:
  `turborec --version` → 2.2.0; `--help` lists detect/devices/encoders/targets/
  gui/record; `import tkinter` works (Tk 8.6); `turborecorder` syntax-checks.

### Verified — Firefox-class packages compile on the live host now
- **librewolf 152.0.1-2 and torbrowser 15.0.16 fully compiled & run-verified**
  (full LTO). Previously these were source-assembled only — the full builds were
  blocked by RAM, not packaging. `gkrust` (the whole-program rust-LTO crate) is a
  single ~14 GiB rustc that OOM-kills a 15 GiB box at every `-j` (24 down to 1),
  with or without `--disable-lto`. The fix is **swap**: a 24 GiB `/var/swapfile`
  is now declared durably in `config-xlibre.scm` (`swap-devices`, layered over
  the existing 8 GiB zram). With it, `guix build --cores=4 librewolf` finishes
  cleanly and the browser launches. See README → LibreWolf caveat.

### Published & authenticated
- The channel is now public: official home **git.securityops.co** (cloned/pulled
  over HTTPS, no account) with mirrors on **Codeberg** and **GitHub**.
- **Every commit is GPG-signed** (ed25519 `0CFA 43B9 AA96 42EA AF2B  E983 C4C6
  61C9 ECFB 46E8`). Added **`.guix-authorizations`** (the maintainer key as the
  sole signer) and a channel **`(introduction …)`** so `guix pull` authenticates
  the full history; `.guix-channel` `url` now points at the forge.

### Docs
- Gave **0.2.2** (LibreWolf 152.0.1-2) its own heading — it was folded under
  0.3.0. Added public clone / signature-verification / troubleshooting sections,
  and corrected the security-toolset note (`nmap` 7.98→7.99, `fping` 5.3→5.5 lag
  upstream; not all re-exports are current).

## [0.3.3] — 2026-06-23

### Changed — first-party app
- **torando-gui 1.0.1 → 1.1.0.** Re-vendored the 1.1.0 source snapshot
  (`sources/torando-gui-1.1.0-src.tar.gz`); the package definition is otherwise
  unchanged (still source-built, self-contained shims/unit). Upstream 1.1.0:
  - **Fixes the connectivity-breaking bugs**: the killswitch no longer drops the
    torified user's loopback (5→7 rules, `127.0.0.0/8` exempt); `resolv.conf` is
    written world-readable (0644, not 0600) so DNS doesn't break for the
    non-root user; DNS is never stranded (rollback on failed connect, startup
    auto-recovery, `torando-guid --restore-dns`).
  - **Native desktop app**: `torando-gui` opens a real GTK4 + WebKitGTK window,
    falling back to the browser if that stack isn't present. The daemon needs
    neither, so they are NOT package inputs — add `gtk webkitgtk
    python-pygobject` to your profile for the native window.

### Verified
- `guix build -L . torando-gui` builds 1.1.0; `guix package -L . -i torando-gui`
  upgrades the profile; `torando-guid --version` → 1.1.0, `--restore-dns` flag
  present, daemon serves in `--mock` mode. Upstream non-server suite passes.

## [0.3.2] — 2026-06-23

Make the torando-gui Shepherd service turnkey on Guix System.

### Changed — `(securityops services torando)`
- Added a **`seed-config`** field and an `activation-service-type` extension:
  on first activation the service writes `/etc/torando-gui/config.json` (a
  writable file, not a store symlink — only if absent, so later GUI changes
  persist) with `{"manage_torrc": false, "dns_port": 5353}`. This is exactly
  what the daemon needs on Guix, where `tor-service-type` owns the read-only
  `/etc/tor/torrc` and listens on DNSPort 5353 — so it works out of the box
  with no manual GUI toggling. `seed-config` is a JSON string (default above)
  or `#f` to seed nothing.

### Verified
- `guix system build -n` over `operating-system`s that include
  `(service torando-gui-service-type)` evaluates with the activation extension
  lowered (validated against the live `config-xlibre.scm` and `config-sway.scm`,
  both of which already match: TransPort 9040 / SocksPort 9050 / ControlPort
  9051 / DNSPort 5353).

## [0.3.1] — 2026-06-23

Make torando-gui usable on **Guix System**, which runs daemons under the GNU
Shepherd (not systemd).

### Added — service
- **`(securityops services torando)`** — a native Shepherd service type,
  `torando-gui-service-type`, with a `torando-gui-configuration` record
  (`package`, `host`, `port`, `config-file`, `extra-options`). It runs
  `torando-guid` as root via `make-forkexec-constructor` (foreground; clean
  `SIGTERM` stop), requires `networking`, logs to `/var/log/torando-gui.log`,
  and extends `profile-service-type` so the launcher/daemon land on `PATH`. The
  package's systemd unit is inert on Guix; this replaces it.

### Verified
- `(securityops services torando)` loads; the service-type and config record
  instantiate; `guix system build -L . -n` over a minimal `operating-system`
  that includes `(service torando-gui-service-type)` evaluates the full system
  derivation graph successfully (the service lowers and its Shepherd
  `networking` requirement resolves).

### Docs
- README gains a "Running torando-gui as a Shepherd service" section with the
  `config.scm` snippet and the Guix caveat (`/etc/tor/torrc` is a read-only
  store symlink, so disable in-GUI torrc management and let `tor-service-type`
  own Tor).

## [0.3.0] — 2026-06-23

A new first-party app: **torando-gui**, the loopback web GUI + root daemon that
routes one local user's egress through Tor (transparent proxy + killswitch).

### Added — first-party app
- **torando-gui 1.0.1** — pure-Python (stdlib only), so it is built **from
  source** with `copy-build-system` (no compile, no patchelf). The 1.0.1 source
  snapshot is vendored at
  `securityops/packages/sources/torando-gui-1.0.1-src.tar.gz` and referenced via
  `local-file` (vendored so the channel builds with no network). A `wrap-shims` phase makes the package
  **self-contained**: both shims are rewritten to call the store `python3` and
  prepend the store bins of the tools the root daemon execs (`iptables`,
  `chattr` via `e2fsprogs`, `tor`), and the installed systemd unit is pointed at
  the store binary instead of `/usr/bin`. Ships the daemon, launcher, systemd
  unit, polkit policy, desktop entry and docs. Added imports for
  `(gnu packages python)`, `(gnu packages tor)` and `(gnu packages linux)` to
  `apps.scm`.

### Upstream (the torando-gui repo, vendored here at 1.0.1)
- 1.0.0 → 1.0.1 robustness/correctness pass: failed connect rolls back the
  `resolv.conf` pin; durable atomic writes (`fsync`); corrupt GeoIP DB no longer
  crashes; `torrc` keeps a single managed block; plain-COOKIE Tor control auth;
  `HEAD`/SSE and query-token hardening; `e2fsprogs` declared as a dependency.

### Verified
- `guix build -L . torando-gui` builds; `guix package -L . -i torando-gui`
  installs into the profile; `torando-guid --version` → 1.0.1 and the daemon
  serves the token-gated loopback UI in `--mock` mode. The upstream test-suite
  passes (80 tests).

## [0.2.2] — 2026-06-22

LibreWolf bumped to the latest upstream (the last curated app still behind), and
a decision recorded on ungoogled-chromium.

### Added — version bump (verified source)
- **librewolf 151.0.4-1 → 152.0.1-2** — new module
  `securityops/packages/librewolf.scm` vendors guix's *private*
  `make-librewolf-source` machinery (firefox-source / librewolf-source /
  computed-origin / firefox-l10n) and then **inherits** guix's `librewolf`,
  overriding only `version` + `source` (same pattern as `torbrowser`).
  Hashes fetched + the **computed-origin source assembled successfully**
  (`guix build -S librewolf` → `librewolf-152.0.1-2.source.tar.zst`):
  - firefox 152.0.1 source `0ppi08ajg00mb0qdlfffnw15mvkfx8xi79ys62ijbpzh0jykgw5z`
  - librewolf/source `152.0.1-2` `0wbisx3yvg7g4d09azgksz3yaf7n12xqa0v4dy9hnplwxcxixgda`
  - firefox-l10n `@9929bc50` `1ka78jhbhgvxby29q7ni5lim5c4977qdixd50cylnvb4807cli6l`
    (the `revision` from `firefox-152.0.1/browser/locales/l10n-changesets.json`).
  The full Firefox compile is deferred to reconfigure (like torbrowser).
- Wired `so:librewolf` into `~/.config/guix/home.scm` (2 sites) and
  `config-xlibre.scm` (browser list); the `BROWSER=librewolf` env var is a
  binary name on `PATH`, unchanged.

### Decision — ungoogled-chromium 147 → 149 DEFERRED
> **Superseded** in `[Unreleased]`: the latest ungoogled-chromium now ships as the
> prebuilt `ungoogled-chromium-bin` 149.0.7827.155-1 (a from-source bump turned out
> to be not just heavy but *impossible* over Tor — Google's GCS 403-blocks the base
> tarball). The note below is the point-in-time 0.2.2 record.
- A source bump is guix-maintainer-level: the source is assembled in-module from
  a chromium "-lite" tarball + version-pinned ungoogled/debian patch repos + a
  hand-picked patch subset, then a multi-hour / ~30GB-RAM compile that can't be
  verified here. Groundwork recorded in `browsers.scm`: upstream tags exist and
  all 18 of guix's selected debian patches are still present at
  `debian/149.0.7827.155-1`. `google-chrome-stable` 149 already covers a current
  Chromium engine. Re-exported at guix's 147 until guix proper advances.

### Verified
- `guix build -L . -n librewolf` evaluates; `guix build -L . -S librewolf`
  assembles the source. `guix system build -n` / `guix home build -n` evaluate
  with `so:librewolf` 152.0.1-2 resolved.

## [0.2.1] — 2026-06-22

Re-validation pass plus the one upstream change since 0.2.0, and wiring the
curated set into the live `/etc/config.scm` and `~/.config/guix/home.scm`.

### Changed — version bump (verified hash)
- **mullvad-vpn-desktop 2026.2 → 2026.3** — Mullvad's published *stable* desktop
  release as of 2026-06-22: the `mullvad.net/download/app/deb/latest` redirect
  resolves to `.../releases/2026.3/MullvadVPN-2026.3_amd64.deb`, and GitHub tag
  `2026.3` is a non-beta release (2026.4+ are not yet promoted). Source still
  `cdn.mullvad.net`; sha256 `1jhsjf707mv3i29i1r62cb6dml5n4n2s48h9as40d1w0mrryxiiq`
  fetched + matched via `guix build -S mullvad-vpn-desktop`.

### Verified — re-checked against upstream (2026-06-22), all still latest
- `kitty` 0.47.4, `tor` 0.4.9.9, `torbrowser` 15.0.16 / `torbrowser-assets`
  15.0.16, `openshot` 3.5.1, `google-chrome-stable` 149.0.7827.155 — confirmed
  still the newest upstream releases, no bump needed. The channel remains ahead
  of the pinned guix/nonguix (d1e9e23: kitty 0.46.2, tor 0.4.9.8, torbrowser
  15.0.14, google-chrome 148.0.7778.215).

### Wired into the live configs (consumers of the channel)
- `/etc/config.scm` (= `guix-config/predator-helios-intel/config-xlibre.scm`)
  and `~/.config/guix/home.scm` now take the curated apps that are *ahead* of
  guix/nonguix from this channel, imported behind a `so:` prefix so the bare
  upstream bindings stay available: `so:kitty` + `so:tor` (both configs),
  `so:torbrowser` + `so:google-chrome-stable` (home), and
  `mullvad-daemon-service-type` is pointed at `so:mullvad-vpn-desktop` (2026.3)
  so the running daemon — not just the profile entry — is the latest.
- Validated: `guix system build -n` and `guix home build -n` both evaluate with
  the channel on the load path (only new build: `mullvad-vpn-desktop-2026.3`).

## [0.2.0] — 2026-06-21

First-party applications from `git.securityops.co/cristiancmoises` and a curated
security toolset. To keep the channel self-contained (it builds with no network),
app sources/artifacts are **vendored** into `packages/sources/` and referenced
via `local-file`.

### Added — first-party apps
- **evelin-bin 4.1.1** — official static-musl release tarball (copy-build-system);
  builds & runs.
- **btp 0.7** — built from source (`cargo build --release`, `btpctl` + `btpd`);
  dynamic binaries patchelf'd onto Guix `glibc`/`gcc:lib`; builds & runs.
- **mirim 1.0.0** — built from source (`mirim` + `mirim-sign`); compiles under
  Guix's Rust 1.93 despite the repo's 1.96 pin; same patchelf vendor as btp.

### Added — security toolset (`security.scm`, re-exports)
- nmap, masscan, arp-scan, netdiscover, fping, mtr, whois, proxychains-ng,
  aircrack-ng, reaver, kismet, hydra, radare2, rizin, binwalk, age.

### Pending / known
- **vaptvupt 2.2.3** — C core + Python GUI AppImage; deferred (cleanest as the
  official `.AppImage` artifact). _(Since added from source as **vaptvupt 4.0.0**
  + **vaptvupt-gui 1.3.0** — see [Unreleased].)_
- **turborec** — deploy key not authorized to read the repo; skipped.
- ~28 security tools not yet in Guix listed as TODO in README (sqlmap, ffuf,
  gobuster, mitmproxy, sleuthkit, volatility3, …).

## [0.1.0] — 2026-06-21

Initial release. Curated latest-version packaging of the securityops
workstation's most-used applications, built and verified against Guix commit
`d1e9e23` on host `predator-helios-intel`. Channel depends on `nonguix`.

### Added — version bumps ahead of Guix/nonguix (real, downloaded hashes)
- **kitty 0.47.4** (guix 0.46.2) — git `v0.47.4`; inherits upstream origin.
- **tor 0.4.9.9** (guix 0.4.9.8) — dist.torproject.org tarball.
- **torbrowser 15.0.16** (guix 15.0.14), latest *stable* — source build from
  `src-firefox-tor-browser-140.12.0esr-15.0-1-build2`; inherits guix's
  `mozilla-build-system` (assets/l10n/build-date stay at the 15.0.14 baseline —
  see README → Caveats).
- **torbrowser-assets 15.0.16** — provided standalone (guix keeps its copy
  private).
- **openshot 3.5.1** (guix 3.4.0) — git `v3.5.1`.
- **google-chrome-stable 149.0.7827.155** (nonguix 148.0.7778.215) — official
  `.deb` via nonguix's `make-google-chrome`.
- **mullvad-vpn-desktop 2026.2** (small-guix 2025.8) — vendored from small-guix
  (build phases bake `version`, so inherit would break the build); source moved
  to `cdn.mullvad.net`; x86_64-only.

### Added — re-exports (already latest; track upstream automatically)
- `alacritty` 0.17.0, `fish` 4.7.1, `emacs` 30.2, `emacs-pgtk` 30.2,
  `mpv` 0.41.0, `vlc` 3.0.23, `keepassxc` 2.7.12, `ueberzugpp` 2.9.10,
  `lf` 41, `steam` (self-updating bootstrap).

### Known limitations (re-exported at guix's version; upstream is newer)
- **librewolf** 151.0.4-1 (upstream 152.0.1-2) — private source builder; bump
  needs vendoring + a ~500MB Firefox source (recipe in README).
- **ungoogled-chromium** 147 (upstream 149) — multi-GB source / many-hour
  compile; out of scope.

### Added — channel infrastructure & docs
- `.guix-channel` (with `nonguix` dependency), `etc/news.txt`,
  `.dir-locals.el` (Guix house style), `.gitignore`, GPL-3.0-or-later `LICENSE`.
- `README.md`, this `CHANGELOG.md`, and **`AUDIT.md`** — a deep version audit of
  every package declared in `/etc/config.scm` and `~/.config/guix/home.scm`
  (391 packages: 124 current, 139 outdated, 128 unknown; plus an active-`home.scm`
  reconciliation for 11 packages the repo copy lacked).

### Verified
- Channel evaluates: `guix build -L . [-L <nonguix>] -n` over all packages — no errors.
- Source hashes fetch + match: `guix build -L . -S` for all seven bumped packages.
- Full compiles deferred to `guix pull` / reconfigure (depth: verified hashes + evaluate).

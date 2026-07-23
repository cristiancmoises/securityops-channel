# securityops — a personal GNU Guix channel

> Latest upstream versions of the **securityops** workstation's most-used
> applications, packaged the Guix way — real source hashes, every definition
> inheriting from upstream so it stays small and auditable.

🌐 **Language:** **English** · [Português (Brasil)](README.pt-BR.md)

This channel curates the programs this machine lives in and keeps them at the
newest official release. Packages the pinned Guix already ships at the latest
upstream version are **re-exported unchanged** (so the channel is the single
place you install them from, and they track Guix automatically); packages that
are *ahead* of Guix/nonguix carry a **real, downloaded source hash**.

- **Host:** `predator-helios-intel` (the live `/etc/config.scm` machine)
- **Pinned Guix:** commit `d1e9e23` (June 2026); **depends on** `nonguix`
- **Built/verified:** 2026-06-21; **re-validated 2026-06-22** (Mullvad → 2026.3, LibreWolf → 152.0.1-2); **2026-06-23** (torando-gui 1.0.1 added, then → 1.1.0: native GUI + connectivity fixes — built & installed); **2026-06-24** (vaptvupt 4.0.0 CLI + vaptvupt-gui 1.3.0 added — built from source; steam bootstrap bumped 1.0.0.85 → 1.0.0.86); **2026-06-25** (turborec 2.2.0 added — built from source; CLI + bash launcher run, Tkinter GUI works via the python `tk` output; **LibreWolf 152.0.1-2 + torbrowser 15.0.16 fully compiled & run-verified** — full Firefox source builds, unblocked by a 24 GiB swapfile); **2026-06-30** (glances 4.5.5 added — from-source bump, new `(securityops packages monitoring)` module + private pyinstrument 5.1.2 dep; built, `glances --version` → 4.5.5, `--stdout cpu,mem` returns live data; **lynis 3.1.7** added; **tor → 0.4.9.11**; batch bumps **steam 1.0.0.87 / google-chrome 150.0.7871.46 / ungoogled-chromium-bin 149.0.7827.200-1 / torbrowser 15.0.17 / turborec 3.0.0** — built & verified; **openshot 3.5.1 build fixed** (stale test path)); **2026-07-01** (esquema 0.2.0 added — new `(securityops packages containers)` module: rootless Guile-native container runtime, built from source, libseccomp-backed; `guix build -L . esquema` verified); **2026-07-09** (batch bumps **google-chrome 150.0.7871.114 / ungoogled-chromium-bin 150.0.7871.100-1 / librewolf 152.0.5-1 / turborec 3.1.0 / vaptvupt 4.1.0 / vaptvupt-gui 4.1.0 / moneyprinterturbo 1.3.1** — all built & run-verified; vaptvupt is source-only upstream now, its `make check` crypto/security suite runs in-build; librewolf source assembly verified with new l10n pin `6ee6f5c4`); **2026-07-10** (**vaptvupt(+gui) → 4.2.0** — critical `--dedup` AES-CTR keystream-reuse fix + pure-PQ `--pq-only` mode; built, full check suite incl. the new dedup-nonce regression green, run-verified; then **→ 4.2.1** — `info` now reads the real envelope type and labels `--pq-only` archives "ML-KEM-768 only, no classical layer" instead of hybrid; fix run-verified on a real `--pq-only` archive; then **→ 5.0.0** — ML-KEM-768 made genuinely FIPS 203-conformant, cross-validated against OpenSSL 3.5 **inside the build** (openssl native-input); **BREAKING: regenerate PQ keys, re-encrypt PQ archives from ≤ 4.2.1**; `--pq-only` keygen→encrypt→decrypt round-trip verified); **2026-07-11/12** (**vaptvupt(+gui) → 5.1.0 → 5.2.0 → 5.2.1** — codec 2.65.0→2.65.3 with large ratio gains and ~2× faster extreme; GUI compress-crash fix (thread-safe `_Job` controller), robust auto-detect Verify/Extract, XWayland fallback on Sway; wire format v1.6 unchanged; all built + profile-verified, GUI `--selftest` OK; **turborec → 3.2.0** — `-R/--resolution` native/720p/1080p/1440p/4k lanczos output scaling; built & run-verified; **ungoogled-chromium-bin → 150.0.7871.114-1** — the .114 prebuilt landed, run-verified; **moneyprinterturbo → 1.3.2** — re-vendored, same prune policy; streamlit 1.59.1 + google-genai in the first-run venv); **2026-07-13** (**turborec → 3.3.0** — live YouTube/RTMPS streaming (`record --stream`), adaptive quality; built & run-verified; then **→ 3.4.0** — security-audit fixes; then **→ 3.5.0** — webcam PiP overlay + mic noise suppression; then **→ 3.6.0** — `turborecorder` Wayland (wf-recorder) capture + static-screen stop fix; all built & run-verified); **2026-07-15** (batch bumps **google-chrome 150.0.7871.124 / librewolf 152.0.6-1 (l10n pin `e42882cf`) / torbrowser 15.0.18 / torbrowser-assets 15.0.18 / mirim 1.1.0** — chrome/mirim/tb-assets built & run-verified, librewolf+torbrowser source assemblies verified (full compile deferred to reconfigure); mirim 1.1.0 moved binaries to the archive root + added an unpackaged `mirim-gui`); **2026-07-17** (**evelin-bin → 4.2.0** — 7 static binaries (adds `ev`/`evelin-keyscan`/`evelin-multisig-verify`); built, `evelin-client 4.2.0`, **installed**; batch bumps **google-chrome 150.0.7871.128 / ungoogled-chromium-bin 150.0.7871.128-1** — built & run-verified (`Chromium 150.0.7871.128`); fixed the **moneyprinterturbo** version field (was mislabelled 1.3.4 — upstream's newest tag is v1.3.2); README re-synced to the torando-gui 1.3.4 commits; then **google-chrome → 150.0.7871.181 / librewolf → 153.0-3 (MAJOR 152→153, l10n pin `235fd5b0`) / torbrowser → 15.0.19 / torbrowser-assets → 15.0.19** — chrome/tb-assets built & run-verified, librewolf+torbrowser source assemblies verified (Firefox compiles at reconfigure); **tor confirmed at 0.4.9.11 — the newest tor that exists** (no 0.4.10/alpha); ran **`guix home reconfigure`** to install torbrowser 15.0.19 + tor + chrome + the rest at latest); **2026-07-23** (**torbrowser version-string fix** — guix's `make-torbrowser` baked its own `%torbrowser-version` 15.0.14 into the displayed version, so a 15.0.19 engine reported 15.0.14; the recipe now rewrites `--with-base-browser-version` + `MOZ_BUILD_DATE` to 15.0.19, verified in the built `omni.ja` (`BASE_BROWSER_VERSION=15.0.19`) and **reconfigured into the home profile**; **kitty → 0.48.0** — one new imported Go dep (`ebitengine/purego`) packaged, `GOTOOLCHAIN=local` phase added (0.48's go.mod pins a toolchain guix can't fetch offline), **built & installed**, `kitty --version` → 0.48.0)
- **Maintainer:** Cristian Cezar Moisés `<ethicalhacker@riseup.net>`
- **Home:** [`https://git.securityops.co/cristiancmoises/securityops-channel`](https://git.securityops.co/cristiancmoises/securityops-channel) (official) · mirrors: [Codeberg](https://codeberg.org/berkeley/securityops-channel) · [GitHub](https://github.com/cristiancmoises/securityops-channel)
- **Signing:** every commit is GPG-signed (ed25519 `0CFA 43B9 … ECFB 46E8`) and the channel is authenticated — see [Publishing & authentication](#publishing--authentication)

---

## The curated set

### 📇 Full package index (50 packages)

Every package this channel defines, its current version, and the most recent
change. **Class**: 🅑 bumped ahead of Guix/nonguix (real downloaded hash) · 🄟
prebuilt binary · 🄡 re-exported (tracks Guix, already latest) · 🄕 first-party
(`git.securityops.co`) / vendored · 🄓 internal build dependency. The detailed
per-category sections and caveats follow below.

| Package | Version | Class | Latest change / note |
|---|---|:--:|---|
| `kitty` | 0.48.0 | 🅑 | ahead of Guix 0.46.2; pulls three vendored Go deps (↓); `GOTOOLCHAIN=local` |
| `tor` | 0.4.9.11 | 🅑 | ahead of Guix 0.4.9.8 |
| `torbrowser` | 15.0.19 | 🅑 | source build + ThinLTO; ahead of Guix 15.0.14 |
| `torbrowser-assets` | 15.0.19 | 🅑 | official bundle (fonts + torrc-defaults); matched to `torbrowser` |
| `openshot` | 3.5.1 | 🅑 | ahead of Guix 3.4.0; stale-test-path build fixed |
| `google-chrome-stable` | 150.0.7871.181 | 🅑 | ahead of nonguix; real `.deb` hash |
| `mullvad-vpn-desktop` | 2026.3 | 🅑 | vendored `.deb`; the daemon service runs this build |
| `librewolf` | 153.0-3 | 🅑 | source build; **major 152→153 bump** (l10n pin `235fd5b0`); compile watched at first reconfigure |
| `steam` | 1.0.0.87 | 🅑 | Valve beta bootstrap (nonguix container rebuilt) |
| `glances` | 4.5.5 | 🅑 | pyproject; private `pyinstrument` 5.1.2 dep |
| `lynis` | 3.1.7 | 🅑 | ahead of Guix 3.1.1; bundled proprietary plugins stripped |
| `nmap` | 7.99 | 🅑 | ahead of Guix 7.98 |
| `fping` | 5.5 | 🅑 | ahead of Guix 5.3 |
| `hydra` | 9.7 | 🅑 | THC-Hydra; ahead of Guix 9.6 |
| `ungoogled-chromium-bin` | 150.0.7871.128-1 | 🄟 | official prebuilt portablelinux; the recommended chromium |
| `alacritty` | 0.17.0 | 🄡 | latest in Guix |
| `fish` | 4.7.1 | 🄡 | latest in Guix; upstream 4.8.0 needs a full cargo-inputs regen |
| `emacs` | 30.2 | 🄡 | latest in Guix |
| `emacs-pgtk` | 30.2 | 🄡 | pure-GTK Emacs; latest in Guix |
| `mpv` | 0.41.0 | 🄡 | latest in Guix |
| `vlc` | 3.0.23 | 🄡 | latest stable (VLC 4.x not released) |
| `keepassxc` | 2.7.12 | 🄡 | latest in Guix |
| `ueberzugpp` | 2.9.10 | 🄡 | latest in Guix |
| `lf` | 41 | 🄡 | latest in Guix |
| `ungoogled-chromium` (source) | 147.0.7727.137-1 | 🄡 | newer exists but source build is Tor-blocked — use `-bin` ↑ |
| `masscan` | 1.3.2 | 🄡 | latest in Guix |
| `arp-scan` | 1.10.0 | 🄡 | latest in Guix |
| `netdiscover` | 0.21 | 🄡 | latest in Guix |
| `mtr` | 0.95 | 🄡 | upstream 0.96 has an `utils.h` include-path bug — kept on Guix |
| `whois` | 5.6.6 | 🄡 | latest in Guix |
| `proxychains-ng` | 4.17 | 🄡 | latest in Guix |
| `aircrack-ng` | 1.7 | 🄡 | latest in Guix |
| `reaver` | 1.6.6 | 🄡 | latest in Guix |
| `kismet` | 2025.09.R1 | 🄡 | latest in Guix |
| `radare2` | 6.1.4 | 🄡 | upstream 6.1.8 needs `zydis` (not in Guix) — kept on Guix |
| `rizin` | 0.8.2 | 🄡 | upstream 0.9.1 reworked meson options — kept on Guix |
| `binwalk` | 3.1.0 | 🄡 | latest in Guix |
| `age` | 1.3.1 | 🄡 | latest in Guix |
| `evelin-bin` | 4.2.0 | 🄕 | official static-musl release tarball; 4.2.0 adds `ev`, `evelin-keyscan`, `evelin-multisig-verify` |
| `btp` | 0.7 | 🄕 | Rust; binaries patchelf'd to glibc/gcc (`btpctl`, `btpd`) |
| `mirim` | 1.1.0 | 🄕 | prebuilt Rust binaries (patchelf'd); `mirim`, `mirim-sign` (upstream also ships a `mirim-gui`, not packaged) |
| `torando-gui` | 1.3.4 | 🄕 | Python daemon + GTK4/WebKit GUI; ships a Shepherd service; ip6tables IPv6 killswitch + cross-platform backends (1.3.1–1.3.4: Windows/packaging fixes, Linux build unchanged) |
| `vaptvupt` | 5.2.1 | 🄕 | PQ backup compressor (ML-KEM-768/FIPS 203); source-only; see BREAKING note ↓ |
| `vaptvupt-gui` | 5.2.1 | 🄕 | PySide6/Qt6 frontend; thread-safe `_Job`, auto-detect Verify |
| `turborec` | 3.6.0 | 🄕 | screen/audio recorder; live YouTube/RTMPS streaming; webcam PiP + noise suppression; 3.6.0 `turborecorder` Wayland (wf-recorder) capture |
| `esquema` | 0.2.0 | 🄕 | rootless Guile-native container runtime (libseccomp) |
| `moneyprinterturbo` | 1.3.2 | 🄕 | vendored 3rd-party AI short-video generator; fonts pruned |
| `go-github-com-emmansun-base64` | 0.9.0 | 🄓 | kitty build dependency |
| `go-github-com-sgtdi-fswatcher` | 1.3.0 | 🄓 | kitty build dependency |
| `go-github-com-ebitengine-purego` | 0.10.1 | 🄓 | kitty 0.48 build dependency (call C from Go, no cgo) |

### 🔌 Services (2)

Two native **GNU Shepherd** service types for `guix system reconfigure` — the
systemd units shipped in the upstream packages are inert on Guix System, so the
channel supplies real Shepherd services:

| Service type | Module | Configuration (fields) | Purpose |
|---|---|---|---|
| `torando-gui-service-type` | `(securityops services torando)` | `torando-gui-configuration`: `package`, `host` (def. `127.0.0.1`), `port` (def. `8088`), `config-file`, `extra-options`, `seed-config` | Runs the Torando Control daemon (`torando-guid`) as root under Shepherd — programs netfilter, pins `resolv.conf`, manages `torrc` — and serves the token-injected UI on `http://127.0.0.1:8088/`. Auto-seeds `/etc/torando-gui/config.json` on first activation (so GUI changes persist). Requires the `networking` target; pair with `tor-service-type`. |
| `esquema-service-type` | `(esquema esquema-service)` — shipped by the `esquema` package | `esquema-configuration` (positional): `name`, `rootfs`, `command`, `scheme-dir` | Supervises a single rootless `esquema` container as a Shepherd service (declarative `<container>`, all namespaces + seccomp + full capability drop). |

Full `(operating-system …)` examples are below: [**torando-gui service**](#running-torando-gui-as-a-shepherd-service-guix-system) and [**esquema service**](#esquema--rootless-guile-native-container-runtime).

### ⬆️ Bumped ahead of Guix / nonguix (real downloaded hashes)

| Package | This channel | Upstream had | Source |
|---|---|---|---|
| **kitty** | 0.48.0 | 0.46.2 (guix) | git tag `v0.48.0` |
| **tor** | 0.4.9.11 | 0.4.9.8 (guix) | dist.torproject.org tarball |
| **torbrowser** | 15.0.19 | 15.0.14 (guix) | source build (see caveat) |
| **torbrowser-assets** | 15.0.19 | _(private in guix)_ | official bundle (fonts + torrc-defaults) |
| **openshot** | 3.5.1 | 3.4.0 (guix) | git tag `v3.5.1` |
| **google-chrome-stable** | 150.0.7871.181 | 148.0.7778.215 (nonguix) | dl.google.com `.deb` |
| **mullvad-vpn-desktop** | 2026.3 | 2025.8 (small-guix) | cdn.mullvad.net `.deb` (vendored) |
| **librewolf** | 153.0-3 | 151.0.4-1 (guix) | source build (vendored `make-librewolf-source`; major 152→153) |
| **steam** | 1.0.0.87 _(Valve beta)_ | 1.0.0.85 (nonguix, stable) | Valve precise archive (nonguix container rebuilt around bumped bootstrap) |
| **glances** | 4.5.5 | 4.3.0 (guix) | git tag `v4.5.5` (pyproject; +`pyinstrument` 5.1.2) |
| **lynis** | 3.1.7 | 3.1.1 (guix) | git tag `3.1.7` (shell; plugins stripped) |

### ✅ Re-exported — already latest in Guix/nonguix (track upstream automatically)

`alacritty` 0.17.0 · `fish` 4.7.1 · `emacs` 30.2 · `emacs-pgtk` 30.2 ·
`mpv` 0.41.0 · `vlc` 3.0.23 · `keepassxc` 2.7.12 · `ueberzugpp` 2.9.10 ·
`lf` 41

### ⚠️ Re-exported — newer upstream exists but a bump is impractical here

| Package | This channel (= guix) | Upstream | Why not bumped |
|---|---|---|---|
| **ungoogled-chromium** (source) | 147.0.7727.137-1 | 150.0.7871.128-1 | source-bump **impossible over Tor** — the Chromium "-lite" base tarball lives only on Google's GCS, which 403-blocks every Tor exit; guix gets existing versions via substitutes, but a new release has none (see caveat). Use `ungoogled-chromium-bin` ↓ |

> **ungoogled-chromium-bin** — the latest ungoogled-chromium *is* available here as
> a **prebuilt** binary: `150.0.7871.128-1`, the official upstream portable Linux
> x86_64 build hosted on GitHub (Tor-reachable), sha256-verified and wrapped with
> nonguix's `chromium-binary-build-system`. **Build-and-run verified** —
> `chromium --version` → `Chromium 150.0.7871.128`. This is the recommended
> chromium on `PATH`.
>
> **librewolf** was in this table; it is now **bumped to 153.0-3** (major 152→153;
> see the table above and the LibreWolf caveat).

> A full version audit of **every other** package in `/etc/config.scm` and
> `~/.config/guix/home.scm` (yours vs. latest upstream) is in **[AUDIT.md](AUDIT.md)**
> — 391 packages: 124 current, 139 outdated, 128 unknown.

---

## First-party apps (`git.securityops.co/cristiancmoises`)

Each app lives in its own repo on the forge. To keep this channel
**self-contained** (it builds with no network access), their sources/artifacts are
**vendored** into `securityops/packages/sources/` and referenced with `local-file`
(content-addressed, no hash field) rather than fetched at build time.

| Package | Version | How | Status |
|---|---|---|---|
| **evelin-bin** | 4.2.0 | official static-musl release tarball (7 fully-static binaries: `ev`, `evelin-agent`/`-client`/`-keygen`/`-keyscan`/`-server`, `evelin-multisig-verify`) | ✅ builds & runs (`evelin-client 4.2.0`) |
| **btp** | 0.7 | built from source (`cargo`), binaries patchelf'd to glibc/gcc | ✅ builds & runs (`btpctl`, `btpd`) |
| **mirim** | 1.1.0 | prebuilt x86_64 release binaries (`copy-build-system` + patchelf to store glibc/gcc), like `btp`/`evelin-bin`. v1.1.0 moved the binaries to the archive root and adds a `mirim-gui` (not packaged — needs a graphical runtime) | ✅ builds & runs (`mirim`, `mirim-sign`) |
| **torando-gui** | 1.3.4 | built from source (pure Python daemon; native GTK4/WebKit GUI optional, browser fallback). 1.2.0/1.3.0: ip6tables IPv6 killswitch (closes the v6 leak) + native macOS/BSD/Windows backends; 1.3.1–1.3.4: Windows all-in-one + packaging fixes — Linux channel build unchanged | ✅ builds, installs & runs (`torando-gui`, `torando-guid`) |
| **vaptvupt** | 5.2.1 | built from source (C11 Makefile; source-only since 4.1.0, links only `-lm -lpthread`; `make check` crypto/security suite runs in-build — since 5.0.0 incl. **FIPS 203 cross-validation against OpenSSL 3.5**, verified green). 5.0.0: ML-KEM-768 now genuinely FIPS 203-conformant; **BREAKING — `--pq`/`--pq-only` keys & archives from ≤ 4.2.1 no longer decrypt: regenerate keys + re-encrypt** (password mode/plain compression unaffected). 5.1.0–5.2.1: codec 2.65.0→2.65.3 (large text-ratio gains, ~2× faster extreme, byte-identical output); wire format stays v1.6, interoperable with 5.0.x. 4.2.0: critical `--dedup` keystream-reuse fix (re-encrypt `--dedup` archives from ≤ 4.1.0) | ✅ builds & runs; `--pq-only` round-trip verified |
| **vaptvupt-gui** | 5.2.1 | PySide6/Qt6 frontend from the same tarball (versioned with the CLI); 5.0.0 reworks it for source-only builds (build-aware Hybrid/Full-PQ selector, PQ-key auto-detect) + XWayland fallback so it appears on Sway; 5.2.x: thread-safe `_Job` controller (fixes compress crash/hang/corruption), CR progress frames parsed, robust Verify/Extract with encryption auto-detect + guided credentials; launcher pins the CLI via `VAPTVUPT_BIN` | ✅ builds (`vaptvupt-gui`, `zupt-gui`); GUI `--selftest` OK |
| **turborec** | 3.4.0 | built from source (pure-Python CLI + Tkinter GUI + bash X11 launcher; self-contained `#!/bin/sh` shims pin python3/bash + ffmpeg/pactl/xrandr/xdpyinfo/lspci, + Wayland wf-recorder/wlr-randr/swaymsg + wmctrl; 3.1.0 `--audio-channels`, 3.2.0 `-R/--resolution` scaling, 3.3.0 live streaming `record --stream KEY` (YouTube/RTMPS default) + adaptive quality, 3.4.0 security-audit fixes, 3.5.0 webcam PiP overlay (`--camera`) + mic noise suppression (`--denoise`), 3.6.0 `turborecorder` Wayland (wf-recorder) capture + static-screen stop fix) | ✅ builds & runs (`turborec`, `turborecorder`) |
| **esquema** | 0.2.0 | built from source (C core `libesquema.so` via `make` + libseccomp; Guile modules byte-compiled; ships the `(esquema esquema-service)` Shepherd service) | ✅ builds & FFI-loads (`esquema-init` → 42); functional/security/ASan suites green |
| **moneyprinterturbo** | 1.3.2 | vendored third-party (harry0703; not a forge repo). AI one-click short-video generator; the (font-pruned) upstream source + a self-contained launcher that builds a first-run venv over Tor; proprietary CJK fonts dropped and repointed to bundled WenQuanYi Zen Hei | ✅ builds; launcher boots (venv on first run) |

To re-vendor an updated app: rebuild/redownload its artifact into
`packages/sources/`, bump `version`, and `guix build -L . <pkg>`.

### Running torando-gui as a Shepherd service (Guix System)

Guix System runs daemons under the **GNU Shepherd**, not systemd — so the
systemd unit inside the `torando-gui` package is inert on Guix. The channel
ships a native service type in `(securityops services torando)`. Add it to your
`operating-system`:

```scheme
(use-modules (securityops services torando))

(operating-system
  ;; …
  (services
   (cons* (service torando-gui-service-type)        ; daemon on 127.0.0.1:8088
          (service tor-service-type)                ; Tor itself
          %desktop-services)))                       ; provides the 'networking target torando-gui requires
```

`guix system reconfigure`, then `herd start torando-gui` (or reboot). The daemon
runs as root under Shepherd, logs to `/var/log/torando-gui.log`, and serves the
token-injected UI on `http://127.0.0.1:8088/`; run the `torando-gui` launcher to
open it. Configuration fields: `host`, `port`, `package`, `config-file`,
`seed-config`, `extra-options`.

> **Turnkey on Guix.** `/etc/tor/torrc` is a read-only store symlink owned by
> `tor-service-type`, so torando-gui's own torrc management cannot write it. The
> service therefore **auto-seeds `/etc/torando-gui/config.json`** on first
> activation (only if absent, so GUI changes persist) with
> `"manage_torrc": false` and `"dns_port": 5353` — matching a `tor-service-type`
> configured with `(dns-port 5353)` (as on this host; torando's own default is
> 53, and TransPort 9040 / SocksPort 9050 / ControlPort 9051 are already
> torando's defaults). Override via the `seed-config` field (a JSON
> string, or `#f` to seed nothing). Netfilter rules, DNS pinning, killswitch and
> status all work; Tor service control from the GUI uses `systemctl` and is a
> no-op on Guix — manage Tor with `herd`.

### Esquema — rootless Guile-native container runtime

`esquema` (new module `(securityops packages containers)`) is a first-party,
security-first container runtime built natively in Scheme. A small C core
(`libesquema.so`, seccomp-BPF via libseccomp) performs the whole isolation
sequence in async-signal-safe code between `fork` and `execve`: user + mount +
PID + UTS + IPC + net + cgroup namespaces, rootless uid/gid maps, `pivot_root`
into the rootfs with the host tree detached, a full capability drop
(bounding set + ambient + `capset` + securebits + `no_new_privs`), a seccomp
allowlist with a stacked filter that kills TIOCSTI/TIOCLINUX terminal
injection, and best-effort cgroup v2 limits — stronger isolation than a plain
`guix shell` while staying daemon-free and rootless (~13 ms startup).

```sh
guix pull                 # or: -L ~/securityops-channel for the working tree
guix install esquema
```

```scheme
(use-modules (esquema runtime) (esquema container))
(run-container
 (make-container "web" "/path/to/rootfs" '("/bin/httpd" "-p" "8080")
                 #:rootfs-ro? #t
                 #:limits (make-limits (* 256 1024 1024) 128 50000 100000)))
```

`make-container` is secure-by-default (all namespaces, seccomp on, every
capability dropped). Installing the package puts the `(esquema …)` Guile
modules on `GUILE_LOAD_PATH` and repoints the FFI at the store `libesquema.so`,
so a bare `(use-modules (esquema runtime))` works. To supervise a container as
a Guix System service, use the bundled service type:

```scheme
(use-modules (esquema esquema-service)
             (securityops packages containers))   ; for the esquema package binding
;; esquema-configuration is a plain SRFI-9 record — POSITIONAL args, in order:
;; name, rootfs, command, scheme-dir.
(service esquema-service-type
         (esquema-configuration
          "web"
          "/srv/web"
          '("/bin/httpd" "-p" "8080")
          (file-append esquema "/share/guile/site/3.0")))
```

---

## Security toolset

`security.scm` re-exports a curated security toolset from Guix, so it installs
from this channel and tracks Guix.  Three are **bumped ahead of Guix** here
(inherit + version + real source hash), all built & run-verified: `nmap` 7.99
(Guix 7.98), `fping` 5.5 (Guix 5.3) and `hydra` 9.7 (Guix 9.6).  A few others
lag Guix but a *clean* bump is not just version+source, so they stay on Guix for
now: `mtr` 0.96 moved `utils.h` without fixing `packet/` includes; `radare2`
6.1.8 pulls a new `zydis` meson subproject not yet in Guix; `rizin` 0.9 reworked
its meson options.  `lynis` is bumped here too (3.1.7 vs Guix 3.1.1):

> **nmap 7.99** · masscan · arp-scan · netdiscover · **fping 5.5** · mtr · whois ·
> proxychains-ng · aircrack-ng · reaver · kismet · **hydra 9.7** (THC) · radare2 ·
> rizin · binwalk · age · **lynis 3.1.7**   *(bold = bumped ahead of Guix)*

**Not yet in Guix** (TODO — package on request; quick: Go/Rust single-binaries;
heavy: zaproxy/volatility3): `sqlmap` · `nikto` · `gobuster` · `ffuf` ·
`rustscan` · `dirb` · `wfuzz` · `whatweb` · `sslscan` · `wapiti` · `zaproxy` ·
`john-the-ripper` · `hashid` · `bettercap` · `ettercap` · `mitmproxy` · `dsniff` ·
`foremost` · `sleuthkit` · `volatility3` · `american-fuzzy-lop` · `honggfuzz` ·
`exploitdb` · `theharvester` · `recon-ng` · `dnsenum` · `fierce` · `zmap`.

---

## Install

This channel **depends on nonguix** (for google-chrome, steam and Mullvad's
build system) — keep your `nonguix` entry in `channels.scm`. Add securityops with
its `(introduction …)` so `guix pull` verifies every commit's signature:

```scheme
(channel
 (name 'securityops)
 (url "https://git.securityops.co/cristiancmoises/securityops-channel")
 (branch "main")
 (introduction
  (make-channel-introduction
   "af46f5cce66179f3e53f87c86ca2538c8fc63f98"
   (openpgp-fingerprint
    "0CFA 43B9 AA96 42EA AF2B  E983 C4C6 61C9 ECFB 46E8"))))
```

The official URL clones over **HTTPS** with no account. Prefer a mirror? Swap the
`url` — the introduction is identical:

```scheme
 (url "https://codeberg.org/berkeley/securityops-channel")   ; or
 (url "https://github.com/cristiancmoises/securityops-channel")
```

Then:

```sh
guix pull
guix install kitty tor torbrowser openshot google-chrome-stable mullvad-vpn-desktop
# everything else resolves to the same package guix/nonguix ships
```

Because every package here has a version **≥** what guix/nonguix ships,
`guix install <pkg>` transparently prefers this channel for the bumped ones.

> Adding `securityops` without a `(commit …)` line tracks its `main` branch; add
> one to pin a fully reproducible pull. The `(introduction …)` is set once and is
> independent of any later pin.

### Clone or pull over HTTPS

Clone over HTTPS from the official forge — or any mirror — with no account:

```sh
git clone https://git.securityops.co/cristiancmoises/securityops-channel   # official
git clone https://codeberg.org/berkeley/securityops-channel               # mirror
git clone https://github.com/cristiancmoises/securityops-channel          # mirror
```

### Verify the introduction and signatures

The `(introduction …)` pins the first signed commit and the maintainer key, so
`guix pull` authenticates every commit — a tampered or unsigned commit aborts the
pull. To check the key out of band:

```sh
gpg --recv-keys 0CFA43B9AA9642EAAF2BE983C4C661C9ECFB46E8
gpg --fingerprint 0CFA43B9AA9642EAAF2BE983C4C661C9ECFB46E8
#   → 0CFA 43B9 AA96 42EA AF2B  E983 C4C6 61C9 ECFB 46E8
git -C securityops-channel log --show-signature -1
```

### Troubleshooting

- **`guix pull` says the channel is unauthenticated / introduction mismatch.**
  Your `channels.scm` entry is missing the `(introduction …)` above (copy it
  verbatim) or pins a commit older than the introduction commit.
- **`failed to authenticate commit … signature verification failed`.** Import
  `0CFA43B9AA9642EAAF2BE983C4C661C9ECFB46E8` into your keyring; authentication
  applies from the introduction commit forward.
- **nonguix introduction conflict.** Keep your `nonguix` pin at or after its
  introduction commit `897c1a47…` so both channels authenticate.

### Consuming the channel from `/etc/config.scm` and `home.scm`

A bare `kitty` / `tor` / `torbrowser` / `google-chrome-stable` written against
`(gnu packages …)` / `(nongnu packages …)` resolves to *guix's own* (older)
package, **not** this channel's — module bindings are resolved by the module you
import, while `guix install <name>` is what picks the highest version by name. So
to actually run the bumped versions declaratively, import the channel module with
a prefix and reference the prefixed symbol:

```scheme
;; in (use-modules …)
((securityops packages terminals) #:prefix so:)   ; so:kitty   0.48.0 (gnu 0.46.2)
((securityops packages tor)       #:prefix so:)   ; so:tor     0.4.9.11, so:torbrowser 15.0.19
((securityops packages browsers)  #:prefix so:)   ; so:google-chrome-stable 150, so:librewolf 153.0-3
((securityops packages vpn)       #:prefix so:)   ; so:mullvad-vpn-desktop  2026.3
((securityops packages video)     #:prefix so:)   ; so:openshot 3.5.1 (gnu 3.4.0)
((securityops packages games)     #:prefix so:)   ; so:steam   1.0.0.87 (nonguix 1.0.0.85)
((securityops packages monitoring) #:prefix so:)  ; so:glances 4.5.5 (gnu 4.3.0)

;; …then in the package list use so:kitty, so:tor, so:torbrowser, …
;; and for the daemon, override the service field:
(service mullvad-daemon-service-type
         (mullvad-daemon-configuration
          (mullvad-vpn-desktop so:mullvad-vpn-desktop)))
```

The live `/etc/config.scm` and `~/.config/guix/home.scm` are wired this way for
exactly the packages that are ahead of guix/nonguix; the re-exports
(`alacritty`, `fish`, `emacs`, `mpv`, `vlc`, `keepassxc`, `ueberzugpp`, `lf`)
are byte-identical to guix's, so they are left as bare symbols.

To apply after a channel edit: `guix pull` (picks up the new `securityops`
commit), then `guix system reconfigure /etc/config.scm` and `guix home
reconfigure ~/.config/guix/home.scm` — or skip the pull and pass
`-L ~/securityops-channel` to reconfigure to use the working tree directly.

---

## Layout

```
securityops-channel/
├── update-channel             # check + auto-apply upstream updates (one command)
├── .guix-channel              # manifest: version, news-file, public url, nonguix dep
├── .guix-authorizations       # OpenPGP keys allowed to sign commits (channel auth)
├── etc/news.txt              # `guix pull --news` entries (per release)
├── securityops/packages/
│   ├── terminals.scm         # kitty 0.48.0 (bump) + its three new Go deps, alacritty (re-export)
│   ├── tor.scm               # tor, torbrowser, torbrowser-assets (bumps)
│   ├── shells.scm            # fish (re-export)
│   ├── emacs.scm             # emacs, emacs-pgtk (re-export)
│   ├── video.scm             # openshot (bump), mpv, vlc (re-export)
│   ├── utils.scm             # keepassxc, ueberzugpp, lf (re-export)
│   ├── browsers.scm          # google-chrome (bump), librewolf + ungoogled-chromium-bin (re-export of ↓), ungoogled-chromium (re-export)
│   ├── librewolf.scm         # librewolf 153.0-3 (vendored make-librewolf-source)
│   ├── chromium.scm          # ungoogled-chromium-bin 150.0.7871.128 (prebuilt, chromium-binary-build-system)
│   ├── vpn.scm               # mullvad-vpn-desktop (vendored bump)
│   ├── games.scm             # steam 1.0.0.87 (nonguix container, bumped bootstrap)
│   ├── apps.scm              # first-party: evelin-bin, btp, mirim, torando-gui, vaptvupt(+gui), turborec, moneyprinterturbo (vendored)
│   ├── security.scm          # curated security toolset (re-exports) + lynis 3.1.7 (bump)
│   ├── monitoring.scm        # glances 4.5.5 (bump) + python-pyinstrument 5.1.2 (private dep bump)
│   ├── containers.scm        # esquema 0.2.0 — rootless Guile-native container runtime (first-party, from source)
│   └── sources/              # vendored release/built artifacts (local-file)
├── securityops/services/
│   └── torando.scm           # torando-gui-service-type (GNU Shepherd service)
├── README.md  CHANGELOG.md  AUDIT.md  LICENSE
└── .dir-locals.el  .gitignore
```

Each module imports the matching upstream module **with a prefix**
(`#:use-module ((gnu packages tor) #:prefix tor:)`) and either re-exports the
binding or defines `(package (inherit tor:tor) (version …) (source …))`. Most
definitions are a few lines, so upstream bugfixes flow through automatically.

---

## Caveats (read before relying on a build)

**Tor Browser (source build).** Guix's `make-torbrowser` and `torbrowser-assets`
are module-private, so `torbrowser` here inherits guix's package and overrides
`version` + `source` (the 15.0.19 Firefox source, `140.13.0esr-15.0-1-build2`)
**plus the two version constants guix's `make-torbrowser` bakes from its own
`%torbrowser-version` (15.0.14)**: without this the browser would report *15.0.14
on a 15.0.19 engine*, so the recipe rewrites `--with-base-browser-version` →
`15.0.19` and `MOZ_BUILD_DATE` → the official 15.0.19 BuildID `20260720080000`
(from the upstream bundle's `application.ini`) — the About dialog now reads
**15.0.19**. Only the bundled fonts/torrc-defaults + l10n still come from guix's
15.0.14 assets (identical across the patch release; Tor Browser spoofs
`navigator.buildID` to web content regardless). The standalone
`torbrowser-assets` (15.0.19) is provided for a fully-pristine rebuild.

**LibreWolf 153 (done).** Bumped to 153.0-3 (major 152→153) in the module
`securityops/packages/librewolf.scm`, which vendors guix's *private*
`make-librewolf-source` (Firefox source + librewolf overlay + l10n) and then
inherits guix's `librewolf`, overriding only `version` + `source`. The l10n commit
is the `revision` from `firefox-153.0/browser/locales/l10n-changesets.json`
(`235fd5b0`). The computed-origin source is assembled and verified
(`guix build -S librewolf` → `librewolf-153.0-3.source.tar.zst`); the full
Firefox compile is left to the reconfigure (full LTO, see the RAM note below).
Wired into `/etc/config.scm` and `home.scm` as `so:librewolf`.

> **Building Firefox-class packages (librewolf / torbrowser / icecat) on a
> RAM-constrained host.** Their final rust crate `gkrust` is whole-program LTO —
> a *single* rustc that needs ~14 GiB — so on a 15 GiB box it OOM-kills at every
> `-j` (24 down to 1), with or without `--disable-lto`. The fix is **swap**: a
> 24 GiB disk swapfile (now declared in `config-xlibre.scm` via `swap-devices`)
> lets the full-LTO build complete (peaks spill to disk); then
> `guix build --cores=4 librewolf` finishes cleanly and the browser runs.

**ungoogled-chromium — prebuilt 150 (`ungoogled-chromium-bin`), source-build
blocked over Tor.** A *from-source* bump is not merely guix-maintainer-level
work here, it is **impossible on this Tor-only host**: guix assembles the source
from a Chromium "-lite" base tarball that lives only on Google's
`commondatastorage` GCS bucket, and that bucket **403-blocks every Tor exit**
(verified across 6+ rotated circuits — even the tiny `.hashes` integrity file and
guix's own known-good 147 tarball; no Wayback copy exists). guix can build
*existing* versions only because their source is served as a substitute
(`.tar.zst`) from `bordeaux.guix.gnu.org`; a brand-new release has no substitute,
so its base tarball must come straight from Google. (It would also be a multi-hour
/ ~30GB-RAM compile on 15GB RAM regardless.) **Resolution:** the channel now ships
`ungoogled-chromium-bin` — the official upstream **prebuilt** portable Linux
x86_64 binary `150.0.7871.128-1` (the newest prebuilt), hosted on GitHub
(Tor-reachable), `sha256`-verified against
the upstream `ungoogled-chromium-binaries` metadata, and wrapped with nonguix's
`chromium-binary-build-system` (patchelf onto the Guix glibc loader + library set;
no bundled `chrome-sandbox`, so Chromium uses the unprivileged user-namespace
sandbox). Build-and-run verified: `chromium --version` → `Chromium 150.0.7871.128`.
The source-built `ungoogled-chromium` (147) remains re-exported for anyone wanting
the substitutable build; `google-chrome-stable` 150 also provides a current engine.

**Mullvad (vendored, x86_64-only).** Bumped to 2026.3 — Mullvad's *published*
stable desktop release as of 2026-06-22 (the `deb/latest` redirect resolves to
`.../releases/2026.3/`; 2026.4+ aren't promoted yet — re-check the redirect
before bumping further). The source URL moved off GitHub (which no longer carries
desktop `.deb`s) to `cdn.mullvad.net`. Vendored rather than inherited because the
build phases bake `version` into the `.deb` unpack step. The
`mullvad-daemon-service-type` in `/etc/config.scm` is pointed at this package so
the **daemon itself** runs 2026.3 (not just a profile entry). Add the aarch64
variant + hash if you need it.

---

## Verification

Done 2026-06-21 against the live daemon (egress works through Tor):

- **Real hashes**, from actual downloads: tarballs via `guix download`; git tags
  (`kitty`, `openshot`) via `guix hash -rx` over `git clone -b <tag>`;
  `.deb`s (`google-chrome`, `mullvad`) via `guix download`.
- **Channel evaluates:** `guix build -L . [-L <nonguix>] -n <all packages>`
  computes the full derivation graph with no errors (modules load exactly as a
  channel does).
- **Sources fetch + hash-match:** `guix build -L . -S` succeeds for every bumped
  package (`tor`, `torbrowser`, `torbrowser-assets`, `kitty`, `openshot`,
  `google-chrome-stable`, `mullvad-vpn-desktop`; `librewolf`'s computed-origin
  source was assembled & verified 2026-06-22) — `kitty`/`openshot` actually
  re-ran their `git-fetch` derivations and matched.

Full multi-hour compiles (emacs, kitty, vlc, the Firefox-based torbrowser) are
left to your `guix pull` / reconfigure, per the chosen "verified hashes +
evaluate" depth.

---

## Keeping packages current — `./update-channel`

One command checks every channel package against upstream and auto-applies the
updates Guix can do safely:

```sh
./update-channel                       # check: current vs latest for every package
./update-channel update --build --commit   # apply guix-refresh updates, build-verify, sign-commit
```

- **Auto** (via `guix refresh -u` — rewrites `version` + real `sha256`): the
  github/gnu/pypi-backed packages (`kitty`, `openshot`, `tor`, `glances`, …).
- **Reported, apply deliberately:** source-builds (`torbrowser`, `librewolf` —
  auto-bumping triggers multi-hour compiles) and binary/vendored packages
  (`google-chrome-stable`, `steam`, `mullvad-vpn-desktop`, `ungoogled-chromium-bin`,
  the first-party apps). The tool prints the exact upstream version and the file
  to edit, then bump it by hand:

## Bumping a package later

```sh
guix refresh <pkg>                                   # find latest
guix download <tarball-url>                           # url-fetch hash
git clone --depth 1 -b <tag> <repo> /tmp/s && guix hash -rx /tmp/s   # git hash
# edit version + base32 in securityops/packages/*.scm
guix build -L ~/securityops-channel -S <pkg>          # verify source
guix build -L ~/securityops-channel -n <pkg>          # verify it evaluates
```

When a re-exported package falls behind upstream, turn its
`(define-public foo bar:foo)` into a full `(package (inherit bar:foo) (version …)
(source …))`.

---

## Publishing & authentication

The channel is published and **authenticated**. Everyone clones and pulls over
**HTTPS** from `git.securityops.co` (or the Codeberg/GitHub mirrors above); push
is restricted to the maintainer. Every commit is **GPG-signed** with ed25519
`0CFA 43B9 AA96 42EA AF2B  E983 C4C6 61C9 ECFB 46E8`; `.guix-authorizations` lists
that key as the sole authorized signer, and the channel `(introduction …)` in
*Install* pins the first signed commit — so `guix pull` verifies the whole history
and refuses a tampered or unsigned commit. The authorized public key is published
on the channel's `keyring` branch (the standard `guix git authenticate` layout),
which `guix pull` fetches automatically. To rotate the key, add the new
fingerprint to `.guix-authorizations` in a commit signed by the old key.

---

## License

Channel code: **GPL-3.0-or-later** (see [LICENSE](LICENSE)); `vpn.scm` carries
the upstream small-guix copyright headers it was vendored from. Each packaged
program keeps its own upstream license, declared in its definition.

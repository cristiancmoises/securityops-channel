# securityops — a personal GNU Guix channel

> Latest upstream versions of the **securityops** workstation's most-used
> applications, packaged the Guix way — real source hashes, every definition
> inheriting from upstream so it stays small and auditable.

This channel curates the programs this machine lives in and keeps them at the
newest official release. Packages the pinned Guix already ships at the latest
upstream version are **re-exported unchanged** (so the channel is the single
place you install them from, and they track Guix automatically); packages that
are *ahead* of Guix/nonguix carry a **real, downloaded source hash**.

- **Host:** `predator-helios-intel` (the live `/etc/config.scm` machine)
- **Pinned Guix:** commit `d1e9e23` (June 2026); **depends on** `nonguix`
- **Built/verified:** 2026-06-21; **re-validated 2026-06-22** (Mullvad → 2026.3)
- **Maintainer:** Cristian Cezar Moisés `<ethicalhacker@riseup.net>`

---

## The curated set

### ⬆️ Bumped ahead of Guix / nonguix (real downloaded hashes)

| Package | This channel | Upstream had | Source |
|---|---|---|---|
| **kitty** | 0.47.4 | 0.46.2 (guix) | git tag `v0.47.4` |
| **tor** | 0.4.9.9 | 0.4.9.8 (guix) | dist.torproject.org tarball |
| **torbrowser** | 15.0.16 | 15.0.14 (guix) | source build (see caveat) |
| **torbrowser-assets** | 15.0.16 | _(private in guix)_ | official bundle |
| **openshot** | 3.5.1 | 3.4.0 (guix) | git tag `v3.5.1` |
| **google-chrome-stable** | 149.0.7827.155 | 148.0.7778.215 (nonguix) | dl.google.com `.deb` |
| **mullvad-vpn-desktop** | 2026.3 | 2025.8 (small-guix) | cdn.mullvad.net `.deb` (vendored) |

### ✅ Re-exported — already latest in Guix/nonguix (track upstream automatically)

`alacritty` 0.17.0 · `fish` 4.7.1 · `emacs` 30.2 · `emacs-pgtk` 30.2 ·
`mpv` 0.41.0 · `vlc` 3.0.23 · `keepassxc` 2.7.12 · `ueberzugpp` 2.9.10 ·
`lf` 41 · `steam` (self-updating bootstrap)

### ⚠️ Re-exported — newer upstream exists but a bump is impractical here

| Package | This channel (= guix) | Upstream | Why not bumped |
|---|---|---|---|
| **librewolf** | 151.0.4-1 | 152.0.1-2 | guix's source builder is private; needs vendoring + ~500MB Firefox source (recipe below) |
| **ungoogled-chromium** | 147.0.7727.137-1 | 149.0.7827.155-1 | multi-GB source + many-hour / large-RAM compile; lags Chrome by design |

> A full version audit of **every other** package in `/etc/config.scm` and
> `~/.config/guix/home.scm` (yours vs. latest upstream) is in **[AUDIT.md](AUDIT.md)**
> — 391 packages: 124 current, 139 outdated, 128 unknown.

---

## First-party apps (`git.securityops.co/cristiancmoises`)

The forge is **SSH-key-only** (anonymous HTTP disabled), so the Guix daemon
can't fetch these with a normal origin. Sources/artifacts are **vendored** into
`securityops/packages/sources/` and referenced with `local-file`
(content-addressed, no hash field) — the channel stays self-contained and builds
with no network or SSH.

| Package | Version | How | Status |
|---|---|---|---|
| **evelin-bin** | 4.1.1 | official static-musl release tarball | ✅ builds & runs |
| **btp** | 0.7 | built from source (`cargo`), binaries patchelf'd to glibc/gcc | ✅ builds & runs (`btpctl`, `btpd`) |
| **mirim** | 1.0.0 | built from source (builds under Rust 1.93 despite 1.96 pin) | ✅ builds & runs (`mirim`, `mirim-sign`) |
| **vaptvupt** | 2.2.3 | C core + Python GUI → AppImage | ⏳ deferred (complex; cleanest as the official `.AppImage`) |
| **turborec** | — | — | ⛔ deploy key not authorized to read the repo |

To re-vendor an updated app: rebuild/redownload its artifact into
`packages/sources/`, bump `version`, and `guix build -L . <pkg>`.

## Security toolset

`security.scm` re-exports the curated tools that Guix already ships current, so
they install from this channel and track Guix:

> nmap · masscan · arp-scan · netdiscover · fping · mtr · whois ·
> proxychains-ng · aircrack-ng · reaver · kismet · hydra (THC) · radare2 ·
> rizin · binwalk · age

**Not yet in Guix** (TODO — package on request; quick: Go/Rust single-binaries;
heavy: zaproxy/volatility3): `sqlmap` · `nikto` · `gobuster` · `ffuf` ·
`rustscan` · `dirb` · `wfuzz` · `whatweb` · `sslscan` · `wapiti` · `zaproxy` ·
`john-the-ripper` · `hashid` · `bettercap` · `ettercap` · `mitmproxy` · `dsniff` ·
`foremost` · `sleuthkit` · `volatility3` · `american-fuzzy-lop` · `honggfuzz` ·
`exploitdb` · `theharvester` · `recon-ng` · `dnsenum` · `fierce` · `zmap`.

---

## Install

This channel **depends on nonguix** (for google-chrome, steam and Mullvad's
build system) — you already have it in `channels.scm`. Add securityops:

```scheme
(channel
 (name 'securityops)
 (url "file:///home/berkeley/securityops-channel")
 (branch "main"))
```

Then:

```sh
guix pull
guix install kitty tor torbrowser openshot google-chrome-stable mullvad-vpn-desktop
# everything else resolves to the same package guix/nonguix ships
```

Because every package here has a version **≥** what guix/nonguix ships,
`guix install <pkg>` transparently prefers this channel for the bumped ones.

> Your `channels.scm` is currently *pinned*. Adding `securityops` without a
> `(commit …)` line tracks its `main` branch; pin it the same way for fully
> reproducible pulls.

### Consuming the channel from `/etc/config.scm` and `home.scm`

A bare `kitty` / `tor` / `torbrowser` / `google-chrome-stable` written against
`(gnu packages …)` / `(nongnu packages …)` resolves to *guix's own* (older)
package, **not** this channel's — module bindings are resolved by the module you
import, while `guix install <name>` is what picks the highest version by name. So
to actually run the bumped versions declaratively, import the channel module with
a prefix and reference the prefixed symbol:

```scheme
;; in (use-modules …)
((securityops packages terminals) #:prefix so:)   ; so:kitty   0.47.4 (gnu 0.46.2)
((securityops packages tor)       #:prefix so:)   ; so:tor     0.4.9.9, so:torbrowser 15.0.16
((securityops packages browsers)  #:prefix so:)   ; so:google-chrome-stable 149 (nongnu 148)
((securityops packages vpn)       #:prefix so:)   ; so:mullvad-vpn-desktop  2026.3

;; …then in the package list use so:kitty, so:tor, so:torbrowser, …
;; and for the daemon, override the service field:
(service mullvad-daemon-service-type
         (mullvad-daemon-configuration
          (mullvad-vpn-desktop so:mullvad-vpn-desktop)))
```

The live `/etc/config.scm` and `~/.config/guix/home.scm` are wired this way for
exactly the packages that are ahead of guix/nonguix; the re-exports
(`alacritty`, `fish`, `emacs`, `mpv`, `vlc`, `keepassxc`, `ueberzugpp`, `lf`,
`steam`) are byte-identical to guix's, so they are left as bare symbols.

To apply after a channel edit: `guix pull` (picks up the new `securityops`
commit), then `guix system reconfigure /etc/config.scm` and `guix home
reconfigure ~/.config/guix/home.scm` — or skip the pull and pass
`-L ~/securityops-channel` to reconfigure to use the working tree directly.

---

## Layout

```
securityops-channel/
├── .guix-channel              # manifest: version, news-file, url, nonguix dep
├── etc/news.txt              # `guix pull --news` entries (per release)
├── securityops/packages/
│   ├── terminals.scm         # kitty (bump), alacritty (re-export)
│   ├── tor.scm               # tor, torbrowser, torbrowser-assets (bumps)
│   ├── shells.scm            # fish (re-export)
│   ├── emacs.scm             # emacs, emacs-pgtk (re-export)
│   ├── video.scm             # openshot (bump), mpv, vlc (re-export)
│   ├── utils.scm             # keepassxc, ueberzugpp, lf (re-export)
│   ├── browsers.scm          # google-chrome (bump), librewolf, ungoogled-chromium (re-export)
│   ├── vpn.scm               # mullvad-vpn-desktop (vendored bump)
│   ├── games.scm             # steam (re-export)
│   ├── apps.scm              # first-party: evelin-bin, btp (vendored)
│   ├── security.scm          # curated security toolset (re-exports)
│   └── sources/              # vendored release/built artifacts (local-file)
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
only `version` + `source` (the 15.0.16 Firefox source,
`140.12.0esr-15.0-1-build2`). The bundled assets, l10n/translation commits and
`MOZ_BUILD_DATE` stay at the 15.0.14 baseline — fonts/torrc/localisation that
don't change across a patch release. The standalone `torbrowser-assets` (15.0.16)
is provided for a fully-pristine rebuild.

**LibreWolf 152 (not done — recipe).** Guix builds librewolf via the *private*
`make-librewolf-source` (Firefox source + librewolf overlay + l10n). To ship
152.0.1-2: vendor `firefox-source-origin`, `librewolf-source-origin`, the l10n
origin and `make-librewolf-source` from `gnu/packages/librewolf.scm` into a
channel module; `guix download` the Firefox 152.0.1 source (~500MB) and
`git`-hash the codeberg `librewolf/source` tag `152.0.1-2`; then
`(make-librewolf-source #:version "152.0.1-2" #:firefox-hash … #:librewolf-hash …)`.
Ask and I'll do it.

**ungoogled-chromium 149 (not done).** A source bump is a multi-GB download and a
many-hour/large-RAM compile — out of scope for "verified hashes + evaluate".

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
  `google-chrome-stable`, `mullvad-vpn-desktop`) — `kitty`/`openshot` actually
  re-ran their `git-fetch` derivations and matched.

Full multi-hour compiles (emacs, kitty, vlc, the Firefox-based torbrowser) are
left to your `guix pull` / reconfigure, per the chosen "verified hashes +
evaluate" depth.

---

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

## Publishing (optional)

Local, unauthenticated today. To publish: push to a Git remote, change `url` in
`.guix-channel` + `channels.scm`, add a `.guix-authorizations`, sign your commits,
and add a channel `(introduction …)` to enable signature verification on pull.

---

## License

Channel code: **GPL-3.0-or-later** (see [LICENSE](LICENSE)); `vpn.scm` carries
the upstream small-guix copyright headers it was vendored from. Each packaged
program keeps its own upstream license, declared in its definition.

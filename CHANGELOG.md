# Changelog

All notable changes to the **securityops** Guix channel are documented here.
Format per [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); released by
tag rather than SemVer of the code.

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

[0.1.0]: #010--2026-06-21

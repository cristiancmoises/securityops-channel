# Usage reference

Operational examples for GNU Guix System and Guix Home. For current versions and validation, see [the package index](../PACKAGES.md) and [the refresh report](../docs/refresh-2026-09-06.md).

### Services (2)

Two native **GNU Shepherd** service types for `guix system reconfigure` — the
systemd units shipped in the upstream packages are inert on Guix System, so the
channel supplies real Shepherd services:

| Service type | Module | Configuration (fields) | Purpose |
|---|---|---|---|
| `torando-gui-service-type` | `(securityops services torando)` | `torando-gui-configuration`: `package`, `host` (def. `127.0.0.1`), `port` (def. `8088`), `config-file`, `extra-options`, `seed-config` | Runs the Torando Control daemon (`torando-guid`) as root under Shepherd — programs netfilter, pins `resolv.conf`, manages `torrc` — and serves the token-injected UI on `http://127.0.0.1:8088/`. Auto-seeds `/etc/torando-gui/config.json` on first activation (so GUI changes persist). Requires the `networking` target; pair with `tor-service-type`. |
| `esquema-service-type` | `(esquema esquema-service)` — shipped by the `esquema` package | `esquema-configuration` (positional): `name`, `rootfs`, `command`, `scheme-dir` | Supervises a single rootless `esquema` container as a Shepherd service (declarative `<container>`, all namespaces + seccomp + full capability drop). |

Full `(operating-system …)` examples are below: [**torando-gui service**](#running-torando-gui-as-a-shepherd-service-guix-system) and [**esquema service**](#esquema--rootless-guile-native-container-runtime).

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

### Consuming the channel from `/etc/config.scm` and `home.scm`

`xlibre-server`, its drivers and the compatibility `(xlibre)` module are
included in SecurityOps. No external XLibre channel is required. Use
`((securityops packages xlibre) #:prefix so:)` and `so:xlibre-server`.
The server source remains pinned to 25.2.2; the obsolete Intel-driver patch
is omitted because its policy is already upstream.

A bare bumped package such as `kitty`, `fish`, `radare2`, or
`google-chrome-stable` written against `(gnu packages …)` / `(nongnu packages
…)` resolves to *guix's own* (older) package, **not** this channel's — module
bindings are resolved by the module you import, while `guix install <name>` is
what picks the highest version by name. To run the bumped versions
declaratively, import the channel module with a prefix and reference the
prefixed symbol:

```scheme
;; in (use-modules …)
((securityops packages terminals) #:prefix so:)   ; so:kitty   0.48.2 (gnu 0.46.2)
((securityops packages shells)    #:prefix so:)   ; so:fish    4.8.1 (gnu 4.7.1)
((securityops packages tor)       #:prefix so:)   ; so:tor     0.4.9.11, so:torbrowser 15.0.20
((securityops packages browsers)  #:prefix so:)   ; so:google-chrome-stable 152, so:librewolf 153.0.4-1
((securityops packages utils)     #:prefix so:)   ; so:lf      42 (gnu 41; tag r42)
((securityops packages security)  #:prefix so:)   ; so:mtr, so:sdb, so:radare2, so:rizin
((securityops packages vpn)       #:prefix so:)   ; so:mullvad-vpn-desktop  2026.3
((securityops packages video)     #:prefix so:)   ; so:openshot 4.0.0 (gnu 3.4.0)
((securityops packages games)     #:prefix so:)   ; so:steam   1.0.0.87 (nonguix 1.0.0.85)
((securityops packages monitoring) #:prefix so:)  ; so:glances 4.5.6 (gnu 4.3.0)
((securityops packages xlibre)    #:prefix so:)   ; so:xlibre-server 25.2.2 (included)

;; …then in the package list use so:kitty, so:fish, so:radare2, …
;; and for the daemon, override the service field:
(service mullvad-daemon-service-type
         (mullvad-daemon-configuration
          (mullvad-vpn-desktop so:mullvad-vpn-desktop)))
```

Use this pattern for every package carried ahead of guix/nonguix. The remaining
re-exports (`alacritty`, `emacs`, `mpv`, `vlc`, `keepassxc`, and `ueberzugpp`)
are byte-identical to guix's and can remain bare symbols.

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
│   ├── terminals.scm         # kitty 0.48.2 (bump) + its three Go deps, alacritty (re-export)
│   ├── tor.scm               # tor, torbrowser, torbrowser-assets (bumps)
│   ├── shells.scm            # fish 4.8.1 hermetic Cargo source build
│   ├── fish-crates.scm       # Fish 4.8.1 Cargo.lock-matched offline sources
│   ├── emacs.scm             # emacs, emacs-pgtk (re-export)
│   ├── video.scm             # openshot 4.0.0 (bump), mpv, vlc (re-export)
│   ├── xlibre.scm            # xlibre-server 25.2.2 export (bundled implementation)
│   ├── utils.scm             # lf 42/tag r42 (bump) + seven private Go modules; keepassxc/ueberzugpp (re-export)
│   ├── browsers.scm          # google-chrome (bump), librewolf + ungoogled-chromium-bin (re-export of ↓), ungoogled-chromium (re-export)
│   ├── librewolf.scm         # librewolf 153.0.4-1 (vendored make-librewolf-source)
│   ├── chromium.scm          # ungoogled-chromium-bin 151.0.7922.173-1 (prebuilt)
│   ├── vpn.scm               # mullvad-vpn-desktop (vendored bump)
│   ├── games.scm             # steam 1.0.0.87 stable (nonguix container, bumped bootstrap)
│   ├── apps.scm              # first-party: evelin-bin, btp, mirim, torando-gui, zupt(+gui), turborec, moneyprinterturbo (vendored)
│   ├── security.scm          # curated toolset; mtr/sdb/radare2/rizin + other bumps/re-exports
│   ├── monitoring.scm        # glances 4.5.6 (bump) + python-pyinstrument 5.1.3 (private dep)
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

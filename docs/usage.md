# Usage reference

Operational examples for GNU Guix System and Guix Home. For current versions
and validation, see [the package index](../PACKAGES.md).

## AutoFirma

The channel provides the official stable **Linux release, 1.9**, through
`(securityops packages autofirma)`. The 1.9.1 and 1.9.2 downloads are macOS
releases, not Linux upgrades. See the [official downloads](https://firmaelectronica.gob.es/descargas).

Installation is optional and separate from adding the channel:

```sh
guix install autofirma
autofirma
autofirmacl -help
```

### Runtime and certificates

The recipe preserves the official signed JAR and its bundled Java libraries.
It uses a private, Guix-linked Eclipse Temurin **17.0.20.1+1** runtime rather
than depending on whichever Java version happens to be in your profile.
NSS 3.129 and NSPR 4.40 reuse the channel's LibreWolf inputs; the native
library directory also includes SQLite 3.53.4.

It includes a desktop entry for `afirma://` links, but does not register it as
your default handler. It does not run privileged installer scripts, import
certificates or alter Firefox settings. Browser signing requires separate
provisioning and trust of the local-service certificate; smart cards require
a running PC/SC service.

### Graphical launch and external documents

The graphical launcher uses Bubblewrap to supply conventional NSS paths and
a readable `/opt` without changing the host filesystem. It requires
unprivileged user namespaces. This is a compatibility layout, not a security
sandbox: your home, network and selected display, session-bus and PC/SC sockets
remain accessible. `autofirmacl` runs directly, without this layout.

Documents in your home are available by default. To select documents from
other existing directories, explicitly share them before launching:

```sh
AUTOFIRMA_SHARED_DIRECTORIES="/mnt/documents:/media/archive" autofirma
```

Use absolute directory paths separated by colons. Broad system roots and
invalid paths are rejected; spaces within a directory name are supported.

### Verification

The command-line checks sign a disposable document with a temporary PKCS12
identity and independently verify the detached signature with OpenSSL.
They do not use your certificates or live preferences. Two runtime checks
exercise Java subprocess creation, and eight invalid directory shares are
rejected. Desktop metadata and GUI startup under Xvfb have also been checked,
including paths with spaces. Signing through the graphical interface, smart
cards, Wayland and end-to-end browser integration remain untested.

To verify the package without installing it:

```sh
guix build -L . -e '(@ (securityops packages autofirma) autofirma)'
guile -s tests/autofirma.scm.in /gnu/store/…-autofirma-1.9
bash tests/autofirma-gui.sh /gnu/store/…-autofirma-1.9
```

The final native-library checks used existing runtime outputs with
`guix build --no-grafts`. Normal builds keep Guix's default grafting behavior
and may need additional output substitutes or a builder. No grafting policy
was disabled in the recipe.

## Services

Two native **GNU Shepherd** service types for `guix system reconfigure` — the
systemd units shipped in the upstream packages are inert on Guix System, so the
channel supplies real Shepherd services:

| Service type | Module | Purpose |
|---|---|---|
| `torando-gui-service-type` | `(securityops services torando)` | Run Torando Control as root under Shepherd |
| `esquema-service-type` | `(esquema esquema-service)`, included in `esquema` | Supervise one rootless container |

Configuration and `(operating-system …)` examples follow below.

### Running torando-gui as a Shepherd service (Guix System)

Guix System runs daemons under the **GNU Shepherd**, not systemd — so the
systemd unit inside the `torando-gui` package is inert on Guix. The channel
ships a native service type in `(securityops services torando)`. Add it to your
`operating-system`:

```scheme
(use-modules (guix gexp)
             (gnu services networking)
             (securityops services torando))

(operating-system
  ;; …
  (services
   (cons* (service torando-gui-service-type)
          (service tor-service-type
                   (tor-configuration
                    ;; Supply the Tor configuration you have prepared and tested.
                    (config-file (local-file "torrc"))))
          %desktop-services)))
```

`guix system reconfigure`, then `herd start torando-gui` (or reboot). The daemon
runs as root under Shepherd, logs to `/var/log/torando-gui.log`, and serves the
token-injected UI on `http://127.0.0.1:8088/`; run the `torando-gui` launcher to
open it. It manages netfilter and `resolv.conf`, requires the `networking`
target and should be paired with `tor-service-type`.

The `torando-gui-configuration` fields are:

| Field | Use |
|---|---|
| `host` | Listen address; defaults to `127.0.0.1` |
| `port` | Web interface port; defaults to `8088` |
| `package` | Torando package used by the service |
| `config-file` | Daemon configuration file |
| `seed-config` | Initial configuration when no daemon configuration exists |
| `extra-options` | Additional daemon arguments |

Guix generates Tor's configuration in the read-only store. The Torando service seeds
its own `/etc/torando-gui/config.json` only when that file is absent, with
`manage_torrc` disabled. It therefore does not configure Tor's listeners.
Its seed expects DNS port 5353, transparent proxy port 9040, SOCKS port 9050
and control port 9051. Prepare Tor's `config-file` to match the listeners and
authentication you intend to use, or adapt Torando's `seed-config` accordingly.
The default `tor-service-type` alone does not establish this integration.

Changing `seed-config` does not overwrite an existing Torando configuration.
Review that file as well when changing Tor's ports. The GUI's `systemctl` calls
do not manage Tor on Guix; use Shepherd (`herd`). Installing these services is
not a validation of DNS routing, firewall rules or the killswitch on a machine.

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

Scheme resolves a package through the module you import. Importing the channel
with a prefix makes that choice explicit, including for packages whose names
also exist in Guix or Nonguix:

```scheme
(use-modules ((securityops packages terminals) #:prefix so:)
             ((securityops packages shells) #:prefix so:)
             ((securityops packages browsers) #:prefix so:)
             ((securityops packages tor) #:prefix so:)
             ((securityops packages river) #:prefix river:)
             ((securityops packages audio) #:prefix audio:))

;; Use these bindings in an operating-system or home-environment package list:
(list so:kitty so:fish so:librewolf so:google-chrome-stable
      so:torbrowser river:foot-latest river:fuzzel-latest)
```

For a separate profile, save a manifest such as `river-tools.scm`:

```scheme
(use-modules (guix profiles)
             ((securityops packages river) #:prefix river:)
             ((securityops packages audio) #:prefix audio:))

(packages->manifest
 (list river:river-xmonad-runtime river:channel-river-input
       river:foot-latest river:fuzzel-latest river:wlr-randr-latest
       river:swaybg-latest river:mako-latest river:swaylock-latest
       audio:pipewire-latest audio:wireplumber-latest))
```

```sh
guix package -p "$HOME/.local/share/river-tools" -m river-tools.scm
```

This installs programs; it does not select a login session, start audio services
or configure authentication for the screen locker. River 0.4 requires a separate
window manager. The XMonad-style manager under development is not included in
this channel refresh; see its [validation status](refresh-2026-09-17.md#river-runtime).

A service has its own package field. Adding a package to a profile does not
change an already configured service. For example:

```scheme
(use-modules (gnu services)
             (gnu services networking)
             ((securityops packages tor) #:prefix so:))

(service tor-service-type
         (tor-configuration (tor so:tor)))
```

After pulling the channel, rebuild the configuration that owns the package:
`guix system build /etc/config.scm` or
`guix home build ~/.config/guix/home.scm`. Reconfigure that same configuration
when you are ready to activate its changes. To use a local checkout, add
`-L /path/to/securityops-channel` to the Guix command.

For Lacuna Web PKI, see the [native host and Guix Home guide](webpki.md).

---

## Layout

| Path | Purpose |
| --- | --- |
| `securityops/packages/` | Package modules; see the [index](../PACKAGES.md) for exports and versions |
| `securityops/patches/` | Downstream patches with their upstream license notices |
| `securityops/services/` | Shepherd service definitions |
| `tests/` | Integration checks for River patches and the Web PKI package |
| `xlibre.scm`, `xlibre-sources.scm` | Bundled XLibre compatibility module and source pins |
| `.guix-channel`, `.guix-authorizations` | Channel dependencies and authorized signing keys |
| `etc/` | Inventory, channel configuration and maintenance tools |
| `docs/` | Usage, integration and dated validation reports |
| `LICENSE`, `LICENSES/`, `LICENSING.md` | License text and file-level exceptions |

Package modules import Guix or Nonguix definitions with prefixes. Some inherit
those definitions, while others provide source assemblers, additional inputs or
build phases. A Guix pin is part of the tested build context; inherited recipes
can change when that pin changes.

---

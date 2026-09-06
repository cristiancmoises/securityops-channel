# SecurityOps channel

A personal GNU Guix channel for workstation applications and security tools.

[Português (Brasil)](README.pt-BR.md)

## At a glance

| Item | Status |
|---|---|
| Package definitions | 52 public exports; versions depend on the Guix baseline for re-exports |
| Dependencies | GNU Guix, nonguix and guix-xlibre |
| Latest recipe refresh | 2026-09-06 |
| Validation | [Build results and known limitations](docs/refresh-2026-09-06.md); not every update is fully validated |
| Authentication | Signed commits and a pinned channel introduction |

## Documentation

| Guide | Contents |
|---|---|
| [Package index](PACKAGES.md) | One version table, grouped by module |
| [Refresh report](docs/refresh-2026-09-06.md) | Updated versions, validation and unfinished work |
| [Usage reference](docs/usage.md) | Services, Guix System and Guix Home examples |
| [Changelog](CHANGELOG.md) | Historical release notes |
| [Update workflow](etc/package-update-prompt.md) | Reusable instructions for a verified package refresh |
| [Licensing](LICENSING.md) | Package and project licensing boundaries |

## Install the channel

Add this entry to your `channels.scm` list. Keep the dependencies available;
`.guix-channel` declares nonguix and guix-xlibre.

```scheme
(channel
 (name 'securityops)
 (url "https://git.securityops.com.br/cristiancmoises/securityops-channel")
 (branch "main")
 (introduction
  (make-channel-introduction
   "af46f5cce66179f3e53f87c86ca2538c8fc63f98"
   (openpgp-fingerprint
    "0CFA 43B9 AA96 42EA AF2B  E983 C4C6 61C9 ECFB 46E8"))))
```

Then update your channels and install the packages you need:

```sh
guix pull
guix install fish kitty zupt zupt-gui
```

A package installed in the user profile does not automatically replace one in
Guix Home or the system profile. Reconfigure the profile that owns the package.
Adding a `(commit "...")` field pins the channel to a reproducible revision.

## Repositories

All repositories use the same channel introduction.

| Role | Repository |
|---|---|
| Canonical | [git.securityops.com.br](https://git.securityops.com.br/cristiancmoises/securityops-channel) |
| Mirror | [git.securityops.co](https://git.securityops.co/cristiancmoises/securityops-channel) |
| Mirror | [Codeberg](https://codeberg.org/berkeley/securityops-channel) |
| Mirror | [GitHub](https://github.com/cristiancmoises/securityops-channel) |

## Build and check a local checkout

With nonguix available to your Guix and the guix-xlibre checkout on the load path:

```sh
guix repl -L . -L /path/to/guix-xlibre etc/package-inventory.scm.in
guix build -L . -L /path/to/guix-xlibre fish
./update-channel check
```

The update helper checks its registered packages, not the entire channel.
Fish requires matching Cargo inputs; Emacs requires version-specific patches.
Binary packages and vendored applications need deliberate source/hash updates.
See the [workflow](etc/package-update-prompt.md) before applying updates.

## Authentication

The introduction pins commit `af46f5cce66179f3e53f87c86ca2538c8fc63f98`
and key `0CFA 43B9 AA96 42EA AF2B E983 C4C6 61C9 ECFB 46E8`.
The public key is on the `keyring` branch; authorized signers are recorded in
`.guix-authorizations`.

```sh
guix git authenticate af46f5cce66179f3e53f87c86ca2538c8fc63f98 \
  "0CFA 43B9 AA96 42EA AF2B E983 C4C6 61C9 ECFB 46E8"
```

## License

Channel code is GPL-3.0-or-later; see [LICENSE](LICENSE).
Packaged programs retain their own licenses. See [LICENSING.md](LICENSING.md).

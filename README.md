# SecurityOps channel

A personal GNU Guix channel for workstation applications and security tools.

A big thank you to the GNU Guix project and its maintainers, and to everyone
who writes and maintains the packages this channel reuses — from the Guix and
nonguix collections to every upstream author whose software gets packaged
here. This channel simply wouldn't exist without that work.

[Português (Brasil)](README.pt-BR.md)

## At a glance

| Item | Status |
|---|---|
| Package definitions | Workstation tools, digital signatures, identity libraries, official schema data and XLibre drivers |
| Dependencies | GNU Guix and nonguix; XLibre packaging is included |
| Validation | [Package versions and checks](PACKAGES.md); system activation requires a separate reconfiguration |
| Authentication | Signed commits and a pinned channel introduction |

## Documentation

| Guide | Contents |
|---|---|
| [Package index](PACKAGES.md) | Packages grouped by purpose, verified versions and test limits (pt-BR) |
| [Identity and official schemas](docs/usage.md#identity-and-official-schema-data) | libdigidocpp and separate eSocial event/communication formats |
| [Electronic invoicing](docs/usage.md#electronic-invoicing) | KoSIT Validator and pinned offline XRechnung rules |
| [Lacuna Web PKI](docs/webpki.md) | Native host, browser manifests and Guix Home setup |
| [AutoFirma](docs/usage.md#autofirma) | Official Linux package, signing commands and browser-integration limits |
| [September validation](docs/refresh-2026-09-17.md) | Historical checks and limitations recorded on 2026-09-17 |
| [Usage reference](docs/usage.md) | Services, Guix System and Guix Home examples |
| [Channel mirrors and authentication](docs/channel-authentication-fix.md) | Eight authenticated channels, integrated XLibre and root installation |
| [Changelog](CHANGELOG.md) | Historical release notes |
| [Licensing](LICENSING.md) | Package and project licensing boundaries |

## Install the channel

Add this entry to your `channels.scm` list. Keep the dependencies available;
`.guix-channel` declares nonguix. A separate XLibre channel is not needed.

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

For certificate-enabled websites, this channel also provides the
`lacuna-webpki` native host. The [Web PKI guide](docs/webpki.md) covers the
separate browser extension and native messaging setup.

AutoFirma 1.9 is available through `(securityops packages autofirma)`. It is
optional: adding this channel does not install it or change certificate stores.
See the [AutoFirma usage notes](docs/usage.md#autofirma) before browser setup.

A package installed in the user profile does not automatically replace one in
Guix Home or the system profile. Reconfigure the profile that owns the package.
Adding a `(commit "...")` field pins the channel to a reproducible revision.

River 0.4 and its desktop helpers are available through
`(securityops packages river)`. The [separate-profile example](docs/usage.md#consuming-the-channel-from-etcconfigscm-and-homescm)
also includes the updated audio packages. River 0.4 needs an external window
manager; this channel ships the XMonad Wayland manager through
`(securityops packages xmonad-wayland)`, built from the signed commit of its
public repository, and a physical River desktop running it has been in use
since September 2026. The latest upstream XMonad core and contrib releases
are available through `(securityops packages xmonad)`. The manager also
accepts the classic `xmonad.hs` idiom via `xmonad-wayland --recompile`,
which makes migrating an X11 configuration to River straightforward.

## Repositories

All repositories use the same channel introduction.

| Role | Repository |
|---|---|
| Canonical | [git.securityops.com.br](https://git.securityops.com.br/cristiancmoises/securityops-channel) |
| Mirror | [git.securityops.co](https://git.securityops.co/cristiancmoises/securityops-channel) |
| Mirror | [Codeberg](https://codeberg.org/berkeley/securityops-channel) |
| Mirror | [GitHub](https://github.com/cristiancmoises/securityops-channel) |

## Build and check a local checkout

With nonguix available to your Guix:

```sh
guix repl -L . etc/package-inventory.scm.in
guix build -L . fish
./update-channel check
```

The update helper checks its registered packages, not the entire channel.
Fish requires matching Cargo inputs; Emacs requires version-specific patches.
Binary packages and vendored applications need deliberate source/hash updates.

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

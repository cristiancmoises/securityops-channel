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
| Package definitions | Workstation tools, electronics, remote desktop, monitoring, digital identity and XLibre drivers |
| Dependencies | GNU Guix and nonguix; XLibre packaging is included |
| Validation | [Package versions and checks](PACKAGES.md); system activation requires a separate reconfiguration |
| Authentication | Signed commits and a pinned channel introduction |

## Documentation

| Guide | Contents |
|---|---|
| [Package index](PACKAGES.md) | Packages grouped by purpose, verified versions and test limits (pt-BR) |
| [WhatsAppel](docs/usage.md#whatsappel-emacs-workspace-and-guile-bridge) | Emacs workspace, Guile bridge and separately configured backend |
| [Electronics](docs/usage.md#electronics) | ngspice simulation and Arduino IDE toolchains |
| [Remote desktop](docs/usage.md#remote-desktop) | RustDesk client and self-hosted rendezvous/relay servers |
| [Monitoring](docs/usage.md#monitoring) | Zabbix server, collectors, frontend, JMX and PDF reports |
| [Wazuh](docs/usage.md#wazuh) | Endpoint, manager, indexer, dashboard, alert forwarding and explicit TLS/state setup |
| [XBRL reporting](docs/usage.md#structured-reporting) | Arelle CLI/library, offline validation and graphical-test limits |
| [Identity and official schemas](docs/usage.md#identity-and-official-schema-data) | DigiDoc4, Belgian eID, signature libraries and eSocial formats |
| [AusweisApp](docs/usage.md#ausweisapp-desktop-and-local-sdk) | German eID desktop and local SDK, with matched Qt libraries |
| [OpenPACE](docs/usage.md#openpace-native-eac-library) | Native EAC library, CVC tools and explicitly selected trust |
| [ICP-Brasil data](docs/usage.md#icp-brasil-root-data) | Explicit-purpose roots, original CA collection, Ed521 limits and no automatic trust |
| [XML validation and electronic invoicing](docs/usage.md#xml-validation-with-phive) | PHIVE Java libraries, KoSIT Validator and pinned offline XRechnung rules |
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

## Applications

Application recipes live in modules named for their projects, such as
`(securityops packages zupt)` and `(securityops packages turborec)`. Each recipe
can refresh its own source, version and dependencies. Existing manifests can
keep importing `(securityops packages applications)` or `(securityops packages apps)`:
both re-export the same package bindings. `(securityops packages containers)`
also preserves its Esquema export. Package names and versions are unchanged;
Evelin's Guix package name is `evelin-bin`.

After publishing a channel revision, refresh the owned
[Toys instance](https://toys.securityops.co) and check its indexed commit and
package module/file metadata. Each instance has its own refresh cycle;
[toys.whereis.social](https://toys.whereis.social) is operated externally and
cannot be promised an immediate update. See the
[project inventory](PACKAGES.md#projetos-securityops-e-catálogo-de-pesquisa)
for the module mapping, versions, checks and catalog limits.

### WhatsAppel

WhatsAppel 3.3.1 is available as `whatsappel`, through
`(securityops packages whatsappel)` and the application collection:

```sh
guix install whatsappel
whatsappel --help
```

The package includes the Emacs client, Python workers and `whatsappel-bridge`.
It uses your selected Emacs and existing configuration; installation does not
start a service or pair an account. Configure wuzapi separately. The optional
Rust `pqenv` helper and external mpv playback are not bundled. See the
[usage and validation limits](docs/usage.md#whatsappel-emacs-workspace-and-guile-bridge).

### TurboRec

TurboRec 3.10.4 is available through `(securityops packages turborec)`:

```sh
guix package -e '(@ (securityops packages turborec) turborec)'
turborec gui
```

It includes English and Brazilian Portuguese documentation under
`share/doc/turborec`. Auto can fall back to CPU; explicitly selecting a GPU
requires a compatible driver and an FFmpeg build with that encoder.
Manual Chroma is off by default (compatible automatic 4:2:0); English,
Best/Auto/23 fps/4K remain the main application's defaults.
Completed files are checked for streams, positive duration and initial frames
before confirming Saved; this bounded check is not a whole-file scan. The
legacy launcher also preserves argument boundaries on Bash 3.2.

For NVIDIA/wlroots Wayland, the explicit `turborec-nvidia-new-feature` variant
uses a matched NVENC-capable wf-recorder 0.6.0/FFmpeg 8.1.3 pair. The rest of
its pipeline uses FFmpeg 9.0.2. Installing a different terminal FFmpeg cannot
replace the recorder's libavcodec dependency; FFmpeg 9 is not ABI-compatible
with this wf-recorder build. After updating the channel, choose one command:

```sh
# First installation, when neither app variant is installed in this profile
guix package -e '(@ (securityops packages turborec) turborec-nvidia-new-feature)'
# OR replace an already installed generic turborec in the same transaction
guix package -r turborec -e '(@ (securityops packages turborec) turborec-nvidia-new-feature)'
```

Do not install both app variants in one profile: they provide the same commands.
The generic app remains free of proprietary NVIDIA dependencies. The variant
does not change or activate a kernel driver, globally override library paths,
or reboot. GPU encoding uses CPU-resident capture/conversion frames, not a
zero-copy CUDA pipeline; its full-profile check is not device certification.
Recipe checks: `guix repl -L . tests/wf-recorder-packages.scm` and
`guix repl -L . tests/turborec-backend-packages.scm`.

### FFmpeg and NVIDIA encoding

`(securityops packages video)` provides FFmpeg 9.0.2 and NVENC headers
13.1.15.0. For a first installation, choose the CPU/general-purpose build
without NVIDIA dependencies:

```sh
guix package -e '(@ (securityops packages video) ffmpeg)'
```

For NVIDIA's new-feature driver, choose the explicit NVENC/NVDEC variant.
If `ffmpeg` is already installed in the same user profile, replace it in one
transaction:

```sh
guix package -r ffmpeg -e '(@ (securityops packages video) ffmpeg-nvidia-new-feature)'
```

If neither variant is installed in that profile, omit the removal:

```sh
guix package -e '(@ (securityops packages video) ffmpeg-nvidia-new-feature)'
```

To switch an installed NVIDIA variant back to CPU/general-purpose:

```sh
guix package -r ffmpeg-nvidia-new-feature -e '(@ (securityops packages video) ffmpeg)'
```

Do not keep both variants in one profile: their executable and library files
collide. Removal requires the named package to be installed. Packages in
other profiles are unchanged. Check `ffmpeg -version` and
`ffmpeg -hide_banner -encoders` after choosing the appropriate command.

SDK 13.1 requires driver 610 or newer. The CUDA, NVENC and NVCUVID userspace
libraries embedded in this build must also match the running kernel driver.
This package does not install or activate a kernel module. Listing an encoder
does not prove that hardware encoding works; test an actual encode before
using it for recording. If Guix Home owns your `ffmpeg`, select this variant
in `home.scm` and reconfigure that profile; check `command -v ffmpeg` to
confirm which executable wins. Already-built applications may retain their
own FFmpeg dependency: changing the terminal command does not replace it.

An actual short encoding check, without capturing your screen or microphone:

```sh
ffmpeg -hide_banner -nostdin -f lavfi -i testsrc2=size=1280x720:rate=23 \
  -frames:v 23 -an -c:v h264_nvenc -preset p6 -f null -
```

Validated on x86_64-linux with an RTX 4060 and driver 615.71.09: both native
builds passed 2,895 FATE tests each, including all three Frei0r tests. Short
synthetic H.264, HEVC and AV1 videos passed NVENC encoding, NVDEC decoding,
4K/23 fps, YUV420 and BT.709 metadata checks in MP4/MKV/WebM. CPU H.264/AAC
recording and complete decoding also passed. This does not establish support
for every GPU, other architectures, or an application's separate capture
backend; those need their own tests.

Recipe regression checks: `guix repl -L . tests/ffmpeg-packages.scm`.

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

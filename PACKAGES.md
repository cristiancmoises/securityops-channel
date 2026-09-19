# Curated package index

Snapshot: 2026-09-17. Evaluated against Guix `fe590afef7319a8ea921d35b67fb39fb79f5a3b3` and nonguix `bf39542ca537fde8839b209ac21d6f3254469b15`. XLibre packaging is now included in SecurityOps. Re-exported versions change with the consumer's channels.

This lists recipe versions, not a claim that every package was rebuilt or is the latest upstream release. See [validation and exceptions](docs/refresh-2026-09-17.md).

| Module | Package | Recipe version |
|---|---|---|
| `apps` | `btp` | 0.7 |
| `apps` | `evelin-bin` | 4.4.0 |
| `apps` | `guixvis` | 0.3.0 |
| `apps` | `mirim` | 1.1.1 |
| `apps` | `moneyprinterturbo` | 1.3.7 |
| `apps` | `torando-gui` | 1.4.1 |
| `apps` | `turborec` | 3.9.1 |
| `apps` | `zupt` | 5.2.9 |
| `apps` | `zupt-gui` | 5.2.9 |
| `audio` | `pipewire-latest` | 1.6.9 |
| `audio` | `wireplumber-latest` | 0.5.17 |
| `browsers` | `google-chrome-stable` | 153.0.8010.47 |
| `browsers` | `ungoogled-chromium` | 150.0.7871.46-1 |
| `chromium` | `ungoogled-chromium-bin` | 153.0.8010.47-1 |
| `containers` | `esquema` | 0.3.0 |
| `emacs` | `emacs` | 31.1 |
| `emacs` | `emacs-pgtk` | 31.1 |
| `games` | `steam` | 1.0.0.87 |
| `librewolf` | `librewolf` | 156.0-1 |
| `monitoring` | `glances` | 4.5.6 |
| `river` | `channel-river-input` | 0.4.1-1.94a3d6c |
| `river` | `foot-latest` | 1.28.0 |
| `river` | `fuzzel-latest` | 1.15.0 |
| `river` | `libevdev-latest` | 1.13.7 |
| `river` | `libinput-minimal-latest` | 1.32.0 |
| `river` | `libxkbcommon-latest` | 1.13.2 |
| `river` | `mako-latest` | 1.11.0 |
| `river` | `river-xmonad-runtime` | 0.4.8 |
| `river` | `swaybg-latest` | 1.2.2 |
| `river` | `swaylock-latest` | 1.8.6 |
| `river` | `wayland-latest` | 1.26.0 |
| `river` | `wayland-protocols-latest` | 1.49 |
| `river` | `wlr-randr-latest` | 0.5.0 |
| `river` | `wlroots-latest` | 0.20.2 |
| `river` | `xwayland-latest` | 24.1.13 |
| `security` | `age` | 1.3.2 |
| `security` | `aircrack-ng` | 1.7 |
| `security` | `arp-scan` | 1.10.0 |
| `security` | `binwalk` | 3.1.0 |
| `security` | `fping` | 5.5 |
| `security` | `hydra` | 9.7 |
| `security` | `kismet` | 2025.09.R1 |
| `security` | `lynis` | 3.1.7 |
| `security` | `masscan` | 1.3.2 |
| `security` | `mtr` | 0.96 |
| `security` | `netdiscover` | 0.21 |
| `security` | `nmap` | 7.991 |
| `security` | `proxychains-ng` | 4.17 |
| `security` | `radare2` | 6.2.2 |
| `security` | `reaver` | 1.6.6 |
| `security` | `rizin` | 0.9.1 |
| `security` | `sdb` | 2.5.2 |
| `security` | `whois` | 5.6.6 |
| `shells` | `fish` | 4.9.3 |
| `terminals` | `alacritty` | 0.17.0 |
| `terminals` | `go-github-com-ebitengine-purego` | 0.11.0 |
| `terminals` | `go-github-com-emmansun-base64` | 0.10.0 |
| `terminals` | `go-github-com-sgtdi-fswatcher` | 1.3.0 |
| `terminals` | `kitty` | 0.48.2 |
| `tor` | `tor` | 0.4.9.12 |
| `tor` | `torbrowser` | 15.0.23 |
| `tor` | `torbrowser-assets` | 15.0.23 |
| `utils` | `keepassxc` | 2.7.12 |
| `utils` | `lf` | 42 |
| `utils` | `ueberzugpp` | 2.9.10 |
| `video` | `mpv` | 0.41.0 |
| `video` | `openshot` | 4.0.0 |
| `video` | `vlc` | 3.0.23 |
| `video` | `yt-dlp` | 2026.08.19 |
| `video` | `ytfzf` | 2.6.2 |
| `vpn` | `mullvad-vpn-desktop` | 2026.5 |
| `xmonad` | `ghc-xmonad-contrib` | 0.18.2 |
| `xmonad` | `xmonad` | 0.18.1 |
| `xmonad-wayland` | `xmonad-wayland` | 0.3.0 |
| `xlibre` | `xlibre-server` | 25.2.2 |
| `xsearch` | `guix-xsearch` | 2.3-0.1af46e0 |

Regenerate the inventory with:

```sh
guix repl -L . etc/package-inventory.scm.in
```

Public exports include three Kitty build dependencies. Duplicate browser re-exports are counted once.

Additional driver exports are provided by the bundled `(xlibre)` compatibility
module; see [XLibre integration](docs/xlibre-integration.md).

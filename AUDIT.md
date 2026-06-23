<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
# Package audit — securityops workstation

A deep version audit of **every package declared** in `/etc/config.scm` (system)
and `~/.config/guix/home.scm` (home), against the latest upstream, on host
`predator-helios-intel`. Compiled 2026-06-21; channel-handled section refreshed
2026-06-22; Guix pin `d1e9e23` (Jun 2026).

**Method:** package symbols were extracted from each `(packages …)` form, each
resolved with `guix show` ("your version") and checked with `guix refresh`
("latest upstream"). Bogus updater results (e.g. `go → "60.3"`, version-control
snapshots already ahead of their last tag) are reclassified as *unknown* rather
than *outdated*, so the outdated table lists only real, comparable upgrades.

**Headline counts:** of **391** packages in the main tables, **124** are already
latest, **139** are outdated, **128** are unknown / not-auto-checkable. The
single most behind is **docker 20.10.27 → 29.6.0** (nine majors; runners-up:
containerd 1.6.22 → 2.3.2, openssl 3.5.7 → 4.0.1, nix 2.25.5 → 2.34.7,
**gopls 0.22.0 → 0.46.0**).

> **Scope = report only.** This audits versions; it does NOT touch
> `config.scm`/`home.scm` — your configs are untouched. Bump anything here (or
> fold it into this channel) as you see fit.

## Handled by securityops-channel

These declared apps are provided by this channel at the latest version, so treat
any "outdated" row for them below as **already addressed here**:

- **Bumped ahead of Guix/nonguix:** `kitty` 0.47.4, `tor` 0.4.9.9,
  `torbrowser` 15.0.16, `openshot` 3.5.1, `google-chrome-stable` 149.0.7827.155,
  `mullvad-vpn-desktop` **2026.3**, `librewolf` **152.0.1-2** (both bumped
  2026-06-22; the rest re-verified as still-latest the same day).
- **Already latest (re-exported):** `alacritty`, `fish`, `emacs`, `emacs-pgtk`,
  `mpv`, `vlc`, `keepassxc`, `ueberzugpp`, `lf`, `steam`.
- **Deferred (see README):** `ungoogled-chromium` (147 → 149.0.7827.155-1) —
  in-module source assembly + unverifiable multi-hour compile;
  `google-chrome-stable` 149 covers a current Chromium engine.

## Active `home.scm` reconciliation

The main tables below were generated against the repo copy
`~/guix-config/predator-helios-intel/home.scm`. Your **active**
`~/.config/guix/home.scm` differs slightly; the packages it declares that the
repo copy does **not** are audited here (and `geeqie` is repo-only — not in the
active config):

| Package | Your version | Latest upstream | Status |
|---|---|---|---|
| gopls | 0.22.0 | 0.46.0 | ⬆️ outdated |
| node-typescript | 5.8.3 | 6.0.3 | ⬆️ outdated |
| python-pyflakes | 3.2.0 | 3.4.0 | ⬆️ outdated |
| python-pycodestyle | 2.12.1 | 2.14.0 | ⬆️ outdated |
| python-bandit | 1.8.6 | 1.9.4 | ⬆️ outdated |
| shellcheck | 0.10.0 | 0.11.0 | ⬆️ outdated |
| aspell | 0.60.8.1 | 0.60.8.2 | ⬆️ outdated |
| fd | 10.4.2 | 10.4.2 | ✅ latest |
| ripgrep | 15.1.0 | 15.1.0 | ✅ latest |
| aspell-dict-en | 2020.12.07-0 | — | ❔ no updater |
| ungoogled-chromium | 147.0.7727.137-1 | 149.0.7827.155-1 | ➡️ handled by channel |

---

## Summary

A total of **391** explicitly-declared packages were audited across the two config files (deduplicated; the six handled elsewhere — alacritty, kitty, tor, torbrowser, fish, emacs — were excluded; `emacs-*` packages and `tdlib` etc. are kept). Of these, **124** are already at the latest upstream version, **139** are outdated with a real upgrade available, and **128** are unknown / not auto-checkable (no Guix updater, VCS-snapshot packages already ahead of the last tagged release, nonguix/locally-defined packages, or updaters that returned an implausible version). "Your version" is the first `version:` from `guix show`; "Latest upstream" is parsed from `guix refresh`.

## Outdated (upgrade available)

139 packages have a newer upstream release than the pinned channel provides.

| Package | Declared in | Your version | Latest upstream |
|---------|-------------|--------------|-----------------|
| alsa-lib | Home+System | 1.2.11 | 1.2.16.1 |
| alsa-utils | Home+System | 1.2.11 | 1.2.16 |
| ansible | System | 14.0.0 | 14.1.0 |
| apparmor | System | 4.1.2 | 5.0.1 |
| at-spi2-core | Home | 2.52.0 | 2.60.4 |
| audit | System | 3.0.9 | 4.0.2 |
| bash | Home | 5.2.37 | 5.3 |
| bcachefs-tools | Home+System | 1.37.4 | 1.38.6 |
| binutils | System | 2.44 | 2.46.1 |
| bluez | Home | 5.79 | 5.86 |
| borg | Home | 1.4.4 | 2.0.0b21 |
| bundler | Home | 2.6.9 | 4.0.14 |
| cabal-doctest | Home | 1.0.11 | 1.0.12 |
| cabal-install | Home+System | 3.12.1.0 | 3.16.1.0 |
| calc | Home | 2.16.1.2 | 3.0.1.0 |
| certbot | Home | 4.2.0 | 5.6.0 |
| chafa | Home | 1.18.0 | 1.18.2 |
| cl-clx | Home | 0.7.7 | 0.7.8 |
| clamav | System | 1.4.3 | 1.5.2 |
| containerd | System | 1.6.22 | 2.3.2 |
| coreutils | Home+System | 9.1 | 9.11 |
| docker | System | 20.10.27 | 29.6.0 |
| emacs-org | Home+System | 9.8.3 | 9.8.6 |
| enca | Home | 1.19 | 1.22 |
| exfatprogs | Home+System | 1.2.9 | 1.4.2 |
| fastfetch | Home+System | 2.63.1 | 2.64.2 |
| fcitx5 | Home | 5.1.19 | 5.1.20 |
| fcitx5-qt | Home | 5.1.13 | 5.1.14 |
| feh | Home | 3.11.3 | 3.12.2 |
| ffmpeg | Home | 8.0 | 8.1.2 |
| ffmpegthumbnailer | Home | 2.2.2 | 2.3.0 |
| firejail | Home+System | 0.9.78 | 0.9.80 |
| flameshot | Home | 13.3.0 | 14.0.0 |
| flatpak-xdg-utils | Home | 1.0.5 | 1.0.6 |
| font-awesome | Home | 4.7.0 | 7.2.0 |
| font-gnu-unifont | Home | 16.0.02 | 17.0.04 |
| font-google-noto | Home | 2026.01.01 | 2026.06.01 |
| font-openmoji | Home | 15.1.0 | 17.0.0 |
| font-tamzen | Home | 1.11.5 | 1.11.6 |
| font-util | Home | 1.4.1 | 1.4.2 |
| fping | System | 5.3 | 5.5 |
| gawk | Home | 5.3.0 | 5.4.0 |
| gedit | Home | 44.3 | 48.1 |
| ghc | Home+System | 9.10.2 | 9.14.1 |
| ghc-xmonad-contrib | System | 0.18.1 | 0.18.2 |
| gimp | Home | 3.2.0 | 3.2.4 |
| glances | System | 4.3.0 | 4.5.5 |
| glib | Home | 2.86.0 | 2.89.0 |
| glibc | Home | 2.41 | 2.43 |
| gnome-tweaks | Home | 46.1 | 49.0 |
| gnupg | Home+System | 2.4.8 | 2.5.20 |
| gpac | Home | 2.4.0-1.9c1da9e | 26.02.0 |
| grep | Home+System | 3.11 | 3.12 |
| gtk | Home | 4.22.1 | 4.23.1 |
| guvcview | Home | 2.2.1 | 2.2.2 |
| higan | Home | 110-0.ad0e11e | 115 |
| jpegoptim | Home | 1.5.5 | 1.5.6 |
| kleopatra | Home | 25.12.3 | 26.04.2 |
| knot | Home | 3.5.3 | 3.5.5 |
| krita | Home | 5.2.16 | 6.0.2.1 |
| ldns | Home | 1.8.4 | 1.9.2 |
| libbluray | Home | 1.3.4 | 1.4.1 |
| libdrm | Home | 2.4.131 | 2.4.134 |
| libdvdcss | Home | 1.4.3 | 1.5.0 |
| libdvdnav | Home | 6.1.1 | 7.0.0 |
| libdvdread | Home | 6.1.3 | 7.0.1 |
| libfido2 | System | 1.16.0 | 1.17.0 |
| libreoffice | Home | 25.2.5.2 | 26.2.4 |
| librsvg | Home | 2.58.5 | 2.62.3 |
| libx11 | Home | 1.8.12 | 1.8.13 |
| libxcomposite | Home | 0.4.6 | 0.4.7 |
| libxdamage | Home | 1.1.6 | 1.1.7 |
| libxext | Home | 1.3.6 | 1.3.7 |
| libxfixes | Home | 6.0.1 | 6.0.2 |
| libxkbcommon | Home | 1.13.1 | 1.13.2 |
| libxml2 | Home | 2.14.6 | 2.15.3 |
| libxrandr | Home | 1.5.4 | 1.5.5 |
| llvm-for-mesa | Home | 18.1.8 | 22.1.8 |
| luanti | Home | 5.16.0 | 5.16.1 |
| luanti-server | Home | 5.16.0 | 5.16.1 |
| lynis | System | 3.1.1 | 3.1.6 |
| mangohud | System | 0.7.0 | 0.8.4 |
| mesa | Home+System | 26.0.2 | 26.1.3 |
| neovim | Home | 0.12.1 | 0.12.3 |
| netcat-openbsd | Home | 1.219-1 | 1.238 |
| nftables | Home+System | 1.0.8 | 1.1.6 |
| nix | System | 2.25.5 | 2.34.7 |
| nmap | Home+System | 7.98 | 7.99 |
| node | Home+System | 22.14.0 | 26.3.1 |
| ntfs-3g | Home+System | 2022.10.3 | 2026.2.25 |
| openjdk | Home | 25.0.2 | 25.0.3 |
| openresolv | System | 3.13.2 | 3.17.4 |
| openssl | Home+System | 3.5.7 | 4.0.1 |
| pandoc | Home | 3.7.0.2 | 3.10 |
| pcsx2 | Home | 2.4.0 | 2.7.423 |
| pipewire | System | 1.6.2 | 1.6.7 |
| polybar | Home | 3.7.1 | 3.7.2 |
| poppler | Home | 22.09.0 | 26.06.0 |
| procps | Home+System | 4.0.3 | 4.0.6 |
| pulseaudio | System | 16.1 | 17.0 |
| python | Home+System | 3.12.12 | 3.15.0 |
| python-biopython | Home | 1.86 | 1.87 |
| python-emoji | Home | 2.12.1 | 2.15.0 |
| python-pip | Home+System | 25.1.1 | 26.1.2 |
| python-virtualenv | Home | 20.35.4 | 21.5.1 |
| qbittorrent | Home | 5.1.4 | 5.2.2 |
| qemu | Home+System | 10.2.1 | 11.0.1 |
| qtbase | Home | 6.9.2 | 6.11.1 |
| qtdeclarative | Home | 6.9.2 | 6.11.1 |
| qtshadertools | Home | 6.9.2 | 6.11.1 |
| qtsvg | Home | 6.9.2 | 6.11.1 |
| qttools | Home | 6.9.2 | 6.11.1 |
| qtwayland | Home | 6.9.2 | 6.11.1 |
| qtwebengine | Home | 6.9.3 | 6.11.1 |
| qtwebview | Home | 6.9.2 | 6.11.1 |
| r-edger | Home | 4.10.0 | 4.10.1 |
| ruby-json | Home | 2.18.1 | 2.19.9 |
| runc | System | 1.3.0 | 1.5.0 |
| sed | Home+System | 4.9 | 4.10 |
| setxkbmap | System | 1.3.4 | 1.3.5 |
| strace | Home+System | 7.0 | 7.1 |
| swaylock | System | 1.8.3 | 1.8.5 |
| tcpdump | Home+System | 4.99.4 | 4.99.6 |
| telegram-desktop | Home | 6.3.6 | 6.9.3 |
| usbutils | Home | 018 | 019 |
| v4l-utils | Home | 1.24.1 | 1.32.0 |
| virt-manager | System | 5.0.0 | 5.1.0 |
| winetricks | Home | 20250102 | 20260125 |
| wireplumber | System | 0.5.14 | 0.5.15 |
| wireshark | Home+System | 4.6.5 | 4.7.1 |
| xdg-desktop-portal | Home | 1.20.3 | 1.22.1 |
| xdpyinfo | Home | 1.3.4 | 1.4.0 |
| xfsprogs | System | 6.12.0 | 7.0.1 |
| xkeyboard-config | Home | 2.44 | 2.48 |
| xkill | System | 1.0.6 | 1.0.7 |
| xmonad | Home+System | 0.18.0 | 0.18.1 |
| xpra | Home | 6.4.4 | 6.5 |
| xrandr | Home+System | 1.5.3 | 1.5.4 |
| xterm | Home | 397 | 410 |

## Up to date

124 packages are already at the latest upstream version.

| Package | Declared in | Version |
|---------|-------------|---------|
| acct | System | 6.6.4 |
| anubis | Home | 4.3 |
| arandr | Home+System | 0.1.11 |
| arp-scan | Home | 1.10.0 |
| atool | Home | 0.39.0 |
| autorandr | Home+System | 1.15 |
| awww | Home | 0.12.1 |
| bat | Home+System | 0.26.1 |
| bluez-alsa | Home | 4.3.1 |
| brightnessctl | Home+System | 0.5.1 |
| btop | System | 1.4.7 |
| btrfs-progs | Home | 7.0 |
| cmatrix | Home | 2.0 |
| cmus | Home | 2.12.0 |
| cool-retro-term | Home | 1.2.0 |
| desktop-file-utils | Home | 0.28 |
| dnstracer | Home | 1.10 |
| dosfstools | Home+System | 4.2 |
| e2fsprogs | System | 1.47.2 |
| emacs-company-emoji | Home | 3.0.0 |
| emacs-emojify | Home | 1.2 |
| emacs-magit | Home | 4.5.0 |
| emacs-org-static-blog | Home | 1.7.0 |
| findutils | Home+System | 4.10.0 |
| fnott | Home | 1.8.0 |
| font-aporetic | System | 1.2.0 |
| font-cronyx-cyrillic | Home | 1.0.4 |
| font-dec-misc | Home | 1.0.4 |
| font-fantasque-sans | Home | 1.8.0 |
| font-gnu-freefont | Home | 20120503 |
| font-google-material-design-icons | Home | 4.0.0 |
| font-google-noto-emoji | Home | 2.051 |
| font-isas-misc | Home | 1.0.4 |
| font-meera-inimai | Home | 2.0 |
| font-micro-misc | Home | 1.0.4 |
| font-misc-cyrillic | Home | 1.0.4 |
| font-misc-ethiopic | Home | 1.0.5 |
| font-misc-misc | Home | 1.1.3 |
| font-mononoki | Home | 1.6 |
| font-mutt-misc | Home | 1.0.4 |
| font-public-sans | Home | 2.001 |
| font-rachana | Home | 7.0.3 |
| font-schumacher-misc | Home | 1.1.3 |
| font-screen-cyrillic | Home | 1.0.5 |
| font-sony-misc | Home | 1.0.4 |
| font-sun-misc | Home | 1.0.4 |
| font-vazirmatn | Home | 33.003 |
| font-winitzki-cyrillic | Home | 1.0.4 |
| font-xfree86-type1 | Home | 1.0.5 |
| foot | System | 1.27.0 |
| fzf | Home | 0.73.1 |
| gamemode | System | 1.8.2 |
| geeqie | Home | 2.7 |
| git | Home+System | 2.54.0 |
| git-lfs | Home+System | 3.7.1 |
| gnome-disk-utility | Home | 46.1 |
| guile-ares-rs | Home | 0.9.7 |
| haunt | Home+System | 0.3.0 |
| htop | System | 3.5.1 |
| igt-gpu-tools | System | 2.4 |
| iperf | Home | 3.21 |
| jekyll | Home | 4.4.1 |
| keepassxc | Home+System | 2.7.12 |
| lf | Home+System | 41 |
| libvdpau | Home | 1.5 |
| libxcb | Home | 1.17.0 |
| libxshmfence | Home | 1.3.3 |
| linux-firmware | System | 20260519 |
| lm-sensors | Home+System | 3.6.2 |
| lxappearance | Home | 0.6.4 |
| macchanger | System | 1.7.0 |
| mpd | Home | 0.24.12 |
| mpv | Home | 0.41.0 |
| nano | Home | 9.0 |
| ncdu | System | 2.9.2 |
| netdiscover | System | 0.21 |
| ninja | Home | 1.13.2 |
| noisetorch | Home | 0.12.2 |
| obs-pipewire-audio-capture | Home | 1.2.1 |
| odt2txt | Home | 0.5 |
| opendoas | Home | 6.8.2 |
| openrgb | System | 0.9 |
| parted | Home+System | 3.7 |
| pavucontrol | Home | 6.2 |
| pavucontrol-qt | Home | 2.4.0 |
| perl-image-exiftool | Home | 13.55 |
| phoronix-test-suite | Home | 10.8.4 |
| picom | Home | 13 |
| pinentry | Home | 1.3.2 |
| pinentry-gtk2 | Home | 1.3.2 |
| podman | System | 5.8.3 |
| proot | Home | 5.4.0 |
| pulsemixer | Home | 1.5.1 |
| pwgen | Home | 2.08 |
| r-biocmanager | Home | 1.30.27 |
| r-deseq2 | Home | 1.52.0 |
| r-emojifont | Home | 0.6.0 |
| rofi | Home | 2.0.0 |
| st | Home | 0.9.3 |
| starship | Home | 1.25.1 |
| sway | System | 1.12 |
| swayidle | System | 1.9.0 |
| uchardet | Home | 0.0.8 |
| udevil | Home | 0.4.4 |
| ueberzugpp | Home+System | 2.9.10 |
| vkbasalt | System | 0.3.2.10 |
| vlc | Home | 3.0.23 |
| waybar | Home+System | 0.15.0 |
| whois | System | 5.6.6 |
| wipe | Home | 2.3.1 |
| wireguard-tools | Home | 1.0.20260223 |
| wl-clipboard | Home+System | 2.3.0 |
| wlrctl | Home | 0.2.2 |
| wlsunset | Home | 0.4.0 |
| xdg-desktop-portal-gtk | Home | 1.15.3 |
| xdg-utils | System | 1.2.1 |
| xlsx2csv | Home | 0.8.3 |
| xmobar | Home | 0.50 |
| xmodmap | System | 1.0.11 |
| xorg-server-xwayland | System | 24.1.12 |
| xprop | Home | 1.2.8 |
| xset | Home | 1.2.5 |
| xwininfo | Home | 1.1.6 |
| zoxide | Home+System | 0.9.9 |

## Unknown / no updater

128 packages could not be auto-checked for a newer version. Most are fine: they are either VCS-snapshot packages already newer than the last tagged upstream release, packages Guix has no updater for, nonguix or locally-defined packages, or cases where the updater returned a non-comparable/implausible version. Your installed version is shown for reference.

| Package | Declared in | Your version | Reason |
|---------|-------------|--------------|--------|
| appimage-type2-runtime | Home | continuous-1.caf24f9 | declared 20251108-snapshot newer than upstream-known 20251108 |
| bash-minimal | Home | 5.2.37 | updater failed |
| blueman | Home | 2.4.6 | updater failed |
| cl-css | Home | 0.1-1.8fe654c | updater failed |
| cmake | Home+System | 4.1.3 | updater failed |
| compton | Home | 0.1beta2 | updater failed |
| edk2-tools | Home+System | 202402 | declared 2.stable202605-snapshot newer than upstream-known 2.stable202605 |
| emacs-nerd-icons | Home | 0.1.0-2.d41902f | declared 0.1.0-snapshot newer than upstream-known 0.1.0 |
| emacs-telega | Home+System | 0.8.640 | declared 0.8.0-snapshot newer than upstream-known 0.8.0 |
| emacs-vterm | Home | 0.0.2-3.a01a289 | updater failed |
| exfat-utils | Home+System | 1.4.0 | updater failed |
| flatpak | Home | 1.16.6 | updater failed |
| font-adobe-source-code-pro | Home | 2.042R-u-1.062R-i-1.026R-vf | declared 1.017R-snapshot newer than upstream-known 1.017R |
| font-adobe-source-han-sans | Home | 2.005 | updater target '2.005R' is the same release with an 'R' suffix |
| font-adobe-source-sans | Home | 3.052 | updater target '3.052R' is the same release with an 'R' suffix |
| font-adobe-source-serif | Home | 4.005 | updater target '4.005R' is the same release with an 'R' suffix |
| font-adobe100dpi | Home | 1.0.4 | updater failed |
| font-adobe75dpi | Home | 1.0.4 | updater failed |
| font-adwaita | System | 49.0 | updater failed |
| font-anonymous-pro | Home | 1.002 | updater failed |
| font-anonymous-pro-minus | Home | 1.003 | updater failed |
| font-cns11643-swjz | Home | 1 | updater failed |
| font-comic-neue | Home | 2.51 | no updater |
| font-culmus | Home | 0.140 | updater failed |
| font-dejavu | Home | 2.37 | updater failed |
| font-dosis | Home | 1.7 | updater failed |
| font-dseg | Home | 0.46 | no updater |
| font-fira-code | Home | 6.2 | no updater |
| font-fira-mono | Home | 3.206 | updater failed |
| font-fira-sans | Home | 4.203 | updater failed |
| font-fontna-yasashisa-antique | Home | 0 | updater failed |
| font-google-roboto | Home | 3.011 | no updater |
| font-hack | Home | 3.003 | no updater |
| font-hermit | Home | 2.0 | no updater |
| font-ibm-plex | Home | 6.4.2-0.89cba80 | declared 6.4.2-snapshot newer than upstream-known 6.4.2 |
| font-inconsolata | Home | 3.000 | no updater |
| font-iosevka | Home | 33.3.0 | no updater |
| font-iosevka-aile | Home+System | 33.3.0 | no updater |
| font-iosevka-curly | System | 33.3.0 | no updater |
| font-iosevka-curly-slab | System | 33.3.0 | no updater |
| font-iosevka-etoile | Home+System | 33.3.0 | no updater |
| font-iosevka-slab | Home+System | 33.3.0 | no updater |
| font-iosevka-ss01 | System | 33.3.0 | no updater |
| font-iosevka-ss02 | System | 33.3.0 | no updater |
| font-iosevka-ss03 | System | 33.3.0 | no updater |
| font-iosevka-ss04 | System | 33.3.0 | no updater |
| font-iosevka-ss05 | System | 33.3.0 | no updater |
| font-iosevka-ss06 | System | 33.3.0 | no updater |
| font-iosevka-ss07 | System | 33.3.0 | no updater |
| font-iosevka-ss08 | System | 33.3.0 | no updater |
| font-iosevka-term | Home+System | 33.3.0 | no updater |
| font-iosevka-term-slab | Home+System | 33.3.0 | no updater |
| font-ipa-mj-mincho | Home | 006.01 | no updater |
| font-jetbrains-mono | Home | 2.304 | no updater |
| font-lato | Home | 2.015 | updater failed |
| font-liberation | Home | 2.1.5 | no updater |
| font-linuxlibertine | Home | 5.3.0 | no updater |
| font-lohit | Home | 20140220 | updater failed |
| font-mplus-testflight | Home | 063a | updater failed |
| font-sarasa-gothic | Home+System | 1.0.31 | updater failed |
| font-sil-andika | Home | 7.000 | updater failed |
| font-sil-charis | Home | 7.000 | updater failed |
| font-sil-gentium | Home | 7.000 | updater failed |
| font-terminus | Home | 4.49.1 | updater failed |
| font-tex-gyre | Home | 2.005 | no updater |
| font-un | Home | 1.0.2-080608 | updater failed |
| font-wqy-microhei | Home | 0.2.0-beta | updater failed |
| font-wqy-zenhei | Home | 0.9.45 | updater failed |
| forgejo | Home | 14.0.4 | updater failed |
| fuse | Home | 3.18.1 | no updater |
| fuse-exfat | Home+System | 1.4.0 | updater failed |
| gcc | Home+System | 14.3.0 | non-installable bare gcc symbol (use gcc-toolchain); refresh n/a |
| gcc-toolchain | Home+System | 16.1.0 | no updater |
| go | Home+System | 1.26.4 | updater reported '60.3' (not a real Go release; comparator confused by tag scheme) |
| google-chrome-stable | Home | 148.0.7778.215 | updater failed |
| gparted | Home | 1.6.0 | updater failed |
| hashcat | Home+System | 7.1.2 | updater failed |
| icecat | System | 140.12.0-gnu1 | updater failed |
| imagemagick | Home | 6.9.13-5 | updater failed |
| intel-media-driver | System | 26.2.0 | updater reported '2018Q2.1' (older than declared 26.2.0; wrong tag matched) |
| inxi | System | 3.3.40-1 | updater failed |
| jq | Home+System | 1.8.1 | updater failed |
| libass | Home | 0.15.1 | updater failed |
| librewolf | Home+System | 151.0.4-1 | no updater |
| libva | Home+System | 2.22.0 | updater failed |
| libva-utils | System | 2.18.1 | updater failed |
| linux-libre-headers | System | 7.0.12 | updater failed |
| mergerfs | Home+System | 2.33.5 | updater failed |
| mesa-headers | System | 26.0.2 | updater failed |
| mesa-opencl | Home | 26.0.2 | updater failed |
| mesa-utils | Home | 8.4.0 | no updater |
| meson | Home+System | 1.9.0 | updater failed |
| mplayer | Home | 1.5 | updater failed |
| net-tools | System | 1.60-0.479bb4a | updater failed |
| nspr | Home | 4.36 | updater failed |
| nss | Home | 3.101.4 | updater failed |
| nvda | System | 580.15 | nonguix nvidia driver; no Guix updater |
| obs | Home | 32.0.4 | no updater |
| openssh | Home+System | 10.3p1 | declared 10.3-snapshot newer than upstream-known 10.3 |
| openvpn | Home+System | 2.6.12 | updater failed |
| p7zip | Home | 26.01 | resolves to p7zip package (7zip 26.01); refresh not run |
| pcsx2-patches | Home | 2025.12.11-0.10239de | updater failed |
| pfetch | Home+System | 0.7.0-1.a906ff8 | declared 0.6.0-snapshot newer than upstream-known 0.6.0 |
| pkg-config | Home | 0.29.2 | updater failed |
| qimgv | Home | 1.0.3-alpha | declared 1.0.2-snapshot newer than upstream-known 1.0.2 |
| qpdfview | Home | 0.5.0 | updater failed |
| qtgraphicaleffects | Home | 5.15.17 | updater failed |
| r | Home | 4.6.0 | no updater |
| ranger | Home | 1.9.4 | updater failed |
| ruby | Home | 4.0.5 | updater failed |
| rust | Home+System | 1.93.0 | updater failed |
| smartmontools | Home+System | 7.5 | updater reported '86.64.LINUX.OK' (CVS tag, not a real version) |
| sqlite | Home+System | 3.53.1 | updater failed |
| steam-nvidia | Home+System | 1.0.0.85 | local transform of nonguix steam; no updater |
| sysstat | System | 12.7.5 | no updater |
| tdlib | Home+System | 1.8.64 | declared 1.8.0-snapshot newer than upstream-known 1.8.0 |
| tor-client | Home | 0.4.9.8 | updater failed |
| torsocks | Home+System | 2.4.0 | updater failed |
| unicode-emoji | Home | 15.1 | no updater |
| vulkan-headers | Home | 1.4.335.0 | updater returned non-version target 'ulkan-sdk-1.4.350.1' |
| vulkan-loader | Home+System | 1.4.335.0 | updater returned non-version target 'ulkan-sdk-1.4.350.1' |
| vulkan-tools | System | 1.4.335.0 | updater returned non-version target 'ulkan-sdk-1.4.350.1' |
| w3m | Home | 0.5.3+git20230121 | declared 0.5.3-snapshot newer than upstream-known 0.5.3 |
| wezterm | Home | 20260117.154428.05343b38 | declared 20240203-110809-5046fc22-snapshot newer than upstream-known 20240203-110809-5046fc22 |
| wine | Home | 11.0 | updater failed |
| wmctrl | Home | 1.07 | updater failed |
| yarn | System | 1.22.22 | no updater |
| zip | Home | 3.0 | updater failed |


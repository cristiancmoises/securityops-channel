# Canal SecurityOps

Um canal pessoal do GNU Guix para aplicativos de trabalho e ferramentas de segurança.

Um agradecimento ao projeto GNU Guix e aos seus mantenedores, e a todas as
pessoas que escrevem e mantêm os pacotes que este canal reutiliza — das
coleções do Guix e do nonguix a cada autor cujo software é empacotado aqui.
Este canal simplesmente não existiria sem esse trabalho.

[English](README.md)

## Visão geral

| Item | Status |
|---|---|
| Definições de pacotes | Ferramentas de trabalho, eletrônica, acesso remoto, monitoramento, identidade digital e drivers XLibre |
| Dependências | GNU Guix e nonguix; o empacotamento XLibre está incluído |
| Validação | Testes dos pacotes e [limites de uso](docs/usage.md); a ativação do sistema requer reconfiguração separada |
| Autenticação | Commits assinados e introdução do canal fixada |

## Destaques de segurança e produtividade

O canal inclui Burp Suite 2026.10.1 para interceptação HTTP e testes de
aplicações, além de Maltego 4.14.0 para análise de vínculos e investigações.
Essas ferramentas de segurança acompanham a suíte completa de produtividade
ArtCraft: CADCraft, DeckCraft, DesignCraft, EffectCraft, FigCraft, FilmCraft,
GridCraft, LightCraft, PdfCraft, PhotoCraft, SoundCraft, VectorCraft e
WordCraft. As versões exatas aparecem no catálogo abaixo.

## Catálogo completo de pacotes

Esta tabela abrange todas as definições de pacote exportadas pelo canal. Os
três drivers marcados `Outro alvo` são mantidos para ARM, i686 ou PowerPC; a
build farm `x86_64-linux` avalia atualmente os outros 196 alvos.

<!-- package-catalog:start -->

| Módulo | Export Guix | Pacote | Versão | Build farm |
|---|---|---|---|---|
| `security` | `age` | `age` | 1.3.2 | x86_64-linux |
| `security` | `aircrack-ng` | `aircrack-ng` | 1.7 | x86_64-linux |
| `terminals` | `alacritty` | `alacritty` | 0.17.0 | x86_64-linux |
| `arduino` | `arduino-ide` | `arduino-ide` | 2.3.10 | x86_64-linux |
| `reporting` | `arelle` | `arelle` | 2.47.4 | x86_64-linux |
| `security` | `arp-scan` | `arp-scan` | 1.10.0 | x86_64-linux |
| `ausweisapp` | `ausweisapp` | `ausweisapp` | 2.6.1 | x86_64-linux |
| `autofirma` | `autofirma` | `autofirma` | 1.9 | x86_64-linux |
| `security` | `binwalk` | `binwalk` | 3.1.0 | x86_64-linux |
| `applications` | `btp` | `btp` | 0.7 | x86_64-linux |
| `burpsuite` | `burpsuite` | `burpsuite` | 2026.10.1 | x86_64-linux |
| `cadcraft` | `cadcraft` | `cadcraft` | 0.7.0 | x86_64-linux |
| `river` | `channel-river-input` | `channel-river-input` | 0.5.1 | x86_64-linux |
| `deckcraft` | `deckcraft` | `deckcraft` | 0.7.0 | x86_64-linux |
| `designcraft` | `designcraft` | `designcraft` | 0.8.0 | x86_64-linux |
| `digidoc4` | `digidoc4` | `digidoc4` | 4.11.1 | x86_64-linux |
| `containers` | `docker-cli-latest` | `docker-cli` | 29.9.3 | x86_64-linux |
| `containers` | `docker-latest` | `docker` | 29.9.3 | x86_64-linux |
| `effectcraft` | `effectcraft` | `effectcraft` | 0.10.0 | x86_64-linux |
| `belgian-eid` | `eid-mw` | `eid-mw` | 5.1.31 | x86_64-linux |
| `emacs` | `emacs-pgtk` | `emacs-pgtk` | 31.1 | x86_64-linux |
| `emacs` | `emacs` | `emacs` | 31.1 | x86_64-linux |
| `brazil-tax` | `esocial-communication-schemas` | `esocial-communication-schemas` | 1.6 | x86_64-linux |
| `brazil-tax` | `esocial-schemas` | `esocial-schemas` | 1.3-20260701 | x86_64-linux |
| `containers` | `esquema` | `esquema` | 0.3.0 | x86_64-linux |
| `applications` | `evelin-bin` | `evelin-bin` | 4.4.0 | x86_64-linux |
| `video` | `ffmpeg-8-nvidia-new-feature` | `ffmpeg-8-nvidia-new-feature` | 8.1.3 | x86_64-linux |
| `video` | `ffmpeg-nvidia-new-feature` | `ffmpeg-nvidia-new-feature` | 9.0.2 | x86_64-linux |
| `video` | `ffmpeg-vvdec` | `ffmpeg-vvdec` | 9.0.2 | x86_64-linux |
| `video` | `ffmpeg` | `ffmpeg` | 9.0.2 | x86_64-linux |
| `figcraft` | `figcraft` | `figcraft` | 0.6.0 | x86_64-linux |
| `wazuh-search` | `wazuh-filebeat` | `filebeat` | 7.10.2-2 | x86_64-linux |
| `filmcraft` | `filmcraft` | `filmcraft` | 0.7.2 | x86_64-linux |
| `shells` | `fish` | `fish` | 4.9.3 | x86_64-linux |
| `river` | `foot-latest` | `foot` | 1.28.0 | x86_64-linux |
| `security` | `fping` | `fping` | 5.5 | x86_64-linux |
| `river` | `fuzzel-latest` | `fuzzel` | 1.15.0 | x86_64-linux |
| `xmonad` | `ghc-xmonad-contrib` | `ghc-xmonad-contrib` | 0.18.2 | x86_64-linux |
| `monitoring` | `glances` | `glances` | 4.5.9 | x86_64-linux |
| `terminals` | `go-github-com-ebitengine-purego` | `go-github-com-ebitengine-purego` | 0.11.3 | x86_64-linux |
| `terminals` | `go-github-com-emmansun-base64` | `go-github-com-emmansun-base64` | 0.11.0 | x86_64-linux |
| `terminals` | `go-github-com-kovidgoyal-go-shm-v2` | `go-github-com-kovidgoyal-go-shm-v2` | 2.0.1 | x86_64-linux |
| `terminals` | `go-github-com-sgtdi-fswatcher` | `go-github-com-sgtdi-fswatcher` | 1.3.0 | x86_64-linux |
| `browsers` | `google-chrome-stable` | `google-chrome-stable` | 157.0.8103.78-1 | x86_64-linux |
| `gridcraft` | `gridcraft` | `gridcraft` | 0.7.0 | x86_64-linux |
| `xsearch` | `guix-xsearch` | `guix-xsearch` | 2.3-0.1af46e0 | x86_64-linux |
| `applications` | `guixvis` | `guixvis` | 0.10.0 | x86_64-linux |
| `security` | `hydra` | `hydra` | 9.7 | x86_64-linux |
| `icp-brasil-chain` | `icp-brasil-ca-data` | `icp-brasil-ca-data` | 2026.08.26 | x86_64-linux |
| `icp-brasil` | `icp-brasil-roots` | `icp-brasil-roots` | 2026.10.05 | x86_64-linux |
| `utils` | `keepassxc` | `keepassxc` | 2.8.0 | x86_64-linux |
| `security` | `kismet` | `kismet` | 2026.10.R1 | x86_64-linux |
| `terminals` | `kitty` | `kitty` | 0.50.0 | x86_64-linux |
| `einvoicing` | `kosit-validator` | `kosit-validator` | 1.6.3 | x86_64-linux |
| `webpki` | `lacuna-webpki` | `lacuna-webpki` | 2.16.0 | x86_64-linux |
| `utils` | `lf` | `lf` | 42 | x86_64-linux |
| `eid` | `libdigidocpp-acceptance` | `libdigidocpp-acceptance` | 4.5.1 | x86_64-linux |
| `eid` | `libdigidocpp` | `libdigidocpp` | 4.5.1 | x86_64-linux |
| `river` | `libevdev-latest` | `libevdev` | 1.14.0 | x86_64-linux |
| `river` | `libinput-minimal-latest` | `libinput-minimal` | 1.32.0 | x86_64-linux |
| `electronics` | `libngspice` | `libngspice` | 47 | x86_64-linux |
| `browsers` | `librewolf` | `librewolf` | 160.0-1 | x86_64-linux |
| `river` | `libxkbcommon-latest` | `libxkbcommon` | 1.13.2 | x86_64-linux |
| `lightcraft` | `lightcraft` | `lightcraft` | 0.8.0 | x86_64-linux |
| `linux-libre-7-2-11` | `linux-libre-7.2.11` | `linux-libre` | 7.2.11 | x86_64-linux |
| `security` | `lynis` | `lynis` | 3.1.7 | x86_64-linux |
| `river` | `mako-latest` | `mako` | 1.11.0 | x86_64-linux |
| `maltego` | `maltego` | `maltego` | 4.14.0 | x86_64-linux |
| `security` | `masscan` | `masscan` | 1.3.2 | x86_64-linux |
| `applications` | `mirim` | `mirim` | 1.1.1 | x86_64-linux |
| `applications` | `moneyprinterturbo` | `moneyprinterturbo` | 1.3.10 | x86_64-linux |
| `video` | `mpv` | `mpv` | 0.42.0 | x86_64-linux |
| `security` | `mtr` | `mtr` | 0.96 | x86_64-linux |
| `vpn` | `mullvad-vpn-desktop` | `mullvad-vpn-desktop` | 2026.5 | x86_64-linux |
| `security` | `netdiscover` | `netdiscover` | 0.21 | x86_64-linux |
| `electronics` | `ngspice` | `ngspice` | 47 | x86_64-linux |
| `security` | `nmap` | `nmap` | 7.993 | x86_64-linux |
| `video` | `nv-codec-headers` | `nv-codec-headers` | 13.1.15.0 | x86_64-linux |
| `nvidia` | `nvda-new-feature` | `nvda` | 615.78.08 | x86_64-linux |
| `nvidia` | `nvidia-driver-new-feature` | `nvidia-driver-new-feature` | 615.78.08 | x86_64-linux |
| `nvidia` | `nvidia-firmware-new-feature` | `nvidia-firmware-new-feature` | 615.78.08 | x86_64-linux |
| `nvidia` | `nvidia-module-new-feature` | `nvidia-module-new-feature` | 615.78.08 | x86_64-linux |
| `openpace` | `openpace` | `openpace` | 1.1.4 | x86_64-linux |
| `video` | `openshot` | `openshot` | 4.1.1 | x86_64-linux |
| `pdfcraft` | `pdfcraft` | `pdfcraft` | 0.8.0 | x86_64-linux |
| `phive` | `phive` | `phive` | 12.2.0 | x86_64-linux |
| `photocraft` | `photocraft` | `photocraft` | 0.9.0 | x86_64-linux |
| `audio` | `pipewire-latest` | `pipewire` | 1.6.11 | x86_64-linux |
| `containers` | `podman-latest` | `podman` | 6.2.0 | x86_64-linux |
| `security` | `proxychains-ng` | `proxychains-ng` | 4.17 | x86_64-linux |
| `security` | `radare2` | `radare2` | 6.2.6 | x86_64-linux |
| `security` | `reaver` | `reaver` | 1.6.6 | x86_64-linux |
| `river` | `river-xmonad-runtime` | `river-xmonad-runtime` | 0.4.8 | x86_64-linux |
| `security` | `rizin` | `rizin` | 0.9.1 | x86_64-linux |
| `remote-desktop` | `rustdesk-server` | `rustdesk-server` | 1.1.16 | x86_64-linux |
| `remote-desktop` | `rustdesk` | `rustdesk` | 1.5.3 | x86_64-linux |
| `security` | `sdb` | `sdb` | 2.6.2 | x86_64-linux |
| `terminals` | `shader-slang-bin` | `shader-slang-bin` | 2026.20 | x86_64-linux |
| `soundcraft` | `soundcraft` | `soundcraft` | 0.5.0 | x86_64-linux |
| `nvidia` | `steam-nvidia-new-feature` | `steam` | 1.0.0.87 | x86_64-linux |
| `games` | `steam` | `steam` | 1.0.0.87 | x86_64-linux |
| `river` | `swaybg-latest` | `swaybg` | 1.2.2 | x86_64-linux |
| `river` | `swaylock-latest` | `swaylock` | 1.8.6 | x86_64-linux |
| `tor` | `tor` | `tor` | 0.4.9.16 | x86_64-linux |
| `applications` | `torando-gui` | `torando-gui` | 1.4.1 | x86_64-linux |
| `tor` | `torbrowser-assets` | `torbrowser-assets` | 16.0.1 | x86_64-linux |
| `tor` | `torbrowser` | `torbrowser` | 16.0.1 | x86_64-linux |
| `applications` | `turborec-nvidia-new-feature` | `turborec-nvidia-new-feature` | 3.10.4 | x86_64-linux |
| `applications` | `turborec` | `turborec` | 3.10.4 | x86_64-linux |
| `utils` | `ueberzugpp` | `ueberzugpp` | 2.9.11 | x86_64-linux |
| `browsers` | `ungoogled-chromium-bin` | `ungoogled-chromium-bin` | 156.0.8078.79-1 | x86_64-linux |
| `browsers` | `ungoogled-chromium` | `ungoogled-chromium` | 156.0.8078.47-1 | x86_64-linux |
| `vectorcraft` | `vectorcraft` | `vectorcraft` | 0.10.0 | x86_64-linux |
| `video` | `vlc` | `vlc` | 3.0.24 | x86_64-linux |
| `video` | `vvdec` | `vvdec` | 3.2.1 | x86_64-linux |
| `river` | `wayland-protocols-latest` | `wayland-protocols` | 1.49 | x86_64-linux |
| `river` | `wayland-latest` | `wayland` | 1.26.0 | x86_64-linux |
| `wazuh` | `wazuh-agent` | `wazuh-agent` | 4.14.10 | x86_64-linux |
| `wazuh-search` | `wazuh-dashboard` | `wazuh-dashboard` | 4.14.10-1 | x86_64-linux |
| `wazuh-search` | `wazuh-indexer` | `wazuh-indexer` | 4.14.10-1 | x86_64-linux |
| `wazuh` | `wazuh-manager` | `wazuh-manager` | 4.14.10 | x86_64-linux |
| `video` | `wf-recorder-nvidia-new-feature` | `wf-recorder-nvidia-new-feature` | 0.6.0 | x86_64-linux |
| `applications` | `whatsappel` | `whatsappel` | 3.3.1 | x86_64-linux |
| `security` | `whois` | `whois` | 5.6.6 | x86_64-linux |
| `audio` | `wireplumber-latest` | `wireplumber` | 0.5.18 | x86_64-linux |
| `river` | `wlr-randr-latest` | `wlr-randr` | 0.5.0 | x86_64-linux |
| `river` | `wlroots-latest` | `wlroots` | 0.20.2 | x86_64-linux |
| `wordcraft` | `wordcraft` | `wordcraft` | 0.7.0 | x86_64-linux |
| `xlibre` | `xf86-input-keyboard-xlibre` | `xf86-input-keyboard-xlibre` | 25.0.0 | x86_64-linux |
| `xlibre` | `xf86-input-mouse-xlibre` | `xf86-input-mouse-xlibre` | 25.0.0 | x86_64-linux |
| `xlibre` | `xf86-input-wacom-xlibre` | `xf86-input-wacom-xlibre` | 1.2.4 | x86_64-linux |
| `xlibre` | `xf86-video-ark-xlibre` | `xf86-video-ark-xlibre` | 25.0.0 | x86_64-linux |
| `xlibre` | `xf86-video-i128-xlibre` | `xf86-video-i128-xlibre` | 25.0.0 | x86_64-linux |
| `xlibre` | `xf86-video-qxl-xlibre` | `xf86-video-qxl-xlibre` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-input-elographics` | `xlibre-input-elographics` | 25.0.1 | x86_64-linux |
| `xlibre` | `xlibre-input-evdev` | `xlibre-input-evdev` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-input-joystick` | `xlibre-input-joystick` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-input-keyboard` | `xlibre-input-keyboard` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-input-libinput` | `xlibre-input-libinput` | 25.0.1 | x86_64-linux |
| `xlibre` | `xlibre-input-mouse` | `xlibre-input-mouse` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-input-synaptics` | `xlibre-input-synaptics` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-input-vmmouse` | `xlibre-input-vmmouse` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-input-void` | `xlibre-input-void` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-input-wacom` | `xlibre-input-wacom` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-server` | `xlibre-server` | 25.2.3 | x86_64-linux |
| `xlibre` | `xlibre-video-amdgpu` | `xlibre-video-amdgpu` | 25.1.2 | x86_64-linux |
| `xlibre` | `xlibre-video-apm` | `xlibre-video-apm` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-ark` | `xlibre-video-ark` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-ast` | `xlibre-video-ast` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-ati` | `xlibre-video-ati` | 25.0.1 | x86_64-linux |
| `xlibre` | `xlibre-video-chips` | `xlibre-video-chips` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-cirrus` | `xlibre-video-cirrus` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-dummy` | `xlibre-video-dummy` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-fbdev` | `xlibre-video-fbdev` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-freedreno` | `xlibre-video-freedreno` | 25.0.0 | Outro alvo |
| `xlibre` | `xlibre-video-geode` | `xlibre-video-geode` | 25.0.0 | Outro alvo |
| `xlibre` | `xlibre-video-i128` | `xlibre-video-i128` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-i740` | `xlibre-video-i740` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-intel` | `xlibre-video-intel` | 25.0.2 | x86_64-linux |
| `xlibre` | `xlibre-video-mach64` | `xlibre-video-mach64` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-mga` | `xlibre-video-mga` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-neomagic` | `xlibre-video-neomagic` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-nested` | `xlibre-video-nested` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-nouveau` | `xlibre-video-nouveau` | 25.0.1 | x86_64-linux |
| `xlibre` | `xlibre-video-nv` | `xlibre-video-nv` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-ps3` | `xlibre-video-ps3` | 1.2.6.1 | Outro alvo |
| `xlibre` | `xlibre-video-qxl` | `xlibre-video-qxl` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-r128` | `xlibre-video-r128` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-rendition` | `xlibre-video-rendition` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-s3virge` | `xlibre-video-s3virge` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-savage` | `xlibre-video-savage` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-siliconmotion` | `xlibre-video-siliconmotion` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-sis` | `xlibre-video-sis` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-sisusb` | `xlibre-video-sisusb` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-tdfx` | `xlibre-video-tdfx` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-trident` | `xlibre-video-trident` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-v4l` | `xlibre-video-v4l` | 25.0.1 | x86_64-linux |
| `xlibre` | `xlibre-video-vbox` | `xlibre-video-vbox` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-vesa` | `xlibre-video-vesa` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-vmware` | `xlibre-video-vmware` | 25.0.0 | x86_64-linux |
| `xlibre` | `xlibre-video-voodoo` | `xlibre-video-voodoo` | 25.0.0 | x86_64-linux |
| `xmonad-wayland` | `xmonad-wayland` | `xmonad-wayland` | 0.5.0 | x86_64-linux |
| `xmonad` | `xmonad` | `xmonad` | 0.18.1 | x86_64-linux |
| `river` | `xwayland-latest` | `xorg-server-xwayland` | 24.1.14 | x86_64-linux |
| `einvoicing` | `xrechnung-validator-configuration` | `xrechnung-validator-configuration` | 2026-08-31 | x86_64-linux |
| `video` | `yt-dlp` | `yt-dlp` | 2026.10.26 | x86_64-linux |
| `video` | `ytfzf` | `ytfzf` | 2.6.2 | x86_64-linux |
| `zabbix` | `zabbix-agent2` | `zabbix-agent2` | 7.4.16 | x86_64-linux |
| `zabbix` | `zabbix-agentd` | `zabbix-agentd` | 7.4.16 | x86_64-linux |
| `zabbix` | `zabbix-get` | `zabbix-get` | 7.4.16 | x86_64-linux |
| `zabbix` | `zabbix-java-gateway` | `zabbix-java-gateway` | 7.4.16 | x86_64-linux |
| `zabbix` | `zabbix-js` | `zabbix-js` | 7.4.16 | x86_64-linux |
| `zabbix` | `zabbix-proxy` | `zabbix-proxy` | 7.4.16 | x86_64-linux |
| `zabbix` | `zabbix-sender` | `zabbix-sender` | 7.4.16 | x86_64-linux |
| `zabbix` | `zabbix-server` | `zabbix-server` | 7.4.16 | x86_64-linux |
| `zabbix` | `zabbix-web-service` | `zabbix-web-service` | 7.4.16 | x86_64-linux |
| `zen` | `zen-browser-bin` | `zen-browser-bin` | 1.23.4b | x86_64-linux |
| `applications` | `zupt-gui` | `zupt-gui` | 5.2.9 | x86_64-linux |
| `applications` | `zupt` | `zupt` | 5.2.9 | x86_64-linux |

<!-- package-catalog:end -->

## Documentação

A [build farm](https://farm.securityops.co/) atende `x86_64-linux`.
Os drivers Freedreno (ARM), Geode (i686) e PS3 (PowerPC) permanecem no
inventário completo, mas dependem de builders compatíveis e validação.
Jobs agendados e builds privados não comprovam disponibilidade pública de substitutos.

| Guia | Conteúdo |
|---|---|
| [Módulos dos pacotes](README.md#applications) | Nomes dos projetos e módulos Guix |
| [WhatsAppel](docs/usage.md#whatsappel-emacs-workspace-and-guile-bridge) | Cliente Emacs, bridge Guile e backend configurado separadamente |
| [Eletrônica](docs/usage.md#electronics) | Simulação com ngspice e toolchains do Arduino IDE |
| [Acesso remoto](docs/usage.md#remote-desktop) | Cliente RustDesk e servidores de rendezvous/relay próprios |
| [Monitoramento](docs/usage.md#monitoring) | Servidor Zabbix, coletores, interface web, JMX e relatórios PDF |
| [Wazuh](docs/usage.md#wazuh) | Endpoint, manager, indexer, dashboard, envio de alertas e configuração explícita de TLS/estado |
| [Relatórios XBRL](docs/usage.md#structured-reporting) | CLI/biblioteca Arelle, validação offline e limites dos testes gráficos |
| [Identidade e esquemas oficiais](docs/usage.md#identity-and-official-schema-data) | DigiDoc4, eID belga, bibliotecas de assinatura e formatos do eSocial |
| [AusweisApp](docs/usage.md#ausweisapp-desktop-and-local-sdk) | Aplicativo de eID alemão e SDK local, com bibliotecas Qt compatíveis |
| [OpenPACE](docs/usage.md#openpace-native-eac-library) | Biblioteca EAC nativa, ferramentas CVC e confiança selecionada explicitamente |
| [Dados ICP-Brasil](docs/usage.md#icp-brasil-root-data) | Raízes por finalidade, coleção original de ACs, limite Ed521 e nenhuma importação automática |
| [Validação XML e documentos fiscais](docs/usage.md#xml-validation-with-phive) | Bibliotecas PHIVE Java, KoSIT Validator e regras XRechnung fixadas para uso offline |
| [Lacuna Web PKI](docs/webpki.pt-BR.md) | Host nativo, manifests dos navegadores e configuração do Guix Home |
| [AutoFirma](docs/usage.md#autofirma) | Pacote Linux oficial, comandos de assinatura e limites da integração com navegadores |
| [Referência de uso](docs/usage.md) | Serviços, Guix System e Guix Home |
| [Autenticação](#manutenção-e-autenticação) | Chave de assinatura e introdução do canal |
| [Histórico](CHANGELOG.md) | Notas de alterações anteriores |
| [Licenciamento](LICENSING.pt-BR.md) | Limites das licenças dos pacotes e projetos |

## Instalação

Adicione esta entrada à lista de canais em `channels.scm`.
O arquivo `.guix-channel` declara nonguix. Não é necessário um canal XLibre separado.

```scheme
(channel
 (name 'securityops)
 (url "https://git.securityops.com.br/cristiancmoises/securityops-channel")
 (branch "main")
 (introduction
  (make-channel-introduction
   "1662809a25bf267088b0c066eed8992bd52da8d7"
   (openpgp-fingerprint
    "0CFA 43B9 AA96 42EA AF2B  E983 C4C6 61C9 ECFB 46E8"))))
```

Atualize os canais e instale os pacotes desejados:

```sh
guix pull
guix install fish kitty zupt zupt-gui
```

O canal também fornece o host nativo `lacuna-webpki` para sites que usam
certificados digitais. O [guia do Web PKI](docs/webpki.pt-BR.md) explica a
extensão separada do navegador e a configuração de mensagens nativas.

O AutoFirma 1.9 está disponível em `(securityops packages autofirma)` e é
opcional. Adicionar o canal não instala o aplicativo nem altera certificados.
Consulte as [notas de uso](docs/usage.md#autofirma) antes de configurar o navegador.

Instalar no perfil do usuário não substitui automaticamente um pacote do
Guix Home ou do sistema. Reconfigure o perfil responsável pelo pacote.
Use `(commit "...")` para fixar uma revisão reproduzível.

## Pacotes pré-compilados

O cache público de substitutos está disponível em
[substitutes.securityops.co](https://substitutes.securityops.co/nix-cache-info),
com [substitutes.securityops.com.br](https://substitutes.securityops.com.br/nix-cache-info)
como endereço alternativo. Os pacotes publicados incluem Esquema 0.3.0,
Wayland protocols 1.49, esquemas de eventos eSocial 1.3-20260701 e esquemas de
comunicação 1.6. Os demais pacotes dependem das verificações de build e redistribuição;
um build concluído na [farm](https://farm.securityops.co/) não significa que
ele já foi publicado.

As versões estáveis das receitas atualizadas em 2026-11-11 estão abaixo. Esta
tabela descreve a revisão do canal; consulte a farm para acompanhar o build e a
disponibilidade pública dos substitutos.

| Receita | Versão |
|---|---|
| PipeWire | 1.6.11 |
| Arelle | 2.47.4 |
| sdb | 2.6.2 |
| Tor | 0.4.9.16 |
| Tor Browser | 16.0.1 |
| yt-dlp | 2026.10.26 |
| OpenShot | 4.1.1 |
| XLibre Server | 25.2.3 |
| Google Chrome | 157.0.8103.78-1 |
| Ungoogled Chromium | 156.0.8078.79-1 |
| Zabbix | 7.4.16 |
| AusweisApp | 2.6.1 |
| MoneyPrinterTurbo | 1.3.10 |
| Wazuh agent/manager | 4.14.10 |

O Google Chrome permanece sujeito à licença do fornecedor e não é publicado
como substituto público.

O [código-fonte correspondente](https://farm.securityops.co/sources/#pt-br)
inclui downloads dos fontes, scripts exatos de compilação, patches e avisos de
licença das saídas publicadas.

Baixe e confira a chave de assinatura dos substitutos antes de autorizá-la:

```sh
curl --fail --location --output securityops-substitutes.pub \
  https://substitutes.securityops.co/signing-key.pub
echo '5db8721d97525215c3497e999c537ee8aaca56f9ee0f4b03e7ad1f0d028040f8  securityops-substitutes.pub' \
  | sha256sum --check && sudo guix archive --authorize < securityops-substitutes.pub
```

Após adicionar o canal, solicite um output pré-compilado sem permitir compilação
local nem offloading:

```sh
guix build -e '(@ (securityops packages river) wayland-protocols-latest)' \
  --substitute-urls='https://substitutes.securityops.co https://bordeaux.guix.gnu.org https://ci.guix.gnu.org' \
  --max-jobs=0 --no-offload
```

Os substitutos correspondem a caminhos exatos no store: as revisões do canal e
das dependências, assim como a arquitetura, precisam corresponder ao build
disponível. O comando falha se faltarem substitutos. A chave do cache é distinta
da chave OpenPGP que assina os commits do canal. As licenças e os avisos dos
pacotes permanecem incluídos nos outputs.

## Aplicativos

As receitas dos aplicativos ficam em módulos com o nome de cada projeto, como
`(securityops packages zupt)` e `(securityops packages turborec)`. Cada receita
pode atualizar sua própria fonte, versão e dependências. Manifests existentes
podem continuar importando `(securityops packages applications)` ou
`(securityops packages apps)`: ambos reexportam os mesmos bindings dos pacotes.
`(securityops packages containers)` também preserva sua exportação do Esquema.
Os nomes e as versões não mudaram; o nome do Evelin no Guix é `evelin-bin`.

Depois de publicar uma revisão do canal, atualize a
[instância Toys mantida pelo projeto](https://toys.securityops.co) e confira
o commit indexado e os módulos/arquivos dos pacotes no catálogo. Cada instância
tem seu próprio ciclo de atualização; [toys.whereis.social](https://toys.whereis.social)
é um serviço externo e não há garantia de atualização imediata. Consulte o
[inventário dos projetos](README.md#applications) para os módulos de cada pacote.

### Zen Browser

O pacote `zen-browser-bin` fornece o [Zen 1.23.4b oficial](https://github.com/zen-browser/desktop/releases/tag/1.23.4b)
para `x86_64-linux`, com SHA-256 fixado. Instale com
`guix install zen-browser-bin` e execute `zen-browser` ou `zen`.
As atualizações são gerenciadas pelo Guix. A receita adapta o binário upstream,
preservando o sandbox e os avisos de licença; não recompila o Firefox.
Um build concluído não significa que o substituto já esteja publicado.

### WhatsAppel

O WhatsAppel 3.3.1 está disponível como `whatsappel`, em
`(securityops packages whatsappel)` e na coleção de aplicativos:

```sh
guix install whatsappel
whatsappel --help
```

O pacote inclui o cliente Emacs, workers Python e `whatsappel-bridge`.
Usa o Emacs selecionado e a configuração existente; a instalação não inicia
serviços nem vincula contas. Configure o wuzapi separadamente. O helper Rust
opcional `pqenv` e o player externo mpv não estão incluídos. Consulte os
[comandos e limites de validação](docs/usage.md#whatsappel-emacs-workspace-and-guile-bridge).

### TurboRec

O TurboRec 3.10.4 está disponível em `(securityops packages turborec)`:

```sh
guix package -e '(@ (securityops packages turborec) turborec)'
turborec gui
```

O pacote inclui documentação em inglês e português do Brasil em
`share/doc/turborec`. Auto pode usar CPU quando a GPU não funciona; selecionar
uma GPU explicitamente exige driver compatível e FFmpeg com esse encoder.
Manual Chroma começa desligado (4:2:0 automático e compatível); inglês e o
perfil Best/Auto/23 fps/4K continuam padrão no aplicativo principal.
Os arquivos concluídos são verificados quanto aos fluxos, duração positiva e
primeiros quadros antes de confirmar Saved; essa checagem limitada não examina
o arquivo inteiro. O launcher legado preserva os argumentos também no Bash 3.2.

Para NVIDIA/Wayland wlroots, a variante explícita `turborec-nvidia-new-feature`
usa wf-recorder 0.6.0/FFmpeg 8.1.3 realmente pareados e com NVENC. O restante
do pipeline usa FFmpeg 9.0.2. Trocar o FFmpeg do terminal não muda a libavcodec
do recorder; o FFmpeg 9 não é compatível com a ABI desse build do wf-recorder.
Depois de atualizar o canal, escolha o comando adequado:

```sh
# Primeira instalação, sem nenhuma variante do aplicativo nesse perfil
guix package -e '(@ (securityops packages turborec) turborec-nvidia-new-feature)'
# OU substitua o turborec genérico já instalado na mesma transação
guix package -r turborec -e '(@ (securityops packages turborec) turborec-nvidia-new-feature)'
```

Não instale ambas no mesmo perfil: elas fornecem os mesmos comandos. O pacote
genérico continua sem dependências proprietárias NVIDIA. A variante não troca
nem ativa o driver do kernel, não altera bibliotecas globalmente e não reinicia
o sistema. A captura/conversão passa pela CPU e a codificação usa a GPU; não é
um pipeline CUDA sem cópias. A checagem do perfil não certifica todos os dispositivos.
Testes das receitas: `guix repl -L . tests/wf-recorder-packages.scm` e
`guix repl -L . tests/turborec-backend-packages.scm`.

### FFmpeg e codificação NVIDIA

O módulo `(securityops packages video)` oferece FFmpeg 9.0.2 e headers NVENC
13.1.15.0. Para uma primeira instalação, escolha CPU e uso geral, sem
dependências proprietárias NVIDIA:

```sh
guix package -e '(@ (securityops packages video) ffmpeg)'
```

Para o driver NVIDIA new-feature, escolha a variante explícita NVENC/NVDEC.
Se `ffmpeg` já estiver instalado no mesmo perfil do usuário, substitua-o em
uma única transação:

```sh
guix package -r ffmpeg -e '(@ (securityops packages video) ffmpeg-nvidia-new-feature)'
```

Se nenhuma das variantes estiver instalada nesse perfil, não use a remoção:

```sh
guix package -e '(@ (securityops packages video) ffmpeg-nvidia-new-feature)'
```

Para voltar da variante NVIDIA já instalada para CPU e uso geral:

```sh
guix package -r ffmpeg-nvidia-new-feature -e '(@ (securityops packages video) ffmpeg)'
```

Não mantenha ambas no mesmo perfil: os arquivos dos executáveis e bibliotecas
entram em conflito. A remoção exige que o pacote indicado esteja instalado.
Pacotes de outros perfis não são alterados. Confira `ffmpeg -version` e
`ffmpeg -hide_banner -encoders` após escolher o comando adequado.

Para decodificar H.266/VVC por software, o módulo também fornece `vvdec` 3.2.1
e `ffmpeg-vvdec` (FFmpeg 9.0.2 com a integração externa do VVdeC fixada por
hash). Instale `ffmpeg-vvdec` em um perfil separado: ele fornece o mesmo
executável `ffmpeg` e as mesmas bibliotecas das outras variantes, portanto não
podem coexistir no mesmo perfil. Selecione `libvvdec` com `-c:v libvvdec`; a
receita testa a decodificação com um fluxo oficial de conformidade de 30
quadros.

O SDK 13.1 exige driver 610 ou superior. As bibliotecas CUDA, NVENC e NVCUVID
usadas pelo pacote também precisam corresponder ao driver carregado no kernel.
Instalar esse pacote não instala nem ativa um módulo do kernel. O encoder
aparecer na lista não comprova funcionamento: faça uma codificação real antes
de gravar. Se o Guix Home fornece seu `ffmpeg`, selecione a variante no
`home.scm` e reconfigure esse perfil; confira `command -v ffmpeg` para saber
qual executável tem prioridade. Aplicativos já compilados podem usar um FFmpeg
próprio: trocar o comando do terminal não substitui essa dependência.

Teste curto de codificação real, sem capturar sua tela ou seu microfone:

```sh
ffmpeg -hide_banner -nostdin -f lavfi -i testsrc2=size=1280x720:rate=23 \
  -frames:v 23 -an -c:v h264_nvenc -preset p6 -f null -
```

Validado em x86_64-linux com RTX 4060 e driver 615.71.09: as duas compilações
passaram em 2.895 testes FATE cada, incluindo os três testes Frei0r. Vídeos
sintéticos curtos em H.264, HEVC e AV1 passaram na codificação NVENC,
decodificação NVDEC e conferência de 4K/23 fps, YUV420 e metadados BT.709 em
MP4/MKV/WebM. A gravação H.264/AAC por CPU e a decodificação completa também
passaram. Isso não comprova suporte a todas as GPUs, outras arquiteturas ou
ao backend de captura específico de um aplicativo; eles exigem testes próprios.

Teste das receitas: `guix repl -L . tests/ffmpeg-packages.scm`.

O River 0.4 e seus auxiliares estão em `(securityops packages river)`.
O [exemplo de perfil separado](docs/usage.md#consuming-the-channel-from-etcconfigscm-and-homescm)
também inclui os pacotes de áudio atualizados. O River 0.4 precisa de um
gerenciador de janelas externo; este canal fornece o gerenciador XMonad
Wayland em `(securityops packages xmonad-wayland)`, compilado a partir do
commit assinado do repositório público, e um desktop físico com River rodando
esse gerenciador está em uso desde setembro de 2026. As versões mais recentes
do XMonad e do xmonad-contrib estão em `(securityops packages xmonad)`.
O gerenciador também aceita o idioma clássico do `xmonad.hs` via
`xmonad-wayland --recompile`, facilitando a migração de uma configuração
X11 para o River.

## Repositórios

Todos utilizam a mesma introdução do canal.

| Função | Repositório |
|---|---|
| Principal | [git.securityops.com.br](https://git.securityops.com.br/cristiancmoises/securityops-channel) |
| Espelho | [git.securityops.co](https://git.securityops.co/cristiancmoises/securityops-channel) |
| Espelho | [Codeberg](https://codeberg.org/berkeley/securityops-channel) |
| Espelho | [GitHub](https://github.com/cristiancmoises/securityops-channel) |

## Manutenção e autenticação

Consulte o [README em inglês](README.md#build-and-check-a-local-checkout) para os
comandos de validação local. O comando `./update-channel check` verifica somente
os pacotes cadastrados no script, não o canal inteiro.

Fish exige dependências Cargo correspondentes; Emacs exige patches compatíveis.
Pacotes binários e aplicativos com fontes incluídas precisam de atualização
deliberada dos arquivos e hashes.

A introdução fixa o commit `1662809a25bf267088b0c066eed8992bd52da8d7`
e a chave `0CFA 43B9 AA96 42EA AF2B E983 C4C6 61C9 ECFB 46E8`.
O Guix verifica as assinaturas ao atualizar o canal.

Em 23/10/2026, documentos internos foram removidos do histórico. A chave de
assinatura permanece a mesma, mas os commits e a introdução mudaram. Atualize
as declarações existentes para a introdução acima. Troque os pins
`(commit "...")` antigos por uma revisão do novo histórico, ou remova o pin
para acompanhar `main`. Gerações antigas podem
recusar a nova ancestralidade; valide o canal em um perfil Guix novo antes
da migração. Mantenha a verificação de assinaturas habilitada.

## Licença

Código do canal: GPL-3.0-or-later; consulte [LICENSE](LICENSE).
Cada programa mantém sua própria licença. Veja [LICENSING.pt-BR.md](LICENSING.pt-BR.md).

### MatLivre / MatLibre (Emacs)

`matlivre` 0.1.9 e `emacs-matlibre` oferecem computação científica no
aplicativo gráfico e no Emacs gráfico ou terminal. Consulte [instalação,
comandos e requisitos da buildfarm](docs/matlivre.md).

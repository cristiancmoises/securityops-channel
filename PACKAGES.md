# Pacotes do canal

Este índice registra as receitas e reexportações usadas na atualização de
01/10/2026. As versões são as verificadas nessa data, não uma promessa de
atualização automática. O canal fixa fontes e hashes quando mantém uma receita
própria; reexportações acompanham a revisão autenticada de seu canal de origem.

## Atualização de 01/10/2026

| Pacote | Receita anterior | Receita atual | Origem |
|---|---|---|---|
| AutoFirma | Novo pacote | 1.9, Linux | [Downloads oficiais](https://firmaelectronica.gob.es/descargas) |
| Google Chrome | 154.0.8037.57-1 | 154.0.8037.92-1 | [Versões estáveis do Google](https://versionhistory.googleapis.com/v1/chrome/platforms/linux/channels/stable/versions) |
| Chromium portátil | 153.0.8010.47-1 | 154.0.8037.57-1 | [Release oficial](https://github.com/ungoogled-software/ungoogled-chromium-portablelinux/releases/tag/154.0.8037.57-1) |
| LibreWolf | 156.0-1 | 156.0.1-1 | [Downloads oficiais](https://librewolf.net/installation/linux/) |
| Tor Browser e assets | 15.0.23 | 15.0.24 | [Release oficial](https://blog.torproject.org/new-release-tor-browser-15024/) |
| Kitty | 0.49.1 | 0.49.2 | [Release oficial](https://github.com/kovidgoyal/kitty/releases/tag/v0.49.2) |
| Slang | 2026.18.3 | 2026.19 | [Release oficial](https://github.com/shader-slang/slang/releases/tag/v2026.19) |
| Steam com NVIDIA, bootstrap | 1.0.0.85 | 1.0.0.87 | [Arquivos estáveis da Valve](https://repo.steampowered.com/steam/archive/stable/) |
| Docker e Docker CLI | 29.8.1 | 29.8.2 | [Moby](https://github.com/moby/moby/releases/tag/docker-v29.8.2), [CLI](https://github.com/docker/cli/tree/v29.8.2) |
| Podman | 6.1.2 | 6.1.3 | [Release e correção de segurança](https://github.com/podman-container-tools/podman/releases/tag/v6.1.3) |
| WirePlumber | 0.5.17 | 0.5.18 | [Notas oficiais](https://pipewire.pages.freedesktop.org/wireplumber/resources/releases.html) |
| VLC | 3.0.23 | 3.0.24 | [Fontes oficiais](https://download.videolan.org/pub/videolan/vlc/3.0.24/) |
| Turborec | 3.9.1 | 3.10.1 | [Release oficial](https://codeberg.org/berkeley/turborec/releases/tag/v3.10.1) |
| Channel, auxiliar River | 0.4.1-1.94a3d6c | 0.5.1 | [Tags oficiais](https://codeberg.org/Sivecano/channel/tags) |
| Wacom para XLibre | 1.2.3 | 1.2.4 | [Release oficial](https://github.com/linuxwacom/xf86-input-wacom/releases/tag/xf86-input-wacom-1.2.4) |

As atualizações de navegadores mantêm os assets, traduções e fontes auxiliares
correspondentes. O inventário inclui os módulos NVIDIA e XMonad, além de todas
as exportações do XLibre incluído; o helper `update-channel` continua sendo uma
verificação parcial.

### Validação e limites

| Verificação | Resultado |
|---|---|
| AutoFirma | Build, dois testes do runtime e sete de CLI e assinatura com verificação independente pelo OpenSSL; sem instalação |
| Interface do AutoFirma | Janela e fontes verificadas em Xvfb; oito compartilhamentos inválidos rejeitados e caminhos com espaços aceitos |
| Kitty e Slang | Build e execução; descoberta do compilador e geração de SPIR-V verificadas |
| WirePlumber | Build com PipeWire 1.6.9; 57 testes passaram, sem falhas |
| Turborec | Build e `--version` verificadas |
| Docker CLI e Podman | Fontes, builds e comandos `--version` verificados; daemon Docker não recompilado |
| Chrome e Chromium portátil | Fontes, builds e comandos `--version` verificados |
| Wacom | Fonte baixada pelo Guix e hash verificado; driver completo não compilado |
| Steam com NVIDIA | Fonte, derivação e preservação dos fechamentos NVIDIA verificadas; contêiner completo não compilado |
| LibreWolf, Tor Browser e VLC | Receitas avaliadas; builds completos dependem de substitutos ou de um builder apropriado |

O Chromium compilado das fontes continua herdando **151.0.7922.137-1** do
Guix, enquanto o upstream publicou 154.0.8037.92-1. A atualização requer
rebase dos patches do compilador, libc++ 22 e validação do conjunto de patches;
alterar somente a versão produziria uma receita incompatível. Use o pacote
portátil atualizado quando essa alternativa for adequada.

Zupt e Zupt GUI mantêm a versão pública 5.2.9. Uma versão candidata 5.2.10
instalada localmente não possui atualmente tag pública recuperável e deve ser
preservada: nenhuma instalação desta revisão deve fazer downgrade automático.
As verificações de versão do Web PKI e do driver PS3 não oferecem uma conclusão
de atualização; seus pins existentes foram mantidos.

O AutoFirma 1.9 é a versão Linux estável; 1.9.1 e 1.9.2 são específicas para
macOS. Usa Java 17.0.20.1+1, NSS 3.129, NSPR 4.40 e SQLite 3.53.4; não importa
certificados nem configura navegadores. A verificação final reutilizou saídas
existentes com `--no-grafts`; a receita mantém o comportamento normal do Guix.
O lançador gráfico requer namespaces de usuário; cartões,
Wayland e integração completa com navegadores ainda não foram testados.
Consulte as [notas de uso](docs/usage.md#autofirma) para os requisitos.

### Instalação neste workstation

O perfil de usuário recebeu Glances 4.5.7, Kitty 0.49.2, Chrome
154.0.8037.92-1, Chromium portátil 154.0.8037.57-1, Docker CLI 29.8.2 e
Podman 6.1.3. Os demais pacotes e as gerações anteriores foram preservados.
O AutoFirma não foi instalado.

As gerações da Home e do sistema não foram ativadas nesta revisão. O fluxo
local continua sendo `~/home.sh` para a Home e `~/up-river.sh` para o sistema.
O launcher local do Kitty ainda aponta para o perfil do sistema; Chrome e
Chromium encontrados pelo shell ainda podem vir da Home. Confira o comando
efetivo com `command -v` e `--version`, não apenas a lista do perfil de usuário.
Reconfigure somente após conferir os substitutos necessários e preservar
qualquer versão local mais nova que a receita pública.

## NVIDIA e desktop River

| Módulo | Pacotes | Versão verificada | Origem |
|---|---|---|---|
| `(securityops packages nvidia)` | `nvidia-driver-new-feature`, `nvidia-firmware-new-feature`, `nvidia-module-new-feature` | 615.71.09 | Reexportações do nonguix; o módulo foi compilado para o kernel 7.2.8 |
| `(securityops packages nvidia)` | `nvda-new-feature` | 615.71 | Integração gráfica nonguix para o driver 615.71.09 |
| `(securityops packages nvidia)` | `steam-nvidia-new-feature` | Bootstrap Steam 1.0.0.87 | Cliente do canal; stack NVIDIA 615.71.09 preservado. O Steam atualiza seu cliente em execução separadamente |
| `(securityops packages river)` | `river-xmonad-runtime` | 0.4.8 | Receita do canal |
| `(securityops packages river)` | `wayland-latest`, `wayland-protocols-latest` | 1.26.0, 1.49 | Receitas do canal |
| `(securityops packages river)` | `libevdev-latest`, `libinput-minimal-latest`, `libxkbcommon-latest` | 1.13.7, 1.32.0, 1.13.2 | Receitas do canal |
| `(securityops packages river)` | `foot-latest`, `fuzzel-latest`, `mako-latest`, `swaybg-latest` | 1.28.0, 1.15.0, 1.11.0, 1.2.2 | Receitas do canal |
| `(securityops packages river)` | `swaylock-latest`, `wlr-randr-latest` | 1.8.6, 0.5.0 | Receitas do canal |
| `(securityops packages river)` | `channel-river-input` | 0.5.1 | Receita do canal |
| `(securityops packages river)` | `xwayland-latest`, `wlroots-latest` | 24.1.13, 0.20.2 | Versões herdadas da revisão Guix selecionada |

`xwayland-latest` e `wlroots-latest` também são exportados pelo módulo River,
mas herdam a versão do Guix selecionado; os números da tabela são os desta
revisão. Consulte `guix show` após cada `guix pull` para saber suas versões
efetivas. O driver NVIDIA não adiciona DLSS
5 ao Red Dead Redemption 2; a disponibilidade desse recurso depende do jogo,
da GPU e do suporte oficial da NVIDIA.

## Aplicativos atualizados

| Módulo | Pacote | Versão verificada | Observação |
|---|---|---|---|
| `(securityops packages browsers)` | `google-chrome-stable` | 154.0.8037.92-1 | Receita binária do canal |
| `(securityops packages browsers)` | `librewolf` | 156.0.1-1 | Reexportação da receita `(securityops packages librewolf)`; build completo não executado nesta revisão |
| `(securityops packages tor)` | `tor` | 0.4.9.13 | Receita do canal; build e testes passaram |
| `(securityops packages shells)` | `fish` | 4.9.3 | Receita do canal; build passou |
| `(securityops packages monitoring)` | `glances` | 4.5.7 | Receita do canal |
| `(securityops packages video)` | `openshot` | 4.0.1 | Receita do canal; build passou |
| `(securityops packages terminals)` | `kitty` | 0.49.2 | Receita do canal; build e execução de `kitty --version` passaram |
| `(securityops packages terminals)` | `shader-slang-bin` | 2026.19 | Dependência da compilação de shaders do Kitty; binário oficial com hash fixado |
| `(securityops packages terminals)` | `go-github-com-ebitengine-purego` | 0.11.1 | Dependência Go do Kitty |
| `(securityops packages terminals)` | `go-github-com-kovidgoyal-go-shm-v2` | 2.0.1 | Dependência Go do Kitty; build e testes passaram |
| `(securityops packages emacs)` | `emacs`, `emacs-pgtk` | 31.1 | Reexportações do Guix selecionado |
| `(securityops packages webpki)` | `lacuna-webpki` | 2.16.0 | Host nativo; [guia de configuração](docs/webpki.pt-BR.md) |

## Contêineres

| Módulo | Pacote | Versão verificada | Origem |
|---|---|---|---|
| `(securityops packages containers)` | `docker-latest` (daemon `dockerd`) | 29.8.2 | Moby, tag `docker-v29.8.2`, fonte e hash fixados |
| `(securityops packages containers)` | `docker-cli-latest` (cliente `docker`) | 29.8.2 | Docker CLI, tag `v29.8.2`, fonte e hash fixados |
| `(securityops packages containers)` | `podman-latest` | 6.1.3 | Podman, tag `v6.1.3`, fonte e hash fixados |

As três receitas usam as fontes oficiais correspondentes aos commits das tags
e compilam com Go 1.26. O Podman herda os auxiliares da receita Guix, inclusive
o runtime OCI. As fontes incluem dependências Go vendorizadas; o build não
precisa baixá-las da rede. Para avaliar as três exportações:

```sh
guix repl -L . tests/containers.scm.in
```

Após `guix build` do daemon, `tests/docker-runtime.sh CAMINHO-NO-STORE`
confere se `containerd` e `runc` permanecem em seu fechamento. Os auxiliares
herdados desta revisão do Guix são `containerd` 1.6.22 e `runc` 1.3.0;
compilar e validar a configuração não substitui um teste real de contêiner
com o novo daemon após a ativação do sistema.

Para instalar cliente Docker e Podman no perfil de usuário, a partir da raiz
do canal:

```sh
guix package -L . \
  -e '(@ (securityops packages containers) docker-cli-latest)' \
  -e '(@ (securityops packages containers) podman-latest)'
```

Para usar o novo daemon em Guix System, configure os campos `docker` e
`docker-cli` do `docker-configuration` com os pacotes deste módulo e só então
reconfigure o sistema:

```scheme
#:use-module ((securityops packages containers) #:prefix container:)
;; No docker-configuration existente:
(docker container:docker-latest)
(docker-cli container:docker-cli-latest)
```

Instalar a CLI em um perfil de usuário altera o comando
`docker`, mas **não** altera o daemon atendendo `/var/run/docker.sock`; confirme
as duas versões com `docker version`. A troca do daemon deve ser feita após
concluir reconfigurações já em curso, preservando a geração anterior para
recuperação. O Podman rootless pode necessitar de `/etc/subuid` e `/etc/subgid`
para imagens que usem múltiplos UIDs/GIDs.

## Atualizar sem downgrade

1. Verifique a versão mais recente no projeto original e a versão efetiva do
   Guix/nonguix/small-guix. Para uma receita própria, atualize fonte, hash e
   dependências juntos; para uma reexportação, atualize o canal de origem.
2. Compare a versão candidata com a receita atual e com o perfil em uso. Não
   publique uma versão menor para contornar uma falha de build: corrija a causa
   ou registre a limitação.
3. Execute `guix lint -L . PACOTE`, `guix style -L . PACOTE` e
   `guix build -L . PACOTE`, além dos testes relevantes. O helper
   `./update-channel check` cobre somente os pacotes cadastrados nele.
4. Atualize o canal com `guix pull`; a instalação no Guix System, Guix Home ou
   perfil de usuário exige reconfigurar separadamente o perfil responsável.

O inventário completo de exportações pode ser obtido com
`guix repl -L . etc/package-inventory.scm.in` em um checkout com os canais
dependentes disponíveis. A compilação do kernel e do módulo NVIDIA 615.71.09
para 7.2.8 foi validada; isso não significa que a geração do sistema já tenha
sido ativada ou que o driver carregado tenha mudado.

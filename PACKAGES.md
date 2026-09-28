# Pacotes do canal

Este índice registra as receitas e reexportações usadas na atualização de
28/09/2026. As versões são as verificadas nessa data, não uma promessa de
atualização automática. O canal fixa fontes e hashes quando mantém uma receita
própria; reexportações acompanham a revisão autenticada de seu canal de origem.

## NVIDIA e desktop River

| Módulo | Pacotes | Versão verificada | Origem |
|---|---|---|---|
| `(securityops packages nvidia)` | `nvidia-driver-new-feature`, `nvidia-firmware-new-feature`, `nvidia-module-new-feature` | 615.71.09 | Reexportações do nonguix; o módulo foi compilado para o kernel 7.2.8 |
| `(securityops packages nvidia)` | `nvda-new-feature` | 615.71 | Integração gráfica nonguix para o driver 615.71.09 |
| `(securityops packages nvidia)` | `steam-nvidia-new-feature` | Steam 1.0.0.85 | Variante nonguix que usa o stack NVIDIA new-feature |
| `(securityops packages river)` | `river-xmonad-runtime` | 0.4.8 | Receita do canal |
| `(securityops packages river)` | `wayland-latest`, `wayland-protocols-latest` | 1.26.0, 1.49 | Receitas do canal |
| `(securityops packages river)` | `libevdev-latest`, `libinput-minimal-latest`, `libxkbcommon-latest` | 1.13.7, 1.32.0, 1.13.2 | Receitas do canal |
| `(securityops packages river)` | `foot-latest`, `fuzzel-latest`, `mako-latest`, `swaybg-latest` | 1.28.0, 1.15.0, 1.11.0, 1.2.2 | Receitas do canal |
| `(securityops packages river)` | `swaylock-latest`, `wlr-randr-latest` | 1.8.6, 0.5.0 | Receitas do canal |
| `(securityops packages river)` | `channel-river-input` | 0.4.1-1.94a3d6c | Receita do canal |
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
| `(securityops packages browsers)` | `google-chrome-stable` | 154.0.8037.57-1 | Receita binária do canal |
| `(securityops packages browsers)` | `librewolf` | 156.0-1 | Reexportação da receita `(securityops packages librewolf)`; já instalado, sem recompilação nesta atualização |
| `(securityops packages tor)` | `tor` | 0.4.9.13 | Receita do canal; build e testes passaram |
| `(securityops packages shells)` | `fish` | 4.9.3 | Receita do canal; build passou |
| `(securityops packages monitoring)` | `glances` | 4.5.7 | Receita do canal |
| `(securityops packages video)` | `openshot` | 4.0.1 | Receita do canal; build passou |
| `(securityops packages terminals)` | `kitty` | 0.49.1 | Receita do canal; build e execução de `kitty --version` passaram |
| `(securityops packages terminals)` | `shader-slang-bin` | 2026.18.3 | Dependência da compilação de shaders do Kitty; binário oficial com hash fixado |
| `(securityops packages terminals)` | `go-github-com-ebitengine-purego` | 0.11.1 | Dependência Go do Kitty |
| `(securityops packages terminals)` | `go-github-com-kovidgoyal-go-shm-v2` | 2.0.1 | Dependência Go do Kitty; build e testes passaram |
| `(securityops packages emacs)` | `emacs`, `emacs-pgtk` | 31.1 | Reexportações do Guix selecionado |
| `(securityops packages webpki)` | `lacuna-webpki` | 2.16.0 | Host nativo; [guia de configuração](docs/webpki.pt-BR.md) |

## Contêineres

| Módulo | Pacote | Versão verificada | Origem |
|---|---|---|---|
| `(securityops packages containers)` | `docker-latest` (daemon `dockerd`) | 29.8.1 | Moby, tag `docker-v29.8.1`, fonte e hash fixados |
| `(securityops packages containers)` | `docker-cli-latest` (cliente `docker`) | 29.8.1 | Docker CLI, tag `v29.8.1`, fonte e hash fixados |
| `(securityops packages containers)` | `podman-latest` | 6.1.2 | Podman, tag `v6.1.2`, fonte e hash fixados |

As três receitas usam as fontes oficiais correspondentes aos commits das tags
e compilam com Go 1.26. O Podman herda os auxiliares da receita Guix, inclusive
o runtime OCI. As fontes incluem dependências Go vendorizadas; o build não
precisa baixá-las da rede. Para avaliar as três exportações:

```sh
guix repl -L . tests/containers.scm
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

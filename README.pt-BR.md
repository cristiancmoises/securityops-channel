# securityops — um canal pessoal do GNU Guix

> Versões mais recentes dos aplicativos mais usados da estação **securityops**,
> empacotados do jeito Guix — hashes de fonte reais, cada definição herdando do
> upstream para permanecer pequena e auditável.

🌐 **Idioma:** **Português (Brasil)** · [English](README.md)

Este canal cura os programas nos quais esta máquina vive e os mantém na versão
oficial mais nova. Pacotes que o Guix fixado já entrega na versão mais recente
são **re-exportados sem alteração** (para que o canal seja o único lugar de onde
você os instala, e eles acompanhem o Guix automaticamente); pacotes que estão
*à frente* do Guix/nonguix carregam um **hash de fonte real, baixado**.

- **Host:** `predator-helios-intel` (a máquina do `/etc/config.scm` ativo)
- **Guix fixado:** commit `d1e9e23` (junho/2026); **depende de** `nonguix`
- **Mantenedor:** Cristian Cezar Moisés `<ethicalhacker@riseup.net>`
- **Casa:** [`https://git.securityops.co/cristiancmoises/securityops-channel`](https://git.securityops.co/cristiancmoises/securityops-channel) (oficial) · espelhos: [Codeberg](https://codeberg.org/berkeley/securityops-channel) · [GitHub](https://github.com/cristiancmoises/securityops-channel)
- **Assinatura:** todo commit é assinado com GPG (ed25519 `0CFA 43B9 … ECFB 46E8`) e o canal é autenticado (veja [Publicação e autenticação](#publicação-e-autenticação))

> A lista completa de pacotes (índice de 50 pacotes), com versões e a última
> mudança de cada um, está no [README em inglês](README.md#-full-package-index-50-packages).
> Este documento cobre tudo que um usuário brasileiro precisa para **instalar,
> usar, verificar e manter** o canal, além de uma visão geral dos pacotes.

---

## Instalação

Este canal **depende do nonguix** (para google-chrome, steam e o sistema de
build do Mullvad) — mantenha a entrada do `nonguix` no seu `channels.scm`.
Adicione o securityops com sua `(introduction …)` para que o `guix pull`
verifique a assinatura de cada commit:

```scheme
(channel
 (name 'securityops)
 (url "https://git.securityops.co/cristiancmoises/securityops-channel")
 (branch "main")
 (introduction
  (make-channel-introduction
   "af46f5cce66179f3e53f87c86ca2538c8fc63f98"
   (openpgp-fingerprint
    "0CFA 43B9 AA96 42EA AF2B  E983 C4C6 61C9 ECFB 46E8"))))
```

A URL oficial é clonada por **HTTPS** sem necessidade de conta. Prefere um
espelho? Troque a `url` — a introdução é idêntica:

```scheme
 (url "https://codeberg.org/berkeley/securityops-channel")   ; ou
 (url "https://github.com/cristiancmoises/securityops-channel")
```

Depois:

```sh
guix pull
guix install kitty tor torbrowser openshot google-chrome-stable mullvad-vpn-desktop
# o restante resolve para o mesmo pacote que o guix/nonguix entrega
```

Como todo pacote aqui tem versão **≥** ao que o guix/nonguix entrega,
`guix install <pacote>` prefere de forma transparente este canal para os que
estão à frente.

> Adicionar o `securityops` sem uma linha `(commit …)` acompanha o ramo `main`;
> adicione uma para fixar um pull totalmente reproduzível. A `(introduction …)`
> é definida uma única vez e independe de qualquer fixação posterior.

### Clonar ou fazer pull por HTTPS

Clone por HTTPS a partir da forja oficial — ou de qualquer espelho — sem conta:

```sh
git clone https://git.securityops.co/cristiancmoises/securityops-channel   # oficial
git clone https://codeberg.org/berkeley/securityops-channel               # espelho
git clone https://github.com/cristiancmoises/securityops-channel          # espelho
```

### Verificar a introdução e as assinaturas

A `(introduction …)` fixa o primeiro commit assinado e a chave do mantenedor,
então o `guix pull` autentica cada commit — um commit adulterado ou não
assinado aborta o pull. Para conferir a chave fora de banda:

```sh
gpg --recv-keys 0CFA43B9AA9642EAAF2BE983C4C661C9ECFB46E8
gpg --fingerprint 0CFA43B9AA9642EAAF2BE983C4C661C9ECFB46E8
#   → 0CFA 43B9 AA96 42EA AF2B  E983 C4C6 61C9 ECFB 46E8
git -C securityops-channel log --show-signature -1
```

### Solução de problemas

- **`guix pull` diz que o canal não está autenticado / introdução divergente.**
  Sua entrada em `channels.scm` está sem a `(introduction …)` acima (copie-a
  exatamente) ou fixa um commit anterior ao commit de introdução.
- **`failed to authenticate commit … signature verification failed`.** Importe
  `0CFA43B9AA9642EAAF2BE983C4C661C9ECFB46E8` no seu chaveiro; a autenticação
  vale a partir do commit de introdução em diante.
- **Conflito de introdução do nonguix.** Mantenha o pin do `nonguix` no commit
  de introdução dele `897c1a47…` ou depois, para que ambos os canais autentiquem.

---

## O conjunto curado

O canal define **50 pacotes** em 5 classes. O índice completo (versão + última
mudança de cada um) fica no [README em inglês](README.md#-full-package-index-50-packages);
abaixo, a visão por categoria.

### ⬆️ À frente do Guix / nonguix (hashes reais baixados)

Pacotes com versão própria, à frente do que o Guix/nonguix entrega:

| Pacote | Versão | Fonte |
|---|---|---|
| **kitty** | 0.48.0 | tag git `v0.48.0` (+ 3 deps Go vendorizadas; `GOTOOLCHAIN=local`) |
| **tor** | 0.4.9.11 | tarball dist.torproject.org |
| **torbrowser** | 15.0.19 | build de fonte + ThinLTO (veja ressalvas) |
| **torbrowser-assets** | 15.0.19 | bundle oficial (fontes + torrc-defaults) |
| **openshot** | 3.5.1 | tag git `v3.5.1` |
| **google-chrome-stable** | 150.0.7871.181 | `.deb` do dl.google.com |
| **mullvad-vpn-desktop** | 2026.3 | `.deb` do cdn.mullvad.net (vendorizado) |
| **librewolf** | 153.0-3 | build de fonte (`make-librewolf-source` vendorizado) |
| **steam** | 1.0.0.87 | beta da Valve (contêiner nonguix) |
| **glances** | 4.5.5 | tag git `v4.5.5` (+ `pyinstrument` 5.1.2) |
| **lynis** | 3.1.7 | tag git `3.1.7` (plugins proprietários removidos) |
| **nmap** | 7.99 · **fping** 5.5 · **hydra** 9.7 | ferramentas de segurança à frente do Guix |

### 🄟 Binário pré-compilado

- **ungoogled-chromium-bin** `150.0.7871.128-1` — build portátil oficial para
  Linux x86_64 (verificado por sha256, empacotado com o
  `chromium-binary-build-system` do nonguix). É o chromium recomendado no `PATH`.

### ✅ Re-exportados — já mais recentes no Guix/nonguix

Acompanham o Guix automaticamente:
`alacritty` 0.17.0 · `fish` 4.7.1 · `emacs` 30.2 · `emacs-pgtk` 30.2 ·
`mpv` 0.41.0 · `vlc` 3.0.23 · `keepassxc` 2.7.12 · `ueberzugpp` 2.9.10 · `lf` 41

### 🄕 Apps primeiros (first-party) da forja `git.securityops.co/cristiancmoises`

Cada app vive no próprio repositório na forja. Para o canal ser
**autocontido** (compila sem acesso à rede), as fontes/artefatos são
**vendorizados** em `securityops/packages/sources/` e referenciados com
`local-file`:

| Pacote | Versão | O quê |
|---|---|---|
| **evelin-bin** | 4.2.0 | transporte pós-quântico (7 binários estáticos musl) |
| **btp** | 0.7 | Rust; binários patchelf'd (`btpctl`, `btpd`) |
| **mirim** | 1.1.0 | cofre pós-quântico + assinatura ML-DSA-87 (binários pré-compilados) |
| **torando-gui** | 1.3.4 | daemon de controle Tor + GUI GTK4; serviço Shepherd |
| **vaptvupt** (+`-gui`) | 5.2.1 | compressor de backup pós-quântico (ML-KEM-768/FIPS 203) |
| **turborec** | 3.6.0 | gravador de tela/áudio; streaming ao vivo, webcam PiP |
| **esquema** | 0.2.0 | runtime de contêiner rootless nativo em Guile |
| **moneyprinterturbo** | 1.3.2 | gerador de vídeos curtos por IA (vendorizado; fontes proprietárias removidas) |

### ⚠️ Re-exportado — existe upstream mais novo, mas o bump é impraticável aqui

- **ungoogled-chromium** (fonte) `147.0.7727.137-1` — é a versão do guix fixado.
  O **147 compila normalmente sob Tor**: a fonte vem como **substituto**
  (`.tar.zst`) do `bordeaux.guix.gnu.org`, que é alcançável via Tor (verificado em
  2026-07-23: `guix build -S ungoogled-chromium` → *0 construídos, 1,1 GB
  baixados*). O que é **impossível sob Tor** é **subir para uma versão mais nova**
  de fonte: o tarball-base "-lite" do Chromium novo só existe no GCS do Google
  (bloqueia 403 todo nó de saída Tor) e ainda não tem substituto. Para um motor
  **atual**, use o `ungoogled-chromium-bin` (150) acima.

---

## Serviços

Dois tipos de serviço **GNU Shepherd** nativos para `guix system reconfigure`
(as units systemd dos pacotes upstream são inertes no Guix System):

| Tipo de serviço | Módulo | Configuração |
|---|---|---|
| `torando-gui-service-type` | `(securityops services torando)` | `torando-gui-configuration`: `package`, `host` (padrão `127.0.0.1`), `port` (`8088`), `config-file`, `extra-options`, `seed-config` |
| `esquema-service-type` | `(esquema esquema-service)` — do pacote `esquema` | `esquema-configuration` (posicional): `name`, `rootfs`, `command`, `scheme-dir` |

**torando-gui** roda o daemon de controle do Tor (`torando-guid`) como root sob
o Shepherd (programa netfilter, fixa o `resolv.conf`, gerencia o `torrc`) e serve
a UI em `http://127.0.0.1:8088/`. Exemplo em `(operating-system …)`:

```scheme
(use-modules (securityops services torando))

(operating-system
  ;; …
  (services
   (cons* (service torando-gui-service-type)        ; daemon em 127.0.0.1:8088
          (service tor-service-type)                ; o próprio Tor
          %desktop-services)))
```

`guix system reconfigure`, depois `herd start torando-gui` (ou reinicie).

**esquema** supervisiona um contêiner rootless declarativo como serviço
Shepherd (todos os namespaces + seccomp + descarte total de capabilities). Veja
a seção *Esquema* no [README em inglês](README.md#esquema--rootless-guile-native-container-runtime).

---

## Consumindo o canal em `/etc/config.scm` e `home.scm`

Um `kitty` / `tor` / `torbrowser` / `google-chrome-stable` "pelado", escrito
contra `(gnu packages …)` / `(nongnu packages …)`, resolve para o pacote
*próprio do guix* (mais antigo), **não** para o deste canal — as ligações de
módulo são resolvidas pelo módulo que você importa, enquanto o
`guix install <nome>` é que escolhe a maior versão pelo nome. Então, para rodar
as versões atualizadas de forma declarativa, importe o módulo do canal com um
prefixo e use o símbolo prefixado:

```scheme
;; em (use-modules …)
((securityops packages terminals) #:prefix so:)   ; so:kitty
((securityops packages tor)       #:prefix so:)   ; so:tor, so:torbrowser
((securityops packages browsers)  #:prefix so:)   ; so:google-chrome-stable, so:ungoogled-chromium-bin
((securityops packages vpn)       #:prefix so:)   ; so:mullvad-vpn-desktop
((securityops packages video)     #:prefix so:)   ; so:openshot
((securityops packages games)     #:prefix so:)   ; so:steam
((securityops packages monitoring) #:prefix so:)  ; so:glances

;; …e na lista de pacotes use so:kitty, so:tor, so:torbrowser, …
;; e, para o daemon, sobrescreva o campo do serviço:
(service mullvad-daemon-service-type
         (mullvad-daemon-configuration
          (mullvad-vpn-desktop so:mullvad-vpn-desktop)))
```

Para aplicar após editar o canal: `guix pull` (pega o novo commit do
`securityops`), depois `guix system reconfigure /etc/config.scm` e
`guix home reconfigure ~/.config/guix/home.scm` — ou pule o pull e passe
`-L ~/securityops-channel` ao reconfigure para usar a árvore de trabalho
diretamente.

---

## Ressalvas importantes (leia antes de confiar em um build)

- **Tor Browser (build de fonte).** O `torbrowser` herda o pacote do guix e
  sobrescreve `version` + `source` **e** as duas constantes de versão que o
  `make-torbrowser` do guix embute a partir do próprio `%torbrowser-version`
  (15.0.14): a receita reescreve `--with-base-browser-version` → `15.0.19` e
  `MOZ_BUILD_DATE` → o BuildID oficial `20260720080000`, para que o "Sobre"
  mostre **15.0.19** (sem isso, ele mostraria 15.0.14 sobre um motor 15.0.19).
  As fontes/torrc-defaults ainda vêm dos assets 15.0.14 do guix (idênticos numa
  versão de correção).
- **Compilar pacotes classe Firefox (librewolf/torbrowser) em máquina com pouca
  RAM.** O crate rust final (`gkrust`) é LTO de programa inteiro (~14 GiB num
  único `rustc`), então numa máquina de 15 GiB ele é morto por OOM em qualquer
  `-j`. A solução é **swap**: um swapfile de 24 GiB deixa o build de LTO completo
  terminar; então `guix build --cores=4 librewolf` conclui e o navegador roda.
- **ungoogled-chromium — o 147 de fonte compila sob Tor; só a versão *nova* é
  bloqueada.** A fonte do `ungoogled-chromium` 147 (do guix fixado) chega como
  **substituto** (`.tar.zst`) do `bordeaux`, alcançável via Tor — então o build
  de fonte do 147 funciona. O que trava é **subir para uma versão mais nova**: o
  tarball-base "-lite" do Chromium novo só existe no GCS do Google (bloqueia 403
  todo nó de saída Tor) e ainda não tem substituto. Por isso, para um motor
  atual, o canal entrega o binário oficial pré-compilado `ungoogled-chromium-bin`
  (150).
- **Mullvad (vendorizado, apenas x86_64).** Fixado na versão estável publicada;
  vendorizado porque as fases de build embutem `version` no passo de descompactar
  o `.deb`.

A lista completa de ressalvas está no
[README em inglês](README.md#caveats-read-before-relying-on-a-build).

---

## Mantendo os pacotes atualizados — `./update-channel`

Um comando confere cada pacote do canal contra o upstream e aplica as
atualizações que o Guix consegue fazer com segurança:

```sh
./update-channel                       # confere: atual vs mais recente de cada pacote
./update-channel update --build --commit   # aplica os updates via guix-refresh, verifica o build, assina o commit
```

- **Automático** (via `guix refresh -u` — reescreve `version` + `sha256` real):
  os pacotes com base em github/gnu/pypi (`openshot`, `tor`, `glances`, …).
- **Reportado, aplique deliberadamente:** builds de fonte (`torbrowser`,
  `librewolf` — auto-bump dispara compilações de horas) e pacotes
  binários/vendorizados (`google-chrome-stable`, `steam`,
  `mullvad-vpn-desktop`, `ungoogled-chromium-bin`, os apps first-party). A
  ferramenta mostra a versão exata do upstream e o arquivo a editar.

---

## Publicação e autenticação

O canal é publicado e **autenticado**. Todos clonam e fazem pull por **HTTPS**
a partir do `git.securityops.co` (ou dos espelhos Codeberg/GitHub); o push é
restrito ao mantenedor. Todo commit é **assinado com GPG** (ed25519
`0CFA 43B9 AA96 42EA AF2B  E983 C4C6 61C9 ECFB 46E8`); o `.guix-authorizations`
lista essa chave como único signatário autorizado, e a `(introduction …)` na
seção *Instalação* fixa o primeiro commit assinado — então o `guix pull` verifica
todo o histórico e recusa um commit adulterado ou não assinado. A chave pública
autorizada é publicada no ramo `keyring` do canal (o layout padrão do
`guix git authenticate`), que o `guix pull` busca automaticamente.

---

## Licença

Código do canal: **GPL-3.0-or-later** (veja [LICENSE](LICENSE)); `vpn.scm`
carrega os cabeçalhos de copyright do small-guix de onde foi vendorizado. Cada
programa empacotado mantém a própria licença upstream, declarada na sua
definição.

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
- **Atualização de 2026-07-25 (compilada, instalada e verificada nos
  perfis):** `fish` 4.8.1, `kitty` 0.48.1 (com
  `go-github-com-emmansun-base64` 0.10.0 e `go-github-com-ebitengine-purego`
  0.10.2), `google-chrome-stable` 150.0.7871.186, `ungoogled-chromium-bin`
  150.0.7871.186-1, `evelin-bin` 4.3.0, `turborec` 3.7.0,
  `moneyprinterturbo` 1.3.3, `mtr` 0.96, `sdb` 2.4.8, `radare2` 6.1.8 e
  `rizin` 0.9.1. Todas as compilações passaram; o Fish também passou 197/197
  testes de integração e 272 testes Cargo. O perfil Home contém Fish, Kitty,
  Chrome, Chromium e MoneyPrinterTurbo; o perfil de usuário contém Evelin,
  TurboRecorder, MTR, SDB, Radare2 e Rizin.
- **Atualização abrangente de 2026-08-09 (auditoria e validação autoritativas e
  ativação dos perfis Home e direto de usuário concluída):** `kitty` 0.48.2,
  `glances` 4.5.6
  (dependência privada `pyinstrument` 5.1.3), `google-chrome-stable`
  151.0.7922.108, `ungoogled-chromium-bin` 151.0.7922.108-1, `librewolf`
  153.0.3-1 (pin l10n `6795ea14`), `sdb` 2.5.0, `radare2` 6.2.0 e `lf` 42
  (tag upstream `r42`; sete módulos Go privados: `uax29/v2` 2.7.0,
  `displaywidth` 0.11.0, `tcell/v3` 3.4.1, `fsnotify` 1.10.1, `x/sys` 0.47.0,
  `x/term` 0.45.0 e `x/text` 0.40.0). Kitty, Glances, SDB, Radare2 e lf
  passaram as compilações exatas e seus testes rápidos/suítes; a montagem
  completa da fonte Firefox/overlay/l10n e o `mach configure` do LibreWolf
  passaram após corrigir o matcher do Makefile e atualizar privadamente
  `rust-cbindgen` para 0.29.4 e `nss-rapid` para 3.126. O build LTO exato passou
  e `librewolf --version` reporta `Mozilla LibreWolf 153.0.3-1`. Chrome e
  Chromium também passaram os builds exatos e ambos reportam 151.0.7922.108 em
  runtime. O perfil Home agora contém Fish 4.8.1, Kitty 0.48.2, Chrome
  151.0.7922.108, ungoogled Chromium 151.0.7922.108, LibreWolf 153.0.3-1, lf 42
  e Tor Browser 15.0.19 (Firefox ESR 140.13.0;
  `BASE_BROWSER_VERSION = 15.0.19`). O perfil direto de usuário contém Fish
  4.8.1, LibreWolf 153.0.3-1, SDB 2.5.0, Radare2 6.2.0 e Glances 4.5.6/PsUtil
  7.2.2. A auditoria release a release de
  todas as definições confirmou que os demais releases estão atuais, salvo o
  fallback documentado do ungoogled Chromium 147 compilado de fonte (o motor
  atual 151 é fornecido pelo `-bin`), inclusive todos os apps first-party; a ressalva dos pins privados de l10n
  15.0.14 do Tor Browser está documentada abaixo.
- **Mantenedor:** Cristian Cezar Moisés `<ethicalhacker@riseup.net>`
- **Casa:** [`https://git.securityops.com.br/cristiancmoises/securityops-channel`](https://git.securityops.com.br/cristiancmoises/securityops-channel) (oficial) · espelhos: [Codeberg](https://codeberg.org/berkeley/securityops-channel) · [GitHub](https://github.com/cristiancmoises/securityops-channel)
- **Assinatura:** todo commit é assinado com GPG (ed25519 `0CFA 43B9 … ECFB 46E8`) e o canal é autenticado (veja [Publicação e autenticação](#publicação-e-autenticação))

> A lista completa de pacotes (índice de 51 pacotes), com versões e a última
> mudança de cada um, está no [README em inglês](README.md#-full-package-index-51-packages).
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
 (url "https://git.securityops.com.br/cristiancmoises/securityops-channel")
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
guix install kitty fish tor torbrowser openshot glances librewolf \
  google-chrome-stable \
  ungoogled-chromium-bin mullvad-vpn-desktop lf mtr sdb radare2 rizin
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
git clone https://git.securityops.com.br/cristiancmoises/securityops-channel   # oficial
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

O canal define **51 pacotes** em 5 classes. O índice completo (versão + última
mudança de cada um) fica no [README em inglês](README.md#-full-package-index-51-packages);
abaixo, a visão por categoria.

### ⬆️ À frente do Guix / nonguix (hashes reais baixados)

Pacotes com versão própria, à frente do que o Guix/nonguix entrega:

| Pacote | Versão | Fonte |
|---|---|---|
| **kitty** | 0.48.2 | tag git `v0.48.2` (+ 3 deps Go empacotadas; `GOTOOLCHAIN=local`); build/runtime aprovados |
| **fish** | 4.8.1 | fonte oficial + conjunto de crates offline correspondente ao Cargo.lock; 197/197 testes de integração e 272 testes Cargo |
| **tor** | 0.4.9.11 | tarball dist.torproject.org |
| **torbrowser** | 15.0.19 | motor/branding atuais; pins privados de l10n ainda no 15.0.14 (veja ressalvas) |
| **torbrowser-assets** | 15.0.19 | bundle oficial independente; fontes/torrc são byte a byte iguais aos arquivos herdados 15.0.14 |
| **openshot** | 3.5.1 | tag git `v3.5.1` |
| **google-chrome-stable** | 151.0.7922.108 | `.deb` do dl.google.com; build/runtime aprovados |
| **mullvad-vpn-desktop** | 2026.3 | `.deb` do cdn.mullvad.net (vendorizado) |
| **librewolf** | 153.0.3-1 | Firefox 153.0.3 + overlay/l10n `6795ea14`; cbindgen 0.29.4/NSS 3.126 privados; build LTO/runtime aprovados |
| **steam** | 1.0.0.87 | estável da Valve (contêiner nonguix) |
| **glances** | 4.5.6 | corrige cinco CVEs (68520, 68519, 68518, 62982, 68517); `pyinstrument` privado 5.1.3; build/métricas ao vivo aprovados |
| **lynis** | 3.1.7 | tag git `3.1.7` (plugins proprietários removidos) |
| **nmap** | 7.99 · **fping** 5.5 · **hydra** 9.7 · **mtr** 0.96 | ferramentas de rede/segurança à frente do Guix |
| **sdb** | 2.5.0 | dependência offline atual do Radare2; build/runtime aprovados |
| **radare2** | 6.2.0 | Zydis/Zycore do sistema + `sdb` 2.5.0 do canal; build/runtime aprovados |
| **rizin** | 0.9.1 | flags Meson/dependências de sistema atualizadas; suíte completa aprovada |
| **lf** | 42 | tag `r42`; à frente do Guix 41; grafo go.mod privado exato com 7 módulos; build e suítes completas aprovados |

### 🄟 Binário pré-compilado

- **ungoogled-chromium-bin** `151.0.7922.108-1` — release PortableLinux x86_64
  oficial atual, fixado pelo hash real baixado e empacotado com o
  `chromium-binary-build-system` do nonguix. O build passou,
  `chromium --version` reporta `Chromium 151.0.7922.108` e esse release está
  ativo no perfil Home como a versão Chromium atual recomendada.

### ✅ Re-exportados — já mais recentes no Guix/nonguix

Acompanham o Guix automaticamente:
`alacritty` 0.17.0 · `emacs` 30.2 · `emacs-pgtk` 30.2 · `mpv` 0.41.0 ·
`vlc` 3.0.23 · `keepassxc` 2.7.12 · `ueberzugpp` 2.9.10

### 🄕 Apps SecurityOps / first-party

Os campos `home-page` apontam para o projeto público ativo: Evelin e BTP usam
os projetos canônicos no Forgejo;
[Mirim](https://codeberg.org/berkeley/mirim),
[Torando](https://codeberg.org/berkeley/torando-gui),
[VaptVupt](https://codeberg.org/berkeley/vaptvupt) (CLI e GUI),
[TurboRecorder](https://codeberg.org/berkeley/turborec) e
[Esquema](https://codeberg.org/berkeley/esquema) usam os espelhos `berkeley` no
Codeberg. O canal continua canônico em `git.securityops.com.br` e espelhado no
Codeberg/GitHub. Para o build ser **autocontido**, as fontes/artefatos continuam
**vendorizados** em `securityops/packages/sources/` e referenciados com
`local-file`:

| Pacote | Versão | O quê |
|---|---|---|
| **evelin-bin** | 4.3.0 | transporte pós-quântico (7 binários estáticos musl); cliente silencioso por padrão e cópia no estilo scp, sem mudanças nos formatos de protocolo/chaves/tickets |
| **btp** | 0.7 | Rust; binários patchelf'd (`btpctl`, `btpd`) |
| **mirim** | 1.1.0 | cofre pós-quântico + assinatura ML-DSA-87 (binários pré-compilados) |
| **torando-gui** | 1.3.4 | daemon de controle Tor + GUI GTK4; serviço Shepherd |
| **vaptvupt** (+`-gui`) | 5.2.1 | compressor de backup pós-quântico (ML-KEM-768/FIPS 203) |
| **turborec** | 3.7.0 | gravador de tela/áudio; padrões automáticos, validação de dispositivos/encoders, fallback Pulse no Linux e correções multiplataforma |
| **esquema** | 0.2.0 | runtime de contêiner rootless nativo em Guile |
| **moneyprinterturbo** | 1.3.3 | gerador de vídeos curtos por IA; prévia de voz, modos de BGM, velocidade/transições, recuperação e avisos de atualização (mesma política de vendorização/poda de fontes) |

### ⚠️ Re-exportado — existe upstream mais novo, mas o bump é impraticável aqui

- **ungoogled-chromium** (fonte) `147.0.7727.137-1` — é a versão do guix fixado.
  O **147 compila normalmente sob Tor**: a fonte vem como **substituto**
  (`.tar.zst`) do `bordeaux.guix.gnu.org`, que é alcançável via Tor (verificado em
  2026-07-23: `guix build -S ungoogled-chromium` → *0 construídos, 1,1 GB
  baixados*). O que é **impossível sob Tor** é **subir para uma versão mais nova**
  de fonte: o tarball-base "-lite" do Chromium novo só existe no GCS do Google
  (bloqueia 403 todo nó de saída Tor) e ainda não tem substituto. Para um motor
  **atual**, use o `ungoogled-chromium-bin` `151.0.7922.108-1` acima; o build e
  o runtime estão validados, e esse release está ativo no perfil Home.

> A auditoria autoritativa de 2026-08-09 cobriu todas as definições do canal,
> inclusive dependências privadas e releases first-party. Todos os pacotes fora
> da lista de atualização estão atuais, salvo a exceção documentada do Chromium
> de fonte 147, inclusive Tor 0.4.9.11, Tor Browser
> 15.0.19 e Steam 1.0.0.87 estável. A auditoria completa e a distinção entre
> o estado do canal e dos perfis ativos estão em [AUDIT.md](AUDIT.md).

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

Um pacote atualizado "pelado", como `kitty`, `fish`, `radare2` ou
`google-chrome-stable`, escrito contra `(gnu packages …)` / `(nongnu packages
…)`, resolve para o pacote *próprio do guix* (mais antigo), **não** para o deste
canal — as ligações de módulo são resolvidas pelo módulo que você importa,
enquanto `guix install <nome>` escolhe a maior versão pelo nome. Para rodar as
versões atualizadas de forma declarativa, importe o módulo do canal com um
prefixo e use o símbolo prefixado:

```scheme
;; em (use-modules …)
((securityops packages terminals) #:prefix so:)   ; so:kitty
((securityops packages shells)    #:prefix so:)   ; so:fish
((securityops packages tor)       #:prefix so:)   ; so:tor, so:torbrowser
((securityops packages browsers)  #:prefix so:)   ; so:google-chrome-stable, so:ungoogled-chromium-bin
((securityops packages utils)     #:prefix so:)   ; so:lf 42 (tag r42)
((securityops packages security)  #:prefix so:)   ; so:mtr, so:sdb, so:radare2, so:rizin
((securityops packages vpn)       #:prefix so:)   ; so:mullvad-vpn-desktop
((securityops packages video)     #:prefix so:)   ; so:openshot
((securityops packages games)     #:prefix so:)   ; so:steam
((securityops packages monitoring) #:prefix so:)  ; so:glances

;; …e na lista de pacotes use so:kitty, so:fish, so:radare2, …
;; e, para o daemon, sobrescreva o campo do serviço:
(service mullvad-daemon-service-type
         (mullvad-daemon-configuration
          (mullvad-vpn-desktop so:mullvad-vpn-desktop)))
```

O Pyinstrument do Glances e os sete módulos do grafo go.mod exato do lf são
definições privadas de build, não exportações públicas. Portanto o lf continua
sendo um único pacote e o índice público permanece com 51 pacotes.

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
  Assim, o motor, a versão base exibida e o `MOZ_BUILD_DATE` são 15.0.19. As
  fontes e o `torrc-defaults` herdados ainda vêm do pacote privado 15.0.14 do
  Guix, mas uma comparação byte a byte confirmou que os 147 arquivos de fonte e
  o `torrc-defaults` são idênticos ao bundle oficial 15.0.19; esses assets são
  equivalentes. **Somente a localização está conhecidamente defasada:** os pins
  privados de l10n continuam no 15.0.14, embora o 15.0.19 tenha mudado a revisão
  base-browser de `6749f7ce` para `38c3b4e6` e a tor-browser de `a2e92e2c` para
  `510b52a6`. O pacote independente `torbrowser-assets` 15.0.19 entrega o bundle
  público atual, mas não consegue atualizar as entradas privadas de l10n do
  pacote herdado.
- **LibreWolf 153.0.3-1 (build completo e runtime verificados).** Firefox
  153.0.3, o overlay LibreWolf 153.0.3-1 e a revisão l10n
  `6795ea14` são fixados juntos. O pacote herda a receita LibreWolf do Guix, mas
  sobrescreve a fonte do release, o `MOZ_BUILD_DATE`/BuildID oficial
  `20260804215502` e duas dependências cuja versão mínima aumentou no Firefox
  153: `rust-cbindgen` privado 0.29.4 no lugar de 0.29.2 e `nss-rapid` privado
  3.126 no lugar de 3.124. Depois da correção do matcher do Makefile upstream,
  a montagem da fonte computada e o `mach configure` concluíram com sucesso. O
  build LTO completo também passou. Sua saída exata sem grafts é
  `/gnu/store/acyszcmi1h01qb4258ribxlx1fa86j88-librewolf-153.0.3-1`; o runtime
  reporta `Mozilla LibreWolf 153.0.3-1` e BuildID `20260804215502` em
  `application.ini` e `platform.ini`. Variantes com grafts desse build estão
  ativas tanto no perfil Home quanto no perfil direto de usuário e reportam a
  mesma versão e o mesmo BuildID.
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
  atual, o canal define o binário oficial pré-compilado
  `ungoogled-chromium-bin` `151.0.7922.108-1`. Seu hash real está fixado; o
  build passou, `chromium --version` reporta `Chromium 151.0.7922.108` e esse
  release está ativo no perfil Home.
- **Mullvad (vendorizado, apenas x86_64).** Fixado na versão estável publicada;
  vendorizado porque as fases de build embutem `version` no passo de descompactar
  o `.deb`.

A lista completa de ressalvas está no
[README em inglês](README.md#caveats-read-before-relying-on-a-build).

---

## Mantendo os pacotes atualizados — `./update-channel`

Um comando relata as versões que os updaters conseguem enxergar para o
subconjunto registrado e pode aplicar as alterações de receita que o Guix
suporta. É um auxiliar de conveniência, não substitui a auditoria release a
release dos 51 pacotes públicos:

```sh
./update-channel                       # relata versão atual vs candidatas visíveis
./update-channel update --build --commit   # aplica alterações suportadas, compila e assina
```

Uma falha ao consultar o upstream ou a versão atual é contada como
`unknown/failed` e faz `check` terminar com código diferente de zero; assim,
uma auditoria de rede incompleta não aparece como aprovada. Como o Esquema não
tem tags públicas de release, seu checker lê o `ESQUEMA_VERSION_STRING`
autoritativo diretamente do cabeçalho upstream.

- **Automático onde suportado** (via `guix refresh -u` — reescreve `version` +
  `sha256` real): pacotes com base em github/gnu/pypi (`openshot`, `tor`,
  `glances`, …). A opção `--build` valida as derivações geradas; só conferir não
  valida a compilação, a execução nem a ativação do perfil.
- **Reportado, aplique deliberadamente:** builds de fonte (`torbrowser`,
  `librewolf` — auto-bump dispara compilações de horas) e pacotes
  binários/vendorizados (`google-chrome-stable`, `steam`,
  `mullvad-vpn-desktop`, `ungoogled-chromium-bin`, os apps first-party). A
  ferramenta mostra a candidata do upstream e o arquivo a editar, mas ainda é
  preciso inspecionar os assets e validar à parte: candidatos e assets binários
  podem aparecer em momentos diferentes, e a atualização automática não prova
  build, runtime nem ativação do perfil.

---

## Publicação e autenticação

O canal é publicado e **autenticado**. Todos clonam e fazem pull por **HTTPS**
a partir do `git.securityops.com.br` (ou dos espelhos Codeberg/GitHub); o push é
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

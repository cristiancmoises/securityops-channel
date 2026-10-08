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
| Validação | [Pacotes, versões e verificações](PACKAGES.md); a ativação do sistema requer reconfiguração separada |
| Autenticação | Commits assinados e introdução do canal fixada |

## Documentação

| Guia | Conteúdo |
|---|---|
| [Índice de pacotes](PACKAGES.md) | Pacotes por finalidade, versões verificadas e limites dos testes |
| [Eletrônica](docs/usage.md#electronics) | Simulação com ngspice e toolchains do Arduino IDE |
| [Acesso remoto](docs/usage.md#remote-desktop) | Cliente RustDesk e servidores de rendezvous/relay próprios |
| [Monitoramento](docs/usage.md#monitoring) | Servidor Zabbix, coletores, interface web, JMX e relatórios PDF |
| [Relatórios XBRL](docs/usage.md#structured-reporting) | CLI/biblioteca Arelle, validação offline e limites dos testes gráficos |
| [Identidade e esquemas oficiais](docs/usage.md#identity-and-official-schema-data) | DigiDoc4, eID belga, bibliotecas de assinatura e formatos do eSocial |
| [Documentos fiscais eletrônicos](docs/usage.md#electronic-invoicing) | KoSIT Validator e regras XRechnung fixadas para uso offline |
| [Lacuna Web PKI](docs/webpki.pt-BR.md) | Host nativo, manifests dos navegadores e configuração do Guix Home |
| [AutoFirma](docs/usage.md#autofirma) | Pacote Linux oficial, comandos de assinatura e limites da integração com navegadores |
| [Validação de setembro](docs/refresh-2026-09-17.pt-BR.md) | Histórico das verificações e limitações em 17/09/2026 |
| [Referência de uso](docs/usage.md) | Serviços, Guix System e Guix Home |
| [Espelhos e autenticação](docs/channel-authentication-fix.md) | Oito canais autenticados, XLibre integrado e instalação para root |
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
   "af46f5cce66179f3e53f87c86ca2538c8fc63f98"
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

O TurboRec 3.10.4 está disponível em `(securityops packages apps)`:

```sh
guix package -e '(@ (securityops packages apps) turborec)'
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
guix package -e '(@ (securityops packages apps) turborec-nvidia-new-feature)'
# OU substitua o turborec genérico já instalado na mesma transação
guix package -r turborec -e '(@ (securityops packages apps) turborec-nvidia-new-feature)'
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

A introdução fixa o commit `af46f5cce66179f3e53f87c86ca2538c8fc63f98`
e a chave `0CFA 43B9 AA96 42EA AF2B E983 C4C6 61C9 ECFB 46E8`.
O Guix verifica as assinaturas ao atualizar o canal.

## Licença

Código do canal: GPL-3.0-or-later; consulte [LICENSE](LICENSE).
Cada programa mantém sua própria licença. Veja [LICENSING.pt-BR.md](LICENSING.pt-BR.md).

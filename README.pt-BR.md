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
| Definições de pacotes | Ferramentas de trabalho, assinaturas digitais, bibliotecas de identidade, esquemas oficiais e drivers XLibre |
| Dependências | GNU Guix e nonguix; o empacotamento XLibre está incluído |
| Validação | [Pacotes, versões e verificações](PACKAGES.md); a ativação do sistema requer reconfiguração separada |
| Autenticação | Commits assinados e introdução do canal fixada |

## Documentação

| Guia | Conteúdo |
|---|---|
| [Índice de pacotes](PACKAGES.md) | Pacotes por finalidade, versões verificadas e limites dos testes |
| [Relatórios XBRL](docs/usage.md#structured-reporting) | CLI/biblioteca Arelle, validação offline e limites dos testes gráficos |
| [Identidade e esquemas oficiais](docs/usage.md#identity-and-official-schema-data) | libdigidocpp e formatos separados de eventos e comunicação do eSocial |
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

# Canal SecurityOps

Um canal pessoal do GNU Guix para aplicativos de trabalho e ferramentas de segurança.

[English](README.md)

## Visão geral

| Item | Status |
|---|---|
| Definições de pacotes | 52 exportações públicas; reexportações dependem da versão-base do Guix |
| Dependências | GNU Guix, nonguix e guix-xlibre |
| Última atualização das receitas | 2026-09-06 |
| Validação | [Resultados e limitações](docs/refresh-2026-09-06.md); nem todas as atualizações foram totalmente validadas |
| Autenticação | Commits assinados e introdução do canal fixada |

## Documentação

| Guia | Conteúdo |
|---|---|
| [Índice de pacotes](PACKAGES.md) | Tabela única de versões, organizada por módulo |
| [Relatório da atualização](docs/refresh-2026-09-06.md) | Versões, validação e trabalho pendente |
| [Referência de uso](docs/usage.md) | Serviços, Guix System e Guix Home |
| [Histórico](CHANGELOG.md) | Notas de alterações anteriores |
| [Fluxo de atualização](etc/package-update-prompt.md) | Instruções reutilizáveis para atualizar com verificação |
| [Licenciamento](LICENSING.pt-BR.md) | Limites das licenças dos pacotes e projetos |

## Instalação

Adicione esta entrada à lista de canais em `channels.scm`.
O arquivo `.guix-channel` declara as dependências nonguix e guix-xlibre.

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

Instalar no perfil do usuário não substitui automaticamente um pacote do
Guix Home ou do sistema. Reconfigure o perfil responsável pelo pacote.
Use `(commit "...")` para fixar uma revisão reproduzível.

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

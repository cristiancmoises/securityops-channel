# Canal SecurityOps

Um canal pessoal do GNU Guix para aplicativos de trabalho e ferramentas de segurança.

> Uma nota rápida sobre IA: uso revisões assistidas por IA neste canal para
> encontrar problemas de segurança e de desempenho mais cedo, e automatizo boa
> parte do trabalho repetitivo com um DeepSeek harness personalizado — isso me
> poupa muitas horas. Se você prefere manter distância de qualquer coisa
> relacionada a IA, tudo bem: apenas saiba que talvez este não seja o projeto
> certo para você. Eu mantenho o canal no meu tempo livre, para uso próprio, e
> você também pode usar os pacotes à vontade. Uma pequena fazenda de builds
> minha ainda serve os binários diretamente.

[English](README.md)

## Visão geral

| Item | Status |
|---|---|
| Definições de pacotes | 77 entradas selecionadas, além dos drivers XLibre incluídos |
| Dependências | GNU Guix e nonguix; o empacotamento XLibre está incluído |
| Última atualização das receitas | 2026-09-17 |
| Validação | [Resultados e limitações](docs/refresh-2026-09-17.pt-BR.md); nem todas as atualizações foram totalmente validadas |
| Autenticação | Commits assinados e introdução do canal fixada |

## Documentação

| Guia | Conteúdo |
|---|---|
| [Índice de pacotes](PACKAGES.md) | Tabela única de versões, organizada por módulo |
| [Relatório da atualização](docs/refresh-2026-09-17.pt-BR.md) | Versões, validação e trabalho pendente |
| [Referência de uso](docs/usage.md) | Serviços, Guix System e Guix Home |
| [Espelhos e autenticação](docs/channel-authentication-fix.md) | Oito canais autenticados, XLibre integrado e instalação para root |
| [Histórico](CHANGELOG.md) | Notas de alterações anteriores |
| [Fluxo de atualização](etc/package-update-prompt.md) | Instruções reutilizáveis para atualizar com verificação |
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

# Pacotes do canal

Este índice organiza as receitas e reexportações por finalidade. As versões
são as verificadas nas datas indicadas, não uma promessa de
atualização automática. O canal fixa fontes e hashes quando mantém uma receita
própria; reexportações acompanham a revisão autenticada de seu canal de origem.

## Projetos SecurityOps e catálogo de pesquisa

Exportações conferidas em 08/10/2026 no módulo `(securityops packages applications)`.
Esta conferência valida o inventário; não é uma nova compilação de cada programa.

| Projeto | Nome no Guix | Versão no canal |
|---|---|---|
| Zupt | `zupt`, `zupt-gui` | 5.2.9 |
| Evelin | `evelin-bin` | 4.4.0 |
| TurboRec | `turborec`, `turborec-nvidia-new-feature` | 3.10.4 |
| Mirim | `mirim` | 1.1.1 |
| BTP | `btp` | 0.7 |

Pesquise os projetos em [toys.securityops.co](https://toys.securityops.co) e
selecione o canal `securityops`. A pesquisa por `evelin` encontra `evelin-bin`;
use o nome completo para instalar com `guix install evelin-bin`.

Cada instância do Toys mantém seu próprio catálogo. A página de canais informa
a revisão indexada; uma exportação correta no Git não garante atualização
imediata de [toys.whereis.social](https://toys.whereis.social) ou de outros
índices independentes. O teste `python3 tests/package-inventory.py` verifica
estes sete nomes, versões e ausência de duplicatas no inventário do canal.

### Compatibilidade do módulo

`applications` substitui o nome genérico `apps`, sem renomear os executáveis ou
pacotes. O módulo antigo permanece como reexportação dos mesmos bindings para
preservar manifests existentes. O teste
`guix repl -q -L . tests/securityops-tools-packages.scm` executa a descoberta
real do Guix e confirma que os dez pacotes originais aparecem uma única vez,
atribuídos ao novo módulo, mantendo os objetos e versões dos imports antigos.

O Toys não exclui módulos chamados `apps`. Esta migração organiza a interface
do canal; sem os logs de uma instância externa, não estabelece a causa de uma
indexação incompleta nem substitui a reindexação pelo responsável pelo serviço.

## Eletrônica, acesso remoto e monitoramento

Verificação de 07/10/2026. Instalar um pacote não ativa serviços nem configura
dispositivos e autenticação automaticamente.

| Categoria | Pacote | Versão | Módulo |
|---|---|---|---|
| Simulação de circuitos | `ngspice`, `libngspice` | 47 | `(securityops packages electronics)` |
| Desenvolvimento embarcado | `arduino-ide` | 2.3.10 | `(securityops packages arduino)` |
| Acesso remoto | `rustdesk` | 1.4.9 | `(securityops packages remote-desktop)` |
| Servidores de acesso remoto | `rustdesk-server`: `hbbs`, `hbbr`, `rustdesk-utils` | 1.1.16 | `(securityops packages remote-desktop)` |
| Coletores de monitoramento | `zabbix-agentd`, `zabbix-agent2` | 7.4.15 | `(securityops packages zabbix)` |
| Servidor e proxy de monitoramento | `zabbix-server`, `zabbix-proxy` | 7.4.15 | `(securityops packages zabbix)` |
| Integração Java/JMX | `zabbix-java-gateway` | 7.4.15 | `(securityops packages zabbix)` |
| Relatórios PDF agendados | `zabbix-web-service` | 7.4.15 | `(securityops packages zabbix)` |
| Comandos de monitoramento | `zabbix-get`, `zabbix-sender`, `zabbix-js` | 7.4.15 | `(securityops packages zabbix)` |

### Verificações e limites

| Componente | Verificação concluída | Limite |
|---|---|---|
| ngspice | Build nativo, API C instalada, divisor DC, resposta RC analítica e regressão upstream stop/resume | Netlists; sem editor de esquemas nem validação de todos os modelos |
| Arduino IDE | Editor sob Xvfb, Board Manager AVR 1.8.8 e compilação real de Blink para Uno | Sem upload, depuração ou hotplug em placa física |
| RustDesk | Build, caminhos de 13 objetos ELF, interface sob Xvfb e registro em `hbbs` privado com `hbbr` em execução | Sem comprovar sessão autenticada, tráfego pelo relay, captura ou entrada remota |
| Zabbix | Builds nativos, testes Go, consultas nos dois coletores, PostgreSQL, proxy SQLite e configuração PHP 8.4/8.5 | Sem deploy de produção ou fluxo completo de métricas pela interface web |
| Java Gateway | Protocolo Zabbix, versão e consulta JMX a um processo Java descartável | Não valida servidores JMX de terceiros nem autenticação/TLS de produção |
| Serviço web | Recusa de IP e URL inválidos; PDF real pelo Chrome e conferência do texto extraído | Dashboard de teste local; sem envio agendado de e-mail ou infraestrutura externa |

O Arduino IDE preserva Electron 30.1.2/Chromium 124 do upstream, fora de
suporte de segurança. A Theia desativa o sandbox do renderer; o container FHS
fornece compatibilidade, não isolamento de segurança. A extensão Cortex-Debug
inclui um módulo serial antigo cuja compatibilidade não foi validada. Não
trate este pacote como um runtime de segurança atualizado.

Arduino IDE e RustDesk usam as distribuições binárias oficiais; ngspice e
os componentes Zabbix são compilados de fonte. O Java Gateway preserva cinco
JARs de dependências binárias upstream e usa o OpenJDK 25.0.2 do Guix; isso não
afirma que cada dependência esteja na última versão global. O serviço de
relatórios usa o Chrome fixado pelo canal e deve executar sem privilégios.
Arduino IDE, o cliente RustDesk e o serviço PDF Zabbix estão limitados
a x86_64-linux. Consulte os [limites de licenciamento](LICENSING.pt-BR.md) e
os [comandos de uso](docs/usage.md#electronics).

## Segurança e monitoramento — Wazuh

Verificação de 08/10/2026 em x86_64-linux. Os cinco componentes têm receitas
próprias; o perfil do servidor contém quatro pacotes e o endpoint usa um perfil
separado. Instalar não cria estado, contas, certificados ou serviços.

| Função | Pacote | Versão | Módulo |
|---|---|---|---|
| Endpoint | `wazuh-agent` | 4.14.8 | `(securityops packages wazuh)` |
| Processamento e API | `wazuh-manager` | 4.14.8 | `(securityops packages wazuh)` |
| Indexação e consulta | `wazuh-indexer` | 4.14.8-1 | `(securityops packages wazuh-search)` |
| Interface web | `wazuh-dashboard` | 4.14.8-1 | `(securityops packages wazuh-search)` |
| Envio compatível de alertas | `wazuh-filebeat`, pacote `filebeat` | 7.10.2-2 | `(securityops packages wazuh-search)` |

### Verificações concluídas

| Área | Evidência | Limite |
|---|---|---|
| Núcleo e estado | Builds nativos, regras e listas CDB originais, dados MITRE, recusa real de estado/aliases inseguros e separação de privilégios preservada | OpenSCAP opcional indisponível; testes de metadata não substituem revisão de uma implantação |
| Fluxo integrado | Evento sintético do endpoint por transporte cifrado, alerta real, módulo Filebeat correspondente, indexer autenticado e rota Wazuh do dashboard para a API real | VM sem rede externa, contas/TLS privados e configuração compartilhada previamente sincronizada; sem reload de configuração alterada |
| Autenticação e TLS | Recusa de senha/JWT inválidos, CA não confiável e acesso sem credenciais; cliente do manager sem encaminhar redirecionamentos | Sem SSO, cluster, CA ou contas de produção |
| Perfil do servidor | Instalação real dos quatro outputs finais, 83 links corretos e inventários de comandos sem colisões | Endpoint e manager não devem ocupar o mesmo perfil |
| Inventário local | Syscollector nativo consultado pela API autenticada | Sem validar sua exportação direta ao indexer, feeds de vulnerabilidades, integrações cloud ou ações de resposta |

O núcleo C/C++ e CPython são compilados de fonte; bibliotecas upstream e
wheels Python permanecem binários fixados. Indexer, dashboard, Filebeat e os
runtimes Java/Node adaptam distribuições oficiais. As versões internas
compatíveis são CPython 3.10.22, Java 21.0.12.1 e Node 18.20.8; Python 3.10 e
Node 18 estão fora de suporte upstream. Filebeat 7.10.2 é o pin de compatibilidade,
não a última versão global. Não interprete o release recente do Wazuh como
garantia de atualização de todas as dependências ou certificação de produção.

O teste integrado conserva os diagnósticos do ambiente: o initrd da VM usou
fallback de inicialização e o caminho de inventário para o indexer não foi
provisionado. O sucesso refere-se às assertions e aos fluxos acima, não a logs
sem avisos. Antes de expor um servidor, configure estado, keystore, contas,
TLS, retenção e firewall e valide os recursos necessários nesse ambiente.
Consulte o [uso e os limites](docs/usage.md#wazuh), o
[release oficial](https://documentation.wazuh.com/current/release-notes/release-4-14-8.html)
e o [escopo de licenciamento](LICENSING.pt-BR.md).

## Atualizações verificadas em 07–08/10/2026

| Pacote | Versão do canal | Fonte |
|---|---|---|
| Google Chrome | 155.0.8059.39-1 | [Repositório oficial](https://dl.google.com/linux/chrome/deb/dists/stable/main/binary-amd64/Packages.gz) |
| Chromium portátil | 154.0.8037.97-1 | [Release oficial](https://github.com/ungoogled-software/ungoogled-chromium-portablelinux/releases/tag/154.0.8037.97-1) |
| Tor | 0.4.9.14 | [Distribuições oficiais](https://dist.torproject.org/) |
| sdb e radare2 | 2.5.8 e 6.2.4 | [sdb](https://github.com/radareorg/sdb/releases/tag/2.5.8), [radare2](https://github.com/radareorg/radare2/releases/tag/6.2.4) |
| libdigidocpp | 4.5.1 | [Release oficial](https://github.com/open-eid/libdigidocpp/releases/tag/v4.5.1) |
| DigiDoc4 | 4.11.1 | [Release oficial](https://github.com/open-eid/DigiDoc4-Client/releases/tag/v4.11.1) |
| Belgium eID | 5.1.31, fonte Linux | [Tag oficial](https://github.com/Fedict/eid-mw/tree/v5.1.31) |
| LibreWolf | 157.0-1 | [Distribuição Linux](https://librewolf.net/installation/linux/) |
| NVIDIA new-feature | 615.78.08 | [Distribuição oficial](https://download.nvidia.com/XFree86/Linux-x86_64/615.78.08/) |
| libevdev e Xwayland | 1.14.0 e 24.1.14 | [libevdev](https://www.freedesktop.org/software/libevdev/), [Xwayland](https://www.x.org/releases/individual/xserver/) |

Os navegadores passaram em renderização, JavaScript, canvas e verificação de
namespaces/seccomp em estado privado, com grafts padrão do Guix. Essa seleção
não significa que todo o catálogo esteja na última versão global: Chromium
compilado de fonte e MoneyPrinterTurbo ainda precisam de atualizações separadas
e validação. Pins de ABI e dependências não devem ser
trocados apenas por existir uma versão numericamente maior.

### LibreWolf e compatibilidade com AutoFirma

O LibreWolf reutiliza o motor compilado de fonte e autenticado do Guix,
preservando suas preferências de privacidade e sandbox. A adaptação do canal
mantém NSS 3.129/NSPR 4.40 e corrige as dependências do probe gráfico. JavaScript,
canvas, imagem renderizada, probe Mesa e processos Web Content com seccomp e
`NoNewPrivs` foram verificados em estado privado. A versão de fonte 157.0.1-1
não foi anunciada aqui como uma distribuição binária já disponível.

A seleção nativa STANDARD do NSS executou 21 suítes: 33.591 verificações passaram,
sem falhas, cores ou erros ASan/UBSan. O relatório preserva um resultado UNKNOWN
para `mozpkix_gtest`, listado pelo harness mas não produzido pelo Makefile GNU;
libpkix, pkits e mpi_tests não pertencem a essa seleção. A criação de um token
SQL e uma assinatura RSA por SunPKCS11, verificada independentemente, confirmaram
a integração do runtime Java do AutoFirma com esse NSS. Isso não testa cartões
reais nem o serviço de assinatura de um navegador.

## Verificação anterior — TurboRec 3.10.2

Atualização de 02/10/2026 em `(securityops packages apps)`, com fonte pública
fixada na [tag v3.10.2](https://codeberg.org/berkeley/turborec/src/tag/v3.10.2)
e hash verificado pelo Guix. O pacote instala os guias em inglês/pt-BR e
verifica os dois comandos instalados. A suíte upstream executou 186 testes,
com 13 skips condicionais ou de plataforma, sem falhas.

Não houve captura física de tela, áudio ou câmera nesta validação do canal.
O modo Auto pode recorrer à CPU; selecionar GPU explicitamente exige encoder
disponível no FFmpeg e driver compatível. O pacote não altera drivers.

## Relatórios estruturados

Verificação de 07/10/2026. O Arelle valida documentos XBRL e oferece módulos
Python para processamento de relatórios; não instala taxonomias nacionais por
associação.

| Pacote | Versão | Módulo | Interface |
|---|---|---|---|
| `arelle` | 2.46.0 | `(securityops packages reporting)` | `arelle`, `arelleCmdLine` e módulos Python |

### Verificações e limites

| Área | Verificação concluída | Limite |
|---|---|---|
| Núcleo | 5.424 testes upstream em 12 módulos selecionados | Não é a suíte completa de conformidade nem uma verificação de todos os plugins opcionais |
| Resultado instalado | CLI e biblioteca com XBRL válido/inválido, recusa de taxonomia remota em modo offline, plugin e cache local | Sem serviços externos ou aceitação regulatória |
| Interface gráfica | Carregamento do entry point e edição/leitura no TkTable nativo sob Xvfb | Evidência em x86_64, não um fluxo completo da interface gráfica |

As dependências efetivamente carregadas são lxml 6.1.3, libxml2 2.15.4,
libxslt 1.1.45 e OpenSSL 3.5.9. A verificação de metadados, faixas de versão,
imports e entry points executa de fato; suas cinco condições de falha têm
testes de regressão. As 33 declarações de dependência originais permanecem
inalteradas. O TkTable é compilado de fonte oficial fixada, com seu aviso de
copyright preservado, e
os wrappers não incluem os caminhos de pytest/setuptools usados no build.
As dependências privadas vcs-versioning 2.6.0 e filelock 4.0.12 passaram nos
testes nativos; hatchling 1.32.4 satisfaz o backend exigido pelo filelock.

O CLI pode terminar com código zero mesmo quando encontra erros de validação:
confira os níveis `error` e `critical` no relatório, não apenas o código de saída.
Fonte: [Arelle 2.46.0](https://github.com/Arelle/Arelle/releases/tag/2.46.0).
Consulte os [comandos e testes reproduzíveis](docs/usage.md#structured-reporting).

## Identidade, documentos fiscais e dados oficiais

Verificações de 02/10/2026 a 08/10/2026. Os pacotes abaixo passaram por build, testes no
resultado instalado e revisão independente. Adicionar o canal não os instala,
não ativa serviços e não importa certificados.

| Categoria | Pacote | Versão | Módulo |
|---|---|---|---|
| Identidade e assinaturas | `libdigidocpp` | 4.5.1 | `(securityops packages eid)` |
| Identidade e assinaturas | `digidoc4` | 4.11.1 | `(securityops packages digidoc4)` |
| Identidade e cartões | `eid-mw` | 5.1.31 | `(securityops packages belgian-eid)` |
| Identidade alemã e SDK local | `ausweisapp` | 2.6.0 | `(securityops packages ausweisapp)` |
| Biblioteca EAC e certificados CVC | `openpace` | 1.1.4 | `(securityops packages openpace)` |
| Dados de PKI | `icp-brasil-roots` | 2026.10.05, registro oficial | `(securityops packages icp-brasil)` |
| Dados de ACs | `icp-brasil-ca-data` | 2026.08.26, arquivo oficial | `(securityops packages icp-brasil-chain)` |
| Validação XML | `phive` | 12.2.0 | `(securityops packages phive)` |
| Documentos fiscais | `kosit-validator` | 1.6.3 | `(securityops packages einvoicing)` |
| Documentos fiscais | `xrechnung-validator-configuration` | 2026-08-31, XRechnung 3.0.2 / CEN 1.3.16 | `(securityops packages einvoicing)` |
| Dados governamentais | `esocial-schemas` | 1.3-20260701, S-1.3 / NT 06/2026 | `(securityops packages brazil-tax)` |
| Dados governamentais | `esocial-communication-schemas` | 1.6 | `(securityops packages brazil-tax)` |

### Verificações e limites

| Pacote | Testes concluídos | Limites |
|---|---|---|
| libdigidocpp | 24 testes TSL, 23 casos offline com 111 asserções e 25 verificações do resultado instalado | Cartões, SiVa, OCSP/TSA ao vivo e renovação online não testados; dez casos upstream ficaram fora da seleção offline |
| DigiDoc4 | Build nativo, assinatura ECC do bootstrap, rejeição real de cache adulterado, abertura gráfica de ASiC-E sem assinatura e recusa de documento inválido; imagens inspecionadas e bibliotecas carregadas conferidas | Sem cartões, assinatura qualificada, SiVa, OCSP/TSA ou renovação online de listas nacionais; não é a suíte Open-EID completa |
| Belgium eID | Build nativo com 15 testes upstream; funções e ciclo de vida PKCS#11 reais, slots vazios, visualizador GTK3 e versão 5.1.31 exibida e inspecionada | 27 skips upstream de hardware/interface preservados; sem leitor, cartão, PIN, assinatura, registro em navegador ou serviço PC/SC no host |
| AusweisApp | Build otimizado nativo, quatro testes QML, SDK/GUI instalados e 135 imagens comuns/de desktop; repetição isolada dos 370 testes Debug com bibliotecas carregadas conferidas | 35 skips condicionais originais preservados; o check Debug no builder teve duas falhas ambientais; sem cartão, PIN, autenticação real ou certificação universal da ABI Qt |
| OpenPACE | Build nativo e testes originais `eactest`/três cadeias CVC; ELF, bibliotecas carregadas, compilação de consumidor e ciclo de vida com busca CVCA em container offline | Sem cartão, PIN, serviço PC/SC ou interoperabilidade de hardware; busca de certificado de exemplo não comprova confiança nem validação de cadeia |
| Raízes ICP-Brasil | Oito arquivos originais e fingerprints conferidos; sete raízes com assinatura, validade e recusa de adulteração no OpenSSL; três bundles carregados em teste isolado | v7/Ed521 apenas como referência, fora dos bundles; sem cadeia intermediária completa, revogação online, assinatura de documentos ou importação global |
| Coleção de ACs ICP-Brasil | SHA-512 oficial do ZIP, 180 PEM originais byte a byte, fingerprints DER, restrições de AC e teste sem privilégios em container offline | Dados de referência, não confiança; sem validação de cadeia, validade atual ou revogação; v7/Ed521 separado e sem assinatura verificada |
| PHIVE Java | JARs, fontes, POMs e avisos originais conferidos; testes upstream selecionados de XSD, Schematron, VES/JAXB, repositório e resultados XML/JSON/HTML em container offline | Biblioteca, sem CLI; não inclui regras fiscais nacionais; políticas de recursos externos foram configuradas nos testes, não impostas globalmente |
| KoSIT e XRechnung | 105 verificações do resultado instalado: UBL/CII válidos e inválidos, etapas XSD/Schematron, argumentos e recusas de recursos externos | Validação offline; sem envio fiscal ou teste do modo daemon |
| Esquemas eSocial | 441 verificações; todos os 52 XSD de eventos e 15 XSD de comunicação compilados offline; arquivos originais preservados byte a byte | Validação estrutural, sem conferir assinaturas, regras de negócio ou aceitação pelo governo |

O libdigidocpp usa libxml2 2.15.4, libxslt 1.1.45 e OpenSSL 3.5.9, incluindo
as dependências transitivas relevantes. Os testes nativos herdados passaram;
o teste do resultado instalado confirma as bibliotecas efetivamente carregadas.
Os auxiliares de segurança são privados a estas receitas, não uma mudança
global no sistema.

O DigiDoc4 usa a mesma biblioteca de assinatura e a mesma ABI XML, inclusive no
libcdoc interno. O bootstrap público de configuração tem serial 212 e assinatura
ECC verificada; erros TLS continuam sendo rejeitados. A lista europeia de
24/09/2026, com próxima atualização em 17/03/2027, substitui os dados expirados
da receita anterior. Listas nacionais continuam usando o fluxo assinado de
atualização online; não há uma lista estoniana recente embutida. A primeira
validação de assinaturas pode exigir internet. Nenhum certificado é importado
para a confiança global do sistema.

O Belgium eID usa a última tag oficial de fonte Linux verificada, 5.1.31;
a edição 5.1.34 é uma distribuição Windows, não uma atualização desta receita.
A versão é gravada pelo mecanismo `.version` previsto pelo upstream, inclusive
no diálogo About. GTK3, os testes nativos e a licença LGPL-3.0-or-later são
preservados; OpenSSL 3.5.9 e libxml2 2.15.4 foram conferidos no processo instalado.
Adicionar o pacote não inicia PC/SC nem registra automaticamente seu provedor
PKCS#11 em aplicativos.

O AusweisApp 2.6.0 fornece o aplicativo Qt e o SDK local. Qtbase, SVG e QML
mantêm a família 6.9.2, com correções upstream fixadas; QML foi recompilado
contra os novos headers privados do SVG. Os testes verificam os caminhos das
bibliotecas realmente carregadas, não apenas seus números de versão. Essas
dependências são privadas à receita, sem atualização global do Qt.

O build otimizado passou seus quatro testes QML. O build Debug original rodou
370 testes e apresentou duas falhas ambientais; a repetição controlada de todos
os 370, com os mesmos executáveis e uma conexão restrita ao provedor de testes
oficial, passou. Os resultados internos preservam 35 skips condicionais upstream.
A interface instalada, o SDK local e o carregamento de 135 imagens comuns/de
desktop também foram verificados; a captura da interface foi inspecionada.
`Image.Ready` e dimensões positivas não provam fidelidade de imagens compostas.
O desktop estável pré-carrega um marcador beta invisível; seu fundo SVG embutido
é recusado pela proteção, embora ambos os arquivos originais estejam incluídos.
O marcador beta não está certificado como íntegro. Isso não cobre cartões,
PINs, autenticação de produção nem serviços externos reais.
O log detalhado dos fixtures QML mantém 86 avisos de conexão do logger, idênticos
ao baseline anterior: o runner não o inicializa antes dos modelos. O aplicativo
o inicializa antes do controller, e os avisos não aparecem nos logs SDK/desktop
verificados. CTest aprovado não equivale a fixtures sem avisos nem comprova as
atualizações de log/notificação ausentes desse ambiente de teste.

A opção SVG padrão usa `NoOption` em vez de tratar entradas como confiáveis.
O override explícito `QT_SVG_DEFAULT_OPTIONS` continua disponível upstream;
não se trata de uma política global inalterável. A receita não ativa PC/SC.
Fonte: [AusweisApp 2.6.0](https://github.com/Governikus/AusweisApp/releases/tag/2.6.0).
Consulte os [comandos e limites do AusweisApp](docs/usage.md#ausweisapp-desktop-and-local-sdk).

O OpenPACE fornece a biblioteca C `libeac.so.3`, headers, metadados `pkg-config`
e ferramentas CVC. O OpenSSL 3.5.9 é propagado para os programas consumidores;
um perfil contendo apenas OpenPACE e ferramentas genéricas compilou, vinculou
e executou a verificação instalada sem selecionar OpenSSL à parte. As fontes
originais do OpenPACE/OpenSSL e a fonte efetiva do OpenSSL com os patches do Guix
são preservadas, junto das permissões de ligação originais.

As raízes padrão CVC/X.509 ficam vazias e imutáveis. Os quatro certificados
originais de exemplo ficam separados, sem importação global; aplicações precisam
selecionar suas próprias raízes e políticas. O teste de busca usou uma cópia
privada de um exemplo, não uma identidade ou AC de produção. A receita não inclui
bindings de outras linguagens nem o aplicativo Autenticação.gov.
Fonte: [OpenPACE 1.1.4](https://github.com/frankmorgner/openpace/releases/tag/1.1.4).
Consulte os [comandos e limites do OpenPACE](docs/usage.md#openpace-native-eac-library).

As raízes ICP-Brasil preservam os arquivos públicos do ITI byte a byte e a
atribuição CC-BY-ND-3.0 do registro oficial. Os bundles utilizáveis separam cinco
raízes gerais para seleção de política de documentos (v4, v5, v6, v12 e v13),
TLS (v10) e assinatura de código (v11). A v7 usa Ed521, não suportado pelo
OpenSSL verificado: seu arquivo fica apenas em `reference-ed521`, sem alegação
de assinatura validada. Raízes expiradas ou revogadas não são incluídas.
Nenhum bundle é registrado como confiança do sistema. O pacote não substitui
a cadeia completa de ACs nem a consulta de revogação necessária ao aplicativo.
Fontes: [registro AC-Raiz do ITI](https://www.gov.br/iti/pt-br/assuntos/repositorio/repositorio-ac-raiz)
e [algoritmos/fingerprints no relatório WebTrust, apêndice A](https://www.gov.br/iti/pt-br/assuntos/comite-gestor/iti_2019_-_webtrust_for_ca_report_consolidado.pdf).
Consulte os [caminhos e testes reproduzíveis](docs/usage.md#icp-brasil-root-data).

O `icp-brasil-ca-data` é separado do pacote de raízes. Ele preserva os 180
certificados do arquivo «Cadeia Vigente» publicado pelo ITI em 26/08/2026,
inclusive os finais de linha originais. Há 179 arquivos de ACs RSA/Ed448 e
uma referência Ed521. O pacote instala somente dados e inventário em `share`;
não fornece um bundle combinado nem promove certificados intermediários a
âncoras de confiança. A coleção é uma fotografia datada, não uma garantia de
que cada certificado continue válido ou de que ela cubra todas as raízes do
registro mais recente. As aplicações precisam selecionar políticas, emissores
atuais e dados de revogação próprios.
Fonte: [arquivo oficial de ACs do ITI](https://www.gov.br/iti/pt-br/assuntos/repositorio/certificados-das-acs-da-icp-brasil-arquivo-unico-compactado).
Consulte a [coleção de ACs e seus testes](docs/usage.md#icp-brasil-ca-collection).

O KoSIT preserva os JARs oficiais, as licenças e os fontes correspondentes:
é um reempacotamento binário, não uma recompilação do projeto. Um adaptador
pequeno corrige os códigos de erro dos argumentos sem alterar os JARs. O
pacote de configuração inclui o conjunto oficial completo de regras e relatórios;
`xrechnung-validator` os seleciona automaticamente. O runtime Java fixado é
17.0.20.1+1; compilador e JDK não ficam no fechamento instalado.

Os dados do eSocial incluem os arquivos ZIP originais, os avisos de terceiros
e a atribuição exigida pela licença CC-BY-ND-3.0 do site oficial. Não são
licenciados como software livre. O suporte a CNPJ alfanumérico pertence aos
eventos S-1.3 desta edição; o envelope de comunicação 1.6 mantém as restrições
numéricas originais e exige validar o evento separadamente.

Fontes: [DigiDoc4 4.11.1](https://github.com/open-eid/DigiDoc4-Client/releases/tag/v4.11.1),
[libdigidocpp 4.5.1](https://github.com/open-eid/libdigidocpp/releases/tag/v4.5.1)
e [documentação técnica do eSocial](https://www.gov.br/esocial/pt-br/documentacao-tecnica),
[KoSIT 1.6.3](https://github.com/itplr-kosit/validator/releases/tag/v1.6.3)
e [configuração XRechnung](https://github.com/itplr-kosit/validator-configuration-xrechnung/releases/tag/v2026-08-31).
Consulte a [referência de uso](docs/usage.md#identity-and-official-schema-data)
e os [comandos de validação fiscal](docs/usage.md#electronic-invoicing) para
caminhos instalados, seleção explícita de receitas e testes reproduzíveis.

### PHIVE — validação XML em Java

O [PHIVE 12.2.0](https://github.com/phax/phive/releases/tag/phive-parent-pom-12.2.0)
reúne os oito módulos do framework e 42 dependências de execução, incluindo o
provedor JAXB de referência. Os 50 JARs permanecem separados e byte a byte
originais, com seus POMs, fontes e avisos. Saxon HE 12.10, JAXB 4.0.9 e o
runtime privado Temurin 17.0.20.1+1 são fixados para esta combinação.

| Saída | Conteúdo | Uso |
|---|---|---|
| `phive:out` | Bibliotecas, classpath, runtime e fontes/avisos | Integração em aplicações Java |
| `phive:tests` | Cinco bibliotecas auxiliares de teste | Verificação explícita; não é propagada para aplicações |

A receita adapta os artefatos publicados; não recompila o framework com Maven.
Foram executados 63 casos upstream selecionados, com fontes e asserções
inalteradas, incluindo sete exemplos VES originais. Os testes compilam apenas
esses casos e um auxiliar local com Java 17; não equivalem à suíte upstream
completa. As regras nacionais, taxonomias e conjuntos fiscais são pacotes
separados; exemplos VES não equivalem a regras fiscais atuais. Consulte os
[comandos e limites de uso](docs/usage.md#xml-validation-with-phive).

## Histórico — revisão de 01/10/2026

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
| AutoFirma | Build com grafts padrão; JAR idêntico ao oficial |
| Assinatura e CLI do AutoFirma | Sete testes PKCS12 e 18 verificações NSS, de ferramentas e de argumentos; assinaturas conferidas pelo OpenSSL |
| Runtime do AutoFirma | Dois testes de compilação e subprocessos passaram |
| Interface do AutoFirma | Janela e fontes verificadas em Xvfb; oito compartilhamentos inválidos rejeitados e caminhos com espaços aceitos |
| NSS 3.129 | 21 grupos concluídos; 33.591 testes passaram, nenhuma falha registrada e um resultado com status desconhecido |
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
certificados nem configura navegadores. O JAR oficial foi preservado byte a
byte; o build e os testes finais mantiveram os grafts padrão do Guix.
O lançador gráfico e as operações de CLI que usam NSS requerem namespaces
de usuário. O comando padrão `certutil` está incluído; cartões,
Wayland e integração completa com navegadores ainda não foram testados.
Consulte as [notas de uso](docs/usage.md#autofirma) para os requisitos.

### Instalação neste workstation

O perfil de usuário recebeu Glances 4.5.7, Kitty 0.49.2, Chrome
154.0.8037.92-1, Chromium portátil 154.0.8037.57-1, Docker CLI 29.8.2 e
Podman 6.1.3. Os demais pacotes e as gerações anteriores foram preservados.
O AutoFirma 1.9 também foi instalado no perfil de usuário: os 41 pacotes
anteriores foram mantidos, e o perfil passou a conter 42 pacotes. Os comandos
`autofirma`, `autofirmacl` e `certutil` estão disponíveis em `~/.guix-profile/bin`.

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
| `(securityops packages nvidia)` | `nvidia-driver-new-feature`, `nvidia-firmware-new-feature`, `nvidia-module-new-feature` | 615.78.08 | Fontes oficiais fixadas; helpers nonguix; módulo compilado para Linux-libre 7.2.8 |
| `(securityops packages nvidia)` | `nvda-new-feature` | 615.78.08 | União gráfica com o mesmo driver, firmware e caminhos ICD |
| `(securityops packages nvidia)` | `steam-nvidia-new-feature` | Bootstrap Steam 1.0.0.87 | Cliente do canal e stack 615.78.08; contêiner Steam completo não testado nesta revisão |
| `(securityops packages river)` | `river-xmonad-runtime` | 0.4.8 | Receita do canal |
| `(securityops packages river)` | `wayland-latest`, `wayland-protocols-latest` | 1.26.0, 1.49 | Receitas do canal |
| `(securityops packages river)` | `libevdev-latest`, `libinput-minimal-latest`, `libxkbcommon-latest` | 1.14.0, 1.32.0, 1.13.2 | Receitas do canal |
| `(securityops packages river)` | `foot-latest`, `fuzzel-latest`, `mako-latest`, `swaybg-latest` | 1.28.0, 1.15.0, 1.11.0, 1.2.2 | Receitas do canal |
| `(securityops packages river)` | `swaylock-latest`, `wlr-randr-latest` | 1.8.6, 0.5.0 | Receitas do canal |
| `(securityops packages river)` | `channel-river-input` | 0.5.1 | Receita do canal |
| `(securityops packages river)` | `xwayland-latest`, `wlroots-latest` | 24.1.14, 0.20.2 | Xwayland fixado no canal; wlroots herdado da revisão Guix |

`wlroots-latest` herda a versão do Guix selecionado; Xwayland tem fonte e hash
fixados no canal. Consulte `guix show` após cada `guix pull` para conferir as
versões efetivas. O driver NVIDIA não adiciona DLSS
5 ao Red Dead Redemption 2; a disponibilidade desse recurso depende do jogo,
da GPU e do suporte oficial da NVIDIA.

Driver, firmware, cinco módulos e união gráfica passaram em build nativo
x86_64, com versão, vermagic, ELF e caminhos ICD conferidos. As variantes
FFmpeg 9.0.2/8.1.3, wf-recorder 0.6.0 e TurboRec 3.10.4 usam o mesmo driver:
FATE, codificação/decodificação CPU H.264/AAC e loaders NVENC foram verificados.
O teste anterior com RTX 4060/615.71.09 não certifica o driver 615.78.08.
Esta revisão não carregou módulos, não ativou a GPU e não testou captura,
CUDA/NVENC/VAAPI em hardware. A arquitetura aarch64 teve hashes oficiais
conferidos, mas não execução nativa. A ABI exigida `libcrypto.so.1.1` mantém
OpenSSL 1.1.1w, fora de suporte público; não se afirma que todo o fechamento
proprietário esteja atualizado ou certificado em segurança.

## Aplicativos atualizados

| Módulo | Pacote | Versão verificada | Observação |
|---|---|---|---|
| `(securityops packages browsers)` | `google-chrome-stable` | 155.0.8059.39-1 | Receita binária do canal; renderização e sandbox verificados |
| `(securityops packages chromium)` | `ungoogled-chromium-bin` | 154.0.8037.97-1 | Build portátil oficial; renderização, driver e sandbox verificados |
| `(securityops packages browsers)` | `librewolf` | 157.0-1 | Motor nativo Guix com adaptação de NSS e probe gráfico; renderização e sandbox verificados |
| `(securityops packages tor)` | `tor` | 0.4.9.14 | Receita do canal; build e testes passaram |
| `(securityops packages shells)` | `fish` | 4.9.3 | Receita do canal; build passou |
| `(securityops packages monitoring)` | `glances` | 4.5.7 | Receita do canal |
| `(securityops packages video)` | `openshot` | 4.0.1 | Receita do canal; build passou |
| `(securityops packages video)` | `ffmpeg` | 9.0.2 | CPU/uso geral; fonte PGP verificada; build, FATE e H.264/AAC validados em x86_64-linux |
| `(securityops packages video)` | `ffmpeg-nvidia-new-feature` | 9.0.2 | Build/FATE, H.264/AAC CPU e loaders do driver 615.78.08 verificados; aceleração em hardware não testada nesta revisão |
| `(securityops packages video)` | `nv-codec-headers` | 13.1.15.0 | Build validado; SDK 13.1 exige driver 610 ou superior; caminhos ajustados pelo Nonguix |
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
dependentes disponíveis. A compilação do kernel e do módulo NVIDIA 615.78.08
para 7.2.8 foi validada; isso não significa que a geração do sistema já tenha
sido ativada ou que o driver carregado tenha mudado.

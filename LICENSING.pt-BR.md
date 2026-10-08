# Escopo de licenciamento

O código original do canal Guix Security Ops está sob GPL-3.0-or-later,
conforme `LICENSE`, salvo quando um arquivo declara termos diferentes. Em
especial, `vpn.scm` preserva os avisos upstream do small-guix de onde foi
vendorizado.

`securityops/packages/river.scm` adapta as receitas BSD-3-Clause do
xmonad-wayland. O aviso original está preservado em
[`LICENSES/xmonad-wayland-BSD3.txt`](LICENSES/xmonad-wayland-BSD3.txt).
Essa exceção se aplica ao código das receitas; River e suas dependências
mantêm as respectivas licenças upstream.
Os patches do River em `securityops/patches/` seguem a licença GPL-3.0-only
do River, conforme os avisos nos próprios arquivos.

Os testes de integração do River em `tests/` trazem avisos BSD-3-Clause; a exceção das
receitas não altera a licença GPL dos patches do River.

Uma definição de pacote Guix não relicencia o programa empacotado. Cada
programa mantém sua licença canônica upstream, registrada na definição e nos
avisos instalados. A receita pública seleciona uma opção pública
redistribuível; ela não coloca contrato comercial privado, chave de licença,
chave de assinatura ou direito de cliente no store do Guix.

O RPM do Web PKI da Lacuna declara MIT em seus metadados, mas não inclui um
texto de licença separado. O aplicativo .NET autossuficiente contém componentes
de terceiros cujos avisos individuais não foram auditados separadamente aqui.
O canal baixa o RPM com hash fixo e não o inclui nem o relicencia.

Arduino IDE e RustDesk preservam as licenças copyleft upstream e os avisos de
terceiros incluídos. As receitas adaptam binários oficiais, sem recompilar os
aplicativos. Arduino instala a licença e indicações de fonte; RustDesk inclui
checkouts recursivos correspondentes e avisos datados das mudanças de
empacotamento. Isso não comprova que os fontes correspondentes de todas as
dependências embutidas foram reunidos. Antes de distribuir substitutos binários,
confira e cumpra as exigências de disponibilidade de fonte e avisos, incluindo
dependências necessárias e instruções de build. Publicar receitas não certifica
automaticamente a conformidade da distribuição binária.

ngspice mantém as famílias de licenças upstream herdadas; Zabbix mantém AGPLv3.
O Java Gateway preserva cinco JARs de dependências upstream com as respectivas
licenças Apache, MIT, BSD e os termos duplos do Logback. São dependências
binárias; publicar a receita não certifica o cumprimento integral das exigências
de disponibilidade dos fontes. O serviço PDF usa o pacote Google Chrome,
licenciado separadamente, como dependência externa de execução.
Os novos testes seguem seus avisos individuais ou a licença padrão do canal,
não a exceção específica dos testes River.

O núcleo C/C++ do Wazuh e o interpretador CPython privado são compilados de
fonte, mas bibliotecas de dependências e wheels Python upstream continuam
binários fixados. Indexer, dashboard, Filebeat, Java e Node adaptam distribuições
binárias oficiais. Os pacotes preservam avisos originais e indicações de fonte,
inclusive os termos dos dados MITRE; os campos de licença resumem os termos
de vários componentes, não uma concessão única. O vínculo exato com os fontes
correspondentes de todos os componentes embutidos não foi estabelecido.
Antes de distribuir substitutos binários, confira e cumpra cada obrigação
aplicável de fonte, instruções de build e avisos. Publicar estas receitas não
autoriza nem certifica a distribuição dos binários resultantes.

O AutoFirma é distribuído sob GPL-2.0-or-later ou EUPL-1.1. O pacote
reutiliza a distribuição Linux oficial e preserva o JAR e os avisos de licença
dos componentes incluídos. Essas dependências mantêm suas próprias licenças;
a definição lista suas famílias de licenças, sem conceder novos direitos.
A compilação do AutoFirma a partir do código-fonte exigiria empacotar
separadamente suas dependências Maven e não está implementada nesta receita.
O runtime privado Eclipse Temurin Java 17 preserva a licença GPL-2.0 com a
exceção Classpath e todos os avisos legais dos componentes incluídos.

Vários projetos próprios e separados da Security Ops oferecem uma opção
pública copyleft e podem oferecer termos diferentes por contrato comercial
assinado separadamente. Nos repositórios locais inspecionados para esta
versão, esse modelo está documentado para Evelin, Evelin Cells, Esquema,
Zupt, seu codec de compressão embutido, libvuptsdk, Mirim e Cofre Soberano PQ. As
licenças públicas diferem: Zupt possui escopos AGPL e GPL, o codec embutido é GPL,
Mirim é somente AGPLv3 e os demais códigos citados geralmente são
AGPLv3-or-later.

Essa informação não concede licença comercial. A opção específica de cada
projeto existe somente por contrato escrito assinado pelo titular aplicável e
pelo licenciado. Um contrato não cobre outro projeto sem texto expresso.
Dependências, contribuições, GNU Guix, Linux, firmware, aplicativos e demais
componentes de terceiros mantêm suas próprias licenças.

BTP usa intencionalmente Apache-2.0 na implementação de referência e CC-BY-4.0
na especificação. Apache-2.0 já permite uso comercial e proprietário sujeito
a suas condições; este checkout não declara opção comercial separada para BTP.

Consultas para componentes próprios elegíveis: `sac@securityops.co`. Informe o
projeto e commit exatos. Este texto resume escopo e não constitui
aconselhamento jurídico.

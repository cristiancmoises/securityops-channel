# Escopo de licenciamento

O código original do canal Guix Security Ops está sob GPL-3.0-or-later,
conforme `LICENSE`, salvo quando um arquivo declara termos diferentes. Em
especial, `vpn.scm` preserva os avisos upstream do small-guix de onde foi
vendorizado.

Uma definição de pacote Guix não relicencia o programa empacotado. Cada
programa mantém sua licença canônica upstream, registrada na definição e nos
avisos instalados. A receita pública seleciona uma opção pública
redistribuível; ela não coloca contrato comercial privado, chave de licença,
chave de assinatura ou direito de cliente no store do Guix.

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

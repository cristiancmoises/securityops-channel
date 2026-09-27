# Lacuna Web PKI no Guix

[English](webpki.md)

O pacote `lacuna-webpki` 2.16.0 adapta o aplicativo nativo do RPM oficial da
Lacuna para `x86_64`. Ele fornece o host de mensagens nativas usado pela
extensão Web PKI; a extensão do navegador deve ser instalada separadamente
pela [página oficial](https://get.webpkiplugin.com/) em cada navegador usado.

A [página de instalação da Lacuna](https://get.webpkiplugin.com/) informa que
o suporte ao Linux foi descontinuado e que não haverá novas atualizações nem
suporte para esse sistema. O RPM não possui assinatura RPM. A receita Guix
fixa o download oficial pelo SHA-256
`409ceba44e5d0726d9a5efce05afb0dbb52de1278c56315ab4f5b3cc0db9e1e6`.

## Instalação e conexão com os navegadores

Depois de adicionar e atualizar o canal, inclua `lacuna-webpki` nos `packages`
do Guix Home e as entradas abaixo na lista de `services`. O exemplo completo
conecta Firefox, LibreWolf, Chromium, Google Chrome e Microsoft Edge:

```scheme
(use-modules (gnu home)
             (gnu home services)
             (gnu services)
             (guix gexp)
             ((securityops packages webpki) #:prefix so:))

(home-environment
 (packages (list so:lacuna-webpki))
 (services
  (list
   (simple-service
    'lacuna-webpki-native-messaging
    home-files-service-type
    `((".mozilla/native-messaging-hosts/com.lacunasoftware.webpki.json"
       ,(file-append so:lacuna-webpki
                     "/share/lacuna-webpki/native-messaging-hosts/firefox.json"))
      (".librewolf/native-messaging-hosts/com.lacunasoftware.webpki.json"
       ,(file-append so:lacuna-webpki
                     "/share/lacuna-webpki/native-messaging-hosts/firefox.json"))
      (".config/chromium/NativeMessagingHosts/com.lacunasoftware.webpki.json"
       ,(file-append so:lacuna-webpki
                     "/share/lacuna-webpki/native-messaging-hosts/chromium.json"))
      (".config/google-chrome/NativeMessagingHosts/com.lacunasoftware.webpki.json"
       ,(file-append so:lacuna-webpki
                     "/share/lacuna-webpki/native-messaging-hosts/chromium.json"))
      (".config/microsoft-edge/NativeMessagingHosts/com.lacunasoftware.webpki.json"
       ,(file-append so:lacuna-webpki
                     "/share/lacuna-webpki/native-messaging-hosts/edge.json")))))))
```

Ao incorporar o serviço à sua configuração Home, mantenha somente os
navegadores usados. Se já existir um manifest em um desses destinos, faça uma
cópia antes de executar `guix home reconfigure`: o Guix Home não o sobrescreve.
Depois da reconfiguração, reinicie o navegador correspondente.

O pacote traz manifests distintos porque Firefox e LibreWolf usam `allowed_extensions`,
enquanto Chromium e Edge usam `allowed_origins`. Instalar o pacote em um perfil
não registra sozinho o host nativo: cada navegador procura o manifest no
diretório de configuração do usuário. Veja as referências de
[Mozilla](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_manifests),
[LibreWolf](https://librewolf.net/docs/faq/),
[Chrome](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging)
e [Edge](https://learn.microsoft.com/pt-br/microsoft-edge/extensions/developer-guide/native-messaging).
O [diretório de manifests do LibreWolf](https://github.com/passff/passff-host)
é diferente do diretório do Firefox.

## Verificação

No checkout local do canal, execute `sh tests/webpki-package.sh`. O teste
constrói o pacote e confirma que os manifests apontam para o executável Guix
e autorizam os IDs corretos das extensões. Para verificar uma assinatura
completa ainda é necessário ter a extensão instalada e configurar o
certificado ou token.

# Lacuna Web PKI on Guix

[Português (Brasil)](webpki.pt-BR.md)

`lacuna-webpki` 2.16.0 packages the native application from Lacuna's official
x86_64 RPM. It is the native messaging host used by the Web PKI browser
extension, not the extension itself. Install the extension through the
[vendor's setup page](https://get.webpkiplugin.com/) in each browser you use.

The [vendor's setup page](https://get.webpkiplugin.com/) currently marks Linux
as discontinued: it says Linux will receive no further Web PKI support or
updates. The RPM has no RPM signature. The Guix recipe pins the exact official
download with SHA-256
`409ceba44e5d0726d9a5efce05afb0dbb52de1278c56315ab4f5b3cc0db9e1e6`.

## Install and connect to browsers

After adding and pulling this channel, add `lacuna-webpki` to your Guix Home
`packages` and add these entries to its `services` list. This complete example
connects Firefox, LibreWolf, Chromium, Google Chrome, and Microsoft Edge:

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

Keep only the browsers you use when adding this service to an existing Home
configuration. If a manifest already exists at one of these destinations,
back it up before `guix home reconfigure`; Guix Home will not overwrite it.
Then run `guix home reconfigure` with your Home configuration and restart the
affected browser.

The package includes separate manifests because Firefox and LibreWolf use
`allowed_extensions`, while Chromium and Edge use `allowed_origins`. The
manifests are read from the browser's user configuration directory; merely
installing the package in a profile does not register the native host. The
[Mozilla](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_manifests),
[LibreWolf](https://librewolf.net/docs/faq/),
[Chrome](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging),
and [Edge](https://learn.microsoft.com/en-us/microsoft-edge/extensions/developer-guide/native-messaging)
documentation describes native messaging; the
[LibreWolf host directory](https://github.com/passff/passff-host)
is separate from Firefox's.

## Check the package

From a local channel checkout, run `sh tests/webpki-package.sh`. It builds the
package and checks that each manifest points to the wrapped Guix executable
and grants access to the corresponding upstream extension ID. A native host
also needs the browser extension and a configured certificate or token for
the complete signing flow.

;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Tor and Tor Browser — latest upstream releases, source-built (Guix-pure),
;;; with real downloaded source hashes.

(define-module (securityops packages tor)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system copy)
  #:use-module (gnu build icecat-extension)
  #:use-module (gnu packages browser-extensions)
  #:use-module (gnu packages compression)
  #:use-module ((guix licenses)
                #:prefix license:)
  #:use-module ((gnu packages tor)
                #:prefix tor:)
  #:use-module ((gnu packages tor-browsers)
                #:prefix tb:))

;;; ---------------------------------------------------------------------------
;;; tor — bumped ahead of Guix: 0.4.9.8 -> 0.4.9.12 (latest stable upstream).
;;; Plain GNU build system; inherit everything and swap source only.
;;; Hash: `guix download https://dist.torproject.org/tor-0.4.9.12.tar.gz'.
;;; ---------------------------------------------------------------------------
(define-public tor
  (package
    (inherit tor:tor)
    (version "0.4.9.12")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://dist.torproject.org/tor-" version
                           ".tar.gz"))
       (sha256
        (base32 "0nsza73dzg8g1dwi5gih9wz854pcqkbfjlyam144ivnsvk4hgly0"))))))

;; All browser inputs below follow tbb-15.0.23-build1 (commit
;; 0b8cdd789f247f5062c9797b0515479eeb56bd38) of tor-browser-build.
;; Translation commits come from projects/translation/config; Firefox locale
;; data is the revision in the released source's l10n-changesets.json.
(define torbrowser-translation-base
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://gitlab.torproject.org/tpo/translation.git")
          (commit "42c240fa39334d44b52a082ece7ea992ce4ff03c")))
    (file-name "translation-base-browser")
    (sha256 (base32 "1gbn4pkmnmvw0gyvvkw0nkzypprw2zzmy4fi4pa1bdxcwqfnh6rj"))))

(define torbrowser-translation-specific
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://gitlab.torproject.org/tpo/translation.git")
          (commit "b43f67013b014d128543404f8e159dd51250da8f")))
    (file-name "translation-tor-browser")
    (sha256 (base32 "0n72wvi49ljf7r5m76cf6j6m58hhnlq7ni6mhx4s0qli9a85w14a"))))

(define torbrowser-firefox-locales
  (let ((commit "412690f1368e37f70af57eecabb93497167eb9ba"))
    (package
      (inherit (@@ (gnu packages tor-browsers) firefox-locales))
      (version (git-version "0.0.0" "2" commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/mozilla-l10n/firefox-l10n")
               (commit commit)))
         (file-name (git-file-name "firefox-locales" version))
         (sha256
          (base32 "15614g94zdk3n1nnx5jy622zryv2ydd5cmn4pidwrl07g1f3xxxa")))))))

(define torbrowser-tor-client
  (package
    (inherit tor:tor-client)
    (version (package-version tor))
    (source
     (package-source tor))))

(define torbrowser-noscript
  (let ((base (@@ (gnu packages browser-extensions) noscript)))
    (make-icecat-extension (package
                             (inherit base)
                             (version "13.6.33.1984")
                             (source
                              (origin
                                (inherit (package-source base))
                                (uri (string-append
                                      "https://archive.torproject.org/tor-package-archive/"
                                      "torbrowser/noscript/noscript-" version
                                      ".xpi"))
                                (sha256
                                 (base32
                                  "1r5p9jd1gdf80z73b23p6wi324366rfs6wn0i1k85cmj8ld7lkhy"))))
                             ;; Bundled flextabs and he JavaScript libraries use the Expat license.
                             (license (list license:gpl3+ license:expat))))))

(define-public torbrowser-assets
  (package
    (name "torbrowser-assets")
    (version "15.0.23")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://archive.torproject.org/tor-package-archive/torbrowser/"
             version "/tor-browser-linux-x86_64-" version ".tar.xz"))
       (sha256
        (base32 "0fdznhi8wmkyn73nld6s7mbq2wzcmbybgfkcp3a4vhvzbkbghqhg"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan ''(("Browser" "."
                         #:include-regexp ("^\\./TorBrowser/Data/Tor/torrc-defaults"
                                           "^\\./fonts/"))
                        ("Browser/TorBrowser/Docs/Licenses"
                         "share/doc/torbrowser-assets"
                         #:include ("Noto-CJK-Font.txt" "Noto-Fonts.txt"
                                    "tor.txt"))
                        ("chrome/toolkit/content/global/license.html"
                         "share/doc/torbrowser-assets/Firefox-license.html"))
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'install 'preserve-font-licenses
            (lambda _
              ;; Includes the Twemoji attribution omitted from the
              ;; bundle's standalone license directory.
              (invoke "unzip" "-q" "Browser/omni.ja"
                      "chrome/toolkit/content/global/license.html"))))))
    (native-inputs (list unzip))
    (home-page "https://www.torproject.org")
    (synopsis "Tor Browser assets (fonts and torrc-defaults)")
    (description
     "Fonts and configuration files extracted from the official Tor
Browser bundle, matching the @code{torbrowser} version in this channel.")
    ;; Noto fonts, Twemoji artwork, and Tor's default configuration.
    (license (list license:silofl1.1 license:cc-by4.0 license:bsd-3))))

(define-public torbrowser
  ;; Guix's constructor accepts coherent assets and translations; inheriting
  ;; its public package alone leaves those inputs pinned to an older release.
  ;; Keep the private API use here so a Guix API change fails at evaluation.
  (let* ((upstream ((@@ (gnu packages tor-browsers) make-torbrowser)
                    #:moz-app-name "torbrowser"
                    #:moz-app-remotingname "Tor Browser"
                    #:branding-directory "browser/branding/tb-release"
                    #:translation-base torbrowser-translation-base
                    #:translation-specific torbrowser-translation-specific
                    #:assets torbrowser-assets
                    #:locales '("ar" "be"
                                "bg"
                                "ca"
                                "cs"
                                "da"
                                "de"
                                "el"
                                "es-ES"
                                "fa"
                                "fi"
                                "fr"
                                "ga-IE"
                                "he"
                                "hu"
                                "id"
                                "is"
                                "it"
                                "ja"
                                "ka"
                                "ko"
                                "lt"
                                "mk"
                                "ms"
                                "my"
                                "nb-NO"
                                "nl"
                                "pl"
                                "pt-BR"
                                "pt-PT"
                                "ro"
                                "ru"
                                "sq"
                                "sv-SE"
                                "th"
                                "tr"
                                "uk"
                                "vi"
                                "zh-CN"
                                "zh-TW")
                    #:build-date "20260914100000"
                    #:base-browser-version "15.0.23"))
         ;; Bind inputs before evaluating the inherited arguments.  Guix's
         ;; phases use this-package-input for Tor's geoip data and locales.
         ;; Evaluating the upstream arguments first captures the old inputs.
         (base (package
                 (inherit upstream)
                 (inputs (modify-inputs (package-inputs upstream)
                           (replace "firefox-locales"
                                    torbrowser-firefox-locales)
                           (replace "tor-client" torbrowser-tor-client))))))
    (package
      (inherit base)
      (version "15.0.23")
      (source
       (origin
         (inherit (package-source base))
         (uri (string-append
               "https://archive.torproject.org/tor-package-archive/torbrowser/"
               version
               "/src-firefox-tor-browser-140.16.0esr-15.0-1-build2.tar.xz"))
         (sha256
          (base32 "0v1d9x0ibs6v5h6irig661dzn2xi30whvzw62w56686i773zjh5c"))))
      (arguments
       (substitute-keyword-arguments (package-arguments base)
         ((#:configure-flags flags
           #~'())
          #~(append #$flags
                    (list "--enable-lto=thin")))))
      (propagated-inputs (modify-inputs (package-propagated-inputs base)
                           (replace "noscript-icecat" torbrowser-noscript))))))

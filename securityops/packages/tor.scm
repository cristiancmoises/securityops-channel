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
  #:use-module ((gnu packages icu4c) #:prefix icu:)
  #:use-module ((gnu packages rust-apps) #:prefix rust-apps:)
  #:use-module ((guix licenses)
                #:prefix license:)
  #:use-module ((gnu packages tor)
                #:prefix tor:)
  #:use-module ((gnu packages tor-browsers)
                #:prefix tb:))

;;; ---------------------------------------------------------------------------
;;; tor — stable upstream release, ahead of the base Guix recipe.
;;; Plain GNU build system; inherit everything and swap source only.
;;; Hash: `guix download https://dist.torproject.org/tor-0.4.9.16.tar.gz'.
;;; ---------------------------------------------------------------------------
(define-public tor
  (package
    (inherit tor:tor)
    (version "0.4.9.16")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://dist.torproject.org/tor-" version
                           ".tar.gz"))
       (sha256
        (base32 "0j0f2vk8czqq58b60g1wjrdh78mj3621cxalrayjai9g2n9y3031"))))))

;; All browser inputs below follow tbb-16.0.1-build1 (commit
;; cd8ab79f93f31ab8259bcf26c9ccb663e25bbd5d) of tor-browser-build.
;; Translation commits come from projects/translation/config.  The Firefox
;; locale snapshot predates the release build; per-locale revisions are listed
;; in the released source's l10n-changesets.json.
(define torbrowser-translation-base
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://gitlab.torproject.org/tpo/translation.git")
          (commit "a92b2df1444ff83dca9278b97dd4a5746ea95a92")))
    (file-name "translation-base-browser")
    (sha256 (base32 "0hynm4h7y5lznzk86rkdqqh2gjv1wl4b3va82f5j5fxc5my1dh78"))))

(define torbrowser-translation-specific
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://gitlab.torproject.org/tpo/translation.git")
          (commit "509783257e9707323d1509622cb711f518fde965")))
    (file-name "translation-tor-browser")
    (sha256 (base32 "0blajm0n4p6xflldznvnvzlgii0h6s3h42zlkpi3nzcc0l8g30lw"))))

(define torbrowser-firefox-locales
  (let ((commit "2412c916180c16ecfd0724cbbecfaa5641a441ba"))
    (package
      (inherit (@@ (gnu packages tor-browsers) firefox-locales))
      (version (git-version "0.0.0" "4" commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/mozilla-l10n/firefox-l10n")
               (commit commit)))
         (file-name (git-file-name "firefox-locales" version))
         (sha256
          (base32 "0jgrxlralgnk2jwjvm414cx1s9x8ng3n0kjg54nw7q1xkxipw7af")))))))

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
                             (version "13.6.38.1984")
                             (source
                              (origin
                                (inherit (package-source base))
                                (uri (string-append
                                      "https://archive.torproject.org/tor-package-archive/"
                                      "torbrowser/noscript/noscript-" version
                                      ".xpi"))
                                (sha256
                                 (base32
                                  "1djaaqddgkqzw3lphwyz76dbg5vc3jcbjpm6ivqqvn0pa3b69mxv"))))
                             ;; Bundled flextabs and he JavaScript libraries use the Expat license.
                             (license (list license:gpl3+ license:expat))))))

(define-public torbrowser-assets
  (package
    (name "torbrowser-assets")
    (version "16.0.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://archive.torproject.org/tor-package-archive/torbrowser/"
             version "/tor-browser-linux-x86_64-" version ".tar.xz"))
       (sha256
        (base32 "1c3qp8b00h41qp7b88634yii87x1scf7vwnafam1zj101ihssdjv"))))
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
                    #:build-date "20261109080000"
                    #:base-browser-version "16.0"))
         ;; Bind inputs before evaluating the inherited arguments.  Guix's
         ;; phases use this-package-input for Tor's geoip data and locales.
         ;; Evaluating the upstream arguments first captures the old inputs.
         (base (package
                 (inherit upstream)
                 (inputs (modify-inputs (package-inputs upstream)
                           (replace "icu4c" icu:icu4c-78)
                           (replace "firefox-locales"
                                    torbrowser-firefox-locales)
                           (replace "tor-client" torbrowser-tor-client))))))
    (package
      (inherit base)
      (version "16.0.1")
      (source
       (origin
         (inherit (package-source base))
         (uri (string-append
               "https://archive.torproject.org/tor-package-archive/torbrowser/"
               version
               "/src-firefox-tor-browser-153.7.0esr-16.0-1-build2.tar.xz"))
         (sha256
          (base32 "1g1mdqk0nxl2v8pn014ym211fx0l43x4gwrs133aqn8wi5fn91dx"))))
      (arguments
       (substitute-keyword-arguments (package-arguments base)
         ((#:configure-flags flags
           #~'())
          #~(append #$flags
                    (list "--enable-lto=thin")))))
      (native-inputs
       (modify-inputs (package-native-inputs base)
         (replace "rust-cbindgen" rust-apps:rust-cbindgen-0.29)))
      (propagated-inputs (modify-inputs (package-propagated-inputs base)
                           (replace "noscript-icecat" torbrowser-noscript))))))

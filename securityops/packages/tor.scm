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

;; All browser inputs below follow tbb-16.0-build1 (commit
;; eb1e8801b909ecedc16bd27b052c3fef8894d16c) of tor-browser-build.
;; Translation commits come from projects/translation/config; Firefox locale
;; data is the revision in the released source's l10n-changesets.json.
(define torbrowser-translation-base
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://gitlab.torproject.org/tpo/translation.git")
          (commit "e1166567b3a76662f0b6223b4eb3ff55a2eca34b")))
    (file-name "translation-base-browser")
    (sha256 (base32 "04qp10jl0bqn65zwca06cbf8hss4ql9yjjmvmv5y9idy838x407v"))))

(define torbrowser-translation-specific
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://gitlab.torproject.org/tpo/translation.git")
          (commit "523ce42af96512b616417c3b5f229887abd9f565")))
    (file-name "translation-tor-browser")
    (sha256 (base32 "18n2yifn6hl5kadzls1yshzmw7jwpppa60wnyq8kw19rsbg3hb9n"))))

(define torbrowser-firefox-locales
  (let ((commit "1e95d1c5f519c3fbde715345ae7beb56a2c79077"))
    (package
      (inherit (@@ (gnu packages tor-browsers) firefox-locales))
      (version (git-version "0.0.0" "3" commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/mozilla-l10n/firefox-l10n")
               (commit commit)))
         (file-name (git-file-name "firefox-locales" version))
         (sha256
          (base32 "12rlba5g46sw22fxqyjj2jfvplxw45dm2m82lq17ajgqh21frdzf")))))))

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
                             (version "13.6.37.1984")
                             (source
                              (origin
                                (inherit (package-source base))
                                (uri (string-append
                                      "https://archive.torproject.org/tor-package-archive/"
                                      "torbrowser/noscript/noscript-" version
                                      ".xpi"))
                                (sha256
                                 (base32
                                  "1lxk46ii1iklfd6ss0n5x1720kp28dv0z00xqd0kib8rh4srd0bb"))))
                             ;; Bundled flextabs and he JavaScript libraries use the Expat license.
                             (license (list license:gpl3+ license:expat))))))

(define-public torbrowser-assets
  (package
    (name "torbrowser-assets")
    (version "16.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://archive.torproject.org/tor-package-archive/torbrowser/"
             version "/tor-browser-linux-x86_64-" version ".tar.xz"))
       (sha256
        (base32 "090s54xc9i4587kym41jx552l8rv5sxibmfd723q9hl9ffv70cyy"))))
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
                    #:build-date "20261026134500"
                    #:base-browser-version "16.0"))
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
      (version "16.0")
      (source
       (origin
         (inherit (package-source base))
         (uri (string-append
               "https://archive.torproject.org/tor-package-archive/torbrowser/"
               version
               "/src-firefox-tor-browser-153.6.0esr-16.0-1-build3.tar.xz"))
         (sha256
          (base32 "0zx87pnm6wrjdxrwyxjz3x2z20v0vsfysxvw8yigx0kxc61in5v4"))))
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

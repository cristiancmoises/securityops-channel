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
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module ((gnu packages tor) #:prefix tor:)
  #:use-module ((gnu packages tor-browsers) #:prefix tb:))

;;; ---------------------------------------------------------------------------
;;; tor — bumped ahead of Guix: 0.4.9.8 -> 0.4.9.9 (latest stable upstream).
;;; Plain GNU build system; inherit everything and swap source only.
;;; Hash: `guix download https://dist.torproject.org/tor-0.4.9.9.tar.gz'.
;;; ---------------------------------------------------------------------------
(define-public tor
  (package
    (inherit tor:tor)
    (version "0.4.9.11")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://dist.torproject.org/tor-"
                           version ".tar.gz"))
       (sha256
        (base32 "1vd825m8v8njsg223hv6syjspgxnj77lgzbr037jm0cc24h1fv1f"))))))

;;; ---------------------------------------------------------------------------
;;; torbrowser — bumped ahead of Guix: 15.0.14 -> 15.0.17 (latest STABLE; the
;;; 16.0aN builds are alphas).  Source-built from the official Tor Browser
;;; Firefox source (140.12.0esr-15.0-1-build2), inheriting Guix's
;;; `mozilla-build-system' machinery.  NOTE: 15.0.17 reuses the byte-identical
;;; 15.0.16 src-firefox tarball (same FFESR build, same hash) — only the version
;;; label changes; the compiled binary is identical.
;;;
;;; CAVEAT (documented in README): Guix's `make-torbrowser' and
;;; `torbrowser-assets' are module-PRIVATE, so they cannot be re-wired without
;;; vendoring ~400 lines plus private helpers.  We therefore inherit the
;;; upstream package and override only `version' + `source'.  The bundled
;;; assets, firefox-l10n / translation commits and MOZ_BUILD_DATE stay at the
;;; 15.0.14 baseline — these are fonts, torrc-defaults and localisation that do
;;; not change across a patch release, so the resulting build is 15.0.16 with a
;;; 15.0.14-era asset/l10n baseline.  Bump those upstream in Guix for a fully
;;; pristine build.
;;; Hash: `guix download .../src-firefox-tor-browser-140.13.0esr-15.0-1-build2.tar.xz'.
;;; ---------------------------------------------------------------------------
;;; Performance: add ThinLTO on top of Guix's stock hardened/optimised build
;;; (--enable-optimize --enable-release --enable-strip, sandbox + PIE kept).
;;; ThinLTO (not full/cross) is deliberate: it gives most of the LTO speedup
;;; while staying within ~16 GiB RAM at link time — full/cross LTO risks OOM on
;;; this host.  The flag is written into the mozconfig as `ac_add_options
;;; --enable-lto=thin' after the stock flags, so it wins over the base config.
(define-public torbrowser
  (package
    (inherit tb:torbrowser)
    (version "15.0.19")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://archive.torproject.org/tor-package-archive/torbrowser/"
             version "/src-firefox-tor-browser-140.13.0esr-15.0-1-build2.tar.xz"))
       (sha256
        (base32 "19ajpd9ly4825ri5q3gwpb12cf0969g1dqgpncmx5cyyd5k0y7yx"))))
    (arguments
     (substitute-keyword-arguments (package-arguments tb:torbrowser)
       ;; Guix's make-torbrowser bakes the DISPLAYED Tor Browser version from its
       ;; %torbrowser-version constant (15.0.14) into --with-base-browser-version
       ;; and MOZ_BUILD_DATE, independently of our version+source override — so
       ;; the browser would report 15.0.14 on a 15.0.19 engine.  Rewrite both to
       ;; 15.0.19: the real base-browser-version, and the official 15.0.19
       ;; build id (BuildID from the upstream 15.0.19 bundle's application.ini).
       ;; Also add ThinLTO.  (The bundled fonts/torrc-defaults still come from
       ;; guix's 15.0.14 assets — unchanged across the patch release.)
       ((#:configure-flags flags #~'())
        #~(append (delete "--with-base-browser-version=15.0.14" #$flags)
                  (list "--with-base-browser-version=15.0.19"
                        "--enable-lto=thin")))
       ((#:phases phases '%standard-phases)
        #~(modify-phases #$phases
            (add-after 'setenv 'fix-tbb-build-date
              (lambda _
                (setenv "MOZ_BUILD_DATE" "20260720080000")))))))))

;;; ---------------------------------------------------------------------------
;;; torbrowser-assets — the official prebuilt bundle (15.0.19) from which fonts
;;; and torrc-defaults are taken.  Provided standalone (Guix keeps its copy
;;; private); verified by hash.  Use it to extract the latest assets, or as the
;;; basis for a fully-pristine torbrowser bump.
;;; Hash: `guix download .../tor-browser-linux-x86_64-15.0.19.tar.xz'.
;;; ---------------------------------------------------------------------------
(define-public torbrowser-assets
  (package
    (name "torbrowser-assets")
    (version "15.0.19")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://archive.torproject.org/tor-package-archive/torbrowser/"
             version "/tor-browser-linux-x86_64-" version ".tar.xz"))
       (sha256
        (base32 "1kz25gmpdmbplm2qy62znvvznwx08psgkdi3n5iwl8a93x1spd1f"))))
    (build-system copy-build-system)
    (arguments
     (list #:install-plan
           ''(("Browser" "." #:include-regexp
               ("^\\./TorBrowser/Data/Tor/torrc-defaults"
                "^\\./fonts/")))))
    (home-page "https://www.torproject.org")
    (synopsis "Tor Browser assets (fonts and torrc-defaults)")
    (description "Fonts and configuration files extracted from the official Tor
Browser bundle, matching the @code{torbrowser} version in this channel.")
    (license license:silofl1.1)))

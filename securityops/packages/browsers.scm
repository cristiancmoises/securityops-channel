;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Web browsers.  Depends on the nonguix channel for google-chrome.

(define-module (securityops packages browsers)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module ((securityops packages librewolf) #:prefix slw:)
  #:use-module ((securityops packages chromium) #:prefix scr:)
  #:use-module ((gnu packages chromium) #:prefix cr:)
  #:use-module ((nongnu packages chrome) #:prefix chrome:))

;;; librewolf — bumped ahead of Guix: 151.0.4-1 -> 153.0.3-1.  The real bump
;;; lives in (securityops packages librewolf), which vendors Guix's private
;;; `make-librewolf-source' machinery (Guix can't be overridden from a channel
;;; otherwise).  Re-exported here so the curated browser set is one module.
(define-public librewolf slw:librewolf)

;;; ungoogled-chromium — TWO variants are provided:
;;;
;;;  * `ungoogled-chromium' re-exports Guix's source-built 147.0.7727.137-1.  A
;;;    from-SOURCE bump beyond 147 is impossible on this Tor-only host: the Chromium
;;;    "-lite" base tarball lives only on Google's commondatastorage GCS bucket,
;;;    which 403-blocks every Tor exit (verified across 6+ rotated circuits, incl.
;;;    the .hashes integrity file; no Wayback copy).  guix builds *existing*
;;;    versions only because their source is served as a substitute (.tar.zst)
;;;    from bordeaux.guix.gnu.org — a brand-new release has no substitute, so it
;;;    must come straight from Google.  (And it would be a ~30GB-RAM, multi-hour
;;;    compile on 15GB RAM regardless.)
;;;
;;;  * `ungoogled-chromium-bin' (see (securityops packages chromium)) is the
;;;    LATEST ungoogled-chromium obtainable here: the official upstream PREBUILT
;;;    Linux x86_64 portable binary (151.0.7922.108-1), hosted on GitHub
;;;    (Tor-reachable) and sha256-verified, wrapped with nonguix's
;;;    chromium-binary-build-system.  Build-and-run verified: `chromium --version'
;;;    => Chromium 151.0.7922.108.  This is the recommended chromium on PATH.
(define-public ungoogled-chromium cr:ungoogled-chromium)
(define-public ungoogled-chromium-bin scr:ungoogled-chromium-bin)

;;; google-chrome — bumped ahead of nonguix: 148.0.7778.215 -> 151.0.7922.108
;;; (latest STABLE per Google's version-history API).  nonguix's
;;; `make-google-chrome' is version-parameterised, so we just call it with the
;;; new version + a real downloaded .deb hash.  Chrome 151 removed its bundled
;;; libEGL/libGLESv2 and added two ELF helpers, so override nonguix's wrapper
;;; plan to match the exact ELF set in this release.
;;; Hash: `guix download .../google-chrome-stable_151.0.7922.108-1_amd64.deb'.
(define-public google-chrome-stable
  (let ((base
         (chrome:make-google-chrome
          "stable" "151.0.7922.108"
          "1vzxirikl8by69nab1gp23h2qwx2dwjj7d0dln0v8ph58p9yddmz")))
    (package
      (inherit base)
      (arguments
       (substitute-keyword-arguments (package-arguments base)
         ((#:wrapper-plan _)
          #~(let ((path "opt/google/chrome/"))
              (map (lambda (file)
                     (string-append path file))
                   '("chrome"
                     "chrome-management-service"
                     "chrome-sandbox"
                     "chrome_crashpad_handler"
                     "libLiteRtWebGpuAccelerator.so"
                     "liboptimization_guide_internal.so"
                     "libqt5_shim.so"
                     "libqt6_shim.so"
                     "libvk_swiftshader.so"
                     "libvulkan.so.1"
                     "WidevineCdm/_platform_specific/linux_x64/libwidevinecdm.so")))))))))

;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Web browsers.  Depends on the nonguix channel for google-chrome.

(define-module (securityops packages browsers)
  #:use-module (guix packages)
  #:use-module ((securityops packages librewolf) #:prefix slw:)
  #:use-module ((securityops packages chromium) #:prefix scr:)
  #:use-module ((gnu packages chromium) #:prefix cr:)
  #:use-module ((nongnu packages chrome) #:prefix chrome:))

;;; librewolf — bumped ahead of Guix: 151.0.4-1 -> 152.0.1-2.  The real bump
;;; lives in (securityops packages librewolf), which vendors Guix's private
;;; `make-librewolf-source' machinery (Guix can't be overridden from a channel
;;; otherwise).  Re-exported here so the curated browser set is one module.
(define-public librewolf slw:librewolf)

;;; ungoogled-chromium — TWO variants are provided:
;;;
;;;  * `ungoogled-chromium' re-exports Guix's source-built 147.0.7727.137-1.  A
;;;    from-SOURCE bump to 149 is impossible on a Tor-only host: the Chromium
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
;;;    Linux x86_64 portable binary (149.0.7827.155-1), hosted on GitHub
;;;    (Tor-reachable) and sha256-verified, wrapped with nonguix's
;;;    chromium-binary-build-system.  Build-and-run verified: `chromium --version'
;;;    => Chromium 149.0.7827.155.  This is the recommended chromium on PATH.
(define-public ungoogled-chromium cr:ungoogled-chromium)
(define-public ungoogled-chromium-bin scr:ungoogled-chromium-bin)

;;; google-chrome — bumped ahead of nonguix: 148.0.7778.215 -> 149.0.7827.155
;;; (latest STABLE per Google's version-history API).  nonguix's
;;; `make-google-chrome' is version-parameterised, so we just call it with the
;;; new version + a real downloaded .deb hash (clean, no inherit-baking).
;;; Hash: `guix download .../google-chrome-stable_150.0.7871.124-1_amd64.deb'.
(define-public google-chrome-stable
  (chrome:make-google-chrome
   "stable" "150.0.7871.124"
   "1p2wqz0r46dixalxqh2cq1d2pl9pm8841fsjdwbz7xn15aynlqsc"))

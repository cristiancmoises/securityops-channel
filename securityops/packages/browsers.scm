;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Web browsers.  Depends on the nonguix channel for google-chrome.

(define-module (securityops packages browsers)
  #:use-module (guix packages)
  #:use-module ((gnu packages librewolf) #:prefix lw:)
  #:use-module ((gnu packages chromium) #:prefix cr:)
  #:use-module ((nongnu packages chrome) #:prefix chrome:))

;;; librewolf — Guix ships 151.0.4-1; upstream is 152.0.1-2.  Re-exported (NOT
;;; bumped) on purpose: Guix's librewolf source is produced by the *private*
;;; `make-librewolf-source' (firefox source + librewolf overlay + l10n), which a
;;; channel cannot override without vendoring that machinery and downloading the
;;; ~500MB Firefox source.  See README → "LibreWolf 152" for the upgrade recipe.
(define-public librewolf lw:librewolf)

;;; ungoogled-chromium — Guix ships 147.0.7727.137-1; upstream is
;;; 149.0.7827.155-1.  Re-exported (NOT bumped): a Chromium source bump is a
;;; multi-GB download and a many-hour/large-RAM compile, impractical to package
;;; and verify here, and ungoogled-chromium lags Chrome by design.  Bump it in
;;; Guix proper when you have the build budget.
(define-public ungoogled-chromium cr:ungoogled-chromium)

;;; google-chrome — bumped ahead of nonguix: 148.0.7778.215 -> 149.0.7827.155
;;; (latest STABLE per Google's version-history API).  nonguix's
;;; `make-google-chrome' is version-parameterised, so we just call it with the
;;; new version + a real downloaded .deb hash (clean, no inherit-baking).
;;; Hash: `guix download .../google-chrome-stable_149.0.7827.155-1_amd64.deb'.
(define-public google-chrome-stable
  (chrome:make-google-chrome
   "stable" "149.0.7827.155"
   "0mk5y08wcqzbswxwmlkc69wpwfzsmrl4xzhddwvf994841zwfhw3"))

;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Web browsers.  Depends on the nonguix channel for google-chrome.

(define-module (securityops packages browsers)
  #:use-module (guix packages)
  #:use-module ((securityops packages librewolf) #:prefix slw:)
  #:use-module ((gnu packages chromium) #:prefix cr:)
  #:use-module ((nongnu packages chrome) #:prefix chrome:))

;;; librewolf — bumped ahead of Guix: 151.0.4-1 -> 152.0.1-2.  The real bump
;;; lives in (securityops packages librewolf), which vendors Guix's private
;;; `make-librewolf-source' machinery (Guix can't be overridden from a channel
;;; otherwise).  Re-exported here so the curated browser set is one module.
(define-public librewolf slw:librewolf)

;;; ungoogled-chromium — Guix ships 147.0.7727.137-1; upstream is
;;; 149.0.7827.155-1.  DEFERRED by choice (re-confirmed 2026-06-22): a source
;;; bump is guix-maintainer-level, not a "verified hash" channel bump.  The
;;; source is ASSEMBLED in-module (gnu/packages/chromium.scm) from a chromium
;;; "-lite" tarball plus version-pinned ungoogled (github tag 149.0.7827.155-1)
;;; and debian (salsa debian/149.0.7827.155-1) patch repos, a hand-picked
;;; 18-patch subset, and preserved/blacklisted file lists — then a multi-hour,
;;; ~30GB-RAM compile that cannot be verified on this host.
;;; Groundwork for a future bump: the upstream tags exist and all 18 of guix's
;;; selected debian patches are STILL PRESENT at debian/149.0.7827.155-1, so a
;;; bump likely needs only the three source hashes (chromium -lite tarball,
;;; ungoogled git, debian git) refreshed.  For a current Chromium engine today,
;;; this channel already ships google-chrome-stable 149.  Re-exported at guix's
;;; version until guix proper advances:
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

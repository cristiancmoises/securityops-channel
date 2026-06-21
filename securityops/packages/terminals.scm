;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Terminal emulators — the latest upstream releases curated for the
;;; securityops workstation.  Packages that Guix already ships at the latest
;;; upstream version are re-exported unchanged so this channel stays the single
;;; source of truth for the curated set; packages ahead of Guix carry a real,
;;; downloaded source hash.

(define-module (securityops packages terminals)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module ((gnu packages terminals) #:prefix gnu:))

;;; ---------------------------------------------------------------------------
;;; kitty — bumped ahead of Guix: 0.46.2 -> 0.47.4 (latest upstream).
;;;
;;; Inherits the upstream package and ORIGIN so the docs-build snippet and
;;; module list are preserved verbatim; only the git tag and the content hash
;;; change.  `version' is in scope inside `source', so the v-tag tracks it.
;;; Hash computed with `guix hash -rx' over a clean `git clone -b v0.47.4'.
;;; ---------------------------------------------------------------------------
(define-public kitty
  (package
    (inherit gnu:kitty)
    (version "0.47.4")
    (source
     (origin
       (inherit (package-source gnu:kitty))
       (uri (git-reference
             (url "https://github.com/kovidgoyal/kitty")
             (commit (string-append "v" version))))
       (file-name (git-file-name (package-name gnu:kitty) version))
       (sha256
        (base32 "1m8sn8hs63qw8n3hvn07pqmnd4grqfr59pxgwa4jq7ivd1nrcfsh"))))))

;;; ---------------------------------------------------------------------------
;;; alacritty — Guix already ships the latest upstream (0.17.0).  Re-exported
;;; so it is installable from this channel and transparently tracks Guix until
;;; upstream advances; bump it here the day Guix lags behind.
;;; ---------------------------------------------------------------------------
(define-public alacritty gnu:alacritty)

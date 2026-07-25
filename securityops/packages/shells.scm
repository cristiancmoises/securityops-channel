;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Shells — curated set for the securityops workstation.

(define-module (securityops packages shells)
  #:use-module (securityops packages fish-crates)
  #:use-module ((gnu packages shells) #:prefix gnu:)
  #:use-module (gnu packages ncurses)
  #:use-module (gnu packages pcre)
  #:use-module (gnu packages python)
  #:use-module (guix base32)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix utils))

;;; fish — updated ahead of Guix.  Fish 4.8.1 adds and updates enough Rust
;;; dependencies that it cannot use Guix's crate set for 4.7.1.  Its registry
;;; crates and Git workspace snapshots are pinned in
;;; (securityops packages fish-crates).
(define-public fish
  (package
    (inherit gnu:fish)
    (version "4.8.1")
    (source
     (origin
       (inherit (package-source gnu:fish))
       (uri (string-append
             "https://github.com/fish-shell/fish-shell/releases/download/"
             version "/fish-" version ".tar.xz"))
       (sha256
        (base32
         "10jpqrv7v1szdnwpn2p0y1w5w8lmfqysg490gi596pl63s2nmf0f"))))
    (inputs
     (cons* gnu:fish-foreign-env
            ncurses
            pcre2
            python
            fish-4.8.1-cargo-inputs))
    (arguments
     (substitute-keyword-arguments (package-arguments gnu:fish)
       ((#:phases phases)
        #~(modify-phases #$phases
            (replace 'use-guix-vendored-dependencies
              (lambda _
                (substitute* "Cargo.toml"
                  (("git = \"[^\"]+\", (tag|rev) = \"[^\"]+\"")
                   "version = \"*\""))))
            (add-before 'patch-tests 'account-for-renamed-migration-test
              (lambda _
                (rename-file "tests/checks/__fish_theme_migrate.fish"
                             "tests/checks/__fish_migrate.fish")))))))))

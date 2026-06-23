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
  #:use-module (guix utils)                    ; substitute-keyword-arguments
  #:use-module (guix git-download)
  #:use-module (guix build-system go)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module ((gnu packages golang-build) #:prefix gb:)   ; go-golang-org-x-sys
  #:use-module ((gnu packages terminals) #:prefix gnu:))

;;; ---------------------------------------------------------------------------
;;; Go dependencies NEW in kitty 0.47.x that Guix's kitty 0.46.2 does not carry.
;;; Guix wires kitty's ~20 Go modules as explicit native-inputs; 0.47.x added
;;; these two, so an inherit+version bump alone fails to build ("cannot find
;;; package github.com/emmansun/base64 …").  Both are tiny: their only non-test
;;; dependency is golang.org/x/sys, already in Guix.
;;; ---------------------------------------------------------------------------
(define-public go-github-com-emmansun-base64
  (package
    (name "go-github-com-emmansun-base64")
    (version "0.9.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/emmansun/base64")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0c1i624nkqb3zcrx5gnmynjg2yvlsglygaw7ms8vry5153dr6i51"))))
    (build-system go-build-system)
    (arguments (list #:import-path "github.com/emmansun/base64"))
    (propagated-inputs (list gb:go-golang-org-x-sys))
    (home-page "https://github.com/emmansun/base64")
    (synopsis "SIMD-accelerated base64 codec for Go")
    (description "A drop-in, SIMD-accelerated replacement for Go's standard
@code{encoding/base64} package.")
    (license license:bsd-3)))

(define-public go-github-com-sgtdi-fswatcher
  (package
    (name "go-github-com-sgtdi-fswatcher")
    (version "1.3.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/sgtdi/fswatcher")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "134swn5x2g0dn8nn48f66r49h5mxfl8yrwrlmkargl25mi7yw383"))))
    (build-system go-build-system)
    ;; Tests pull testify/go-spew/go-difflib/yaml.v3; the library's only
    ;; runtime dependency is golang.org/x/sys, so skip them.
    (arguments (list #:import-path "github.com/sgtdi/fswatcher"
                     #:tests? #f))
    (propagated-inputs (list gb:go-golang-org-x-sys))
    (home-page "https://github.com/sgtdi/fswatcher")
    (synopsis "Filesystem-change watcher library for Go")
    (description "A small library for watching filesystem changes, used by
kitty's @code{watch} kitten.")
    (license license:expat)))

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
        (base32 "1m8sn8hs63qw8n3hvn07pqmnd4grqfr59pxgwa4jq7ivd1nrcfsh"))))
    ;; kitty 0.47.4 adds tests that need a real environment the build sandbox
    ;; lacks: kitty_tests/dnd_kitten imports the display-only graphics module
    ;; (which Guix already strips) and the Go TestMachineId needs
    ;; /etc/machine-id.  The release is upstream-tested and the build itself is
    ;; unaffected, so skip the suite.
    (arguments
     (substitute-keyword-arguments (package-arguments gnu:kitty)
       ((#:tests? _ #f) #f)))
    (native-inputs
     (modify-inputs (package-native-inputs gnu:kitty)
       (append go-github-com-emmansun-base64
               go-github-com-sgtdi-fswatcher)))))

;;; ---------------------------------------------------------------------------
;;; alacritty — Guix already ships the latest upstream (0.17.0).  Re-exported
;;; so it is installable from this channel and transparently tracks Guix until
;;; upstream advances; bump it here the day Guix lags behind.
;;; ---------------------------------------------------------------------------
(define-public alacritty gnu:alacritty)

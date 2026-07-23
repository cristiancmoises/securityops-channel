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
  #:use-module (guix gexp)                      ; #~ / modify-phases for the kitty go-toolchain phase
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
;;; kitty — bumped ahead of Guix: 0.46.2 -> 0.48.0 (latest upstream).
;;;
;;; Inherits the upstream package and ORIGIN so the docs-build snippet and
;;; module list are preserved verbatim; only the git tag and the content hash
;;; change.  `version' is in scope inside `source', so the v-tag tracks it.
;;; Hash is Guix's own git-fetch of tag v0.48.0 (authoritative — a plain
;;; `guix hash -rx' over a working tree can differ from the git-fetch fixed
;;; output, so always take the value Guix reports on a hash mismatch).
;;; ---------------------------------------------------------------------------
;;; ebitengine/purego — call C from Go without cgo.  A NEW direct dependency of
;;; kitty 0.48 (imported once, in the notify kitten); Guix does not package it,
;;; so define it here.  kitty builds in GOPATH mode, so only genuinely-imported
;;; deps need providing — the other go.mod bumps (chroma, x/sys, …) are used
;;; from Guix's existing sources.
(define-public go-github-com-ebitengine-purego
  (package
    (name "go-github-com-ebitengine-purego")
    (version "0.10.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/ebitengine/purego")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "12bcfb1zwrk5pc1spkbpd0ymvkpwhfyk9ni77p164pp7c3r21bkv"))))
    (build-system go-build-system)
    (arguments (list #:import-path "github.com/ebitengine/purego"
                     #:tests? #f))
    (home-page "https://github.com/ebitengine/purego")
    (synopsis "Call C from Go without cgo")
    (description "purego lets Go programs call C functions without using cgo, by
loading shared libraries and dispatching into them at runtime.")
    (license license:asl2.0)))

(define-public kitty
  (package
    (inherit gnu:kitty)
    (version "0.48.0")
    (source
     (origin
       (inherit (package-source gnu:kitty))
       (uri (git-reference
             (url "https://github.com/kovidgoyal/kitty")
             (commit (string-append "v" version))))
       (file-name (git-file-name (package-name gnu:kitty) version))
       (sha256
        (base32 "1nbfkkjcs5c54w5fd02djljxl90fykmc5w470mrs1yrhfilyq7gv"))))
    ;; kitty's tests need a real environment the build sandbox lacks
    ;; (kitty_tests/dnd_kitten imports the display-only graphics module Guix
    ;; strips; the Go TestMachineId needs /etc/machine-id).  The release is
    ;; upstream-tested and the build itself is unaffected, so skip the suite.
    ;;
    ;; 0.48's go.mod pins `toolchain go1.26.5', but Guix ships go-1.26.4 — so
    ;; `go list -m' (run by kitty's setup.py) tries to DOWNLOAD that toolchain
    ;; and fails offline.  Force the local toolchain (1.26.x is compatible).
    (arguments
     (substitute-keyword-arguments (package-arguments gnu:kitty)
       ((#:tests? _ #f) #f)
       ((#:phases phases '%standard-phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'set-go-toolchain-local
              (lambda _
                (setenv "GOTOOLCHAIN" "local")))))))
    (native-inputs
     (modify-inputs (package-native-inputs gnu:kitty)
       (append go-github-com-emmansun-base64
               go-github-com-sgtdi-fswatcher
               go-github-com-ebitengine-purego)))))

;;; ---------------------------------------------------------------------------
;;; alacritty — Guix already ships the latest upstream (0.17.0).  Re-exported
;;; so it is installable from this channel and transparently tracks Guix until
;;; upstream advances; bump it here the day Guix lags behind.
;;; ---------------------------------------------------------------------------
(define-public alacritty gnu:alacritty)

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
  #:use-module (guix download)
  #:use-module (guix build-system copy)
  #:use-module (guix build-system go)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages base)             ; glibc
  #:use-module (gnu packages gcc)              ; libstdc++ and libgcc_s
  #:use-module (gnu packages elf)              ; patchelf
  #:use-module (gnu packages sphinx)           ; python-sphinx-design
  #:use-module ((gnu packages golang-build) #:prefix gb:)   ; go-golang-org-x-sys
  #:use-module ((gnu packages terminals) #:prefix gnu:))

;;; Kitty 0.49 requires Slang at build time and for user-defined shaders.
;;; The upstream glibc-2.27 release has a small, auditable runtime set.  Keep
;;; only the compiler, its modules, and upstream license notices; relink the
;;; ELF objects to Guix's libc and C++ runtime.  The release bundles glslang
;;; and SPIR-V support (notices included), so it is not a source build.
(define-public shader-slang-bin
  (package
    (name "shader-slang-bin")
    (version "2026.18.3")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/shader-slang/slang/releases/download/v"
             version "/slang-" version "-linux-x86_64-glibc-2.27.tar.gz"))
       (sha256
        (base32 "12j6qzkqdknyf4giq78yix3d53ycgbhqvglmbbvw6gcypkv5ffrp"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan
      #~'(("bin/slangc" "bin/")
          ("lib/libslang-compiler.so.0.2026.18.3" "lib/")
          ("lib/libslang-glsl-module-2026.18.3.so" "lib/")
          ("lib/libslang-glslang-2026.18.3.so" "lib/")
          ("lib/slang-standard-module-2026.18.3" "lib/")
          ("LICENSE" "share/doc/shader-slang/")
          ("LICENSES" "share/doc/shader-slang/")
          ("third-party-notices" "share/doc/shader-slang/"))
      #:phases
      #~(modify-phases %standard-phases
          ;; All upstream license texts are copied by #:install-plan below.
          (delete 'install-license-files)
          (add-after 'unpack 'enter-release-root
            (lambda _
              ;; This archive has several top-level directories; Guix's
              ;; generic unpack phase otherwise enters the first one (bin).
              (unless (file-exists? "bin/slangc")
                (chdir ".."))
              (unless (file-exists? "bin/slangc")
                (error "Shader Slang release archive has no slangc"))))
          (add-after 'install 'relink-compiler
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((out #$output)
                     (lib (string-append out "/lib"))
                     (glibc #$(this-package-input "glibc"))
                     (gcc-lib (assoc-ref inputs "gcc:lib"))
                     (rpath (string-join (list lib
                                               (string-append glibc "/lib")
                                               (string-append gcc-lib "/lib"))
                                         ":")))
                (invoke "patchelf" "--set-interpreter"
                        (string-append glibc "/lib/ld-linux-x86-64.so.2")
                        (string-append out "/bin/slangc"))
                (for-each (lambda (f)
                            (invoke "patchelf" "--set-rpath" rpath f))
                          (cons (string-append out "/bin/slangc")
                                (find-files lib "\\.so(\\..*)?$")))))))))
    (native-inputs (list patchelf))
    (inputs (list (list "glibc" glibc)
                  (list "gcc:lib" gcc "lib")))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/shader-slang/slang")
    (synopsis "Slang shader compiler from the official Linux release")
    (description
     "Upstream Slang shader compiler and its runtime modules,
relinked against Guix's glibc and C++ libraries.  Includes upstream license
and bundled-dependency notices.  Required by Kitty's shader pipeline.")
    (license license:asl2.0)))

;;; ---------------------------------------------------------------------------
;;; Go dependencies NEW in kitty 0.47+ that Guix's kitty 0.46.2 does not carry.
;;; Guix wires kitty's ~20 Go modules as explicit native-inputs; 0.47+ added
;;; these, so an inherit+version bump alone fails to build ("cannot find
;;; package github.com/emmansun/base64 …").  Both are tiny: their only non-test
;;; dependency is golang.org/x/sys, already in Guix.
;;; ---------------------------------------------------------------------------
(define-public go-github-com-emmansun-base64
  (package
    (name "go-github-com-emmansun-base64")
    (version "0.10.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/emmansun/base64")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0mkkk9xhc55jfq1nbavb8vivv2xb8sp0l807ci0ak3aimxxjqj9c"))))
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

(define-public go-github-com-kovidgoyal-go-shm-v2
  (package
    (name "go-github-com-kovidgoyal-go-shm-v2")
    (version "2.0.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/kovidgoyal/go-shm")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0lkkqc6cxkkjrpb6b3bpfv7rgna50rdajrsvq4kzv5p3wl23fg8s"))))
    (build-system go-build-system)
    (arguments
     (list
      #:import-path "github.com/kovidgoyal/go-shm/v2"))
    (propagated-inputs (list gb:go-golang-org-x-sys))
    (home-page "https://github.com/kovidgoyal/go-shm")
    (synopsis "Shared memory support for Go")
    (description "Portable shared-memory files and mapping helpers for Go.")
    (license license:bsd-3)))

;;; ---------------------------------------------------------------------------
;;; kitty — bumped ahead of Guix: 0.46.2 -> 0.49.1 (latest upstream).
;;;
;;; Inherits the upstream package and ORIGIN so the docs-build snippet and
;;; module list are preserved verbatim; only the git tag and the content hash
;;; change.  `version' is in scope inside `source', so the v-tag tracks it.
;;; Hash is Guix's own git-fetch of tag v0.49.1 (authoritative — a plain
;;; `guix hash -rx' over a working tree can differ from the git-fetch fixed
;;; output, so always take the value Guix reports on a hash mismatch).
;;; ---------------------------------------------------------------------------
;;; ebitengine/purego — call C from Go without cgo.  A NEW direct dependency of
;;; kitty 0.48 (imported once, in the notify kitten); Guix does not package it,
;;; so define it here.  kitty builds in GOPATH mode, so only genuinely-imported
;;; deps need providing — the other go.mod bumps (chroma, x/sys, …) are used
;;; from Guix's existing sources.  Kitty's go.mod names 0.11.0; this channel
;;; supplies the newer stable purego 0.11.1.
(define-public go-github-com-ebitengine-purego
  (package
    (name "go-github-com-ebitengine-purego")
    (version "0.11.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/ebitengine/purego")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1r7ivlgwn7ikifzxbp62vzdjccvh19iyill3mzqw4dgc9b0hvg15"))))
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
    (version "0.49.1")
    (source
     (origin
       (inherit (package-source gnu:kitty))
       (uri (git-reference
             (url "https://github.com/kovidgoyal/kitty")
             (commit (string-append "v" version))))
       (file-name (git-file-name (package-name gnu:kitty) version))
       (sha256
        (base32 "19sjlf44gq38r4fa8iivp2y4y494lynhm43mf1il0d7ck5yd6n31"))))
    ;; kitty's tests need a real environment the build sandbox lacks
    ;; (kitty_tests/dnd_kitten imports the display-only graphics module Guix
    ;; strips; the Go TestMachineId needs /etc/machine-id).  The release is
    ;; upstream-tested and the build itself is unaffected, so skip the suite.
    ;;
    ;; 0.49's go.mod requests `toolchain go1.26.6'.  Use Guix's packaged
    ;; toolchain instead of allowing an implicit build-time download.
    (arguments
     (substitute-keyword-arguments (package-arguments gnu:kitty)
       ((#:tests? _ #f)
        #f)
       ((#:phases phases
         '%standard-phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'set-go-toolchain-local
              (lambda _
                (setenv "GOTOOLCHAIN" "local")))))))
    (native-inputs (modify-inputs (package-native-inputs gnu:kitty)
                     (append go-github-com-emmansun-base64
                             go-github-com-sgtdi-fswatcher
                             go-github-com-kovidgoyal-go-shm-v2
                             go-github-com-ebitengine-purego
                             python-sphinx-design
                             shader-slang-bin)))
    (inputs (modify-inputs (package-inputs gnu:kitty)
              (append shader-slang-bin)))))

;;; ---------------------------------------------------------------------------
;;; alacritty — Guix already ships the latest upstream (0.17.0).  Re-exported
;;; so it is installable from this channel and transparently tracks Guix until
;;; upstream advances; bump it here the day Guix lags behind.
;;; ---------------------------------------------------------------------------
(define-public alacritty gnu:alacritty)

;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Everyday TUI / desktop utilities.  KeePassXC and ueberzug++ track the
;;; pinned Guix packages; lf is bumped ahead with its new Go dependency chain.

(define-module (securityops packages utils)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:use-module (guix build-system go)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module ((gnu packages password-utils) #:prefix pw:)
  #:use-module ((gnu packages image-viewers) #:prefix iv:)
  #:use-module ((gnu packages disk) #:prefix disk:)
  #:use-module ((gnu packages golang-build) #:prefix gb:)
  #:use-module ((gnu packages golang-xyz) #:prefix go:))

(define-public keepassxc pw:keepassxc)        ; 2.7.12 — latest
(define-public ueberzugpp iv:ueberzugpp)      ; 2.9.10 — latest (ueberzug++)

;; lf r42 migrated from tcell/v2 to tcell/v3 and now measures terminal display
;; width with clipperhouse's UAX #29 implementation.  These three Go modules are
;; not yet in the pinned Guix revision, so keep the dependency chain local.
(define go-github-com-clipperhouse-uax29-v2
  (package
    (name "go-github-com-clipperhouse-uax29-v2")
    (version "2.7.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/clipperhouse/uax29")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0p18s46jd4ryqp036cyv4j6ys67706kihw0fj5ym98xf1m2mdsgg"))))
    (build-system go-build-system)
    (arguments
     (list #:import-path "github.com/clipperhouse/uax29/v2"
           ;; Exclude generator/comparative submodules: they carry separate
           ;; go.mod files and benchmark-only dependencies.  Exercise every
           ;; library package used by lf.
           #:test-subdirs
           #~(list "." "graphemes" "internal/iterators/..."
                   "sentences" "words")))
    (home-page "https://github.com/clipperhouse/uax29")
    (synopsis "Unicode text segmentation for Go")
    (description "uax29 implements Unicode text segmentation for words,
sentences, and graphemes according to Unicode Standard Annex Number 29.")
    (license license:expat)))

(define go-github-com-clipperhouse-displaywidth
  (package
    (name "go-github-com-clipperhouse-displaywidth")
    (version "0.11.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/clipperhouse/displaywidth")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "032f33vf5ign78l9clc3vz1kzirxgalxswm3j6l4nbf46vpp08yz"))))
    (build-system go-build-system)
    (arguments
     (list #:import-path "github.com/clipperhouse/displaywidth"
           ;; comparison/ and internal/gen carry benchmark/generator-only
           ;; dependencies; run the complete public-library test package.
           #:test-subdirs #~(list ".")))
    (propagated-inputs
     (list go-github-com-clipperhouse-uax29-v2))
    (home-page "https://github.com/clipperhouse/displaywidth")
    (synopsis "Measure monospace display width in Go")
    (description "displaywidth efficiently measures the monospace display
width of Go strings, UTF-8 byte slices, and runes.")
    (license license:expat)))

;; Keep lf's private dependency graph at the exact versions declared by r42.
;; The pinned Guix revision carries older compatible releases; these local
;; inherits retain Guix's phases/metadata while replacing only version+source.
(define go-golang-org-x-sys-0.47
  (package
    (inherit gb:go-golang-org-x-sys)
    (version "0.47.0")
    (source
     (origin
       (inherit (package-source gb:go-golang-org-x-sys))
       (uri (git-reference
             (url "https://go.googlesource.com/sys")
             (commit (string-append "v" version))))
       (file-name (git-file-name "go-golang-org-x-sys" version))
       (sha256
        (base32 "16jnfsdfwwnldkspgnyhi70br0y3ygl8r7wm08yd3s4dff93xpaa"))))))

(define go-golang-org-x-term-0.45
  (package
    (inherit gb:go-golang-org-x-term)
    (version "0.45.0")
    (source
     (origin
       (inherit (package-source gb:go-golang-org-x-term))
       (uri (git-reference
             (url "https://go.googlesource.com/term")
             (commit (string-append "v" version))))
       (file-name (git-file-name "go-golang-org-x-term" version))
       (sha256
        (base32 "031n9igqc9q855wzs5n0cxb2br12nifnja2fyr1rs4d98wk5xw5w"))))
    (propagated-inputs
     (list go-golang-org-x-sys-0.47))))

(define go-golang-org-x-text-0.40
  (package
    (inherit gb:go-golang-org-x-text)
    (version "0.40.0")
    (source
     (origin
       (inherit (package-source gb:go-golang-org-x-text))
       (uri (git-reference
             (url "https://go.googlesource.com/text")
             (commit (string-append "v" version))))
       (file-name (git-file-name "go-golang-org-x-text" version))
       (sha256
        (base32 "0ha1bf1anwwdks9xr3f6iw48zi6nhqbryyfxbap3wddz9vkj44n2"))))))

(define go-github-com-fsnotify-fsnotify-1.10
  (package
    (inherit go:go-github-com-fsnotify-fsnotify)
    (version "1.10.1")
    (source
     (origin
       (inherit (package-source go:go-github-com-fsnotify-fsnotify))
       (uri (git-reference
             (url "https://github.com/fsnotify/fsnotify")
             (commit (string-append "v" version))))
       (file-name (git-file-name "go-github-com-fsnotify-fsnotify" version))
       (sha256
        (base32 "0dc2bwbji8slb5fc17az9m4q788i0p35cjh4lq6ak73qr214pc78"))))
    (propagated-inputs
     (list go-golang-org-x-sys-0.47))))

(define go-github-com-gdamore-tcell-v3
  (package
    (name "go-github-com-gdamore-tcell-v3")
    (version "3.4.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/gdamore/tcell")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0nfz8yf9ynmigrs81mbr65ci9czc2b4pzap1dg0slp1ryqvhpnqk"))))
    (build-system go-build-system)
    (arguments
     (list #:import-path "github.com/gdamore/tcell/v3"))
    (propagated-inputs
     (list go-github-com-clipperhouse-displaywidth
           go-github-com-clipperhouse-uax29-v2
           go:go-github-com-gdamore-encoding
           go:go-github-com-lucasb-eyer-go-colorful
           go-golang-org-x-sys-0.47
           go-golang-org-x-term-0.45
           go-golang-org-x-text-0.40))
    (home-page "https://github.com/gdamore/tcell")
    (synopsis "Portable terminal-cell API for Go")
    (description "Tcell provides a portable lower-level API for Go programs
that interact with terminals, terminal emulators, and Windows consoles.")
    (license license:asl2.0)))

(define-public lf
  (package
    (inherit disk:lf)
    (version "42")
    (source
     (origin
       (inherit (package-source disk:lf))
       (uri (git-reference
             (url "https://github.com/gokcehan/lf")
             (commit (string-append "r" version))))
       (file-name (git-file-name "lf" version))
       (sha256
        (base32 "08gpmlh664xf2sgbdvxsql24shww7l8xh8vrw6m5qwvv7nzdn5av"))))
    (native-inputs
     (list go-github-com-clipperhouse-displaywidth
           go-github-com-gdamore-tcell-v3
           go:go-github-com-djherbis-times
           go-github-com-fsnotify-fsnotify-1.10
           go-golang-org-x-sys-0.47
           go-golang-org-x-term-0.45))))

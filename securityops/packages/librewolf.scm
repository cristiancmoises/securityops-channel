;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2024, 2025 Ian Eure <ian@retrospec.tv>          ; upstream librewolf.scm
;;; Copyright © 2025, 2026 Untrusem <mysticmoksh@riseup.net>    ; upstream librewolf.scm
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; LibreWolf — bumped ahead of Guix: 151.0.4-1 -> 152.0.1-2 (latest upstream).
;;;
;;; Guix builds librewolf from the module-PRIVATE `make-librewolf-source'
;;; (Firefox release source + the codeberg librewolf/source overlay + a pinned
;;; firefox-l10n checkout, assembled by a `computed-origin-method' derivation).
;;; A channel cannot reach that helper, so the source-assembly machinery
;;; (`firefox-source-origin', `librewolf-source-origin', `computed-origin-method',
;;; `firefox-l10n', `make-librewolf-source') is VENDORED here verbatim from
;;; gnu/packages/librewolf.scm; only the three release hashes and the l10n commit
;;; change.  The package then INHERITS guix's `librewolf' (build phases, inputs,
;;; clang/llvm/rust toolchain, configure flags, %librewolf-build-id) and overrides
;;; only `version' + `source' — exactly the torbrowser-bump pattern, so upstream
;;; build fixes keep flowing through.
;;;
;;; The librewolf-specific patches (`librewolf-neuter-locale-download.patch',
;;; `librewolf-compare-paths.patch', …) are guix-bundled; `search-patches' resolves
;;; them from guix's patch dir on the channel load path — no need to vendor them.
;;;
;;; Hashes (all fetched + verified 2026-06-22):
;;;   firefox 152.0.1 source  (ftp.mozilla.org)  -> firefox-hash
;;;   librewolf/source 152.0.1-2 (codeberg, git) -> librewolf-hash
;;;   firefox-l10n @ 9929bc50 (github, git)       -> l10n-hash
;;; The l10n commit is the `revision' from
;;; firefox-152.0.1/browser/locales/l10n-changesets.json in the Firefox source.
;;;
;;; A full build is a multi-hour Firefox compile (deferred to reconfigure, like
;;; torbrowser).  The SOURCE assembly is verifiable here:
;;;   guix build -L ~/securityops-channel -S librewolf

(define-module (securityops packages librewolf)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((srfi srfi-1) #:hide (zip))
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module ((gnu packages librewolf) #:prefix lw:))

(define (firefox-source-origin version hash)
  (origin
    (method url-fetch)
    (uri (string-append
          "https://ftp.mozilla.org/pub/firefox/releases/"
          version "/source/" "firefox-" version
          ".source.tar.xz"))
    (sha256 (base32 hash))))

(define (librewolf-source-origin version hash)
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://codeberg.org/librewolf/source.git")
          (commit version)
          (recursive? #t)))
    (file-name (git-file-name "librewolf-source" version))
    (patches (search-patches "librewolf-neuter-locale-download.patch"))
    (sha256 (base32 hash))))

(define computed-origin-method (@@ (guix packages) computed-origin-method))

(define firefox-l10n
  ;; Match this commit to the upstream tarball.  The hash is in
  ;; firefox-NNN.0/browser/locales/l10n-changesets.json (the "revision" field;
  ;; the same value repeats for every language).  For 152.0.1 it is 9929bc50.
  (let ((commit "9929bc50607f8c2aac9db5329a596997eee1cabb"))
    (origin
      (method git-fetch)
      (uri (git-reference
            (url "https://github.com/mozilla-l10n/firefox-l10n.git")
            (commit commit)))
      (file-name (git-file-name "firefox-l10n" commit))
      (sha256 (base32 "1ka78jhbhgvxby29q7ni5lim5c4977qdixd50cylnvb4807cli6l")))))

(define* (make-librewolf-source #:key version firefox-hash librewolf-hash l10n)
  (let* ((ff-src (firefox-source-origin
                  (car (string-split version #\-))
                  firefox-hash))
         (lw-src (librewolf-source-origin
                  version
                  librewolf-hash)))

    (origin
      (method computed-origin-method)
      (file-name (string-append "librewolf-" version ".source.tar.gz"))
      (sha256 #f)
      (uri
       (delay
         (with-imported-modules '((guix build utils))
           #~(begin
               (use-modules (guix build utils))
               (set-path-environment-variable
                "PATH" '("bin")
                (list #+python
                      #+(canonical-package bash)
                      #+(canonical-package gnu-make)
                      #+(canonical-package coreutils)
                      #+(canonical-package findutils)
                      #+(canonical-package patch)
                      #+(canonical-package xz)
                      #+(canonical-package sed)
                      #+(canonical-package grep)
                      #+(canonical-package pigz)
                      #+(canonical-package tar)))
               (set-path-environment-variable
                "PYTHONPATH"
                (list #+(format #f "lib/python~a/site-packages"
                                (version-major+minor
                                 (package-version python))))
                '#+(cons python-jsonschema
                         (map second
                              (package-transitive-propagated-inputs
                               python-jsonschema))))

               ;; Copy LibreWolf source into the build directory and make
               ;; everything writable.
               (copy-recursively #+lw-src ".")
               (for-each make-file-writable (find-files "."))

               ;; Patch Makefile to use the upstream source instead of
               ;; downloading.
               (substitute* '("Makefile")
                 (("^ff_source_tarball:=.*")
                  (string-append "ff_source_tarball:=" #+ff-src)))

               ;; Neuter GPG signing of the tarball.
               (substitute* '("Makefile")
                 (("if [ -f pk.asc ].*") ""))

               ;; Stage locales.
               (begin
                 (substitute* "scripts/librewolf-patches.py"
                   (("l10n_dir = Path(\"..\", \"l10n\")")
                    (string-append
                     "l10n_dir = \"" #+l10n "\""))))

               ;; Run the build script
               (invoke "make" "all")
               (copy-file (string-append "librewolf-" #$version
                                         ".source.tar.gz")
                          #$output)))))
      (patches
       (search-patches
        "librewolf-compare-paths.patch"
        "librewolf-use-system-wide-dir.patch"
        "librewolf-add-store-to-rdd-allowlist.patch"))
      ;; Slim down the tarball by removing unbundled libraries and 75 Mo (800+
      ;; Mo uncompressed) of unused tests.
      (modules '((guix build utils)))
      (snippet
       #~(for-each delete-file-recursively
                   '("testing/web-platform"
                     "gfx/cairo/libpixman"
                     "js/src/ctypes/libffi"
                     "ipc/chromium/src/third_party/libevent"
                     "media/libvpx"
                     "docs/nspr"
                     "media/libwebp"
                     "modules/zlib"))))))

;;; LibreWolf 152.0.1-2 — inherits guix's package; only version + source change.
(define-public librewolf
  (package
    (inherit lw:librewolf)
    (version "152.0.1-2")
    (source
     (make-librewolf-source
      #:version version
      #:firefox-hash "0ppi08ajg00mb0qdlfffnw15mvkfx8xi79ys62ijbpzh0jykgw5z"
      #:librewolf-hash "0wbisx3yvg7g4d09azgksz3yaf7n12xqa0v4dy9hnplwxcxixgda"
      #:l10n firefox-l10n))))

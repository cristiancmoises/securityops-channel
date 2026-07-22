;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2024, 2025 Ian Eure <ian@retrospec.tv>          ; upstream librewolf.scm
;;; Copyright © 2025, 2026 Untrusem <mysticmoksh@riseup.net>    ; upstream librewolf.scm
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; LibreWolf — bumped ahead of Guix: 152.0.1-2 -> 152.0.4-1 (latest upstream).
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
;;; The librewolf-specific patches (`librewolf-compare-paths.patch',
;;; `librewolf-use-system-wide-dir.patch', …) are guix-bundled; `search-patches'
;;; resolves them from guix's patch dir on the channel load path — no need to
;;; vendor them.  (The l10n-download neuter is NOT a search-patch here: guix's
;;; `librewolf-neuter-locale-download.patch' no longer applies to 152.0.x's
;;; `curl'-based script, so it is done inline via `substitute*' below.)
;;;
;;; Hashes (all fetched + verified 2026-07-17):
;;;   firefox 153.0 source    (ftp.mozilla.org)  -> firefox-hash
;;;   librewolf/source 153.0-3 (codeberg, git)   -> librewolf-hash
;;;   firefox-l10n @ 235fd5b0 (github, git)       -> l10n-hash
;;; The l10n commit is the `revision' from
;;; firefox-153.0/browser/locales/l10n-changesets.json in the Firefox source.
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
    ;; The network l10n download in scripts/librewolf-patches.py is neutered in
    ;; `make-librewolf-source' via `substitute*' instead of guix's bundled
    ;; `librewolf-neuter-locale-download.patch'.  That patch targets the old
    ;; `wget|unzip|mv' form of the script; upstream 152.0.4-1 switched to `curl'
    ;; and dropped an unrelated gkrust block above it, so its hunk context no
    ;; longer applies.  The substitute* below tracks the current script.
    (sha256 (base32 hash))))

(define computed-origin-method (@@ (guix packages) computed-origin-method))

(define firefox-l10n
  ;; Match this commit to the upstream tarball.  The hash is in
  ;; firefox-NNN.0/browser/locales/l10n-changesets.json (the "revision" field;
  ;; the same value repeats for every language).  For 153.0 it is 235fd5b0.
  (let ((commit "235fd5b0427bec104e6af4055756b286554fce17"))
    (origin
      (method git-fetch)
      (uri (git-reference
            (url "https://github.com/mozilla-l10n/firefox-l10n.git")
            (commit commit)))
      (file-name (git-file-name "firefox-l10n" commit))
      (sha256 (base32 "003l3jzsf2ysj5vwsjcx91csrj2626j61s0zga3ffkm0v5w72xra")))))

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

               ;; Stage locales: neuter the network firefox-l10n download (no
               ;; network in the build sandbox) and redirect the locale-apply
               ;; loop at the staged firefox-l10n checkout.
               (begin
                 (substitute* "scripts/librewolf-patches.py"
                   ;; Drop the curl|unzip|mv block that fetches l10n from
                   ;; GitHub; keep the `with TemporaryDirectory()' valid by
                   ;; turning its body into `pass'.
                   (("exec\\(f\"curl -so .*l10n\\.zip.*") "pass")
                   (("exec\\(f\"unzip -qo .*l10n\\.zip.*") "")
                   (("exec\\(f\"mv .*firefox-l10n-main lw/l10n\"\\).*") "")
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

;;; LibreWolf 153.0-3 — inherits guix's package; only version + source change.
;;; NOTE: this is a MAJOR firefox 152 -> 153 bump.  The source assembly is
;;; verified, but the compile runs against guix's 152-era build args/toolchain;
;;; watch the first reconfigure for a build-time incompatibility.
(define-public librewolf
  (package
    (inherit lw:librewolf)
    (version "153.0-3")
    (source
     (make-librewolf-source
      #:version version
      #:firefox-hash "08jmllczhrjg00gchji1k2y177c4a1cfp6jm3v9r5in4r1s0yldw"
      #:librewolf-hash "021620653fj7p8dpd3wj65msc6d8frpdx97db2qjvbcwx0hbw5li"
      #:l10n firefox-l10n))))
